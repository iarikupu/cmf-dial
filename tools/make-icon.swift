import AppKit

func render(_ px: Int) -> Data {
    let img = NSImage(size: NSSize(width: px, height: px))
    img.lockFocus()
    let s = CGFloat(px)
    let rect = NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(colors: [NSColor(red: 0.10, green: 0.11, blue: 0.20, alpha: 1), NSColor(red: 0.20, green: 0.12, blue: 0.40, alpha: 1)])!.draw(in: bg, angle: -60)
    let c = NSPoint(x: s / 2, y: s / 2)
    // tick ring
    for i in 0..<36 {
        let a = CGFloat(i) * .pi / 18
        let r1 = s * 0.33, r2 = s * (i % 3 == 0 ? 0.375 : 0.355)
        let p = NSBezierPath()
        p.move(to: NSPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
        p.line(to: NSPoint(x: c.x + cos(a) * r2, y: c.y + sin(a) * r2))
        p.lineWidth = s * 0.008
        NSColor.white.withAlphaComponent(i % 3 == 0 ? 0.7 : 0.35).setStroke()
        p.stroke()
    }
    // knob
    let kr = s * 0.25
    let knob = NSBezierPath(ovalIn: NSRect(x: c.x - kr, y: c.y - kr, width: kr * 2, height: kr * 2))
    NSGradient(colors: [NSColor(red: 0.45, green: 0.62, blue: 1, alpha: 1), NSColor(red: 0.55, green: 0.35, blue: 0.95, alpha: 1)])!.draw(in: knob, angle: -45)
    NSColor.white.withAlphaComponent(0.4).setStroke(); knob.lineWidth = s * 0.006; knob.stroke()
    let ind = NSBezierPath(roundedRect: NSRect(x: c.x - s * 0.012, y: c.y + kr * 0.45, width: s * 0.024, height: kr * 0.42), xRadius: s * 0.012, yRadius: s * 0.012)
    NSColor.white.setFill(); ind.fill()
    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let dir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
}
