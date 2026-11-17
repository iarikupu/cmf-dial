import SwiftUI
import AppKit

/// Low-level input helpers used by the dial actions.
enum Input {
    static let src = CGEventSource(stateID: .hidSystemState)

    static func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
    }

    /// Smooth scroll: spreads `pixels` over a few frames.
    static func scroll(_ pixels: Int32) {
        let steps = 6
        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.016) {
                CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                        wheel1: pixels / Int32(steps), wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
            }
        }
    }

    static func shell(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", command]
        try? p.run()
    }
}

struct DialAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let category: String
    var isVolume = false      // native volume: the engine stops fighting the buds' own volume
    var run: () -> Void = {}
}

struct Preset: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    let up: String
    let down: String
}

enum Catalog {
    private static let cmd = CGEventFlags.maskCommand
    private static let shift = CGEventFlags.maskShift
    private static let ctrl = CGEventFlags.maskControl
    private static let arrowFlags: CGEventFlags = [.maskControl, .maskSecondaryFn]

    static let actions: [DialAction] = [
        DialAction(id: "none", title: "Do nothing", symbol: "nosign", category: "Basic"),
        DialAction(id: "shell", title: "Run a shell command…", symbol: "terminal", category: "Basic"),

        DialAction(id: "app.next", title: "Next app", symbol: "square.stack.3d.forward.dottedline", category: "Switching") { Switcher.step(forward: true) },
        DialAction(id: "app.prev", title: "Previous app", symbol: "square.stack.3d.down.backward", category: "Switching") { Switcher.step(forward: false) },
        DialAction(id: "win.next", title: "Next window", symbol: "macwindow.on.rectangle", category: "Switching") { Input.key(50, cmd) },
        DialAction(id: "win.prev", title: "Previous window", symbol: "macwindow", category: "Switching") { Input.key(50, [cmd, shift]) },
        DialAction(id: "desk.right", title: "Desktop to the right", symbol: "rectangle.righthalf.inset.filled.arrow.right", category: "Switching") { Input.key(124, arrowFlags) },
        DialAction(id: "desk.left", title: "Desktop to the left", symbol: "rectangle.lefthalf.inset.filled.arrow.left", category: "Switching") { Input.key(123, arrowFlags) },
        DialAction(id: "tab.next", title: "Next browser tab", symbol: "rectangle.stack.badge.plus", category: "Switching") { Input.key(48, ctrl) },
        DialAction(id: "tab.prev", title: "Previous browser tab", symbol: "rectangle.stack.badge.minus", category: "Switching") { Input.key(48, [ctrl, shift]) },

        DialAction(id: "media.next", title: "Next track", symbol: "forward.end.fill", category: "Media") { postMediaKey(17) },
        DialAction(id: "media.prev", title: "Previous track", symbol: "backward.end.fill", category: "Media") { postMediaKey(18) },
        DialAction(id: "media.playpause", title: "Play / pause", symbol: "playpause.fill", category: "Media") { postMediaKey(16) },
        DialAction(id: "media.mute", title: "Mute", symbol: "speaker.slash.fill", category: "Media") { postMediaKey(7) },
        DialAction(id: "vol.up", title: "Volume up (native)", symbol: "speaker.wave.3.fill", category: "Media", isVolume: true),
        DialAction(id: "vol.down", title: "Volume down (native)", symbol: "speaker.wave.1.fill", category: "Media", isVolume: true),

        DialAction(id: "scroll.down", title: "Scroll down", symbol: "arrow.down.to.line", category: "Navigation") { Input.scroll(-90) },
        DialAction(id: "scroll.up", title: "Scroll up", symbol: "arrow.up.to.line", category: "Navigation") { Input.scroll(90) },
        DialAction(id: "arrow.down", title: "Arrow down", symbol: "chevron.down", category: "Navigation") { Input.key(125) },
        DialAction(id: "arrow.up", title: "Arrow up", symbol: "chevron.up", category: "Navigation") { Input.key(126) },
        DialAction(id: "arrow.right", title: "Arrow right", symbol: "chevron.right", category: "Navigation") { Input.key(124) },
        DialAction(id: "arrow.left", title: "Arrow left", symbol: "chevron.left", category: "Navigation") { Input.key(123) },

        DialAction(id: "seek.fwd", title: "Seek forward", symbol: "goforward", category: "Video") { Input.key(124) },
        DialAction(id: "seek.back", title: "Seek back", symbol: "gobackward", category: "Video") { Input.key(123) },
        DialAction(id: "short.next", title: "Next short / reel", symbol: "chevron.down.square", category: "Video") { Input.key(125) },
        DialAction(id: "short.prev", title: "Previous short / reel", symbol: "chevron.up.square", category: "Video") { Input.key(126) },
        DialAction(id: "brush.up", title: "Brush bigger  ]", symbol: "paintbrush.pointed.fill", category: "Creative") { Input.key(30) },
        DialAction(id: "brush.down", title: "Brush smaller  [", symbol: "paintbrush.pointed", category: "Creative") { Input.key(33) },

        DialAction(id: "zoom.in", title: "Zoom in", symbol: "plus.magnifyingglass", category: "Editing") { Input.key(24, cmd) },
        DialAction(id: "zoom.out", title: "Zoom out", symbol: "minus.magnifyingglass", category: "Editing") { Input.key(27, cmd) },
        DialAction(id: "redo", title: "Redo", symbol: "arrow.uturn.forward", category: "Editing") { Input.key(6, [cmd, shift]) },
        DialAction(id: "undo", title: "Undo", symbol: "arrow.uturn.backward", category: "Editing") { Input.key(6, cmd) },

        DialAction(id: "sc.spotlight", title: "Spotlight", symbol: "magnifyingglass", category: "Shortcuts") { Input.key(49, cmd) },
        DialAction(id: "sc.mission", title: "Mission Control", symbol: "rectangle.3.group", category: "Shortcuts") { Input.shell("open -a 'Mission Control'") },
        DialAction(id: "sc.screenshot", title: "Screenshot area", symbol: "camera.viewfinder", category: "Shortcuts") { Input.key(21, [cmd, shift]) },
        DialAction(id: "sc.lock", title: "Lock screen", symbol: "lock.fill", category: "Shortcuts") { Input.key(12, [cmd, ctrl]) },
        DialAction(id: "sc.newtab", title: "New tab", symbol: "plus.square", category: "Shortcuts") { Input.key(17, cmd) },
        DialAction(id: "sc.closetab", title: "Close tab / window", symbol: "xmark.square", category: "Shortcuts") { Input.key(13, cmd) },
        DialAction(id: "sc.reopen", title: "Reopen closed tab", symbol: "arrow.uturn.backward.square", category: "Shortcuts") { Input.key(17, [cmd, shift]) },

        DialAction(id: "bright.up", title: "Brightness up", symbol: "sun.max.fill", category: "Display") { postMediaKey(2) },
        DialAction(id: "bright.down", title: "Brightness down", symbol: "sun.min.fill", category: "Display") { postMediaKey(3) },
    ]

    static let byID: [String: DialAction] = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    static let categories = ["Basic", "Switching", "Media", "Shortcuts", "Video", "Navigation", "Editing", "Creative", "Display"]

    static let presets: [Preset] = [
        Preset(id: "apps", title: "Switch Apps", symbol: "square.stack.3d.up.fill", tint: .blue, up: "app.next", down: "app.prev"),
        Preset(id: "windows", title: "Switch Windows", symbol: "macwindow.on.rectangle", tint: .indigo, up: "win.next", down: "win.prev"),
        Preset(id: "desktops", title: "Switch Desktops", symbol: "rectangle.3.group.fill", tint: .purple, up: "desk.right", down: "desk.left"),
        Preset(id: "tabs", title: "Browser Tabs", symbol: "rectangle.stack.fill", tint: .teal, up: "tab.next", down: "tab.prev"),
        Preset(id: "tracks", title: "Skip Tracks", symbol: "forward.end.fill", tint: .pink, up: "media.next", down: "media.prev"),
        Preset(id: "scroll", title: "Scroll Page", symbol: "computermouse.fill", tint: .orange, up: "scroll.down", down: "scroll.up"),
        Preset(id: "seek", title: "Seek Video", symbol: "forward.frame.fill", tint: .cyan, up: "seek.fwd", down: "seek.back"),
        Preset(id: "shorts", title: "Reels / Shorts", symbol: "play.rectangle.on.rectangle.fill", tint: .pink, up: "short.next", down: "short.prev"),
        Preset(id: "brush", title: "Brush Size", symbol: "paintbrush.pointed.fill", tint: .brown, up: "brush.up", down: "brush.down"),
        Preset(id: "zoom", title: "Zoom", symbol: "plus.magnifyingglass", tint: .mint, up: "zoom.in", down: "zoom.out"),
        Preset(id: "undo", title: "Undo / Redo", symbol: "arrow.uturn.backward.circle.fill", tint: .red, up: "redo", down: "undo"),
        Preset(id: "brightness", title: "Screen Brightness", symbol: "sun.max.fill", tint: .yellow, up: "bright.up", down: "bright.down"),
        Preset(id: "volume", title: "Volume (stock)", symbol: "speaker.wave.2.fill", tint: .green, up: "vol.up", down: "vol.down"),
        Preset(id: "custom", title: "Custom…", symbol: "slider.horizontal.3", tint: .gray, up: "none", down: "none"),
    ]
    static let presetByID: [String: Preset] = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0) })
}
