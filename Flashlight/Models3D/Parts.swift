import SceneKit
import UIKit

/// Small building blocks shared by every model. Y is up and all radial parts sit on the Y axis.
enum Parts {
    static func lathe(_ profile: Profile, _ material: SCNMaterial, segments: Int = 96) -> SCNNode {
        let geometry = Lathe.geometry(profile, segments: segments)
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    static func cylinder(r: CGFloat, h: CGFloat, y: CGFloat, _ material: SCNMaterial,
                         x: CGFloat = 0, z: CGFloat = 0) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h)
        g.radialSegmentCount = 48
        g.materials = [material]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(Float(x), Float(y), Float(z))
        return n
    }

    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, at p: SCNVector3, chamfer: CGFloat = 0,
                    _ material: SCNMaterial) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
        g.chamferSegmentCount = 4
        g.materials = [material]
        let n = SCNNode(geometry: g)
        n.position = p
        return n
    }

    static func sphere(r: CGFloat, at p: SCNVector3, _ material: SCNMaterial) -> SCNNode {
        let g = SCNSphere(radius: r)
        g.segmentCount = 48
        g.materials = [material]
        let n = SCNNode(geometry: g)
        n.position = p
        return n
    }

    /// A horizontal ring (torus) around the Y axis, such as a bead, O-ring or wire hoop.
    static func ring(R: CGFloat, tube: CGFloat, y: CGFloat, _ material: SCNMaterial) -> SCNNode {
        let g = SCNTorus(ringRadius: R, pipeRadius: tube)
        g.ringSegmentCount = 72
        g.pipeSegmentCount = 20
        g.materials = [material]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(0, Float(y), 0)
        return n
    }

    /// A capsule-ended rod between two points.
    static func rod(from a: SCNVector3, to b: SCNVector3, radius: CGFloat, _ material: SCNMaterial) -> SCNNode {
        let va = SIMD3<Float>(a.x, a.y, a.z)
        let vb = SIMD3<Float>(b.x, b.y, b.z)
        let d = vb - va
        let length = simd_length(d)
        let g = SCNCapsule(capRadius: radius, height: CGFloat(length) + radius * 2)
        g.radialSegmentCount = 16
        g.materials = [material]
        let n = SCNNode(geometry: g)
        n.simdPosition = (va + vb) / 2
        n.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(d))
        return n
    }

    /// A smooth arc built from rod segments, for handles, bails and bent wire.
    static func wireArc(center: SCNVector3, radius: CGFloat, from: CGFloat, to: CGFloat,
                        thickness: CGFloat, steps: Int = 28, _ material: SCNMaterial) -> SCNNode {
        let group = SCNNode()
        var previous: SCNVector3?
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = (from + (to - from) * t) * .pi / 180
            let p = SCNVector3(center.x + Float(radius * cos(a)), center.y + Float(radius * sin(a)), center.z)
            if let previous { group.addChildNode(rod(from: previous, to: p, radius: thickness, material)) }
            previous = p
        }
        return group
    }

    /// A printed wrap-around label, laid over a cylinder of the given radius.
    static func decal(radius: CGFloat, height: CGFloat, y: CGFloat, image: UIImage) -> SCNNode {
        let g = SCNCylinder(radius: radius, height: height)
        g.radialSegmentCount = 96
        let m = PBR.material(.white, metal: 0, rough: 0.5)
        m.diffuse.contents = image
        m.transparencyMode = .aOne
        m.blendMode = .alpha
        m.writesToDepthBuffer = false
        g.materials = [m, PBR.glass(opacity: 0), PBR.glass(opacity: 0)]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(0, Float(y), 0)
        n.renderingOrder = 5
        return n
    }

    static func omni(_ color: UIColor, range: CGFloat) -> SCNLight {
        let l = SCNLight()
        l.type = .omni
        l.color = color
        l.attenuationStartDistance = 0
        l.attenuationEndDistance = range
        l.attenuationFalloffExponent = 1.5
        return l
    }
}

/// Draws printed artwork for decals and glow textures.
enum Artwork {
    /// A soft radial glow: colour at the centre, fading to fully transparent at the edge.
    static func radialGlow(color: UIColor, size: CGFloat = 256) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let g = ctx.cgContext
            var r: CGFloat = 0, gr: CGFloat = 0, b: CGFloat = 0, al: CGFloat = 0
            color.getRed(&r, green: &gr, blue: &b, alpha: &al)
            func tone(_ alpha: CGFloat) -> CGColor { UIColor(red: r, green: gr, blue: b, alpha: alpha).cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [tone(0.95), tone(0.5), tone(0.14), tone(0)] as CFArray,
                                      locations: [0, 0.32, 0.68, 1])!
            let c = CGPoint(x: size / 2, y: size / 2)
            g.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size / 2, options: [])
        }
    }

    /// A wrap-around label: `panelFraction` of the circumference, centred on the front.
    static func wrapLabel(size: CGSize = CGSize(width: 2048, height: 512),
                          panelFraction: CGFloat, panel: UIColor?, border: UIColor?,
                          lines: [(text: String, font: UIFont, color: UIColor, kern: CGFloat)]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let panelW = size.width * panelFraction
            let rect = CGRect(x: (size.width - panelW) / 2, y: size.height * 0.06,
                              width: panelW, height: size.height * 0.88)
            if let panel {
                panel.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 28).fill()
            }
            if let border {
                border.setStroke()
                g.setLineWidth(8)
                UIBezierPath(roundedRect: rect.insetBy(dx: 18, dy: 18), cornerRadius: 18).stroke()
            }
            var y = rect.minY + rect.height * 0.14
            for line in lines {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: line.font, .foregroundColor: line.color, .kern: line.kern,
                ]
                let text = NSAttributedString(string: line.text, attributes: attributes)
                let s = text.size()
                text.draw(at: CGPoint(x: rect.midX - s.width / 2, y: y))
                y += s.height + rect.height * 0.04
            }
        }
    }
}
