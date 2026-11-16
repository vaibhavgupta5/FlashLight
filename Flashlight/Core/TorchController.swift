import AVFoundation

/// Thin wrapper around the rear camera torch.
/// On devices or simulators without a torch, every call is a safe no-op.
@MainActor
final class TorchController {
    let isHardwareAvailable: Bool
    private let device: AVCaptureDevice?

    init() {
        device = AVCaptureDevice.default(for: .video)
        isHardwareAvailable = device?.hasTorch ?? false
    }

    /// Sets torch brightness. `level` is 0...1; 0 turns the torch off.
    func set(level: Float) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if level <= 0.001 {
                device.torchMode = .off
            } else {
                let clamped = min(max(level, 0.01), AVCaptureDevice.maxAvailableTorchLevel)
                try device.setTorchModeOn(level: clamped)
            }
        } catch {
            // Torch busy or unavailable (e.g. another app holds the camera). Fail quietly.
        }
    }

    func off() {
        set(level: 0)
    }
}
