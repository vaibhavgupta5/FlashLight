import SceneKit
import SwiftUI

/// SceneKit view that reports its layout so the rig can frame the model and project its emitter.
final class RigView: SCNView {
    var onLayout: ((RigView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(self)
    }
}

/// Hosts a `Rig` on a transparent SceneKit view.
struct LampSceneView: UIViewRepresentable {
    let rig: Rig
    let level: Double
    var animated = true
    @Binding var geometry: StageGeometry

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var geometry: Binding<StageGeometry>?
    }

    func makeUIView(context: Context) -> RigView {
        let view = RigView(frame: .zero, options: nil)
        view.scene = rig.scene
        view.pointOfView = rig.cameraNode
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.isUserInteractionEnabled = false
        view.autoenablesDefaultLighting = false
        let continuous = animated && rig.animated
        view.rendersContinuously = continuous
        view.isPlaying = continuous

        context.coordinator.geometry = $geometry
        let rig = self.rig
        view.onLayout = { [weak coordinator = context.coordinator] v in
            guard v.bounds.width > 1, v.bounds.height > 1 else { return }
            rig.fit(aspect: v.bounds.width / v.bounds.height)
            let g = rig.geometry(size: v.bounds.size)
            DispatchQueue.main.async {
                if coordinator?.geometry?.wrappedValue != g { coordinator?.geometry?.wrappedValue = g }
            }
        }
        return view
    }

    func updateUIView(_ view: RigView, context: Context) {
        context.coordinator.geometry = $geometry
        rig.apply(level: level)
    }
}
