import SwiftUI

/// Nothing-style: near-monochrome, hairlines, dot-matrix type, one accent used sparingly.
enum Theme {
    /// Dark = the dial-app look; Light = nothing.tech (#F4F4F4 page, near-black #040404 text).
    private static func adaptive(_ dark: (Double, Double, Double, Double), _ light: (Double, Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }
    static let bg = adaptive((0.055, 0.055, 0.060, 1), (0.957, 0.957, 0.957, 1))
    static let surface = adaptive((0.095, 0.095, 0.105, 1), (1, 1, 1, 1))
    static let surface2 = adaptive((0.14, 0.14, 0.155, 1), (0.918, 0.918, 0.925, 1))
    static let line = adaptive((1, 1, 1, 0.09), (0, 0, 0, 0.10))
    static let text = adaptive((0.94, 0.94, 0.94, 1), (0.016, 0.016, 0.016, 1))
    static let dim = adaptive((0.55, 0.55, 0.55, 1), (0.42, 0.42, 0.43, 1))
    static let accent = Color(red: 0.94, green: 0.39, blue: 0.24)   // CMF-style orange (approximate)
}

// MARK: - Dot-matrix type (5x7 glyphs drawn as dots)

private let glyphs: [Character: [String]] = {
    let raw: [Character: String] = [
        "A": "01110 10001 10001 11111 10001 10001 10001", "B": "11110 10001 10001 11110 10001 10001 11110",
        "C": "01110 10001 10000 10000 10000 10001 01110", "D": "11110 10001 10001 10001 10001 10001 11110",
        "E": "11111 10000 10000 11110 10000 10000 11111", "F": "11111 10000 10000 11110 10000 10000 10000",
        "G": "01110 10001 10000 10111 10001 10001 01111", "H": "10001 10001 10001 11111 10001 10001 10001",
        "I": "01110 00100 00100 00100 00100 00100 01110", "J": "00111 00010 00010 00010 00010 10010 01100",
        "K": "10001 10010 10100 11000 10100 10010 10001", "L": "10000 10000 10000 10000 10000 10000 11111",
        "M": "10001 11011 10101 10101 10001 10001 10001", "N": "10001 11001 10101 10011 10001 10001 10001",
        "O": "01110 10001 10001 10001 10001 10001 01110", "P": "11110 10001 10001 11110 10000 10000 10000",
        "Q": "01110 10001 10001 10001 10101 10010 01101", "R": "11110 10001 10001 11110 10100 10010 10001",
        "S": "01111 10000 10000 01110 00001 00001 11110", "T": "11111 00100 00100 00100 00100 00100 00100",
        "U": "10001 10001 10001 10001 10001 10001 01110", "V": "10001 10001 10001 10001 10001 01010 00100",
        "W": "10001 10001 10001 10101 10101 11011 10001", "X": "10001 10001 01010 00100 01010 10001 10001",
        "Y": "10001 10001 01010 00100 00100 00100 00100", "Z": "11111 00001 00010 00100 01000 10000 11111",
        "0": "01110 10001 10011 10101 11001 10001 01110", "1": "00100 01100 00100 00100 00100 00100 01110",
        "2": "01110 10001 00001 00010 00100 01000 11111", "3": "11110 00001 00001 01110 00001 00001 11110",
        "4": "00010 00110 01010 10010 11111 00010 00010", "5": "11111 10000 11110 00001 00001 10001 01110",
        "6": "00110 01000 10000 11110 10001 10001 01110", "7": "11111 00001 00010 00100 01000 01000 01000",
        "8": "01110 10001 10001 01110 10001 10001 01110", "9": "01110 10001 10001 01111 00001 00010 01100",
        "%": "11001 11010 00010 00100 01000 01011 10011", "-": "00000 00000 00000 11111 00000 00000 00000",
        ".": "00000 00000 00000 00000 00000 01100 01100", ":": "00000 01100 01100 00000 01100 01100 00000",
        "/": "00001 00010 00010 00100 01000 01000 10000", "+": "00000 00100 00100 11111 00100 00100 00000",
        "(": "00010 00100 01000 01000 01000 00100 00010", ")": "01000 00100 00010 00010 00010 00100 01000",
        ">": "10000 01000 00100 00010 00100 01000 10000", "<": "00001 00010 00100 01000 00100 00010 00001",
        "?": "01110 10001 00001 00010 00100 00000 00100", "!": "00100 00100 00100 00100 00100 00000 00100",
        " ": "00000 00000 00000 00000 00000 00000 00000",
    ]
    return raw.mapValues { $0.split(separator: " ").map(String.init) }
}()

extension Theme {
    static let ndotName = "Ndot-55"
    static let letteraName = "LetteraMonoLL-Regular"
    static var hasNdot: Bool { NSFont(name: ndotName, size: 12) != nil }

    /// Lettera Mono for small uppercase labels, system mono as a fallback.
    static func mono(_ size: CGFloat) -> Font {
        NSFont(name: letteraName, size: size) != nil ? .custom(letteraName, size: size) : .system(size: size, weight: .medium, design: .monospaced)
    }
}

struct DotText: View {
    let text: String
    var dot: CGFloat = 2.6
    var gap: CGFloat = 1.4
    var color: Color = Theme.text

    private var chars: [Character] { Array(text.uppercased()) }
    private var pitch: CGFloat { dot + gap }
    private var width: CGFloat { max(0, CGFloat(chars.count) * 6 * pitch - pitch) }

    /// Font size whose cap height matches the height of the drawn 7-row dot matrix.
    private var ndotSize: CGFloat {
        guard let f = NSFont(name: Theme.ndotName, size: 100), f.capHeight > 0 else { return 12 }
        return (7 * pitch - gap) / f.capHeight * 100
    }

    @ViewBuilder var body: some View {
        if Theme.hasNdot {
            Text(text.uppercased())
                .font(.custom(Theme.ndotName, size: ndotSize))
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .frame(height: 7 * pitch - gap, alignment: .center)
                .animation(nil, value: text)
        } else {
            canvasBody
        }
    }

    private var canvasBody: some View {
        Canvas { ctx, _ in
            for (ci, ch) in chars.enumerated() {
                guard let rows = glyphs[ch] else { continue }
                for (r, row) in rows.enumerated() {
                    for (c, bit) in row.enumerated() where bit == "1" {
                        let x = (CGFloat(ci) * 6 + CGFloat(c)) * pitch
                        let y = CGFloat(r) * pitch
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(color))
                    }
                }
            }
        }
        .frame(width: width, height: 7 * pitch - gap)
        .animation(nil, value: text)
    }
}

/// Section container with a dot-matrix title and a hairline border.
struct Panel<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                DotText(text: title, dot: 1.7, gap: 0.9, color: Theme.dim)
                Spacer()
                trailing
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct KeyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.mono(10))
            .foregroundStyle(Theme.dim)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line, lineWidth: 1))
    }
}
