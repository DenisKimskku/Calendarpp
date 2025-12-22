import Foundation
import EventKit
import Combine

final class EventKitManager: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    private let eventStore = EKEventStore()

    @Published var eventsByDay: [Date: [EventSummary]] = [:]
    @Published var googleEventsByDay: [Date: [EventSummary]] = [:]

    private var cancellables = Set<AnyCancellable>()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)

        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                self?.reloadAllEvents()
            }
            .store(in: &cancellables)
    }

    func requestAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status

        guard status == .notDetermined else { return }

        eventStore.requestAccess(to: .event) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted {
                    self?.reloadAllEvents()
                }
            }
        }
    }

    func reloadAllEvents(range: DateInterval? = nil) {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let now = Date()

        let defaultInterval: DateInterval
        if let range = range {
            defaultInterval = range
        } else {
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let start = calendar.date(byAdding: .day, value: -7, to: startOfMonth)!
            let end = calendar.date(byAdding: .day, value: 50, to: startOfMonth)!
            defaultInterval = DateInterval(start: start, end: end)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: defaultInterval.start,
            end: defaultInterval.end,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)

        let grouped = Dictionary(grouping: events) { event -> Date in
            let comps = calendar.dateComponents([.year, .month, .day], from: event.startDate)
            return calendar.date(from: comps)!
        }

        var mapped: [Date: [EventSummary]] = [:]
        for (date, events) in grouped {
            mapped[date] = events.map { ekEvent in
                EventSummary(
                    id: ekEvent.eventIdentifier,
                    title: ekEvent.title,
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    isAllDay: ekEvent.isAllDay,
                    calendarName: ekEvent.calendar.title,
                    calendarColor: ekEvent.calendar.color,
                    location: ekEvent.location
                )
            }.sorted(by: { $0.startDate < $1.startDate })
        }

        DispatchQueue.main.async {
            self.eventsByDay = mapped
        }
    }

    func events(on date: Date) -> [EventSummary] {
        let calendar = Calendar.current
        let key = calendar.startOfDay(for: date)

        // Merge local and Google events
        let localEvents = eventsByDay[key] ?? []
        let googleEvents = googleEventsByDay[key] ?? []

        return (localEvents + googleEvents).sorted { $0.startDate < $1.startDate }
    }

    func setGoogleEvents(_ events: [EventSummary]) {
        let calendar = Calendar.current

        // Group Google events by day
        let grouped = Dictionary(grouping: events) { event -> Date in
            calendar.startOfDay(for: event.startDate)
        }

        DispatchQueue.main.async {
            self.googleEventsByDay = grouped
        }
    }

    func totalBusyMinutes(on date: Date) -> Int {
        let todayEvents = events(on: date)
        let now = Date()
        let calendar = Calendar.current
        let isToday = calendar.isDate(date, inSameDayAs: now)

        var totalMinutes = 0
        for event in todayEvents {
            guard !event.isAllDay else { continue }

            let start: Date
            if isToday && event.startDate < now {
                start = now
            } else {
                start = event.startDate
            }

            let end = event.endDate
            guard end > start else { continue }

            let duration = end.timeIntervalSince(start) / 60.0
            totalMinutes += Int(duration)
        }
        return totalMinutes
    }

    func nextEvent() -> EventSummary? {
        let now = Date()
        let calendar = Calendar.current

        // Get events from today and tomorrow
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!

        var upcomingEvents: [EventSummary] = []
        upcomingEvents.append(contentsOf: events(on: today))
        upcomingEvents.append(contentsOf: events(on: tomorrow))
        upcomingEvents.append(contentsOf: events(on: dayAfter))

        return upcomingEvents
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    func simpleInsight() -> String? {
        let todayEvents = events(on: Date())
        guard !todayEvents.isEmpty else { return nil }

        let busyMinutes = totalBusyMinutes(on: Date())
        let hours = busyMinutes / 60
        let minutes = busyMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m busy today"
        } else if hours > 0 {
            return "\(hours)h busy today"
        } else if minutes > 0 {
            return "\(minutes)m busy today"
        }

        return "\(todayEvents.count) events today"
    }

    func createEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, calendar: EKCalendar?) {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
            reloadAllEvents()
        } catch {
            print("Error creating event: \(error)")
        }
    }

    func deleteEvent(withId eventId: String) {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return }

        // Extract the actual EventKit identifier (remove "google-" prefix if present)
        let ekEventId = eventId.replacingOccurrences(of: "google-", with: "")

        // Try to find and delete the event
        if let event = eventStore.event(withIdentifier: ekEventId) {
            do {
                try eventStore.remove(event, span: .thisEvent)
                reloadAllEvents()
            } catch {
                print("Error deleting event: \(error)")
            }
        } else {
            print("Event not found with ID: \(ekEventId)")
        }
    }
}
