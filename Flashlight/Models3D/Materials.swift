import SceneKit
import UIKit

/// Physically based material presets. Metalness and roughness follow real surfaces.
enum PBR {
    static func material(_ color: UIColor, metal: CGFloat, rough: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = metal
        m.roughness.contents = rough
        return m
    }

    static func chrome() -> SCNMaterial { material(UIColor(white: 0.93, alpha: 1), metal: 1, rough: 0.09) }
    static func steel(_ rough: CGFloat = 0.34) -> SCNMaterial { material(UIColor(white: 0.78, alpha: 1), metal: 1, rough: rough) }
    static func aluminium(_ rough: CGFloat = 0.28) -> SCNMaterial { material(UIColor(white: 0.86, alpha: 1), metal: 1, rough: rough) }
    static func brass(_ rough: CGFloat = 0.3) -> SCNMaterial { material(UIColor(red: 0.86, green: 0.64, blue: 0.3, alpha: 1), metal: 1, rough: rough) }
    static func anodised(_ color: UIColor, _ rough: CGFloat = 0.42) -> SCNMaterial { material(color, metal: 0.88, rough: rough) }
    static func paint(_ color: UIColor, _ rough: CGFloat = 0.26) -> SCNMaterial { material(color, metal: 0.05, rough: rough) }
    static func rubber(_ color: UIColor) -> SCNMaterial { material(color, metal: 0, rough: 0.92) }
    static func plastic(_ color: UIColor, _ rough: CGFloat = 0.4) -> SCNMaterial { material(color, metal: 0, rough: rough) }
    static func ceramic(_ color: UIColor) -> SCNMaterial { material(color, metal: 0, rough: 0.12) }

    /// Clear glass: mostly transparent, still catches reflections.
    static func glass(_ tint: UIColor = UIColor(white: 0.9, alpha: 1), opacity: CGFloat = 0.16) -> SCNMaterial {
        // A near-black body colour: clear glass reflects, it does not scatter light, so a bright
        // diffuse colour would make it look milky. The tint survives as a faint cast.
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        tint.getRed(&r, green: &g, blue: &bl, alpha: &a)
        let body = UIColor(red: r * 0.06, green: g * 0.06, blue: bl * 0.06, alpha: 1)
        let m = material(body, metal: 0, rough: 0.03)
        m.transparency = opacity
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        return m
    }

    /// A surface that glows by itself. The rig scales `emission.intensity` with the lamp level.
    static func emitter(base: UIColor, glow: UIColor) -> SCNMaterial {
        let m = material(base, metal: 0, rough: 0.5)
        m.emission.contents = glow
        m.emission.intensity = 0
        return m
    }

    /// Light additively blended, for flames and halos.
    static func additive(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }
}

/// A dark studio with soft boxes, so metal and glass reflect something believable.
enum StudioEnvironment {
    static let image: UIImage = {
        let size = CGSize(width: 1024, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(red: 0.20, green: 0.24, blue: 0.30, alpha: 1).cgColor,
                          UIColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1).cgColor,
                          UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.5, 1])!
            g.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor) {
                color.setFill()
                UIBezierPath(roundedRect: CGRect(x: x * size.width, y: y * size.height,
                                                 width: w * size.width, height: h * size.height),
                             cornerRadius: 8).fill()
            }
            box(0.13, 0.22, 0.13, 0.26, UIColor(white: 1.0, alpha: 1))                       // key softbox
            box(0.60, 0.10, 0.045, 0.42, UIColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)) // cool strip
            box(0.36, 0.05, 0.28, 0.06, UIColor(white: 0.95, alpha: 1))                      // top light
            box(0.86, 0.30, 0.04, 0.22, UIColor(red: 1, green: 0.88, blue: 0.7, alpha: 1))   // warm kicker
            box(0.0, 0.46, 1.0, 0.02, UIColor(white: 0.5, alpha: 1))                         // horizon line
        }
    }()
}
