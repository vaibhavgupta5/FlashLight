import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showStyle = false

    var body: some View {
        let torch = model.torch

        ZStack {
            SceneBackground(scene: model.scenery)
                .ignoresSafeArea()
            // A soft floor so the glass controls read on bright scenes.
            LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                topBar(torch)
                Spacer(minLength: 0)
                TorchStage(torch: torch)
                    .id(torch.id)
                Spacer(minLength: 0)
                statusPill
                controlPanel(torch)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            if model.isOn && model.mode == .screen {
                ScreenLightView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isOn)
        .animation(.easeInOut(duration: 0.4), value: model.sceneID)
        .animation(.easeInOut(duration: 0.3), value: model.torchID)
        .sheet(isPresented: $showStyle) {
            StylePickerView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Never leave the torch burning in the background.
            if phase == .background { model.stop() }
        }
    }

    // MARK: - Top bar

    private func topBar(_ torch: TorchStyle) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(torch.name)
                    .font(.title2.weight(.bold))
                Text(model.scenery.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 2)

            Spacer()

            Button {
                showStyle = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .liquidGlass(Circle(), interactive: true)
            .accessibilityLabel("Choose torch and scene")
        }
        .padding(.top, 6)
    }

    // MARK: - Status

    private var statusPill: some View {
        let percent = Int((model.intensity * 100).rounded())
        let text: String
        if model.isOn {
            text = "\(model.mode.title) on · \(percent)%"
        } else if !model.hasTorch && model.mode != .screen {
            text = "No LED here · the beam is a preview"
        } else {
            text = "Tap the torch to switch on"
        }
        return Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .liquidGlass(Capsule())
    }

    // MARK: - Controls

    private func controlPanel(_ torch: TorchStyle) -> some View {
        let percent = Int((model.intensity * 100).rounded())
        return GlassGroup(spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(LightMode.allCases) { mode in
                        modeButton(mode, torch: torch)
                    }
                }

                if model.mode == .strobe {
                    sliderRow(low: "tortoise.fill", high: "hare.fill",
                              value: Bindable(model).strobeHz, range: 1...15, step: 1,
                              label: "\(Int(model.strobeHz)) Hz", tint: torch.accent)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 10) {
                    powerButton(torch)
                    sliderRow(low: "sun.min.fill", high: "sun.max.fill",
                              value: Bindable(model).intensity, range: 0.05...1, step: nil,
                              label: "\(percent)%", tint: torch.accent)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.mode)
    }

    private func modeButton(_ mode: LightMode, torch: TorchStyle) -> some View {
        let selected = model.mode == mode
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            model.mode = mode
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 17, weight: .semibold))
                Text(mode.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? torch.onAccent : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .liquidGlass(shape, tint: selected ? torch.accent.opacity(0.85) : nil, interactive: true)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func powerButton(_ torch: TorchStyle) -> some View {
        Button {
            model.toggle()
        } label: {
            Image(systemName: "power")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(model.isOn ? torch.onAccent : .white)
                .frame(width: 60, height: 60)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .liquidGlass(Circle(), tint: model.isOn ? torch.accent.opacity(0.9) : nil, interactive: true)
        .accessibilityLabel(model.isOn ? "Switch off" : "Switch on")
    }

    private func sliderRow(low: String, high: String, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double?,
                           label: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: low)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            Group {
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
            }
            .tint(tint)
            Image(systemName: high)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            Text(label)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .liquidGlass(Capsule())
    }
}
