import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else { exit(1) }
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let s = CGFloat(pixels)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: s, height: s).fill(using: .copy)
        let shape = NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88),
                                 xRadius: s * 0.20, yRadius: s * 0.20)
        NSGradient(starting: NSColor(srgbRed: 0.84, green: 0.90, blue: 0.85, alpha: 1),
                   ending: NSColor(srgbRed: 0.44, green: 0.64, blue: 0.65, alpha: 1))!.draw(in: shape, angle: -40)
        NSColor.black.withAlphaComponent(0.25).setStroke()
        let lines = NSBezierPath(); lines.lineWidth = max(0.5, s * 0.002)
        for x in [0.22, 0.40, 0.60, 0.78] {
            lines.move(to: NSPoint(x: s * x, y: s * 0.23)); lines.line(to: NSPoint(x: s * x, y: s * 0.77))
        }
        lines.stroke()
        let font = NSFont(name: "HelveticaNeue-Light", size: s * 0.43) ?? NSFont.systemFont(ofSize: s * 0.43, weight: .light)
        let label = NSAttributedString(string: "31", attributes: [.font: font, .foregroundColor: NSColor.black])
        label.draw(at: NSPoint(x: (s - label.size().width) / 2, y: s * 0.27))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
