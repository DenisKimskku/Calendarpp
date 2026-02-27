//
//  MeetingNotesManager.swift
//  calendar++
//
//  Manages meeting notes linked to calendar events
//

import Foundation
import EventKit
import Combine

// MARK: - Meeting Note Model

struct MeetingNote: Identifiable, Codable {
    let id: UUID
    var eventID: String // Link to calendar event
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var attendees: [String]
    var agenda: [AgendaItem]
    var actionItems: [ActionItem]
    var decisions: [String]
    var tags: [String]
    var template: NoteTemplate?

    init(
        id: UUID = UUID(),
        eventID: String,
        title: String = "",
        content: String = "",
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        attendees: [String] = [],
        agenda: [AgendaItem] = [],
        actionItems: [ActionItem] = [],
        decisions: [String] = [],
        tags: [String] = [],
        template: NoteTemplate? = nil
    ) {
        self.id = id
        self.eventID = eventID
        self.title = title
        self.content = content
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.attendees = attendees
        self.agenda = agenda
        self.actionItems = actionItems
        self.decisions = decisions
        self.tags = tags
        self.template = template
    }

    mutating func update(content: String) {
        self.content = content
        self.modifiedDate = Date()
    }
}

// MARK: - Agenda Item

struct AgendaItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval?
    var presenter: String?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval? = nil,
        presenter: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.presenter = presenter
        self.isCompleted = isCompleted
    }
}

// MARK: - Action Item

struct ActionItem: Identifiable, Codable {
    let id: UUID
    var task: String
    var assignee: String?
    var dueDate: Date?
    var priority: Priority
    var isCompleted: Bool

    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"

        var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "orange"
            case .urgent: return "red"
            }
        }
    }

    init(
        id: UUID = UUID(),
        task: String,
        assignee: String? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.task = task
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
    }
}

// MARK: - Note Template

enum NoteTemplate: String, Codable, CaseIterable {
    case blank = "Blank"
    case standup = "Daily Standup"
    case oneOnOne = "1:1 Meeting"
    case retrospective = "Retrospective"
    case planning = "Planning Session"
    case brainstorming = "Brainstorming"
    case review = "Review Meeting"

    var structure: String {
        switch self {
        case .blank:
            return ""

        case .standup:
            return """
            # Daily Standup

            ## What did you accomplish yesterday?
            -

            ## What will you work on today?
            -

            ## Any blockers or challenges?
            -
            """

        case .oneOnOne:
            return """
            # 1:1 Meeting

            ## Recent Wins
            -

            ## Challenges
            -

            ## Career Development
            -

            ## Feedback
            -

            ## Action Items
            -
            """

        case .retrospective:
            return """
            # Sprint Retrospective

            ## What went well?
            -

            ## What could be improved?
            -

            ## Action items for next sprint
            -
            """

        case .planning:
            return """
            # Planning Session

            ## Goals
            -

            ## Timeline
            -

            ## Resources Needed
            -

            ## Dependencies
            -

            ## Risks
            -
            """

        case .brainstorming:
            return """
            # Brainstorming Session

            ## Problem Statement


            ## Ideas
            -

            ## Next Steps
            -
            """

        case .review:
            return """
            # Review Meeting

            ## Summary


            ## Feedback
            -

            ## Decisions Made
            -

            ## Next Steps
            -
            """
        }
    }
}

// MARK: - Meeting Notes Manager

class MeetingNotesManager: ObservableObject {
    @Published var notes: [MeetingNote] = []

    private let notesKey = "meeting_notes"
    private let eventStore = EKEventStore()

    init() {
        loadNotes()
    }

    // MARK: - CRUD Operations

    func createNote(for eventID: String, template: NoteTemplate? = nil) -> MeetingNote {
        // Get event details
        var title = "Meeting Notes"
        var attendees: [String] = []

        if let event = eventStore.event(withIdentifier: eventID) {
            title = "Notes: \(event.title ?? "Meeting")"

            // Extract attendees
            attendees = event.attendees?.compactMap { attendee in
                attendee.name
            } ?? []
        }

        var note = MeetingNote(
            eventID: eventID,
            title: title,
            attendees: attendees,
            template: template
        )

        // Apply template
        if let template = template {
            note.content = template.structure
        }

        notes.append(note)
        saveNotes()

        return note
    }

    func updateNote(_ note: MeetingNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            notes[index].modifiedDate = Date()
            saveNotes()
        }
    }

    func deleteNote(_ note: MeetingNote) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }

    func getNote(for eventID: String) -> MeetingNote? {
        return notes.first { $0.eventID == eventID }
    }

    func getAllNotes() -> [MeetingNote] {
        return notes.sorted { $0.modifiedDate > $1.modifiedDate }
    }

    // MARK: - Agenda Management

    func addAgendaItem(_ item: AgendaItem, to note: MeetingNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].agenda.append(item)
            saveNotes()
        }
    }

    func updateAgendaItem(_ item: AgendaItem, in note: MeetingNote) {
        if let noteIndex = notes.firstIndex(where: { $0.id == note.id }),
           let itemIndex = notes[noteIndex].agenda.firstIndex(where: { $0.id == item.id }) {
            notes[noteIndex].agenda[itemIndex] = item
            saveNotes()
        }
    }

    func deleteAgendaItem(_ item: AgendaItem, from note: MeetingNote) {
        if let noteIndex = notes.firstIndex(where: { $0.id == note.id }) {
            notes[noteIndex].agenda.removeAll { $0.id == item.id }
            saveNotes()
        }
    }

    // MARK: - Action Item Management

    func addActionItem(_ item: ActionItem, to note: MeetingNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].actionItems.append(item)
            saveNotes()
        }
    }

    func updateActionItem(_ item: ActionItem, in note: MeetingNote) {
        if let noteIndex = notes.firstIndex(where: { $0.id == note.id }),
           let itemIndex = notes[noteIndex].actionItems.firstIndex(where: { $0.id == item.id }) {
            notes[noteIndex].actionItems[itemIndex] = item
            saveNotes()
        }
    }

    func deleteActionItem(_ item: ActionItem, from note: MeetingNote) {
        if let noteIndex = notes.firstIndex(where: { $0.id == note.id }) {
            notes[noteIndex].actionItems.removeAll { $0.id == item.id }
            saveNotes()
        }
    }

    func getOpenActionItems() -> [(note: MeetingNote, item: ActionItem)] {
        var openItems: [(MeetingNote, ActionItem)] = []

        for note in notes {
            for item in note.actionItems where !item.isCompleted {
                openItems.append((note, item))
            }
        }

        return openItems.sorted { first, second in
            // Sort by due date, then priority
            if let firstDue = first.1.dueDate, let secondDue = second.1.dueDate {
                return firstDue < secondDue
            }
            return first.1.priority.rawValue > second.1.priority.rawValue
        }
    }

    func getOverdueActionItems() -> [(note: MeetingNote, item: ActionItem)] {
        let now = Date()
        return getOpenActionItems().filter { _, item in
            if let dueDate = item.dueDate {
                return dueDate < now
            }
            return false
        }
    }

    // MARK: - Search & Filter

    func searchNotes(query: String) -> [MeetingNote] {
        let lowercasedQuery = query.lowercased()

        return notes.filter { note in
            note.title.lowercased().contains(lowercasedQuery) ||
            note.content.lowercased().contains(lowercasedQuery) ||
            note.attendees.contains { $0.lowercased().contains(lowercasedQuery) } ||
            note.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    func filterNotesByDate(from startDate: Date, to endDate: Date) -> [MeetingNote] {
        return notes.filter { note in
            note.createdDate >= startDate && note.createdDate <= endDate
        }
    }

    func filterNotesByTag(_ tag: String) -> [MeetingNote] {
        return notes.filter { $0.tags.contains(tag) }
    }

    // MARK: - Export

    func exportNote(_ note: MeetingNote, format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return exportAsMarkdown(note)
        case .plainText:
            return exportAsPlainText(note)
        case .html:
            return exportAsHTML(note)
        }
    }

    enum ExportFormat {
        case markdown
        case plainText
        case html
    }

    private func exportAsMarkdown(_ note: MeetingNote) -> String {
        var markdown = "# \(note.title)\n\n"

        // Metadata
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short

        markdown += "**Date:** \(dateFormatter.string(from: note.createdDate))\n\n"

        if !note.attendees.isEmpty {
            markdown += "**Attendees:**\n"
            for attendee in note.attendees {
                markdown += "- \(attendee)\n"
            }
            markdown += "\n"
        }

        // Agenda
        if !note.agenda.isEmpty {
            markdown += "## Agenda\n\n"
            for item in note.agenda {
                let status = item.isCompleted ? "✅" : "⬜️"
                markdown += "\(status) \(item.title)"
                if let presenter = item.presenter {
                    markdown += " (Presenter: \(presenter))"
                }
                if let duration = item.duration {
                    markdown += " [\(Int(duration / 60)) min]"
                }
                markdown += "\n"
            }
            markdown += "\n"
        }

        // Content
        if !note.content.isEmpty {
            markdown += "## Notes\n\n"
            markdown += note.content
            markdown += "\n\n"
        }

        // Decisions
        if !note.decisions.isEmpty {
            markdown += "## Decisions\n\n"
            for decision in note.decisions {
                markdown += "- \(decision)\n"
            }
            markdown += "\n"
        }

        // Action Items
        if !note.actionItems.isEmpty {
            markdown += "## Action Items\n\n"
            for item in note.actionItems {
                let status = item.isCompleted ? "✅" : "⬜️"
                markdown += "\(status) \(item.task)"

                if let assignee = item.assignee {
                    markdown += " (@\(assignee))"
                }

                if let dueDate = item.dueDate {
                    let dueDateFormatter = DateFormatter()
                    dueDateFormatter.dateStyle = .short
                    markdown += " [Due: \(dueDateFormatter.string(from: dueDate))]"
                }

                markdown += " [Priority: \(item.priority.rawValue)]\n"
            }
            markdown += "\n"
        }

        // Tags
        if !note.tags.isEmpty {
            markdown += "**Tags:** \(note.tags.map { "#\($0)" }.joined(separator: " "))\n"
        }

        return markdown
    }

    private func exportAsPlainText(_ note: MeetingNote) -> String {
        // Similar to markdown but without formatting
        return exportAsMarkdown(note)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "✅", with: "[X]")
            .replacingOccurrences(of: "⬜️", with: "[ ]")
    }

    private func exportAsHTML(_ note: MeetingNote) -> String {
        let markdown = exportAsMarkdown(note)

        // Basic markdown to HTML conversion
        var html = "<html><head><style>"
        html += "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 20px; }"
        html += "h1 { color: #333; }"
        html += "h2 { color: #666; margin-top: 20px; }"
        html += "ul { list-style-type: none; }"
        html += "</style></head><body>"

        html += markdown
            .replacingOccurrences(of: "# ", with: "<h1>").replacingOccurrences(of: "\n\n", with: "</h1>")
            .replacingOccurrences(of: "## ", with: "<h2>").replacingOccurrences(of: "\n", with: "</h2>")
            .replacingOccurrences(of: "- ", with: "<li>").replacingOccurrences(of: "\n", with: "</li>")
            .replacingOccurrences(of: "**", with: "<strong>").replacingOccurrences(of: "**", with: "</strong>")

        html += "</body></html>"

        return html
    }

    // MARK: - Statistics

    func getTotalNotes() -> Int {
        return notes.count
    }

    func getTotalActionItems() -> Int {
        return notes.reduce(0) { $0 + $1.actionItems.count }
    }

    func getCompletedActionItems() -> Int {
        return notes.reduce(0) { count, note in
            count + note.actionItems.filter { $0.isCompleted }.count
        }
    }

    func getActionItemCompletionRate() -> Double {
        let total = getTotalActionItems()
        guard total > 0 else { return 0 }

        let completed = getCompletedActionItems()
        return Double(completed) / Double(total) * 100
    }

    // MARK: - Persistence

    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: notesKey)
        }
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([MeetingNote].self, from: data) {
            notes = decoded
        }
    }
}
