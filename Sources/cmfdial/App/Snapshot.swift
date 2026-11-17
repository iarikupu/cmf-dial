import SwiftUI
import AppKit
import CoreText

/// `cmfdial snapshot out.png [tab] [light|dark]` renders the main window with sample data, for layout checks.
@MainActor
func renderSnapshot(path: String, tab: String, scheme: String) {
    for name in ["Ndot-Regular", "LatteraMonoLL"] {
        let url = URL(fileURLWithPath: "Resources/Fonts/\(name).otf")
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    NSApplication.shared.appearance = NSAppearance(named: scheme == "light" ? .aqua : .darkAqua)
    NSAppearance.current = NSApplication.shared.appearance
    let engine = DialEngine()
    engine.preview = true
    engine.connected = true
    engine.battery = Battery(left: 85, right: 85, caseLevel: 90, leftCharging: false, rightCharging: false, caseCharging: true)
    engine.dialMode = .volume
    engine.accessibilityOK = true
    engine.volume = 0.31
    engine.outputIsBuds = true
    engine.outputName = "CMF Buds Pro 2"
    engine.settings.presetID = "apps"
    engine.settings.appearance = scheme
    engine.gestures = [
        GestureEntry(dev: 4, common: 1, type: 1, action: 2), GestureEntry(dev: 4, common: 1, type: 2, action: 9),
        GestureEntry(dev: 4, common: 1, type: 3, action: 8), GestureEntry(dev: 4, common: 1, type: 7, action: 11),
        GestureEntry(dev: 4, common: 1, type: 10, action: 23), GestureEntry(dev: 4, common: 9, type: 2, action: 3),
        GestureEntry(dev: 4, common: 9, type: 3, action: 26),
        GestureEntry(dev: 2, common: 1, type: 2, action: 9), GestureEntry(dev: 2, common: 1, type: 3, action: 8),
        GestureEntry(dev: 2, common: 1, type: 7, action: 22),
        GestureEntry(dev: 3, common: 1, type: 2, action: 9), GestureEntry(dev: 3, common: 1, type: 3, action: 8),
        GestureEntry(dev: 3, common: 1, type: 7, action: 22),
    ]
    engine.events = [
        DialEvent(up: true, title: "Next app", symbol: "square.stack.3d.forward.dottedline"),
        DialEvent(up: false, title: "Previous app", symbol: "square.stack.3d.down.backward"),
    ]
    if tab == "presses" {
        engine.settings.press = ["single": "media.mute", "double": "sc.spotlight", "triple": "shell"]
        engine.settings.pressShell = ["triple": "open -a Safari"]
        engine.tapRunning = true
        let v = PressesPanel().padding(22).frame(width: 700).background(Theme.bg).environmentObject(engine)
        let pr = ImageRenderer(content: v); pr.scale = 2
        if let img = pr.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)); print("wrote \(path)") }
        return
    }
    if tab == "panels" {
        let v = VStack(spacing: 14) { OnBudsPanel(); ReconnectPanel() }
            .padding(22).frame(width: 700).background(Theme.bg)
            .environmentObject(engine)
        let pr = ImageRenderer(content: v); pr.scale = 2
        if let img = pr.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)); print("wrote \(path)") }
        return
    }
    let view = ContentView(initialTab: Tab(rawValue: tab.uppercased()) ?? .overview)
        .environmentObject(engine)
        .frame(width: 980, height: 660)
        .environment(\.colorScheme, scheme == "light" ? .light : .dark)
    let r = ImageRenderer(content: view)
    r.scale = 2
    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    } else { print("render failed") }
}
