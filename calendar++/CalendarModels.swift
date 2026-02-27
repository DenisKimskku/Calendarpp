import Foundation
import AppKit

struct EventSummary: Identifiable, Equatable, Codable {
    let id: String                     // EKEvent.eventIdentifier
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    /// Stable calendar identifier (EKCalendar.calendarIdentifier) when available.
    /// Optional to preserve backward compatibility with older encoded payloads.
    let calendarId: String?
    let calendarName: String
    let calendarColor: NSColor
    let location: String?
    let notes: String?

    static func == (lhs: EventSummary, rhs: EventSummary) -> Bool {
        lhs.id == rhs.id
    }

    enum CodingKeys: String, CodingKey {
        case id, title, startDate, endDate, isAllDay, calendarId, calendarName, location, notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encodeIfPresent(calendarId, forKey: .calendarId)
        try container.encode(calendarName, forKey: .calendarName)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        calendarId = try container.decodeIfPresent(String.self, forKey: .calendarId)
        calendarName = try container.decode(String.self, forKey: .calendarName)
        calendarColor = .blue
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    init(id: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendarId: String? = nil, calendarName: String, calendarColor: NSColor, location: String? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarId = calendarId
        self.calendarName = calendarName
        self.calendarColor = calendarColor
        self.location = location
        self.notes = notes
    }
}

struct DayEvents: Identifiable {
    let id = UUID()
    let date: Date
    let events: [EventSummary]
}
