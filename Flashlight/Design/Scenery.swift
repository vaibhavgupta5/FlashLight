import SwiftUI
import UIKit

/// A procedural landscape. `shaderParams` packs everything for `Landscape.metal`.
///
/// Float layout (must match the shader):
///  0 stars · 1 aurora · 2 clouds · 3 fog
///  4–7 celestial x, y, radius, kind (0 none, 1 moon, 2 sun)
///  8 water horizon (0 = no water) · 9–11 reserved
///  12–14 zenith · 15–17 mid · 18–20 horizon · 21–23 celestial colour · 24–26 fog colour
///  27 + 7k: layer k → kind, baseline, amplitude, seed, r, g, b   (k = 0…3, far → near)
struct Scenery: Identifiable {
    enum Kind: Float { case none = 0, rock, snow, pines, dunes, hills, grass }
    enum Celestial: Float { case none = 0, moon, sun }
    enum Particle: Hashable { case fireflies, snow, mist, dust }

    struct Layer {
        let kind: Kind
        let baseline: Float
        let amplitude: Float
        let seed: Float
        let color: Color
    }

    let id: String
    let name: String
    let mood: String
    let zenith: Color
    let mid: Color
    let horizon: Color
    let fogColor: Color
    let stars: Float
    let aurora: Float
    let clouds: Float
    let fog: Float
    let celestial: Celestial
    let celestialX: Float
    let celestialY: Float
    let celestialRadius: Float
    let celestialColor: Color
    let waterHorizon: Float
    let layers: [Layer]
    let particles: [Particle]

    var shaderParams: [Float] {
        var p = [Float](repeating: 0, count: 55)
        p[0] = stars; p[1] = aurora; p[2] = clouds; p[3] = fog
        p[4] = celestialX; p[5] = celestialY; p[6] = celestialRadius; p[7] = celestial.rawValue
        p[8] = waterHorizon
        func put(_ color: Color, at index: Int) {
            let (r, g, b) = color.rgb
            p[index] = r; p[index + 1] = g; p[index + 2] = b
        }
        put(zenith, at: 12); put(mid, at: 15); put(horizon, at: 18)
        put(celestialColor, at: 21); put(fogColor, at: 24)
        for (k, layer) in layers.prefix(4).enumerated() {
            let o = 27 + k * 7
            p[o] = layer.kind.rawValue
            p[o + 1] = layer.baseline
            p[o + 2] = layer.amplitude
            p[o + 3] = layer.seed
            put(layer.color, at: o + 4)
        }
        return p
    }

    static let forest = Scenery(
        id: "forest", name: "Pine Night", mood: "Moonlit forest, mist and fireflies",
        zenith: Color(hex: 0x040A12), mid: Color(hex: 0x0B1D2B), horizon: Color(hex: 0x2B4A55),
        fogColor: Color(hex: 0x3A5C66),
        stars: 0.9, aurora: 0, clouds: 0.35, fog: 0.6,
        celestial: .moon, celestialX: 0.24, celestialY: 0.2, celestialRadius: 0.05,
        celestialColor: Color(hex: 0xF2EBD3), waterHorizon: 0,
        layers: [
            Layer(kind: .rock, baseline: 0.62, amplitude: 0.2, seed: 3, color: Color(hex: 0x1A3140)),
            Layer(kind: .pines, baseline: 0.76, amplitude: 0.11, seed: 11, color: Color(hex: 0x102530)),
            Layer(kind: .pines, baseline: 0.88, amplitude: 0.15, seed: 23, color: Color(hex: 0x08151C)),
            Layer(kind: .pines, baseline: 0.99, amplitude: 0.2, seed: 37, color: Color(hex: 0x030A0E)),
        ],
        particles: [.mist, .fireflies])

    static let desert = Scenery(
        id: "desert", name: "Desert Dusk", mood: "Warm dunes at sundown",
        zenith: Color(hex: 0x1A2038), mid: Color(hex: 0x6A3A44), horizon: Color(hex: 0xF0A064),
        fogColor: Color(hex: 0xE8905C),
        stars: 0.25, aurora: 0, clouds: 0.3, fog: 0.35,
        celestial: .sun, celestialX: 0.3, celestialY: 0.62, celestialRadius: 0.045,
        celestialColor: Color(hex: 0xFFD08A), waterHorizon: 0,
        layers: [
            Layer(kind: .dunes, baseline: 0.66, amplitude: 0.07, seed: 5, color: Color(hex: 0x8E4E33)),
            Layer(kind: .dunes, baseline: 0.76, amplitude: 0.09, seed: 9, color: Color(hex: 0x6A3220)),
            Layer(kind: .dunes, baseline: 0.87, amplitude: 0.1, seed: 13, color: Color(hex: 0x45200F)),
            Layer(kind: .dunes, baseline: 0.98, amplitude: 0.09, seed: 17, color: Color(hex: 0x261008)),
        ],
        particles: [.dust])

    static let ocean = Scenery(
        id: "ocean", name: "Moon Tide", mood: "Coast at moonrise",
        zenith: Color(hex: 0x03080F), mid: Color(hex: 0x0A1F2E), horizon: Color(hex: 0x1F4A5A),
        fogColor: Color(hex: 0x2A5666),
        stars: 0.85, aurora: 0, clouds: 0.4, fog: 0.5,
        celestial: .moon, celestialX: 0.52, celestialY: 0.26, celestialRadius: 0.045,
        celestialColor: Color(hex: 0xF3F0E2), waterHorizon: 0.56,
        layers: [
            Layer(kind: .hills, baseline: 0.555, amplitude: 0.03, seed: 4, color: Color(hex: 0x0A1A24)),
            Layer(kind: .none, baseline: 0, amplitude: 0, seed: 0, color: .black),
            Layer(kind: .none, baseline: 0, amplitude: 0, seed: 0, color: .black),
            Layer(kind: .rock, baseline: 0.98, amplitude: 0.13, seed: 31, color: Color(hex: 0x02070B)),
        ],
        particles: [.mist])

    static let aurora = Scenery(
        id: "aurora", name: "Aurora Tundra", mood: "Northern lights over snow",
        zenith: Color(hex: 0x01050B), mid: Color(hex: 0x04141F), horizon: Color(hex: 0x0D2A33),
        fogColor: Color(hex: 0x1C4A52),
        stars: 1.0, aurora: 0.9, clouds: 0, fog: 0.4,
        celestial: .none, celestialX: 0.5, celestialY: 0.12, celestialRadius: 0.04,
        celestialColor: Color(hex: 0x5FE8B0), waterHorizon: 0,
        layers: [
            Layer(kind: .snow, baseline: 0.64, amplitude: 0.22, seed: 17, color: Color(hex: 0x1F3647)),
            Layer(kind: .hills, baseline: 0.82, amplitude: 0.05, seed: 19, color: Color(hex: 0x10202A)),
            Layer(kind: .pines, baseline: 0.94, amplitude: 0.1, seed: 29, color: Color(hex: 0x070E14)),
            Layer(kind: .none, baseline: 0, amplitude: 0, seed: 0, color: .black),
        ],
        particles: [.snow])

    static let alpine = Scenery(
        id: "alpine", name: "Alpine Dawn", mood: "First light on the peaks",
        zenith: Color(hex: 0x1A2A4A), mid: Color(hex: 0x6B7FA8), horizon: Color(hex: 0xF3C9A0),
        fogColor: Color(hex: 0xD9B4A4),
        stars: 0.15, aurora: 0, clouds: 0.5, fog: 0.42,
        celestial: .sun, celestialX: 0.7, celestialY: 0.58, celestialRadius: 0.04,
        celestialColor: Color(hex: 0xFFE2B0), waterHorizon: 0,
        layers: [
            Layer(kind: .snow, baseline: 0.56, amplitude: 0.24, seed: 2, color: Color(hex: 0x4A5C82)),
            Layer(kind: .snow, baseline: 0.68, amplitude: 0.22, seed: 14, color: Color(hex: 0x2A3858)),
            Layer(kind: .pines, baseline: 0.85, amplitude: 0.1, seed: 21, color: Color(hex: 0x18202F)),
            Layer(kind: .pines, baseline: 0.99, amplitude: 0.14, seed: 27, color: Color(hex: 0x0A0F18)),
        ],
        particles: [.mist])

    static let meadow = Scenery(
        id: "meadow", name: "Firefly Meadow", mood: "Summer night in the grass",
        zenith: Color(hex: 0x030A08), mid: Color(hex: 0x0A1D15), horizon: Color(hex: 0x1E3A2D),
        fogColor: Color(hex: 0x2F5240),
        stars: 0.8, aurora: 0, clouds: 0.2, fog: 0.35,
        celestial: .moon, celestialX: 0.22, celestialY: 0.2, celestialRadius: 0.045,
        celestialColor: Color(hex: 0xEEF2D8), waterHorizon: 0,
        layers: [
            Layer(kind: .hills, baseline: 0.62, amplitude: 0.07, seed: 33, color: Color(hex: 0x11271D)),
            Layer(kind: .hills, baseline: 0.72, amplitude: 0.06, seed: 37, color: Color(hex: 0x0C1D15)),
            Layer(kind: .grass, baseline: 0.84, amplitude: 0.07, seed: 41, color: Color(hex: 0x07130D)),
            Layer(kind: .grass, baseline: 0.98, amplitude: 0.12, seed: 43, color: Color(hex: 0x030906)),
        ],
        particles: [.fireflies])

    static let all: [Scenery] = [.forest, .desert, .ocean, .aurora, .alpine, .meadow]
}

extension Color {
    /// sRGB components, for packing into shader parameters.
    var rgb: (Float, Float, Float) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
    }
}
