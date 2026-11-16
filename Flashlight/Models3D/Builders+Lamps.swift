import SceneKit
import UIKit

extension Builders {
    // MARK: - Inner glow

    /// A soft, camera-facing glow sprite inside clear glass, standing in for light scattering.
    static func innerGlow(_ rig: Rig, radius: CGFloat, at p: SCNVector3, color: UIColor) {
        let plane = SCNPlane(width: radius * 2, height: radius * 2)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = Artwork.radialGlow(color: color)
        m.blendMode = .alpha
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        plane.materials = [m]
        rig.trackSprite(m)
        let node = SCNNode(geometry: plane)
        node.position = p
        node.renderingOrder = 25
        node.categoryBitMask = 2
        node.constraints = [SCNBillboardConstraint()]
        rig.add(node)
    }

    // MARK: - Flame

    /// A teardrop flame: translucent outer envelope, bright core, blue base. Flickers by itself.
    static func flameNode(scale: CGFloat) -> SCNNode {
        let root = SCNNode()
        let core = SCNNode()
        root.addChildNode(core)

        let tear = Profile(0, 0)
            .curve(0.3, 0.55, c1x: 0.24, c1y: 0, c2x: 0.32, c2y: 0.3)
            .curve(0, 1.95, c1x: 0.28, c1y: 1.0, c2x: 0.08, c2y: 1.55)
        let outer = Parts.lathe(tear, PBR.additive(UIColor(red: 0.95, green: 0.46, blue: 0.1, alpha: 1)), segments: 32)
        outer.renderingOrder = 30
        core.addChildNode(outer)

        let inner = Parts.lathe(tear, PBR.additive(UIColor(red: 1, green: 0.86, blue: 0.5, alpha: 1)), segments: 32)
        inner.scale = SCNVector3(0.55, 0.62, 0.55)
        inner.position = SCNVector3(0, 0.1, 0)
        inner.renderingOrder = 31
        core.addChildNode(inner)

        let blue = Parts.sphere(r: 0.13, at: SCNVector3(0, 0.12, 0), PBR.additive(UIColor(red: 0.15, green: 0.3, blue: 0.85, alpha: 1)))
        blue.renderingOrder = 32
        core.addChildNode(blue)

        let step = SCNAction.sequence([
            .run { n in
                n.scale = SCNVector3(Float.random(in: 0.92...1.08), Float.random(in: 0.88...1.2), Float.random(in: 0.92...1.08))
                n.position.x = Float.random(in: -0.035...0.035)
            },
            .wait(duration: 0.08, withRange: 0.06),
        ])
        core.runAction(.repeatForever(step))
        root.scale = SCNVector3(Float(scale), Float(scale), Float(scale))
        return root
    }

    // MARK: - Harbor Lantern (brass hurricane lantern)

    static func lantern() -> Rig {
        let rig = Rig(tilt: 0, spin: 12 * .pi / 180)
        rig.animated = true
        let brass = PBR.brass(0.27)
        let dark = PBR.plastic(UIColor(hex: 0x15110C), 0.7)

        // Fuel font with a flange and burner.
        let font = Profile(0, 0).to(2.8, 0)
            .curve(3.25, 0.8, c1x: 3.2, c1y: 0, c2x: 3.28, c2y: 0.4)
            .curve(2.35, 3.0, c1x: 3.2, c1y: 1.7, c2x: 2.5, c2y: 2.4)
            .to(2.3, 3.3).to(2.8, 3.3).to(2.8, 3.62).to(2.0, 3.62).to(1.95, 3.9)
        rig.add(Parts.lathe(font, brass))
        rig.add(Parts.ring(R: 3.22, tube: 0.1, y: 1.3, brass))
        rig.add(Parts.lathe(Profile(0, 3.8).to(0.72, 3.8).to(0.72, 4.35).to(0.46, 4.42).to(0, 4.42), brass, segments: 48))
        rig.add(Parts.box(0.55, 0.4, 0.1, at: SCNVector3(0, 4.6, 0), dark))

        // Glass globe, slightly warm, that glows when lit.
        let glass = PBR.glass(UIColor(hex: 0xFFEFD2), opacity: 0.16)
        rig.addEmitter(glass, glow: UIColor(hex: 0x5A3410))
        let globe = Profile(1.95, 3.85)
            .curve(2.55, 6.6, c1x: 1.9, c1y: 4.9, c2x: 2.55, c2y: 5.4)
            .curve(1.4, 10.5, c1x: 2.55, c1y: 8.2, c2x: 1.55, c2y: 9.6)
        let globeNode = Parts.lathe(globe, glass)
        globeNode.renderingOrder = 12
        globeNode.categoryBitMask = 2
        rig.add(globeNode)

        innerGlow(rig, radius: 2.6, at: SCNVector3(0, 6.0, 0), color: UIColor(red: 0.95, green: 0.5, blue: 0.16, alpha: 1))

        // Cage wires and hoops.
        for i in 0..<4 {
            let a = (Float(i) * 90 + 45) * .pi / 180
            rig.add(Parts.rod(from: SCNVector3(2.85 * cos(a), 3.7, 2.85 * sin(a)),
                              to: SCNVector3(2.0 * cos(a), 10.9, 2.0 * sin(a)), radius: 0.075, brass))
        }
        rig.add(Parts.ring(R: 2.72, tube: 0.06, y: 6.4, brass))

        // Top cap, ventilator and bail handle.
        let cap = Profile(1.3, 10.4).to(2.25, 10.4).to(2.25, 10.8)
            .curve(1.0, 12.1, c1x: 2.25, c1y: 11.6, c2x: 1.5, c2y: 11.95)
            .to(0.85, 12.1).to(0.85, 12.7)
            .curve(0, 13.5, c1x: 0.85, c1y: 13.2, c2x: 0.4, c2y: 13.5)
        rig.add(Parts.lathe(cap, brass))
        rig.add(Parts.ring(R: 1.35, tube: 0.1, y: 10.45, brass))
        rig.add(Parts.wireArc(center: SCNVector3(0, 11.0, 0), radius: 2.7, from: 0, to: 180, thickness: 0.1, brass))
        rig.add(Parts.sphere(r: 0.16, at: SCNVector3(2.7, 11.0, 0), brass))
        rig.add(Parts.sphere(r: 0.16, at: SCNVector3(-2.7, 11.0, 0), brass))

        // Enamel name plate on the font.
        let plate = Artwork.wrapLabel(
            size: CGSize(width: 2048, height: 330), panelFraction: 0.3,
            panel: UIColor(hex: 0x1F3A2E), border: UIColor(hex: 0xE8D4A0),
            lines: [("HARBOR", UIFont(name: "Didot-Bold", size: 92) ?? .boldSystemFont(ofSize: 92), UIColor(hex: 0xE8D4A0), 12)])
        rig.add(Parts.decal(radius: 3.24, height: 1.4, y: 1.8, image: plate))

        // Flame on the wick.
        let flame = flameNode(scale: 1.25)
        flame.position = SCNVector3(0, 4.75, 0)
        rig.add(flame)
        rig.flame = flame

        rig.addLight(Parts.omni(UIColor(hex: 0xFFB060), range: 20), at: SCNVector3(0, 5.6, 0), base: 360)
        rig.emission = .glow
        rig.place(anchorAt: SCNVector3(0, 5.6, 0))
        return rig
    }

    // MARK: - Filament Bulb (pendant, E27 LED)

    static func bulb() -> Rig {
        let rig = Rig(tilt: .pi, spin: 10 * .pi / 180)
        let nickel = PBR.steel(0.3)
        let brass = PBR.brass(0.3)
        let black = PBR.plastic(UIColor(hex: 0x111111), 0.35)

        // E27 screw base with real threads, contact and insulator.
        rig.add(Parts.lathe(Profile(0, -0.5).to(0.5, -0.5).to(0.6, -0.35).to(0.6, 0).to(0, 0), brass, segments: 48))
        let base = Profile(0, 0).to(1.15, 0).to(1.2, 0.3)
            .teeth(from: 0.3, to: 3.4, count: 5, rLow: 1.22, rHigh: 1.46)
            .to(1.42, 3.55).to(1.56, 3.7).to(1.56, 4.15).to(0, 4.15)
        rig.add(Parts.lathe(base, nickel, segments: 96))
        rig.add(Parts.ring(R: 1.15, tube: 0.14, y: 0.12, black))

        // Glass envelope (A60 shape) over the neck.
        let glass = PBR.glass(UIColor(hex: 0xF6F2E8), opacity: 0.13)
        let envelope = Profile(1.5, 4.0)
            .curve(3.05, 7.4, c1x: 1.5, c1y: 5.2, c2x: 3.05, c2y: 5.6)
            .curve(0, 11.6, c1x: 3.05, c1y: 9.8, c2x: 1.6, c2y: 11.6)
        let glassNode = Parts.lathe(envelope, glass)
        glassNode.renderingOrder = 12
        glassNode.categoryBitMask = 2
        rig.add(glassNode)

        innerGlow(rig, radius: 3.4, at: SCNVector3(0, 7.5, 0), color: UIColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1))

        // Glass stem, flare and LED filaments.
        let stemGlass = PBR.glass(UIColor(hex: 0xF6F2E8), opacity: 0.35)
        rig.add(Parts.cylinder(r: 0.3, h: 1.9, y: 4.95, stemGlass))
        rig.add(Parts.cylinder(r: 0.9, h: 0.1, y: 5.9, stemGlass))
        let filament = PBR.emitter(base: UIColor(hex: 0x8A5A1E), glow: UIColor(hex: 0xFFB04A))
        rig.addEmitter(filament, glow: UIColor(hex: 0xFFB04A))
        for i in 0..<4 {
            let a = Float(i) * .pi / 2 + .pi / 4
            rig.add(Parts.rod(from: SCNVector3(0.55 * cos(a), 5.95, 0.55 * sin(a)),
                              to: SCNVector3(0.9 * cos(a), 9.55, 0.9 * sin(a)), radius: 0.075, filament))
        }
        rig.add(Parts.rod(from: SCNVector3(0, 5.9, 0), to: SCNVector3(0, 9.9, 0), radius: 0.03, nickel))
        rig.add(Parts.ring(R: 0.92, tube: 0.04, y: 9.55, nickel))
        rig.add(Parts.sphere(r: 0.09, at: SCNVector3(0, 9.95, 0), nickel))

        // Bakelite socket hugging the thread, and a cloth cord going up out of frame
        // (the bulb hangs, so local -Y points up on screen).
        let socket = Profile(0, -4.6).to(0.55, -4.6)
            .curve(1.55, -3.2, c1x: 0.95, c1y: -4.4, c2x: 1.55, c2y: -3.8)
            .to(1.68, -2.4).to(1.68, 2.3)
            .curve(1.78, 2.75, c1x: 1.68, c1y: 2.5, c2x: 1.78, c2y: 2.6).to(1.6, 2.85).to(0, 2.85)
        rig.add(Parts.lathe(socket, black, segments: 72))
        rig.add(Parts.ring(R: 1.69, tube: 0.07, y: 2.2, brass))
        rig.add(Parts.ring(R: 1.69, tube: 0.06, y: -2.5, brass))
        rig.add(Parts.cylinder(r: 0.2, h: 5.6, y: -7.2, PBR.rubber(UIColor(hex: 0x241810))))

        rig.addLight(Parts.omni(UIColor(hex: 0xFFB866), range: 18), at: SCNVector3(0, 7.6, 0), base: 260)
        rig.emission = .glow
        rig.glowCore = 0.18
        rig.place(anchorAt: SCNVector3(0, 7.6, 0))
        return rig
    }

    // MARK: - Taper Candle (beeswax in a brass holder)

    static func candle() -> Rig {
        let rig = Rig(tilt: 0, spin: 10 * .pi / 180)
        rig.animated = true
        let brass = PBR.brass(0.26)

        // Brass candlestick.
        let holder = Profile(0, 0).to(3.3, 0)
            .curve(3.0, 0.65, c1x: 3.4, c1y: 0.3, c2x: 3.2, c2y: 0.5)
            .to(2.3, 0.95)
            .curve(0.85, 2.7, c1x: 1.4, c1y: 1.3, c2x: 0.85, c2y: 1.9)
            .to(0.75, 3.2)
            .curve(1.15, 3.9, c1x: 0.75, c1y: 3.45, c2x: 1.15, c2y: 3.6)
            .curve(0.72, 4.7, c1x: 1.15, c1y: 4.25, c2x: 0.72, c2y: 4.4)
            .to(0.72, 6.0)
            .curve(1.0, 6.7, c1x: 0.72, c1y: 6.2, c2x: 1.0, c2y: 6.4)
            .curve(0.8, 7.4, c1x: 1.0, c1y: 6.95, c2x: 0.8, c2y: 7.15)
            .curve(2.0, 8.6, c1x: 0.85, c1y: 7.9, c2x: 1.6, c2y: 8.25)
            .to(2.0, 8.9).to(0.9, 8.9)
        rig.add(Parts.lathe(holder, brass))

        // Wax with a melted pool at the top. A vertical gradient makes the top glow when lit.
        let wax = PBR.material(UIColor(hex: 0xF3EAD3), metal: 0, rough: 0.5)
        let glowImage = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 256)).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [UIColor(hex: 0xFF9A3C).cgColor, UIColor(hex: 0x2A1204).cgColor, UIColor.black.cgColor] as CFArray,
                               locations: [0, 0.22, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
        rig.addEmitter(wax, glow: .white)
        wax.emission.contents = glowImage
        let candleProfile = Profile(0, 8.7).to(0.8, 8.7).to(0.76, 16.5)
            .curve(0.7, 17.0, c1x: 0.75, c1y: 16.8, c2x: 0.72, c2y: 17.0)
            .curve(0.4, 16.78, c1x: 0.5, c1y: 17.0, c2x: 0.45, c2y: 16.9)
            .curve(0, 16.6, c1x: 0.25, c1y: 16.68, c2x: 0.1, c2y: 16.6)
        rig.add(Parts.lathe(candleProfile, wax))
        for (angle, bottom) in [(40.0, 14.9), (160.0, 15.6), (280.0, 15.1)] as [(CGFloat, CGFloat)] {
            let a = Float(angle * .pi / 180)
            rig.add(Parts.rod(from: SCNVector3(0.8 * cos(a), 16.6, 0.8 * sin(a)),
                              to: SCNVector3(0.86 * cos(a), Float(bottom), 0.86 * sin(a)), radius: 0.12, wax))
        }
        // A wax puddle on the drip tray.
        rig.add(Parts.lathe(Profile(0, 8.92).to(1.5, 8.92).curve(1.15, 9.1, c1x: 1.5, c1y: 9.02, c2x: 1.3, c2y: 9.1).to(0, 9.1), wax))

        // Wick with a glowing ember tip.
        let char = PBR.plastic(UIColor(hex: 0x14100C), 0.8)
        rig.add(Parts.rod(from: SCNVector3(0, 16.6, 0), to: SCNVector3(0.06, 17.5, 0.03), radius: 0.045, char))
        let ember = PBR.emitter(base: UIColor(hex: 0x331208), glow: UIColor(hex: 0xFF5A1A))
        rig.addEmitter(ember, glow: UIColor(hex: 0xFF5A1A))
        rig.add(Parts.sphere(r: 0.07, at: SCNVector3(0.06, 17.52, 0.03), ember))

        let flame = flameNode(scale: 1.15)
        flame.position = SCNVector3(0.06, 17.5, 0.03)
        rig.add(flame)
        rig.flame = flame

        rig.addLight(Parts.omni(UIColor(hex: 0xFFAA55), range: 24), at: SCNVector3(0, 18.4, 0), base: 300)
        rig.emission = .glow
        rig.place(anchorAt: SCNVector3(0, 18.4, 0))
        return rig
    }

    // MARK: - Ring Light (desktop studio ring)

    static func ring() -> Rig {
        let rig = Rig(tilt: 0, spin: -26 * .pi / 180)
        let black = PBR.plastic(UIColor(hex: 0x131416), 0.45)
        let alu = PBR.aluminium(0.3)
        let rubber = PBR.rubber(UIColor(hex: 0x0D0D0E))

        // Housing and the LED diffuser. Profiles are revolved around Y, then turned to face the viewer.
        let housing = Profile(4.15, -0.5).to(5.75, -0.5).to(5.75, 0.45).to(5.5, 0.55).to(4.4, 0.55).to(4.15, 0.45).to(4.15, -0.5)
        let housingNode = Parts.lathe(housing, black, segments: 128)
        housingNode.eulerAngles.x = Float.pi / 2
        rig.add(housingNode)

        let diffuser = PBR.emitter(base: UIColor(hex: 0x9A9EA6), glow: UIColor(hex: 0xF4F8FF))
        rig.addEmitter(diffuser, glow: UIColor(hex: 0xF4F8FF))
        let panel = Profile(4.5, 0.53).to(5.4, 0.53).to(5.4, 0.6).to(4.5, 0.6).to(4.5, 0.53)
        let panelNode = Parts.lathe(panel, diffuser, segments: 128)
        panelNode.eulerAngles.x = Float.pi / 2
        rig.add(panelNode)
        // Brand strip on the bottom of the ring.
        rig.add(Parts.box(1.5, 0.28, 0.06, at: SCNVector3(0, -4.95, 0.58), PBR.plastic(UIColor(hex: 0x2A2C30), 0.4)))

        // Bracket, swivel knob and telescoping pole on a weighted base.
        rig.add(Parts.box(1.5, 1.3, 1.1, at: SCNVector3(0, -6.0, -0.1), chamfer: 0.25, black))
        let knob = Parts.cylinder(r: 0.62, h: 1.1, y: -6.9, alu, z: -0.1)
        knob.eulerAngles.z = Float.pi / 2
        rig.add(knob)
        rig.add(Parts.cylinder(r: 0.36, h: 3.0, y: -8.4, alu, z: -0.1))
        rig.add(Parts.cylinder(r: 0.3, h: 3.2, y: -11.2, alu, z: -0.1))
        rig.add(Parts.ring(R: 0.41, tube: 0.07, y: -9.8, black).also { $0.position.z = -0.1 })
        rig.add(Parts.ring(R: 0.36, tube: 0.06, y: -12.6, black).also { $0.position.z = -0.1 })
        let foot = Profile(0, -14.4).to(3.6, -14.4).curve(3.9, -14.0, c1x: 3.8, c1y: -14.4, c2x: 3.9, c2y: -14.2)
            .to(3.9, -13.6).to(2.0, -13.4).to(0.5, -13.0).to(0, -13.0)
        let footNode = Parts.lathe(foot, black)
        footNode.position.z = -0.1
        rig.add(footNode)
        rig.add(Parts.ring(R: 3.7, tube: 0.1, y: -14.35, rubber).also { $0.position.z = -0.1 })

        rig.addLight(Parts.omni(UIColor(hex: 0xEAF2FF), range: 26), at: SCNVector3(0, 0, 4), base: 320)
        rig.emission = .ring
        rig.place(anchorAt: SCNVector3(0, 0, 0.6))
        for p in [SCNVector3(4.95, 0, 0.6), SCNVector3(0, 4.95, 0.6)] {
            let n = SCNNode()
            n.position = p
            rig.add(n)
            rig.secondaryNodes.append(n)
        }
        return rig
    }

    // MARK: - Table Lamp (ceramic base, linen shade)

    static func table() -> Rig {
        let rig = Rig(tilt: 0, spin: 14 * .pi / 180)
        let brass = PBR.brass(0.3)
        let glaze = PBR.ceramic(UIColor(hex: 0x0E6B66))

        // Brass plinth and glazed ceramic body.
        rig.add(Parts.lathe(Profile(0, 0).to(2.9, 0).to(2.9, 0.6).to(0, 0.6), brass))
        let body = Profile(0, 0.55).to(2.6, 0.55)
            .curve(3.75, 2.7, c1x: 3.3, c1y: 0.8, c2x: 3.85, c2y: 1.7)
            .curve(3.2, 5.4, c1x: 3.65, c1y: 3.7, c2x: 3.45, c2y: 4.7)
            .curve(1.25, 7.7, c1x: 3.0, c1y: 6.4, c2x: 1.7, c2y: 7.1)
            .to(1.05, 8.0).to(1.25, 8.2).to(0, 8.2)
        rig.add(Parts.lathe(body, glaze, segments: 128))
        rig.add(Parts.lathe(Profile(0.98, 8.1).to(1.4, 8.1).to(1.4, 8.7).to(0.98, 8.7), brass, segments: 64))

        // Stem, socket, pull chain.
        rig.add(Parts.cylinder(r: 0.28, h: 3.6, y: 10.4, brass))
        let socket = Profile(0, 11.8).to(0.95, 11.8).to(0.95, 13.4).curve(0.55, 14.0, c1x: 0.95, c1y: 13.8, c2x: 0.75, c2y: 14.0).to(0, 14.0)
        rig.add(Parts.lathe(socket, brass, segments: 64))
        for i in 0..<12 {
            rig.add(Parts.sphere(r: 0.07, at: SCNVector3(1.15, 12.3 - Float(i) * 0.3, 0.35), PBR.brass(0.25)))
        }
        rig.add(Parts.sphere(r: 0.2, at: SCNVector3(1.15, 8.55, 0.35), brass))

        // The bulb, glowing, sits inside the shade.
        let bulb = PBR.emitter(base: UIColor(hex: 0xFFF3DC), glow: UIColor(hex: 0xFFE2B0))
        rig.addEmitter(bulb, glow: UIColor(hex: 0xFFE2B0))
        rig.add(Parts.sphere(r: 1.35, at: SCNVector3(0, 15.3, 0), bulb))

        // Empire-shaped linen shade, brighter when lit.
        let linen = PBR.material(UIColor(hex: 0xEDE0C6), metal: 0, rough: 0.95)
        linen.isDoubleSided = true
        linen.transparency = 0.93
        rig.addEmitter(linen, glow: UIColor(hex: 0xB98A4A))
        let shade = Profile(5.0, 11.0).curve(3.6, 19.0, c1x: 4.7, c1y: 13.5, c2x: 4.0, c2y: 16.5)
        let shadeNode = Parts.lathe(shade, linen, segments: 128)
        shadeNode.renderingOrder = 20
        rig.add(shadeNode)
        rig.add(Parts.ring(R: 5.0, tube: 0.07, y: 11.0, brass))
        rig.add(Parts.ring(R: 3.6, tube: 0.07, y: 19.0, brass))
        for i in 0..<3 {
            let a = Float(i) * 2 * .pi / 3
            rig.add(Parts.rod(from: SCNVector3(0, 13.9, 0), to: SCNVector3(4.7 * cos(a), 11.2, 4.7 * sin(a)), radius: 0.03, brass))
        }
        rig.add(Parts.lathe(Profile(0, 19.0).to(0.5, 19.0).to(0.35, 19.7).to(0.7, 20.5).to(0, 21.2), brass, segments: 48))

        rig.addLight(Parts.omni(UIColor(hex: 0xFFC882), range: 30), at: SCNVector3(0, 15.3, 0), base: 420)
        rig.emission = .shade
        rig.lensRadius = 5.0
        rig.place(anchorAt: SCNVector3(0, 15.3, 0))
        for p in [SCNVector3(0, 19.0, 0), SCNVector3(0, 11.0, 0)] {
            let n = SCNNode()
            n.position = p
            rig.add(n)
            rig.secondaryNodes.append(n)
        }
        return rig
    }
}

private extension SCNNode {
    @discardableResult
    func also(_ configure: (SCNNode) -> Void) -> SCNNode {
        configure(self)
        return self
    }
}
