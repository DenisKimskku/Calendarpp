import Foundation
import AppKit

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

final class EventKitManager {
    var hasCalendarAccess = true
    var shouldFailCreate = false
    var updatedEventIds: [String] = []
    var deletedEventIds: [String] = []
    var createCalls = 0

    func updateEvent(withId eventId: String, startDate: Date, endDate: Date) -> Result<Void, EventKitWriteError> {
        updatedEventIds.append(eventId)
        return .success(())
    }

    func deleteEventResult(withId eventId: String) -> Result<Void, EventKitWriteError> {
        deletedEventIds.append(eventId)
        return .success(())
    }

    func createEventResult(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        notes: String?,
        calendar: Any?
    ) -> Result<Void, EventKitWriteError> {
        createCalls += 1
        if shouldFailCreate {
            return .failure(.underlying("Simulated create failure"))
        }
        return .success(())
    }
}

private let calendar = Calendar.current

private func dateForNext(weekday: Int, hour: Int, minute: Int = 0) -> Date {
    let today = calendar.startOfDay(for: Date())
    let currentWeekday = calendar.component(.weekday, from: today)
    let delta = (weekday - currentWeekday + 7) % 7
    // Match app behavior: weekday references can resolve to today when the day matches.
    let day = calendar.date(byAdding: .day, value: delta, to: today) ?? today
    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
}

private func makeEvent(id: String, title: String, start: Date, minutes: Int) -> EventSummary {
    EventSummary(
        id: id,
        title: title,
        startDate: start,
        endDate: start.addingTimeInterval(TimeInterval(minutes * 60)),
        isAllDay: false,
        calendarId: "cal-1",
        calendarName: "Work",
        calendarColor: .systemBlue,
        location: nil,
        notes: nil
    )
}

private var failures: [String] = []

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures.append(message)
    }
}

private func runTests() {
    let manager = NaturalLanguageCommandsManager()

    do {
        print("[case] ambiguous cancel is blocked in apply mode")
        let eventKit = EventKitManager()
        let twoPmToday = dateForNext(weekday: calendar.component(.weekday, from: Date()), hour: 14)
        let twoPmTomorrow = twoPmToday.addingTimeInterval(24 * 3600)
        let events = [
            makeEvent(id: "e1", title: "Standup", start: twoPmToday, minutes: 30),
            makeEvent(id: "e2", title: "Review", start: twoPmTomorrow, minutes: 30)
        ]

        let result = manager.processCommand(
            "cancel my 2pm",
            events: events,
            eventKitManager: eventKit,
            performChanges: true
        )
        assertCondition(!result.success, "Ambiguous cancel should fail in apply mode.")
        assertCondition(result.message.contains("For safety"), "Ambiguous cancel should return safety disambiguation message.")
        assertCondition(eventKit.deletedEventIds.isEmpty, "Ambiguous cancel should not delete any events.")
    }

    do {
        print("[case] ambiguous cancel preview remains available")
        let eventKit = EventKitManager()
        let twoPmToday = dateForNext(weekday: calendar.component(.weekday, from: Date()), hour: 14)
        let twoPmTomorrow = twoPmToday.addingTimeInterval(24 * 3600)
        let events = [
            makeEvent(id: "e1", title: "Standup", start: twoPmToday, minutes: 30),
            makeEvent(id: "e2", title: "Review", start: twoPmTomorrow, minutes: 30)
        ]

        let result = manager.processCommand(
            "cancel my 2pm",
            events: events,
            eventKitManager: eventKit,
            performChanges: false
        )
        assertCondition(result.success, "Preview cancel should succeed.")
        assertCondition(result.affectedEvents.count == 2, "Preview cancel should show both 2pm matches.")
    }

    do {
        print("[case] friday afternoon bulk command excludes morning/evening")
        let eventKit = EventKitManager()
        let fridayMorning = dateForNext(weekday: 6, hour: 10)
        let fridayAfternoon = dateForNext(weekday: 6, hour: 13)
        let fridayEvening = dateForNext(weekday: 6, hour: 18)
        let events = [
            makeEvent(id: "f1", title: "Friday Morning Sync", start: fridayMorning, minutes: 30),
            makeEvent(id: "f2", title: "Friday Afternoon Review", start: fridayAfternoon, minutes: 30),
            makeEvent(id: "f3", title: "Friday Evening Wrap", start: fridayEvening, minutes: 30)
        ]

        let result = manager.processCommand(
            "cancel all meetings friday afternoon",
            events: events,
            eventKitManager: eventKit,
            performChanges: false
        )
        assertCondition(result.success, "Bulk Friday-afternoon preview should succeed.")
        assertCondition(result.affectedEvents.count == 1, "Friday-afternoon command should only match afternoon events.")
        if let matched = result.affectedEvents.first {
            let hour = calendar.component(.hour, from: matched.startDate)
            assertCondition((12..<17).contains(hour), "Matched Friday event should be in afternoon window.")
        }
    }

    do {
        print("[case] minute precision selects the exact event")
        let eventKit = EventKitManager()
        let day = dateForNext(weekday: 3, hour: 0)
        let twoPm = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day) ?? day
        let twoThirty = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: day) ?? day
        let events = [
            makeEvent(id: "m1", title: "2pm Meeting", start: twoPm, minutes: 30),
            makeEvent(id: "m2", title: "2:30 Meeting", start: twoThirty, minutes: 30)
        ]

        let result = manager.processCommand(
            "cancel my 2:30pm",
            events: events,
            eventKitManager: eventKit,
            performChanges: false
        )
        assertCondition(result.success, "2:30pm preview should succeed.")
        assertCondition(result.affectedEvents.count == 1, "2:30pm query should match exactly one event.")
        assertCondition(result.affectedEvents.first?.id == "m2", "2:30pm query should match minute-precise event.")
    }

    do {
        print("[case] block command surfaces create failure")
        let eventKit = EventKitManager()
        eventKit.shouldFailCreate = true
        let result = manager.processCommand(
            "block 90 minutes tomorrow morning",
            events: [],
            eventKitManager: eventKit,
            performChanges: true
        )
        assertCondition(!result.success, "Block command should fail when create fails.")
        assertCondition(result.message.contains("Simulated create failure"), "Block command should surface create failure.")
    }
}

@main
struct NLCommandRegressionMain {
    static func main() {
        runTests()

        if failures.isEmpty {
            print("ALL NL COMMAND REGRESSION TESTS PASSED")
            exit(EXIT_SUCCESS)
        }

        print("NL COMMAND REGRESSION TESTS FAILED (\(failures.count))")
        for failure in failures {
            print("- \(failure)")
        }
        exit(EXIT_FAILURE)
    }
}
