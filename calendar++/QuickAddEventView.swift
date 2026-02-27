import SwiftUI

struct QuickAddEventView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var commandsManager: NaturalLanguageCommandsManager
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Double = 60
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var useNaturalLanguage: Bool = true

    private let calendar = Calendar.current
    private let parser = SmartEventParser.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Quick add")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    useNaturalLanguage.toggle()
                } label: {
                    Image(systemName: useNaturalLanguage ? "text.bubble.fill" : "text.bubble")
                        .font(.caption)
                        .foregroundColor(useNaturalLanguage ? .accentColor : .secondary)
                        .help(useNaturalLanguage ? "Natural language mode (ON)" : "Form mode (OFF)")
                }
                .buttonStyle(.plain)
            }

            if useNaturalLanguage {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("e.g. Lunch tomorrow at 1pm", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onChange(of: title) { newValue in
                            parseAndFillFields(newValue)
                        }
                        .onSubmit {
                            submitQuickAddFromKeyboard()
                        }

                    Text("Try: \"meeting at 2pm\", \"lunch tomorrow 1-2pm\", \"dentist Friday at 9am\"")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(spacing: 6) {
                    TextField("Title (e.g. Lunch)", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            submitQuickAddFromKeyboard()
                        }

                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(width: 80)

                    Stepper(value: $durationMinutes, in: 15...240, step: 15) {
                        Text("\(Int(durationMinutes))m")
                            .font(.caption2)
                            .frame(width: 40)
                    }
                    .frame(width: 80)

                    Button {
                        createEvent()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }

                TextField("Location (optional)", text: $location)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit {
                        submitQuickAddFromKeyboard()
                    }
            }

            // Preview of parsed event (in natural language mode)
            if useNaturalLanguage && !title.isEmpty {
                if let command = detectedCommand {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.and.mic")
                            .foregroundColor(.blue)
                            .font(.caption2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Command detected")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(commandSummary(command))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            submitQuickAddFromKeyboard()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(10)
                    .calendarPPZenCard(cornerRadius: 10, strong: false)
                } else if let parsed = parser.parse(title) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(parsed.title)
                                .font(.caption)
                                .fontWeight(.medium)

                            HStack(spacing: 4) {
                                Text(formatPreviewDate(parsed.startDate))
                                    .font(.caption2)
                                Text("→")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(formatPreviewDate(parsed.endDate))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)

                            if let location = parsed.location {
                                Text("📍 \(location)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            createEventFromParsed(parsed)
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(10)
                    .calendarPPZenCard(cornerRadius: 10, strong: false)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
    }

    private func createEvent() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        // Merge selectedDate's Y/M/D with chosen time's hour/minute
        let comps = calendar.dateComponents([.hour, .minute], from: startTime)
        let baseDate = calendarVM.selectedDate
        var baseComps = calendar.dateComponents([.year, .month, .day], from: baseDate)
        baseComps.hour = comps.hour
        baseComps.minute = comps.minute

        guard let start = calendar.date(from: baseComps) else {
            isSaving = false
            errorMessage = "Could not build start date."
            return
        }

        let end = start.addingTimeInterval(durationMinutes * 60)

        let result = eventKit.createEventResult(
            title: trimmedTitle,
            startDate: start,
            endDate: end,
            location: location.isEmpty ? nil : location,
            notes: nil,
            calendar: nil
        )

        switch result {
        case .success:
            isSaving = false
            title = ""
            location = ""

            // Dismiss the QuickAdd form
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPresented = false
            }
        case .failure(let error):
            isSaving = false
            errorMessage = error.errorDescription ?? "Could not create event."
        }
    }

    private func parseAndFillFields(_ text: String) {
        // This function is called onChange in natural language mode
        // It doesn't auto-fill, but the preview shows the parsed result
        // User can toggle to form mode if they want manual control
    }

    private func submitQuickAddFromKeyboard() {
        guard !isSaving else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        errorMessage = nil

        if useNaturalLanguage {
            let command = commandsManager.parseCommand(trimmedTitle)
            if !isUnknown(command) {
                let result = commandsManager.processCommand(
                    trimmedTitle,
                    events: eventKit.events,
                    eventKitManager: eventKit,
                    performChanges: true
                )

                guard result.success else {
                    errorMessage = result.message
                    return
                }

                if shouldDismissAfterExecuting(command) {
                    clearAndDismiss()
                } else {
                    errorMessage = result.message
                }
                return
            }

            guard let parsed = parser.parse(trimmedTitle) else {
                errorMessage = "Could not parse input. Try adding a time, like \"at 4pm\"."
                return
            }
            createEventFromParsed(parsed)
            return
        }

        createEvent()
    }

    private func createEventFromParsed(_ parsed: ParsedEvent) {
        isSaving = true
        errorMessage = nil

        let result = eventKit.createEventResult(
            title: parsed.title,
            startDate: parsed.startDate,
            endDate: parsed.endDate,
            location: parsed.location,
            notes: nil,
            calendar: nil
        )
        switch result {
        case .success:
            clearAndDismiss()
        case .failure(let error):
            isSaving = false
            errorMessage = error.errorDescription ?? "Could not create event."
        }
    }

    private var detectedCommand: CalendarCommand? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard useNaturalLanguage, !trimmed.isEmpty else { return nil }
        let command = commandsManager.parseCommand(trimmed)
        return isUnknown(command) ? nil : command
    }

    private func clearAndDismiss() {
        isSaving = false
        title = ""
        location = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }

    private func isUnknown(_ command: CalendarCommand) -> Bool {
        if case .unknown = command {
            return true
        }
        return false
    }

    private func shouldDismissAfterExecuting(_ command: CalendarCommand) -> Bool {
        if case .find(_) = command {
            return false
        }
        return true
    }

    private func commandSummary(_ command: CalendarCommand) -> String {
        switch command {
        case .move(let query, _):
            return "Move \(query)"
        case .cancel(let query):
            return "Cancel \(query)"
        case .reschedule(let query, _):
            return "Reschedule \(query)"
        case .find(_):
            return "Find available time"
        case .block(let duration, _):
            return "Block \(duration) minutes"
        case .shorten(let query, let minutes):
            return "Shorten \(query) by \(minutes)m"
        case .extend(let query, let minutes):
            return "Extend \(query) by \(minutes)m"
        case .addBuffer(let query, let minutes):
            return "Add \(minutes)m buffer for \(query)"
        case .unknown:
            return "Unknown command"
        }
    }

    private func formatPreviewDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
