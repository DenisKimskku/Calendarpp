//
//  TimeAnalyticsDashboardView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI
import Charts

struct TimeAnalyticsDashboardView: View {
    @EnvironmentObject var analyticsManager: TimeAnalyticsManager
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
                } else if analyticsManager.isAnalyzing {
                    ProgressView("Analyzing your calendar...")
                        .padding(40)
                } else if let analytics = analyticsManager.currentAnalytics {
                    calendarHealthCard(analytics.calendarHealth)
                    weeklyStatsCard(analytics.weeklyStats)
                    focusScoreCard(analytics.focusScore, weeklyStats: analytics.weeklyStats)
                    dailyBreakdownChart(analytics.dailyBreakdown)
                    meetingPatternsCard(analytics.meetingPatterns)
                } else {
                    emptyStateView
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshAnalytics()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshAnalytics()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshAnalytics()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshAnalytics()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Analytics")
                    .font(.system(size: 24, weight: .bold))
                Text("This Week's Insights")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                Task {
                    await analyticsManager.analyzeWeek(events: visibleEvents)
                }
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
            Text("Enable calendar permission to generate analytics.")
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

    private func refreshAnalytics() {
        guard eventKitManager.hasCalendarAccess else { return }
        Task {
            await analyticsManager.analyzeWeek(events: visibleEvents)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No analytics available")
                .font(.headline)
            Text("Add some events to see insights")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    private func calendarHealthCard(_ health: CalendarHealth) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(health.status.emoji)
                    .font(.system(size: 32))
                Text("Calendar Health: \(health.status.rawValue)")
                    .font(.headline)
                Spacer()
            }

            Text(health.message)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !health.recommendations.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(health.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(recommendation)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(health.status.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(health.status.color.opacity(0.3), lineWidth: 1)
        )
    }

    private func weeklyStatsCard(_ stats: WeeklyStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statBox(
                    title: "Meeting Time",
                    value: String(format: "%.1f hrs", stats.totalMeetingHours),
                    subtitle: "\(stats.meetingCount) meetings",
                    icon: "video.fill",
                    color: .blue
                )

                statBox(
                    title: "Focus Time",
                    value: String(format: "%.1f hrs", stats.totalFocusHours),
                    subtitle: "Available for deep work",
                    icon: "brain.head.profile",
                    color: .green
                )

                statBox(
                    title: "Avg Meeting",
                    value: String(format: "%.0f min", stats.averageMeetingDuration),
                    subtitle: "Per meeting",
                    icon: "clock.fill",
                    color: .orange
                )

                statBox(
                    title: "Longest Focus",
                    value: formatDuration(stats.longestFocusBlock),
                    subtitle: "Uninterrupted time",
                    icon: "flame.fill",
                    color: .purple
                )
            }

            HStack(spacing: 8) {
                Image(systemName: stats.changeFromLastWeek >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundColor(stats.changeFromLastWeek >= 0 ? .orange : .green)
                Text(String(format: "%.1f%% vs last week", abs(stats.changeFromLastWeek)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Time distribution
            let totalHours = stats.totalMeetingHours + stats.totalFocusHours
            if totalHours > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time Distribution")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * (stats.totalMeetingHours / totalHours))

                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * (stats.totalFocusHours / totalHours))
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 20)

                    HStack {
                        Label(String(format: "%.0f%% Meetings", (stats.totalMeetingHours / totalHours) * 100), systemImage: "circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Spacer()

                        Label(String(format: "%.0f%% Focus", (stats.totalFocusHours / totalHours) * 100), systemImage: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func focusScoreCard(_ score: Double, weeklyStats: WeeklyStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Score")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.0f", score))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(scoreColor(score))
                Text("/ 100")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Score bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(scoreColor(score))
                        .frame(width: geometry.size.width * (score / 100))
                }
            }
            .frame(height: 8)

            Text(scoreMessage(score))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func dailyBreakdownChart(_ dailyStats: [DailyStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)

            if #available(macOS 13.0, *) {
                Chart {
                    ForEach(dailyStats) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Hours", day.meetingHours),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(.blue)
                        .position(by: .value("Type", "Meetings"))

                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Hours", day.focusHours),
                            width: .ratio(0.4)
                        )
                        .foregroundStyle(.green)
                        .position(by: .value("Type", "Focus"))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                            }
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Meetings": .blue,
                    "Focus": .green
                ])
                .frame(height: 200)
            } else {
                Text("Charts require macOS 13.0 or later")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func meetingPatternsCard(_ patterns: MeetingPatterns) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meeting Patterns")
                .font(.headline)

            VStack(spacing: 12) {
                patternRow(
                    icon: "arrow.right.arrow.left.circle.fill",
                    label: "Back-to-back meetings",
                    value: "\(patterns.backToBackCount)",
                    color: patterns.backToBackCount > 5 ? .orange : .secondary
                )

                patternRow(
                    icon: "clock.circle.fill",
                    label: "Average gap between meetings",
                    value: String(format: "%.0f min", patterns.averageGapMinutes),
                    color: .secondary
                )

                patternRow(
                    icon: "calendar.circle.fill",
                    label: "Busiest day",
                    value: patterns.busiestDay,
                    color: .secondary
                )

                patternRow(
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    label: "Most meetings at",
                    value: formatHour(patterns.mostFrequentMeetingHour),
                    color: .secondary
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func statBox(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 24, weight: .semibold))

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }

    private func patternRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
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

    private func scoreColor(_ score: Double) -> Color {
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

    private func scoreMessage(_ score: Double) -> String {
        if score >= 80 {
            return "Excellent focus time balance. Keep it up!"
        } else if score >= 60 {
            return "Good balance, but room for improvement."
        } else if score >= 40 {
            return "Consider blocking more focus time."
        } else {
            return "Calendar is overloaded. Take action to protect focus time."
        }
    }
}

struct TimeAnalyticsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        TimeAnalyticsDashboardView()
            .environmentObject(TimeAnalyticsManager())
            .environmentObject(EventKitManager())
    }
}
