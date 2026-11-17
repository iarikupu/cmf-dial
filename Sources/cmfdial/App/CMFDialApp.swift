import SwiftUI

struct CMFDialApp: App {
    @StateObject private var engine = DialEngine()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("CMF Dial", id: "main") {
            ContentView().environmentObject(engine)
                .onAppear { engine.start() }
        }
        .defaultSize(width: 980, height: 660)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuContent().environmentObject(engine)
        } label: {
            Image(systemName: engine.settings.enabled ? "dial.medium.fill" : "dial.medium")
                .onAppear { engine.start() }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @EnvironmentObject var engine: DialEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Remapping on", isOn: $engine.settings.enabled)
        Divider()
        Button("Connect buds") { engine.reconnect() }.keyboardShortcut("r")
        Button("Play sound on buds") { engine.useAsOutput() }.keyboardShortcut("o")
        Button("Switch dial to Volume") { engine.enableDial() }.keyboardShortcut("d")
        Divider()
        ForEach(Catalog.presets.filter { $0.id != "custom" }) { p in
            Button {
                engine.settings.presetID = p.id
            } label: {
                Label(p.title + (engine.settings.presetID == p.id ? "  ✓" : ""), systemImage: p.symbol)
            }
        }
        Divider()
        Button("Open CMF Dial") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
