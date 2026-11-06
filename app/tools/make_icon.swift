// Draws the app icon: a compass on a dark tile. Writes an .iconset folder.
import AppKit
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px), c = NSPoint(x: s / 2, y: s / 2), r = s * 0.27
    NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.27, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8), xRadius: s * 0.18, yRadius: s * 0.18).fill()
    let ring = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    NSColor.white.setStroke(); ring.lineWidth = s * 0.03; ring.stroke()
    let a = CGFloat.pi / 5, l = r * 0.8, w = r * 0.2
    func tip(_ sign: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: c.x + sign * l * sin(a), y: c.y + sign * l * cos(a)))
        p.line(to: NSPoint(x: c.x + w * cos(a), y: c.y - w * sin(a)))
        p.line(to: NSPoint(x: c.x - w * cos(a), y: c.y + w * sin(a)))
        p.close()
        return p
    }
    NSColor.systemOrange.setFill(); tip(1).fill()
    NSColor.white.setFill(); tip(-1).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(name).png"))
}
