import SceneKit
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Torches point along +Y with the lens at the top. The pose tilts them up and to the right.
enum Builders {
    static let torchTilt: CGFloat = -62 * .pi / 180

    // MARK: - Shared optics

    /// Parabolic reflector, domed lens and an LED, plus the light that makes the reflector shine.
    static func addOptics(_ rig: Rig, radius R: CGFloat, dishY y0: CGFloat, rimY y1: CGFloat,
                          led: CGFloat, ledGlow: UIColor, lightRange: CGFloat) {
        // Dish, ordered rim → axis so the concave side faces the lens.
        let k = (y1 - y0) / (R * R)
        var dish = Profile(R, y1)
        let steps = 24
        for i in stride(from: steps - 1, through: 0, by: -1) {
            let r = R * CGFloat(i) / CGFloat(steps)
            dish = dish.to(r, y0 + k * r * r)
        }
        let mirror = PBR.chrome()
        mirror.roughness.contents = 0.06
        rig.add(Parts.lathe(dish, mirror))

        // LED chip.
        let chip = PBR.emitter(base: UIColor(white: 0.92, alpha: 1), glow: ledGlow)
        rig.addEmitter(chip, glow: ledGlow)
        rig.add(Parts.box(led, 0.12, led, at: SCNVector3(0, Float(y0 + 0.08), 0), chip))

        // Lens.
        let lensGlass = PBR.glass(opacity: 0.1)
        rig.addEmitter(lensGlass, glow: ledGlow.withAlphaComponent(1))
        let lens = Profile(0, y1 + 0.2)
            .curve(R * 0.98, y1 + 0.02, c1x: R * 0.45, c1y: y1 + 0.2, c2x: R * 0.9, c2y: y1 + 0.14)
            .to(R * 0.98, y1 - 0.05).to(0, y1 - 0.05)
        let lensNode = Parts.lathe(lens, lensGlass)
        lensNode.renderingOrder = 10
        rig.add(lensNode)

        rig.addLight(Parts.omni(ledGlow, range: lightRange), at: SCNVector3(0, Float(y0 + 1.2), 0), base: 420)

        rig.emission = .beam
        rig.lensRadius = R
        rig.place(anchorAt: SCNVector3(0, Float(y1 + 0.25), 0), axis: SCNVector3(0, 1, 0))
    }

    // MARK: - Tin Beacon (1950s painted steel)

    static func tin() -> Rig {
        let rig = Rig(tilt: torchTilt, spin: 16 * .pi / 180)
        let chrome = PBR.chrome()
        let lacquer = PBR.paint(UIColor(hex: 0xB0221C), 0.2)
        let darkCream = UIColor(hex: 0xEFE6CF)

        // Bottom cap with rolled edge, and a lanyard eye.
        let cap = Profile(0, 0).to(1.8, 0)
            .curve(2.62, 0.6, c1x: 2.35, c1y: 0, c2x: 2.62, c2y: 0.28)
            .to(2.62, 1.5).to(2.5, 1.58).to(0, 1.58)
        rig.add(Parts.lathe(cap, chrome))
        let eye = Parts.ring(R: 0.6, tube: 0.1, y: 0, chrome)
        eye.position = SCNVector3(0, -0.15, 0)
        eye.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        rig.add(eye)

        // Painted tube with two pressed beads.
        rig.add(Parts.lathe(Profile(0, 1.5).to(2.5, 1.5).to(2.5, 11).to(0, 11), lacquer))
        rig.add(Parts.ring(R: 2.5, tube: 0.1, y: 2.1, lacquer))
        rig.add(Parts.ring(R: 2.5, tube: 0.1, y: 10.3, lacquer))

        // Bulbous chrome head.
        let head = Profile(0, 10.9).to(2.62, 10.9).to(2.62, 11.5)
            .curve(4.15, 13.8, c1x: 2.62, c1y: 12.9, c2x: 4.15, c2y: 12.7)
            .to(4.15, 14.7)
            .curve(4.32, 15.15, c1x: 4.15, c1y: 14.95, c2x: 4.2, c2y: 15.15)
            .to(3.75, 15.15).to(3.72, 14.98)
        rig.add(Parts.lathe(head, chrome))
        rig.add(Parts.ring(R: 2.64, tube: 0.14, y: 11.0, chrome))
        rig.add(Parts.ring(R: 4.2, tube: 0.1, y: 14.75, chrome))

        // Incandescent bulb and filament inside the reflector.
        let bulbGlass = PBR.glass(UIColor(hex: 0xFFF0D0), opacity: 0.22)
        let bulb = Profile(0, 12.95)
            .curve(0.95, 13.9, c1x: 0.6, c1y: 12.95, c2x: 0.95, c2y: 13.4)
            .curve(0, 14.7, c1x: 0.95, c1y: 14.3, c2x: 0.5, c2y: 14.7)
        rig.add(Parts.lathe(bulb, bulbGlass))
        let filament = PBR.emitter(base: UIColor(hex: 0x6B4A2A), glow: UIColor(hex: 0xFFC77A))
        rig.addEmitter(filament, glow: UIColor(hex: 0xFFC77A))
        rig.add(Parts.cylinder(r: 0.09, h: 0.8, y: 13.7, filament))

        addOptics(rig, radius: 3.7, dishY: 12.9, rimY: 14.95, led: 0.01, ledGlow: UIColor(hex: 0xFFD79A), lightRange: 22)

        // Slide switch on the +Z side.
        let slot = PBR.plastic(UIColor(hex: 0x15110E), 0.6)
        rig.add(Parts.box(0.55, 2.6, 0.22, at: SCNVector3(0, 8.2, 2.52), chamfer: 0.08, slot))
        let slider = Parts.box(1.0, 0.9, 0.42, at: SCNVector3(0, 7.7, 2.64), chamfer: 0.14, chrome)
        rig.add(slider)
        for i in 0..<3 {
            rig.add(Parts.box(0.78, 0.07, 0.1, at: SCNVector3(0, 7.5 + Float(i) * 0.22, 2.86), slot))
        }

        // Printed label panel.
        let label = Artwork.wrapLabel(
            size: CGSize(width: 2048, height: 394), panelFraction: 0.33,
            panel: darkCream, border: UIColor(hex: 0x7A1A16),
            lines: [("BEACON", UIFont(name: "Baskerville-Bold", size: 104) ?? .boldSystemFont(ofSize: 104),
                     UIColor(hex: 0x7A1A16), 10),
                    ("No. 2 · HEAVY DUTY", UIFont(name: "Baskerville", size: 44) ?? .systemFont(ofSize: 44),
                     UIColor(hex: 0x7A1A16), 5)])
        let tinDecal = Parts.decal(radius: 2.515, height: 3.0, y: 4.6, image: label)
        tinDecal.eulerAngles.y = -0.3
        rig.add(tinDecal)
        return rig
    }

    // MARK: - Ranger (anodised tactical)

    static func tactical() -> Rig {
        let rig = Rig(tilt: torchTilt, spin: 14 * .pi / 180)
        let body = PBR.anodised(UIColor(hex: 0x1D2025), 0.4)
        let metal = PBR.aluminium(0.3)
        let rubber = PBR.rubber(UIColor(hex: 0x0E0F10))
        let orange = PBR.rubber(UIColor(hex: 0xFF6A1F))

        // Tail cap with a rubber tail switch and lanyard tab.
        let tail = Profile(0, 0.05).to(1.55, 0.05)
            .curve(1.92, 0.5, c1x: 1.8, c1y: 0.05, c2x: 1.92, c2y: 0.2)
            .to(1.92, 1.4).to(0, 1.4)
        rig.add(Parts.lathe(tail, body))
        rig.add(Parts.cylinder(r: 0.78, h: 0.45, y: -0.15, rubber))
        rig.add(Parts.ring(R: 0.84, tube: 0.07, y: -0.1, orange))
        let tab = Parts.ring(R: 0.42, tube: 0.1, y: 0.5, metal)
        tab.position = SCNVector3(2.2, 0.55, 0)
        tab.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        rig.add(tab)

        // Barrel: knurled grip, smooth section, flared head.
        let barrel = Profile(0, 1.35).to(1.92, 1.35).to(1.92, 2.0)
            .teeth(from: 2.0, to: 7.4, count: 56, rLow: 1.83, rHigh: 1.93)
            .to(1.92, 10.2).to(2.0, 10.45).to(2.8, 11.3).to(2.8, 13.5)
            .to(2.98, 13.75).to(2.98, 14.1).to(2.6, 14.25).to(2.56, 14.05)
        rig.add(Parts.lathe(barrel, body, segments: 120))
        rig.add(Parts.ring(R: 1.93, tube: 0.09, y: 10.25, rubber))
        rig.add(Parts.ring(R: 1.94, tube: 0.05, y: 7.75, metal))
        rig.add(Parts.ring(R: 1.94, tube: 0.05, y: 9.7, metal))

        // Strike bezel with crenellations.
        rig.add(Parts.lathe(Profile(2.62, 13.78).to(3.04, 13.78).to(3.04, 14.2).to(2.62, 14.2), metal))
        for i in 0..<14 {
            let a = Float(i) / 14 * 2 * .pi
            let tooth = Parts.box(0.46, 0.5, 0.34, at: SCNVector3(2.88 * cos(a), 14.42, 2.88 * sin(a)), chamfer: 0.04, metal)
            tooth.eulerAngles.y = -a
            rig.add(tooth)
        }

        addOptics(rig, radius: 2.5, dishY: 12.0, rimY: 14.0, led: 0.7,
                  ledGlow: UIColor(hex: 0xEAF2FF), lightRange: 20)

        // Side switch on the +Z side, and a laser-etched label.
        rig.add(Parts.box(1.0, 1.9, 0.34, at: SCNVector3(0, 8.9, 1.95), chamfer: 0.16, orange))
        let label = Artwork.wrapLabel(
            size: CGSize(width: 2048, height: 280), panelFraction: 0.32, panel: nil, border: nil,
            lines: [("RANGER 3-MODE", UIFont(name: "Menlo-Bold", size: 70) ?? .boldSystemFont(ofSize: 70),
                     UIColor(hex: 0xA9B0B9), 9)])
        rig.add(Parts.decal(radius: 1.935, height: 1.0, y: 4.7, image: label))
        return rig
    }

    // MARK: - Pen Steel (aluminium pen light)

    static func penlight() -> Rig {
        let rig = Rig(tilt: torchTilt, spin: 20 * .pi / 180)
        let alu = PBR.aluminium(0.26)
        let chrome = PBR.chrome()
        let dark = PBR.plastic(UIColor(hex: 0x16181B), 0.45)

        // Push-button end cap.
        rig.add(Parts.lathe(Profile(0, 0).to(0.32, 0).curve(0.5, 0.3, c1x: 0.46, c1y: 0, c2x: 0.5, c2y: 0.12)
            .to(0.5, 0.7).to(0, 0.7), chrome, segments: 64))
        rig.add(Parts.ring(R: 0.52, tube: 0.04, y: 0.75, dark))

        // Barrel with a knurled grip band and a tapered head.
        let barrel = Profile(0, 0.7).to(0.55, 0.7).to(0.55, 7.2)
            .teeth(from: 7.2, to: 9.0, count: 22, rLow: 0.53, rHigh: 0.58)
            .to(0.55, 9.5).to(0.62, 9.8)
            .curve(0.8, 10.9, c1x: 0.66, c1y: 10.2, c2x: 0.8, c2y: 10.5)
            .to(0.86, 11.2).to(0.5, 11.25).to(0.48, 11.12)
        rig.add(Parts.lathe(barrel, alu, segments: 72))
        rig.add(Parts.ring(R: 0.56, tube: 0.03, y: 9.55, chrome))

        // Pocket clip on the +Z side, with a rolled tip.
        rig.add(Parts.box(0.22, 6.6, 0.07, at: SCNVector3(0, 4.3, 0.68), chamfer: 0.02, chrome))
        rig.add(Parts.rod(from: SCNVector3(0, 7.55, 0.68), to: SCNVector3(0, 7.7, 0.5), radius: 0.04, chrome))
        rig.add(Parts.rod(from: SCNVector3(0, 0.95, 0.64), to: SCNVector3(0, 0.95, 0.5), radius: 0.05, chrome))
        rig.add(Parts.sphere(r: 0.08, at: SCNVector3(0, 7.65, 0.6), chrome))

        addOptics(rig, radius: 0.46, dishY: 10.35, rimY: 11.12, led: 0.32,
                  ledGlow: UIColor(hex: 0xF4F8FF), lightRange: 8)

        let label = Artwork.wrapLabel(
            size: CGSize(width: 2048, height: 256), panelFraction: 0.3, panel: nil, border: nil,
            lines: [("LUMEN · PEN 60", UIFont(name: "AvenirNext-DemiBold", size: 60) ?? .boldSystemFont(ofSize: 60),
                     UIColor(hex: 0x5A6068), 8)])
        let decal = Parts.decal(radius: 0.555, height: 0.5, y: 5.2, image: label)
        decal.eulerAngles.y = Float.pi
        rig.add(decal)
        return rig
    }

    // MARK: - Site Light (yellow rubber work torch)

    static func workLight() -> Rig {
        let rig = Rig(tilt: torchTilt, spin: 16 * .pi / 180)
        let yellow = PBR.rubber(UIColor(hex: 0xF2C400))
        let black = PBR.rubber(UIColor(hex: 0x111111))
        let metal = PBR.steel(0.4)

        // Black tail bumper and a hanging loop.
        let tail = Profile(0, 0).to(1.9, 0)
            .curve(2.5, 0.7, c1x: 2.3, c1y: 0, c2x: 2.5, c2y: 0.35)
            .to(2.5, 2.0).to(2.42, 2.1).to(0, 2.1)
        rig.add(Parts.lathe(tail, black))
        let loop = Parts.ring(R: 0.95, tube: 0.13, y: 0, metal)
        loop.position = SCNVector3(0, -0.7, 0)
        loop.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        rig.add(loop)

        // Yellow overmold with ribs, and a black hazard band.
        rig.add(Parts.lathe(Profile(0, 2.0).to(2.4, 2.0).to(2.4, 9.5).to(0, 9.5), yellow))
        for i in 0..<5 {
            let y = 2.8 + CGFloat(i) * 0.55
            rig.add(Parts.ring(R: 2.4, tube: 0.1, y: y, yellow))
        }
        rig.add(Parts.lathe(Profile(2.38, 5.0).to(2.46, 5.0).to(2.46, 6.9).to(2.38, 6.9), black))
        let band = Artwork.wrapLabel(
            size: CGSize(width: 2048, height: 360), panelFraction: 0.34, panel: nil, border: nil,
            lines: [("KINETIC", UIFont(name: "AvenirNextCondensed-Heavy", size: 118) ?? .boldSystemFont(ofSize: 118),
                     UIColor(hex: 0xFFD60A), 12)])
        rig.add(Parts.decal(radius: 2.475, height: 1.9, y: 5.95, image: band))

        // Black rubber head bumper.
        let head = Profile(0, 9.4).to(2.5, 9.4)
            .curve(3.4, 10.6, c1x: 3.0, c1y: 9.5, c2x: 3.4, c2y: 10.0)
            .to(3.4, 12.2)
            .curve(3.1, 12.85, c1x: 3.4, c1y: 12.6, c2x: 3.3, c2y: 12.85)
            .to(2.98, 12.72)
        rig.add(Parts.lathe(head, black))
        rig.add(Parts.ring(R: 3.38, tube: 0.12, y: 11.2, yellow))

        addOptics(rig, radius: 2.9, dishY: 10.6, rimY: 12.65, led: 1.2,
                  ledGlow: UIColor(hex: 0xFFF8DC), lightRange: 22)

        // Large rubber switch pad on the +Z side.
        rig.add(Parts.box(1.6, 1.1, 0.4, at: SCNVector3(0, 7.9, 2.28), chamfer: 0.22, black))
        rig.add(Parts.ring(R: 0.3, tube: 0.045, y: 0, PBR.plastic(UIColor(hex: 0xF2C400), 0.4)).also {
            $0.position = SCNVector3(0, 7.9, 2.52)
            $0.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        })
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
