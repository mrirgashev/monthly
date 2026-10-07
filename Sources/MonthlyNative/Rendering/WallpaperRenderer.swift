import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers
import WallpaperCore

struct RenderRequest: Sendable {
    let date: Date
    let timeZone: TimeZone
    let settings: WallpaperSettings
    let events: [ScheduleEntry]
    let logicalSize: CGSize
    let pixelSize: CGSize
    let highlightToday: Bool
}

enum RenderError: LocalizedError {
    case invalidSize, allocation, encoding
    var errorDescription: String? {
        switch self {
        case .invalidSize: return "The requested display size is not supported."
        case .allocation: return "There was not enough memory to render this wallpaper."
        case .encoding: return "The wallpaper could not be saved as a PNG."
        }
    }
}

/// Stateless renderer. No view hierarchy, web engine, screen capture, or display loop.
enum WallpaperRenderer {
    static let version = 4

    static func validate(_ request: RenderRequest) throws {
        guard request.pixelSize.width.isFinite, request.pixelSize.height.isFinite,
              request.pixelSize.width > 0, request.pixelSize.height > 0,
              request.pixelSize.width <= 16_384, request.pixelSize.height <= 16_384,
              request.logicalSize.width.isFinite, request.logicalSize.height.isFinite else { throw RenderError.invalidSize }
        let width = Int(request.pixelSize.width.rounded())
        let height = Int(request.pixelSize.height.rounded())
        guard width > 0, height > 0, width <= 16_384, height <= 16_384,
              width * height <= 100_000_000,
              request.logicalSize.width > 0, request.logicalSize.height > 0 else { throw RenderError.invalidSize }
    }

    static func render(_ request: RenderRequest) throws -> CGImage {
        try validate(request)
        let width = Int(request.pixelSize.width.rounded())
        let height = Int(request.pixelSize.height.rounded())
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RenderError.allocation }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(width) / request.logicalSize.width,
                        y: -CGFloat(height) / request.logicalSize.height)
        let snapshot = CalendarSnapshot(date: request.date, timeZone: request.timeZone)
        let hemisphere = request.settings.hemisphere.resolved(in: request.timeZone)
        let appearance = request.settings.backgroundChoice.resolved(month: snapshot.month, hemisphere: hemisphere, fill: request.settings.fill)
        background(context, size: request.logicalSize, appearance: appearance, fill: request.settings.fill)
        composition(context, request: request, snapshot: snapshot, appearance: appearance)
        guard let image = context.makeImage() else { throw RenderError.allocation }
        return image
    }

    static func png(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderError.encoding
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.encoding }
        return data as Data
    }

    static func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
        let number = UInt32(hex, radix: 16) ?? 0
        return CGColor(srgbRed: CGFloat((number >> 16) & 255) / 255,
                       green: CGFloat((number >> 8) & 255) / 255,
                       blue: CGFloat(number & 255) / 255, alpha: alpha)
    }

    private static func background(_ context: CGContext, size: CGSize, appearance: ResolvedBackground, fill: Fill) {
        let rect = CGRect(origin: .zero, size: size)
        context.setFillColor(color(appearance.end)); context.fill(rect)
        guard fill == .gradient else { return }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let current = color(appearance.end), old = color(appearance.start)
        let a = old.components!, b = current.components!
        let mix = CGColor(srgbRed: a[0] * 0.45 + b[0] * 0.55,
                          green: a[1] * 0.45 + b[1] * 0.55,
                          blue: a[2] * 0.45 + b[2] * 0.55, alpha: 1)
        let colors = appearance.seasonalGlow ? [old, mix, current, current] : [old, current]
        let stops: [CGFloat] = appearance.seasonalGlow ? [0, 0.32, 0.68, 1] : [0, 1]
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops) {
            // CSS 132° gradient, including the rectangle's projected gradient length.
            let angle = appearance.angle * Double.pi / 180
            let dx = CGFloat(sin(angle)), dy = CGFloat(-cos(angle))
            let length = abs(size.width * dx) + abs(size.height * dy)
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            context.drawLinearGradient(gradient,
                start: CGPoint(x: centre.x - dx * length / 2, y: centre.y - dy * length / 2),
                end: CGPoint(x: centre.x + dx * length / 2, y: centre.y + dy * length / 2),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        // Retain the measured glow only for the original seasonal palette.
        guard appearance.seasonalGlow else { return }
        context.saveGState()
        context.translateBy(x: size.width * 0.08, y: size.height * 0.96)
        context.scaleBy(x: size.width * 1.2, y: size.height * 0.9)
        if let glow = CGGradient(colorsSpace: space,
                                 colors: [color("FFFFFF", alpha: 0.78), color("FFFFFF", alpha: 0.3), color("FFFFFF", alpha: 0)] as CFArray,
                                 locations: [0, 0.34, 0.62]) {
            context.drawRadialGradient(glow, startCenter: .zero, startRadius: 0,
                                       endCenter: .zero, endRadius: 1, options: [])
        }
        context.restoreGState()
    }

    private static func composition(_ context: CGContext, request: RenderRequest, snapshot: CalendarSnapshot, appearance: ResolvedBackground) {
        let w = request.logicalSize.width, h = request.logicalSize.height
        // Preserve the reference width-based scale on ordinary desktop ratios.
        // Cap at 21:9 for extreme displays; centre the complete composition on portrait panels.
        let contentWidth = min(w, h * 2.333333)
        let contentHeight = min(h, contentWidth * 0.9)
        let origin = CGPoint(x: (w - contentWidth) / 2, y: (h - contentHeight) / 2)
        let u = contentWidth / 100
        let top = origin.y + 7 * u, bottom = origin.y + contentHeight - 7 * u
        let left = origin.x + 5 * u, column = 22.5 * u
        let number = String(request.settings.numeral == .month ? snapshot.month : snapshot.day)
        let numberSize = (number.count == 1 ? 28.0 : 18.0) * u
        let label = appearance.label
        let ink = appearance.ink
        let captionHeight = CGFloat(label.components(separatedBy: "\n").count) * 1.575 * u
        func x(_ col: Int) -> CGFloat { left + CGFloat(col) * column + 2 * u }
        func y(_ position: VerticalPosition, height: CGFloat) -> CGFloat {
            switch position { case .top: return top; case .centre: return (top + bottom - height) / 2; case .bottom: return bottom - height }
        }
        context.setStrokeColor(color(ink, alpha: 0.42))
        context.setLineWidth(max(0.5, contentWidth / 1440))
        // Five rules bound the four columns, including the right outer edge.
        for index in 0...4 {
            let px = left + CGFloat(index) * column
            context.move(to: CGPoint(x: px, y: top)); context.addLine(to: CGPoint(x: px, y: bottom))
        }
        context.strokePath()
        text(String(snapshot.year), at: CGPoint(x: x(0), y: top), size: 1.1 * u, weight: .medium, color: ink, in: context)
        calendar(context, snapshot: snapshot, left: x(0), bottom: bottom, unit: u, highlight: request.highlightToday, ink: ink)

        switch request.settings.layout {
        case .designed:
            let design = Composition.designed(month: snapshot.month)
            text(snapshot.monthName, at: CGPoint(x: x(design.monthColumn), y: y(design.monthPosition, height: 3.4 * u)),
                 size: 3.4 * u, weight: .light, color: ink, maxWidth: 20.5 * u, tracking: -0.02, in: context)
            numeral(number, at: CGPoint(x: x(design.numeralColumn), y: y(design.numeralPosition, height: numberSize * 0.78)),
                    size: numberSize, maxWidth: min(41 * u, w - x(design.numeralColumn) - 5 * u), ink: ink, in: context)
            multiline(label, at: CGPoint(x: x(design.captionColumn), y: y(design.captionPosition, height: captionHeight)),
                      size: 1.05 * u, maxWidth: 20.5 * u, ink: ink, in: context)
        case .centred, .right:
            // The entire numeral/month block occupies one column, with a clear
            // inset from both vertical dividers, for one- and two-digit dates.
            let col = request.settings.layout == .centred ? 2 : 3
            let blockWidth = 18.5 * u
            let availableHeight = bottom - top
            let fitted = fittedNumeralSize(number, size: min(numberSize, availableHeight * 0.70), maxWidth: blockWidth)
            let capHeight = font(size: fitted, weight: .light).capHeight
            let totalHeight = capHeight + 2.8 * u + 4.2 * u
            let numberTop = (top + bottom - totalHeight) / 2
            numeral(number, at: CGPoint(x: x(col), y: numberTop), size: fitted,
                    maxWidth: blockWidth, alignment: .center, ink: ink, in: context)
            text(snapshot.monthName, at: CGPoint(x: x(col), y: numberTop + capHeight + 2.8 * u),
                 size: 3.4 * u, weight: .light, color: ink, maxWidth: blockWidth, alignment: .center,
                 tracking: -0.02, shrink: true, in: context)
            multiline(label, at: CGPoint(x: x(request.settings.layout == .right ? 2 : 3), y: top),
                      size: 1.05 * u, maxWidth: 18.5 * u, ink: ink, in: context)
        }
        if request.settings.schedule != .off {
            // Reserve the otherwise-empty area above the mini calendar. This avoids
            // collisions with month-specific numeral positions and the colour caption.
            let calendarTop = bottom - CGFloat(snapshot.weekCount + 1) * 2.49 * u - 0.15 * u
            let scheduleTop = top + 7 * u
            schedule(context, request: request, at: CGPoint(x: x(0), y: scheduleTop),
                     width: 20.5 * u, unit: u, maxHeight: max(0, calendarTop - scheduleTop - 1.5 * u), ink: ink)
        }
    }

    private static func calendar(_ context: CGContext, snapshot: CalendarSnapshot, left: CGFloat, bottom: CGFloat, unit u: CGFloat, highlight: Bool, ink: String) {
        let font = 1.1 * u, pitchX = 2.72 * u, pitchY = 2.49 * u
        let cellWidth = 1.23 * u
        let startY = bottom - CGFloat(snapshot.weekCount + 1) * pitchY - 0.15 * u
        for col in 0..<7 {
            text(CalendarSnapshot.weekdayLabels[col], at: CGPoint(x: left + CGFloat(col) * pitchX, y: startY),
                 size: font, weight: .medium, color: ink, maxWidth: cellWidth, alignment: .center, in: context)
        }
        for (index, day) in snapshot.cells.enumerated() {
            guard let day else { continue }
            let pos = CGPoint(x: left + CGFloat(index % 7) * pitchX, y: startY + CGFloat(index / 7 + 1) * pitchY)
            if day == snapshot.day && highlight {
                let chip = CGRect(x: pos.x + cellWidth / 2 - font * 0.95, y: pos.y - font * 0.05,
                                  width: font * 1.9, height: font * 1.6)
                context.setFillColor(color(ink == "FFFFFF" ? "FFFFFF" : "111111"))
                context.addPath(CGPath(roundedRect: chip, cornerWidth: font * 0.35, cornerHeight: font * 0.35, transform: nil))
                context.fillPath()
            }
            text(String(day), at: pos, size: font, weight: .medium, color: day == snapshot.day && highlight ? (ink == "FFFFFF" ? "111111" : "FFFFFF") : ink,
                 maxWidth: cellWidth, alignment: .center, in: context)
        }
    }

    private static func schedule(_ context: CGContext, request: RenderRequest, at p: CGPoint, width: CGFloat, unit u: CGFloat, maxHeight: CGFloat, ink: String) {
        guard maxHeight >= 1.3 * u else { return }
        text("TODAY'S SCHEDULE", at: p, size: 0.92 * u, weight: .medium, color: ink, tracking: 0.09, in: context)
        guard request.settings.schedule == .expanded, maxHeight >= 4.5 * u else { return }
        let capacity = max(1, min(6, Int(maxHeight / (2.3 * u)) - 2))
        if request.events.isEmpty {
            text("No events today", at: CGPoint(x: p.x, y: p.y + 2.3 * u), size: 1.05 * u, color: ink, in: context)
        }
        for (index, event) in request.events.prefix(capacity).enumerated() {
            let rowY = p.y + CGFloat(index + 1) * 2.3 * u
            text(event.time, at: CGPoint(x: p.x, y: rowY), size: 1.05 * u, weight: .medium, color: ink, maxWidth: 5.3 * u, in: context)
            text(event.title, at: CGPoint(x: p.x + 6 * u, y: rowY), size: 1.05 * u, color: ink, maxWidth: width - 6 * u, in: context)
        }
        if request.events.count > capacity {
            text("+\(request.events.count - capacity) more", at: CGPoint(x: p.x, y: p.y + CGFloat(capacity + 1) * 2.3 * u),
                 size: 0.9 * u, color: ink, in: context)
        }
    }

    private static func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let name = weight == .light ? "HelveticaNeue-Light" : weight == .medium ? "HelveticaNeue-Medium" : "HelveticaNeue"
        let base = NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: [
            [NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
             NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector]
        ]])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    private static func fittedNumeralSize(_ value: String, size: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: value,
            attributes: [.font: font(size: size, weight: .light)]))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        return size * min(1, maxWidth / max(1, width))
    }

    private static func numeral(_ value: String, at point: CGPoint, size: CGFloat, maxWidth: CGFloat,
                                alignment: NSTextAlignment = .left, ink: String, in context: CGContext) {
        let fitted = fittedNumeralSize(value, size: size, maxWidth: maxWidth)
        let f = font(size: fitted, weight: .light)
        text(value, at: CGPoint(x: point.x, y: point.y - (f.ascender - f.capHeight)), size: fitted, weight: .light,
             color: ink, maxWidth: maxWidth, alignment: alignment, shrink: true, in: context)
    }

    private static func multiline(_ value: String, at point: CGPoint, size: CGFloat, maxWidth: CGFloat, ink: String, in context: CGContext) {
        for (index, line) in value.components(separatedBy: "\n").enumerated() {
            text(line, at: CGPoint(x: point.x, y: point.y + CGFloat(index) * size * 1.5), size: size,
                 weight: .medium, color: ink, maxWidth: maxWidth, in: context)
        }
    }

    private static func text(_ value: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular,
                             color hex: String = "000000", maxWidth: CGFloat? = nil, alignment: NSTextAlignment = .left,
                             tracking: CGFloat = 0, shrink: Bool = false, in context: CGContext) {
        let clean = value.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        var f = font(size: size, weight: weight)
        func makeLine() -> CTLine {
            CTLineCreateWithAttributedString(NSAttributedString(string: clean, attributes: [
                .font: f, .foregroundColor: NSColor(cgColor: color(hex)) ?? .black, .kern: tracking * f.pointSize
            ]))
        }
        var line = makeLine()
        var width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        if let maxWidth, width > maxWidth {
            if shrink {
                f = font(size: f.pointSize * maxWidth / width, weight: weight)
                line = makeLine()
            } else {
                let token = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: [.font: f]))
                line = CTLineCreateTruncatedLine(line, Double(maxWidth), .end, token) ?? line
            }
            width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }
        var x = point.x
        if alignment == .center, let maxWidth { x += (maxWidth - width) / 2 }
        context.saveGState()
        context.translateBy(x: x, y: point.y + f.ascender)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        context.textPosition = .zero
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
