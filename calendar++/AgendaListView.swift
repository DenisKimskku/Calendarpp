import SwiftUI
import EventKit

struct AgendaListView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var reminders: ReminderManager
    @Environment(\.calendarPPPresentationContext) private var presentationContext

    let date: Date
    let maxHeight: CGFloat?
    @Binding var inspectedEvent: EventSummary?
    @State private var popoverEvent: EventSummary?

    private var formatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }

    init(date: Date, maxHeight: CGFloat? = 160, inspectedEvent: Binding<EventSummary?> = .constant(nil)) {
        self.date = date
        self.maxHeight = maxHeight
        self._inspectedEvent = inspectedEvent
    }

    var body: some View {
        let allEvents = eventKit.events(on: date)
        let events = filterManager.filterEvents(allEvents)
        let allDayEvents = events.filter(\.isAllDay)
        let timedEvents = events
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
        let remindersForDay = settings.showRemindersInAgenda ? reminders.reminders(on: date) : []

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Events")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Text(formattedDate(date))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if events.isEmpty {
                        Text("Nothing scheduled")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    } else {
                        if !allDayEvents.isEmpty {
                            agendaSectionTitle("All-day")
                            ForEach(allDayEvents) { event in
                                let isSelected = inspectedEvent?.id == event.id
                                eventRow(event: event, isSelected: isSelected)
                            }
                        }

                        if !timedEvents.isEmpty {
                            if !allDayEvents.isEmpty {
                                Divider()
                                    .overlay(CalendarPPZenStyle.stroke)
                                    .padding(.vertical, 4)
                            }
                            agendaSectionTitle("Schedule")
                            ForEach(timedEvents) { event in
                                let isSelected = inspectedEvent?.id == event.id
                                eventRow(event: event, isSelected: isSelected)
                            }
                        }
                    }

                    if settings.showRemindersInAgenda {
                        Divider()
                            .overlay(CalendarPPZenStyle.stroke)
                            .padding(.vertical, 6)

                        HStack {
                            Text("Reminders")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("\(remindersForDay.count)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        if !isRemindersAuthorized {
                            Text("Reminders access not granted.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Button("Request Reminders Access") {
                                reminders.requestAccessIfNeeded()
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        } else if remindersForDay.isEmpty {
                            Text("No reminders")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        } else {
                            ForEach(remindersForDay) { reminder in
                                HStack(spacing: 8) {
                                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(reminder.isCompleted ? Color.green : Color.secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reminder.title)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .lineLimit(2)

                                        HStack(spacing: 8) {
                                            if let due = reminder.dueDate {
                                                Text(timeOnly(due))
                                            }
                                            Text(reminder.listName)
                                        }
                                        .font(.system(size: 10, weight: .regular, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .calendarPPZenCard(cornerRadius: 10, strong: false)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .applyAgendaMaxHeight(maxHeight)
            .popover(item: $popoverEvent) { event in
                EventDetailPopover(event: event)
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

    private var isRemindersAuthorized: Bool {
        let status = reminders.authorizationStatus
        if status == .authorized { return true }
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return true }
        }
        return false
    }

    private func timeOnly(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: date)
    }

    private func agendaSectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func eventRow(event: EventSummary, isSelected: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color(event.calendarColor))
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(eventTimeText(for: event))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )

                    Text(event.title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .calendarPPZenCard(cornerRadius: 10, strong: false)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.8)
        )
        .onTapGesture {
            if presentationContext == .menuBar {
                popoverEvent = event
            } else {
                inspectedEvent = event
            }
        }
        .contextMenu {
            EventContextMenu(event: event)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyAgendaMaxHeight(_ maxHeight: CGFloat?) -> some View {
        if let maxHeight {
            self.frame(maxHeight: maxHeight)
        } else {
            self
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

        // Delete event (local calendars only; Google events are read-only today)
        if event.id.hasPrefix("google-") {
            Button {
                // no-op
            } label: {
                Label("Delete Event (Google is read-only)", systemImage: "lock")
            }
            .disabled(true)
        } else {
            Button(role: .destructive) {
                deleteEvent()
            } label: {
                Label("Delete Event", systemImage: "trash")
            }
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
