//
//  MeetingCostCalculator.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import SwiftUI

struct MeetingCost: Identifiable {
    let id: String
    let event: EventSummary
    let attendeeCount: Int
    let durationHours: Double
    let estimatedCost: Double
    let costPerMinute: Double

    var formattedCost: String {
        String(format: "$%.0f", estimatedCost)
    }

    var costLevel: CostLevel {
        if estimatedCost >= 1000 {
            return .veryHigh
        } else if estimatedCost >= 500 {
            return .high
        } else if estimatedCost >= 200 {
            return .medium
        } else {
            return .low
        }
    }

    enum CostLevel {
        case low, medium, high, veryHigh

        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .veryHigh: return .red
            }
        }

        var emoji: String {
            switch self {
            case .low: return "💰"
            case .medium: return "💸"
            case .high: return "🔥"
            case .veryHigh: return "⚠️"
            }
        }
    }
}

struct WeeklyCostReport {
    let totalCost: Double
    let totalMeetingHours: Double
    let mostExpensiveMeeting: MeetingCost?
    let averageMeetingCost: Double
    let costTrend: Double // % change from last week
}

class MeetingCostCalculator: ObservableObject {
    @Published var meetingCosts: [MeetingCost] = []
    @Published var weeklyReport: WeeklyCostReport?
    @Published var averageHourlyRate: Double = 75.0 { // Default $75/hour
        didSet {
            UserDefaults.standard.set(averageHourlyRate, forKey: "averageHourlyRate")
        }
    }
    @Published var defaultAttendeeCount: Int = 3 {
        didSet {
            UserDefaults.standard.set(defaultAttendeeCount, forKey: "defaultAttendeeCount")
        }
    }

    private let calendar = Calendar.current
    private let userDefaults = UserDefaults.standard
    private let weeklyCostHistoryKey = "meetingCost.weeklyTotalHistory"

    init() {
        loadSettings()
    }

    // MARK: - Settings

    private func loadSettings() {
        if let rate = userDefaults.value(forKey: "averageHourlyRate") as? Double {
            averageHourlyRate = rate
        }

        if let count = userDefaults.value(forKey: "defaultAttendeeCount") as? Int {
            defaultAttendeeCount = count
        }
    }

    // MARK: - Cost Calculation

    func calculateCosts(for events: [EventSummary]) {
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            ?? weekStart.addingTimeInterval(7 * 24 * 3600)

        // Filter to this week's events
        let thisWeekEvents = events.filter { event in
            event.startDate >= weekStart && event.startDate < weekEnd && !event.isAllDay
        }

        // Calculate costs for each meeting
        let costs = thisWeekEvents.map { event in
            calculateMeetingCost(event)
        }
        .sorted { $0.estimatedCost > $1.estimatedCost }

        // Generate weekly report
        let totalCost = costs.reduce(0.0) { $0 + $1.estimatedCost }
        let totalHours = costs.reduce(0.0) { $0 + $1.durationHours }
        let mostExpensive = costs.first
        let averageCost = costs.isEmpty ? 0 : totalCost / Double(costs.count)

        let trend = calculateWeeklyTrend(currentTotal: totalCost, weekStart: weekStart)

        let report = WeeklyCostReport(
            totalCost: totalCost,
            totalMeetingHours: totalHours,
            mostExpensiveMeeting: mostExpensive,
            averageMeetingCost: averageCost,
            costTrend: trend
        )

        saveWeeklyCost(totalCost, for: weekStart)

        DispatchQueue.main.async {
            self.meetingCosts = costs
            self.weeklyReport = report
        }
    }

    private func calculateMeetingCost(_ event: EventSummary) -> MeetingCost {
        // Calculate duration in hours
        let rawDurationMinutes = event.startDate.distance(to: event.endDate) / 60
        let durationMinutes = max(1, rawDurationMinutes)
        let durationHours = durationMinutes / 60

        // Estimate attendee count (default to configured value)
        // In a real app, this would parse from the event or notes
        let attendeeCount = extractAttendeeCount(from: event) ?? defaultAttendeeCount

        // Calculate cost
        let costPerPerson = averageHourlyRate * durationHours
        let totalCost = costPerPerson * Double(attendeeCount)
        let costPerMinute = totalCost / durationMinutes

        return MeetingCost(
            id: event.id,
            event: event,
            attendeeCount: attendeeCount,
            durationHours: durationHours,
            estimatedCost: totalCost,
            costPerMinute: costPerMinute
        )
    }

    private func extractAttendeeCount(from event: EventSummary) -> Int? {
        // Try to extract attendee count from notes
        guard let notes = event.notes else { return nil }

        let lines = notes.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().contains("attendees:") {
                let value = line.replacingOccurrences(
                    of: "(?i)attendees:",
                    with: "",
                    options: .regularExpression
                )
                let names = value
                    .components(separatedBy: ",")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !names.isEmpty {
                    return names.count
                }
            }
        }

        return nil
    }

    private func calculateWeeklyTrend(currentTotal: Double, weekStart: Date) -> Double {
        guard let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else {
            return 0
        }

        let history = loadWeeklyCostHistory()
        let previous = history[weekStorageKey(for: previousWeekStart)] ?? 0
        guard previous > 0 else { return 0 }

        return ((currentTotal - previous) / previous) * 100.0
    }

    private func saveWeeklyCost(_ total: Double, for weekStart: Date) {
        var history = loadWeeklyCostHistory()
        history[weekStorageKey(for: weekStart)] = total

        let keysByDate = history.keys.compactMap { key -> (String, Date)? in
            guard let date = ISO8601DateFormatter.meetingCostWeekKey.date(from: key) else { return nil }
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
            userDefaults.set(data, forKey: weeklyCostHistoryKey)
        }
    }

    private func loadWeeklyCostHistory() -> [String: Double] {
        guard let data = userDefaults.data(forKey: weeklyCostHistoryKey),
              let history = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return history
    }

    private func weekStorageKey(for weekStart: Date) -> String {
        ISO8601DateFormatter.meetingCostWeekKey.string(from: calendar.startOfDay(for: weekStart))
    }

    // MARK: - Insights

    func getHighCostMeetings() -> [MeetingCost] {
        meetingCosts.filter { $0.estimatedCost >= 500 }
    }

    func getCostSavingsSuggestions() -> [String] {
        var suggestions: [String] = []

        let highCost = getHighCostMeetings()
        if !highCost.isEmpty {
            suggestions.append("You have \(highCost.count) high-cost meeting\(highCost.count == 1 ? "" : "s") (>$500)")
        }

        let longMeetings = meetingCosts.filter { $0.durationHours >= 1.5 }
        if !longMeetings.isEmpty {
            suggestions.append("Consider if \(longMeetings.count) meeting\(longMeetings.count == 1 ? "" : "s") over 90 min could be shortened")
        }

        let largeGroupMeetings = meetingCosts.filter { $0.attendeeCount >= 10 }
        if !largeGroupMeetings.isEmpty {
            suggestions.append("\(largeGroupMeetings.count) meeting\(largeGroupMeetings.count == 1 ? "" : "s") with 10+ attendees - could some skip?")
        }

        if suggestions.isEmpty {
            suggestions.append("Your meeting costs are well-managed!")
        }

        return suggestions
    }
}

private extension ISO8601DateFormatter {
    static let meetingCostWeekKey: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
