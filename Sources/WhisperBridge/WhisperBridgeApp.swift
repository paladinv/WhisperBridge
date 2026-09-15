import SwiftUI

@main
@MainActor
struct WhisperBridgeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 760, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Audio…") {
                    model.chooseAudio()
                }
                .keyboardShortcut("o")
                .disabled(model.isBusy)
            }
        }
    }
}
