//
//  FocusTimeProtectionView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI
import Combine

struct FocusTimeProtectionView: View {
    @EnvironmentObject var focusProtection: FocusTimeProtectionManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var showingAddBlock = false
    @State private var editingBlock: FocusTimeBlock?

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if !eventKitManager.hasCalendarAccess {
                    calendarAccessState
                } else {
                    focusScoreCard
                    conflictsSection
                    focusBlocksList
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .calendarppModal(isPresented: $showingAddBlock) {
            AddFocusBlockView(onSave: { block in
                focusProtection.addFocusBlock(block)
                showingAddBlock = false
            })
        }
        .calendarppModal(item: $editingBlock) { block in
            EditFocusBlockView(block: block, onSave: { updatedBlock in
                focusProtection.updateFocusBlock(updatedBlock)
                editingBlock = nil
            })
        }
        .onAppear {
            refreshConflicts()
        }
        .onReceive(eventKitManager.$eventsByDay.combineLatest(eventKitManager.$googleEventsByDay)) { _, _ in
            refreshConflicts()
        }
        .onReceive(focusProtection.$focusBlocks) { _ in
            refreshConflicts()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshConflicts()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Time Protection")
                    .font(.system(size: 24, weight: .bold))
                Text("Defend your deep work time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showingAddBlock = true }) {
                Label("Add Block", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.bottom, 10)
    }

    private var calendarAccessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Calendar access is required")
                .font(.headline)
            Text("Enable calendar permission to detect focus-time conflicts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Grant Calendar Access") {
                eventKitManager.requestAccessIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var focusScoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Score")
                    .font(.headline)

                Spacer()

                Text(String(format: "%.0f%%", focusProtection.focusScore))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(scoreColor)
            }

            // Score bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(scoreColor)
                        .frame(width: geometry.size.width * (focusProtection.focusScore / 100))
                }
            }
            .frame(height: 8)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f hrs", focusProtection.protectedHoursThisWeek))
                        .font(.headline)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Stolen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f hrs", focusProtection.stolenHoursThisWeek))
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }

            Text(scoreMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var conflictsSection: some View {
        Group {
            if !focusProtection.conflictingMeetings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Conflicts Detected")
                            .font(.headline)
                    }

                    ForEach(focusProtection.conflictingMeetings) { conflict in
                        ConflictCard(conflict: conflict, onDecline: {
                            focusProtection.declineMeeting(conflict)
                        })
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private var focusBlocksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Blocks")
                .font(.headline)

            if focusProtection.focusBlocks.isEmpty {
                emptyStateView
            } else {
                ForEach(focusProtection.focusBlocks) { block in
                    FocusBlockRow(
                        block: block,
                        onToggle: {
                            focusProtection.toggleBlockActive(block)
                        },
                        onEdit: {
                            editingBlock = block
                        },
                        onDelete: {
                            focusProtection.deleteFocusBlock(block)
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No focus blocks yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Add Your First Block") {
                showingAddBlock = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var scoreColor: Color {
        let score = focusProtection.focusScore
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .blue
        } else if score >= 40 {
            return .yellow
        } else {
            return .red
        }
    }

    private var scoreMessage: String {
        let score = focusProtection.focusScore
        if score >= 80 {
            return "Excellent! You're protecting your focus time well."
        } else if score >= 60 {
            return "Good, but some focus time is being compromised."
        } else if score >= 40 {
            return "Warning: Significant focus time conflicts detected."
        } else {
            return "Alert: Most of your focus time is being taken by meetings."
        }
    }

    private func refreshConflicts() {
        guard eventKitManager.hasCalendarAccess else { return }
        focusProtection.checkConflicts(events: visibleEvents)
    }
}

struct FocusBlockRow: View {
    let block: FocusTimeBlock
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { block.isActive },
                set: { newValue in
                    // Prevent accidental double-toggles if SwiftUI replays the setter.
                    guard newValue != block.isActive else { return }
                    onToggle()
                }
            ))
                .labelsHidden()
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label(block.dayName, systemImage: "calendar")
                    Label("\(block.startTime) - \(block.endTime)", systemImage: "clock")
                    Label("\(block.durationMinutes) min", systemImage: "hourglass")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if block.autoDeclineConflicts {
                    Label("Auto-decline enabled", systemImage: "checkmark.shield.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(block.isActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
}

struct ConflictCard: View {
    let conflict: ConflictingMeeting
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conflict.event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Conflicts with: \(conflict.focusBlock.title)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if conflict.conflictType == .complete {
                    Text("Full")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.2)))
                        .foregroundColor(.red)
                } else {
                    Text("Partial")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Text(formatEventTime(conflict.event))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Suggest Decline") {
                    onDecline()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copies a suggested decline message and opens Calendar.app at the meeting time.")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func formatEventTime(_ event: EventSummary) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}

// MARK: - Add/Edit Views

struct AddFocusBlockView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (FocusTimeBlock) -> Void

    @State private var title = "Focus Time"
    @State private var selectedDay = 2 // Monday
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var durationMinutes = 120
    @State private var autoDecline = false
    @State private var declineMessage = "I'm protecting this time for deep work. Can we reschedule?"

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Focus Block")
                .font(.headline)

            Form {
                TextField("Title", text: $title)

                Picker("Day", selection: $selectedDay) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Tuesday").tag(3)
                    Text("Wednesday").tag(4)
                    Text("Thursday").tag(5)
                    Text("Friday").tag(6)
                    Text("Saturday").tag(7)
                }

                HStack {
                    Picker("Start Hour", selection: $startHour) {
                        ForEach(0..<24) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .frame(width: 100)

                    Text(":")

                    Picker("Start Minute", selection: $startMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .frame(width: 100)
                }

                Picker("Duration", selection: $durationMinutes) {
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                    Text("1.5 hours").tag(90)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                    Text("4 hours").tag(240)
                }

                Toggle("Auto-decline conflicts", isOn: $autoDecline)

                if autoDecline {
                    TextEditor(text: $declineMessage)
                        .frame(height: 60)
                        .border(Color.gray.opacity(0.2))
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let block = FocusTimeBlock(
                        title: title,
                        dayOfWeek: selectedDay,
                        startHour: startHour,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        autoDeclineConflicts: autoDecline,
                        declineMessage: declineMessage
                    )
                    onSave(block)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400)
        .padding()
    }
}

struct EditFocusBlockView: View {
    @Environment(\.dismiss) var dismiss
    let block: FocusTimeBlock
    let onSave: (FocusTimeBlock) -> Void

    @State private var title: String
    @State private var selectedDay: Int
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var durationMinutes: Int
    @State private var autoDecline: Bool
    @State private var declineMessage: String

    init(block: FocusTimeBlock, onSave: @escaping (FocusTimeBlock) -> Void) {
        self.block = block
        self.onSave = onSave
        _title = State(initialValue: block.title)
        _selectedDay = State(initialValue: block.dayOfWeek)
        _startHour = State(initialValue: block.startHour)
        _startMinute = State(initialValue: block.startMinute)
        _durationMinutes = State(initialValue: block.durationMinutes)
        _autoDecline = State(initialValue: block.autoDeclineConflicts)
        _declineMessage = State(initialValue: block.declineMessage)
    }

    var body: some View {
        AddFocusBlockView(onSave: { _ in
            var updatedBlock = block
            updatedBlock.title = title
            updatedBlock.dayOfWeek = selectedDay
            updatedBlock.startHour = startHour
            updatedBlock.startMinute = startMinute
            updatedBlock.durationMinutes = durationMinutes
            updatedBlock.autoDeclineConflicts = autoDecline
            updatedBlock.declineMessage = declineMessage
            onSave(updatedBlock)
            dismiss()
        })
    }
}

struct FocusTimeProtectionView_Previews: PreviewProvider {
    static var previews: some View {
        FocusTimeProtectionView()
            .environmentObject(FocusTimeProtectionManager())
            .environmentObject(EventKitManager())
    }
}
