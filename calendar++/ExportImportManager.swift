//
//  ExportImportManager.swift
//  calendar++
//
//  Manages exporting and importing calendar data
//

import Foundation
import EventKit
import AppKit
import Combine

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case ics = "ICS (iCalendar)"
    case csv = "CSV (Spreadsheet)"
    case json = "JSON"
    case markdown = "Markdown"

    var fileExtension: String {
        switch self {
        case .ics: return "ics"
        case .csv: return "csv"
        case .json: return "json"
        case .markdown: return "md"
        }
    }
}

// MARK: - Export Options

struct ExportOptions {
    var format: ExportFormat = .ics
    var includeNotes: Bool = true
    var includeLocation: Bool = true
    var includeAttendees: Bool = true
    var includeAlarms: Bool = true
    var dateRange: DateInterval?
    var selectedCalendars: [String] = [] // Calendar IDs
}

// MARK: - Import Result

struct ImportResult {
    var successCount: Int = 0
    var failedCount: Int = 0
    var duplicateCount: Int = 0
    var errors: [String] = []
}

// MARK: - Export Import Manager

class ExportImportManager: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false

    private let eventStore = EKEventStore()

    // MARK: - Export Events

    func exportEvents(_ events: [EventSummary], options: ExportOptions) -> String {
        switch options.format {
        case .ics:
            return exportToICS(events, options: options)
        case .csv:
            return exportToCSV(events, options: options)
        case .json:
            return exportToJSON(events, options: options)
        case .markdown:
            return exportToMarkdown(events, options: options)
        }
    }

    // MARK: - ICS Export

    private func exportToICS(_ events: [EventSummary], options: ExportOptions) -> String {
        var ics = "BEGIN:VCALENDAR\n"
        ics += "VERSION:2.0\n"
        ics += "PRODID:-//Calendar++//EN\n"
        ics += "CALSCALE:GREGORIAN\n"
        ics += "METHOD:PUBLISH\n"

        for event in events {
            guard let ekEvent = eventStore.event(withIdentifier: event.id) else {
                continue
            }

            ics += "BEGIN:VEVENT\n"
            ics += "UID:\(event.id)\n"
            ics += "DTSTAMP:\(formatICSDate(Date()))\n"
            ics += "DTSTART:\(formatICSDate(event.startDate))\n"
            ics += "DTEND:\(formatICSDate(event.endDate))\n"
            ics += "SUMMARY:\(escapeICSText(event.title))\n"

            if options.includeLocation, let location = event.location {
                ics += "LOCATION:\(escapeICSText(location))\n"
            }

            if options.includeNotes, let notes = event.notes {
                ics += "DESCRIPTION:\(escapeICSText(notes))\n"
            }

            if options.includeAttendees {
                for attendee in ekEvent.attendees ?? [] {
                    let email = attendee.url.absoluteString
                    ics += "ATTENDEE;CN=\"\(attendee.name ?? "")\":\(email)\n"
                }
            }

            if options.includeAlarms {
                for alarm in ekEvent.alarms ?? [] {
                    let offset = alarm.relativeOffset
                    ics += "BEGIN:VALARM\n"
                    ics += "ACTION:DISPLAY\n"
                    ics += "TRIGGER:-PT\(Int(abs(offset) / 60))M\n"
                    ics += "END:VALARM\n"
                }
            }

            if event.isAllDay {
                ics += "X-APPLE-ALL-DAY:TRUE\n"
            }

            ics += "END:VEVENT\n"
        }

        ics += "END:VCALENDAR\n"
        return ics
    }

    private func formatICSDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }

    private func escapeICSText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }

    // MARK: - CSV Export

    private func exportToCSV(_ events: [EventSummary], options: ExportOptions) -> String {
        var csv = "Title,Start Date,End Date,Calendar"

        if options.includeLocation {
            csv += ",Location"
        }
        if options.includeNotes {
            csv += ",Notes"
        }

        csv += "\n"

        for event in events {
            let title = escapeCSV(event.title)
            let startDate = formatCSVDate(event.startDate)
            let endDate = formatCSVDate(event.endDate)
            let calendar = escapeCSV(event.calendarName)

            csv += "\(title),\(startDate),\(endDate),\(calendar)"

            if options.includeLocation {
                csv += ",\(escapeCSV(event.location ?? ""))"
            }

            if options.includeNotes {
                csv += ",\(escapeCSV(event.notes ?? ""))"
            }

            csv += "\n"
        }

        return csv
    }

    private func formatCSVDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }

    // MARK: - JSON Export

    private func exportToJSON(_ events: [EventSummary], options: ExportOptions) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(events)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            print("Failed to encode JSON: \(error)")
            return "{}"
        }
    }

    // MARK: - Markdown Export

    private func exportToMarkdown(_ events: [EventSummary], options: ExportOptions) -> String {
        var markdown = "# Calendar Export\n\n"
        markdown += "Exported on \(formatMarkdownDate(Date()))\n\n"
        markdown += "Total events: \(events.count)\n\n"
        markdown += "---\n\n"

        // Group by date
        let groupedEvents = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }

        for (date, dateEvents) in groupedEvents.sorted(by: { $0.key < $1.key }) {
            markdown += "## \(formatMarkdownDate(date))\n\n"

            for event in dateEvents.sorted(by: { $0.startDate < $1.startDate }) {
                markdown += "### \(event.title)\n\n"
                markdown += "- **Time:** \(formatMarkdownTime(event.startDate)) - \(formatMarkdownTime(event.endDate))\n"
                markdown += "- **Calendar:** \(event.calendarName)\n"

                if options.includeLocation, let location = event.location {
                    markdown += "- **Location:** \(location)\n"
                }

                if options.includeNotes, let notes = event.notes {
                    markdown += "\n\(notes)\n"
                }

                markdown += "\n---\n\n"
            }
        }

        return markdown
    }

    private func formatMarkdownDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func formatMarkdownTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Import Events

    func importFromICS(data: Data) -> ImportResult {
        var result = ImportResult()

        guard let content = String(data: data, encoding: .utf8) else {
            result.errors.append("Failed to read file")
            return result
        }

        let events = parseICS(content)

        for parsedEvent in events {
            do {
                try createEventFromParsed(parsedEvent)
                result.successCount += 1
            } catch {
                result.failedCount += 1
                result.errors.append("Failed to import '\(parsedEvent.title)': \(error.localizedDescription)")
            }
        }

        return result
    }

    private func parseICS(_ content: String) -> [ParsedEvent] {
        var events: [ParsedEvent] = []
        let lines = content.components(separatedBy: .newlines)

        var currentEvent: ParsedEvent?
        var isInEvent = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "BEGIN:VEVENT" {
                isInEvent = true
                currentEvent = ParsedEvent()
            } else if trimmedLine == "END:VEVENT" {
                if let event = currentEvent {
                    events.append(event)
                }
                isInEvent = false
                currentEvent = nil
            } else if isInEvent {
                if let event = currentEvent {
                    currentEvent = parseEventProperty(line: trimmedLine, event: event)
                }
            }
        }

        return events
    }

    struct ParsedEvent {
        var title: String = ""
        var startDate: Date = Date()
        var endDate: Date = Date()
        var location: String?
        var notes: String?
        var uid: String?
        var isAllDay: Bool = false
    }

    private func parseEventProperty(line: String, event: ParsedEvent) -> ParsedEvent {
        var updatedEvent = event

        if line.hasPrefix("SUMMARY:") {
            updatedEvent.title = String(line.dropFirst("SUMMARY:".count))
        } else if line.hasPrefix("DTSTART") {
            if let date = extractICSDate(from: line) {
                updatedEvent.startDate = date
            }
        } else if line.hasPrefix("DTEND") {
            if let date = extractICSDate(from: line) {
                updatedEvent.endDate = date
            }
        } else if line.hasPrefix("LOCATION:") {
            updatedEvent.location = String(line.dropFirst("LOCATION:".count))
        } else if line.hasPrefix("DESCRIPTION:") {
            updatedEvent.notes = String(line.dropFirst("DESCRIPTION:".count))
        } else if line.hasPrefix("X-APPLE-ALL-DAY:TRUE") {
            updatedEvent.isAllDay = true
        }

        return updatedEvent
    }

    private func extractICSDate(from line: String) -> Date? {
        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }

        let dateString = components[1]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateString)
    }

    private func createEventFromParsed(_ parsedEvent: ParsedEvent) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = parsedEvent.title
        event.startDate = parsedEvent.startDate
        event.endDate = parsedEvent.endDate
        event.location = parsedEvent.location
        event.notes = parsedEvent.notes
        event.isAllDay = parsedEvent.isAllDay
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
    }

    // MARK: - Backup & Restore

    func createBackup() -> Data? {
        let backup = BackupData(
            exportDate: Date(),
            version: "1.0",
            preferences: UserDefaults.standard.dictionaryRepresentation(),
            categories: loadData(forKey: "event_categories"),
            savedSearches: loadData(forKey: "saved_filters"),
            worldClocks: loadData(forKey: "favorite_timezones"),
            meetingNotes: loadData(forKey: "meeting_notes"),
            teams: loadData(forKey: "teams"),
            subscriptions: loadData(forKey: "calendar_subscriptions")
        )

        return try? JSONEncoder().encode(backup)
    }

    func restoreBackup(data: Data) throws {
        let backup = try JSONDecoder().decode(BackupData.self, from: data)

        // Restore each component
        if let categories = backup.categories {
            UserDefaults.standard.set(categories, forKey: "event_categories")
        }

        if let searches = backup.savedSearches {
            UserDefaults.standard.set(searches, forKey: "saved_filters")
        }

        if let clocks = backup.worldClocks {
            UserDefaults.standard.set(clocks, forKey: "favorite_timezones")
        }

        if let notes = backup.meetingNotes {
            UserDefaults.standard.set(notes, forKey: "meeting_notes")
        }

        if let teams = backup.teams {
            UserDefaults.standard.set(teams, forKey: "teams")
        }

        if let subscriptions = backup.subscriptions {
            UserDefaults.standard.set(subscriptions, forKey: "calendar_subscriptions")
        }

        // Notify of restore
        NotificationCenter.default.post(name: .backupRestored, object: nil)
    }

    private func loadData(forKey key: String) -> Data? {
        return UserDefaults.standard.data(forKey: key)
    }

    struct BackupData: Codable {
        let exportDate: Date
        let version: String
        let preferences: [String: Any]?
        let categories: Data?
        let savedSearches: Data?
        let worldClocks: Data?
        let meetingNotes: Data?
        let teams: Data?
        let subscriptions: Data?

        enum CodingKeys: String, CodingKey {
            case exportDate, version, categories, savedSearches,
                 worldClocks, meetingNotes, teams, subscriptions
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(exportDate, forKey: .exportDate)
            try container.encode(version, forKey: .version)
            try container.encodeIfPresent(categories, forKey: .categories)
            try container.encodeIfPresent(savedSearches, forKey: .savedSearches)
            try container.encodeIfPresent(worldClocks, forKey: .worldClocks)
            try container.encodeIfPresent(meetingNotes, forKey: .meetingNotes)
            try container.encodeIfPresent(teams, forKey: .teams)
            try container.encodeIfPresent(subscriptions, forKey: .subscriptions)
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            exportDate = try container.decode(Date.self, forKey: .exportDate)
            version = try container.decode(String.self, forKey: .version)
            preferences = nil
            categories = try container.decodeIfPresent(Data.self, forKey: .categories)
            savedSearches = try container.decodeIfPresent(Data.self, forKey: .savedSearches)
            worldClocks = try container.decodeIfPresent(Data.self, forKey: .worldClocks)
            meetingNotes = try container.decodeIfPresent(Data.self, forKey: .meetingNotes)
            teams = try container.decodeIfPresent(Data.self, forKey: .teams)
            subscriptions = try container.decodeIfPresent(Data.self, forKey: .subscriptions)
        }

        init(exportDate: Date, version: String, preferences: [String: Any]?,
             categories: Data?, savedSearches: Data?, worldClocks: Data?,
             meetingNotes: Data?, teams: Data?, subscriptions: Data?) {
            self.exportDate = exportDate
            self.version = version
            self.preferences = preferences
            self.categories = categories
            self.savedSearches = savedSearches
            self.worldClocks = worldClocks
            self.meetingNotes = meetingNotes
            self.teams = teams
            self.subscriptions = subscriptions
        }
    }

    // MARK: - Save Dialog

    func saveFile(content: String, fileName: String, fileExtension: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(fileName).\(fileExtension)"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func saveDataFile(data: Data, fileName: String, fileExtension: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(fileName).\(fileExtension)"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - Open Dialog

    func openFile(completion: @escaping (Data?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                let data = try? Data(contentsOf: url)
                completion(data)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let backupRestored = Notification.Name("backupRestored")
}
