import SwiftUI

/// The hero. A 3D lamp with its light cast into the scene. Tap to switch.
struct TorchStage: View {
    @Environment(AppModel.self) private var model
    let torch: TorchStyle
    @State private var rig: Rig
    @State private var geometry = StageGeometry()

    init(torch: TorchStyle) {
        self.torch = torch
        _rig = State(initialValue: ModelFactory.make(torch))
    }

    private var percent: Int { Int((model.intensity * 100).rounded()) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LightLayer(rig: rig, beam: torch.beam, level: model.lampLevel,
                           intensity: model.intensity, geometry: geometry)
                    .frame(width: geo.size.width + 2 * LightLayer.pad, height: geo.size.height + 2 * LightLayer.pad)
                    .allowsHitTesting(false)

                LampSceneView(rig: rig, level: model.lampLevel, geometry: $geometry)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 360)
        .contentShape(Rectangle())
        .onTapGesture { model.toggle() }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.isOn)
        .animation(.easeOut(duration: 0.08), value: model.lampLevel)
        .accessibilityElement()
        .accessibilityLabel(torch.name)
        .accessibilityValue(model.isOn ? "On, \(percent) percent" : "Off")
        .accessibilityHint("Double tap to switch. Swipe up or down to change intensity.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.intensity = min(1, model.intensity + 0.1)
            case .decrement: model.intensity = max(0.05, model.intensity - 0.1)
            @unknown default: break
            }
        }
    }
}

/// Additive light drawn behind the model: a cone for torches, a halo for lamps and flames.
struct LightLayer: View {
    static let pad: CGFloat = 500

    let rig: Rig
    let beam: Color
    let level: Double
    let intensity: Double
    let geometry: StageGeometry

    var body: some View {
        Canvas { context, _ in
            guard level > 0.001 else { return }
            var ctx = context
            ctx.translateBy(x: Self.pad, y: Self.pad)
            ctx.blendMode = .plusLighter
            let a = geometry.anchor
            let u = geometry.unit
            let strength = 0.3 + 0.7 * level

            switch rig.emission {
            case .beam:
                var c = ctx
                c.translateBy(x: a.x, y: a.y)
                c.rotate(by: .radians(geometry.angle))
                let start = rig.lensRadius * u * 0.9
                let length: CGFloat = 540
                let spread = start + (60 + 120 * intensity)
                for (alpha, widen) in [(0.07, 1.6), (0.17, 1.28), (0.42, 1.0)] {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: -start))
                    path.addLine(to: CGPoint(x: length, y: -spread * widen))
                    path.addLine(to: CGPoint(x: length, y: spread * widen))
                    path.addLine(to: CGPoint(x: 0, y: start))
                    path.closeSubpath()
                    c.fill(path, with: .linearGradient(
                        Gradient(stops: [
                            .init(color: beam.opacity(0.9 * alpha * strength), location: 0),
                            .init(color: beam.opacity(0.35 * alpha * strength), location: 0.45),
                            .init(color: beam.opacity(0), location: 1),
                        ]),
                        startPoint: .zero, endPoint: CGPoint(x: length, y: 0)))
                }
                // Bloom at the lens.
                let bloom = start * 2.4
                c.fill(Path(ellipseIn: CGRect(x: -bloom, y: -bloom, width: bloom * 2, height: bloom * 2)),
                       with: .radialGradient(Gradient(colors: [beam.opacity(0.8 * strength), beam.opacity(0)]),
                                             center: .zero, startRadius: 0, endRadius: bloom))

            case .glow:
                let radius = 110 + 170 * intensity
                for (r, alpha) in [(radius * 1.6, 0.16), (radius, 0.42), (radius * 0.35, rig.glowCore)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [beam.opacity(alpha * strength), beam.opacity(0)]),
                                                   center: a, startRadius: 0, endRadius: r))
                }

            case .ring:
                // secondary[0] = right edge of the ring, secondary[1] = top edge.
                guard geometry.secondary.count >= 2 else { return }
                let rx = abs(geometry.secondary[0].x - a.x)
                let ry = abs(geometry.secondary[1].y - a.y)
                let wash = (rx + ry) * 1.6
                ctx.fill(Path(ellipseIn: CGRect(x: a.x - wash, y: a.y - wash, width: wash * 2, height: wash * 2)),
                         with: .radialGradient(Gradient(colors: [beam.opacity(0.5 * strength), beam.opacity(0)]),
                                               center: a, startRadius: 0, endRadius: wash))
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 16))
                    layer.stroke(Path(ellipseIn: CGRect(x: a.x - rx, y: a.y - ry, width: rx * 2, height: ry * 2)),
                                 with: .color(beam.opacity(0.85 * strength)), lineWidth: 26)
                }

            case .shade:
                // secondary[0] = top of the shade, secondary[1] = bottom of the shade.
                guard geometry.secondary.count >= 2 else { return }
                let top = geometry.secondary[0]
                let bottom = geometry.secondary[1]
                let topW = rig.lensRadius * u * 0.62
                let botW = rig.lensRadius * u
                let radius = 140 + 150 * intensity
                ctx.fill(Path(ellipseIn: CGRect(x: a.x - radius, y: a.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [beam.opacity(0.55 * strength), beam.opacity(0)]),
                                               center: a, startRadius: 0, endRadius: radius))
                var up = Path()
                up.move(to: CGPoint(x: top.x - topW, y: top.y))
                up.addLine(to: CGPoint(x: top.x - topW - 90, y: top.y - 230))
                up.addLine(to: CGPoint(x: top.x + topW + 90, y: top.y - 230))
                up.addLine(to: CGPoint(x: top.x + topW, y: top.y))
                ctx.fill(up, with: .linearGradient(
                    Gradient(stops: [.init(color: beam.opacity(0.24 * strength), location: 0),
                                     .init(color: beam.opacity(0.08 * strength), location: 0.5),
                                     .init(color: beam.opacity(0), location: 1)]),
                    startPoint: top, endPoint: CGPoint(x: top.x, y: top.y - 230)))
                var down = Path()
                down.move(to: CGPoint(x: bottom.x - botW, y: bottom.y))
                down.addLine(to: CGPoint(x: bottom.x - botW - 120, y: bottom.y + 280))
                down.addLine(to: CGPoint(x: bottom.x + botW + 120, y: bottom.y + 280))
                down.addLine(to: CGPoint(x: bottom.x + botW, y: bottom.y))
                ctx.fill(down, with: .linearGradient(
                    Gradient(stops: [.init(color: beam.opacity(0.3 * strength), location: 0),
                                     .init(color: beam.opacity(0.1 * strength), location: 0.5),
                                     .init(color: beam.opacity(0), location: 1)]),
                    startPoint: bottom, endPoint: CGPoint(x: bottom.x, y: bottom.y + 280)))
            }
        }
    }
}

/// Lit preview of a lamp for the style picker: a cached snapshot, not a live 3D view.
struct TorchThumbnail: View {
    let style: TorchStyle

    var body: some View {
        if let image = ThumbnailCache.image(for: style) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }
}
