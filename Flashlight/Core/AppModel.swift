import SwiftUI
import UIKit

enum LightMode: String, CaseIterable, Identifiable {
    case steady, strobe, sos, screen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steady: "Torch"
        case .strobe: "Strobe"
        case .sos: "SOS"
        case .screen: "Screen"
        }
    }

    var symbol: String {
        switch self {
        case .steady: "flashlight.on.fill"
        case .strobe: "bolt.fill"
        case .sos: "light.beacon.max.fill"
        case .screen: "iphone"
        }
    }
}

enum ScreenTint: String, CaseIterable, Identifiable {
    case white, warm, red, blue

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: .white
        case .warm: Color(hex: 0xFFD9A0)
        case .red: Color(hex: 0xFF3B30)
        case .blue: Color(hex: 0x4DA3FF)
        }
    }
}

/// Single source of truth for the light: mode, intensity, torch, scene and the running pattern.
@MainActor
@Observable
final class AppModel {
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let hardware = TorchController()
    @ObservationIgnored private var pattern: Task<Void, Never>?
    @ObservationIgnored private var savedBrightness: CGFloat?

    private(set) var isOn = false

    /// What the lamp is emitting right now, 0 when dark. Drives the on-screen beam,
    /// so strobe and SOS blink in the UI exactly as the LED does.
    private(set) var lampLevel: Double = 0

    var mode: LightMode = .steady {
        didSet { if isOn && oldValue != mode { run() } }
    }

    /// Light output, 0.05...1. In Screen mode it sets display brightness.
    var intensity: Double {
        didSet {
            defaults.set(intensity, forKey: "intensity")
            guard isOn else { return }
            switch mode {
            case .steady: light(intensity)
            case .screen: screen?.brightness = CGFloat(intensity)
            case .strobe, .sos: break  // patterns pick it up on the next flash
            }
        }
    }

    /// Strobe frequency in flashes per second, 1...15.
    var strobeHz: Double {
        didSet {
            defaults.set(strobeHz, forKey: "strobeHz")
            if isOn && mode == .strobe { run() }
        }
    }

    var screenTint: ScreenTint = .white

    var torchID: String {
        didSet { defaults.set(torchID, forKey: "torchID") }
    }

    var sceneID: String {
        didSet { defaults.set(sceneID, forKey: "sceneID") }
    }

    var torch: TorchStyle { TorchStyle.all.first { $0.id == torchID } ?? .tin }
    var scenery: Scenery { Scenery.all.first { $0.id == sceneID } ?? .forest }
    var hasTorch: Bool { hardware.isHardwareAvailable }

    init() {
        torchID = defaults.string(forKey: "torchID") ?? TorchStyle.tin.id
        sceneID = defaults.string(forKey: "sceneID") ?? Scenery.forest.id
        intensity = defaults.object(forKey: "intensity") as? Double ?? 1.0
        strobeHz = defaults.object(forKey: "strobeHz") as? Double ?? 8.0
        #if DEBUG
        // Test hook: launch with `-startLit` to open with the light already on.
        if ProcessInfo.processInfo.arguments.contains("-startLit") {
            DispatchQueue.main.async { [weak self] in self?.start() }
        }
        #endif
    }

    func toggle() {
        isOn ? stop() : start()
    }

    func start() {
        guard !isOn else { return }
        isOn = true
        UIApplication.shared.isIdleTimerDisabled = true
        run()
    }

    func stop() {
        guard isOn else { return }
        isOn = false
        pattern?.cancel()
        pattern = nil
        light(0)
        restoreBrightness()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Pattern engine

    private func run() {
        pattern?.cancel()
        pattern = nil
        restoreBrightness()
        guard isOn else { return }

        switch mode {
        case .steady:
            light(intensity)
        case .screen:
            light(0)
            boostBrightness()
        case .strobe:
            startStrobe()
        case .sos:
            startSOS()
        }
    }

    /// Drives the real LED and the on-screen lamp together.
    private func light(_ level: Double) {
        hardware.set(level: Float(level))
        lampLevel = level
    }

    /// Only lights while the pattern task is live, so a cancelled loop can't relight the lamp.
    private func pulse(_ level: Double) {
        if Task.isCancelled { return }
        light(level)
    }

    private func startStrobe() {
        pattern = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let half = 0.5 / self.strobeHz
                self.pulse(self.intensity)
                await Self.pause(half)
                self.pulse(0)
                await Self.pause(half)
            }
        }
    }

    /// Morse S-O-S: dot = 1 unit, dash = 3, symbol gap = 1, letter gap = 3, word gap = 7.
    private func startSOS() {
        let unit = 0.2
        let letters = ["...", "---", "..."]
        pattern = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                for (index, letter) in letters.enumerated() {
                    for symbol in letter {
                        self.pulse(self.intensity)
                        await Self.pause(unit * (symbol == "-" ? 3 : 1))
                        self.pulse(0)
                        await Self.pause(unit)
                    }
                    await Self.pause(unit * (index == letters.count - 1 ? 4 : 2))
                }
            }
        }
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: - Screen brightness

    private var screen: UIScreen? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
    }

    private func boostBrightness() {
        guard savedBrightness == nil, let screen else { return }
        savedBrightness = screen.brightness
        screen.brightness = CGFloat(intensity)
    }

    private func restoreBrightness() {
        guard let saved = savedBrightness else { return }
        screen?.brightness = saved
        savedBrightness = nil
    }
}
