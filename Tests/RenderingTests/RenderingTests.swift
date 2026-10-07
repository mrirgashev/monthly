import AppKit
import ImageIO
import XCTest
import WallpaperCore
@testable import MonthlyNative

final class RenderingTests: XCTestCase {
    private func request(width: Int = 1440, height: Int = 900, fill: Fill = .solid,
                         layout: Layout = .designed, month: Int = 10) -> RenderRequest {
        var settings = WallpaperSettings(); settings.fill = fill; settings.layout = layout; settings.hemisphere = .northern
        let zone = TimeZone(secondsFromGMT: 0)!
        let date = CalendarSnapshot.previewDate(month: month, year: 2026, timeZone: zone)!
        return RenderRequest(date: date, timeZone: zone, settings: settings, events: [],
                             logicalSize: CGSize(width: 1440, height: 900), pixelSize: CGSize(width: CGFloat(width), height: CGFloat(height)), highlightToday: true)
    }

    func testPNGIsOpaqueAndHasExactRetinaDimensions() throws {
        let image = try WallpaperRenderer.render(request(width: 2880, height: 1800))
        let data = try WallpaperRenderer.png(image)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(decoded.width, 2880); XCTAssertEqual(decoded.height, 1800)
        let pixel = sample(image, x: 0, y: 0)
        XCTAssertLessThanOrEqual(abs(pixel[0] - 199), 1); XCTAssertLessThanOrEqual(abs(pixel[1] - 81), 1)
        XCTAssertLessThanOrEqual(abs(pixel[2] - 31), 1); XCTAssertEqual(pixel[3], 255)
    }

    func testGradientChangesSpatiallyWhileSolidMatchesPalette() throws {
        let solid = try WallpaperRenderer.render(request())
        let gradient = try WallpaperRenderer.render(request(fill: .gradient))
        XCTAssertEqual(sample(solid, x: 1, y: 1), sample(solid, x: 1400, y: 850))
        XCTAssertNotEqual(sample(gradient, x: 1, y: 1), sample(gradient, x: 1400, y: 850))
    }

    func testEveryMonthAndLayoutRendersWithoutClippingContextFailure() throws {
        for month in 1...12 {
            for layout in Layout.allCases {
                let image = try WallpaperRenderer.render(request(width: 640, height: 400, layout: layout, month: month))
                XCTAssertEqual(image.width, 640)
            }
        }
    }

    func testPortraitAndUltrawideHaveExactPixelDimensions() throws {
        for size in [CGSize(width: 1080, height: 1920), CGSize(width: 3440, height: 1440)] {
            let original = request()
            let modified = RenderRequest(date: original.date, timeZone: original.timeZone, settings: original.settings,
                                         events: [], logicalSize: size, pixelSize: size, highlightToday: true)
            let image = try WallpaperRenderer.render(modified)
            XCTAssertEqual(image.width, Int(size.width)); XCTAssertEqual(image.height, Int(size.height))
        }
    }

    func testInvalidDimensionsFailBeforeAllocation() {
        XCTAssertThrowsError(try WallpaperRenderer.render(request(width: 0, height: 400)))
        XCTAssertThrowsError(try WallpaperRenderer.render(request(width: 20000, height: 20000)))
    }

    private func sample(_ image: CGImage, x: Int, y: Int) -> [Int] {
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { pointer in
            let context = CGContext(data: pointer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: CGFloat(-x), y: CGFloat(-y), width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return bytes.map(Int.init)
    }
}
