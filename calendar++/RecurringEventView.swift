//
//  RecurringEventView.swift
//  calendar++
//
//  UI for creating and managing recurring events
//

import SwiftUI
import EventKit

struct RecurringEventView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @StateObject private var recurringManager = RecurringEventsManager()

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var duration: TimeInterval = 3600 // 1 hour
    @State private var location: String = ""
    @State private var notes: String = ""

    @State private var selectedPattern: RecurrencePattern = .daily
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date().addingTimeInterval(30 * 24 * 3600) // 30 days
    @State private var hasOccurrenceLimit: Bool = false
    @State private var occurrenceCount: Int = 10

    @State private var selectedDaysOfWeek: Set<Int> = []
    @State private var dayOfMonth: Int = 1

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Recurring Event")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Basic Info
                    Section {
                        TextField("Event Title", text: $title)
                            .textFieldStyle(.roundedBorder)

                        TextField("Location (optional)", text: $location)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Date & Time
                    Section {
                        Text("Date & Time")
                            .font(.subheadline.bold())

                        DatePicker("Start", selection: $startDate)
                            .datePickerStyle(.compact)

                        HStack {
                            Text("Duration")
                            Spacer()
                            Picker("Duration", selection: $duration) {
                                Text("15 min").tag(TimeInterval(900))
                                Text("30 min").tag(TimeInterval(1800))
                                Text("1 hour").tag(TimeInterval(3600))
                                Text("2 hours").tag(TimeInterval(7200))
                                Text("4 hours").tag(TimeInterval(14400))
                            }
                            .labelsHidden()
                        }
                    }

                    Divider()

                    // Recurrence Pattern
                    Section {
                        Text("Repeat")
                            .font(.subheadline.bold())

                        Picker("Pattern", selection: $selectedPattern) {
                            Text("Daily").tag(RecurrencePattern.daily)
                            Text("Weekly").tag(RecurrencePattern.weekly(daysOfWeek: []))
                            Text("Monthly").tag(RecurrencePattern.monthly(dayOfMonth: 1))
                            Text("Yearly").tag(RecurrencePattern.yearly)
                        }
                        .pickerStyle(.segmented)

                        // Weekly: Select days
                        if case .weekly = selectedPattern {
                            WeekdaySelector(selectedDays: $selectedDaysOfWeek)
                        }

                        // Monthly: Select day
                        if case .monthly = selectedPattern {
                            Stepper("Day of month: \(dayOfMonth)", value: $dayOfMonth, in: 1...31)
                        }
                    }

                    Divider()

                    // End Condition
                    Section {
                        Text("End")
                            .font(.subheadline.bold())

                        Toggle("End date", isOn: $hasEndDate)

                        if hasEndDate {
                            DatePicker("Ends on", selection: $endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        Toggle("Limit occurrences", isOn: $hasOccurrenceLimit)

                        if hasOccurrenceLimit {
                            Stepper("Occurrences: \(occurrenceCount)", value: $occurrenceCount, in: 1...100)
                        }
                    }

                    Divider()

                    // Notes
                    Section {
                        Text("Notes")
                            .font(.subheadline.bold())

                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.3))
                    }

                    // Create Button
                    Button {
                        createRecurringEvent()
                    } label: {
                        Text("Create Recurring Event")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(title.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(title.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }

    private func createRecurringEvent() {
        var pattern = selectedPattern

        // Update pattern with user selections
        switch selectedPattern {
        case .weekly:
            pattern = .weekly(daysOfWeek: Array(selectedDaysOfWeek))
        case .monthly:
            pattern = .monthly(dayOfMonth: dayOfMonth)
        default:
            break
        }

        let success = recurringManager.createRecurringEvent(
            title: title,
            startDate: startDate,
            duration: duration,
            pattern: pattern,
            endDate: hasEndDate ? endDate : nil,
            occurrences: hasOccurrenceLimit ? occurrenceCount : nil,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            dismiss()
        }
    }
}

// MARK: - Weekday Selector

struct WeekdaySelector: View {
    @Binding var selectedDays: Set<Int>

    private let weekdays = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"),
        (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekdays, id: \.0) { day, label in
                Button {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(selectedDays.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Recurring Event Detail View

struct RecurringEventDetailView: View {
    let event: EKEvent
    @StateObject private var recurringManager = RecurringEventsManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title)
                .font(.title2.bold())

            if let description = recurringManager.getRecurrenceDescription(for: event) {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(.blue)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            // Modification Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Modify")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Button("Edit this event only") {
                    // Modify single occurrence
                }

                Button("Edit all future events") {
                    // Modify future occurrences
                }
            }

            Divider()

            // Deletion Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Button("Delete this event only") {
                    // Delete single occurrence
                }
                .foregroundColor(.red)

                Button("Delete all future events") {
                    // Delete future occurrences
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }
}
