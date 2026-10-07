import XCTest
@testable import WallpaperCore

final class SettingsTests: XCTestCase {
    func testSouthernSeasonShiftAndYearBoundary() {
        XCTAssertEqual(Palette.current(month: 10, hemisphere: .southern).hex, "7FB7D8")
        XCTAssertEqual(Palette.previous(month: 1, hemisphere: .northern).hex, "1F4D3C")
        XCTAssertEqual(Palette.current(month: 1, hemisphere: .southern).hex, "F26B4F")
    }
    func testAutomaticHemisphereIsLocalAndOverridable() {
        XCTAssertEqual(Hemisphere.automatic.resolved(in: TimeZone(identifier: "Australia/Sydney")!), .southern)
        XCTAssertEqual(Hemisphere.automatic.resolved(in: TimeZone(identifier: "America/Sao_Paulo")!), .southern)
        XCTAssertEqual(Hemisphere.automatic.resolved(in: TimeZone(identifier: "Asia/Samarkand")!), .northern)
        XCTAssertEqual(Hemisphere.northern.resolved(in: TimeZone(identifier: "Australia/Sydney")!), .northern)
    }
    func testPreferencesPreserveDraftAppliedAndDisplaySelection() throws {
        var value = Preferences()
        value.draft.layout = .right; value.applied.layout = .designed
        value.draft.numeral = .day; value.draft.schedule = .collapsed
        value.draft.allCalendars = false; value.draft.calendarIDs = ["calendar-A", "calendar-B"]
        value.hasApplied = true; value.allDisplays = false; value.displayIDs = ["stable-display-uuid"]
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(value)), value)
    }
    func testMissingCaptionIsNotRepresentedAsVerified() {
        XCTAssertFalse(Palette.all[0].captionVerified)
        XCTAssertEqual(Palette.all[0].caption, "")
        XCTAssertTrue(Palette.all[9].captionVerified)
    }
}
