import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: DialEngine
    var initialTab: Tab = .overview

    var body: some View {
        HStack(spacing: 0) {
            Sidebar().frame(width: 252)
            Rectangle().fill(Theme.line).frame(width: 1)
            MainColumn(tab: initialTab).padding(22)
        }
        .frame(minWidth: 960, minHeight: 620)
        .background(Theme.bg)
        .preferredColorScheme(engine.settings.appearance == "light" ? .light : engine.settings.appearance == "dark" ? .dark : nil)
        .overlay(alignment: .top) { NoticeToast() }
        .task { engine.start() }
    }
}

struct NoticeToast: View {
    @EnvironmentObject var engine: DialEngine
    var body: some View {
        if let n = engine.notice {
            HStack(spacing: 8) {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
                Text(n).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.ultraThickMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line))
            .padding(.top, 14)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case overview = "OVERVIEW", presses = "PRESSES", controls = "CONTROLS", reconnect = "RECONNECT"
    var id: String { rawValue }
}

struct MainColumn: View {
    @EnvironmentObject var engine: DialEngine
    @State private var tab: Tab
    @Namespace private var tabNS
    init(tab: Tab = .overview) { _tab = State(initialValue: tab) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader()
            StatusStrip()

            if !engine.accessibilityOK { AccessibilityCard().transition(.move(edge: .top).combined(with: .opacity)) }
            if engine.connected && engine.dialMode == .off { DialSetupCard().transition(.move(edge: .top).combined(with: .opacity)) }

            tabBar

            ZStack {
                switch tab {
                case .overview:
                    HStack(alignment: .top, spacing: 16) {
                        CaseStage()
                        VStack(spacing: 14) {
                            VolumePanel()
                            RecentPanel()
                        }
                        .frame(width: 262)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                case .presses:
                    ScrollView { PressesPanel() }
                        .scrollIndicators(.hidden)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .controls:
                    ScrollView { OnBudsPanel() }
                        .scrollIndicators(.hidden)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .reconnect:
                    ScrollView { ReconnectPanel() }
                        .scrollIndicators(.hidden)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .animation(.smooth, value: engine.accessibilityOK)
        .animation(.smooth, value: engine.dialMode)
        .animation(.smooth, value: engine.connected)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { t in
                Text(t.rawValue)
                    .font(Theme.mono(10.5))
                    .foregroundStyle(tab == t ? Theme.bg : Theme.dim)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background {
                        if tab == t { Capsule().fill(Theme.text).matchedGeometryEffect(id: "tab", in: tabNS) }
                    }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { tab = t } }
            }
            Spacer()
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line))
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Header + status

struct StatusHeader: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DotText(text: engine.deviceName, dot: 2.3, gap: 1.2)
            Spacer()
            Text(engine.settings.enabled ? "REMAPPING ON" : "PAUSED")
                .font(Theme.mono(10)).foregroundStyle(Theme.dim)
            Toggle("", isOn: $engine.settings.enabled.animation(.snappy)).labelsHidden().toggleStyle(.switch).tint(Theme.accent)
        }
    }
}

/// At-a-glance: what's connected and the battery of each part.
struct StatusStrip: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        HStack(spacing: 0) {
            cell("BUDS", dot: engine.connected ? .green : Theme.accent,
                 value: engine.connected ? "ON" : "OFF", valueColor: engine.connected ? Theme.text : Theme.accent)
            divider
            battery("LEFT", engine.battery.left, engine.battery.leftCharging)
            divider
            battery("RIGHT", engine.battery.right, engine.battery.rightCharging)
            divider
            battery("CASE", engine.battery.caseLevel, engine.battery.caseCharging)
            divider
            cell("SOUND", dot: engine.outputIsBuds ? .green : Theme.dim,
                 value: engine.outputIsBuds ? "BUDS" : "MAC", valueColor: engine.outputIsBuds ? Theme.text : Theme.dim)
            divider
            cell("DIAL", dot: engine.dialMode == .volume ? .green : (engine.dialMode == .off ? Theme.accent : Theme.dim),
                 value: engine.dialMode == .volume ? "ON" : (engine.dialMode == .off ? "OFF" : "--"),
                 valueColor: engine.dialMode == .off ? Theme.accent : Theme.text)
        }
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line))
        .help(engine.connected ? "Output: \(engine.outputName)" : "Open the case lid or press ⌘R to connect")
    }

    private var divider: some View { Rectangle().fill(Theme.line).frame(width: 1, height: 38) }

    private func cell(_ label: String, dot: Color, value: String, valueColor: Color) -> some View {
        VStack(spacing: 7) {
            DotText(text: value, dot: 2.6, gap: 1.3, color: valueColor)
            HStack(spacing: 5) {
                Circle().fill(dot).frame(width: 5, height: 5)
                DotText(text: label, dot: 1.4, gap: 0.9, color: Theme.dim)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func battery(_ label: String, _ level: Int?, _ charging: Bool) -> some View {
        let connected = engine.connected && level != nil
        return VStack(spacing: 7) {
            HStack(spacing: 3) {
                DotText(text: connected ? "\(level!)%" : "--", dot: 2.6, gap: 1.3,
                        color: connected ? ((level ?? 100) < 20 ? Theme.accent : Theme.text) : Theme.dim)
                if charging { Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.green) }
            }
            HStack(spacing: 5) {
                Circle().fill(connected ? Color.green : Theme.dim.opacity(0.5)).frame(width: 5, height: 5)
                DotText(text: label, dot: 1.4, gap: 0.9, color: Theme.dim)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AccessibilityCard: View {
    @EnvironmentObject var engine: DialEngine
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised").font(.title3).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Allow keyboard control").font(.system(size: 13.5, weight: .medium))
                Text("CMF Dial needs Accessibility access to switch apps and press shortcuts for you.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            }
            Spacer()
            Button("Open Settings") { engine.requestAccessibility() }.buttonStyle(.borderedProminent).tint(Theme.accent)
        }
        .padding(10)
        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.accent.opacity(0.4)))
    }
}

struct DialSetupCard: View {
    @EnvironmentObject var engine: DialEngine
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "dial.medium").font(.title3).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Turn on the dial").font(.system(size: 13.5, weight: .medium))
                Text("Dial rotation is set to \"no action\" on your buds. Switch it to Volume so it can report turns.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            }
            Spacer()
            Button(engine.changingDial ? "Setting…" : "Enable") { engine.setDialRotation(volume: true) }
                .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(engine.changingDial)
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line))
    }
}

// MARK: - Case

struct CaseStage: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        Panel(title: "CASE", trailing: Assets.image("smart-dial") == nil ? AnyView(swatches) : nil) {
            VStack(spacing: 10) {
                if let dial = Assets.image("smart-dial") {
                    ProductStage(dialPhoto: dial, casePhoto: Assets.image("case-buds"))
                        .frame(maxWidth: 440)
                } else {
                    CaseView().scaleEffect(0.74).frame(width: 300, height: 284).frame(maxWidth: .infinity)
                }
                EventPill()
                HStack(spacing: 10) {
                    tryButton(up: false)
                    Text(engine.preset.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                        .contentTransition(.interpolate).animation(.smooth, value: engine.preset.title)
                        .frame(minWidth: 90)
                    tryButton(up: true)
                }
            }
        }
    }

    private var swatches: some View {
        HStack(spacing: 8) {
            ForEach(CaseColour.allCases) { c in
                Circle().fill(c.tray).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(engine.settings.caseColour == c.rawValue ? Theme.text : Theme.line, lineWidth: 1.5))
                    .onTapGesture { withAnimation(.smooth) { engine.settings.caseColour = c.rawValue } }
                    .help(c.label)
            }
        }
    }

    private func tryButton(up: Bool) -> some View {
        Button { engine.trigger(up: up) } label: {
            HStack(spacing: 6) {
                Image(systemName: up ? "arrow.clockwise" : "arrow.counterclockwise").font(.system(size: 12, weight: .bold))
                Text(up ? engine.upTitle : engine.downTitle).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(width: 104, height: 28)
        }
        .buttonStyle(.bordered)
        .help("Try it without touching the dial")
    }
}

struct BatteryReadout: View {
    let label: String
    let level: Int?
    let charging: Bool
    var body: some View {
        VStack(spacing: 6) {
            DotText(text: level.map { "\($0)" } ?? "--", dot: 3, gap: 1.4, color: level.map { $0 < 20 ? Theme.accent : Theme.text } ?? Theme.dim)
                .overlay(alignment: .topTrailing) {
                    if charging { Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.green).offset(x: 12, y: -4) }
                }
            DotText(text: label, dot: 1.6, gap: 1.0, color: Theme.dim)
        }
    }
}

struct EventPill: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        ZStack {
            if let e = engine.lastEvent {
                HStack(spacing: 10) {
                    if let p = e.press {
                        Image(systemName: "hand.tap.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                        Text(p.uppercased()).font(Theme.mono(10)).foregroundStyle(Theme.dim)
                    } else {
                        Image(systemName: e.up ? "arrow.clockwise" : "arrow.counterclockwise").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                    }
                    Image(systemName: e.symbol)
                    Text(e.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Theme.surface2, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.7), lineWidth: 1.2))
                .id(e.id)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .move(edge: .bottom)).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95))))
            } else {
                Text(engine.settings.enabled ? "Turn the dial on your case" : "Paused")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).transition(.opacity)
            }
        }
        .frame(height: 38)
    }
}

// MARK: - Volume

struct VolumePanel: View {
    @EnvironmentObject var engine: DialEngine
    private let segments = 16        // the dial moves exactly one segment per tick

    var body: some View {
        Panel(title: "VOLUME") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    DotText(text: engine.volume.map { "\(Int(($0 * 100).rounded()))" } ?? "--", dot: 3.6, gap: 1.6)
                        .contentTransition(.numericText())
                    DotText(text: "%", dot: 2.0, gap: 1.0, color: Theme.dim).padding(.bottom, 2)
                    Spacer()
                    HStack(spacing: 8) {
                        roundButton("minus") { engine.nudgeVolume(-1.0 / 16) }
                        roundButton("plus") { engine.nudgeVolume(1.0 / 16) }
                    }
                }
                bar
                footer
            }
        }
    }

    private var bar: some View {
        let level = Int(((engine.volume ?? 0) * Float(segments)).rounded())
        let ghostIdx = engine.ghost.map { Int(($0 * Float(segments)).rounded()) - 1 }
        return HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { i in
                let on = i < level
                let isGhost = ghostIdx == i
                Capsule()
                    .fill(isGhost ? Theme.accent : (on ? Theme.text : Theme.surface2))
                    .frame(height: 14)
                    .scaleEffect(y: isGhost ? 1.45 : 1)
                    .shadow(color: isGhost ? Theme.accent.opacity(0.8) : .clear, radius: 6)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isGhost)
                    .animation(.easeOut(duration: 0.18), value: on)
            }
        }
        .frame(height: 22)
    }

    @ViewBuilder private var footer: some View {
        if !engine.outputIsBuds {
            HStack {
                Text("Sound is on \(engine.outputName), not your buds.")
                    .font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(2)
                Spacer(minLength: 6)
                Button("Use buds") { engine.useAsOutput() }.controlSize(.small).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        } else {
            Text(engine.settings.presetID == "volume" ? "Turning the dial changes this level."
                 : "Dial is remapped: the level stays put and each turn flashes a step.")
                .font(.system(size: 11)).foregroundStyle(Theme.dim)
        }
    }

    private func roundButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                .background(Theme.surface2, in: Circle()).overlay(Circle().strokeBorder(Theme.line))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reconnect shortcuts

struct ReconnectPanel: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        Panel(title: "RECONNECT") {
            VStack(spacing: 8) {
                shortcut("Connect buds", "link", "⌘R", key: "r") { engine.reconnect() }
                shortcut("Play sound on buds", "speaker.wave.2", "⌘O", key: "o") { engine.useAsOutput() }
                shortcut("Switch dial to Volume", "dial.medium", "⌘D", key: "d") { engine.enableDial() }
                shortcut("Refresh from buds", "arrow.clockwise", "⌘⇧R", key: "r", shift: true) { engine.refresh() }
                Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 2)
                auto("When buds reconnect: use them for sound", isOn: $engine.settings.autoOutput)
                auto("When buds reconnect: re-enable the dial", isOn: $engine.settings.autoDial)
            }
        }
    }

    private func shortcut(_ title: String, _ symbol: String, _ hint: String, key: KeyEquivalent, shift: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18).foregroundStyle(Theme.accent)
                Text(title).font(.system(size: 12.5, weight: .medium))
                Spacer()
                KeyHint(text: hint)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.surface2.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(key, modifiers: shift ? [.command, .shift] : .command)
    }

    private func auto(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 11.5)).foregroundStyle(Theme.dim)
            Spacer()
            Toggle("", isOn: isOn.animation(.snappy)).labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(Theme.accent)
        }
    }
}

// MARK: - Everything currently set on the buds

private func actionName(_ a: UInt8) -> String {
    switch a {
    case 1: return "No action"
    case 2: return "Play / pause"
    case 3: return "Answer calls"
    case 8: return "Previous track"
    case 9: return "Next track"
    case 11: return "Voice assistant"
    case 17: return "Low-lag mode"
    case 22: return "Noise control"
    case 23: return "Volume control"
    case 25: return "Answer / mute mic"
    case 26: return "Hang up / decline"
    default: return "Action \(a)"
    }
}

private func typeName(_ t: UInt8) -> String {
    switch t {
    case 1: return "Single press"
    case 2: return "Double press"
    case 3: return "Triple press"
    case 7: return "Press & hold"
    case 10: return "Rotate"
    default: return "Gesture \(t)"
    }
}

private func dialOptions(_ e: GestureEntry) -> [UInt8] {
    switch (e.common, e.type) {
    case (1, 1), (1, 2), (1, 3): return [2, 9, 8, 11, 17, 1]
    case (1, 7): return [11, 17, 1]
    case (1, 10): return [23, 1]
    case (9, 2): return [3, 25, 1]
    case (9, 3): return [26, 1]
    default: return [e.action]
    }
}

struct OnBudsPanel: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        Panel(title: "SET ON YOUR BUDS", trailing: AnyView(refreshButton)) {
            if engine.gestures.isEmpty {
                Text(engine.connected ? "Reading from your buds…" : "Connect your buds to read their controls.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.dim).padding(.vertical, 8)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 22) { budsGroups }
                    VStack(alignment: .leading, spacing: 18) { budsGroups }
                }
            }
        }
        .animation(.smooth, value: engine.gestures)
    }

    @ViewBuilder private var budsGroups: some View {
        group("CASE DIAL", engine.dialEntries.sorted { ($0.common, $0.type) < ($1.common, $1.type) }, editable: true)
        VStack(alignment: .leading, spacing: 18) {
            group("LEFT BUD", engine.earEntries(2), editable: false)
            group("RIGHT BUD", engine.earEntries(3), editable: false)
        }
    }

    private var refreshButton: some View {
        Button { engine.refresh() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)) }
            .buttonStyle(.plain).foregroundStyle(Theme.dim)
    }

    private func group(_ title: String, _ entries: [GestureEntry], editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DotText(text: title, dot: 1.8, gap: 1.0, color: Theme.accent)
            ForEach(entries) { e in
                HStack(spacing: 8) {
                    Text(typeName(e.type) + (e.common == 9 ? " (calls)" : ""))
                        .font(.system(size: 12)).foregroundStyle(Theme.dim)
                    Spacer(minLength: 8)
                    if editable && dialOptions(e).count > 1 {
                        Menu {
                            ForEach(dialOptions(e), id: \.self) { a in
                                Button(actionName(a)) { engine.setGesture(e, action: a) }
                            }
                        } label: {
                            Text(actionName(e.action)).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                        }
                        .menuStyle(.borderlessButton).fixedSize()
                    } else {
                        Text(actionName(e.action)).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                    }
                }
                .frame(minWidth: 230)
            }
        }
    }
}

struct RecentPanel: View {
    @EnvironmentObject var engine: DialEngine
    private let df: DateFormatter = { let f = DateFormatter(); f.timeStyle = .medium; return f }()

    var body: some View {
        Panel(title: "RECENT") {
            VStack(alignment: .leading, spacing: 8) {
                if engine.events.isEmpty { Text("Nothing yet").font(.system(size: 12)).foregroundStyle(Theme.dim) }
                ForEach(engine.events.prefix(6)) { e in
                    HStack(spacing: 8) {
                        Image(systemName: e.press != nil ? "hand.tap.fill" : (e.up ? "arrow.clockwise" : "arrow.counterclockwise")).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.accent)
                        Image(systemName: e.symbol).font(.system(size: 11)).frame(width: 16)
                        Text(e.title).font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Text(df.string(from: e.date)).font(Theme.mono(10)).foregroundStyle(Theme.dim)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.events)
        }
    }
}


// MARK: - Dial presses

struct PressesPanel: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        VStack(spacing: 14) {
            Panel(title: "WHEN YOU PRESS THE DIAL") {
                VStack(spacing: 10) {
                    ForEach(DialEngine.pressTypes, id: \.key) { p in row(p) }
                    HStack(spacing: 10) {
                        Image(systemName: "hand.tap").frame(width: 18).foregroundStyle(Theme.dim)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Press & hold").font(.system(size: 12.5, weight: .medium))
                            Text("Handled by the buds (voice assistant, low-lag, none). Change it under Controls.")
                                .font(.system(size: 11)).foregroundStyle(Theme.dim)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Theme.surface2.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Panel(title: "HOW IT WORKS") {
                VStack(alignment: .leading, spacing: 8) {
                    note("Each press is sent by the buds as a media key: single = play/pause, double = next, triple = previous. CMF Dial catches it and runs your action instead.")
                    note("Picking an action here also sets that press on the buds to the matching media key, so you don't need the phone app.")
                    note("The buds' own double/triple taps use the same keys, so they trigger these actions too.")
                    HStack {
                        Text("Ignore keyboard media keys").font(.system(size: 12)).foregroundStyle(Theme.text)
                        Spacer()
                        Toggle("", isOn: $engine.settings.pressBluetoothOnly.animation(.snappy)).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.accent)
                    }
                    if !engine.accessibilityOK {
                        Text("Needs Accessibility access (see the banner above).").font(.system(size: 11)).foregroundStyle(Theme.accent)
                    } else if !engine.tapRunning {
                        Text("Press detection isn't running yet. Quit and reopen CMF Dial once.").font(.system(size: 11)).foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private func note(_ t: String) -> some View {
        Text(t).font(.system(size: 11.5)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ p: (key: String, title: String, buttonType: UInt8, budsAction: UInt8, mediaKey: Int)) -> some View {
        let current = engine.settings.press[p.key] ?? "leave"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: current == "leave" ? "hand.tap" : (Catalog.byID[current]?.symbol ?? "hand.tap"))
                    .frame(width: 18).foregroundStyle(current == "leave" ? Theme.dim : Theme.accent)
                    .contentTransition(.symbolEffect(.replace))
                Text(p.title).font(.system(size: 12.5, weight: .medium))
                Spacer()
                Picker("", selection: Binding(get: { current }, set: { engine.setPress(p.key, to: $0) })) {
                    Text("Leave as is").tag("leave")
                    ForEach(Catalog.categories, id: \.self) { cat in
                        Section(cat) {
                            ForEach(Catalog.actions.filter { $0.category == cat && !$0.isVolume && $0.id != "none" }) { a in
                                Label(a.title, systemImage: a.symbol).tag(a.id)
                            }
                        }
                    }
                }
                .labelsHidden().frame(width: 200)
            }
            if current == "shell" {
                TextField("e.g. open -a Safari", text: Binding(
                    get: { engine.settings.pressShell[p.key] ?? "" },
                    set: { engine.settings.pressShell[p.key] = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Theme.surface2.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.smooth, value: current)
    }
}
