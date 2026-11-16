import SwiftUI
import Vortex

/// Renders a `Scenery`: a Metal shader for sky and terrain, plus Vortex particles on top.
struct SceneBackground: View {
    let scene: Scenery
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Reduce Motion: hold the sky still and drop the drifting particles.
        let live = animated && !reduceMotion
        ZStack {
            if LandscapeGPU.shared != nil {
                LandscapeView(scene: scene, animated: live)
            } else {
                // No Metal device: fall back to the sky gradient.
                LinearGradient(colors: [scene.zenith, scene.mid, scene.horizon],
                               startPoint: .top, endPoint: .bottom)
            }
            if live {
                ParticleLayer(particles: scene.particles)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Particles

/// Fresh `VortexSystem`s per view. The library's presets are shared singletons, so reusing them
/// across views would make them share state.
private enum Particles {
    typealias C = VortexSystem.Color

    static func fireflies() -> VortexSystem {
        let g = (0.84, 0.95, 0.48)
        return VortexSystem(
            tags: ["dot"], position: [0.5, 0.78], shape: .box(width: 1, height: 0.3),
            birthRate: 6, lifespan: 7, lifespanVariation: 2,
            speed: 0.03, speedVariation: 0.03, angleRange: .degrees(360),
            colors: .ramp(C(red: g.0, green: g.1, blue: g.2, opacity: 0),
                          C(red: g.0, green: g.1, blue: g.2, opacity: 1),
                          C(red: g.0, green: g.1, blue: g.2, opacity: 0.9),
                          C(red: g.0, green: g.1, blue: g.2, opacity: 0)),
            size: 0.5, sizeVariation: 0.3)
    }

    static func snow() -> VortexSystem {
        VortexSystem(
            tags: ["dot"], position: [0.5, 0], shape: .box(width: 1.2, height: 0),
            birthRate: 22, lifespan: 14, speed: 0.07, speedVariation: 0.04,
            angle: .degrees(180), angleRange: .degrees(18),
            acceleration: [0.004, 0],
            colors: .single(C(white: 0.95, opacity: 0.7)),
            size: 0.22, sizeVariation: 0.15)
    }

    static func mist() -> VortexSystem {
        VortexSystem(
            tags: ["cloud"], position: [0, 0.72], shape: .box(width: 0.05, height: 0.2),
            birthRate: 0.5, lifespan: 26, lifespanVariation: 6,
            speed: 0.035, speedVariation: 0.01, angle: .degrees(90), angleRange: .degrees(6),
            colors: .ramp(C(red: 0.62, green: 0.76, blue: 0.82, opacity: 0),
                          C(red: 0.62, green: 0.76, blue: 0.82, opacity: 0.16),
                          C(red: 0.62, green: 0.76, blue: 0.82, opacity: 0)),
            size: 2.4, sizeVariation: 0.6)
    }

    static func dust() -> VortexSystem {
        VortexSystem(
            tags: ["dot"], position: [0, 0.7], shape: .box(width: 0.05, height: 0.3),
            birthRate: 7, lifespan: 9, lifespanVariation: 3,
            speed: 0.05, speedVariation: 0.03, angle: .degrees(75), angleRange: .degrees(25),
            colors: .ramp(C(red: 1, green: 0.77, blue: 0.54, opacity: 0),
                          C(red: 1, green: 0.77, blue: 0.54, opacity: 0.55),
                          C(red: 1, green: 0.77, blue: 0.54, opacity: 0)),
            size: 0.1, sizeVariation: 0.08)
    }
}

private struct ParticleLayer: View {
    let particles: [Scenery.Particle]

    var body: some View {
        ZStack {
            ForEach(particles, id: \.self) { kind in
                switch kind {
                case .fireflies: system(Particles.fireflies(), glow: 3)
                case .snow: system(Particles.snow(), glow: 0.6)
                case .dust: system(Particles.dust(), glow: 1.5)
                case .mist:
                    VortexView(Particles.mist(), targetFrameRate: 20) {
                        Circle()
                            .fill(RadialGradient(colors: [.white, .white.opacity(0)],
                                                 center: .center, startRadius: 0, endRadius: 40))
                            .frame(width: 80, height: 80)
                            .tag("cloud")
                    }
                }
            }
        }
    }

    private func system(_ vortex: VortexSystem, glow: CGFloat) -> some View {
        VortexView(vortex, targetFrameRate: 30) {
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .blur(radius: glow)
                .blendMode(.plusLighter)
                .tag("dot")
        }
    }
}
