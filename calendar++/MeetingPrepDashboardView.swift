//
//  MeetingPrepDashboardView.swift
//  calendar++
//
//  Dashboard view for meeting preparation
//

import SwiftUI

struct MeetingPrepDashboardView: View {
    @EnvironmentObject var prepManager: MeetingPrepManager
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKit.events)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if !eventKit.hasCalendarAccess {
                    calendarAccessState
                } else {
                    // Info Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("How Meeting Prep Works")
                                    .font(.headline)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                MeetingInfoRow(icon: "bell.badge", text: "Notifications appear 15 minutes before meetings")
                                MeetingInfoRow(icon: "clock.badge", text: "Final warning at 5 minutes before start")
                                MeetingInfoRow(icon: "doc.text", text: "Prep cards show agenda, attendees, and history")
                                MeetingInfoRow(icon: "link", text: "Quick join for video meetings")
                            }
                        }
                        .padding()
                    }

                    // Upcoming Meetings with Prep Info
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("Upcoming Meetings")
                                    .font(.headline)

                                Spacer()

                                Text("\(upcomingMeetings.count)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }

                            if upcomingMeetings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.green)

                                    Text("No upcoming meetings")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    Text("You're all clear for now!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(40)
                            } else {
                                ForEach(upcomingMeetings) { meeting in
                                    MeetingPrepRow(meeting: meeting, prepManager: prepManager)
                                }
                            }
                        }
                        .padding()
                    }

                    // Tips Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text("Prep Tips")
                                    .font(.headline)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                TipRow(icon: "doc.text", text: "Add agenda to meeting notes for automatic extraction")
                                TipRow(icon: "person.2", text: "Prep cards show previous meeting history with attendees")
                                TipRow(icon: "bell", text: "Notifications appear 15 and 5 minutes before meetings")
                                TipRow(icon: "link", text: "Click 'Join' on prep cards to open meeting links")
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshMeetings()
        }
        .onChange(of: eventKit.eventsByDay) { _ in
            refreshMeetings()
        }
        .onChange(of: eventKit.googleEventsByDay) { _ in
            refreshMeetings()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshMeetings()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meeting Prep")
                    .font(.system(size: 24, weight: .bold))
                Text("Upcoming meetings and preparation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var calendarAccessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Calendar access is required")
                .font(.headline)
            Text("Enable calendar permission to build meeting prep cards.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Grant Calendar Access") {
                eventKit.requestAccessIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var upcomingMeetings: [MeetingPrepInfo] {
        Array(prepManager.upcomingMeetings.prefix(10))
    }

    private func refreshMeetings() {
        guard eventKit.hasCalendarAccess else { return }
        prepManager.updateUpcomingMeetings(events: visibleEvents)
    }
}

struct MeetingPrepRow: View {
    let meeting: MeetingPrepInfo
    let prepManager: MeetingPrepManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time indicator
            VStack(spacing: 4) {
                Text(formatTime(meeting.event.startDate))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)

                Text(timeUntil(meeting.event.startDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)

            Divider()

            // Event details
            VStack(alignment: .leading, spacing: 6) {
                Text(meeting.event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let location = meeting.event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: location.contains("http") ? "video.fill" : "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    if !meeting.attendees.isEmpty {
                        Label("\(meeting.attendees.count)", systemImage: "person.2")
                    }
                    if meeting.agenda != nil {
                        Label("Agenda", systemImage: "list.bullet")
                    }
                    if meeting.lastMeetingDate != nil {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(formatDuration(meeting.event))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            if shouldShowPrepNotification(meeting.event) {
                Image(systemName: "bell.badge")
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func timeUntil(_ date: Date) -> String {
        let minutes = Int(Date().distance(to: date) / 60)
        if minutes < 60 {
            return "in \(minutes)m"
        } else {
            let hours = minutes / 60
            return "in \(hours)h"
        }
    }

    private func formatDuration(_ event: EventSummary) -> String {
        let duration = event.endDate.timeIntervalSince(event.startDate) / 60
        let hours = Int(duration) / 60
        let minutes = Int(duration) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func shouldShowPrepNotification(_ event: EventSummary) -> Bool {
        let timeUntil = Date().distance(to: event.startDate) / 60
        return timeUntil <= 15.0 && timeUntil > 0
    }
}

struct MeetingInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MeetingPrepDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingPrepDashboardView()
            .environmentObject(MeetingPrepManager())
            .environmentObject(EventKitManager())
    }
}
