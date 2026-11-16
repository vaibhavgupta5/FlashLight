import SceneKit
import UIKit

enum ModelFactory {
    static func make(_ style: TorchStyle) -> Rig {
        switch style.kind {
        case .tin: Builders.tin()
        case .tactical: Builders.tactical()
        case .penlight: Builders.penlight()
        case .workLight: Builders.workLight()
        case .lantern: Builders.lantern()
        case .bulb: Builders.bulb()
        case .candle: Builders.candle()
        case .ring: Builders.ring()
        case .table: Builders.table()
        }
    }
}

/// Renders each lamp once, lit, into an image for the style picker. Far cheaper than nine live views.
enum ThumbnailCache {
    private static var images: [String: UIImage] = [:]

    static func image(for style: TorchStyle, size: CGSize = CGSize(width: 280, height: 260)) -> UIImage? {
        if let cached = images[style.id] { return cached }
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let rig = ModelFactory.make(style)
        rig.apply(level: 0.9)
        rig.fit(aspect: size.width / size.height)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = rig.scene
        renderer.pointOfView = rig.cameraNode
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        images[style.id] = image
        return image
    }
}
