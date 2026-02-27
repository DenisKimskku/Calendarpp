//
//  DailyBriefingView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct DailyBriefingView: View {
    @EnvironmentObject var briefingManager: DailyBriefingManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if !eventKitManager.hasCalendarAccess {
                    calendarAccessState
                } else if let briefing = briefingManager.todaysBriefing {
                    summaryCard(briefing)

                    if !briefing.warnings.isEmpty {
                        warningsCard(briefing.warnings)
                    }

                    if !briefing.suggestions.isEmpty {
                        suggestionsCard(briefing.suggestions)
                    }

                    meetingsList(briefing)
                } else {
                    emptyStateView
                }

                settingsSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshBriefing()
            notifyBriefingViewedIfEligible()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshBriefing()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshBriefing()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshBriefing()
        }
        .onChange(of: briefingManager.todaysBriefing?.date) { _ in
            notifyBriefingViewedIfEligible()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Briefing")
                    .font(.system(size: 24, weight: .bold))
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                refreshBriefing()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding(.bottom, 10)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("No briefing available")
                .font(.headline)
            Text("Check back tomorrow morning")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    private var calendarAccessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Calendar access is required")
                .font(.headline)
            Text("Enable calendar permission to generate your briefing.")
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

    private func summaryCard(_ briefing: DailyBriefing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: briefing.totalMeetings == 0 ? "sun.max.fill" : "calendar.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(briefing.totalMeetings == 0 ? .orange : .blue)

                VStack(alignment: .leading, spacing: 4) {
                    if briefing.totalMeetings == 0 {
                        Text("No meetings today!")
                            .font(.headline)
                        Text("Perfect day for deep work")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(briefing.totalMeetings) meeting\(briefing.totalMeetings == 1 ? "" : "s") today")
                            .font(.headline)
                        Text(String(format: "%.1f hours in meetings", briefing.totalMeetingHours))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(
                    icon: "video.fill",
                    label: "Meetings",
                    value: "\(briefing.totalMeetings)",
                    color: .blue
                )

                statCard(
                    icon: "brain.head.profile",
                    label: "Focus Time",
                    value: String(format: "%.1fh", briefing.focusTimeHours),
                    color: .green
                )

                if let firstMeeting = briefing.firstMeeting {
                    statCard(
                        icon: "clock.fill",
                        label: "First Meeting",
                        value: formatTime(firstMeeting.startDate),
                        color: .orange
                    )
                }

                if let lastMeeting = briefing.lastMeeting {
                    statCard(
                        icon: "moon.fill",
                        label: "Last Meeting",
                        value: formatTime(lastMeeting.startDate),
                        color: .purple
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

    private func warningsCard(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Heads Up")
                    .font(.headline)
            }

            ForEach(warnings, id: \.self) { warning in
                Text(warning)
                    .font(.subheadline)
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

    private func suggestionsCard(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Suggestions")
                    .font(.headline)
            }

            ForEach(suggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .font(.subheadline)
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

    private func meetingsList(_ briefing: DailyBriefing) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Schedule")
                .font(.headline)

            if briefing.totalMeetings == 0 {
                Text("No meetings scheduled")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Get today's events
                let today = Calendar.current.startOfDay(for: Date())
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
                    ?? today.addingTimeInterval(24 * 3600)

                let todaysEvents = visibleEvents.filter { event in
                    event.startDate >= today && event.startDate < tomorrow && !event.isAllDay
                }
                .sorted { $0.startDate < $1.startDate }

                ForEach(todaysEvents) { event in
                    BriefingEventRow(event: event)
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
            Text("Briefing Settings")
                .font(.headline)

            Toggle("Enable daily briefing", isOn: $briefingManager.isEnabled)

            if briefingManager.isEnabled {
                HStack {
                    Text("Briefing time:")
                        .font(.subheadline)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $briefingManager.briefingTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 32)

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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    private func refreshBriefing() {
        guard eventKitManager.hasCalendarAccess else { return }
        briefingManager.updateTodaysBriefing(events: visibleEvents)
    }

    private func notifyBriefingViewedIfEligible() {
        guard briefingManager.todaysBriefing != nil else { return }
        NotificationCenter.default.post(name: .achievementDailyBriefingViewed, object: nil)
    }
}

struct BriefingEventRow: View {
    let event: EventSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(formatHour(event.startDate))
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(formatMinute(event.startDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            Rectangle()
                .fill(Color(event.calendarColor))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label(formatDuration(event), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h"
        return formatter.string(from: date)
    }

    private func formatMinute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ event: EventSummary) -> String {
        let duration = event.startDate.distance(to: event.endDate) / 60
        let hours = Int(duration) / 60
        let minutes = Int(duration) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct DailyBriefingView_Previews: PreviewProvider {
    static var previews: some View {
        DailyBriefingView()
            .environmentObject(DailyBriefingManager())
            .environmentObject(EventKitManager())
    }
}
