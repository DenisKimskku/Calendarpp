import Foundation
import EventKit
import Combine

struct ReminderSummary: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
    let listName: String
}

final class ReminderManager: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    private let eventStore = EKEventStore()

    @Published var remindersByDay: [Date: [ReminderSummary]] = [:]

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        authorizationStatus = status

        guard status == .notDetermined else { return }

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
                    if granted {
                        self?.reloadReminders()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
                    if granted {
                        self?.reloadReminders()
                    }
                }
            }
        }
    }

    func reloadReminders(range: DateInterval? = nil) {
        var isAuthorized = (authorizationStatus == .authorized)
        if #available(macOS 14.0, *) {
            isAuthorized = isAuthorized || (authorizationStatus == .fullAccess)
        }
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let now = Date()

        let interval: DateInterval
        if let range = range {
            interval = range
        } else {
            let start = calendar.date(byAdding: .day, value: -2, to: now)!
            let end = calendar.date(byAdding: .day, value: 7, to: now)!
            interval = DateInterval(start: start, end: end)
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: interval.start,
            ending: interval.end,
            calendars: nil
        )

        eventStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
            guard let self, let reminders = ekReminders else { return }
            let grouped = Dictionary(grouping: reminders) { rem -> Date in
                if let due = rem.dueDateComponents?.date {
                    let comps = calendar.dateComponents([.year, .month, .day], from: due)
                    return calendar.date(from: comps)!
                } else {
                    // undated: group by today
                    return calendar.startOfDay(for: now)
                }
            }

            var mapped: [Date: [ReminderSummary]] = [:]
            for (date, list) in grouped {
                mapped[date] = list.map { rem in
                    ReminderSummary(
                        id: rem.calendarItemIdentifier,
                        title: rem.title,
                        dueDate: rem.dueDateComponents?.date,
                        isCompleted: rem.isCompleted,
                        listName: rem.calendar.title
                    )
                }.sorted(by: { (a, b) in
                    (a.dueDate ?? now) < (b.dueDate ?? now)
                })
            }

            DispatchQueue.main.async {
                self.remindersByDay = mapped
            }
        }
    }

    func reminders(on date: Date) -> [ReminderSummary] {
        let key = Calendar.current.startOfDay(for: date)
        return remindersByDay[key] ?? []
    }
}
