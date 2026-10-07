import Foundation

public struct CalendarSnapshot: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let weekdayOffset: Int
    public let dayCount: Int
    public let timeZoneID: String
    public let nextMidnight: Date
    public static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    public static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    public var monthName: String { Self.monthNames[month - 1] }
    public var weekCount: Int { (weekdayOffset + dayCount + 6) / 7 }
    public var dayKey: String { "\(year)-\(month)-\(day)@\(timeZoneID)" }
    public var cells: [Int?] {
        (0..<(weekCount * 7)).map { index in
            let day = index - weekdayOffset + 1
            return (1...dayCount).contains(day) ? day : nil
        }
    }

    public init(date: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 2000
        month = parts.month ?? 1
        day = parts.day ?? 1
        timeZoneID = timeZone.identifier
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        weekdayOffset = (calendar.component(.weekday, from: monthStart) + 5) % 7
        dayCount = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        // A calendar interval handles 23/25-hour days and historical midnight shifts.
        nextMidnight = calendar.dateInterval(of: .day, for: date)?.end ?? date.addingTimeInterval(86_400)
    }

    public static func previewDate(month: Int, year: Int, timeZone: TimeZone = .autoupdatingCurrent) -> Date? {
        guard (1...12).contains(month) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 12))
    }
}

public struct ScheduleEntry: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let time: String
    public let start: Date
    public let end: Date
    public let allDay: Bool
    public init(id: String, title: String, time: String, start: Date, end: Date, allDay: Bool) {
        self.id = id; self.title = title; self.time = time
        self.start = start; self.end = end; self.allDay = allDay
    }
}
