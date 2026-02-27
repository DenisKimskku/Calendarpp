//
//  EnergyAwareSchedulingView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct EnergyAwareSchedulingView: View {
    @EnvironmentObject var analyticsManager: TimeAnalyticsManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var selectedHour: Int?
    @State private var showingEnergyEditor = false

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                if !eventKitManager.hasCalendarAccess {
                    calendarAccessHint
                }
                energyHeatmap
                schedulingSuggestions
                energyPatternsList
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .calendarppModal(isPresented: $showingEnergyEditor) {
            if let hour = selectedHour {
                EnergyLevelEditor(
                    hour: hour,
                    currentLevel: analyticsManager.getEnergyLevel(for: hour),
                    onSave: { level in
                        let pattern = EnergyPattern(hourOfDay: hour, energyLevel: level)
                        analyticsManager.saveEnergyPattern(pattern)
                        showingEnergyEditor = false
                    }
                )
            }
        }
        .onAppear {
            analyticsManager.loadEnergyPatterns()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Energy-Aware Scheduling")
                    .font(.system(size: 24, weight: .bold))
                Text("Schedule meetings when you're at your best")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.bottom, 10)
    }

    private var calendarAccessHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
            Text("Grant calendar access to get event-aware warnings based on your energy profile.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            Button("Grant Access") {
                eventKitManager.requestAccessIfNeeded()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    private var energyHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Energy Patterns")
                .font(.headline)

            Text("Click on any hour to set your typical energy level")
                .font(.caption)
                .foregroundColor(.secondary)

            // 24-hour energy heatmap
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                ForEach(0..<24) { hour in
                    EnergyHourCell(
                        hour: hour,
                        energyLevel: analyticsManager.getEnergyLevel(for: hour),
                        isSelected: selectedHour == hour
                    )
                    .onTapGesture {
                        selectedHour = hour
                        showingEnergyEditor = true
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                ForEach([EnergyLevel.peak, .high, .medium, .low], id: \.self) { level in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(level.color)
                            .frame(width: 12, height: 12)
                        Text(level.rawValue)
                            .font(.caption)
                    }
                }

                Spacer()

                Button("Reset to Defaults") {
                    resetToDefaultPattern()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var schedulingSuggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Smart Scheduling Tips")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let peakHours = getPeakHours() {
                    suggestionRow(
                        icon: "star.fill",
                        text: "Schedule important meetings during peak hours: \(peakHours)",
                        color: .green
                    )
                }

                if let lowHours = getLowEnergyHours() {
                    suggestionRow(
                        icon: "moon.fill",
                        text: "Avoid scheduling critical meetings during low energy hours: \(lowHours)",
                        color: .orange
                    )
                }

                if let warnings = getEnergyWarnings() {
                    ForEach(warnings, id: \.self) { warning in
                        suggestionRow(
                            icon: "exclamationmark.triangle.fill",
                            text: warning,
                            color: .red
                        )
                    }
                }
            }
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

    private var energyPatternsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Schedule")
                .font(.headline)

            ForEach(analyticsManager.energyPatterns.sorted { $0.hourOfDay < $1.hourOfDay }) { pattern in
                HStack {
                    Text(formatHour(pattern.hourOfDay))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 80, alignment: .leading)

                    Circle()
                        .fill(pattern.energyLevel.color)
                        .frame(width: 10, height: 10)

                    Text(pattern.energyLevel.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        selectedHour = pattern.hourOfDay
                        showingEnergyEditor = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    // MARK: - Helpers

    private func getPeakHours() -> String? {
        let peakPatterns = analyticsManager.energyPatterns.filter { $0.energyLevel == .peak }
        guard !peakPatterns.isEmpty else { return nil }

        let hours = peakPatterns.map { formatHour($0.hourOfDay) }
        return hours.joined(separator: ", ")
    }

    private func getLowEnergyHours() -> String? {
        let lowPatterns = analyticsManager.energyPatterns.filter { $0.energyLevel == .low }
        guard !lowPatterns.isEmpty else { return nil }

        let hours = lowPatterns.map { formatHour($0.hourOfDay) }
        return hours.joined(separator: ", ")
    }

    private func getEnergyWarnings() -> [String]? {
        guard eventKitManager.hasCalendarAccess else {
            return nil
        }

        var warnings: [String] = []

        // Check if important meetings are scheduled during low energy times
        let today = Date()
        let dayStart = Calendar.current.startOfDay(for: today)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 3600)

        let todaysEvents = visibleEvents.filter { event in
            event.startDate >= dayStart && event.startDate < dayEnd
        }

        for event in todaysEvents {
            let hour = Calendar.current.component(.hour, from: event.startDate)
            if let level = analyticsManager.getEnergyLevel(for: hour), level == .low {
                warnings.append("Meeting '\(event.title)' scheduled during low energy time (\(formatHour(hour)))")
            }
        }

        return warnings.isEmpty ? nil : warnings
    }

    private func resetToDefaultPattern() {
        // Reset to default energy pattern
        let defaults = [
            EnergyPattern(hourOfDay: 9, energyLevel: .peak),
            EnergyPattern(hourOfDay: 10, energyLevel: .peak),
            EnergyPattern(hourOfDay: 11, energyLevel: .high),
            EnergyPattern(hourOfDay: 14, energyLevel: .medium),
            EnergyPattern(hourOfDay: 15, energyLevel: .medium),
            EnergyPattern(hourOfDay: 16, energyLevel: .low),
        ]

        for pattern in defaults {
            analyticsManager.saveEnergyPattern(pattern)
        }
    }

    private func suggestionRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        var components = DateComponents()
        components.hour = hour

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }

        return "\(hour):00"
    }
}

struct EnergyHourCell: View {
    let hour: Int
    let energyLevel: EnergyLevel?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(String(hour))
                .font(.caption2)
                .foregroundColor(.secondary)

            RoundedRectangle(cornerRadius: 4)
                .fill(energyLevel?.color ?? Color.gray.opacity(0.2))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
    }
}

struct EnergyLevelEditor: View {
    @Environment(\.dismiss) var dismiss

    let hour: Int
    let currentLevel: EnergyLevel?
    let onSave: (EnergyLevel) -> Void

    @State private var selectedLevel: EnergyLevel

    init(hour: Int, currentLevel: EnergyLevel?, onSave: @escaping (EnergyLevel) -> Void) {
        self.hour = hour
        self.currentLevel = currentLevel
        self.onSave = onSave
        _selectedLevel = State(initialValue: currentLevel ?? .medium)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Energy Level for \(formatHour(hour))")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach([EnergyLevel.peak, .high, .medium, .low], id: \.self) { level in
                    Button(action: {
                        selectedLevel = level
                    }) {
                        HStack {
                            Circle()
                                .fill(level.color)
                                .frame(width: 16, height: 16)

                            Text(level.rawValue)
                                .font(.subheadline)

                            Spacer()

                            if selectedLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedLevel == level ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(selectedLevel)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 300)
        .padding()
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        var components = DateComponents()
        components.hour = hour

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }

        return "\(hour):00"
    }
}

struct EnergyAwareSchedulingView_Previews: PreviewProvider {
    static var previews: some View {
        EnergyAwareSchedulingView()
            .environmentObject(TimeAnalyticsManager())
            .environmentObject(EventKitManager())
    }
}
