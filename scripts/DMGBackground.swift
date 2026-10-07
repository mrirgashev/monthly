import AppKit

// Vector typography and an installation arrow, rendered at 1x and 2x for Finder.
guard CommandLine.arguments.count == 2 else { exit(1) }
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for scale in [1, 2] {
    let width = 660, height = 420
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: width * scale, pixelsHigh: height * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let bounds = NSRect(x: 0, y: 0, width: width, height: height)
    NSColor(srgbRed: 0.95, green: 0.96, blue: 0.93, alpha: 1).setFill()
    bounds.fill()

    func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, secondary: Bool = false) {
        let label = NSAttributedString(string: value, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: secondary
                ? NSColor(srgbRed: 0.34, green: 0.40, blue: 0.36, alpha: 1)
                : NSColor(srgbRed: 0.13, green: 0.20, blue: 0.17, alpha: 1)
        ])
        label.draw(at: NSPoint(x: (660 - label.size().width) / 2, y: y))
    }
    text("Monthly Native", y: 334, size: 30, weight: .medium)
    text("A little more season in your day.", y: 303, size: 15, weight: .regular, secondary: true)

    NSColor(srgbRed: 0.39, green: 0.49, blue: 0.43, alpha: 1).setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 2.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 299, y: 212))
    arrow.line(to: NSPoint(x: 359, y: 212))
    arrow.move(to: NSPoint(x: 348, y: 223))
    arrow.line(to: NSPoint(x: 359, y: 212))
    arrow.line(to: NSPoint(x: 348, y: 201))
    arrow.stroke()

    text("Drag Monthly Native to Applications", y: 67, size: 17, weight: .medium)
    text("Then open it from Applications. You can eject this disk afterward.",
         y: 40, size: 12, weight: .regular, secondary: true)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try data.write(to: directory.appendingPathComponent(scale == 1 ? "installer.png" : "installer@2x.png"))
}
