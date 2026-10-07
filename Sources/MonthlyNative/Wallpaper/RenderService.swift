import AppKit
import CryptoKit
import ImageIO
import WallpaperCore

struct RenderedWallpaper: @unchecked Sendable {
    let image: CGImage
    let url: URL
}

actor RenderService {
    static let shared = RenderService()
    private let outputDirectory: URL

    init(directory: URL = RenderService.directory) { outputDirectory = directory }

    private var previews: [String: CGImage] = [:]
    private var previewOrder: [String] = []

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MonthlyNative/Wallpapers", isDirectory: true)
    }

    private struct Fingerprint: Encodable {
        let renderer: Int
        let day: String
        let settings: WallpaperSettings
        let calendarIDs: [String]
        let events: [ScheduleEntry]
        let width: Int
        let height: Int
        let logicalWidth: Double
        let logicalHeight: Double
        let highlight: Bool
        let hemisphere: Hemisphere
    }

    private func key(_ request: RenderRequest) throws -> String {
        try WallpaperRenderer.validate(request)
        // Sets are canonicalized explicitly; JSON sortedKeys alone doesn't sort arrays.
        var settings = request.settings
        settings.calendarIDs = []
        settings.desktopControls = false // Controls are a native overlay, never burned into the image.
        let data = Fingerprint(renderer: WallpaperRenderer.version,
                               day: CalendarSnapshot(date: request.date, timeZone: request.timeZone).dayKey,
                               settings: settings, calendarIDs: request.settings.calendarIDs.sorted(),
                               events: request.settings.schedule == .expanded ? request.events : [],
                               width: Int(request.pixelSize.width.rounded()), height: Int(request.pixelSize.height.rounded()),
                               logicalWidth: request.logicalSize.width, logicalHeight: request.logicalSize.height,
                               highlight: request.highlightToday,
                               hemisphere: request.settings.hemisphere.resolved(in: request.timeZone))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(data)).map { String(format: "%02x", $0) }.joined()
    }

    func preview(_ request: RenderRequest) throws -> CGImage {
        let identifier = try key(request)
        if let image = previews[identifier] { return image }
        let image = try WallpaperRenderer.render(request)
        previews[identifier] = image; previewOrder.append(identifier)
        while previewOrder.count > 4 { previews.removeValue(forKey: previewOrder.removeFirst()) }
        return image
    }

    func wallpaper(_ request: RenderRequest) throws -> RenderedWallpaper {
        try WallpaperRenderer.validate(request)
        let directory = outputDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let url = directory.appendingPathComponent("\(try key(request)).png")
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
           image.width == Int(request.pixelSize.width.rounded()), image.height == Int(request.pixelSize.height.rounded()) {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return RenderedWallpaper(image: image, url: url)
        }
        let image = try WallpaperRenderer.render(request)
        let data = try WallpaperRenderer.png(image)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return RenderedWallpaper(image: image, url: url)
    }
}
