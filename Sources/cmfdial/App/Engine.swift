import SwiftUI
import IOBluetooth
import ApplicationServices

struct DialSettings: Codable, Equatable {
    var presetID = "apps"
    var customUp = "app.next"
    var customDown = "app.prev"
    var shellUp = ""
    var shellDown = ""
    var reversed = false
    var enabled = true
    var caseColour = "orange"
    var autoOutput = false     // when the buds reconnect: make them the Mac's audio output
    var autoDial = false       // when the buds reconnect: make sure dial rotation = Volume
    var appearance = "system"  // system | light | dark
    var press: [String: String] = [:]       // "single" | "double" | "triple" -> action id (absent = leave as is)
    var pressShell: [String: String] = [:]
    var pressBluetoothOnly = true           // ignore media keys that come from a keyboard
}

struct GestureEntry: Identifiable, Equatable {
    let dev: UInt8, common: UInt8, type: UInt8
    var action: UInt8
    var id: String { "\(dev)-\(common)-\(type)" }
}

struct DialEvent: Identifiable, Equatable {
    let id = UUID()
    let date = Date()
    let up: Bool
    let title: String
    let symbol: String
    var press: String? = nil        // "Single press" etc. when this was a dial click, not a turn
}

struct Battery: Equatable {
    var left: Int?, right: Int?, caseLevel: Int?
    var leftCharging = false, rightCharging = false, caseCharging = false
}

enum DialMode { case unknown, volume, off }

private struct Bound {
    let action: DialAction
    let shell: String
}

final class DialEngine: ObservableObject {
    @Published var settings: DialSettings { didSet { save() } }
    @Published var connected = false
    @Published var deviceName = "CMF Buds Pro 2"
    @Published var battery = Battery()
    @Published var dialMode: DialMode = .unknown
    @Published var accessibilityOK = AXIsProcessTrusted()
    @Published var events: [DialEvent] = []
    @Published var lastEvent: DialEvent?
    @Published var angle = 0.0
    @Published var pulse = 0
    @Published var changingDial = false
    @Published var volume: Float?
    @Published var gestures: [GestureEntry] = []
    @Published var notice: String?
    @Published var pressPulse = 0
    @Published var tapRunning = false
    @Published var ghost: Float?     // raw volume the dial just reported (shown briefly while remapped)
    @Published var outputName = "—"
    @Published var outputIsBuds = false

    private var started = false
    private var watcher: VolumeWatcher?
    private var link: RFCOMMLink?
    private var device: IOBluetoothDevice?
    private var anchor: Float?
    private var ignoreUntil = Date.distantPast
    private var lastOutput: AudioDeviceID = 0
    private var opId: UInt8 = 10
    private let mediaTap = MediaKeyTap()

    private static let key = "dialSettings.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: Self.key),
           let s = try? JSONDecoder().decode(DialSettings.self, from: d) {
            settings = s
        } else {
            settings = DialSettings()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            Switcher.release()
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(d, forKey: Self.key) }
    }

    // MARK: Derived

    var preset: Preset { Catalog.presetByID[settings.presetID] ?? Catalog.presets[0] }

    private func resolved() -> (up: Bound, down: Bound) {
        var upID = preset.up, downID = preset.down
        var upShell = "", downShell = ""
        if preset.id == "custom" {
            upID = settings.customUp; downID = settings.customDown
            upShell = settings.shellUp; downShell = settings.shellDown
        }
        if settings.reversed { swap(&upID, &downID); swap(&upShell, &downShell) }
        let none = Catalog.byID["none"]!
        return (Bound(action: Catalog.byID[upID] ?? none, shell: upShell),
                Bound(action: Catalog.byID[downID] ?? none, shell: downShell))
    }

    var upTitle: String { title(of: resolved().up) }
    var downTitle: String { title(of: resolved().down) }
    private func title(of b: Bound) -> String {
        b.action.id == "shell" ? (b.shell.isEmpty ? "Shell command" : b.shell) : b.action.title
    }
    var upSymbol: String { resolved().up.action.symbol }
    var downSymbol: String { resolved().down.action.symbol }

    // MARK: Lifecycle

    func start() {
        guard !started else { return }
        started = true
        openAppLog()
        log("Accessibility trusted: \(AXIsProcessTrusted())")
        if !AXIsProcessTrusted() {
            // Shows the system prompt and adds "CMF Dial" to Privacy & Security > Accessibility.
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        }
        device = findDevice(address: nil)
        if let n = device?.name { deviceName = n }

        watcher = VolumeWatcher { [weak self] id, v in self?.volumeChanged(id, v) }
        mediaTap.handler = { [weak self] key, down, pid in self?.mediaKey(key, down: down, pid: pid) ?? false }
        startTapIfPossible()

        if let dev = device {
            link = RFCOMMLink(device: dev) { [weak self] _, bytes in self?.received(bytes) }
            link?.onOpen = { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self?.send(NT.getGesture)
                    self?.send(NT.getBattery)
                }
            }
        }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }.fire()
    }

    private func poll() {
        let ax = AXIsProcessTrusted()
        if ax != accessibilityOK { log("Accessibility trusted: \(ax)") }
        accessibilityOK = ax
        if ax { startTapIfPossible() }
        let nowConnected = device?.isConnected() ?? false
        if nowConnected != connected {
            log("Buds connected: \(nowConnected)")
            withAnimation(.smooth) { connected = nowConnected }
            if !nowConnected {
                withAnimation(.smooth) { battery = Battery(); dialMode = .unknown; gestures = [] }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.runReconnectAutomations() }
            }
        }
        if nowConnected { link?.open(NT.channel) }

        let out = Audio.defaultOutput()
        let nm = Audio.name(out), isBuds = isTarget(out)
        if nm != outputName { outputName = nm }
        if isBuds != outputIsBuds { withAnimation(.smooth) { outputIsBuds = isBuds } }
        if out != lastOutput {
            lastOutput = out
            anchor = isTarget(out) ? Audio.getVolume(out) : nil
            if let a = anchor { showVolume(a) } else { volume = nil }
        }
    }

    private func isTarget(_ id: AudioDeviceID) -> Bool {
        let addr = device?.addressString?.uppercased().replacingOccurrences(of: ":", with: "-")
        if let a = addr, !a.isEmpty, Audio.uid(id).uppercased().contains(a) { return true }
        return Audio.name(id).localizedCaseInsensitiveContains("CMF")
    }

    // MARK: Dial ticks

    private func volumeChanged(_ id: AudioDeviceID, _ v: Float) {
        guard isTarget(id) else { if anchor != nil { log("volume event on non-buds device \(Audio.name(id)); ignoring") }; anchor = nil; return }
        if Date() < ignoreUntil { return }
        guard let a = anchor else { anchor = v; showVolume(v); return }
        if abs(v - a) < 0.001 { return }
        let up = v > a
        let r = resolved()
        log("tick \(up ? "UP" : "DOWN") v=\(v) anchor=\(a) up=\(r.up.action.id) down=\(r.down.action.id) enabled=\(settings.enabled) preset=\(settings.presetID)")
        let native = !settings.enabled || r.up.action.isVolume || r.down.action.isVolume
        if native {
            anchor = v
            showVolume(v)
            if settings.enabled { record(up: up, bound: up ? r.up : r.down) }
            return
        }
        let bound = up ? r.up : r.down
        record(up: up, bound: bound)
        showGhost(v)
        if bound.action.id == "shell" { Input.shell(bound.shell) } else { bound.action.run() }
        ignoreUntil = Date().addingTimeInterval(0.2)
        Audio.setVolume(id, a)
    }

    private func showGhost(_ v: Float) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { ghost = v }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self = self, self.ghost == v else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.ghost = nil }
        }
    }

    private func showVolume(_ v: Float) {
        if volume.map({ abs($0 - v) > 0.002 }) ?? true { withAnimation(.smooth(duration: 0.25)) { volume = v } }
    }

    func trigger(up: Bool) {   // preview buttons in the UI
        let r = resolved()
        let bound = up ? r.up : r.down
        record(up: up, bound: bound)
        if bound.action.isVolume { return }
        if bound.action.id == "shell" { Input.shell(bound.shell) } else { bound.action.run() }
    }

    private func record(up: Bool, bound: Bound) {
        let e = DialEvent(up: up, title: title(of: bound), symbol: bound.action.symbol)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            lastEvent = e
            events.insert(e, at: 0)
            if events.count > 6 { events.removeLast() }
            angle += up ? 18 : -18
            pulse += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self, self.lastEvent?.id == e.id else { return }
            withAnimation(.easeOut(duration: 0.35)) { self.lastEvent = nil }
        }
    }

    // MARK: Buds protocol

    private func send(_ cmd: UInt16, payload: [UInt8] = []) {
        opId = opId &+ 1
        link?.send(NT.channel, NT.frame(cmd: cmd, payload: payload, op: opId))
    }

    private func received(_ bytes: [UInt8]) {
        for f in NT.splitFrames(bytes) {
            switch NT.command(f) {
            case NT.batteryNotify, NT.batteryReply:
                let b = NT.decodeBattery(f)
                withAnimation(.smooth) {
                    if let l = b[2] { battery.left = l.level; battery.leftCharging = l.charging }
                    if let r = b[3] { battery.right = r.level; battery.rightCharging = r.charging }
                    if let c = b[4] { battery.caseLevel = c.level; battery.caseCharging = c.charging }
                }
            case NT.gestureReply:
                log("gesture table received (\(NT.decodeGestures(f).count) entries)")
                let all = NT.decodeGestures(f)
                withAnimation(.smooth) {
                    gestures = all.map { GestureEntry(dev: $0.dev, common: $0.common, type: $0.type, action: $0.action) }
                    if let g = all.first(where: { $0.dev == NT.dialDevice && $0.type == 10 }) {
                        dialMode = g.action == 23 ? .volume : .off
                    }
                }
            default: break
            }
        }
    }

    /// Same write Nothing X makes for "Smart Dial → Rotate".
    func setDialRotation(volume: Bool) {
        changingDial = true
        send(NT.setGesture, payload: [0x01, NT.dialDevice, 0x01, 0x0a, volume ? 0x17 : 0x01])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.send(NT.getGesture)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.changingDial = false }
        }
    }

    // MARK: Reconnect helpers

    func flash(_ text: String) {
        withAnimation(.smooth) { notice = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard self?.notice == text else { return }
            withAnimation(.smooth) { self?.notice = nil }
        }
    }

    /// Ask macOS to connect the paired buds.
    func reconnect() {
        guard let dev = device ?? findDevice(address: nil) else { flash("No paired CMF buds found"); return }
        device = dev
        if dev.isConnected() { flash("Already connected"); return }
        flash("Connecting…")
        DispatchQueue.global().async {
            let r = dev.openConnection()
            DispatchQueue.main.async { [weak self] in
                self?.flash(r == kIOReturnSuccess ? "Connection requested" : "Open the case lid, then try again")
            }
        }
    }

    /// Make the buds the Mac's sound output.
    func useAsOutput() {
        let addr = device?.addressString?.uppercased().replacingOccurrences(of: ":", with: "-") ?? ""
        let candidates = Audio.allDevices().filter { Audio.hasOutput($0) }
        let target = candidates.first { !addr.isEmpty && Audio.uid($0).uppercased().contains(addr) }
            ?? candidates.first { Audio.name($0).localizedCaseInsensitiveContains("CMF") }
        guard let t = target else { flash("Buds aren't available as an output yet"); return }
        flash(Audio.setDefaultOutput(t) ? "Sound now plays on your buds" : "Couldn't switch output")
    }

    func enableDial() {
        guard connected else { flash("Connect the buds first"); return }
        setDialRotation(volume: true)
        flash("Dial set to Volume")
    }

    func refresh() {
        guard connected else { flash("Connect the buds first"); return }
        send(NT.getGesture); send(NT.getBattery)
        flash("Refreshed")
    }

    private func runReconnectAutomations() {
        guard connected else { return }
        if settings.autoOutput { useAsOutput() }
        if settings.autoDial, dialMode == .off { setDialRotation(volume: true) }
    }

    // MARK: Dial presses (media keys)

    private func startTapIfPossible() {
        guard !mediaTap.isRunning, AXIsProcessTrusted() else { return }
        let ok = mediaTap.start()
        log("Media-key tap \(ok ? "started" : "FAILED (needs Accessibility / Input Monitoring)")")
        tapRunning = ok
    }

    static let pressTypes: [(key: String, title: String, buttonType: UInt8, budsAction: UInt8, mediaKey: Int)] = [
        ("single", "Single press", 1, 2, 16),    // buds send Play/Pause
        ("double", "Double press", 2, 9, 17),    // buds send Next
        ("triple", "Triple press", 3, 8, 18),    // buds send Previous
    ]

    /// Returns true to swallow the media key.
    private func mediaKey(_ key: Int, down: Bool, pid: Int64) -> Bool {
        log("media key \(key) \(down ? "down" : "up") pid=\(pid)")
        guard let p = Self.pressTypes.first(where: { $0.mediaKey == key }),
              let id = settings.press[p.key], id != "leave", settings.enabled else { return false }
        if settings.pressBluetoothOnly && pid == 0 { return false }      // real keyboard key
        if down {
            DispatchQueue.main.async { [weak self] in self?.firePress(p.key, title: p.title, actionID: id) }
        }
        return true
    }

    private func firePress(_ type: String, title: String, actionID: String) {
        guard let a = Catalog.byID[actionID] else { return }
        let shell = settings.pressShell[type] ?? ""
        let name = actionID == "shell" ? (shell.isEmpty ? "Shell command" : shell) : a.title
        log("press \(type) -> \(name)")
        let e = DialEvent(up: true, title: name, symbol: a.symbol, press: title)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            lastEvent = e
            events.insert(e, at: 0)
            if events.count > 6 { events.removeLast() }
            pressPulse += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self, self.lastEvent?.id == e.id else { return }
            withAnimation(.easeOut(duration: 0.35)) { self.lastEvent = nil }
        }
        if actionID == "shell" { Input.shell(shell) } else { a.run() }
    }

    /// Choose what a dial click does on the Mac. The buds are switched to the matching media action so the click arrives as a media key.
    func setPress(_ type: String, to id: String) {
        withAnimation(.smooth) {
            if id == "leave" { settings.press[type] = nil } else { settings.press[type] = id }
        }
        guard id != "leave", let p = Self.pressTypes.first(where: { $0.key == type }) else { return }
        if let e = gestures.first(where: { $0.dev == NT.dialDevice && $0.common == 1 && $0.type == p.buttonType }) {
            if e.action != p.budsAction { setGesture(e, action: p.budsAction) }
        } else if connected {
            send(NT.setGesture, payload: [0x01, NT.dialDevice, 0x01, p.buttonType, p.budsAction])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.send(NT.getGesture) }
        } else {
            flash("Connect the buds to finish setting this press")
        }
    }

    // MARK: Buds settings

    var dialEntries: [GestureEntry] { gestures.filter { $0.dev == NT.dialDevice } }
    func earEntries(_ dev: UInt8) -> [GestureEntry] { gestures.filter { $0.dev == dev && $0.type != 9 } }

    func setGesture(_ e: GestureEntry, action: UInt8) {
        guard connected, let i = gestures.firstIndex(where: { $0.id == e.id }) else { return }
        withAnimation(.smooth) { gestures[i].action = action }
        send(NT.setGesture, payload: [0x01, e.dev, e.common, e.type, action])
        if e.type == 10 { dialMode = action == 23 ? .volume : .off }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.send(NT.getGesture) }
    }

    // MARK: Volume buttons

    func nudgeVolume(_ delta: Float) {
        let out = Audio.defaultOutput()
        guard isTarget(out), let v = Audio.getVolume(out) else { flash("Buds aren't the sound output"); return }
        let nv = max(0, min(1, v + delta))
        anchor = nv
        ignoreUntil = Date().addingTimeInterval(0.2)
        Audio.setVolume(out, nv)
        withAnimation(.smooth(duration: 0.25)) { volume = nv }
    }

    func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
