//
//  MeetingCostView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct MeetingCostView: View {
    @EnvironmentObject var costCalculator: MeetingCostCalculator
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var showingSettings = false

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if !eventKitManager.hasCalendarAccess {
                    calendarAccessState
                } else if let report = costCalculator.weeklyReport {
                    weeklyReportCard(report)
                    savingsSuggestionsCard
                    costBreakdownList
                } else {
                    emptyStateView
                }

                settingsCard
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .calendarppModal(isPresented: $showingSettings) {
            CostSettingsView(
                hourlyRate: costCalculator.averageHourlyRate,
                defaultAttendees: costCalculator.defaultAttendeeCount,
                onSave: { rate, attendees in
                    costCalculator.averageHourlyRate = rate
                    costCalculator.defaultAttendeeCount = attendees
                    refreshCosts()
                    showingSettings = false
                }
            )
        }
        .onAppear {
            refreshCosts()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshCosts()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshCosts()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshCosts()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meeting Cost Calculator")
                    .font(.system(size: 24, weight: .bold))
                Text("Understand the true cost of meetings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                refreshCosts()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
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
            Text("Enable calendar permission to calculate meeting costs.")
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

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("No cost data available")
                .font(.headline)
            Text("Add some meetings to see cost analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    private func weeklyReportCard(_ report: WeeklyCostReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week's Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "$%.0f", report.totalCost))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f hrs", report.totalMeetingHours))
                        .font(.headline)
                }
            }

            Divider()

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(
                    label: "Average per meeting",
                    value: String(format: "$%.0f", report.averageMeetingCost),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )

                if let mostExpensive = report.mostExpensiveMeeting {
                    statCard(
                        label: "Most expensive",
                        value: mostExpensive.formattedCost,
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            }

            if let mostExpensive = report.mostExpensiveMeeting {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Costliest Meeting:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mostExpensive.event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(mostExpensive.attendeeCount) attendees × \(String(format: "%.1f", mostExpensive.durationHours)) hrs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: report.costTrend >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundColor(report.costTrend >= 0 ? .orange : .green)
                Text(String(format: "%.1f%% vs last week", abs(report.costTrend)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var savingsSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Cost Saving Opportunities")
                    .font(.headline)
            }

            ForEach(costCalculator.getCostSavingsSuggestions(), id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(suggestion)
                        .font(.subheadline)
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

    private var costBreakdownList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Breakdown")
                .font(.headline)

            if costCalculator.meetingCosts.isEmpty {
                Text("No meetings this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(costCalculator.meetingCosts) { cost in
                    MeetingCostRow(cost: cost)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Settings")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average hourly rate")
                        .font(.subheadline)
                    Text(String(format: "$%.0f/hour", costCalculator.averageHourlyRate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Default attendees")
                        .font(.subheadline)
                    Text("\(costCalculator.defaultAttendeeCount) people")
                        .font(.caption)
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

    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }

    private func refreshCosts() {
        guard eventKitManager.hasCalendarAccess else { return }
        costCalculator.calculateCosts(for: visibleEvents)
    }
}

struct MeetingCostRow: View {
    let cost: MeetingCost

    var body: some View {
        HStack(spacing: 12) {
            Text(cost.costLevel.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(cost.event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(cost.attendeeCount) people", systemImage: "person.2")
                    Label(String(format: "%.1f hrs", cost.durationHours), systemImage: "clock")
                    Label(formatTime(cost.event.startDate), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(cost.formattedCost)
                    .font(.headline)
                    .foregroundColor(cost.costLevel.color)

                Text(String(format: "$%.0f/min", cost.costPerMinute))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cost.costLevel.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct CostSettingsView: View {
    @Environment(\.dismiss) var dismiss

    let hourlyRate: Double
    let defaultAttendees: Int
    let onSave: (Double, Int) -> Void

    @State private var newHourlyRate: Double
    @State private var newDefaultAttendees: Int

    init(hourlyRate: Double, defaultAttendees: Int, onSave: @escaping (Double, Int) -> Void) {
        self.hourlyRate = hourlyRate
        self.defaultAttendees = defaultAttendees
        self.onSave = onSave
        _newHourlyRate = State(initialValue: hourlyRate)
        _newDefaultAttendees = State(initialValue: defaultAttendees)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Cost Calculation Settings")
                .font(.headline)

            Form {
                Section("Hourly Rate") {
                    Slider(value: $newHourlyRate, in: 25...300, step: 5) {
                        Text("Average hourly rate")
                    }

                    Text(String(format: "$%.0f per hour", newHourlyRate))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("This is used to estimate the cost of meeting time. Adjust based on your organization's average salary.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Default Attendees") {
                    Stepper("Default attendee count: \(newDefaultAttendees)", value: $newDefaultAttendees, in: 1...50)

                    Text("Used when attendee count cannot be determined from the meeting")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    onSave(newHourlyRate, newDefaultAttendees)
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

struct MeetingCostView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingCostView()
            .environmentObject(MeetingCostCalculator())
            .environmentObject(EventKitManager())
    }
}
