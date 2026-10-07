import Foundation

public enum DesignTiming: String, Codable, CaseIterable, Sendable {
    case off, dailyTimes, hourlyCycle, dailyCycle
    public var title: String {
        switch self { case .off: return "Off"; case .dailyTimes: return "Daily times"; case .hourlyCycle: return "Every hour"; case .dailyCycle: return "Every day" }
    }
}

public struct SavedDesign: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var settings: WallpaperSettings
    public var minuteOfDay: Int
    public init(name: String, settings: WallpaperSettings, minuteOfDay: Int = 480) {
        id = UUID(); self.name = name; self.settings = settings; self.minuteOfDay = minuteOfDay
    }
}

public struct DesignPlan: Codable, Equatable, Sendable {
    public var timing: DesignTiming = .off
    public var designs: [SavedDesign] = []
    public var startDate = Date()
    public init() {}
    public var enabled: Bool { timing != .off && !designs.isEmpty }
    public var validationError: String? {
        guard timing != .off else { return nil }
        guard !designs.isEmpty else { return "Add at least one design to the automatic schedule." }
        guard designs.count <= 24 else { return "Use up to 24 saved designs." }
        guard startDate.timeIntervalSince1970.isFinite else { return "Choose a valid start date." }
        if timing == .dailyTimes {
            guard designs.allSatisfy({ (0..<1440).contains($0.minuteOfDay) }) else { return "Choose a valid time for each design." }
            guard Set(designs.map(\.minuteOfDay)).count == designs.count else { return "Choose a different time for each design." }
        }
        return nil
    }
}

/// Pure wall-clock decisions: no timers, randomness, persisted counters or device clock changes.
public enum DesignTimeline {
    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone; return calendar
    }
    private static func occurrence(day: Date, minute: Int, calendar: Calendar) -> Date {
        // A nonexistent spring-forward time moves to the next valid time. A repeated
        // fall-back time runs once, at its first occurrence.
        calendar.nextDate(after: calendar.startOfDay(for: day).addingTimeInterval(-1),
                          matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
                          matchingPolicy: .nextTime, repeatedTimePolicy: .first)!
    }
    private static func anchor(_ plan: DesignPlan) -> Date {
        Date(timeIntervalSince1970: floor(plan.startDate.timeIntervalSince1970 / 60) * 60)
    }

    public static func index(for plan: DesignPlan, at date: Date, timeZone: TimeZone) -> Int? {
        guard plan.enabled, plan.validationError == nil else { return nil }
        let calendar = calendar(timeZone)
        switch plan.timing {
        case .off: return nil
        case .dailyTimes:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
            var latest: (date: Date, index: Int)?
            for (index, design) in plan.designs.enumerated() {
                for day in [yesterday, date] {
                    let time = occurrence(day: day, minute: design.minuteOfDay, calendar: calendar)
                    if time <= date, latest == nil || time > latest!.date { latest = (time, index) }
                }
            }
            return latest?.index
        case .hourlyCycle:
            let elapsed = date.timeIntervalSince(anchor(plan))
            guard elapsed >= 0 else { return nil }
            return Int(floor(elapsed / 3600).truncatingRemainder(dividingBy: Double(plan.designs.count)))
        case .dailyCycle:
            let start = anchor(plan)
            guard date >= start else { return nil }
            let minute = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
            var days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
            if date < occurrence(day: date, minute: minute, calendar: calendar) { days -= 1 }
            return days < 0 ? nil : days % plan.designs.count
        }
    }

    public static func nextChange(for plan: DesignPlan, after date: Date, timeZone: TimeZone) -> Date? {
        guard plan.enabled, plan.validationError == nil else { return nil }
        let calendar = calendar(timeZone)
        switch plan.timing {
        case .off: return nil
        case .hourlyCycle:
            let start = anchor(plan)
            if date < start { return start }
            return start.addingTimeInterval((floor(date.timeIntervalSince(start) / 3600) + 1) * 3600)
        case .dailyTimes, .dailyCycle:
            let start = anchor(plan)
            if plan.timing == .dailyCycle && date < start { return start }
            let minutes = plan.timing == .dailyTimes ? plan.designs.map(\.minuteOfDay)
                : [calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)]
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
            return [date, tomorrow].flatMap { day in
                minutes.map { occurrence(day: day, minute: $0, calendar: calendar) }
            }.filter { $0 > date }.min()
        }
    }

    public static func settings(base: WallpaperSettings, plan: DesignPlan?, at date: Date, timeZone: TimeZone) -> WallpaperSettings {
        guard let plan, let index = index(for: plan, at: date, timeZone: timeZone) else { return base }
        return plan.designs[index].settings
    }

    public static func nextRefresh(plan: DesignPlan?, after date: Date, timeZone: TimeZone) -> Date {
        let midnight = CalendarSnapshot(date: date, timeZone: timeZone).nextMidnight
        guard let plan, let next = nextChange(for: plan, after: date, timeZone: timeZone) else { return midnight }
        return min(midnight, next)
    }
}
