//
//  SmartBufferTimeManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import EventKit

struct BufferSuggestion: Identifiable {
    let id = UUID()
    let beforeEvent: EventSummary
    let afterEvent: EventSummary
    let gapMinutes: Int
    let suggestedBufferMinutes: Int
    let reason: BufferReason

    enum BufferReason {
        case backToBack // No gap at all
        case tooShort // Less than 5 minutes
        case differentLocations // Meetings in different places
        case longMeeting // After a long meeting (>1 hour)
        case contextSwitch // Different types of meetings

        var description: String {
            switch self {
            case .backToBack:
                return "Back-to-back meetings with no break"
            case .tooShort:
                return "Very short gap - not enough for a break"
            case .differentLocations:
                return "Different locations - need travel time"
            case .longMeeting:
                return "After a long meeting - need recovery time"
            case .contextSwitch:
                return "Different meeting types - need prep time"
            }
        }

        var emoji: String {
            switch self {
            case .backToBack: return "⚡"
            case .tooShort: return "⏱️"
            case .differentLocations: return "🚗"
            case .longMeeting: return "🧠"
            case .contextSwitch: return "🔄"
            }
        }
    }
}

struct BufferPreferences: Codable {
    var minimumBufferMinutes: Int = 5
    var standardBufferMinutes: Int = 10
    var longMeetingThreshold: Int = 60 // meetings longer than this get extra buffer
    var longMeetingBufferMinutes: Int = 15
    var differentLocationBufferMinutes: Int = 20
    var autoAddBuffers: Bool = false
}

enum BufferActionError: LocalizedError {
    case notAuthorized
    case noGap
    case noRoom
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access is not granted. Enable it in System Settings and try again."
        case .noGap:
            return "There is no free time between these meetings to insert a buffer."
        case .noRoom:
            return "There is not enough room to add a buffer event here."
        case .saveFailed(let message):
            return message
        }
    }
}

class SmartBufferTimeManager: ObservableObject {
    @Published var bufferSuggestions: [BufferSuggestion] = []
    @Published var preferences: BufferPreferences = BufferPreferences()
    @Published var backToBackCount: Int = 0
    @Published var averageGapMinutes: Double = 0
    @Published var lastActionMessage: String? = nil

    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current

    init() {
        loadPreferences()
    }

    // MARK: - Preferences

    func loadPreferences() {
        if let data = userDefaults.data(forKey: "bufferPreferences"),
           let prefs = try? JSONDecoder().decode(BufferPreferences.self, from: data) {
            preferences = prefs
        }
    }

    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: "bufferPreferences")
        }
    }

    func updatePreferences(_ newPreferences: BufferPreferences) {
        preferences = newPreferences
        savePreferences()
    }

    // MARK: - Analysis

    func analyzeMeetings(events: [EventSummary]) {
        // Filter to this week's events
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            ?? weekStart.addingTimeInterval(7 * 24 * 3600)

        let thisWeekEvents = events.filter { event in
            event.startDate >= weekStart && event.startDate < weekEnd && !event.isAllDay
        }
        .sorted { $0.startDate < $1.startDate }

        // Find buffer suggestions
        var suggestions: [BufferSuggestion] = []
        var backToBack = 0
        var totalGap = 0.0
        var gapCount = 0

        for (current, next) in zip(thisWeekEvents, thisWeekEvents.dropFirst()) {

            // Check if they're on the same day
            let currentDay = calendar.startOfDay(for: current.startDate)
            let nextDay = calendar.startOfDay(for: next.startDate)

            guard currentDay == nextDay else { continue }

            let gapMinutes = Int(current.endDate.distance(to: next.startDate) / 60)

            // Track stats
            if gapMinutes < 5 {
                backToBack += 1
            }

            if gapMinutes >= 0 && gapMinutes < 480 {
                totalGap += Double(gapMinutes)
                gapCount += 1
            }

            // Determine if buffer is needed
            if let suggestion = createBufferSuggestion(
                beforeEvent: current,
                afterEvent: next,
                gapMinutes: gapMinutes
            ) {
                suggestions.append(suggestion)
            }
        }

        DispatchQueue.main.async {
            self.bufferSuggestions = suggestions
            self.backToBackCount = backToBack
            self.averageGapMinutes = gapCount > 0 ? totalGap / Double(gapCount) : 0
        }
    }

    private func createBufferSuggestion(
        beforeEvent: EventSummary,
        afterEvent: EventSummary,
        gapMinutes: Int
    ) -> BufferSuggestion? {
        var reason: BufferSuggestion.BufferReason?
        var suggestedBuffer = preferences.standardBufferMinutes

        // Check for back-to-back
        if gapMinutes == 0 {
            reason = .backToBack
            suggestedBuffer = preferences.standardBufferMinutes
        }
        // Check for too short gap
        else if gapMinutes < preferences.minimumBufferMinutes {
            reason = .tooShort
            suggestedBuffer = preferences.minimumBufferMinutes
        }
        // Check for different locations
        else if let loc1 = beforeEvent.location,
                let loc2 = afterEvent.location,
                !loc1.isEmpty && !loc2.isEmpty && loc1 != loc2 {
            reason = .differentLocations
            suggestedBuffer = preferences.differentLocationBufferMinutes
        }
        // Check for long meeting
        else {
            let beforeDuration = beforeEvent.startDate.distance(to: beforeEvent.endDate) / 60
            if beforeDuration >= Double(preferences.longMeetingThreshold) && gapMinutes < preferences.longMeetingBufferMinutes {
                reason = .longMeeting
                suggestedBuffer = preferences.longMeetingBufferMinutes
            }
        }

        guard let finalReason = reason else {
            return nil
        }

        return BufferSuggestion(
            beforeEvent: beforeEvent,
            afterEvent: afterEvent,
            gapMinutes: gapMinutes,
            suggestedBufferMinutes: suggestedBuffer,
            reason: finalReason
        )
    }

    // MARK: - Actions

    func addBufferTime(for suggestion: BufferSuggestion, using eventKitManager: EventKitManager) -> Result<String, BufferActionError> {
        guard isCalendarAuthorized() else {
            return .failure(.notAuthorized)
        }

        guard suggestion.gapMinutes > 0 else {
            return .failure(.noGap)
        }

        let requested = max(1, suggestion.suggestedBufferMinutes)
        let bufferMinutes = min(requested, suggestion.gapMinutes)

        let start = suggestion.beforeEvent.endDate
        let unclampedEnd = calendar.date(byAdding: .minute, value: bufferMinutes, to: start) ?? start
        let end = min(unclampedEnd, suggestion.afterEvent.startDate)

        let actualMinutes = Int(end.timeIntervalSince(start) / 60.0)
        guard actualMinutes > 0 else {
            return .failure(.noRoom)
        }

        let title = "Buffer"
        let notes = """
        Auto-created by calendar++.

        Between:
        - \(suggestion.beforeEvent.title)
        - \(suggestion.afterEvent.title)
        """

        switch eventKitManager.createEventResult(
            title: title,
            startDate: start,
            endDate: end,
            location: nil,
            notes: notes,
            calendar: nil
        ) {
        case .success:
            break
        case .failure(let error):
            return .failure(.saveFailed(error.errorDescription ?? "Failed to save buffer event."))
        }

        DispatchQueue.main.async {
            self.bufferSuggestions.removeAll { $0.id == suggestion.id }
            self.lastActionMessage = "Added a \(actualMinutes)-minute buffer."
        }

        return .success("Added a \(actualMinutes)-minute buffer.")
    }

    func dismissSuggestion(_ suggestion: BufferSuggestion) {
        DispatchQueue.main.async {
            self.bufferSuggestions.removeAll { $0.id == suggestion.id }
        }
    }

    func dismissAllSuggestions() {
        DispatchQueue.main.async {
            self.bufferSuggestions.removeAll()
        }
    }

    private func isCalendarAuthorized() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .authorized { return true }
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return true }
        }
        return false
    }

    // MARK: - Quick Actions

    func suggestOptimalBufferPattern() -> String {
        if backToBackCount > 10 {
            return "You have many back-to-back meetings. Consider adding 10-15 minute buffers between all meetings."
        } else if backToBackCount > 5 {
            return "Several back-to-back meetings detected. Try to add 5-10 minute buffers."
        } else if averageGapMinutes < 10 {
            return "Your average gap is \(Int(averageGapMinutes)) minutes. Consider extending to 10-15 minutes."
        } else {
            return "Your buffer time looks good! Average gap: \(Int(averageGapMinutes)) minutes."
        }
    }
}
