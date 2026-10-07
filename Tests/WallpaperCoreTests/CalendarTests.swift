import XCTest
@testable import WallpaperCore

final class CalendarTests: XCTestCase {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func snapshot(_ text: String, zone: String = "UTC") -> CalendarSnapshot {
        CalendarSnapshot(date: date(text), timeZone: TimeZone(identifier: zone)!)
    }

    func testOctober2026MatchesReferenceMondayFirstGrid() {
        let value = snapshot("2026-10-06T12:00:00Z")
        XCTAssertEqual(value.monthName, "October")
        XCTAssertEqual(value.weekdayOffset, 3)
        XCTAssertEqual(value.weekCount, 5)
        XCTAssertEqual(Array(value.cells.prefix(7)), [nil, nil, nil, 1, 2, 3, 4])
        XCTAssertEqual(value.cells[8], 6)
        XCTAssertEqual(value.cells.compactMap { $0 }, Array(1...31))
    }

    func testFourAndSixWeekMonths() {
        XCTAssertEqual(snapshot("2021-02-10T12:00:00Z").weekCount, 4)
        XCTAssertEqual(snapshot("2026-03-10T12:00:00Z").weekCount, 6)
        XCTAssertEqual(snapshot("2026-03-10T12:00:00Z").cells.first!, nil)
    }

    func testGregorianLeapYearCenturyRules() {
        XCTAssertEqual(snapshot("2024-02-29T12:00:00Z").dayCount, 29)
        XCTAssertEqual(snapshot("2000-02-20T12:00:00Z").dayCount, 29)
        XCTAssertEqual(snapshot("2100-02-20T12:00:00Z").dayCount, 28)
    }

    func testInternationalDateLineAndYearRollover() {
        let western = snapshot("2027-01-01T00:30:00Z", zone: "America/Los_Angeles")
        let eastern = snapshot("2027-01-01T00:30:00Z", zone: "Pacific/Kiritimati")
        XCTAssertEqual(western.year, 2026); XCTAssertEqual(western.month, 12); XCTAssertEqual(western.day, 31)
        XCTAssertEqual(eastern.year, 2027); XCTAssertEqual(eastern.month, 1); XCTAssertEqual(eastern.day, 1)
    }

    func testNextMidnightAcrossSpringDST() {
        let now = date("2026-03-08T08:00:00Z")
        let value = CalendarSnapshot(date: now, timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        XCTAssertEqual(value.nextMidnight.timeIntervalSince(now), 23 * 3600, accuracy: 0.01)
    }

    func testNextMidnightAcrossAutumnDST() {
        let now = date("2026-11-01T07:00:00Z")
        let value = CalendarSnapshot(date: now, timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        XCTAssertEqual(value.nextMidnight.timeIntervalSince(now), 25 * 3600, accuracy: 0.01)
    }

    func testEveryMonthForTwoHundredYearsHasACompleteGrid() {
        for year in 2000...2200 {
            for month in 1...12 {
                let instant = CalendarSnapshot.previewDate(month: month, year: year, timeZone: TimeZone(secondsFromGMT: 0)!)!
                let value = CalendarSnapshot(date: instant, timeZone: TimeZone(secondsFromGMT: 0)!)
                XCTAssertTrue((4...6).contains(value.weekCount))
                XCTAssertTrue((28...31).contains(value.dayCount))
                XCTAssertEqual(value.cells.compactMap { $0 }, Array(1...value.dayCount))
                XCTAssertGreaterThan(value.nextMidnight, instant)
            }
        }
    }
}
