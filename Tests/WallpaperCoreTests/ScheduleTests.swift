import XCTest
@testable import WallpaperCore

final class ScheduleTests: XCTestCase {
    let zone = TimeZone(secondsFromGMT: 0)!
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    var today: Date { date("2026-10-06T12:00:00Z") }
    func event(_ id: String, start: String = "2026-10-06T09:30:00Z", end: String = "2026-10-06T10:00:00Z",
               allDay: Bool = false, cancelled: Bool = false, title: String = "Fixture") -> CalendarEvent {
        CalendarEvent(id: id, calendarID: "A", title: title, start: date(start), end: date(end), allDay: allDay, cancelled: cancelled)
    }
    func testEmptySelectionNeverFallsBackToAllCalendars() {
        XCTAssertTrue(ScheduleSnapshot.entries(from: [event("1")], on: today, timeZone: zone, selectedIDs: [], allCalendars: false).isEmpty)
        XCTAssertEqual(ScheduleSnapshot.entries(from: [event("1")], on: today, timeZone: zone, selectedIDs: ["A"], allCalendars: false).count, 1)
    }
    func testCancellationDayBoundariesAndPointEvents() {
        let values = [event("cancelled", cancelled: true),
                      event("past", start: "2026-10-05T22:00:00Z", end: "2026-10-06T00:00:00Z"),
                      event("tomorrow", start: "2026-10-07T00:00:00Z", end: "2026-10-07T01:00:00Z"),
                      event("midnight", start: "2026-10-06T00:00:00Z", end: "2026-10-06T00:00:00Z")]
        let rows = ScheduleSnapshot.entries(from: values, on: today, timeZone: zone, selectedIDs: [], allCalendars: true)
        XCTAssertEqual(rows.count, 1); XCTAssertTrue(rows[0].id.hasPrefix("midnight-")); XCTAssertEqual(rows[0].time, "00:00")
    }
    func testMultiDayAllDayRecurringInstancesAndTitleNormalization() {
        let values = [event("series", title: "  Review\nデザイン\tmeeting "),
                      event("series", start: "2026-10-06T15:30:00Z", end: "2026-10-06T16:30:00Z"),
                      event("allDay", start: "2026-10-05T00:00:00Z", end: "2026-10-08T00:00:00Z", allDay: true, title: "  ")]
        let rows = ScheduleSnapshot.entries(from: values, on: today, timeZone: zone, selectedIDs: [], allCalendars: true)
        XCTAssertEqual(rows.count, 3); XCTAssertEqual(rows[0].time, "All day"); XCTAssertEqual(rows[0].title, "Untitled event")
        XCTAssertEqual(rows[1].title, "Review デザイン meeting"); XCTAssertNotEqual(rows[1].id, rows[2].id)
    }
}
