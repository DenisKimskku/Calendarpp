//
//  DailyBriefingManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import UserNotifications
import EventKit

struct DailyBriefing {
    let date: Date
    let totalMeetings: Int
    let totalMeetingHours: Double
    let focusTimeHours: Double
    let firstMeeting: EventSummary?
    let lastMeeting: EventSummary?
    let hasBackToBack: Bool
    let backToBackCount: Int
    let warnings: [String]
    let suggestions: [String]
    let weatherNote: String?
}

class DailyBriefingManager: ObservableObject {
    @Published var todaysBriefing: DailyBriefing?
    @Published var briefingTime: Date = {
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }() {
        didSet {
            let hour = calendar.component(.hour, from: briefingTime)
            let minute = calendar.component(.minute, from: briefingTime)
            UserDefaults.standard.set(hour, forKey: "briefingHour")
            UserDefaults.standard.set(minute, forKey: "briefingMinute")

            if isEnabled {
                scheduleDailyBriefing()
            }
        }
    }
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "dailyBriefingEnabled")
            if isEnabled {
                requestNotificationPermission()
                scheduleDailyBriefing()
            } else {
                cancelScheduledBriefing()
            }
        }
    }

    private let notificationCenter = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    init() {
        loadSettings()
    }

    // MARK: - Settings

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "dailyBriefingEnabled")

        if let hour = UserDefaults.standard.value(forKey: "briefingHour") as? Int,
           let minute = UserDefaults.standard.value(forKey: "briefingMinute") as? Int {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            briefingTime = calendar.date(from: components) ?? briefingTime
        }
    }

    func setBriefingTime(hour: Int, minute: Int) {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        briefingTime = calendar.date(from: components) ?? briefingTime
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted {
                print("Daily briefing notifications not authorized")
            }
        }
    }

    // MARK: - Briefing Generation

    func generateBriefing(for date: Date, events: [EventSummary]) -> DailyBriefing {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

        // Filter events for today
        let todaysEvents = events.filter { event in
            event.startDate >= dayStart && event.startDate < dayEnd && !event.isAllDay
        }
        .sorted { $0.startDate < $1.startDate }

        // Calculate meeting stats
        let totalMeetings = todaysEvents.count
        let totalMinutes = todaysEvents.reduce(0.0) { sum, event in
            sum + event.startDate.distance(to: event.endDate) / 60
        }
        let totalMeetingHours = totalMinutes / 60

        // Calculate focus time (8 hour work day - meeting time)
        let workHours = 8.0
        let focusTimeHours = max(0, workHours - totalMeetingHours)

        // Find first and last meetings
        let firstMeeting = todaysEvents.first
        let lastMeeting = todaysEvents.last

        // Check for back-to-back meetings
        var backToBackCount = 0
        for (current, next) in zip(todaysEvents, todaysEvents.dropFirst()) {
            let gap = current.endDate.distance(to: next.startDate) / 60
            if gap < 5 {
                backToBackCount += 1
            }
        }
        let hasBackToBack = backToBackCount > 0

        // Generate warnings
        var warnings: [String] = []

        if totalMeetings > 6 {
            warnings.append("⚠️ Heavy meeting day (\(totalMeetings) meetings)")
        }

        if hasBackToBack {
            warnings.append("⚠️ Back-to-back meetings (\(backToBackCount) instances)")
        }

        if totalMeetingHours > 6 {
            warnings.append("⚠️ Over 6 hours in meetings")
        }

        if focusTimeHours < 2 {
            warnings.append("⚠️ Less than 2 hours of focus time")
        }

        // Check for long consecutive meeting blocks
        var currentBlockDuration = 0.0
        var maxBlockDuration = 0.0

        var previousEventEnd: Date?
        for event in todaysEvents {
            let duration = event.startDate.distance(to: event.endDate) / 3600

            if let previousEnd = previousEventEnd {
                let gap = previousEnd.distance(to: event.startDate) / 60
                if gap < 15 {
                    currentBlockDuration += duration
                } else {
                    maxBlockDuration = max(maxBlockDuration, currentBlockDuration)
                    currentBlockDuration = duration
                }
            } else {
                currentBlockDuration = duration
            }

            previousEventEnd = event.endDate
        }
        maxBlockDuration = max(maxBlockDuration, currentBlockDuration)

        if maxBlockDuration > 3 {
            warnings.append("⚠️ Consecutive meetings for \(String(format: "%.1f", maxBlockDuration)) hours")
        }

        // Generate suggestions
        var suggestions: [String] = []

        if focusTimeHours > 3 {
            suggestions.append("💡 Good focus time available - protect it!")
        }

        if totalMeetings == 0 {
            suggestions.append("💡 No meetings today - great for deep work")
        }

        if hasBackToBack {
            suggestions.append("💡 Add buffer time between meetings")
        }

        if let firstMeeting = firstMeeting, firstMeeting.startDate > Date() {
            let hourUntilFirst = Date().distance(to: firstMeeting.startDate) / 3600
            if hourUntilFirst > 2 {
                suggestions.append("💡 Use morning for important work before first meeting")
            }
        }

        return DailyBriefing(
            date: date,
            totalMeetings: totalMeetings,
            totalMeetingHours: totalMeetingHours,
            focusTimeHours: focusTimeHours,
            firstMeeting: firstMeeting,
            lastMeeting: lastMeeting,
            hasBackToBack: hasBackToBack,
            backToBackCount: backToBackCount,
            warnings: warnings,
            suggestions: suggestions,
            weatherNote: nil
        )
    }

    // MARK: - Scheduling

    func scheduleDailyBriefing() {
        // Cancel existing notifications
        cancelScheduledBriefing()

        guard isEnabled else { return }

        // Schedule daily briefing
        let hour = calendar.component(.hour, from: briefingTime)
        let minute = calendar.component(.minute, from: briefingTime)

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = "Your daily briefing is ready"
        content.sound = .default
        content.categoryIdentifier = "DAILY_BRIEFING"

        // Add action to view full briefing
        let viewAction = UNNotificationAction(
            identifier: "VIEW_BRIEFING",
            title: "View Briefing",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: "DAILY_BRIEFING",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        registerNotificationCategory(category)

        let request = UNNotificationRequest(
            identifier: "daily-briefing",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling daily briefing: \(error.localizedDescription)")
            }
        }
    }

    private func cancelScheduledBriefing() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-briefing"])
    }

    // MARK: - Notification Content

    func sendBriefingNotification(_ briefing: DailyBriefing) {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = formatBriefingMessage(briefing)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "briefing-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    private func registerNotificationCategory(_ category: UNNotificationCategory) {
        notificationCenter.getNotificationCategories { existing in
            var categories = existing
            categories.update(with: category)
            self.notificationCenter.setNotificationCategories(categories)
        }
    }

    private func formatBriefingMessage(_ briefing: DailyBriefing) -> String {
        var message = ""

        if briefing.totalMeetings == 0 {
            message = "No meetings today - perfect for deep work!"
        } else {
            message = "Today: \(briefing.totalMeetings) meeting\(briefing.totalMeetings == 1 ? "" : "s"), "
            message += String(format: "%.1f hrs in meetings", briefing.totalMeetingHours)

            if briefing.focusTimeHours > 0 {
                message += String(format: ", %.1f hrs focus time", briefing.focusTimeHours)
            }

            if briefing.hasBackToBack {
                message += "\n⚠️ You have \(briefing.backToBackCount) back-to-back meeting block\(briefing.backToBackCount == 1 ? "" : "s")"
            }

            if let firstMeeting = briefing.firstMeeting {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                message += "\n\nFirst meeting: \(firstMeeting.title) at \(formatter.string(from: firstMeeting.startDate))"
            }
        }

        return message
    }

    // MARK: - Update Today's Briefing

    func updateTodaysBriefing(events: [EventSummary]) {
        let briefing = generateBriefing(for: Date(), events: events)

        DispatchQueue.main.async {
            self.todaysBriefing = briefing
        }
    }
}
