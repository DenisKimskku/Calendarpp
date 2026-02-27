//
//  CalendarInboxView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct CalendarInboxView: View {
    @Environment(\.calendarPPPresentationContext) private var presentationContext
    @EnvironmentObject var inboxManager: CalendarInboxManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if !eventKitManager.hasCalendarAccess {
                    calendarAccessState
                } else {
                    statisticsCard
                    quickActionsCard
                    filterSortBar
                    inboxItemsList
                }
            }
            .padding()
        }
        .frame(
            maxWidth: presentationContext == .menuBar ? nil : .infinity,
            maxHeight: presentationContext == .menuBar ? nil : .infinity,
            alignment: .topLeading
        )
        .frame(
            width: presentationContext == .menuBar ? 800 : nil,
            height: presentationContext == .menuBar ? 700 : nil
        )
        .onAppear {
            refreshInbox()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshInbox()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshInbox()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshInbox()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar Inbox")
                    .font(.system(size: 24, weight: .bold))
                Text("Review invites and jump to Calendar.app for final response")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                refreshInbox()
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding(.bottom, 10)
    }

    private var statisticsCard: some View {
        Group {
            if let stats = inboxManager.statistics {
                HStack(spacing: 20) {
                    statBox(
                        label: "Pending",
                        value: "\(stats.totalPending)",
                        icon: "tray.fill",
                        color: .blue
                    )

                    statBox(
                        label: "High Priority",
                        value: "\(stats.highPriority)",
                        icon: "exclamationmark.circle.fill",
                        color: .red
                    )

                    statBox(
                        label: "Conflicts",
                        value: "\(stats.withConflicts)",
                        icon: "calendar.badge.exclamationmark",
                        color: .orange
                    )

                    statBox(
                        label: "Decline Rate",
                        value: String(format: "%.0f%%", stats.declineRate * 100),
                        icon: "hand.raised.fill",
                        color: .purple
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
    }

    private var quickActionsCard: some View {
        Group {
            let actions = inboxManager.getQuickActions()
            if !actions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                        Text("Quick Actions")
                            .font(.headline)
                    }

                    ForEach(actions, id: \.self) { action in
                        HStack {
                            Text("•")
                            Text(action)
                                .font(.subheadline)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Follow All Suggestions") {
                            inboxManager.followAllSuggestions()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Decline All with Conflicts") {
                            inboxManager.declineAll { !$0.conflicts.isEmpty }
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Note: Invite actions open Calendar.app so you can send official RSVP responses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        }
    }

    private var filterSortBar: some View {
        HStack {
            Menu {
                Button("All") { inboxManager.filterMode = .all; inboxManager.applySortAndFilter() }
                Button("High Priority") { inboxManager.filterMode = .highPriority; inboxManager.applySortAndFilter() }
                Button("With Conflicts") { inboxManager.filterMode = .conflicts; inboxManager.applySortAndFilter() }
                Button("Today") { inboxManager.filterMode = .today; inboxManager.applySortAndFilter() }
                Button("This Week") { inboxManager.filterMode = .thisWeek; inboxManager.applySortAndFilter() }
            } label: {
                Label("Filter: \(filterLabel)", systemImage: "line.3.horizontal.decrease.circle")
            }

            Menu {
                Button("Priority") { inboxManager.sortMode = .priority; inboxManager.applySortAndFilter() }
                Button("Date") { inboxManager.sortMode = .date; inboxManager.applySortAndFilter() }
                Button("Conflicts") { inboxManager.sortMode = .conflicts; inboxManager.applySortAndFilter() }
            } label: {
                Label("Sort: \(sortLabel)", systemImage: "arrow.up.arrow.down")
            }

            Spacer()

            Text("\(inboxManager.inboxItems.count) item\(inboxManager.inboxItems.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var inboxItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if inboxManager.inboxItems.isEmpty {
                emptyStateView
            } else {
                ForEach(inboxManager.inboxItems) { item in
                    InboxItemCard(item: item)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Inbox Zero!")
                .font(.headline)
            Text("No pending invites to review")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var calendarAccessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Calendar access is required")
                .font(.headline)
            Text("Enable calendar permission to review pending invitations.")
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

    private func statBox(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            Text(value)
                .font(.system(size: 24, weight: .bold))

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }

    private var filterLabel: String {
        switch inboxManager.filterMode {
        case .all: return "All"
        case .highPriority: return "High Priority"
        case .conflicts: return "Conflicts"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        }
    }

    private var sortLabel: String {
        switch inboxManager.sortMode {
        case .priority: return "Priority"
        case .date: return "Date"
        case .conflicts: return "Conflicts"
        }
    }
}

private extension CalendarInboxView {
    func refreshInbox() {
        guard eventKitManager.hasCalendarAccess else { return }

        let now = Date()
        // Keep a wider horizon so pending invites don't disappear after one week.
        let monthFromNow = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(30 * 24 * 3600)
        let range = DateInterval(start: now, end: monthFromNow)

        let pendingInvites = filterManager.filterEvents(eventKitManager.pendingInvitations(within: range))
        let visibleEvents = filterManager.filterEvents(eventKitManager.events)
        inboxManager.processInbox(invites: pendingInvites, allEvents: visibleEvents)
    }
}

struct InboxItemCard: View {
    @EnvironmentObject var inboxManager: CalendarInboxManager

    let item: InboxItem
    @State private var showingDeclineSheet = false
    @State private var showingProposeTimeSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(item.priority.color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.event.title)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Label(formatDateTime(item.event.startDate), systemImage: "calendar")
                        if let location = item.event.location, !location.isEmpty {
                            Label(location, systemImage: "location")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Text(item.priority.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(item.priority.color.opacity(0.2)))
                    .foregroundColor(item.priority.color)
            }

            // Conflicts
            if !item.conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Conflicts with \(item.conflicts.count) event\(item.conflicts.count == 1 ? "" : "s"):")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    ForEach(item.conflicts.prefix(2)) { conflict in
                        Text("• \(conflict.title)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if item.conflicts.count > 2 {
                        Text("• +\(item.conflicts.count - 2) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
            }

            // Suggested Action
            if let suggestion = item.suggestedAction {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Suggested: \(actionLabel(suggestion.action))")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("- \(suggestion.reason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.yellow.opacity(0.1))
                )
            }

            // Status indicator
            if item.status != .pending {
                HStack {
                    Image(systemName: statusIcon(item.status))
                        .foregroundColor(statusColor(item.status))
                    Text(statusLabel(item.status))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(statusColor(item.status))
                }
            }

            Divider()

            // Actions
            if item.status == .pending {
                HStack(spacing: 8) {
                    Button(action: {
                        inboxManager.acceptInvite(item)
                    }) {
                        Label("Accept", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .help("Opens Calendar.app at the event time so you can accept the invitation.")

                    Button(action: {
                        inboxManager.tentativeInvite(item)
                    }) {
                        Label("Tentative", systemImage: "questionmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .help("Opens Calendar.app at the event time so you can respond Tentative.")

                    Button(action: {
                        showingDeclineSheet = true
                    }) {
                        Label("Decline", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .help("Copies your decline message (if provided) and opens Calendar.app at the event time.")

                    Button(action: {
                        showingProposeTimeSheet = true
                    }) {
                        Image(systemName: "clock.arrow.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .help("Propose new time")
                }
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.priority.color.opacity(0.3), lineWidth: 1)
        )
        .calendarppModal(isPresented: $showingDeclineSheet) {
            DeclineMessageSheet(item: item, onDecline: { message in
                inboxManager.declineInvite(item, message: message)
                showingDeclineSheet = false
            })
        }
        .calendarppModal(isPresented: $showingProposeTimeSheet) {
            ProposeTimeSheet(item: item, onPropose: { newTime in
                inboxManager.proposeNewTime(item, newTime: newTime)
                showingProposeTimeSheet = false
            })
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func actionLabel(_ action: InboxItemAction) -> String {
        switch action {
        case .accept: return "Accept"
        case .decline: return "Decline"
        case .tentative: return "Tentative"
        case .proposeNewTime: return "Propose new time"
        case .delegate: return "Delegate"
        }
    }

    private func statusIcon(_ status: InboxItem.InboxStatus) -> String {
        switch status {
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .tentative: return "questionmark.circle.fill"
        case .actionTaken: return "checkmark.circle"
        case .pending: return "circle"
        }
    }

    private func statusColor(_ status: InboxItem.InboxStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .declined: return .red
        case .tentative: return .orange
        case .actionTaken: return .blue
        case .pending: return .secondary
        }
    }

    private func statusLabel(_ status: InboxItem.InboxStatus) -> String {
        switch status {
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .tentative: return "Tentative"
        case .actionTaken: return "Action Taken"
        case .pending: return "Pending"
        }
    }
}

struct DeclineMessageSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: InboxItem
    let onDecline: (String?) -> Void

    @State private var message = ""
    @State private var useTemplate = true

    private let templates = [
        "I have a scheduling conflict and won't be able to attend.",
        "Thank you for the invite, but I'll need to decline this time.",
        "I'm focusing on other priorities and won't be able to join.",
        "I don't think I can add value to this meeting. Please proceed without me."
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Decline: \(item.event.title)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Use template message", isOn: $useTemplate)

                if useTemplate {
                    Picker("Template", selection: $message) {
                        ForEach(templates, id: \.self) { template in
                            Text(template).tag(template)
                        }
                    }
                    .onAppear {
                        if message.isEmpty {
                            message = templates[0]
                        }
                    }
                } else {
                    Text("Custom message:")
                        .font(.subheadline)

                    TextEditor(text: $message)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.2))
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Decline") {
                    onDecline(useTemplate || !message.isEmpty ? message : nil)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
        }
        .frame(width: 400)
        .padding()
    }
}

struct ProposeTimeSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: InboxItem
    let onPropose: (Date) -> Void

    @State private var proposedDate = Date()

    var body: some View {
        VStack(spacing: 20) {
            Text("Propose New Time")
                .font(.headline)

            Text("Current: \(formatDateTime(item.event.startDate))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            DatePicker("Proposed time:", selection: $proposedDate)
                .datePickerStyle(.graphical)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Propose") {
                    onPropose(proposedDate)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400)
        .padding()
        .onAppear {
            proposedDate = item.event.startDate
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CalendarInboxView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarInboxView()
            .environmentObject(CalendarInboxManager())
            .environmentObject(EventKitManager())
    }
}
