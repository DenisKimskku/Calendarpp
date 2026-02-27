//
//  CalendarWidgetViews.swift
//  calendar++
//
//  Widget UI components for different sizes
//

import SwiftUI
import WidgetKit

// MARK: - Small Widget (Shows next event + count)

struct SmallWidgetView: View {
    let entry: CalendarWidgetEntry

    var nextEvent: EventSummary? {
        entry.events.first(where: { $0.startDate > Date() }) ?? entry.events.first
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "calendar")
                        .font(.title3)
                    Text("Today")
                        .font(.headline)
                    Spacer()
                    Text("\(entry.events.count)")
                        .font(.title2.bold())
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Next Event
                if let event = nextEvent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.subheadline.bold())
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formatTime(event.startDate))
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    Text("No events")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .foregroundColor(.white)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Medium Widget (Shows 3-4 events)

struct MediumWidgetView: View {
    let entry: CalendarWidgetEntry

    var upcomingEvents: [EventSummary] {
        Array(entry.events.prefix(4))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Date & Count
            VStack(alignment: .leading, spacing: 8) {
                Text(formatDate(Date()))
                    .font(.title2.bold())

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("\(entry.events.count) events")
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                Spacer()

                // Calendar icon
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(.blue.opacity(0.3))
            }
            .padding()
            .frame(width: 120)
            .background(Color.blue.opacity(0.1))

            // Right side: Event List
            VStack(alignment: .leading, spacing: 8) {
                ForEach(upcomingEvents) { event in
                    EventRow(event: event)
                    if event.id != upcomingEvents.last?.id {
                        Divider()
                    }
                }

                if upcomingEvents.isEmpty {
                    Text("No events today")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Large Widget (Shows full day schedule)

struct LargeWidgetView: View {
    let entry: CalendarWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatFullDate(Date()))
                        .font(.title2.bold())
                    Text("\(entry.events.count) events today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue.opacity(0.7))
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // Event Timeline
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entry.events) { event in
                        EventTimelineRow(event: event)
                    }

                    if entry.events.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 50))
                                .foregroundColor(.green.opacity(0.5))
                            Text("No events scheduled")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Enjoy your free day!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct EventRow: View {
    let event: EventSummary

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Color indicator
            Circle()
                .fill(Color(event.calendarColor))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(formatTimeRange(event.startDate, event.endDate))
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct EventTimelineRow: View {
    let event: EventSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack(alignment: .trailing, spacing: 0) {
                Text(formatTime(event.startDate))
                    .font(.caption.bold())
                Text("-")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(formatTime(event.endDate))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)

            // Event Card
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color(event.calendarColor))
                        .frame(width: 8, height: 8)

                    Text(event.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                }

                if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Text(event.calendarName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
