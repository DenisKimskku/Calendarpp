//
//  EventDetailPopover.swift
//  calendar++
//
//  Detailed event information popover
//

import SwiftUI

struct EventDetailPopover: View {
    let event: EventSummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title
            HStack {
                Rectangle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(event.calendarName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Time information
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "clock")
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    if event.isAllDay {
                        Text("All day")
                            .font(.body)
                    } else {
                        Text(formatDateTime(event.startDate))
                            .font(.body)
                        Text("to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDateTime(event.endDate))
                            .font(.body)

                        // Duration
                        let duration = event.endDate.timeIntervalSince(event.startDate)
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Location
            if let location = event.location, !location.isEmpty {
                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.accentColor)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(location)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        // Quick join button if meeting URL
                        if let meetingURL = extractMeetingURL(from: location) {
                            Button {
                                NSWorkspace.shared.open(meetingURL)
                            } label: {
                                Label("Join Meeting", systemImage: "video.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Divider()

            // Quick actions
            HStack(spacing: 12) {
                Button {
                    copyEventDetails()
                } label: {
                    Label("Copy Details", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    openInCalendarApp()
                } label: {
                    Label("Open in Calendar", systemImage: "calendar")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func extractMeetingURL(from location: String) -> URL? {
        // Extract meeting URLs from location
        if location.contains("zoom.us"), let url = URL(string: location) {
            return url
        }
        if location.contains("meet.google.com"), let url = URL(string: location) {
            return url
        }
        if location.contains("teams.microsoft.com"), let url = URL(string: location) {
            return url
        }

        // Try to extract URL using regex
        let pattern = "https?://[^\\s]+"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: location, range: NSRange(location.startIndex..., in: location)),
           let range = Range(match.range, in: location) {
            let urlString = String(location[range])
            return URL(string: urlString)
        }

        return nil
    }

    private func copyEventDetails() {
        var details = "\(event.title)\n"
        details += "\(formatDateTime(event.startDate))"
        if !event.isAllDay {
            details += " – \(formatDateTime(event.endDate))"
        }
        details += "\n"

        if let location = event.location, !location.isEmpty {
            details += "Location: \(location)\n"
        }

        details += "Calendar: \(event.calendarName)"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(details, forType: .string)
    }

    private func openInCalendarApp() {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }
}
