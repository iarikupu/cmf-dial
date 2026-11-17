import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var engine: DialEngine
    @Namespace private var ns

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                DotText(text: "CMF DIAL", dot: 2.4, gap: 1.2, color: Theme.text)
                Text("Turning the dial does…")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Catalog.presets) { p in
                        PresetRow(preset: p, selected: engine.settings.presetID == p.id, ns: ns)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { engine.settings.presetID = p.id }
                            }
                        if p.id == "custom" && engine.settings.presetID == "custom" {
                            CustomPicker().transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Reverse direction", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer(minLength: 4)
                    Toggle("", isOn: $engine.settings.reversed.animation(.snappy)).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.accent)
                }
                Picker("", selection: $engine.settings.appearance.animation(.smooth)) {
                    Text("Auto").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Theme.surface.opacity(0.6))
    }
}

struct PresetRow: View {
    @EnvironmentObject var engine: DialEngine
    let preset: Preset
    let selected: Bool
    let ns: Namespace.ID
    @State private var hover = false

    private var subtitle: String {
        if preset.id == "custom" { return "Pick each direction yourself" }
        let up = Catalog.byID[preset.up]?.title ?? "", down = Catalog.byID[preset.down]?.title ?? ""
        return preset.id == "volume" ? "Keep the dial's stock behaviour" : "\(up)  /  \(down)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: preset.symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(selected ? Theme.bg : Theme.text)
                .frame(width: 30, height: 30)
                .background(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Theme.text)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Theme.dim).lineLimit(1)
            }
            Spacer()
            if selected {
                Circle().fill(Theme.accent).frame(width: 7, height: 7).transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1))
                    .matchedGeometryEffect(id: "selection", in: ns)
            } else if hover {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04))
            }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

struct CustomPicker: View {
    @EnvironmentObject var engine: DialEngine

    var body: some View {
        VStack(spacing: 12) {
            direction("TURN UP", icon: "arrow.clockwise", action: $engine.settings.customUp, shell: $engine.settings.shellUp)
            direction("TURN DOWN", icon: "arrow.counterclockwise", action: $engine.settings.customDown, shell: $engine.settings.shellDown)
        }
        .padding(12)
        .background(Theme.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func direction(_ label: String, icon: String, action: Binding<String>, shell: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                DotText(text: label, dot: 1.7, gap: 1.0, color: Theme.dim)
            }.foregroundStyle(Theme.dim)
            Picker("", selection: action.animation(.snappy)) {
                ForEach(Catalog.categories, id: \.self) { cat in
                    Section(cat) {
                        ForEach(Catalog.actions.filter { $0.category == cat }) { a in
                            Label(a.title, systemImage: a.symbol).tag(a.id)
                        }
                    }
                }
            }.labelsHidden()
            if action.wrappedValue == "shell" {
                TextField("e.g. open -a Safari", text: shell)
                    .textFieldStyle(.roundedBorder)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
