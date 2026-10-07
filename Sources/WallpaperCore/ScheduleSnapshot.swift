import Foundation

/// Value snapshot keeps filtering testable without a Calendar account or permission.
public struct CalendarEvent: Sendable {
    public let id: String
    public let calendarID: String
    public let title: String
    public let start: Date
    public let end: Date
    public let allDay: Bool
    public let cancelled: Bool

    public init(id: String, calendarID: String, title: String, start: Date, end: Date, allDay: Bool, cancelled: Bool = false) {
        self.id = id; self.calendarID = calendarID; self.title = title
        self.start = start; self.end = end; self.allDay = allDay; self.cancelled = cancelled
    }
}

public enum ScheduleSnapshot {
    public static func entries(from events: [CalendarEvent], on date: Date, timeZone: TimeZone,
                               selectedIDs: Set<String>, allCalendars: Bool) -> [ScheduleEntry] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone; formatter.dateFormat = "HH:mm"
        return events.filter {
            !$0.cancelled && (allCalendars || selectedIDs.contains($0.calendarID)) &&
            $0.start < interval.end && ($0.end > interval.start || ($0.start == $0.end && $0.start >= interval.start))
        }.sorted {
            if $0.allDay != $1.allDay { return $0.allDay }
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.id < $1.id
        }.map { event in
            let title = event.title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            return ScheduleEntry(id: "\(event.id)-\(event.start.timeIntervalSince1970)",
                                 title: title.isEmpty ? "Untitled event" : title,
                                 time: event.allDay ? "All day" : formatter.string(from: event.start),
                                 start: event.start, end: event.end, allDay: event.allDay)
        }
    }
}
