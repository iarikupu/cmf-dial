import AppKit
import Foundation
import IOBluetooth

setvbuf(stdout, nil, _IOLBF, 0)

let usage = """
cmfdial — remap the CMF Buds case dial on macOS   (no arguments = open the app)

  cmfdial devices                       list paired Bluetooth devices
  cmfdial services [ADDR]               list the buds' SDP services / RFCOMM channels
  cmfdial sniff [ADDR] [--all] [--channel N]
                                        log every volume/media-key/RFCOMM event (type a line + Enter to drop a MARK)
  cmfdial ble [--name CMF] [--all]      connect over Bluetooth LE (GATT), dump services, log every notification
  cmfdial nt get [ADDR]                 read the dial/gesture settings from the buds (read-only)
  cmfdial nt set-dial-rotate volume|none --yes [ADDR]
                                        write the dial rotation setting to the buds (what Nothing X does)
  cmfdial run [CONFIG.json]             run the remapper (default: config.json)
  cmfdial media KEY                     fire a media key, to test (play_pause, next, volume_up, ...)

"""

var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args[0].hasPrefix("-psn") || args[0] == "gui" {
    CMFDialApp.main()
    exit(0)
}
guard let command = args.first else { print(usage); exit(0) }
args.removeFirst()

func startApp() -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.run()
    exit(0)
}

func isTargetDevice(_ id: UInt32, address: String?, name: String) -> Bool {
    let uid = Audio.uid(id).uppercased()
    if let a = address?.uppercased().replacingOccurrences(of: ":", with: "-"), !a.isEmpty, uid.contains(a) { return true }
    return Audio.name(id).localizedCaseInsensitiveContains(name)
}

switch command {
case "snapshot":
    MainActor.assumeIsolated {
        renderSnapshot(path: args.first ?? "snapshot.png", tab: args.count > 1 ? args[1] : "overview", scheme: args.count > 2 ? args[2] : "dark")
    }

case "devices":
    for d in pairedDevices() {
        print("\(d.isConnected() ? "●" : "○") \(d.name ?? "?")  \(d.addressString ?? "?")")
    }

case "services":
    guard let dev = findDevice(address: args.first) else { print("No CMF device found; pass the address (see `devices`)."); exit(1) }
    print("Device: \(dev.name ?? "?") \(dev.addressString ?? "")")
    for s in listServices(dev) { print("  RFCOMM ch \(s.channel.map(String.init) ?? "-")\t\(s.name)") }

case "sniff":
    openLogFile(prefix: "sniff")
    let all = args.contains("--all")
    var forced: UInt8?
    if let i = args.firstIndex(of: "--channel"), i + 1 < args.count { forced = UInt8(args[i + 1]) }
    let addr = args.first { !$0.hasPrefix("--") && $0.contains(":") || $0.contains("-") && $0.count == 17 }
    guard let dev = findDevice(address: addr) else { print("No CMF device found; pass the address."); exit(1) }
    log("Target: \(dev.name ?? "?") \(dev.addressString ?? "") connected=\(dev.isConnected())")

    let watcher = VolumeWatcher { id, v in
        log("VOLUME \(Audio.name(id)): \(String(format: "%.4f", v))")
    }
    _ = watcher

    NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { e in
        guard e.subtype.rawValue == 8 else { return }
        let key = (e.data1 & 0xFFFF0000) >> 16
        let flags = e.data1 & 0xFFFF
        log("MEDIA KEY code=\(key) \(((flags & 0xFF00) >> 8) == 0xA ? "down" : "up")")
    }

    let link = RFCOMMLink(device: dev) { ch, bytes in
        log("RFCOMM ch \(ch) RX \(bytes.count)B: \(hex(bytes))")
    }
    var toOpen: [UInt8] = []
    if let f = forced {
        toOpen = [f]
    } else {
        // Default: only vendor (128-bit UUID) services; skip standard phone/audio ones like HFP.
        let skip = ["uuid32"]
        log("Services:")
        for s in listServices(dev) {
            let skipped = !all && skip.contains { s.name.localizedCaseInsensitiveContains($0) } && !s.name.contains("TOTA")
            log("  ch \(s.channel.map(String.init) ?? "-")  \(s.name)\(skipped ? "   (skipped, use --all)" : "")")
            if let c = s.channel, !skipped { toOpen.append(c) }
        }
    }
    for c in toOpen { link.open(c) }
    Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
        guard dev.isConnected() else { return }
        for c in toOpen { link.open(c) }
    }
    log("Now rotate the dial slowly, then press it, long-press it, etc. Type a note + Enter to mark each step.")

    DispatchQueue.global().async {
        while let line = readLine() { DispatchQueue.main.async { log("──── MARK: \(line) ────") } }
    }
    withExtendedLifetime(link) { startApp() }

case "ble":
    openLogFile(prefix: "ble")
    var nameFilter = "CMF"
    if let i = args.firstIndex(of: "--name"), i + 1 < args.count { nameFilter = args[i + 1] }
    let sniffer = BLESniffer(nameFilter: nameFilter, listAll: args.contains("--all"))
    log("Rotate/press the dial once connected. Type a note + Enter to drop a MARK.")
    DispatchQueue.global().async {
        while let line = readLine() { DispatchQueue.main.async { log("──── MARK: \(line) ────") } }
    }
    withExtendedLifetime(sniffer) { startApp() }

case "nt":
    openLogFile(prefix: "nt")
    let sub = args.first ?? ""
    let addr = args.dropFirst().first { $0.count == 17 }
    guard let dev = findDevice(address: addr) else { print("No CMF device found."); exit(1) }
    var writePayload: [UInt8]?
    if sub == "set-dial-rotate" {
        guard args.contains("--yes"), let mode = args.dropFirst().first, ["volume", "none"].contains(mode) else {
            print("Usage: cmfdial nt set-dial-rotate volume|none --yes"); exit(1)
        }
        writePayload = [0x01, NT.dialDevice, 0x01, 0x0a, mode == "volume" ? 0x17 : 0x01]
    } else if sub != "get" { print(usage); exit(1) }

    func dump(_ f: [UInt8]) {
        guard f.count > 8, f[3] == 0x18, f[4] == 0x40 else { return }
        log("Gesture table:")
        for g in NT.decodeGestures(f) {
            let who = g.dev == NT.dialDevice ? "DIAL" : "dev\(g.dev)"
            log("  \(who)  \(NT.typeNames[g.type] ?? "type\(g.type)")  -> \(NT.actionNames[g.action] ?? "action \(g.action)")  (common=\(g.common))")
        }
    }
    var link: RFCOMMLink!
    link = RFCOMMLink(device: dev) { _, bytes in
        log("RX \(hex(bytes))")
        dump(bytes)
    }
    link.onOpen = { _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if let p = writePayload {
                let f = NT.frame(cmd: NT.setGesture, payload: p, op: 2)
                log("TX set gesture: \(hex(f))")
                link.send(NT.channel, f)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let f = NT.frame(cmd: NT.getGesture, op: 3)
                log("TX get gesture: \(hex(f))")
                link.send(NT.channel, f)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { exit(0) }
        }
    }
    link.open(NT.channel)
    withExtendedLifetime(link) { startApp() }

case "run":
    let path = args.first ?? "config.json"
    guard let cfg = loadConfig(path: path) else { print("Could not read \(path). Copy config.example.json to config.json."); exit(1) }
    openLogFile(prefix: "run")
    let name = cfg.deviceName ?? "CMF"
    var anchor: Float?
    var ignoreUntil = Date.distantPast

    if let dial = cfg.dial {
        let restore = dial.restoreVolume ?? true
        let watcher = VolumeWatcher { id, v in
            guard isTargetDevice(id, address: cfg.deviceAddress, name: name) else { anchor = nil; return }
            if Date() < ignoreUntil { return }
            guard let a = anchor else { anchor = v; return }
            if abs(v - a) < 0.001 { return }
            let up = v > a
            if let act = up ? dial.up : dial.down { perform(act, label: up ? "dial UP" : "dial DOWN") }
            if restore {
                ignoreUntil = Date().addingTimeInterval(0.2)
                Audio.setVolume(id, a)
            } else {
                anchor = v
            }
        }
        // Capture the starting volume as the anchor if buds are already the output.
        let cur = Audio.defaultOutput()
        if isTargetDevice(cur, address: cfg.deviceAddress, name: name) { anchor = Audio.getVolume(cur) }
        _ = Unmanaged.passRetained(watcher)
        log("Dial remap on (restore volume: \(restore)). Anchor volume: \(anchor.map { String(format: "%.3f", $0) } ?? "set when buds become output")")
    }

    var link: RFCOMMLink?
    if let triggers = cfg.rfcomm, !triggers.isEmpty {
        guard let dev = findDevice(address: cfg.deviceAddress) else { print("No CMF device found."); exit(1) }
        let patterns = triggers.map { parsePattern($0.match) }
        let l = RFCOMMLink(device: dev) { ch, bytes in
            for (t, p) in zip(triggers, patterns) where t.channel == Int(ch) && frame(bytes, contains: p) {
                perform(t.action, label: t.name ?? t.match)
            }
        }
        link = l
        let channels = Set(triggers.map { UInt8($0.channel) })
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            guard dev.isConnected() else { return }
            for c in channels { l.open(c) }
        }.fire()
    }
    withExtendedLifetime(link) { startApp() }

case "media":
    guard let k = args.first else { print(usage); exit(1) }
    perform(Action(type: "media", command: nil, key: k), label: "test")
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))

default:
    print(usage)
}
