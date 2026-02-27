//
//  MeetingNotesView.swift
//  calendar++
//
//  UI for creating and managing meeting notes
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Meeting Notes List View

struct MeetingNotesListView: View {
    @StateObject private var notesManager = MeetingNotesManager()
    @State private var searchQuery: String = ""
    @State private var showingCreateNote = false
    @State private var selectedNote: MeetingNote?

    var filteredNotes: [MeetingNote] {
        if searchQuery.isEmpty {
            return notesManager.getAllNotes()
        } else {
            return notesManager.searchNotes(query: searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Meeting Notes")
                    .font(.headline)
                Spacer()
                Button {
                    showingCreateNote = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes...", text: $searchQuery)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))

            // Notes List
            if filteredNotes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredNotes) { note in
                            NoteCard(note: note) {
                                selectedNote = note
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 600)
        .calendarppModal(item: $selectedNote) { note in
            MeetingNoteEditorView(note: note, manager: notesManager)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No meeting notes")
                .foregroundColor(.secondary)
            Button("Create Your First Note") {
                showingCreateNote = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Note Card

struct NoteCard: View {
    let note: MeetingNote
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(note.title)
                    .font(.headline)
                    .lineLimit(2)

                // Date
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(formatDate(note.createdDate))
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                // Preview
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                // Stats
                HStack(spacing: 16) {
                    if !note.attendees.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                            Text("\(note.attendees.count)")
                                .font(.caption2)
                        }
                    }

                    if !note.actionItems.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                            Text("\(note.actionItems.filter { $0.isCompleted }.count)/\(note.actionItems.count)")
                                .font(.caption2)
                        }
                    }

                    if !note.tags.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption2)
                            Text("\(note.tags.count)")
                                .font(.caption2)
                        }
                    }
                }
                .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Meeting Note Editor

struct MeetingNoteEditorView: View {
    @State var note: MeetingNote
    @ObservedObject var manager: MeetingNotesManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: Tab = .notes

    enum Tab {
        case notes
        case agenda
        case actionItems
        case decisions
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                TextField("Meeting Title", text: $note.title)
                    .font(.headline)
                    .textFieldStyle(.plain)

                Spacer()

                Button("Export") {
                    exportNote()
                }

                Button("Done") {
                    saveAndClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Tab Bar
            Picker("Section", selection: $selectedTab) {
                Text("Notes").tag(Tab.notes)
                Text("Agenda").tag(Tab.agenda)
                Text("Actions").tag(Tab.actionItems)
                Text("Decisions").tag(Tab.decisions)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .notes:
                        notesTab
                    case .agenda:
                        agendaTab
                    case .actionItems:
                        actionItemsTab
                    case .decisions:
                        decisionsTab
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
    }

    // MARK: - Notes Tab

    private var notesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Attendees
            Section {
                Text("Attendees")
                    .font(.subheadline.bold())

                if note.attendees.isEmpty {
                    Text("No attendees")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(note.attendees, id: \.self) { attendee in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                Text(attendee)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            Divider()

            // Main Notes
            Section {
                Text("Notes")
                    .font(.subheadline.bold())

                TextEditor(text: $note.content)
                    .frame(minHeight: 300)
                    .border(Color.gray.opacity(0.3))
            }

            // Tags
            Section {
                Text("Tags")
                    .font(.subheadline.bold())

                HStack {
                    ForEach(note.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Agenda Tab

    private var agendaTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agenda Items")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    let newItem = AgendaItem(title: "New agenda item")
                    manager.addAgendaItem(newItem, to: note)
                    note = manager.notes.first { $0.id == note.id }!
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if note.agenda.isEmpty {
                Text("No agenda items")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(note.agenda.indices, id: \.self) { index in
                    AgendaItemRow(
                        item: $note.agenda[index],
                        onDelete: {
                            manager.deleteAgendaItem(note.agenda[index], from: note)
                            note = manager.notes.first { $0.id == note.id }!
                        }
                    )
                }
            }
        }
    }

    // MARK: - Action Items Tab

    private var actionItemsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Action Items")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    let newItem = ActionItem(task: "New action item")
                    manager.addActionItem(newItem, to: note)
                    note = manager.notes.first { $0.id == note.id }!
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if note.actionItems.isEmpty {
                Text("No action items")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(note.actionItems.indices, id: \.self) { index in
                    ActionItemRow(
                        item: $note.actionItems[index],
                        onDelete: {
                            manager.deleteActionItem(note.actionItems[index], from: note)
                            note = manager.notes.first { $0.id == note.id }!
                        }
                    )
                }
            }

            // Summary
            if !note.actionItems.isEmpty {
                HStack {
                    Text("Completed: \(note.actionItems.filter { $0.isCompleted }.count)/\(note.actionItems.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    let completionRate = Double(note.actionItems.filter { $0.isCompleted }.count) / Double(note.actionItems.count) * 100
                    Text("\(Int(completionRate))%")
                        .font(.caption.bold())
                        .foregroundColor(completionRate == 100 ? .green : .blue)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Decisions Tab

    private var decisionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Decisions Made")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    note.decisions.append("New decision")
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if note.decisions.isEmpty {
                Text("No decisions recorded")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(note.decisions.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)

                        TextField("Decision", text: $note.decisions[index])
                            .textFieldStyle(.plain)

                        Button {
                            note.decisions.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveAndClose() {
        manager.updateNote(note)
        dismiss()
    }

    private func exportNote() {
        let markdown = manager.exportNote(note, format: .markdown)

        // Save to file
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(note.title).md"
        panel.allowedContentTypes = [.plainText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Agenda Item Row

struct AgendaItemRow: View {
    @Binding var item: AgendaItem
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Agenda item", text: $item.title)
                    .textFieldStyle(.plain)
                    .font(.headline)

                HStack {
                    if let presenter = item.presenter {
                        Text("Presenter: \(presenter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let duration = item.duration {
                        Text("\(Int(duration / 60)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Action Item Row

struct ActionItemRow: View {
    @Binding var item: ActionItem
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Action item", text: $item.task)
                    .textFieldStyle(.plain)
                    .font(.headline)

                HStack {
                    if let assignee = item.assignee {
                        Text("@\(assignee)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if let dueDate = item.dueDate {
                        Text("Due: \(formatDueDate(dueDate))")
                            .font(.caption)
                            .foregroundColor(dueDate < Date() ? .red : .secondary)
                    }

                    // Priority badge
                    Text(item.priority.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(item.priority).opacity(0.2))
                        .foregroundColor(priorityColor(item.priority))
                        .cornerRadius(4)
                }
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func priorityColor(_ priority: ActionItem.Priority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    MeetingNotesListView()
}
