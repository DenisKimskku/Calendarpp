//
//  MeetingPrepCardView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct MeetingPrepCardView: View {
    let prepInfo: MeetingPrepInfo
    let onDismiss: () -> Void
    let onRunningLate: () -> Void

    @State private var timeUntilMeeting: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meeting Prep")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(prepInfo.event.title)
                        .font(.headline)
                        .lineLimit(2)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Time until meeting
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)

                Text("Starts in \(formatTimeRemaining())")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formatMeetingTime())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )

            // Location
            if let location = prepInfo.event.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    Text(location)
                        .font(.subheadline)
                }
            }

            // Attendees
            if !prepInfo.attendees.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                            .frame(width: 20)

                        Text("Attendees")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    ForEach(prepInfo.attendees.prefix(5), id: \.self) { attendee in
                        HStack {
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(String(attendee.prefix(1)).uppercased())
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                )

                            Text(attendee)
                                .font(.caption)
                        }
                    }

                    if prepInfo.attendees.count > 5 {
                        Text("+\(prepInfo.attendees.count - 5) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Last meeting info
            if let lastMeetingDate = prepInfo.lastMeetingDate {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.green)
                        .frame(width: 20)

                    Text("Last met: \(formatLastMeeting(lastMeetingDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Agenda
            if let agenda = prepInfo.agenda {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundColor(.indigo)
                            .frame(width: 20)

                        Text("Agenda")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(agenda)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button(action: onRunningLate) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text("Running Late")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let location = prepInfo.event.location, location.contains("http") {
                    Button(action: {
                        if let url = URL(string: location) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Join")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 350)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            updateTimeRemaining()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                updateTimeRemaining()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func updateTimeRemaining() {
        timeUntilMeeting = Date().distance(to: prepInfo.event.startDate)
    }

    private func formatTimeRemaining() -> String {
        let minutes = Int(timeUntilMeeting / 60)

        if minutes < 1 {
            return "less than a minute"
        } else if minutes == 1 {
            return "1 minute"
        } else {
            return "\(minutes) minutes"
        }
    }

    private func formatMeetingTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: prepInfo.event.startDate)
    }

    private func formatLastMeeting(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Overlay view for prep cards
struct MeetingPrepOverlay: View {
    @EnvironmentObject var prepManager: MeetingPrepManager

    var body: some View {
        ZStack {
            if let prepCard = prepManager.currentPrepCard {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        prepManager.dismissPrepCard()
                    }

                VStack {
                    Spacer()

                    MeetingPrepCardView(
                        prepInfo: prepCard,
                        onDismiss: {
                            prepManager.dismissPrepCard()
                        },
                        onRunningLate: {
                            prepManager.notifyRunningLate(for: prepCard)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    Spacer()
                        .frame(height: 40)
                }
                .animation(.spring(), value: prepManager.currentPrepCard != nil)
            }
        }
    }
}

struct MeetingPrepCardView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEvent = EventSummary(
            id: "1",
            title: "Team Standup",
            startDate: Date().addingTimeInterval(5 * 60),
            endDate: Date().addingTimeInterval(35 * 60),
            isAllDay: false,
            calendarName: "Work",
            calendarColor: NSColor.blue,
            location: "https://zoom.us/j/123456",
            notes: "Agenda:\n- Sprint progress\n- Blockers\n- Next steps"
        )

        let prepInfo = MeetingPrepInfo(
            id: sampleEvent.id,
            event: sampleEvent,
            attendees: ["Alice Smith", "Bob Johnson", "Carol White"],
            lastMeetingDate: Date().addingTimeInterval(-7 * 24 * 3600),
            relatedNotes: [],
            agenda: "- Sprint progress\n- Blockers\n- Next steps",
            prepTime: 15 * 60,
            warningTime: 5 * 60
        )

        MeetingPrepCardView(
            prepInfo: prepInfo,
            onDismiss: {},
            onRunningLate: {}
        )
    }
}
