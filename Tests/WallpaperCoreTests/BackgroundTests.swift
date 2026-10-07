import XCTest
@testable import WallpaperCore

final class BackgroundTests: XCTestCase {
    func testPresetAndCustomColoursStayFixedAcrossMonthsAndHemispheres() {
        for mode in [BackgroundMode.custom, .preset] {
            var choice = BackgroundChoice(); choice.mode = mode; choice.firstHex = "123456"; choice.secondHex = "ABCDEF"
            let expected = choice.resolved(month: 1, hemisphere: .northern, fill: .gradient)
            for month in 1...12 {
                for hemisphere in [Hemisphere.northern, .southern] {
                    XCTAssertEqual(choice.resolved(month: month, hemisphere: hemisphere, fill: .gradient), expected)
                }
            }
        }
    }
    func testSolidUsesFirstCustomColourAndAutoInkHandlesBlackAndWhite() {
        var choice = BackgroundChoice(); choice.mode = .custom
        for (hex, ink) in [("000000", "FFFFFF"), ("FFFFFF", "000000")] {
            choice.firstHex = hex
            let resolved = choice.resolved(month: 10, hemisphere: .northern, fill: .solid)
            XCTAssertEqual(resolved.start, hex); XCTAssertEqual(resolved.end, hex); XCTAssertEqual(resolved.ink, ink)
        }
        choice.ink = .light
        XCTAssertEqual(choice.resolved(month: 10, hemisphere: .northern, fill: .solid).ink, "FFFFFF")
    }
    func testSeasonalCompatibilityAndMoreThanTwelveValidPresets() {
        let choice = BackgroundChoice()
        XCTAssertEqual(choice.resolved(month: 10, hemisphere: .northern, fill: .solid).end, "C7511F")
        XCTAssertGreaterThan(GradientPreset.all.count, 12)
        XCTAssertEqual(Set(GradientPreset.all.map(\.id)).count, GradientPreset.all.count)
        for p in GradientPreset.all {
            XCTAssertNotNil(BackgroundChoice.normalizedHex(p.start)); XCTAssertNotNil(BackgroundChoice.normalizedHex(p.end))
        }
    }
    func testHexValidationAndNonFiniteAngleFallback() {
        XCTAssertEqual(BackgroundChoice.normalizedHex(" #a1b2c3 "), "A1B2C3")
        for bad in ["123", "12345G", "FFFFFFF", "red", ""] { XCTAssertNil(BackgroundChoice.normalizedHex(bad)) }
        var choice = BackgroundChoice(); choice.mode = .custom; choice.angle = .nan; choice.firstHex = "broken"
        let value = choice.resolved(month: 1, hemisphere: .northern, fill: .gradient)
        XCTAssertEqual(value.angle, 132); XCTAssertEqual(value.start, "B9DDDD")
    }
}
