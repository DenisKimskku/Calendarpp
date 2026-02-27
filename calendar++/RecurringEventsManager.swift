//
//  RecurringEventsManager.swift
//  calendar++
//
//  Handles recurring event patterns and creation
//

import Foundation
import EventKit
import Combine

enum RecurrencePattern: Hashable {
    case daily
    case weekly(daysOfWeek: [Int]) // 1 = Sunday, 7 = Saturday
    case monthly(dayOfMonth: Int)
    case yearly
    case custom(interval: Int, frequency: EKRecurrenceFrequency)

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .daily:
            hasher.combine("daily")
        case .weekly(let days):
            hasher.combine("weekly")
            hasher.combine(days)
        case .monthly(let day):
            hasher.combine("monthly")
            hasher.combine(day)
        case .yearly:
            hasher.combine("yearly")
        case .custom(let interval, let frequency):
            hasher.combine("custom")
            hasher.combine(interval)
            hasher.combine(frequency.rawValue)
        }
    }

    static func == (lhs: RecurrencePattern, rhs: RecurrencePattern) -> Bool {
        switch (lhs, rhs) {
        case (.daily, .daily), (.yearly, .yearly):
            return true
        case (.weekly(let lhsDays), .weekly(let rhsDays)):
            return lhsDays == rhsDays
        case (.monthly(let lhsDay), .monthly(let rhsDay)):
            return lhsDay == rhsDay
        case (.custom(let lhsInt, let lhsFreq), .custom(let rhsInt, let rhsFreq)):
            return lhsInt == rhsInt && lhsFreq == rhsFreq
        default:
            return false
        }
    }
}

class RecurringEventsManager: ObservableObject {
    private let eventStore = EKEventStore()

    // MARK: - Create Recurring Event

    func createRecurringEvent(
        title: String,
        startDate: Date,
        duration: TimeInterval,
        pattern: RecurrencePattern,
        endDate: Date? = nil,
        occurrences: Int? = nil,
        calendar: EKCalendar? = nil,
        location: String? = nil,
        notes: String? = nil
    ) -> Bool {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        event.location = location
        event.notes = notes

        // Create recurrence rule
        if let rule = createRecurrenceRule(
            pattern: pattern,
            endDate: endDate,
            occurrences: occurrences
        ) {
            event.addRecurrenceRule(rule)
        }

        do {
            try eventStore.save(event, span: .futureEvents)
            return true
        } catch {
            print("Error creating recurring event: \(error)")
            return false
        }
    }

    // MARK: - Recurrence Rule Creation

    private func createRecurrenceRule(
        pattern: RecurrencePattern,
        endDate: Date?,
        occurrences: Int?
    ) -> EKRecurrenceRule? {
        var recurrenceEnd: EKRecurrenceEnd?

        if let endDate = endDate {
            recurrenceEnd = EKRecurrenceEnd(end: endDate)
        } else if let occurrences = occurrences {
            recurrenceEnd = EKRecurrenceEnd(occurrenceCount: occurrences)
        }

        switch pattern {
        case .daily:
            return EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: recurrenceEnd
            )

        case .weekly(let daysOfWeek):
            let daysOfWeekRecurrence = daysOfWeek.map {
                EKRecurrenceDayOfWeek(EKWeekday(rawValue: $0)!)
            }
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: daysOfWeekRecurrence,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: recurrenceEnd
            )

        case .monthly(let dayOfMonth):
            let daysOfMonthRecurrence = [NSNumber(value: dayOfMonth)]
            return EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                daysOfTheWeek: nil,
                daysOfTheMonth: daysOfMonthRecurrence,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: recurrenceEnd
            )

        case .yearly:
            return EKRecurrenceRule(
                recurrenceWith: .yearly,
                interval: 1,
                end: recurrenceEnd
            )

        case .custom(let interval, let frequency):
            return EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: interval,
                end: recurrenceEnd
            )
        }
    }

    // MARK: - Modify Recurring Event

    func modifyRecurringEvent(
        event: EKEvent,
        modifyFutureEvents: Bool,
        newTitle: String? = nil,
        newStartDate: Date? = nil,
        newDuration: TimeInterval? = nil,
        newLocation: String? = nil,
        newNotes: String? = nil
    ) -> Bool {
        if let title = newTitle {
            event.title = title
        }

        if let startDate = newStartDate {
            let duration = event.endDate.timeIntervalSince(event.startDate)
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(newDuration ?? duration)
        }

        if let location = newLocation {
            event.location = location
        }

        if let notes = newNotes {
            event.notes = notes
        }

        let span: EKSpan = modifyFutureEvents ? .futureEvents : .thisEvent

        do {
            try eventStore.save(event, span: span)
            return true
        } catch {
            print("Error modifying recurring event: \(error)")
            return false
        }
    }

    // MARK: - Delete Recurring Event

    func deleteRecurringEvent(event: EKEvent, deleteFutureEvents: Bool) -> Bool {
        let span: EKSpan = deleteFutureEvents ? .futureEvents : .thisEvent

        do {
            try eventStore.remove(event, span: span)
            return true
        } catch {
            print("Error deleting recurring event: \(error)")
            return false
        }
    }

    // MARK: - Get Recurring Event Occurrences

    func getOccurrences(
        for event: EKEvent,
        from startDate: Date,
        to endDate: Date
    ) -> [EKEvent] {
        guard event.hasRecurrenceRules else { return [event] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let allEvents = eventStore.events(matching: predicate)
        return allEvents.filter { $0.eventIdentifier == event.eventIdentifier }
    }

    // MARK: - Recurrence Pattern Detection

    func detectPattern(from event: EKEvent) -> RecurrencePattern? {
        guard let rule = event.recurrenceRules?.first else { return nil }

        switch rule.frequency {
        case .daily:
            return .daily

        case .weekly:
            if let daysOfWeek = rule.daysOfTheWeek {
                let days = daysOfWeek.map { $0.dayOfTheWeek.rawValue }
                return .weekly(daysOfWeek: days)
            }
            return .weekly(daysOfWeek: [])

        case .monthly:
            if let daysOfMonth = rule.daysOfTheMonth?.first {
                return .monthly(dayOfMonth: daysOfMonth.intValue)
            }
            return nil

        case .yearly:
            return .yearly

        @unknown default:
            return nil
        }
    }

    // MARK: - Helper Methods

    func getRecurrenceDescription(for event: EKEvent) -> String? {
        guard let rule = event.recurrenceRules?.first else { return nil }

        var description = "Repeats "

        switch rule.frequency {
        case .daily:
            description += rule.interval == 1 ? "daily" : "every \(rule.interval) days"

        case .weekly:
            if rule.interval == 1 {
                if let daysOfWeek = rule.daysOfTheWeek, !daysOfWeek.isEmpty {
                    let dayNames = daysOfWeek.map { dayOfWeekName($0.dayOfTheWeek) }
                    description += "weekly on \(dayNames.joined(separator: ", "))"
                } else {
                    description += "weekly"
                }
            } else {
                description += "every \(rule.interval) weeks"
            }

        case .monthly:
            if let day = rule.daysOfTheMonth?.first {
                description += "monthly on day \(day)"
            } else {
                description += "monthly"
            }

        case .yearly:
            description += "yearly"

        @unknown default:
            description += "with custom pattern"
        }

        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                description += " until \(formatter.string(from: endDate))"
            } else {
                let count = end.occurrenceCount
                description += " for \(count) occurrences"
            }
        }

        return description
    }

    private func dayOfWeekName(_ weekday: EKWeekday) -> String {
        switch weekday {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        @unknown default: return "Unknown"
        }
    }
}
