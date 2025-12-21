import Foundation
import AppKit

struct EventSummary: Identifiable, Equatable {
    let id: String                     // EKEvent.eventIdentifier
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarName: String
    let calendarColor: NSColor
    let location: String?

    static func == (lhs: EventSummary, rhs: EventSummary) -> Bool {
        lhs.id == rhs.id
    }
}

struct DayEvents: Identifiable {
    let id = UUID()
    let date: Date
    let events: [EventSummary]
}
