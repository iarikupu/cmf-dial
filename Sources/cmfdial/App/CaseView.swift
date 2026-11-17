import SwiftUI

private struct Ring {
    var scale = 1.0
    var opacity = 0.0
}

enum CaseColour: String, CaseIterable, Identifiable {
    case orange, light, dark
    var id: String { rawValue }
    var tray: Color {
        switch self {
        case .orange: return Color(red: 0.95, green: 0.42, blue: 0.27)
        case .light: return Color(red: 0.83, green: 0.83, blue: 0.84)
        case .dark: return Color(red: 0.24, green: 0.25, blue: 0.26)
        }
    }
    var lid: Color {
        switch self {
        case .orange: return Color(red: 0.98, green: 0.50, blue: 0.34)
        case .light: return Color(red: 0.90, green: 0.90, blue: 0.91)
        case .dark: return Color(red: 0.30, green: 0.31, blue: 0.33)
        }
    }
    var label: String { rawValue.capitalized }
}

/// Top-down drawing of the CMF Buds Pro 2 case (lid up, buds in the tray) with the Smart Dial.
struct CaseView: View {
    @EnvironmentObject var engine: DialEngine
    private var colour: CaseColour { CaseColour(rawValue: engine.settings.caseColour) ?? .orange }

    var body: some View {
        ZStack {
            // soft glow under the case
            Ellipse().fill(RadialGradient(colors: [Theme.accent.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 230))
                .frame(width: 460, height: 360).offset(y: 40)

            // lid
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [colour.lid, colour.tray], startPoint: .top, endPoint: .bottom))
                .frame(width: 300, height: 64)
                .offset(y: -150)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.35))
                .frame(width: 58, height: 12).offset(y: -112)

            // tray
            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .fill(LinearGradient(colors: [colour.tray.opacity(1), colour.tray.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 310, height: 300)
                .overlay(RoundedRectangle(cornerRadius: 64, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1.2))
                .overlay(RoundedRectangle(cornerRadius: 56, style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 2).padding(10))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
                .offset(y: 10)

            DotText(text: "CMF BY NOTHING", dot: 1.5, gap: 1.0, color: .white.opacity(0.55))
                .rotationEffect(.degrees(-24)).offset(x: -64, y: -34)

            bud.rotationEffect(.degrees(35)).offset(x: 62, y: -52)
            bud.rotationEffect(.degrees(215)).offset(x: -70, y: 40)

            dial.offset(x: 88, y: 92)
        }
        .frame(width: 400, height: 380)
    }

    private var bud: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [colour.lid, colour.tray.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 22, height: 96).offset(y: 34)
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8).frame(width: 22, height: 96).offset(y: 34))
            Circle().fill(.white.opacity(0.85)).frame(width: 5, height: 5).offset(y: 62)
            Circle().fill(RadialGradient(colors: [colour.lid, colour.tray], center: .topLeading, startRadius: 2, endRadius: 40))
                .frame(width: 62, height: 62)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .frame(width: 70, height: 130)
    }

    private var dial: some View {
        ZStack {
            // pulse ring on each tick
            Circle().stroke(Theme.accent, lineWidth: 2.5).frame(width: 74, height: 74)
                .keyframeAnimator(initialValue: Ring(), trigger: engine.pulse) { c, v in
                    c.scaleEffect(v.scale).opacity(v.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) { LinearKeyframe(1.0, duration: 0.01); CubicKeyframe(1.7, duration: 0.7) }
                    KeyframeTrack(\.opacity) { LinearKeyframe(0.9, duration: 0.01); CubicKeyframe(0, duration: 0.7) }
                }
            Circle().fill(.black.opacity(0.22)).frame(width: 78, height: 78)
            Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.2).frame(width: 74, height: 74)
            // knob with ticks, rotates with every dial tick
            ZStack {
                Circle().fill(LinearGradient(colors: [.white.opacity(0.95), Color(white: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                ForEach(0..<24, id: \.self) { i in
                    Capsule().fill(.black.opacity(0.25)).frame(width: 1.4, height: 5)
                        .offset(y: -25).rotationEffect(.degrees(Double(i) * 15))
                }
                Circle().fill(Theme.accent).frame(width: 7, height: 7).offset(y: -15)
            }
            .frame(width: 58, height: 58)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .rotationEffect(.degrees(engine.angle))
            .animation(.spring(response: 0.38, dampingFraction: 0.6), value: engine.angle)
        }
        .frame(width: 90, height: 90)
    }
}
