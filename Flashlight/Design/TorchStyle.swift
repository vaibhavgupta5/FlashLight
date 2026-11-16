import SwiftUI

/// Something that gives light. Each kind has its own 3D model (see `ModelFactory`).
struct TorchStyle: Identifiable {
    enum Kind { case tin, tactical, penlight, workLight, lantern, bulb, candle, ring, table }

    let id: String
    let name: String
    let spec: String
    let kind: Kind
    let beam: Color        // colour of the light it casts
    let accent: Color      // UI tint while this lamp is selected
    let onAccent: Color

    static let tin = TorchStyle(
        id: "tin", name: "Tin Beacon", spec: "1950s · painted steel", kind: .tin,
        beam: Color(hex: 0xFFE2A0), accent: Color(hex: 0xE0654F), onAccent: .white)

    static let tactical = TorchStyle(
        id: "tactical", name: "Ranger", spec: "Anodised · knurled grip", kind: .tactical,
        beam: Color(hex: 0xF0F5FF), accent: Color(hex: 0xFF7A2F), onAccent: .white)

    static let penlight = TorchStyle(
        id: "penlight", name: "Pen Steel", spec: "Aluminium · 60 lm", kind: .penlight,
        beam: Color(hex: 0xF4F8FF), accent: Color(hex: 0x5B8CFF), onAccent: .white)

    static let workLight = TorchStyle(
        id: "workLight", name: "Site Light", spec: "Rubber · IP67", kind: .workLight,
        beam: Color(hex: 0xFFFBE0), accent: Color(hex: 0xFFD60A), onAccent: Color(hex: 0x121212))

    static let lantern = TorchStyle(
        id: "lantern", name: "Harbor Lantern", spec: "Brass · hurricane", kind: .lantern,
        beam: Color(hex: 0xFFC978), accent: Color(hex: 0xF2C46D), onAccent: Color(hex: 0x2A1D0E))

    static let bulb = TorchStyle(
        id: "bulb", name: "Filament Bulb", spec: "E27 · 2200 K LED", kind: .bulb,
        beam: Color(hex: 0xFFC67A), accent: Color(hex: 0xFFB54A), onAccent: Color(hex: 0x2A1A06))

    static let candle = TorchStyle(
        id: "candle", name: "Taper Candle", spec: "Beeswax · brass holder", kind: .candle,
        beam: Color(hex: 0xFFB45E), accent: Color(hex: 0xFFB066), onAccent: Color(hex: 0x2A1606))

    static let ring = TorchStyle(
        id: "ring", name: "Ring Light", spec: "Studio · 3 colour temps", kind: .ring,
        beam: Color(hex: 0xF2F8FF), accent: Color(hex: 0x7FD6FF), onAccent: Color(hex: 0x06202A))

    static let table = TorchStyle(
        id: "table", name: "Table Lamp", spec: "Ceramic · linen shade", kind: .table,
        beam: Color(hex: 0xFFD79A), accent: Color(hex: 0xF0C987), onAccent: Color(hex: 0x2A1D0E))

    static let all: [TorchStyle] = [.tin, .tactical, .penlight, .workLight, .lantern, .bulb, .candle, .ring, .table]
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}
