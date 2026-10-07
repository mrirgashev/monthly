import XCTest
@testable import WallpaperCore

final class DesignTimelineTests: XCTestCase {
    let utc = TimeZone(secondsFromGMT: 0)!
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func plan(_ timing: DesignTiming) -> DesignPlan {
        var p = DesignPlan(); p.timing = timing; p.startDate = date("2026-10-06T08:15:00Z")
        p.designs = (0..<3).map { i in
            var settings = WallpaperSettings(); settings.layout = Layout.allCases[i]
            var color = BackgroundChoice(); color.mode = .preset; color.presetID = GradientPreset.all[i].id
            settings.background = color
            return SavedDesign(name: "Design \(i)", settings: settings, minuteOfDay: [480, 780, 1200][i])
        }
        return p
    }
    func testDailyTimesRepeatAndUsePreviousEveningBeforeFirstTime() {
        let p = plan(.dailyTimes)
        for (text, expected) in [("2026-10-06T00:00:00Z", 2), ("2026-10-06T07:59:59Z", 2),
                                 ("2026-10-06T08:00:00Z", 0), ("2026-10-06T13:00:00Z", 1),
                                 ("2026-10-06T20:00:00Z", 2), ("2026-10-07T08:00:00Z", 0)] {
            XCTAssertEqual(DesignTimeline.index(for: p, at: date(text), timeZone: utc), expected, text)
        }
        XCTAssertEqual(DesignTimeline.nextChange(for: p, after: date("2026-10-06T20:00:00Z"), timeZone: utc), date("2026-10-07T08:00:00Z"))
    }
    func testHourlyOrderIsDeterministicAcrossRelaunchAndMissedHours() throws {
        let p = plan(.hourlyCycle)
        XCTAssertNil(DesignTimeline.index(for: p, at: date("2026-10-06T08:14:59Z"), timeZone: utc))
        for hour in 0..<240 {
            let now = p.startDate.addingTimeInterval(Double(hour * 3600))
            XCTAssertEqual(DesignTimeline.index(for: p, at: now, timeZone: utc), hour % 3)
            XCTAssertEqual(DesignTimeline.index(for: p, at: now.addingTimeInterval(3599), timeZone: utc), hour % 3)
            XCTAssertEqual(DesignTimeline.nextChange(for: p, after: now, timeZone: utc), now.addingTimeInterval(3600))
        }
        let reloaded = try JSONDecoder().decode(DesignPlan.self, from: JSONEncoder().encode(p))
        let wake = p.startDate.addingTimeInterval(139 * 3600 + 17)
        XCTAssertEqual(DesignTimeline.index(for: p, at: wake, timeZone: utc), DesignTimeline.index(for: reloaded, at: wake, timeZone: utc))
        XCTAssertEqual(DesignTimeline.settings(base: WallpaperSettings(), plan: p, at: wake, timeZone: utc), p.designs[1].settings)
    }
    func testDailyCycleKeepsClockTimeAcrossSpringAndFallDST() {
        let zone = TimeZone(identifier: "America/New_York")!
        var p = plan(.dailyCycle)
        p.startDate = date("2026-03-07T13:15:00Z") // 08:15 EST
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2026-03-08T12:14:59Z"), timeZone: zone), 0)
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2026-03-08T12:15:00Z"), timeZone: zone), 1)
        XCTAssertEqual(DesignTimeline.nextChange(for: p, after: p.startDate, timeZone: zone), date("2026-03-08T12:15:00Z"))
        p.startDate = date("2026-10-31T12:15:00Z") // 08:15 EDT
        XCTAssertEqual(DesignTimeline.nextChange(for: p, after: p.startDate, timeZone: zone), date("2026-11-01T13:15:00Z"))
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2026-11-01T13:14:59Z"), timeZone: zone), 0)
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2026-11-01T13:15:00Z"), timeZone: zone), 1)
    }
    func testSkippedAndRepeatedLocalTimesRunOnce() {
        let zone = TimeZone(identifier: "America/New_York")!
        var p = plan(.dailyTimes)
        p.designs[0].minuteOfDay = 150 // nonexistent 02:30 on spring-forward day
        XCTAssertEqual(DesignTimeline.nextChange(for: p, after: date("2026-03-08T06:59:59Z"), timeZone: zone), date("2026-03-08T07:00:00Z"))
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2026-03-08T07:00:00Z"), timeZone: zone), 0)
        p.designs[0].minuteOfDay = 90 // repeated 01:30 on fall-back day
        XCTAssertEqual(DesignTimeline.nextChange(for: p, after: date("2026-11-01T05:00:00Z"), timeZone: zone), date("2026-11-01T05:30:00Z"))
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2026-11-01T06:10:00Z"), timeZone: zone), 0)
        XCTAssertEqual(DesignTimeline.nextChange(for: p, after: date("2026-11-01T05:31:00Z"), timeZone: zone), date("2026-11-01T18:00:00Z"))
    }
    func testMidnightRefreshDoesNotWaitForNextDesign() {
        var p = plan(.dailyCycle)
        let now = date("2026-12-31T23:50:00Z")
        XCTAssertEqual(DesignTimeline.nextRefresh(plan: p, after: now, timeZone: utc), date("2027-01-01T00:00:00Z"))
        p.timing = .hourlyCycle; p.startDate = date("2026-12-31T23:55:00Z")
        XCTAssertEqual(DesignTimeline.nextRefresh(plan: p, after: now, timeZone: utc), p.startDate)
        XCTAssertEqual(DesignTimeline.nextRefresh(plan: nil, after: now, timeZone: utc), date("2027-01-01T00:00:00Z"))
    }
    func testTimezoneChangeReevaluatesDailySlots() {
        let p = plan(.dailyTimes), now = date("2026-10-06T09:00:00Z")
        XCTAssertEqual(DesignTimeline.index(for: p, at: now, timeZone: utc), 0)
        XCTAssertEqual(DesignTimeline.index(for: p, at: now, timeZone: TimeZone(identifier: "Asia/Samarkand")!), 1)
        XCTAssertEqual(DesignTimeline.index(for: p, at: now, timeZone: TimeZone(identifier: "America/New_York")!), 2)
    }
    func testDisabledEmptyAndConflictingPlansAreSafe() {
        var p = plan(.off)
        XCTAssertNil(DesignTimeline.index(for: p, at: Date(), timeZone: utc))
        XCTAssertNil(DesignTimeline.nextChange(for: p, after: Date(), timeZone: utc))
        p.timing = .dailyTimes; p.designs[1].minuteOfDay = p.designs[0].minuteOfDay
        XCTAssertNotNil(p.validationError)
        XCTAssertNil(DesignTimeline.index(for: p, at: Date(), timeZone: utc))
        p.designs = []; XCTAssertNotNil(p.validationError)
        XCTAssertNil(DesignTimeline.nextChange(for: p, after: Date(), timeZone: utc))
    }
    func testLeapDayAndYearRolloverPreserveDailyOrder() {
        var p = plan(.dailyCycle); p.startDate = date("2024-02-28T08:15:00Z")
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2024-02-29T08:15:00Z"), timeZone: utc), 1)
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2024-03-01T08:15:00Z"), timeZone: utc), 2)
        p.startDate = date("2026-12-31T08:15:00Z")
        XCTAssertEqual(DesignTimeline.index(for: p, at: date("2027-01-01T08:15:00Z"), timeZone: utc), 1)
    }
    func testNextBoundaryStrictlyAdvancesThroughDSTForEveryMode() {
        for zoneID in ["America/New_York", "Australia/Lord_Howe", "Europe/London", "Asia/Samarkand"] {
            let zone = TimeZone(identifier: zoneID)!
            for mode in [DesignTiming.dailyTimes, .hourlyCycle, .dailyCycle] {
                var p = plan(mode); p.startDate = date("2026-01-01T08:15:00Z")
                for offset in stride(from: 0, through: 365 * 24, by: 3) {
                    let now = p.startDate.addingTimeInterval(Double(offset * 3600))
                    let next = DesignTimeline.nextRefresh(plan: p, after: now, timeZone: zone)
                    XCTAssertGreaterThan(next, now, "\(zoneID) \(mode)")
                    XCTAssertLessThanOrEqual(next.timeIntervalSince(now), 26 * 3600)
                    XCTAssertNotNil(DesignTimeline.index(for: p, at: next, timeZone: zone))
                }
            }
        }
    }
}
