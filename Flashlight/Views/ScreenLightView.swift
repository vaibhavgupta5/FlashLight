import SwiftUI

/// Full-screen coloured light. The intensity slider sets display brightness.
struct ScreenLightView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            model.screenTint.color
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                GlassGroup(spacing: 14) {
                    HStack(spacing: 14) {
                        ForEach(ScreenTint.allCases) { tint in
                            Button {
                                model.screenTint = tint
                            } label: {
                                Circle()
                                    .fill(tint.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 1))
                                    .padding(8)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .liquidGlass(Circle(), interactive: true)
                            .overlay(Circle().strokeBorder(.black.opacity(model.screenTint == tint ? 0.55 : 0), lineWidth: 2))
                            .accessibilityLabel("\(tint.rawValue) light")
                            .accessibilityAddTraits(model.screenTint == tint ? .isSelected : [])
                        }
                    }
                }

                Button {
                    model.stop()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.black.opacity(0.75))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .liquidGlass(Capsule(), interactive: true)
                .padding(.bottom, 30)
            }
        }
        .statusBarHidden()
    }
}
