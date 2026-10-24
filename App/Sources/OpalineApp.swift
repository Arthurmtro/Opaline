import SwiftUI

@main
struct OpalineApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Opaline") {
            RootView()
                .environment(model)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Theme…") { model.isImporting = true }
                    .keyboardShortcut("o")
                Button("Paste Theme") { model.pasteTheme() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Divider()
                Button("Export Theme…") { model.exporting = model.selectedTheme }
                    .keyboardShortcut("e")
                    .disabled(model.selectedTheme == nil)
                Button("Copy Theme JSON") {
                    if let theme = model.selectedTheme { model.copyJSON(of: theme) }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(model.selectedTheme == nil)
            }
        }
    }
}
