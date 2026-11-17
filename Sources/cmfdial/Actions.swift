import AppKit
import Foundation

struct Action: Codable {
    var type: String          // "shell" | "media" | "app_switcher" | "log"
    var command: String?      // for shell
    var key: String?          // for media
}

private let mediaKeys: [String: Int32] = [
    "volume_up": 0, "volume_down": 1, "brightness_up": 2, "brightness_down": 3,
    "mute": 7, "play_pause": 16, "next": 17, "previous": 18, "fast_forward": 19, "rewind": 20,
    "keyboard_brightness_up": 21, "keyboard_brightness_down": 22,
]

func postMediaKey(_ code: Int32) {
    for down in [true, false] {
        let flags = down ? 0xA00 : 0xB00
        let data1 = Int((Int(code) << 16) | flags)
        let cg = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
            timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1
        )?.cgEvent
        cg?.setIntegerValueField(.eventSourceUserData, value: MediaKeyTap.marker)   // our own: the tap must not re-handle it
        cg?.post(tap: .cghidEventTap)
    }
}

/// Native Cmd+Tab switcher: holds Cmd, taps Tab (or Shift+Tab) per dial tick, and lets go of Cmd
/// once the dial has been idle, which commits the selection — same as Cmd+Tab on the keyboard.
enum Switcher {
    private static var active = false
    private static var timer: Timer?
    private static var sources: [DispatchSourceSignal] = []
    private static let src = CGEventSource(stateID: .hidSystemState)

    private static func post(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) {
        let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
        e?.flags = flags
        e?.post(tap: .cghidEventTap)
    }

    static func step(forward: Bool) {
        if !active {
            active = true
            installSignalHandlers()
            post(55, down: true, flags: .maskCommand)          // Command down
        }
        let flags: CGEventFlags = forward ? .maskCommand : [.maskCommand, .maskShift]
        post(48, down: true, flags: flags)                      // Tab
        post(48, down: false, flags: flags)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in release() }
    }

    static func release() {
        guard active else { return }
        active = false
        timer?.invalidate()
        post(55, down: false, flags: [])                        // Command up
    }

    private static func installSignalHandlers() {
        guard sources.isEmpty else { return }
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            s.setEventHandler { release(); exit(0) }
            s.resume()
            sources.append(s)
        }
    }
}

func perform(_ action: Action, label: String) {
    switch action.type {
    case "app_switcher":
        let forward = action.key != "prev"
        log("\(label) -> app switcher \(forward ? "forward" : "back")")
        Switcher.step(forward: forward)
    case "shell":
        guard let cmd = action.command else { return }
        log("\(label) -> shell: \(cmd)")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", cmd]
        try? p.run()
    case "media":
        guard let k = action.key, let code = mediaKeys[k] else {
            log("Unknown media key \(action.key ?? "nil"); valid: \(mediaKeys.keys.sorted().joined(separator: ", "))")
            return
        }
        log("\(label) -> media key: \(k)")
        postMediaKey(code)
    default:
        log("\(label) (no action)")
    }
}
