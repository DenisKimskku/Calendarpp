//
//  MeetingPrepManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import EventKit
import UserNotifications

struct MeetingPrepInfo: Identifiable {
    let id: String
    let event: EventSummary
    let attendees: [String]
    let lastMeetingDate: Date?
    let relatedNotes: [String]
    let agenda: String?
    let prepTime: TimeInterval // How much time before meeting to show prep
    let warningTime: TimeInterval // Time before meeting to notify
}

class MeetingPrepManager: ObservableObject {
    @Published var upcomingMeetings: [MeetingPrepInfo] = []
    @Published var currentPrepCard: MeetingPrepInfo?
    @Published private(set) var isMonitoring: Bool = false

    private let calendar = Calendar.current
    private let notificationCenter = UNUserNotificationCenter.current()
    private var timer: Timer?
    private var scheduledPrepForEventStart: [String: Date] = [:]
    private var scheduledWarningForEventStart: [String: Date] = [:]

    init() {
        // Intentionally do not prompt for notification permission at init.
        // The UI should call `setEnabled(true)` when the feature is enabled.
    }

    deinit {
        stopMonitoring()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            requestNotificationPermission()
            startMonitoring()
        } else {
            stopMonitoring()
            DispatchQueue.main.async {
                self.currentPrepCard = nil
            }
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard timer == nil else { return }
        DispatchQueue.main.async { self.isMonitoring = true }
        // Check for upcoming meetings every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkUpcomingMeetings()
        }

        // Initial check
        checkUpcomingMeetings()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        let identifiers = scheduledPrepForEventStart.keys.map { "prep-\($0)" } +
            scheduledWarningForEventStart.keys.map { "warning-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        scheduledPrepForEventStart.removeAll()
        scheduledWarningForEventStart.removeAll()
        DispatchQueue.main.async { self.isMonitoring = false }
    }

    // MARK: - Meeting Prep

    func updateUpcomingMeetings(events: [EventSummary]) {
        let now = Date()
        let next24Hours = calendar.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(24 * 3600)

        // Find meetings in next 24 hours
        let upcoming = events.filter { event in
            event.startDate > now && event.startDate < next24Hours && !event.isAllDay
        }
        .sorted { $0.startDate < $1.startDate }
        .map { event -> MeetingPrepInfo in
            createPrepInfo(for: event, allEvents: events)
        }

        let activeIds = Set(upcoming.map(\.id))
        let stalePrepIds = Set(scheduledPrepForEventStart.keys).subtracting(activeIds)
        let staleWarningIds = Set(scheduledWarningForEventStart.keys).subtracting(activeIds)

        if !stalePrepIds.isEmpty || !staleWarningIds.isEmpty {
            let staleIdentifiers = stalePrepIds.map { "prep-\($0)" } + staleWarningIds.map { "warning-\($0)" }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)
        }

        scheduledPrepForEventStart = scheduledPrepForEventStart.filter { activeIds.contains($0.key) }
        scheduledWarningForEventStart = scheduledWarningForEventStart.filter { activeIds.contains($0.key) }

        DispatchQueue.main.async {
            self.upcomingMeetings = upcoming
        }
    }

    private func createPrepInfo(for event: EventSummary, allEvents: [EventSummary]) -> MeetingPrepInfo {
        // Extract attendees from notes (simplified)
        let attendees = extractAttendees(from: event)

        // Find last meeting with similar title
        let lastMeeting = findLastMeeting(similarTo: event, in: allEvents)

        // Extract agenda from notes
        let agenda = extractAgenda(from: event)

        // Determine prep and warning times
        let prepTime: TimeInterval = 15 * 60 // 15 minutes before
        let warningTime: TimeInterval = 5 * 60 // 5 minutes before

        return MeetingPrepInfo(
            id: event.id,
            event: event,
            attendees: attendees,
            lastMeetingDate: lastMeeting?.startDate,
            relatedNotes: [],
            agenda: agenda,
            prepTime: prepTime,
            warningTime: warningTime
        )
    }

    private func extractAttendees(from event: EventSummary) -> [String] {
        // Parse attendees from notes or location field
        // This is a simplified version - in real app, use EKEvent.attendees
        var attendees: [String] = []

        if let notes = event.notes {
            let lines = notes.components(separatedBy: .newlines)
            for line in lines {
                if line.lowercased().contains("attendees:") {
                    let names = line.replacingOccurrences(
                        of: "(?i)attendees:",
                        with: "",
                        options: .regularExpression
                    )
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    attendees.append(contentsOf: names)
                }
            }
        }

        return attendees
    }

    private func findLastMeeting(similarTo event: EventSummary, in allEvents: [EventSummary]) -> EventSummary? {
        let now = Date()

        return allEvents
            .filter { $0.title == event.title && $0.startDate < now }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    private func extractAgenda(from event: EventSummary) -> String? {
        guard let notes = event.notes else { return nil }

        let lines = notes.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.lowercased().contains("agenda:") {
                // Return the agenda line and the next few lines
                let agendaLines = lines[index..<min(index + 5, lines.count)]
                return agendaLines.joined(separator: "\n")
            }
        }

        return nil
    }

    // MARK: - Notifications

    private func checkUpcomingMeetings() {
        let now = Date()
        guard !upcomingMeetings.isEmpty else {
            if currentPrepCard != nil {
                DispatchQueue.main.async {
                    self.currentPrepCard = nil
                }
            }
            return
        }

        for meeting in upcomingMeetings {
            let timeUntilMeeting = now.distance(to: meeting.event.startDate)

            // Schedule prep/warning notifications exactly once per event start time.
            if timeUntilMeeting > 0 {
                schedulePrepNotificationIfNeeded(for: meeting, timeUntilMeeting: timeUntilMeeting)
                scheduleWarningNotificationIfNeeded(for: meeting, timeUntilMeeting: timeUntilMeeting)
            }

            // Show current prep card during final 5-minute window.
            if timeUntilMeeting <= 5 * 60 && timeUntilMeeting > 0 {
                DispatchQueue.main.async {
                    self.currentPrepCard = meeting
                }
            } else if timeUntilMeeting <= 0, currentPrepCard?.id == meeting.id {
                DispatchQueue.main.async {
                    self.currentPrepCard = nil
                }
            }
        }
    }

    private func schedulePrepNotificationIfNeeded(for meeting: MeetingPrepInfo, timeUntilMeeting: TimeInterval) {
        if let scheduledStart = scheduledPrepForEventStart[meeting.id], scheduledStart == meeting.event.startDate {
            return
        }

        let delay = max(1, timeUntilMeeting - meeting.prepTime)
        schedulePrepNotification(for: meeting, delay: delay)
        scheduledPrepForEventStart[meeting.id] = meeting.event.startDate
    }

    private func schedulePrepNotification(for meeting: MeetingPrepInfo, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting in 15 minutes"
        content.body = meeting.event.title

        var bodyText = meeting.event.title

        if !meeting.attendees.isEmpty {
            bodyText += "\n👥 With: \(meeting.attendees.joined(separator: ", "))"
        }

        if meeting.agenda != nil {
            bodyText += "\n📋 Agenda available"
        }

        if let location = meeting.event.location, !location.isEmpty {
            bodyText += "\n📍 \(location)"
        }

        content.body = bodyText
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "prep-\(meeting.id)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling prep notification: \(error.localizedDescription)")
            }
        }
    }

    private func scheduleWarningNotificationIfNeeded(for meeting: MeetingPrepInfo, timeUntilMeeting: TimeInterval) {
        if let scheduledStart = scheduledWarningForEventStart[meeting.id], scheduledStart == meeting.event.startDate {
            return
        }

        let delay = max(1, timeUntilMeeting - meeting.warningTime)
        scheduleWarningNotification(for: meeting, delay: delay)
        scheduledWarningForEventStart[meeting.id] = meeting.event.startDate
    }

    private func scheduleWarningNotification(for meeting: MeetingPrepInfo, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Meeting starting soon"
        content.body = "\(meeting.event.title) starts in 5 minutes"
        content.sound = .default

        // Add "Running late" action
        let runningLateAction = UNNotificationAction(
            identifier: "RUNNING_LATE",
            title: "Running Late",
            options: []
        )

        let joinAction = UNNotificationAction(
            identifier: "JOIN_MEETING",
            title: "Join Now",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: "MEETING_WARNING",
            actions: [runningLateAction, joinAction],
            intentIdentifiers: [],
            options: []
        )
        registerNotificationCategory(category)
        content.categoryIdentifier = "MEETING_WARNING"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "warning-\(meeting.id)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling warning notification: \(error.localizedDescription)")
            }
        }
    }

    private func registerNotificationCategory(_ category: UNNotificationCategory) {
        notificationCenter.getNotificationCategories { existing in
            var categories = existing
            categories.update(with: category)
            self.notificationCenter.setNotificationCategories(categories)
        }
    }

    func dismissPrepCard() {
        currentPrepCard = nil
    }

    // MARK: - Running Late

    func notifyRunningLate(for meeting: MeetingPrepInfo) {
        // In a real app, this would send an email or message to attendees
        print("Notifying attendees of \(meeting.event.title) that you're running late")

        // For now, just show a system notification
        let content = UNMutableNotificationContent()
        content.title = "Attendees notified"
        content.body = "Your team has been informed you're running late to \(meeting.event.title)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "late-notification-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }
}
