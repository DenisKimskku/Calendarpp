import Foundation
import EventKit
import Combine

enum EventKitWriteError: LocalizedError {
    case notAuthorized
    case readOnly
    case eventNotFound
    case invalidDates
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access is not granted."
        case .readOnly:
            return "This event is read-only."
        case .eventNotFound:
            return "Event not found."
        case .invalidDates:
            return "End date must be after start date."
        case .underlying(let message):
            return message
        }
    }
}

final class EventKitManager: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    private let eventStore = EKEventStore()

    @Published var eventsByDay: [Date: [EventSummary]] = [:]
    @Published var googleEventsByDay: [Date: [EventSummary]] = [:]

    var hasCalendarAccess: Bool {
        var authorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            authorized = authorized || (authorizationStatus == .fullAccess)
        }
        return authorized
    }

    // Computed property to get all events as flat array
    var events: [EventSummary] {
        let localEvents = eventsByDay.values.flatMap { $0 }
        let googleEvents = googleEventsByDay.values.flatMap { $0 }
        return (localEvents + googleEvents).sorted { $0.startDate < $1.startDate }
    }

    // Shared calendar source so views do not instantiate additional EKEventStore connections.
    func calendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    private var cancellables = Set<AnyCancellable>()
    private var lastReloadAnchorDate: Date = Date()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)

        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reloadAllEvents(around: self.lastReloadAnchorDate)
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
        let mapped = fetchEventSummaries(range: defaultInterval)

        DispatchQueue.main.async {
            self.eventsByDay = mapped
        }
    }

    func reloadAllEvents(around anchorDate: Date) {
        lastReloadAnchorDate = anchorDate

        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return }

        let anchorRange = rangeForVisibleMonth(around: anchorDate)
        let baselineRange = rangeForVisibleMonth(around: Date())

        var ranges: [DateInterval] = [anchorRange]
        // Keep a baseline "now" window so next-event dot and notifications keep working when browsing other months.
        if !(anchorRange.start <= baselineRange.start && anchorRange.end >= baselineRange.end) {
            ranges.append(baselineRange)
        }

        var merged: [Date: [EventSummary]] = [:]
        for range in ranges {
            let mapped = fetchEventSummaries(range: range)
            for (day, summaries) in mapped {
                merged[day, default: []].append(contentsOf: summaries)
            }
        }

        // De-dupe by event id and keep stable ordering.
        for (day, summaries) in merged {
            var seen = Set<String>()
            let unique = summaries
                .sorted { $0.startDate < $1.startDate }
                .filter { seen.insert($0.id).inserted }
            merged[day] = unique
        }

        DispatchQueue.main.async {
            self.eventsByDay = merged
        }
    }

    private func rangeForVisibleMonth(around anchorDate: Date) -> DateInterval {
        let calendar = Calendar.current

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate))
            ?? calendar.startOfDay(for: anchorDate)

        // Month grid can spill over into adjacent months; fetch a bit extra on both sides.
        let start = calendar.date(byAdding: .day, value: -14, to: startOfMonth) ?? startOfMonth
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? anchorDate
        let end = calendar.date(byAdding: .day, value: 14, to: endOfMonth) ?? endOfMonth

        return DateInterval(start: start, end: end)
    }

    private func fetchEventSummaries(range: DateInterval) -> [Date: [EventSummary]] {
        let calendar = Calendar.current

        let predicate = eventStore.predicateForEvents(
            withStart: range.start,
            end: range.end,
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
                    calendarId: ekEvent.calendar.calendarIdentifier,
                    calendarName: ekEvent.calendar.title,
                    calendarColor: ekEvent.calendar.color,
                    location: ekEvent.location,
                    notes: ekEvent.notes
                )
            }.sorted(by: { $0.startDate < $1.startDate })
        }

        return mapped
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

    func pendingInvitations(within range: DateInterval) -> [EventSummary] {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        let candidateEvents = eventStore.events(matching: predicate)

        let pending = candidateEvents.filter { ekEvent in
            guard ekEvent.status != .canceled else { return false }
            guard let attendees = ekEvent.attendees, !attendees.isEmpty else { return false }
            guard let selfAttendee = attendees.first(where: { $0.isCurrentUser }) else { return false }
            return selfAttendee.participantStatus == .pending
        }

        return pending
            .map { ekEvent in
                EventSummary(
                    id: ekEvent.eventIdentifier,
                    title: ekEvent.title,
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    isAllDay: ekEvent.isAllDay,
                    calendarId: ekEvent.calendar.calendarIdentifier,
                    calendarName: ekEvent.calendar.title,
                    calendarColor: ekEvent.calendar.color,
                    location: ekEvent.location,
                    notes: ekEvent.notes
                )
            }
            .sorted { $0.startDate < $1.startDate }
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

    @discardableResult
    func createEventResult(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        notes: String?,
        calendar: EKCalendar?
    ) -> Result<Void, EventKitWriteError> {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return .failure(.notAuthorized) }

        guard endDate > startDate else {
            return .failure(.invalidDates)
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        guard let targetCalendar = calendar ?? eventStore.defaultCalendarForNewEvents else {
            return .failure(.underlying("No writable calendar is available."))
        }
        event.calendar = targetCalendar

        do {
            try eventStore.save(event, span: .thisEvent)
            reloadAllEvents()
            return .success(())
        } catch {
            return .failure(.underlying("Error creating event: \(error.localizedDescription)"))
        }
    }

    func createEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, calendar: EKCalendar?) {
        _ = createEventResult(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: notes,
            calendar: calendar
        )
    }

    func updateEvent(withId eventId: String, startDate: Date, endDate: Date) -> Result<Void, EventKitWriteError> {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return .failure(.notAuthorized) }

        if eventId.hasPrefix("google-") {
            return .failure(.readOnly)
        }

        guard let event = eventStore.event(withIdentifier: eventId) else {
            return .failure(.eventNotFound)
        }

        guard endDate > startDate else {
            return .failure(.invalidDates)
        }

        event.startDate = startDate
        event.endDate = endDate

        do {
            try eventStore.save(event, span: .thisEvent)
            reloadAllEvents()
            return .success(())
        } catch {
            return .failure(.underlying("Error saving event: \(error.localizedDescription)"))
        }
    }

    func deleteEventResult(withId eventId: String) -> Result<Void, EventKitWriteError> {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return .failure(.notAuthorized) }

        if eventId.hasPrefix("google-") {
            return .failure(.readOnly)
        }

        guard let event = eventStore.event(withIdentifier: eventId) else {
            return .failure(.eventNotFound)
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
            reloadAllEvents()
            return .success(())
        } catch {
            return .failure(.underlying("Error deleting event: \(error.localizedDescription)"))
        }
    }

    func fetchEvents() -> [EventSummary] {
        // Combine all events from eventsByDay and googleEventsByDay
        var allEvents: [EventSummary] = []

        for (_, events) in eventsByDay {
            allEvents.append(contentsOf: events)
        }

        for (_, events) in googleEventsByDay {
            allEvents.append(contentsOf: events)
        }

        return allEvents.sorted { $0.startDate < $1.startDate }
    }

    func deleteEvent(withId eventId: String) {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return }

        // Google events are fetched via the API with a read-only scope.
        // Don't pretend we can delete them through EventKit.
        if eventId.hasPrefix("google-") {
            print("Cannot delete Google Calendar events (read-only).")
            return
        }

        // Try to find and delete the event
        if let event = eventStore.event(withIdentifier: eventId) {
            do {
                try eventStore.remove(event, span: .thisEvent)
                reloadAllEvents()
            } catch {
                print("Error deleting event: \(error)")
            }
        } else {
            print("Event not found with ID: \(eventId)")
        }
    }
}
