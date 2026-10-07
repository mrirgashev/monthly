import AppKit
import EventKit
import WallpaperCore

struct CalendarChoice: Identifiable {
    let id: String
    let title: String
    let source: String
    let color: NSColor
}

@MainActor final class CalendarService: ObservableObject {
    private let store = EKEventStore()
    @Published private(set) var calendars: [CalendarChoice] = []
    @Published private(set) var authorized = false
    @Published private(set) var message: String?

    init() { refreshAuthorization() }

    func refreshAuthorization() {
        authorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        guard authorized else { calendars = []; return }
        calendars = store.calendars(for: .event).map {
            CalendarChoice(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title,
                           color: NSColor(cgColor: $0.cgColor) ?? .secondaryLabelColor)
        }.sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            message = granted ? nil : "Calendar access is off. Enable it in System Settings → Privacy & Security → Calendars."
        } catch { message = error.localizedDescription }
        refreshAuthorization()
    }

    func events(on date: Date, timeZone: TimeZone, selectedIDs: Set<String>, allCalendars: Bool) -> [ScheduleEntry] {
        refreshAuthorization()
        guard authorized else { return [] }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        guard let interval = calendar.dateInterval(of: .day, for: date) else { return [] }
        let available = store.calendars(for: .event)
        let selected = allCalendars ? available : available.filter { selectedIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: selected)
        let events = store.events(matching: predicate).map {
            CalendarEvent(id: $0.calendarItemIdentifier, calendarID: $0.calendar.calendarIdentifier,
                          title: $0.title ?? "", start: $0.startDate, end: $0.endDate,
                          allDay: $0.isAllDay, cancelled: $0.status == .canceled)
        }
        return ScheduleSnapshot.entries(from: events, on: date, timeZone: timeZone,
                                        selectedIDs: selectedIDs, allCalendars: allCalendars)
    }
}
