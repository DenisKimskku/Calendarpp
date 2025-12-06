import Foundation
import EventKit
import Combine

final class EventKitManager: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    private let eventStore = EKEventStore()

    @Published var eventsByDay: [Date: [EventSummary]] = [:]

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
        guard authorizationStatus == .authorized || authorizationStatus == .fullAccess else { return }

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
        return eventsByDay[key] ?? []
    }
}
