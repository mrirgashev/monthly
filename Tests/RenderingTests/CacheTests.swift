import AppKit
import XCTest
import WallpaperCore
@testable import MonthlyNative

final class CacheTests: XCTestCase {
    private func request(size: CGSize = CGSize(width: 640, height: 400), ids: Set<String> = [],
                         events: [ScheduleEntry] = [], mode: ScheduleMode = .off) -> RenderRequest {
        var settings = WallpaperSettings()
        settings.calendarIDs = ids; settings.schedule = mode
        let zone = TimeZone(secondsFromGMT: 0)!
        return RenderRequest(date: CalendarSnapshot.previewDate(month: 10, year: 2026, timeZone: zone)!,
                             timeZone: zone, settings: settings, events: events,
                             logicalSize: CGSize(width: 1440, height: 900), pixelSize: size, highlightToday: true)
    }

    func testInvalidSizeIsRejectedBeforeCacheKeyIntegerConversion() async throws {
        let renderer = RenderService()
        for size in [CGSize(width: CGFloat.nan, height: 10), CGSize(width: CGFloat.infinity, height: 10), CGSize(width: 0, height: 10)] {
            do { _ = try await renderer.preview(request(size: size)); XCTFail("Invalid input accepted") }
            catch { XCTAssertTrue(error is RenderError) }
        }
    }

    func testCacheCanonicalizesSetsAndRecoversCorruptFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = RenderService(directory: directory)
        let first = try await renderer.wallpaper(request(ids: Set(["a", "b"])))
        let second = try await renderer.wallpaper(request(ids: Set(["b", "a"])))
        XCTAssertEqual(first.url, second.url)
        try Data("broken".utf8).write(to: first.url)
        let recovered = try await renderer.wallpaper(request(ids: ["a", "b"]))
        XCTAssertEqual(recovered.image.width, 640)
        XCTAssertGreaterThan(try Data(contentsOf: recovered.url).count, 100)
        let attributes = try FileManager.default.attributesOfItem(atPath: recovered.url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let folder = try FileManager.default.attributesOfItem(atPath: directory.path)
        XCTAssertEqual((folder[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    func testHiddenEventsCannotAffectOffOrCollapsedWallpaper() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = RenderService(directory: directory)
        let event = ScheduleEntry(id: "synthetic", title: "Private fixture", time: "09:30", start: Date(), end: Date(), allDay: false)
        for mode in [ScheduleMode.off, .collapsed] {
            let empty = try await renderer.wallpaper(request(mode: mode))
            let hidden = try await renderer.wallpaper(request(events: [event], mode: mode))
            XCTAssertEqual(empty.url, hidden.url)
        }
        let empty = try await renderer.wallpaper(request(mode: .expanded))
        let visible = try await renderer.wallpaper(request(events: [event], mode: .expanded))
        XCTAssertNotEqual(empty.url, visible.url)
    }

    func testUnwritableDestinationFailureCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let blocked = root.appendingPathComponent("wallpapers")
        try Data("not a directory".utf8).write(to: blocked)
        let renderer = RenderService(directory: blocked)
        do { _ = try await renderer.wallpaper(request()); XCTFail("Expected filesystem failure") } catch { }
        try FileManager.default.removeItem(at: blocked)
        let result = try await renderer.wallpaper(request())
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
    }

    func testFractionalPixelSizesUseRenderedDimensionsInCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let renderer = RenderService(directory: directory)
        let a = try await renderer.wallpaper(request(size: CGSize(width: 640.1, height: 400)))
        let b = try await renderer.wallpaper(request(size: CGSize(width: 640.9, height: 400)))
        XCTAssertNotEqual(a.url, b.url)
        XCTAssertEqual(a.image.width, 640); XCTAssertEqual(b.image.width, 641)
    }
}
