//
//  SmartBufferTimeView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct SmartBufferTimeView: View {
    @EnvironmentObject var bufferManager: SmartBufferTimeManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var showingSettings = false
    @State private var actionAlert: BufferActionAlert?

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    private struct BufferActionAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                if !eventKitManager.hasCalendarAccess {
                    calendarAccessState
                } else {
                    statsCard
                    suggestionsCard
                    bufferSuggestionsList
                    settingsSection
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .calendarppModal(isPresented: $showingSettings) {
            BufferSettingsView(
                preferences: bufferManager.preferences,
                onSave: { newPrefs in
                    bufferManager.updatePreferences(newPrefs)
                    showingSettings = false
                }
            )
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            refreshAnalysis()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshAnalysis()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshAnalysis()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshAnalysis()
        }
        .onReceive(bufferManager.$preferences) { _ in
            refreshAnalysis()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Buffer Time")
                    .font(.system(size: 24, weight: .bold))
                Text("Prevent meeting burnout")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showingSettings = true }) {
                Label("Settings", systemImage: "gear")
            }
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
            Text("Enable calendar permission to suggest smart buffer time.")
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

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("Back-to-back")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(bufferManager.backToBackCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Average gap")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(Int(bufferManager.averageGapMinutes)) min")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Needs buffer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("\(bufferManager.bufferSuggestions.count)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Recommendation")
                    .font(.headline)
            }

            Text(bufferManager.suggestOptimalBufferPattern())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private var bufferSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Buffer Suggestions")
                    .font(.headline)

                Spacer()

                if !bufferManager.bufferSuggestions.isEmpty {
                    Button("Dismiss All") {
                        bufferManager.dismissAllSuggestions()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
            }

            if bufferManager.bufferSuggestions.isEmpty {
                emptyStateView
            } else {
                ForEach(bufferManager.bufferSuggestions) { suggestion in
                    BufferSuggestionCard(
                        suggestion: suggestion,
                        onAdd: {
                            let result = bufferManager.addBufferTime(for: suggestion, using: eventKitManager)
                            switch result {
                            case .success(let message):
                                actionAlert = BufferActionAlert(title: "Buffer Added", message: message)
                            case .failure(let error):
                                actionAlert = BufferActionAlert(title: "Could Not Add Buffer", message: error.localizedDescription)
                            }
                        },
                        onDismiss: {
                            bufferManager.dismissSuggestion(suggestion)
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

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Settings")
                .font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Minimum buffer time")
                        .font(.subheadline)
                    Spacer()
                    Text("\(bufferManager.preferences.minimumBufferMinutes) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Standard buffer time")
                        .font(.subheadline)
                    Spacer()
                    Text("\(bufferManager.preferences.standardBufferMinutes) min")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Auto-add buffers")
                        .font(.subheadline)
                    Spacer()
                    Text(bufferManager.preferences.autoAddBuffers ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Button("Configure Settings") {
                showingSettings = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            Text("No buffer suggestions")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Your meeting spacing looks good!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func refreshAnalysis() {
        guard eventKitManager.hasCalendarAccess else { return }
        bufferManager.analyzeMeetings(events: visibleEvents)
    }
}

struct BufferSuggestionCard: View {
    let suggestion: BufferSuggestion
    let onAdd: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(suggestion.reason.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.reason.description)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if suggestion.gapMinutes > 0 {
                        Text("Current gap: \(suggestion.gapMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No gap - back-to-back")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Add buffer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(suggestion.suggestedBufferMinutes) min")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(formatTime(suggestion.beforeEvent.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text(suggestion.beforeEvent.title)
                        .font(.caption)
                        .lineLimit(1)
                }

                HStack {
                    Text(formatTime(suggestion.afterEvent.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)

                    Text(suggestion.afterEvent.title)
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            HStack {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Add Buffer") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct BufferSettingsView: View {
    @Environment(\.dismiss) var dismiss
    var preferences: BufferPreferences
    let onSave: (BufferPreferences) -> Void

    @State private var minimumBuffer: Int
    @State private var standardBuffer: Int
    @State private var longMeetingThreshold: Int
    @State private var longMeetingBuffer: Int
    @State private var differentLocationBuffer: Int
    @State private var autoAdd: Bool

    init(preferences: BufferPreferences, onSave: @escaping (BufferPreferences) -> Void) {
        self.preferences = preferences
        self.onSave = onSave
        _minimumBuffer = State(initialValue: preferences.minimumBufferMinutes)
        _standardBuffer = State(initialValue: preferences.standardBufferMinutes)
        _longMeetingThreshold = State(initialValue: preferences.longMeetingThreshold)
        _longMeetingBuffer = State(initialValue: preferences.longMeetingBufferMinutes)
        _differentLocationBuffer = State(initialValue: preferences.differentLocationBufferMinutes)
        _autoAdd = State(initialValue: preferences.autoAddBuffers)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Buffer Settings")
                .font(.headline)

            Form {
                Section("Buffer Durations") {
                    Stepper("Minimum buffer: \(minimumBuffer) min", value: $minimumBuffer, in: 0...30, step: 5)
                    Stepper("Standard buffer: \(standardBuffer) min", value: $standardBuffer, in: 5...30, step: 5)
                }

                Section("Long Meetings") {
                    Stepper("Long meeting threshold: \(longMeetingThreshold) min", value: $longMeetingThreshold, in: 30...120, step: 15)
                    Stepper("Long meeting buffer: \(longMeetingBuffer) min", value: $longMeetingBuffer, in: 10...30, step: 5)
                }

                Section("Travel Time") {
                    Stepper("Different location buffer: \(differentLocationBuffer) min", value: $differentLocationBuffer, in: 10...60, step: 5)
                }

                Section("Automation") {
                    Toggle("Automatically add buffers", isOn: $autoAdd)
                        .help("Automatically suggest adding buffer time when scheduling new meetings")
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
                    let newPrefs = BufferPreferences(
                        minimumBufferMinutes: minimumBuffer,
                        standardBufferMinutes: standardBuffer,
                        longMeetingThreshold: longMeetingThreshold,
                        longMeetingBufferMinutes: longMeetingBuffer,
                        differentLocationBufferMinutes: differentLocationBuffer,
                        autoAddBuffers: autoAdd
                    )
                    onSave(newPrefs)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500)
        .padding()
    }
}

struct SmartBufferTimeView_Previews: PreviewProvider {
    static var previews: some View {
        SmartBufferTimeView()
            .environmentObject(SmartBufferTimeManager())
            .environmentObject(EventKitManager())
    }
}
