//
//  ProductivityAchievementsManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Models

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: Category
    let requirement: Int
    var progress: Int = 0
    var isUnlocked: Bool = false
    var unlockedDate: Date?

    enum Category: String, Codable, CaseIterable {
        case focusTime = "Focus Time"
        case meetings = "Meetings"
        case calendar = "Calendar Health"
        case productivity = "Productivity"

        var color: Color {
            switch self {
            case .focusTime: return .green
            case .meetings: return .blue
            case .calendar: return .purple
            case .productivity: return .orange
            }
        }
    }

    var progressPercentage: Double {
        min(Double(progress) / Double(requirement), 1.0) * 100
    }
}

struct ProductivityStreak: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date?
    var streakType: StreakType

    enum StreakType: String, Codable {
        case focusTime = "Focus Time"
        case inboxZero = "Inbox Zero"
        case calendarHealth = "Healthy Calendar"
        case morningBriefing = "Morning Person"
    }
}

struct ProductivityDailyStats: Codable {
    let date: Date
    let focusHours: Double
    let meetingHours: Double
    let calendarHealth: String
    let inboxCleared: Bool
    let briefingViewed: Bool
}

// MARK: - Manager

class ProductivityAchievementsManager: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var streaks: [ProductivityStreak] = []
    @Published var dailyStats: [ProductivityDailyStats] = []
    @Published var totalPoints: Int = 0
    @Published var level: Int = 1
    @Published private(set) var naturalLanguageCommandCount: Int = 0
    @Published private(set) var declinedMeetingCount: Int = 0

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current

    init() {
        loadProgress()
        setupAchievements()
        loadStreaks()
        subscribeToAppEvents()
    }

    private func subscribeToAppEvents() {
        NotificationCenter.default.publisher(for: .achievementNaturalLanguageCommandUsed)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recordNaturalLanguageCommandUsage()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .achievementMeetingDeclined)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recordMeetingDeclined()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .achievementDailyBriefingViewed)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recordDailyBriefingViewed()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .achievementInboxZero)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recordInboxZeroAchieved()
            }
            .store(in: &cancellables)
    }

    // MARK: - Achievements Setup

    private func setupAchievements() {
        let predefinedAchievements = [
            // Focus Time Achievements
            Achievement(
                id: "focus_warrior",
                title: "Focus Warrior",
                description: "Protect 10 hours of focus time in a week",
                icon: "brain.head.profile",
                category: .focusTime,
                requirement: 10
            ),
            Achievement(
                id: "deep_work_master",
                title: "Deep Work Master",
                description: "Have a 4-hour uninterrupted focus block",
                icon: "flame.fill",
                category: .focusTime,
                requirement: 4
            ),
            Achievement(
                id: "focus_streak_7",
                title: "Week of Focus",
                description: "Maintain 2+ hours of focus time for 7 consecutive days",
                icon: "calendar.badge.clock",
                category: .focusTime,
                requirement: 7
            ),

            // Meeting Achievements
            Achievement(
                id: "meeting_decliner",
                title: "Meeting Decliner",
                description: "Decline 10 meetings to protect your time",
                icon: "hand.raised.fill",
                category: .meetings,
                requirement: 10
            ),
            Achievement(
                id: "no_back_to_back",
                title: "Buffer Master",
                description: "Have zero back-to-back meetings for a full week",
                icon: "hourglass",
                category: .meetings,
                requirement: 7
            ),
            Achievement(
                id: "cost_conscious",
                title: "Cost Conscious",
                description: "Reduce meeting costs by $1000 in a week",
                icon: "dollarsign.circle.fill",
                category: .meetings,
                requirement: 1000
            ),

            // Calendar Health Achievements
            Achievement(
                id: "inbox_zero_streak",
                title: "Inbox Zero Hero",
                description: "Achieve inbox zero for 7 consecutive days",
                icon: "tray",
                category: .calendar,
                requirement: 7
            ),
            Achievement(
                id: "health_score_excellent",
                title: "Excellent Calendar",
                description: "Maintain 'Excellent' calendar health for a month",
                icon: "heart.fill",
                category: .calendar,
                requirement: 30
            ),
            Achievement(
                id: "early_riser",
                title: "Early Riser",
                description: "View daily briefing before 8am for 14 days",
                icon: "sunrise.fill",
                category: .calendar,
                requirement: 14
            ),

            // Productivity Achievements
            Achievement(
                id: "energy_optimizer",
                title: "Energy Optimizer",
                description: "Schedule important meetings during peak energy 20 times",
                icon: "bolt.fill",
                category: .productivity,
                requirement: 20
            ),
            Achievement(
                id: "automation_expert",
                title: "Automation Expert",
                description: "Use 50 natural language commands",
                icon: "wand.and.stars",
                category: .productivity,
                requirement: 50
            ),
            Achievement(
                id: "balance_master",
                title: "Work-Life Balance",
                description: "Maintain 50/50 meeting-focus ratio for 2 weeks",
                icon: "scale.3d",
                category: .productivity,
                requirement: 14
            )
        ]

        // Merge with existing progress
        for predefined in predefinedAchievements {
            if achievements.contains(where: { $0.id == predefined.id }) {
                continue
            }
            achievements.append(predefined)
        }
    }

    // MARK: - Progress Tracking

    func updateProgress(achievementId: String, increment: Int = 1) {
        guard let index = achievements.firstIndex(where: { $0.id == achievementId }) else { return }

        achievements[index].progress += increment

        if achievements[index].progress >= achievements[index].requirement && !achievements[index].isUnlocked {
            unlockAchievement(at: index)
        }

        saveProgress()
    }

    private func unlockAchievement(at index: Int) {
        achievements[index].isUnlocked = true
        achievements[index].unlockedDate = Date()

        // Award points
        let points = calculatePoints(for: achievements[index])
        totalPoints += points

        // Level up check
        updateLevel()

        // Show notification (in real app)
        print("🎉 Achievement Unlocked: \(achievements[index].title) (+\(points) points)")

        saveProgress()
    }

    private func calculatePoints(for achievement: Achievement) -> Int {
        switch achievement.category {
        case .focusTime: return 100
        case .meetings: return 75
        case .calendar: return 50
        case .productivity: return 125
        }
    }

    private func updateLevel() {
        // Simple leveling: 500 points per level
        level = (totalPoints / 500) + 1
    }

    // MARK: - Activity Hooks

    private func recordNaturalLanguageCommandUsage() {
        naturalLanguageCommandCount += 1
        setProgress(achievementId: "automation_expert", progress: naturalLanguageCommandCount)
        saveProgress()
    }

    private func recordMeetingDeclined() {
        declinedMeetingCount += 1
        setProgress(achievementId: "meeting_decliner", progress: declinedMeetingCount)
        saveProgress()
    }

    private func recordDailyBriefingViewed() {
        let hour = calendar.component(.hour, from: Date())
        guard hour < 8 else { return }

        updateStreak(.morningBriefing, completed: true)
        if let streak = streaks.first(where: { $0.streakType == .morningBriefing })?.currentStreak {
            setProgress(achievementId: "early_riser", progress: streak)
        }
        saveProgress()
    }

    private func recordInboxZeroAchieved() {
        updateStreak(.inboxZero, completed: true)
        if let streak = streaks.first(where: { $0.streakType == .inboxZero })?.currentStreak {
            setProgress(achievementId: "inbox_zero_streak", progress: streak)
        }
        saveProgress()
        saveStreaks()
    }

    // MARK: - Computed Progress

    /// Recompute "stats-derived" achievements from the currently loaded events.
    /// Call this when the app refreshes calendar data so Phase 7 isn't a dead-end UI.
    func refreshComputedProgress(events: [EventSummary]) {
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            ?? calendar.startOfDay(for: now)

        var focusHoursThisWeek = 0.0
        var longestFocusBlockThisWeek: TimeInterval = 0

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let stats = dayStats(for: day, events: events)
            focusHoursThisWeek += stats.focusHours
            longestFocusBlockThisWeek = max(longestFocusBlockThisWeek, stats.longestFocusBlock)
        }

        // Weekly achievements
        setProgress(achievementId: "focus_warrior", progress: Int(floor(focusHoursThisWeek)))
        setProgress(achievementId: "deep_work_master", progress: Int(floor(longestFocusBlockThisWeek / 3600.0)))

        // Streak achievements (consecutive days ending today)
        let focusStreak = computeDailyStreak(maxDaysBack: 30) { day in
            dayStats(for: day, events: events).focusHours >= 2.0
        }
        setProgress(achievementId: "focus_streak_7", progress: focusStreak)
        setStreakValue(.focusTime, current: focusStreak)

        let noBackToBackStreak = computeDailyStreak(maxDaysBack: 30) { day in
            !dayStats(for: day, events: events).hasBackToBackMeetings
        }
        setProgress(achievementId: "no_back_to_back", progress: noBackToBackStreak)

        let balanceStreak = computeDailyStreak(maxDaysBack: 90) { day in
            let stats = dayStats(for: day, events: events)
            let total = stats.focusHours + stats.meetingHours
            guard total > 0 else { return false }
            let ratio = stats.focusHours / total
            return ratio >= 0.45 && ratio <= 0.55
        }
        setProgress(achievementId: "balance_master", progress: balanceStreak)

        let healthStreak = computeDailyStreak(maxDaysBack: 120) { day in
            let stats = dayStats(for: day, events: events)
            // Simplified "Excellent" heuristic: <= 2 hours of meetings within 9-5.
            return stats.meetingHours <= 2.0
        }
        setProgress(achievementId: "health_score_excellent", progress: healthStreak)
        setStreakValue(.calendarHealth, current: healthStreak)

        // Action-count achievements (driven by notifications)
        setProgress(achievementId: "meeting_decliner", progress: declinedMeetingCount)
        setProgress(achievementId: "automation_expert", progress: naturalLanguageCommandCount)

        saveProgress()
        saveStreaks()
    }

    private func setProgress(achievementId: String, progress: Int) {
        guard let index = achievements.firstIndex(where: { $0.id == achievementId }) else { return }

        let clamped = min(max(progress, 0), achievements[index].requirement)
        achievements[index].progress = clamped

        if achievements[index].progress >= achievements[index].requirement && !achievements[index].isUnlocked {
            unlockAchievement(at: index)
        }
    }

    private func setStreakValue(_ type: ProductivityStreak.StreakType, current: Int) {
        if let index = streaks.firstIndex(where: { $0.streakType == type }) {
            streaks[index].currentStreak = current
            streaks[index].longestStreak = max(streaks[index].longestStreak, current)
            if current > 0 {
                streaks[index].lastActiveDate = Date()
            }
        }
    }

    private func computeDailyStreak(maxDaysBack: Int, predicate: (Date) -> Bool) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        for _ in 0..<maxDaysBack {
            if predicate(day) {
                streak += 1
            } else {
                break
            }

            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }

        return streak
    }

    private struct DayComputedStats {
        let meetingHours: Double
        let focusHours: Double
        let longestFocusBlock: TimeInterval
        let hasBackToBackMeetings: Bool
    }

    private func dayStats(for day: Date, events: [EventSummary]) -> DayComputedStats {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

        let dayEvents = events
            .filter { !$0.isAllDay && $0.startDate < dayEnd && $0.endDate > dayStart }
            .sorted { $0.startDate < $1.startDate }

        // Back-to-back: any gap < 5 minutes (including overlaps).
        var hasBackToBack = false
        for (current, next) in zip(dayEvents, dayEvents.dropFirst()) {
            let gap = next.startDate.timeIntervalSince(current.endDate)
            if gap < 5 * 60 {
                hasBackToBack = true
                break
            }
        }

        guard let workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart),
              let workEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart),
              workEnd > workStart else {
            return DayComputedStats(meetingHours: 0, focusHours: 0, longestFocusBlock: 0, hasBackToBackMeetings: hasBackToBack)
        }

        let workInterval = DateInterval(start: workStart, end: workEnd)

        let busyIntervals = dayEvents
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            .compactMap { intersect($0, with: workInterval) }
            .sorted { $0.start < $1.start }

        let mergedBusy = mergeIntervals(busyIntervals)
        let busySeconds = mergedBusy.reduce(0.0) { $0 + $1.duration }
        let focusSeconds = max(0.0, workInterval.duration - busySeconds)

        var longestGap: TimeInterval = 0
        var cursor = workStart
        for interval in mergedBusy {
            let gap = interval.start.timeIntervalSince(cursor)
            if gap > longestGap { longestGap = gap }
            cursor = max(cursor, interval.end)
        }
        let finalGap = workEnd.timeIntervalSince(cursor)
        if finalGap > longestGap { longestGap = finalGap }

        return DayComputedStats(
            meetingHours: busySeconds / 3600.0,
            focusHours: focusSeconds / 3600.0,
            longestFocusBlock: longestGap,
            hasBackToBackMeetings: hasBackToBack
        )
    }

    private func intersect(_ a: DateInterval, with b: DateInterval) -> DateInterval? {
        let start = max(a.start, b.start)
        let end = min(a.end, b.end)
        return end > start ? DateInterval(start: start, end: end) : nil
    }

    private func mergeIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        guard let first = intervals.first else { return [] }

        var merged: [DateInterval] = [first]
        for interval in intervals.dropFirst() {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= last.end {
                merged.removeLast()
                merged.append(DateInterval(start: last.start, end: max(last.end, interval.end)))
            } else {
                merged.append(interval)
            }
        }

        return merged
    }

    // MARK: - Streaks

    func updateStreak(_ type: ProductivityStreak.StreakType, completed: Bool) {
        if let index = streaks.firstIndex(where: { $0.streakType == type }) {
            let today = Calendar.current.startOfDay(for: Date())
            let lastActive = streaks[index].lastActiveDate.flatMap { Calendar.current.startOfDay(for: $0) }

            if completed {
                if let lastActive = lastActive, Calendar.current.isDate(lastActive, inSameDayAs: today) {
                    // Already counted today
                    return
                }

                // Check if consecutive
                if let lastActive = lastActive {
                    let daysDifference = Calendar.current.dateComponents([.day], from: lastActive, to: today).day ?? 0

                    if daysDifference == 1 {
                        // Consecutive day
                        streaks[index].currentStreak += 1
                    } else if daysDifference > 1 {
                        // Streak broken
                        streaks[index].currentStreak = 1
                    }
                } else {
                    // First day
                    streaks[index].currentStreak = 1
                }

                streaks[index].lastActiveDate = Date()

                // Update longest
                if streaks[index].currentStreak > streaks[index].longestStreak {
                    streaks[index].longestStreak = streaks[index].currentStreak
                }
            }
        } else {
            // Create new streak
            var newStreak = ProductivityStreak(streakType: type)
            if completed {
                newStreak.currentStreak = 1
                newStreak.longestStreak = 1
                newStreak.lastActiveDate = Date()
            }
            streaks.append(newStreak)
        }

        saveStreaks()
    }

    // MARK: - Daily Stats

    func recordDailyStats(
        focusHours: Double,
        meetingHours: Double,
        calendarHealth: String,
        inboxCleared: Bool,
        briefingViewed: Bool
    ) {
        let today = Calendar.current.startOfDay(for: Date())

        // Remove existing stat for today if any
        dailyStats.removeAll { Calendar.current.isDate($0.date, inSameDayAs: today) }

        let stat = ProductivityDailyStats(
            date: today,
            focusHours: focusHours,
            meetingHours: meetingHours,
            calendarHealth: calendarHealth,
            inboxCleared: inboxCleared,
            briefingViewed: briefingViewed
        )

        dailyStats.append(stat)

        // Keep only last 90 days
        if dailyStats.count > 90 {
            dailyStats.sort { $0.date < $1.date }
            dailyStats.removeFirst(dailyStats.count - 90)
        }

        // Update related achievements
        checkAchievements(with: stat)

        saveDailyStats()
    }

    private func checkAchievements(with stat: ProductivityDailyStats) {
        // Check focus time achievements
        if stat.focusHours >= 2 {
            updateProgress(achievementId: "focus_streak_7")
        }

        if stat.inboxCleared {
            updateProgress(achievementId: "inbox_zero_streak")
            updateStreak(.inboxZero, completed: true)
        }

        if stat.calendarHealth == "Excellent" {
            updateProgress(achievementId: "health_score_excellent")
        }

        if stat.briefingViewed {
            let hour = Calendar.current.component(.hour, from: Date())
            if hour < 8 {
                updateProgress(achievementId: "early_riser")
            }
        }

        // Check balance
        let total = stat.focusHours + stat.meetingHours
        if total > 0 {
            let ratio = stat.focusHours / total
            if ratio >= 0.45 && ratio <= 0.55 {
                updateProgress(achievementId: "balance_master")
            }
        }
    }

    // MARK: - Persistence

    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            userDefaults.set(encoded, forKey: "achievements")
        }
        userDefaults.set(totalPoints, forKey: "totalPoints")
        userDefaults.set(level, forKey: "level")
        userDefaults.set(naturalLanguageCommandCount, forKey: "nlCommandCount")
        userDefaults.set(declinedMeetingCount, forKey: "declinedMeetingCount")
    }

    private func loadProgress() {
        if let data = userDefaults.data(forKey: "achievements"),
           let loaded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = loaded
        }

        totalPoints = userDefaults.integer(forKey: "totalPoints")
        level = userDefaults.integer(forKey: "level")
        if level == 0 { level = 1 }
        naturalLanguageCommandCount = userDefaults.integer(forKey: "nlCommandCount")
        declinedMeetingCount = userDefaults.integer(forKey: "declinedMeetingCount")
    }

    private func saveStreaks() {
        if let encoded = try? JSONEncoder().encode(streaks) {
            userDefaults.set(encoded, forKey: "streaks")
        }
    }

    private func loadStreaks() {
        if let data = userDefaults.data(forKey: "streaks"),
           let loaded = try? JSONDecoder().decode([ProductivityStreak].self, from: data) {
            streaks = loaded
        } else {
            // Initialize default streaks
            streaks = [
                ProductivityStreak(streakType: .focusTime),
                ProductivityStreak(streakType: .inboxZero),
                ProductivityStreak(streakType: .calendarHealth),
                ProductivityStreak(streakType: .morningBriefing)
            ]
        }
    }

    private func saveDailyStats() {
        if let encoded = try? JSONEncoder().encode(dailyStats) {
            userDefaults.set(encoded, forKey: "dailyStats")
        }
    }

    // MARK: - Query Methods

    func getUnlockedCount() -> Int {
        achievements.filter { $0.isUnlocked }.count
    }

    func getTotalCount() -> Int {
        achievements.count
    }

    func getRecentAchievements(count: Int = 5) -> [Achievement] {
        achievements
            .filter { $0.isUnlocked }
            .sorted { ($0.unlockedDate ?? Date.distantPast) > ($1.unlockedDate ?? Date.distantPast) }
            .prefix(count)
            .map { $0 }
    }

    func getNextAchievement() -> Achievement? {
        achievements
            .filter { !$0.isUnlocked }
            .sorted { $0.progressPercentage > $1.progressPercentage }
            .first
    }
}
