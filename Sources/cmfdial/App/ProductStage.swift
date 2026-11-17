import SwiftUI
import AppKit

enum Assets {
    /// Looks in the app bundle first, then ./Resources/Images (command-line runs).
    static func image(_ name: String) -> NSImage? {
        let exts = ["png", "jpg"]
        var dirs: [String] = []
        if let r = Bundle.main.resourcePath { dirs.append(r + "/Images") }
        dirs.append("Resources/Images")
        for d in dirs { for e in exts {
            let p = "\(d)/\(name).\(e)"
            if FileManager.default.fileExists(atPath: p), let i = NSImage(contentsOfFile: p) { return i }
        } }
        return nil
    }
}

private struct Ring {
    var scale = 1.0
    var opacity = 0.0
}

/// Official CMF Buds Pro 2 imagery: the Smart Dial close-up as hero (with a live marker that turns
/// on the knob), and the case + buds render as an inset.
struct ProductStage: View {
    @EnvironmentObject var engine: DialEngine
    let dialPhoto: NSImage
    let casePhoto: NSImage?

    // Knob centre / radius in the source photo (fractions of its width/height).
    private let knob = CGPoint(x: 0.60, y: 0.59)
    private let knobRadius: CGFloat = 0.19

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cx = knob.x * w
            let cy = knob.y * w - (w - h) / 2        // photo is square, filled to width and cropped vertically
            let r = knobRadius * w

            ZStack(alignment: .bottomLeading) {
                ZStack {
                    Image(nsImage: dialPhoto)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(width: w, height: h)
                        .clipped()

                    // pulse ring
                    Circle().stroke(Theme.accent, lineWidth: 3)
                        .frame(width: r * 2, height: r * 2)
                        .position(x: cx, y: cy)
                        .keyframeAnimator(initialValue: Ring(), trigger: engine.pulse) { c, v in
                            c.scaleEffect(v.scale).opacity(v.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) { LinearKeyframe(1.0, duration: 0.01); CubicKeyframe(1.25, duration: 0.7) }
                            KeyframeTrack(\.opacity) { LinearKeyframe(0.9, duration: 0.01); CubicKeyframe(0, duration: 0.7) }
                        }

                    // press flash: the knob "dips" when you click it
                    Circle().fill(Theme.accent)
                        .frame(width: r * 1.9, height: r * 1.9)
                        .position(x: cx, y: cy)
                        .keyframeAnimator(initialValue: Ring(scale: 1, opacity: 0), trigger: engine.pressPulse) { c, v in
                            c.scaleEffect(v.scale).opacity(v.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) { LinearKeyframe(0.9, duration: 0.01); SpringKeyframe(1.0, duration: 0.5, spring: .bouncy) }
                            KeyframeTrack(\.opacity) { LinearKeyframe(0.55, duration: 0.01); CubicKeyframe(0, duration: 0.5) }
                        }

                    // rim ticks + marker that follow the dial
                    ZStack {
                        ForEach(0..<36, id: \.self) { i in
                            Capsule().fill(Theme.accent.opacity(i % 3 == 0 ? 0.9 : 0.45))
                                .frame(width: 2, height: i % 3 == 0 ? 9 : 5)
                                .offset(y: -(r + 8))
                                .rotationEffect(.degrees(Double(i) * 10))
                        }
                        Circle().fill(Theme.accent).frame(width: 11, height: 11)
                            .shadow(color: Theme.accent, radius: 6)
                            .offset(y: -(r - 14))
                    }
                    .rotationEffect(.degrees(engine.angle))
                    .animation(.spring(response: 0.38, dampingFraction: 0.62), value: engine.angle)
                    .position(x: cx, y: cy)
                }
                .frame(width: w, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line))

                if let casePhoto {
                    Image(nsImage: casePhoto)
                        .resizable().aspectRatio(contentMode: .fill)
                        .scaleEffect(1.35)
                        .frame(width: w * 0.30, height: w * 0.30)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        .padding(12)
                }
            }
        }
        .aspectRatio(1.2, contentMode: .fit)
    }
}
