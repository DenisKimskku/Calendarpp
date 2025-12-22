import SwiftUI

struct AgendaListView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    let date: Date
    @State private var selectedEvent: EventSummary?

    private var formatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }

    var body: some View {
        let allEvents = eventKit.events(on: date)
        let events = filterManager.filterEvents(allEvents)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Events")
                    .font(.subheadline.bold())
                Spacer()
                Text(formattedDate(date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            if events.isEmpty {
                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: 6) {
                                Rectangle()
                                    .fill(Color(event.calendarColor))
                                    .frame(width: 3)
                                    .cornerRadius(1.5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(eventTimeText(for: event))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if let location = event.location, !location.isEmpty {
                                        Text(location)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onTapGesture {
                                selectedEvent = event
                            }
                            .contextMenu {
                                EventContextMenu(event: event)
                            }
                            .popover(item: $selectedEvent) { event in
                                EventDetailPopover(event: event)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 160)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func eventTimeText(for event: EventSummary) -> String {
        if event.isAllDay {
            return "All day"
        } else {
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            return "\(start) – \(end)"
        }
    }
}

// Event Context Menu for Quick Actions
struct EventContextMenu: View {
    let event: EventSummary
    @EnvironmentObject var eventKit: EventKitManager

    var body: some View {
        // Open in Calendar app
        Button {
            openInCalendarApp()
        } label: {
            Label("Open in Calendar", systemImage: "calendar")
        }

        // Quick Join (if meeting link exists)
        if let meetingURL = extractMeetingURL(from: event) {
            Button {
                NSWorkspace.shared.open(meetingURL)
            } label: {
                Label("Join Meeting", systemImage: "video.fill")
            }
        }

        Divider()

        // Copy event details
        Button {
            copyEventDetails()
        } label: {
            Label("Copy Event Details", systemImage: "doc.on.doc")
        }

        // Copy location
        if let location = event.location, !location.isEmpty {
            Button {
                copyToClipboard(location)
            } label: {
                Label("Copy Location", systemImage: "map")
            }
        }

        Divider()

        // Delete event
        Button(role: .destructive) {
            deleteEvent()
        } label: {
            Label("Delete Event", systemImage: "trash")
        }
    }

    private func openInCalendarApp() {
        // Open macOS Calendar app
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else {
            // Fallback to direct path
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }

    private func extractMeetingURL(from event: EventSummary) -> URL? {
        // Check location for meeting URLs
        if let location = event.location {
            // Check for Zoom
            if location.contains("zoom.us"), let url = URL(string: location) {
                return url
            }
            // Check for Google Meet
            if location.contains("meet.google.com"), let url = URL(string: location) {
                return url
            }
            // Check for Teams
            if location.contains("teams.microsoft.com"), let url = URL(string: location) {
                return url
            }
        }
        return nil
    }

    private func copyEventDetails() {
        var details = "\(event.title)\n"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if event.isAllDay {
            details += "All day on \(formatter.string(from: event.startDate))\n"
        } else {
            details += "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))\n"
        }

        if let location = event.location, !location.isEmpty {
            details += "Location: \(location)\n"
        }

        details += "Calendar: \(event.calendarName)"

        copyToClipboard(details)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func deleteEvent() {
        // Delete event from EventKit
        eventKit.deleteEvent(withId: event.id)
    }
}

// Helper to convert NSColor to SwiftUI Color
extension Color {
    init(_ nsColor: NSColor) {
        self.init(cgColor: nsColor.cgColor)
    }
}
