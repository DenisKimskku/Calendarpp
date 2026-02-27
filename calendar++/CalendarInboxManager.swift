//
//  CalendarInboxManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import EventKit
import SwiftUI
import AppKit

// MARK: - Models

enum InboxItemAction {
    case accept
    case decline
    case tentative
    case proposeNewTime(Date)
    case delegate(String) // Delegate to someone else
}

struct InboxItem: Identifiable {
    let id: String
    let event: EventSummary
    let inviteDate: Date
    let priority: Priority
    let conflicts: [EventSummary]
    let suggestedAction: SuggestedAction?
    var status: InboxStatus = .pending

    enum Priority: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }

    enum InboxStatus {
        case pending
        case accepted
        case declined
        case tentative
        case actionTaken
    }

    struct SuggestedAction {
        let action: InboxItemAction
        let reason: String
    }
}

struct InboxStatistics {
    let totalPending: Int
    let highPriority: Int
    let withConflicts: Int
    let declineRate: Double // % of invites declined
    let averageResponseTime: TimeInterval
}

// MARK: - Manager

class CalendarInboxManager: ObservableObject {
    @Published var inboxItems: [InboxItem] = []
    @Published var statistics: InboxStatistics?
    @Published var filterMode: FilterMode = .all
    @Published var sortMode: SortMode = .priority

    enum FilterMode {
        case all
        case highPriority
        case conflicts
        case today
        case thisWeek
    }

    enum SortMode {
        case priority
        case date
        case conflicts
    }

    private let calendar = Calendar.current
    private let userDefaults = UserDefaults.standard
    private var allItems: [InboxItem] = []
    private let actionStatsKey = "calendarInbox.actionStats"
    private var actionStats = ActionStats()

    private struct ActionStats: Codable {
        var processedCount: Int = 0
        var declinedCount: Int = 0
        var recentResponseTimes: [TimeInterval] = []
    }

    init() {
        loadActionStats()
    }

    // MARK: - Inbox Processing

    func processInbox(invites: [EventSummary], allEvents: [EventSummary]) {
        // This is intentionally scoped to "pending invitations" (see EventKitManager.pendingInvitations).
        // If there are no pending invites, the inbox should be empty.
        let upcomingInvites = invites.sorted { $0.startDate < $1.startDate }

        var items: [InboxItem] = []

        for event in upcomingInvites {
            // Find conflicts
            let conflicts = findConflicts(for: event, in: allEvents)

            // Determine priority
            let priority = determinePriority(for: event, conflicts: conflicts)

            // Generate suggested action
            let suggestedAction = generateSuggestedAction(
                for: event,
                conflicts: conflicts,
                priority: priority
            )

            let item = InboxItem(
                id: event.id,
                event: event,
                inviteDate: estimatedInviteDate(for: event),
                priority: priority,
                conflicts: conflicts,
                suggestedAction: suggestedAction
            )

            items.append(item)
        }

        // Calculate statistics
        let stats = calculateStatistics(items: items)
        emitInboxZeroAchievementIfNeeded(stats: stats)

        DispatchQueue.main.async {
            self.allItems = items
            self.statistics = stats
            self.applySortAndFilter()
        }
    }

    private func findConflicts(for event: EventSummary, in allEvents: [EventSummary]) -> [EventSummary] {
        allEvents.filter { otherEvent in
            otherEvent.id != event.id &&
            otherEvent.startDate < event.endDate &&
            otherEvent.endDate > event.startDate
        }
    }

    private func determinePriority(for event: EventSummary, conflicts: [EventSummary]) -> InboxItem.Priority {
        // High priority if:
        // - Has conflicts
        // - Starts soon (within 24 hours)
        // - Contains keywords like "urgent", "important", "CEO"

        let hoursTilStart = Date().distance(to: event.startDate) / 3600

        if !conflicts.isEmpty {
            return .high
        }

        if hoursTilStart < 24 {
            return .high
        }

        let keywords = ["urgent", "important", "ceo", "executive", "board"]
        let titleLower = event.title.lowercased()
        if keywords.contains(where: { titleLower.contains($0) }) {
            return .high
        }

        if hoursTilStart < 72 {
            return .medium
        }

        return .low
    }

    private func generateSuggestedAction(
        for event: EventSummary,
        conflicts: [EventSummary],
        priority: InboxItem.Priority
    ) -> InboxItem.SuggestedAction? {
        // Suggest declining if:
        // - Has conflicts with higher priority events
        // - Optional attendance
        // - Recurring and you've declined before

        if !conflicts.isEmpty {
            return InboxItem.SuggestedAction(
                action: .decline,
                reason: "Conflicts with \(conflicts.count) existing event\(conflicts.count == 1 ? "" : "s")"
            )
        }

        // Check if it's a large meeting (optional attendee)
        if let notes = event.notes, notes.lowercased().contains("optional") {
            return InboxItem.SuggestedAction(
                action: .decline,
                reason: "You're marked as optional attendee"
            )
        }

        // Check meeting duration
        let durationHours = event.startDate.distance(to: event.endDate) / 3600
        if durationHours > 2 {
            return InboxItem.SuggestedAction(
                action: .tentative,
                reason: "Long meeting (\(String(format: "%.1f", durationHours)) hrs) - consider if necessary"
            )
        }

        return InboxItem.SuggestedAction(
            action: .accept,
            reason: "No conflicts, fits your schedule"
        )
    }

    private func calculateStatistics(items: [InboxItem]) -> InboxStatistics {
        let pending = items.filter { $0.status == .pending }.count
        let highPri = items.filter { $0.priority == .high && $0.status == .pending }.count
        let withConflicts = items.filter { !$0.conflicts.isEmpty && $0.status == .pending }.count

        let declineRate: Double
        if actionStats.processedCount > 0 {
            declineRate = Double(actionStats.declinedCount) / Double(actionStats.processedCount)
        } else {
            declineRate = 0
        }

        let avgResponseTime: TimeInterval
        if actionStats.recentResponseTimes.isEmpty {
            avgResponseTime = 0
        } else {
            let total = actionStats.recentResponseTimes.reduce(0, +)
            avgResponseTime = total / Double(actionStats.recentResponseTimes.count)
        }

        return InboxStatistics(
            totalPending: pending,
            highPriority: highPri,
            withConflicts: withConflicts,
            declineRate: declineRate,
            averageResponseTime: avgResponseTime
        )
    }

    // MARK: - Actions

    func acceptInvite(_ item: InboxItem) {
        performAction(for: item, action: .accept, openInCalendar: true)
    }

    func declineInvite(_ item: InboxItem, message: String? = nil) {
        if let message = message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copyToClipboard(message)
        }
        performAction(for: item, action: .decline, openInCalendar: true)
    }

    func tentativeInvite(_ item: InboxItem) {
        performAction(for: item, action: .tentative, openInCalendar: true)
    }

    func proposeNewTime(_ item: InboxItem, newTime: Date) {
        // We can't programmatically send a counter-proposal via EventKit on macOS.
        // Open Calendar at the event time so the user can propose/reschedule manually.
        performAction(for: item, action: .proposeNewTime(newTime), openInCalendar: true)
    }

    private func performAction(for item: InboxItem, action: InboxItemAction, openInCalendar: Bool) {
        if openInCalendar {
            openCalendar(at: item.event.startDate)
        }

        if let index = allItems.firstIndex(where: { $0.id == item.id }) {
            let previousStatus = allItems[index].status
            switch action {
            case .accept:
                allItems[index].status = .accepted
            case .decline:
                allItems[index].status = .declined
                if previousStatus == .pending {
                    NotificationCenter.default.post(name: .achievementMeetingDeclined, object: nil)
                }
            case .tentative:
                allItems[index].status = .tentative
            default:
                allItems[index].status = .actionTaken
            }

            if previousStatus == .pending {
                let responseTime = max(0, Date().timeIntervalSince(item.inviteDate))
                actionStats.processedCount += 1
                if case .decline = action {
                    actionStats.declinedCount += 1
                }
                actionStats.recentResponseTimes.append(responseTime)
                if actionStats.recentResponseTimes.count > 100 {
                    actionStats.recentResponseTimes.removeFirst(actionStats.recentResponseTimes.count - 100)
                }
                saveActionStats()
            }

            statistics = calculateStatistics(items: allItems)
            if let statistics {
                emitInboxZeroAchievementIfNeeded(stats: statistics)
            }
            applySortAndFilter()
        }
    }

    // MARK: - Batch Actions

    func acceptAll(matching filter: (InboxItem) -> Bool) {
        for item in allItems.filter(filter) {
            performAction(for: item, action: .accept, openInCalendar: false)
        }
    }

    func declineAll(matching filter: (InboxItem) -> Bool) {
        for item in allItems.filter(filter) {
            performAction(for: item, action: .decline, openInCalendar: false)
        }
    }

    func followAllSuggestions() {
        for item in allItems where item.status == .pending {
            if let suggestion = item.suggestedAction {
                performAction(for: item, action: suggestion.action, openInCalendar: false)
            }
        }
    }

    // MARK: - Filtering & Sorting

    func applySortAndFilter() {
        var filtered = allItems

        // Apply filter
        switch filterMode {
        case .all:
            break
        case .highPriority:
            filtered = filtered.filter { $0.priority == .high }
        case .conflicts:
            filtered = filtered.filter { !$0.conflicts.isEmpty }
        case .today:
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(24 * 3600)
            filtered = filtered.filter { $0.event.startDate >= today && $0.event.startDate < tomorrow }
        case .thisWeek:
            let now = Date()
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 3600)
            filtered = filtered.filter { $0.event.startDate < weekEnd }
        }

        // Apply sort
        switch sortMode {
        case .priority:
            filtered.sort { item1, item2 in
                let priority1 = priorityValue(item1.priority)
                let priority2 = priorityValue(item2.priority)
                return priority1 > priority2
            }
        case .date:
            filtered.sort { $0.event.startDate < $1.event.startDate }
        case .conflicts:
            filtered.sort { $0.conflicts.count > $1.conflicts.count }
        }

        DispatchQueue.main.async {
            self.inboxItems = filtered
        }
    }

    private func priorityValue(_ priority: InboxItem.Priority) -> Int {
        switch priority {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    // MARK: - Smart Suggestions

    func getQuickActions() -> [String] {
        var actions: [String] = []

        let highPriItems = allItems.filter { $0.priority == .high && $0.status == .pending }
        if highPriItems.count > 0 {
            actions.append("Review \(highPriItems.count) high priority invite\(highPriItems.count == 1 ? "" : "s")")
        }

        let conflictItems = allItems.filter { !$0.conflicts.isEmpty && $0.status == .pending }
        if conflictItems.count > 0 {
            actions.append("Resolve \(conflictItems.count) conflict\(conflictItems.count == 1 ? "" : "s")")
        }

        let declineSuggestions = allItems.filter {
            guard $0.status == .pending else { return false }
            if case .decline? = $0.suggestedAction?.action {
                return true
            }
            return false
        }
        if declineSuggestions.count > 0 {
            actions.append("Decline \(declineSuggestions.count) suggested invite\(declineSuggestions.count == 1 ? "" : "s")")
        }

        return actions
    }

    private func openCalendar(at date: Date) {
        // `calshow://<seconds since reference date>` is understood by Calendar.app.
        let seconds = date.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow://\(seconds)"), NSWorkspace.shared.open(url) {
            return
        }
        openCalendarApp()
    }

    private func openCalendarApp() {
        let config = NSWorkspace.OpenConfiguration()
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
            return
        }

        let fallbackURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.openApplication(at: fallbackURL, configuration: config) { _, _ in }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func estimatedInviteDate(for event: EventSummary) -> Date {
        let oneDayBeforeEvent = event.startDate.addingTimeInterval(-24 * 3600)
        return min(Date(), oneDayBeforeEvent)
    }

    private func emitInboxZeroAchievementIfNeeded(stats: InboxStatistics) {
        guard stats.totalPending == 0 else { return }
        NotificationCenter.default.post(name: .achievementInboxZero, object: nil)
    }

    private func saveActionStats() {
        if let data = try? JSONEncoder().encode(actionStats) {
            userDefaults.set(data, forKey: actionStatsKey)
        }
    }

    private func loadActionStats() {
        guard let data = userDefaults.data(forKey: actionStatsKey),
              let decoded = try? JSONDecoder().decode(ActionStats.self, from: data) else {
            return
        }
        actionStats = decoded
    }
}
