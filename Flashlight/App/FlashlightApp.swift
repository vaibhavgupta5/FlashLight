import SwiftUI

@main
struct FlashlightApp: App {
    @State private var model = AppModel()

    init() {
        #if DEBUG
        IconExporter.exportIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(model.torch.accent)
        }
    }
}
