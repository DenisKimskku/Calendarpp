//
//  SmartSchedulingAssistant.swift
//  calendar++
//
//  AI-powered scheduling assistant using ML to suggest optimal meeting times
//

import Foundation
import Combine

// MARK: - Models

struct SchedulingSuggestion: Identifiable {
    let id = UUID()
    let suggestedTime: Date
    let duration: TimeInterval
    let confidence: Double // 0.0 - 1.0
    let reason: String
    let pros: [String]
    let cons: [String]
}

struct SchedulingPreferences {
    var preferredStartHour: Int = 9
    var preferredEndHour: Int = 17
    var preferredMeetingDuration: Int = 30
    var avoidBackToBack: Bool = true
    var preferMornings: Bool = false
    var preferAfternoons: Bool = false
    var minimumBufferMinutes: Int = 15
}

struct MeetingPattern: Codable {
    let dayOfWeek: Int
    let hourOfDay: Int
    let duration: Int
    let acceptanceRate: Double
    let attendeeCount: Int
}

// MARK: - Smart Scheduling Assistant

class SmartSchedulingAssistant: ObservableObject {
    @Published var suggestions: [SchedulingSuggestion] = []
    @Published var isAnalyzing = false
    @Published var preferences = SchedulingPreferences()

    private var historicalPatterns: [MeetingPattern] = []
    private let calendar = Calendar.current

    // MARK: - Learning from History

    func learnFromHistory(_ events: [EventSummary]) {
        // Analyze historical meeting patterns
        var patternMap: [String: (count: Int, totalDuration: Int, accepted: Int, attendees: Int)] = [:]

        for event in events where !event.isAllDay {
            let weekday = calendar.component(.weekday, from: event.startDate)
            let hour = calendar.component(.hour, from: event.startDate)
            let duration = Int(event.endDate.timeIntervalSince(event.startDate) / 60)

            let key = "\(weekday)-\(hour)"
            let existing = patternMap[key] ?? (0, 0, 0, 0)

            // Assume events that happened are "accepted"
            patternMap[key] = (
                existing.count + 1,
                existing.totalDuration + duration,
                existing.accepted + 1,
                existing.attendees + 1
            )
        }

        // Convert to patterns
        historicalPatterns = patternMap.map { key, value in
            let components = key.split(separator: "-")
            let weekday = Int(components[0]) ?? 1
            let hour = Int(components[1]) ?? 9

            return MeetingPattern(
                dayOfWeek: weekday,
                hourOfDay: hour,
                duration: value.totalDuration / max(value.count, 1),
                acceptanceRate: Double(value.accepted) / Double(max(value.count, 1)),
                attendeeCount: value.attendees / max(value.count, 1)
            )
        }
    }

    // MARK: - Generate Suggestions

    func suggestOptimalTimes(
        for duration: Int,
        within dateRange: DateInterval,
        existingEvents: [EventSummary],
        attendeeCount: Int = 1
    ) -> [SchedulingSuggestion] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        var suggestions: [SchedulingSuggestion] = []
        let durationInterval = TimeInterval(duration * 60)
        let now = Date()
        let busyEvents = existingEvents.filter { !$0.isAllDay }

        // Generate candidate time slots
        var currentDate = dateRange.start
        let endDate = dateRange.end

        guard preferences.preferredStartHour < preferences.preferredEndHour else {
            return []
        }

        while currentDate < endDate {
            // Skip weekends if preferences say so
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday == 1 || weekday == 7 {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                continue
            }

            guard let dayWorkEnd = calendar.date(
                bySettingHour: preferences.preferredEndHour,
                minute: 0,
                second: 0,
                of: currentDate
            ) else {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                continue
            }

            // Check each hour in the working day.
            for hour in preferences.preferredStartHour..<preferences.preferredEndHour {
                guard let candidateTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: currentDate) else { continue }
                let candidateEnd = candidateTime.addingTimeInterval(durationInterval)
                guard candidateTime >= now else { continue }
                guard candidateTime >= dateRange.start && candidateEnd <= endDate else { continue }
                guard candidateEnd <= dayWorkEnd else { continue }

                // Check if slot is available
                let hasConflict = busyEvents.contains { event in
                    let eventInterval = DateInterval(start: event.startDate, end: event.endDate)
                    let candidateInterval = DateInterval(start: candidateTime, end: candidateEnd)
                    return eventInterval.intersects(candidateInterval)
                }

                if !hasConflict {
                    let score = calculateScore(
                        for: candidateTime,
                        duration: duration,
                        existingEvents: busyEvents,
                        attendeeCount: attendeeCount
                    )

                    if score.confidence > 0.3 {
                        suggestions.append(score)
                    }
                }
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Sort by confidence and return top suggestions
        return Array(suggestions.sorted { $0.confidence > $1.confidence }.prefix(5))
    }

    // MARK: - Scoring Algorithm

    private func calculateScore(
        for time: Date,
        duration: Int,
        existingEvents: [EventSummary],
        attendeeCount: Int
    ) -> SchedulingSuggestion {
        var confidence: Double = 0.5 // Base confidence
        var pros: [String] = []
        var cons: [String] = []
        var reason = ""

        let weekday = calendar.component(.weekday, from: time)
        let hour = calendar.component(.hour, from: time)

        // 1. Historical pattern matching
        if let pattern = historicalPatterns.first(where: { $0.dayOfWeek == weekday && $0.hourOfDay == hour }) {
            confidence += pattern.acceptanceRate * 0.2
            if pattern.acceptanceRate > 0.7 {
                pros.append("Similar meetings accepted \(Int(pattern.acceptanceRate * 100))% of the time")
            }
        }

        // 2. Time of day preferences
        if preferences.preferMornings && hour < 12 {
            confidence += 0.15
            pros.append("Morning slot (preferred)")
            reason = "Good morning time slot"
        } else if preferences.preferAfternoons && hour >= 12 {
            confidence += 0.15
            pros.append("Afternoon slot (preferred)")
            reason = "Good afternoon time slot"
        }

        // 3. Check for back-to-back meetings
        let endTime = time.addingTimeInterval(TimeInterval(duration * 60))
        let bufferTime = TimeInterval(preferences.minimumBufferMinutes * 60)
        let busyEvents = existingEvents.filter { !$0.isAllDay }

        let hasBufferBefore = !busyEvents.contains { event in
            let timeDiff = time.timeIntervalSince(event.endDate)
            return timeDiff >= 0 && timeDiff < bufferTime
        }

        let hasBufferAfter = !busyEvents.contains { event in
            let timeDiff = event.startDate.timeIntervalSince(endTime)
            return timeDiff >= 0 && timeDiff < bufferTime
        }

        if hasBufferBefore && hasBufferAfter {
            confidence += 0.2
            pros.append("Has buffer time before and after")
        } else if !hasBufferBefore || !hasBufferAfter {
            confidence -= 0.1
            cons.append("Back-to-back with other meetings")
        }

        // 4. Energy level (morning = high energy, post-lunch = low)
        if hour >= 9 && hour <= 11 {
            confidence += 0.1
            pros.append("Peak morning energy time")
        } else if hour >= 14 && hour <= 15 {
            confidence -= 0.1
            cons.append("Post-lunch energy dip")
        }

        // 5. Meeting density for the day
        let dayStart = calendar.startOfDay(for: time)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        let dayEvents = busyEvents.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }

        if dayEvents.count < 3 {
            confidence += 0.1
            pros.append("Light meeting day")
        } else if dayEvents.count > 6 {
            confidence -= 0.15
            cons.append("Heavy meeting day")
        }

        // 6. Duration fit
        if duration <= 30 {
            confidence += 0.05
            pros.append("Short meeting - easy to fit in")
        } else if duration >= 120 {
            confidence -= 0.05
            cons.append("Long meeting - harder to schedule")
        }

        // Ensure confidence is in valid range
        confidence = max(0.0, min(1.0, confidence))

        if reason.isEmpty {
            reason = confidence > 0.7 ? "Excellent time slot" :
                     confidence > 0.5 ? "Good time slot" :
                     "Available time slot"
        }

        return SchedulingSuggestion(
            suggestedTime: time,
            duration: TimeInterval(duration * 60),
            confidence: confidence,
            reason: reason,
            pros: pros,
            cons: cons
        )
    }

    // MARK: - Predict Meeting Duration

    func predictDuration(for eventTitle: String, attendeeCount: Int) -> Int {
        // Analyze title for keywords
        let title = eventTitle.lowercased()

        // Common patterns
        if title.contains("standup") || title.contains("daily") {
            return 15
        } else if title.contains("1:1") || title.contains("one-on-one") || title.contains("1-on-1") {
            return 30
        } else if title.contains("review") || title.contains("planning") {
            return 60
        } else if title.contains("workshop") || title.contains("training") {
            return 120
        } else if title.contains("retrospective") || title.contains("retro") {
            return 60
        }

        // Based on attendee count
        if attendeeCount <= 2 {
            return 30
        } else if attendeeCount <= 5 {
            return 45
        } else {
            return 60
        }
    }

    // MARK: - Find Best Time

    func findBestTime(
        title: String,
        duration: Int? = nil,
        attendeeCount: Int = 1,
        within days: Int = 7,
        existingEvents: [EventSummary]
    ) -> SchedulingSuggestion? {
        let predictedDuration = duration ?? predictDuration(for: title, attendeeCount: attendeeCount)

        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: days, to: startDate)
            ?? startDate.addingTimeInterval(Double(days) * 24 * 3600)
        let dateRange = DateInterval(start: startDate, end: endDate)

        let suggestions = suggestOptimalTimes(
            for: predictedDuration,
            within: dateRange,
            existingEvents: existingEvents,
            attendeeCount: attendeeCount
        )

        return suggestions.first
    }
}
