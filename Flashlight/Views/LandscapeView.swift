import MetalKit
import SwiftUI

/// Compiles the landscape shader once and shares the pipeline between every view.
final class LandscapeGPU {
    static let shared = LandscapeGPU()

    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: landscapeShaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "landscapeVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "landscapeFragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            assertionFailure("Landscape shader failed to compile: \(error)")
            return nil
        }
        self.device = device
        self.queue = queue
    }
}

/// A Metal view that draws one `Scenery`. Animated scenes redraw at a low frame rate;
/// static ones (thumbnails) draw once per layout.
struct LandscapeView: UIViewRepresentable {
    let scene: Scenery
    var animated = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LandscapeMTKView {
        let view = LandscapeMTKView(frame: .zero, device: LandscapeGPU.shared?.device)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isOpaque = true
        view.delegate = context.coordinator
        // Landscapes are soft, so render below native resolution and let the compositor scale.
        view.contentScaleFactor = animated ? 2 : 1
        view.isPaused = !animated
        view.enableSetNeedsDisplay = !animated
        view.preferredFramesPerSecond = 15
        return view
    }

    func updateUIView(_ view: LandscapeMTKView, context: Context) {
        context.coordinator.params = scene.shaderParams
        view.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var params: [Float] = []
        private let start = CACurrentMediaTime()

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let gpu = LandscapeGPU.shared,
                  let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor,
                  let buffer = gpu.queue.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(descriptor: pass),
                  !params.isEmpty else { return }

            var size = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
            var time = Float((CACurrentMediaTime() - start).truncatingRemainder(dividingBy: 3600))
            if view.isPaused { time = 4 }

            encoder.setRenderPipelineState(gpu.pipeline)
            encoder.setFragmentBytes(&size, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
            encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 1)
            encoder.setFragmentBytes(params, length: params.count * MemoryLayout<Float>.size, index: 2)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }
    }
}

/// Redraws static scenes whenever layout changes.
final class LandscapeMTKView: MTKView {
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
}
