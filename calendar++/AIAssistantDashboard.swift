//
//  AIAssistantDashboard.swift
//  calendar++
//
//  Phase 8: AI/ML Integration Hub
//

import SwiftUI

struct AIAssistantDashboard: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.calendarPPPresentationContext) private var presentationContext
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var smartScheduler: SmartSchedulingAssistant
    @EnvironmentObject var eventCategorizer: EventCategorizationML
    @EnvironmentObject var bufferManager: SmartBufferTimeManager
    @EnvironmentObject var conflictPredictor: SmartConflictPredictor

    private enum AITab: String, CaseIterable, Identifiable {
        case smartScheduling
        case autoCategorization
        case conflictPrediction
        case bufferStrategy

        var id: String { rawValue }

        var label: (text: String, systemImage: String) {
            switch self {
                case .smartScheduling: return ("Smart Scheduling", "calendar.badge.clock")
                case .autoCategorization: return ("Auto-Categorization", "tag.fill")
                case .conflictPrediction: return ("Conflict Prediction", "exclamationmark.triangle.fill")
                case .bufferStrategy: return ("Buffer Strategy", "hourglass")
            }
        }
    }

    @State private var selectedTab: AITab = .smartScheduling

    private var enabledTabs: [AITab] {
        var tabs: [AITab] = []
        if settings.enableSmartScheduling { tabs.append(.smartScheduling) }
        if settings.enableAutoCategorization { tabs.append(.autoCategorization) }
        if settings.enableConflictPrediction { tabs.append(.conflictPrediction) }
        if settings.enableSmartBuffer { tabs.append(.bufferStrategy) }
        return tabs
    }

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKit.events)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.purple)

                        Text("Planning Assistant")
                            .font(.system(size: 22, weight: .bold))
                    }

                    Text("Smart scheduling, categorization, conflict prevention, and buffer strategy in one place")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

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

            // Tab Selector
            if !enabledTabs.isEmpty {
                Picker("AI Feature", selection: $selectedTab) {
                    ForEach(enabledTabs) { tab in
                        Label(tab.label.text, systemImage: tab.label.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            Divider()

            // Content
            if !eventKit.hasCalendarAccess {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Calendar access is required")
                        .font(.headline)
                    Text("Enable calendar permission to use Planning Assistant features.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    Button("Grant Calendar Access") {
                        eventKit.requestAccessIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if enabledTabs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Planning Features Disabled")
                        .font(.headline)
                    Text("Enable Planning Assistant features in Settings to use this workspace.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $selectedTab) {
                    if settings.enableSmartScheduling {
                        SmartSchedulingTab(scheduler: smartScheduler)
                            .tag(AITab.smartScheduling)
                    }

                    if settings.enableAutoCategorization {
                        AutoCategorizationTab(categorizer: eventCategorizer)
                            .tag(AITab.autoCategorization)
                    }

                    if settings.enableConflictPrediction {
                        ConflictPredictionTab(conflictPredictor: conflictPredictor)
                            .tag(AITab.conflictPrediction)
                    }

                    if settings.enableSmartBuffer {
                        BufferStrategyTab(bufferManager: bufferManager)
                            .tag(AITab.bufferStrategy)
                    }
                }
                .tabViewStyle(.automatic)
            }
        }
        .frame(
            maxWidth: presentationContext == .menuBar ? nil : .infinity,
            maxHeight: presentationContext == .menuBar ? nil : .infinity,
            alignment: .topLeading
        )
        .frame(
            width: presentationContext == .menuBar ? 800 : nil,
            height: presentationContext == .menuBar ? 700 : nil
        )
        .onAppear {
            ensureValidSelectedTab()
            runAnalysesIfNeeded()
        }
        .onChange(of: eventKit.eventsByDay) { _ in
            runAnalysesIfNeeded()
        }
        .onChange(of: eventKit.googleEventsByDay) { _ in
            runAnalysesIfNeeded()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            runAnalysesIfNeeded()
        }
        .onChange(of: settings.enableSmartScheduling) { _ in
            ensureValidSelectedTab()
            runAnalysesIfNeeded()
        }
        .onChange(of: settings.enableConflictPrediction) { _ in
            ensureValidSelectedTab()
            runAnalysesIfNeeded()
        }
        .onChange(of: settings.enableAutoCategorization) { _ in
            ensureValidSelectedTab()
            runAnalysesIfNeeded()
        }
        .onChange(of: settings.enableSmartBuffer) { _ in
            ensureValidSelectedTab()
            runAnalysesIfNeeded()
        }
    }

    private func ensureValidSelectedTab() {
        guard let first = enabledTabs.first else { return }
        if !enabledTabs.contains(selectedTab) {
            selectedTab = first
        }
    }

    private func runAnalysesIfNeeded() {
        guard eventKit.hasCalendarAccess else {
            smartScheduler.suggestions = []
            eventCategorizer.categorizedEvents = [:]
            conflictPredictor.predictedConflicts = []
            bufferManager.dismissAllSuggestions()
            return
        }

        let events = visibleEvents

        if settings.enableSmartScheduling {
            smartScheduler.learnFromHistory(events)
            if events.isEmpty {
                smartScheduler.suggestions = []
            }
        } else {
            smartScheduler.suggestions = []
        }

        if settings.enableConflictPrediction {
            conflictPredictor.detectConflicts(in: events)
        } else {
            conflictPredictor.predictedConflicts = []
        }

        if settings.enableAutoCategorization {
            eventCategorizer.categorizeEvents(events)
        } else {
            eventCategorizer.categorizedEvents = [:]
        }

        if settings.enableSmartBuffer {
            bufferManager.analyzeMeetings(events: events)
        } else {
            bufferManager.dismissAllSuggestions()
        }
    }
}

// MARK: - Smart Scheduling Tab

struct SmartSchedulingTab: View {
    @ObservedObject var scheduler: SmartSchedulingAssistant
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var meetingTitle = ""
    @State private var duration = 30
    @State private var attendeeCount = 1
    @State private var searchDays = 7

    let durationOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Input Form
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Find Optimal Meeting Time")
                            .font(.headline)

                        TextField("Meeting title", text: $meetingTitle)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Text("Duration:")
                            Picker("Duration", selection: $duration) {
                                ForEach(durationOptions, id: \.self) { mins in
                                    Text("\(mins) min").tag(mins)
                                }
                            }
                            .frame(width: 120)
                        }

                        HStack {
                            Text("Attendees:")
                            Stepper("\(attendeeCount)", value: $attendeeCount, in: 1...20)
                        }

                        HStack {
                            Text("Search within:")
                            Picker("Days", selection: $searchDays) {
                                Text("3 days").tag(3)
                                Text("7 days").tag(7)
                                Text("14 days").tag(14)
                            }
                            .frame(width: 120)
                        }

                        Button(action: findOptimalTimes) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Find Best Times")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(meetingTitle.isEmpty)
                    }
                    .padding()
                }

                // Results
                if !scheduler.suggestions.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top \(scheduler.suggestions.count) Suggestions")
                                .font(.headline)

                            ForEach(Array(scheduler.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                                HStack {
                                    Text("#\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(formatDateTime(suggestion.suggestedTime))
                                            .font(.subheadline)

                                        Text(suggestion.reason)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text("\(Int(suggestion.confidence * 100))%")
                                        .font(.caption)
                                        .foregroundColor(confidenceColor(suggestion.confidence))
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }

    private func findOptimalTimes() {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: searchDays, to: startDate)
            ?? startDate.addingTimeInterval(Double(searchDays) * 24 * 3600)
        let dateRange = DateInterval(start: startDate, end: endDate)
        let visibleEvents = filterManager.filterEvents(eventKit.events)
            .filter { !$0.isAllDay }

        let suggestions = scheduler.suggestOptimalTimes(
            for: duration,
            within: dateRange,
            existingEvents: visibleEvents,
            attendeeCount: attendeeCount
        )

        scheduler.suggestions = suggestions
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .blue }
        else if confidence >= 0.4 { return .orange }
        else { return .red }
    }
}

// MARK: - Buffer Strategy Tab

struct BufferStrategyTab: View {
    @ObservedObject var bufferManager: SmartBufferTimeManager
    @EnvironmentObject var eventKit: EventKitManager

    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !eventKit.hasCalendarAccess {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Calendar access is required")
                            .font(.headline)
                        Text("Enable calendar permission to analyze meeting gaps.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recommendation")
                                .font(.headline)
                            Text(bufferManager.suggestOptimalBufferPattern())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }

                    GroupBox {
                        HStack(spacing: 20) {
                            metric(title: "Back-to-back", value: "\(bufferManager.backToBackCount)", color: .orange)
                            metric(title: "Average gap", value: "\(Int(bufferManager.averageGapMinutes))m", color: .blue)
                            metric(title: "Needs buffer", value: "\(bufferManager.bufferSuggestions.count)", color: .red)
                        }
                        .padding()
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Actionable Gaps")
                                    .font(.headline)
                                Spacer()
                                if !bufferManager.bufferSuggestions.isEmpty {
                                    Button("Dismiss all") {
                                        bufferManager.dismissAllSuggestions()
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.secondary)
                                }
                            }

                            if let lastAction = bufferManager.lastActionMessage {
                                Text(lastAction)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            if bufferManager.bufferSuggestions.isEmpty {
                                Text("No buffer suggestions right now.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(bufferManager.bufferSuggestions.prefix(8)) { suggestion in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "hourglass")
                                            .foregroundColor(.orange)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(suggestion.beforeEvent.title) → \(suggestion.afterEvent.title)")
                                                .font(.subheadline)
                                            Text("\(suggestion.reason.description) · gap \(max(0, suggestion.gapMinutes))m · suggest \(suggestion.suggestedBufferMinutes)m")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }

                                        Spacer()

                                        Button("Add Buffer") {
                                            let result = bufferManager.addBufferTime(for: suggestion, using: eventKit)
                                            if case .failure(let error) = result {
                                                errorMessage = error.errorDescription ?? "Could not add buffer."
                                            } else {
                                                errorMessage = nil
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button("Dismiss") {
                                            bufferManager.dismissSuggestion(suggestion)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .padding(10)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }

    private func metric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Auto-Categorization Tab

struct AutoCategorizationTab: View {
    @ObservedObject var categorizer: EventCategorizationML
    @EnvironmentObject var eventKit: EventKitManager

    @State private var selectedCategory: AIEventCategory? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Categories")
                            .font(.headline)

                        Text("AI has categorized \(categorizer.categorizedEvents.count) events")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        let distribution = categorizer.getCategoryDistribution()

                        ForEach(Array(distribution.sorted { $0.value > $1.value }), id: \.key) { category, count in
                            Button(action: { selectedCategory = category }) {
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(.blue)
                                        .frame(width: 24)

                                    Text(category.rawValue)
                                        .font(.subheadline)

                                    Spacer()

                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(8)
                                .background(selectedCategory == category ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }

                if let category = selectedCategory {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                                    .font(.headline)
                            }

                            let events = categorizer.getEventsForCategory(category)

                            ForEach(events.prefix(10)) { event in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.subheadline)

                                        Text(formatDate(event.startDate))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if let categorized = categorizer.categorizedEvents[event.id] {
                                        Text("\(Int(categorized.confidence * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                            }

                            if events.count > 10 {
                                Text("+ \(events.count - 10) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Conflict Prediction Tab

struct ConflictPredictionTab: View {
    @ObservedObject var conflictPredictor: SmartConflictPredictor
    @EnvironmentObject var eventKit: EventKitManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)

                            Text("Predicted Conflicts")
                                .font(.headline)

                            Spacer()

                            Text("\(conflictPredictor.predictedConflicts.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }

                        if conflictPredictor.predictedConflicts.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.green)

                                    Text("No Conflicts Detected")
                                        .font(.headline)

                                    Text("Your calendar looks good!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(40)
                        } else {
                            ForEach(conflictPredictor.predictedConflicts) { conflict in
                                AIConflictCard(conflict: conflict)
                            }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

struct AIConflictCard: View {
    let conflict: PredictedConflict

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForType(conflict.type))
                    .foregroundColor(colorForSeverity(conflict.severity))

                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.description)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(conflict.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(conflict.severity.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorForSeverity(conflict.severity).opacity(0.2))
                    .foregroundColor(colorForSeverity(conflict.severity))
                    .cornerRadius(4)

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Divider()

                Text(conflict.prediction)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(conflict.suggestedResolution)
                        .font(.caption)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorForSeverity(conflict.severity).opacity(0.3), lineWidth: 1)
        )
    }

    private func iconForType(_ type: ConflictType) -> String {
        switch type {
        case .overlap: return "rectangle.stack.fill"
        case .backToBack: return "arrow.right.arrow.left"
        case .travelTime: return "car.fill"
        case .overload: return "gauge.high"
        case .energyDrain: return "battery.25"
        case .focusInterruption: return "brain.head.profile"
        case .recurring: return "repeat"
        }
    }

    private func colorForSeverity(_ severity: ConflictSeverity) -> Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

struct AIAssistantDashboard_Previews: PreviewProvider {
    static var previews: some View {
        AIAssistantDashboard()
            .environmentObject(SettingsViewModel())
            .environmentObject(EventKitManager())
            .environmentObject(CalendarFilterManager())
            .environmentObject(SmartSchedulingAssistant())
            .environmentObject(EventCategorizationML())
            .environmentObject(SmartBufferTimeManager())
            .environmentObject(SmartConflictPredictor())
    }
}
