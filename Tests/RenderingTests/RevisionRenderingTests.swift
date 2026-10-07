import AppKit
import XCTest
import WallpaperCore
@testable import MonthlyNative

final class RevisionRenderingTests: XCTestCase {
    let zone = TimeZone(secondsFromGMT: 0)!
    func request(date: Date, settings: WallpaperSettings, events: [ScheduleEntry] = [], size: CGSize = CGSize(width: 1000, height: 625)) -> RenderRequest {
        RenderRequest(date: date, timeZone: zone, settings: settings, events: events,
                      logicalSize: size, pixelSize: size, highlightToday: true)
    }
    func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    func testCentredAndRightKeepClearGuttersBesideDividers() throws {
        for layout in [Layout.centred, .right] {
            for day in [1, 9, 10, 31] {
                for size in [CGSize(width: 1000, height: 625), CGSize(width: 1400, height: 600), CGSize(width: 625, height: 1000)] {
                    var settings = WallpaperSettings(), background = BackgroundChoice()
                    settings.layout = layout; settings.numeral = .day; settings.fill = .solid
                    background.mode = .custom; background.firstHex = "FFFFFF"; settings.background = background
                    let image = try WallpaperRenderer.render(request(date: date(String(format: "2026-10-%02dT12:00:00Z", day)), settings: settings, size: size))
                    let w = image.width, h = image.height
                    var bytes = [UInt8](repeating: 0, count: w * h * 4)
                    bytes.withUnsafeMutableBytes { ptr in
                        let context = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                        context.draw(image, in: CGRect(origin: .zero, size: size))
                    }
                    let contentWidth = min(size.width, size.height * 2.333333), unit = contentWidth / 100
                    let left = (size.width - contentWidth) / 2 + 5 * unit
                    for column in 1...4 {
                        // Scan clear vertical gutters on both sides of each divider,
                        // excluding the divider's own antialiased stroke.
                        for offset in [-0.8, 0.8] {
                            let x = Int(left + Double(column) * 22.5 * unit + offset * unit)
                            let lowest = (0..<h).map { Int(bytes[($0 * w + x) * 4]) }.min()!
                            XCTAssertGreaterThan(lowest, 245, "\(layout) day \(day), \(size), divider \(column) side \(offset)")
                        }
                    }
                }
            }
        }
    }

    func testFixedBackgroundStillRefreshesDateAndEventsAcrossMidnight() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = RenderService(directory: directory)
        var settings = WallpaperSettings(), color = BackgroundChoice()
        color.mode = .custom; color.firstHex = "336699"; color.secondHex = "99BBDD"
        settings.background = color; settings.numeral = .day; settings.schedule = .expanded
        let before = date("2026-12-31T23:59:59Z"), after = date("2027-01-01T00:00:00Z")
        let event = CalendarEvent(id: "new-year", calendarID: "fixture", title: "Tomorrow's fixture", start: after, end: after.addingTimeInterval(3600), allDay: false)
        let oldEvents = ScheduleSnapshot.entries(from: [event], on: before, timeZone: zone, selectedIDs: [], allCalendars: true)
        let newEvents = ScheduleSnapshot.entries(from: [event], on: after, timeZone: zone, selectedIDs: [], allCalendars: true)
        XCTAssertTrue(oldEvents.isEmpty); XCTAssertEqual(newEvents.count, 1)
        let a = try await renderer.wallpaper(request(date: before, settings: settings, events: oldEvents))
        let b = try await renderer.wallpaper(request(date: after, settings: settings, events: newEvents))
        XCTAssertNotEqual(a.url, b.url)
        XCTAssertNotEqual(try Data(contentsOf: a.url), try Data(contentsOf: b.url))
        XCTAssertEqual(color.resolved(month: 12, hemisphere: .northern, fill: .gradient), color.resolved(month: 1, hemisphere: .northern, fill: .gradient))
        var revised = settings; revised.background?.secondHex = "FFFFFF"
        let c = try await renderer.wallpaper(request(date: after, settings: revised, events: newEvents))
        XCTAssertNotEqual(b.url, c.url)
    }
}
