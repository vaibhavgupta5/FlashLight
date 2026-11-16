import SwiftUI

/// Pick a torch and a scene independently.
struct StylePickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("Torch") {
                        ForEach(TorchStyle.all) { torch in
                            torchCard(torch)
                        }
                    }
                    section("Scene") {
                        ForEach(Scenery.all) { scene in
                            sceneCard(scene)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    content()
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func torchCard(_ torch: TorchStyle) -> some View {
        let selected = torch.id == model.torchID
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            model.torchID = torch.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    SceneBackground(scene: model.scenery, animated: false)
                    TorchThumbnail(style: torch)
                }
                .frame(width: 140, height: 130)
                .clipShape(shape)
                .overlay(shape.strokeBorder(selected ? torch.accent : .clear, lineWidth: 3))

                Text(torch.name)
                    .font(.subheadline.weight(.semibold))
                Text(torch.spec)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func sceneCard(_ scene: Scenery) -> some View {
        let selected = scene.id == model.sceneID
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            model.sceneID = scene.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                SceneBackground(scene: scene, animated: false)
                    .frame(width: 110, height: 150)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(selected ? Color.white : .clear, lineWidth: 3))

                Text(scene.name)
                    .font(.subheadline.weight(.semibold))
                Text(scene.mood)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(width: 110, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
