//
//  EventTemplatesView.swift
//  calendar++
//
//  UI for managing and using event templates
//

import SwiftUI

struct EventTemplatesView: View {
    @EnvironmentObject var templatesManager: EventTemplatesManager
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var calendarVM: CalendarViewModel

    @State private var showingAddTemplate = false
    @State private var editingTemplate: EventTemplate?
    @State private var selectedDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Event Templates")
                    .font(.headline)

                Spacer()

                Button {
                    showingAddTemplate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Add new template")
            }

            if templatesManager.templates.isEmpty {
                Text("No templates yet. Create one to quickly add recurring events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(templatesManager.templates) { template in
                            TemplateRow(
                                template: template,
                                onUse: { useTemplate(template) },
                                onEdit: { editingTemplate = template },
                                onDelete: { templatesManager.deleteTemplate(template) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .frame(width: 400)
        .sheet(isPresented: $showingAddTemplate) {
            TemplateEditorView(
                template: nil,
                onSave: { template in
                    templatesManager.addTemplate(template)
                    showingAddTemplate = false
                }
            )
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(
                template: template,
                onSave: { updatedTemplate in
                    templatesManager.updateTemplate(updatedTemplate)
                    editingTemplate = nil
                }
            )
        }
    }

    private func useTemplate(_ template: EventTemplate) {
        let now = Date()
        let calendar = Calendar.current

        // Round to next 15-minute interval
        let minutes = calendar.component(.minute, from: now)
        let roundedMinutes = ((minutes + 14) / 15) * 15
        let minutesToAdd = roundedMinutes - minutes

        guard var startDate = calendar.date(byAdding: .minute, value: minutesToAdd, to: now) else { return }

        // If using selected date from calendar, use that instead
        if !calendar.isDateInToday(calendarVM.selectedDate) {
            let timeComps = calendar.dateComponents([.hour, .minute], from: startDate)
            var dateComps = calendar.dateComponents([.year, .month, .day], from: calendarVM.selectedDate)
            dateComps.hour = timeComps.hour
            dateComps.minute = timeComps.minute
            startDate = calendar.date(from: dateComps) ?? startDate
        }

        let endDate = calendar.date(byAdding: .minute, value: template.durationMinutes, to: startDate)!

        eventKit.createEvent(
            title: template.title,
            startDate: startDate,
            endDate: endDate,
            location: template.location,
            notes: template.notes,
            calendar: nil
        )
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: EventTemplate
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label("\(template.durationMinutes)m", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let location = template.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    onUse()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Create event from template")

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit template")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete template")
            }
        }
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Template Editor

struct TemplateEditorView: View {
    let template: EventTemplate?
    let onSave: (EventTemplate) -> Void

    @State private var name: String
    @State private var title: String
    @State private var durationMinutes: Int
    @State private var location: String
    @State private var notes: String

    @Environment(\.dismiss) var dismiss

    init(template: EventTemplate?, onSave: @escaping (EventTemplate) -> Void) {
        self.template = template
        self.onSave = onSave

        _name = State(initialValue: template?.name ?? "")
        _title = State(initialValue: template?.title ?? "")
        _durationMinutes = State(initialValue: template?.durationMinutes ?? 30)
        _location = State(initialValue: template?.location ?? "")
        _notes = State(initialValue: template?.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(template == nil ? "New Template" : "Edit Template")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Template Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Daily Standup", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Team Standup Meeting", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Stepper(value: $durationMinutes, in: 15...480, step: 15) {
                            Text("\(durationMinutes) minutes")
                                .font(.subheadline)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Conference Room A", text: $location)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(height: 60)
                        .font(.caption)
                        .border(Color.gray.opacity(0.3), width: 1)
                }
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveTemplate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || title.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }

    private func saveTemplate() {
        let newTemplate = EventTemplate(
            id: template?.id ?? UUID(),
            name: name,
            title: title,
            durationMinutes: durationMinutes,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )

        onSave(newTemplate)
        dismiss()
    }
}
