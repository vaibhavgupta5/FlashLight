#if DEBUG
import SceneKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Renders the App Store icon from the real 3D Tin Beacon model.
/// Run with the launch argument `-exportIcon`; the PNG is written to the app's tmp folder.
enum IconExporter {
    static func exportIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-exportIcon") else { return }
        DispatchQueue.main.async {
            guard let data = render() else { NSLog("IconExporter: render failed"); return }
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon-1024.png")
            do {
                try data.write(to: url)
                NSLog("IconExporter wrote %@", url.path)
            } catch {
                NSLog("IconExporter: write failed %@", "\(error)")
            }
        }
    }

    private static func render() -> Data? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let side: CGFloat = 1024
        let size = CGSize(width: side, height: side)

        // The 3D torch, lit, framed for a square icon.
        let rig = Builders.tin()
        rig.apply(level: 1)
        rig.fit(aspect: 1)
        let geometry = rig.geometry(size: size)
        // Pull the camera back a little for margin, then re-measure.
        rig.cameraNode.position.z += 4
        let framed = rig.geometry(size: size)
        _ = geometry

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = rig.scene
        renderer.pointOfView = rig.cameraNode
        let torch = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            drawNight(g, side: side)
            drawBeam(g, from: framed.anchor, angle: framed.angle, unit: framed.unit)
            torch.draw(in: CGRect(origin: .zero, size: size))
        }
        return opaquePNG(image)
    }

    /// Re-encodes without an alpha channel, which App Store Connect requires for icons.
    private static func opaquePNG(_ image: UIImage) -> Data? {
        guard let cg = image.cgImage,
              let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let flat = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, flat, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    private static func drawNight(_ g: CGContext, side: CGFloat) {
        let space = CGColorSpaceCreateDeviceRGB()
        func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor { UIColor(hex: hex, alpha: a).cgColor }
        let sky = CGGradient(colorsSpace: space, colors: [c(0x050E18), c(0x0F2433), c(0x2A4F5A)] as CFArray, locations: [0, 0.55, 1])!
        g.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: side), options: [])

        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func rnd() -> CGFloat {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return CGFloat(seed % 10_000) / 10_000
        }
        for _ in 0..<80 {
            let x = rnd() * side, y = pow(rnd(), 1.5) * side * 0.6, r = 1.2 + rnd() * 2.6
            g.setFillColor(c(0xFFFFFF, 0.25 + rnd() * 0.6))
            g.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }

        // Moon with a soft halo.
        let moon = CGPoint(x: 220, y: 215)
        let halo = CGGradient(colorsSpace: space, colors: [c(0xF4EBD0, 0.4), c(0xF4EBD0, 0)] as CFArray, locations: [0, 1])!
        g.drawRadialGradient(halo, startCenter: moon, startRadius: 0, endCenter: moon, endRadius: 190, options: [])
        g.setFillColor(c(0xEFE6CC))
        g.fillEllipse(in: CGRect(x: moon.x - 44, y: moon.y - 44, width: 88, height: 88))
        g.setFillColor(c(0xCFC7AC, 0.5))
        for (dx, dy, r) in [(-12, -8, 12), (14, 10, 9), (-4, 18, 7)] as [(CGFloat, CGFloat, CGFloat)] {
            g.fillEllipse(in: CGRect(x: moon.x + dx - r, y: moon.y + dy - r, width: r * 2, height: r * 2))
        }

        // Pine ridges.
        func pines(base: CGFloat, height: CGFloat, color: UInt32, seed s: UInt64) {
            var state = s
            func r() -> CGFloat {
                state ^= state << 13; state ^= state >> 7; state ^= state << 17
                return CGFloat(state % 10_000) / 10_000
            }
            g.setFillColor(c(color))
            g.fill(CGRect(x: 0, y: base, width: side, height: side - base))
            var x: CGFloat = -20
            while x < side + 40 {
                let h = height * (0.5 + 0.5 * r()), w = h * 0.42
                let gy = base + 6
                g.move(to: CGPoint(x: x, y: gy - h))
                g.addLine(to: CGPoint(x: x + w / 2, y: gy - h * 0.1))
                g.addLine(to: CGPoint(x: x - w / 2, y: gy - h * 0.1))
                g.closePath()
                g.move(to: CGPoint(x: x, y: gy - h * 0.72))
                g.addLine(to: CGPoint(x: x + w * 0.64, y: gy))
                g.addLine(to: CGPoint(x: x - w * 0.64, y: gy))
                g.closePath()
                g.fillPath()
                x += height * 0.3 * (0.6 + 0.7 * r())
            }
        }
        pines(base: 870, height: 150, color: 0x0F212C, seed: 11)
        pines(base: 965, height: 190, color: 0x061218, seed: 23)
    }

    private static func drawBeam(_ g: CGContext, from lens: CGPoint, angle: CGFloat, unit: CGFloat) {
        g.saveGState()
        g.translateBy(x: lens.x, y: lens.y)
        g.rotate(by: angle)
        let space = CGColorSpaceCreateDeviceRGB()
        let warm = UIColor(hex: 0xFFE2A0)
        for (alpha, widen) in [(0.12, 1.6), (0.26, 1.28), (0.5, 1.0)] as [(CGFloat, CGFloat)] {
            let start = unit * 3.7 * 0.9
            let spread = (start + 190) * widen
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: -start))
            path.addLine(to: CGPoint(x: 1100, y: -spread))
            path.addLine(to: CGPoint(x: 1100, y: spread))
            path.addLine(to: CGPoint(x: 0, y: start))
            path.closeSubpath()
            g.saveGState()
            g.addPath(path)
            g.clip()
            let gradient = CGGradient(colorsSpace: space,
                                      colors: [warm.withAlphaComponent(alpha).cgColor, warm.withAlphaComponent(alpha * 0.35).cgColor,
                                               warm.withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 0.45, 1])!
            g.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1100, y: 0), options: [])
            g.restoreGState()
        }
        let bloom = unit * 7
        let glow = CGGradient(colorsSpace: space, colors: [warm.withAlphaComponent(0.85).cgColor, warm.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        g.drawRadialGradient(glow, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: bloom, options: [])
        g.restoreGState()
    }
}
#endif
