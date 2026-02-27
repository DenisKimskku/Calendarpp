//
//  NaturalLanguageCommandsView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct NaturalLanguageCommandsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.calendarPPPresentationContext) private var presentationContext
    @EnvironmentObject var commandsManager: NaturalLanguageCommandsManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var commandInput = ""
    @State private var performChanges = false
    @FocusState private var isInputFocused: Bool

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Close button header
            HStack {
                Text("Voice Commands")
                    .font(.system(size: 22, weight: .bold))

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VStack(spacing: 20) {
                headerSection

                if !eventKitManager.hasCalendarAccess {
                    calendarAccessState
                } else {
                    commandInputSection
                    suggestionsSection

                    if let result = commandsManager.lastResult {
                        resultSection(result)
                    }

                    historySection
                }
            }
            .padding()
        }
        .frame(
            maxWidth: presentationContext == .menuBar ? nil : .infinity,
            maxHeight: presentationContext == .menuBar ? nil : .infinity,
            alignment: .topLeading
        )
        .frame(
            width: presentationContext == .menuBar ? 600 : nil,
            height: presentationContext == .menuBar ? 500 : nil
        )
        .onAppear {
            isInputFocused = true
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Natural Language Commands")
                .font(.system(size: 24, weight: .bold))
            Text("Control your calendar with plain English")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarAccessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Calendar access is required")
                .font(.headline)
            Text("Enable calendar permission to run commands.")
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

    private var commandInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What would you like to do?")
                .font(.subheadline)
                .fontWeight(.semibold)

            Toggle("Apply changes to your calendar", isOn: $performChanges)
                .help("When enabled, commands will create/move/shorten/extend/cancel real calendar events.")

            HStack {
                TextField("e.g., Move my 2pm to tomorrow", text: $commandInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }

                Button("Execute") {
                    executeCommand()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandInput.isEmpty)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example Commands")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(commandsManager.getSuggestions(), id: \.self) { suggestion in
                    Button(action: {
                        commandInput = suggestion
                    }) {
                        Text(suggestion)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func resultSection(_ result: CommandResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                Text("Result")
                    .font(.headline)
            }

            Text(result.message)
                .font(.subheadline)

            if !result.affectedEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Affected Events:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ForEach(result.affectedEvents) { event in
                        HStack {
                            Text("•")
                            Text(event.title)
                                .font(.caption)
                            Spacer()
                            Text(formatTime(event.startDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var historySection: some View {
        Group {
            if !commandsManager.commandHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Commands")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(commandsManager.commandHistory.reversed(), id: \.self) { cmd in
                                Button(action: {
                                    commandInput = cmd
                                }) {
                                    Text(cmd)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 80)
                }
            }
        }
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        guard eventKitManager.hasCalendarAccess else { return }

        _ = commandsManager.processCommand(
            commandInput,
            events: visibleEvents,
            eventKitManager: eventKitManager,
            performChanges: performChanges
        )

        // Clear input
        commandInput = ""
        isInputFocused = true
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NaturalLanguageCommandsView_Previews: PreviewProvider {
    static var previews: some View {
        NaturalLanguageCommandsView()
            .environmentObject(NaturalLanguageCommandsManager())
            .environmentObject(EventKitManager())
            .environmentObject(CalendarFilterManager())
    }
}
