//
//  TimeAnalyticsManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import EventKit
import SwiftUI

// MARK: - Data Models

struct TimeAnalytics: Codable {
    var weeklyStats: WeeklyStats
    var dailyBreakdown: [DailyStats]
    var meetingPatterns: MeetingPatterns
    var focusScore: Double // 0-100 score
    var calendarHealth: CalendarHealth
}

struct WeeklyStats: Codable {
    var totalMeetingHours: Double
    var totalFocusHours: Double
    var meetingCount: Int
    var averageMeetingDuration: Double
    var longestFocusBlock: TimeInterval
    var changeFromLastWeek: Double // percentage change
}

struct DailyStats: Codable, Identifiable {
    var id: String { date.ISO8601Format() }
    var date: Date
    var meetingHours: Double
    var focusHours: Double
    var meetingCount: Int
    var energyLevel: EnergyLevel?
}

struct MeetingPatterns: Codable {
    var backToBackCount: Int
    var averageGapMinutes: Double
    var busiestDay: String
    var mostFrequentMeetingHour: Int
    var recurringMeetingPercentage: Double
}

struct CalendarHealth: Codable {
    var status: HealthStatus
    var message: String
    var recommendations: [String]

    enum HealthStatus: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case moderate = "Moderate"
        case heavy = "Heavy"
        case overloaded = "Overloaded"

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .moderate: return .yellow
            case .heavy: return .orange
            case .overloaded: return .red
            }
        }

        var emoji: String {
            switch self {
            case .excellent: return "🟢"
            case .good: return "🔵"
            case .moderate: return "🟡"
            case .heavy: return "🟠"
            case .overloaded: return "🔴"
            }
        }
    }
}

enum EnergyLevel: String, Codable {
    case peak = "Peak"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .peak: return .green
        case .high: return .blue
        case .medium: return .yellow
        case .low: return .orange
        }
    }
}

struct EnergyPattern: Codable, Identifiable {
    var id: Int { hourOfDay }
    var hourOfDay: Int
    var energyLevel: EnergyLevel
}

// MARK: - Manager

class TimeAnalyticsManager: ObservableObject {
    @Published var currentAnalytics: TimeAnalytics?
    @Published var energyPatterns: [EnergyPattern] = []
    @Published var isAnalyzing = false

    private let calendar = Calendar.current
    private let userDefaults = UserDefaults.standard
    private let weeklyMeetingHoursHistoryKey = "timeAnalytics.weeklyMeetingHoursHistory"

    // MARK: - Energy Patterns

    func saveEnergyPattern(_ pattern: EnergyPattern) {
        var patterns = energyPatterns
        patterns.removeAll { $0.hourOfDay == pattern.hourOfDay }
        patterns.append(pattern)
        patterns.sort { $0.hourOfDay < $1.hourOfDay }
        energyPatterns = patterns
        saveEnergyPatternsToDefaults()
    }

    func getEnergyLevel(for hour: Int) -> EnergyLevel? {
        energyPatterns.first { $0.hourOfDay == hour }?.energyLevel
    }

    func getEnergyLevel(for date: Date) -> EnergyLevel? {
        let hour = calendar.component(.hour, from: date)
        return getEnergyLevel(for: hour)
    }

    private func saveEnergyPatternsToDefaults() {
        if let encoded = try? JSONEncoder().encode(energyPatterns) {
            userDefaults.set(encoded, forKey: "energyPatterns")
        }
    }

    func loadEnergyPatterns() {
        if let data = userDefaults.data(forKey: "energyPatterns"),
           let patterns = try? JSONDecoder().decode([EnergyPattern].self, from: data) {
            energyPatterns = patterns
        } else {
            // Set default energy patterns
            energyPatterns = [
                EnergyPattern(hourOfDay: 9, energyLevel: .peak),
                EnergyPattern(hourOfDay: 10, energyLevel: .peak),
                EnergyPattern(hourOfDay: 11, energyLevel: .high),
                EnergyPattern(hourOfDay: 14, energyLevel: .medium),
                EnergyPattern(hourOfDay: 15, energyLevel: .medium),
                EnergyPattern(hourOfDay: 16, energyLevel: .low),
            ]
        }
    }

    // MARK: - Analytics Calculation

    func analyzeWeek(events: [EventSummary]) async {
        await MainActor.run {
            isAnalyzing = true
        }

        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            ?? weekStart.addingTimeInterval(7 * 24 * 3600)

        // Filter events for this week
        let thisWeekEvents = events.filter { event in
            event.startDate >= weekStart && event.startDate < weekEnd
        }

        // Calculate stats
        let weeklyStats = calculateWeeklyStats(events: thisWeekEvents, weekStart: weekStart)
        let dailyBreakdown = calculateDailyBreakdown(events: thisWeekEvents, weekStart: weekStart)
        let meetingPatterns = calculateMeetingPatterns(events: thisWeekEvents)
        let focusScore = calculateFocusScore(weeklyStats: weeklyStats, patterns: meetingPatterns)
        let calendarHealth = assessCalendarHealth(weeklyStats: weeklyStats, patterns: meetingPatterns)

        let analytics = TimeAnalytics(
            weeklyStats: weeklyStats,
            dailyBreakdown: dailyBreakdown,
            meetingPatterns: meetingPatterns,
            focusScore: focusScore,
            calendarHealth: calendarHealth
        )

        saveWeeklyMeetingHours(totalHours: weeklyStats.totalMeetingHours, weekStart: weekStart)

        await MainActor.run {
            currentAnalytics = analytics
            isAnalyzing = false
        }
    }

    private func calculateWeeklyStats(events: [EventSummary], weekStart: Date) -> WeeklyStats {
        let totalMeetingMinutes = events.reduce(0.0) { sum, event in
            sum + event.startDate.distance(to: event.endDate) / 60
        }
        let totalMeetingHours = totalMeetingMinutes / 60

        let meetingCount = events.count
        let averageDuration = meetingCount > 0 ? totalMeetingMinutes / Double(meetingCount) : 0

        // Calculate focus time within work hours (Mon-Fri, 9-17) for this week.
        var focusHours = 0.0
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard (2...6).contains(weekday) else { continue } // Mon-Fri

            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
            let dayEvents = events.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
            focusHours += calculateFocusTimeForDay(events: dayEvents, day: day)
        }

        // Find longest focus block
        let longestFocus = findLongestFocusBlock(events: events, weekStart: weekStart)

        let changeFromLastWeek = calculateWeekOverWeekChange(
            currentTotalMeetingHours: totalMeetingHours,
            weekStart: weekStart
        )

        return WeeklyStats(
            totalMeetingHours: totalMeetingHours,
            totalFocusHours: focusHours,
            meetingCount: meetingCount,
            averageMeetingDuration: averageDuration,
            longestFocusBlock: longestFocus,
            changeFromLastWeek: changeFromLastWeek
        )
    }

    private func calculateDailyBreakdown(events: [EventSummary], weekStart: Date) -> [DailyStats] {
        var dailyStats: [DailyStats] = []

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

            let dayEvents = events.filter { event in
                event.startDate >= dayStart && event.startDate < dayEnd
            }

            let meetingMinutes = dayEvents.reduce(0.0) { sum, event in
                sum + event.startDate.distance(to: event.endDate) / 60
            }

            let focusHours = calculateFocusTimeForDay(events: dayEvents, day: day)

            dailyStats.append(DailyStats(
                date: day,
                meetingHours: meetingMinutes / 60,
                focusHours: focusHours,
                meetingCount: dayEvents.count,
                energyLevel: nil
            ))
        }

        return dailyStats
    }

    private func calculateMeetingPatterns(events: [EventSummary]) -> MeetingPatterns {
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        // Count back-to-back meetings (gap < 5 minutes)
        var backToBackCount = 0
        var totalGapMinutes = 0.0
        var gapCount = 0

        for (current, next) in zip(sortedEvents, sortedEvents.dropFirst()) {
            let gap = current.endDate.distance(to: next.startDate) / 60
            if gap < 5 {
                backToBackCount += 1
            }
            if gap > 0 && gap < 480 { // Only count gaps within same day
                totalGapMinutes += gap
                gapCount += 1
            }
        }

        let averageGap = gapCount > 0 ? totalGapMinutes / Double(gapCount) : 0

        // Find busiest day
        var dayCounts: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"

        for event in events {
            let dayName = dateFormatter.string(from: event.startDate)
            dayCounts[dayName, default: 0] += 1
        }

        let busiestDay = dayCounts.max { $0.value < $1.value }?.key ?? "Monday"

        // Find most frequent meeting hour
        var hourCounts: [Int: Int] = [:]
        for event in events {
            let hour = calendar.component(.hour, from: event.startDate)
            hourCounts[hour, default: 0] += 1
        }

        let mostFrequentHour = hourCounts.max { $0.value < $1.value }?.key ?? 10

        // Estimate recurring percentage using normalized title repetition within the week.
        let recurringPercentage = calculateRecurringMeetingPercentage(events: events)

        return MeetingPatterns(
            backToBackCount: backToBackCount,
            averageGapMinutes: averageGap,
            busiestDay: busiestDay,
            mostFrequentMeetingHour: mostFrequentHour,
            recurringMeetingPercentage: recurringPercentage
        )
    }

    private func calculateFocusTimeForDay(events: [EventSummary], day: Date) -> Double {
        guard let workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
              let workEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day),
              workEnd > workStart else {
            return 0
        }

        let workInterval = DateInterval(start: workStart, end: workEnd)

        let busyIntervals = events
            .filter { !$0.isAllDay }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            .compactMap { intersect($0, with: workInterval) }
            .sorted { $0.start < $1.start }

        let merged = mergeIntervals(busyIntervals)
        let busySeconds = merged.reduce(0.0) { $0 + $1.duration }
        let focusSeconds = max(0.0, workInterval.duration - busySeconds)

        return focusSeconds / 3600.0
    }

    private func findLongestFocusBlock(events: [EventSummary], weekStart: Date) -> TimeInterval {
        var longestGap: TimeInterval = 0

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard (2...6).contains(weekday) else { continue } // Mon-Fri

            guard let workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                  let workEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day),
                  workEnd > workStart else {
                continue
            }

            let workInterval = DateInterval(start: workStart, end: workEnd)
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

            let dayBusy = events
                .filter { !$0.isAllDay && $0.startDate < dayEnd && $0.endDate > dayStart }
                .map { DateInterval(start: $0.startDate, end: $0.endDate) }
                .compactMap { intersect($0, with: workInterval) }
                .sorted { $0.start < $1.start }

            let merged = mergeIntervals(dayBusy)

            var cursor = workStart
            for interval in merged {
                let gap = interval.start.timeIntervalSince(cursor)
                if gap > longestGap { longestGap = gap }
                cursor = max(cursor, interval.end)
            }

            let finalGap = workEnd.timeIntervalSince(cursor)
            if finalGap > longestGap { longestGap = finalGap }
        }

        return longestGap
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

    private func calculateFocusScore(weeklyStats: WeeklyStats, patterns: MeetingPatterns) -> Double {
        var score = 100.0

        // Penalize for too many meetings
        let totalHours = weeklyStats.totalMeetingHours + weeklyStats.totalFocusHours
        if totalHours > 0 {
            let meetingRatio = weeklyStats.totalMeetingHours / totalHours
            if meetingRatio > 0.7 {
                score -= 30
            } else if meetingRatio > 0.5 {
                score -= 15
            }
        }

        // Penalize for back-to-back meetings
        if patterns.backToBackCount > 10 {
            score -= 20
        } else if patterns.backToBackCount > 5 {
            score -= 10
        }

        // Reward for long focus blocks
        let longestFocusHours = weeklyStats.longestFocusBlock / 3600
        if longestFocusHours > 3 {
            score += 10
        } else if longestFocusHours < 1 {
            score -= 15
        }

        return max(0, min(100, score))
    }

    private func assessCalendarHealth(weeklyStats: WeeklyStats, patterns: MeetingPatterns) -> CalendarHealth {
        let meetingHours = weeklyStats.totalMeetingHours
        var recommendations: [String] = []

        let status: CalendarHealth.HealthStatus
        let message: String

        if meetingHours > 30 {
            status = .overloaded
            message = "Your calendar is severely overloaded. Consider declining optional meetings."
            recommendations = [
                "Decline 2-3 optional meetings this week",
                "Block focus time for deep work",
                "Review recurring meetings for relevance"
            ]
        } else if meetingHours > 20 {
            status = .heavy
            message = "Meeting load is heavy. Look for opportunities to reduce."
            recommendations = [
                "Add buffer time between meetings",
                "Consider declining optional meetings",
                "Block at least 2 hours for focus work daily"
            ]
        } else if meetingHours > 15 {
            status = .moderate
            message = "Calendar is moderately busy. Monitor for creep."
            recommendations = [
                "Protect morning hours for deep work",
                "Review meeting attendance needs"
            ]
        } else if meetingHours > 10 {
            status = .good
            message = "Good balance between meetings and focus time."
            recommendations = [
                "Maintain current calendar discipline"
            ]
        } else {
            status = .excellent
            message = "Excellent calendar health with plenty of focus time."
            recommendations = []
        }

        // Add recommendations for back-to-back meetings
        if patterns.backToBackCount > 5 {
            recommendations.append("You have \(patterns.backToBackCount) back-to-back meetings. Add 5-15 min buffers.")
        }

        return CalendarHealth(status: status, message: message, recommendations: recommendations)
    }

    // MARK: - History / Trends

    private func calculateWeekOverWeekChange(currentTotalMeetingHours: Double, weekStart: Date) -> Double {
        guard let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else {
            return 0
        }

        let history = loadWeeklyMeetingHoursHistory()
        let previous = history[weekStorageKey(for: previousWeekStart)] ?? 0
        guard previous > 0 else { return 0 }

        return ((currentTotalMeetingHours - previous) / previous) * 100.0
    }

    private func calculateRecurringMeetingPercentage(events: [EventSummary]) -> Double {
        guard !events.isEmpty else { return 0 }

        let normalizedTitles = events.map { normalizeTitle($0.title) }
        let counts = Dictionary(grouping: normalizedTitles, by: { $0 }).mapValues(\.count)

        let recurringCount = normalizedTitles.reduce(0) { partial, title in
            partial + ((counts[title] ?? 0) > 1 ? 1 : 0)
        }

        return (Double(recurringCount) / Double(events.count)) * 100.0
    }

    private func normalizeTitle(_ title: String) -> String {
        let collapsedWhitespace = title
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsedWhitespace
    }

    private func saveWeeklyMeetingHours(totalHours: Double, weekStart: Date) {
        var history = loadWeeklyMeetingHoursHistory()
        history[weekStorageKey(for: weekStart)] = totalHours

        // Keep the map bounded so defaults don't grow forever.
        let keysByDate = history.keys.compactMap { key -> (String, Date)? in
            guard let date = ISO8601DateFormatter.dayOnly.date(from: key) else { return nil }
            return (key, date)
        }
        if keysByDate.count > 24 {
            let sorted = keysByDate.sorted { $0.1 < $1.1 }
            let keysToDrop = sorted.prefix(keysByDate.count - 24).map(\.0)
            for key in keysToDrop {
                history.removeValue(forKey: key)
            }
        }

        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: weeklyMeetingHoursHistoryKey)
        }
    }

    private func loadWeeklyMeetingHoursHistory() -> [String: Double] {
        guard let data = userDefaults.data(forKey: weeklyMeetingHoursHistoryKey),
              let history = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return history
    }

    private func weekStorageKey(for weekStart: Date) -> String {
        ISO8601DateFormatter.dayOnly.string(from: calendar.startOfDay(for: weekStart))
    }
}

private extension ISO8601DateFormatter {
    static let dayOnly: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
