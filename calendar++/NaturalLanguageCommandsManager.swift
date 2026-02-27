//
//  NaturalLanguageCommandsManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import NaturalLanguage

// MARK: - Models

enum CalendarCommand {
    case move(eventQuery: String, newTime: DateQuery)
    case cancel(eventQuery: String)
    case reschedule(eventQuery: String, newTime: DateQuery)
    case find(query: String)
    case block(duration: Int, when: DateQuery)
    case shorten(eventQuery: String, minutes: Int)
    case extend(eventQuery: String, minutes: Int)
    case addBuffer(eventQuery: String, minutes: Int)
    case unknown

    enum DateQuery {
        case absolute(Date)
        case relative(String) // "tomorrow", "next week", "Friday afternoon"
        case timeOfDay(String) // "3pm", "morning", "afternoon"
    }
}

struct CommandResult {
    let success: Bool
    let message: String
    let affectedEvents: [EventSummary]
}

// MARK: - Manager

class NaturalLanguageCommandsManager: ObservableObject {
    @Published var lastCommand: CalendarCommand?
    @Published var lastResult: CommandResult?
    @Published var commandHistory: [String] = []

    private let calendar = Calendar.current

    // MARK: - Command Parsing

    func parseCommand(_ input: String) -> CalendarCommand {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Move command: "move my 2pm to tomorrow", "move team standup to Friday"
        if lowercased.starts(with: "move ") {
            return parseMoveCommand(lowercased)
        }

        // Cancel command: "cancel my 3pm", "cancel all meetings Friday"
        if lowercased.starts(with: "cancel ") {
            return parseCancelCommand(lowercased)
        }

        // Reschedule: "reschedule team meeting to next week"
        if lowercased.starts(with: "reschedule ") {
            return parseRescheduleCommand(lowercased)
        }

        // Find: "find me 2 hours for project work this week"
        if lowercased.contains("find me ") || lowercased.starts(with: "find ") {
            return parseFindCommand(lowercased)
        }

        // Block time: "block 90 minutes tomorrow morning"
        if lowercased.starts(with: "block ") {
            return parseBlockCommand(lowercased)
        }

        // Shorten: "shorten my 2pm by 15 minutes"
        if lowercased.contains("shorten ") {
            return parseShortenCommand(lowercased)
        }

        // Extend: "extend team meeting by 30 minutes"
        if lowercased.contains("extend ") {
            return parseExtendCommand(lowercased)
        }

        // Add buffer: "add 10 minute buffer to team sync"
        if lowercased.contains("add buffer") || lowercased.contains("add ") && lowercased.contains(" buffer") {
            return parseAddBufferCommand(lowercased)
        }

        return .unknown
    }

    private func parseMoveCommand(_ input: String) -> CalendarCommand {
        // Extract event query and target time
        // "move [event] to [time]"

        if let toIndex = input.range(of: " to ") {
            let eventPart = String(input[input.index(input.startIndex, offsetBy: 5)..<toIndex.lowerBound])
            let timePart = String(input[toIndex.upperBound...])

            let dateQuery = parseTimeExpression(timePart)
            return .move(eventQuery: eventPart, newTime: dateQuery)
        }

        return .unknown
    }

    private func parseCancelCommand(_ input: String) -> CalendarCommand {
        // "cancel [event description]"
        let eventPart = String(input.dropFirst(7)) // Remove "cancel "
        return .cancel(eventQuery: eventPart)
    }

    private func parseRescheduleCommand(_ input: String) -> CalendarCommand {
        // "reschedule [event] to [time]"
        if let toIndex = input.range(of: " to ") {
            let eventPart = String(input[input.index(input.startIndex, offsetBy: 11)..<toIndex.lowerBound])
            let timePart = String(input[toIndex.upperBound...])

            let dateQuery = parseTimeExpression(timePart)
            return .reschedule(eventQuery: eventPart, newTime: dateQuery)
        }

        return .unknown
    }

    private func parseFindCommand(_ input: String) -> CalendarCommand {
        // "find me [duration] for [purpose] [when]"
        return .find(query: input)
    }

    private func parseBlockCommand(_ input: String) -> CalendarCommand {
        // "block [duration] [when]"
        let minutes = extractDuration(from: input) ?? 60
        let whenPart = extractTrailingTimeExpression(afterBlockDurationIn: input)
        let dateQuery = parseTimeExpression(whenPart)

        return .block(duration: minutes, when: dateQuery)
    }

    private func extractTrailingTimeExpression(afterBlockDurationIn input: String) -> String {
        // Captures everything after: "block <duration> <units>"
        // Examples:
        // - "block 90 minutes tomorrow morning" -> "tomorrow morning"
        // - "block 2 hours friday afternoon" -> "friday afternoon"
        let pattern = #"^block\s+\d+\s*(?:minutes?|mins?|hours?|hrs?)\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return ""
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = regex.firstMatch(in: input, range: range),
              match.numberOfRanges >= 2,
              let trailingRange = Range(match.range(at: 1), in: input) else {
            // Fallback: everything after "block"
            return input.replacingOccurrences(of: "block", with: "", options: [.caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(input[trailingRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseShortenCommand(_ input: String) -> CalendarCommand {
        // "shorten [event] by [duration]"
        let minutes = extractDuration(from: input) ?? 15

        if let byIndex = input.range(of: " by ") {
            let eventPart = String(input[input.index(input.startIndex, offsetBy: 8)..<byIndex.lowerBound])
            return .shorten(eventQuery: eventPart, minutes: minutes)
        }

        return .unknown
    }

    private func parseExtendCommand(_ input: String) -> CalendarCommand {
        // "extend [event] by [duration]"
        let minutes = extractDuration(from: input) ?? 15

        if let byIndex = input.range(of: " by ") {
            let eventPart = String(input[input.index(input.startIndex, offsetBy: 7)..<byIndex.lowerBound])
            return .extend(eventQuery: eventPart, minutes: minutes)
        }

        return .unknown
    }

    private func parseAddBufferCommand(_ input: String) -> CalendarCommand {
        let minutes = extractDuration(from: input) ?? 10

        if let toIndex = input.range(of: " to ") {
            let eventPart = String(input[toIndex.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return eventPart.isEmpty ? .unknown : .addBuffer(eventQuery: eventPart, minutes: minutes)
        }

        var eventPart = input
        eventPart = eventPart.replacingOccurrences(of: #"(?i)\badd\b"#, with: "", options: .regularExpression)
        eventPart = eventPart.replacingOccurrences(of: #"(?i)\bbuffer\b"#, with: "", options: .regularExpression)
        eventPart = eventPart.replacingOccurrences(of: #"(?i)\bby\b"#, with: "", options: .regularExpression)
        eventPart = eventPart.replacingOccurrences(of: #"\d+\s*(?i:minutes?|mins?|hours?|hrs?)"#, with: "", options: .regularExpression)
        eventPart = eventPart.trimmingCharacters(in: .whitespacesAndNewlines)

        return eventPart.isEmpty ? .unknown : .addBuffer(eventQuery: eventPart, minutes: minutes)
    }

    // MARK: - Helper Parsers

    private func parseTimeExpression(_ expression: String) -> CalendarCommand.DateQuery {
        let expr = expression.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

        let hasDateKeyword =
            expr.contains("today") ||
            expr.contains("tomorrow") ||
            expr.contains("next week") ||
            expr.contains("this week") ||
            weekdays.contains(where: { expr.contains($0) })

        let hasTimeOfDayKeyword =
            expr.contains("morning") ||
            expr.contains("afternoon") ||
            expr.contains("evening") ||
            expr.contains("tonight")

        // If the expression mixes date + time, keep it as `.relative` so we can resolve both parts later.
        if hasDateKeyword && hasTimeOfDayKeyword {
            return .relative(expr)
        }
        if hasDateKeyword, extractTime(from: expr) != nil {
            return .relative(expr)
        }

        if expr.contains("morning") {
            return .timeOfDay("morning")
        } else if expr.contains("afternoon") {
            return .timeOfDay("afternoon")
        } else if expr.contains("evening") {
            return .timeOfDay("evening")
        } else if expr.contains("tonight") {
            return .timeOfDay("tonight")
        }

        if let time = extractTime(from: expr) {
            return .absolute(time)
        }

        return .relative(expr)
    }

    private func extractTime(from text: String) -> Date? {
        // Try to find time patterns like "2pm", "3:30pm", "14:00"
        let patterns = [
            "(\\d{1,2})\\s*pm",
            "(\\d{1,2})\\s*am",
            "(\\d{1,2}):(\\d{2})\\s*pm",
            "(\\d{1,2}):(\\d{2})\\s*am",
            "(\\d{2}):(\\d{2})"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                var hour = 0
                var minute = 0

                if match.numberOfRanges > 1, let hourRange = Range(match.range(at: 1), in: text) {
                    hour = Int(text[hourRange]) ?? 0
                }

                if match.numberOfRanges > 2, let minuteRange = Range(match.range(at: 2), in: text) {
                    minute = Int(text[minuteRange]) ?? 0
                }

                // Adjust for PM
                if text.lowercased().contains("pm") && hour < 12 {
                    hour += 12
                }

                var components = DateComponents()
                components.hour = hour
                components.minute = minute

                return calendar.date(from: components)
            }
        }

        return nil
    }

    private func extractDuration(from text: String) -> Int? {
        // Extract numbers followed by time units
        let patterns = [
            "(\\d+)\\s*minutes?",
            "(\\d+)\\s*mins?",
            "(\\d+)\\s*hours?",
            "(\\d+)\\s*hrs?"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let valueRange = Range(match.range(at: 1), in: text) {

                if let value = Int(text[valueRange]) {
                    if pattern.contains("hour") {
                        return value * 60
                    } else {
                        return value
                    }
                }
            }
        }

        return nil
    }

    private func extractTimeExpression(from text: String) -> String {
        // Extract temporal expressions: "tomorrow", "next week", "Friday afternoon"
        let keywords = ["tomorrow", "today", "tonight", "morning", "afternoon", "evening",
                        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                        "next week", "this week"]

        for keyword in keywords {
            if text.contains(keyword) {
                return keyword
            }
        }

        return ""
    }

    // MARK: - Command Execution

    func executeCommand(
        _ command: CalendarCommand,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        if case .unknown = command {
            // Don't count unknown input as a "used command".
        } else {
            NotificationCenter.default.post(name: .achievementNaturalLanguageCommandUsed, object: nil)
        }

        switch command {
        case .move(let query, let newTime):
            return executeMoveCommand(query: query, newTime: newTime, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .cancel(let query):
            return executeCancelCommand(query: query, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .reschedule(let query, let newTime):
            return executeRescheduleCommand(query: query, newTime: newTime, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .find(let query):
            return executeFindCommand(query: query, events: events)

        case .block(let duration, let when):
            return executeBlockCommand(duration: duration, when: when, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .shorten(let query, let minutes):
            return executeShortenCommand(query: query, minutes: minutes, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .extend(let query, let minutes):
            return executeExtendCommand(query: query, minutes: minutes, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .addBuffer(let query, let minutes):
            return executeAddBufferCommand(query: query, minutes: minutes, events: events, eventKitManager: eventKitManager, performChanges: performChanges)

        case .unknown:
            return CommandResult(
                success: false,
                message: "I didn't understand that command. Try 'move my 2pm to tomorrow' or 'cancel all meetings Friday'.",
                affectedEvents: []
            )
        }
    }

    private func executeMoveCommand(
        query: String,
        newTime: CalendarCommand.DateQuery,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        let matchedEvents = findMatchingEvents(query: query, in: events)

        guard !matchedEvents.isEmpty else {
            return CommandResult(
                success: false,
                message: "No events found matching '\(query)'",
                affectedEvents: []
            )
        }

        if let disambiguation = disambiguationResultIfNeeded(
            query: query,
            matchedEvents: matchedEvents,
            performChanges: performChanges,
            actionVerb: "move"
        ) {
            return disambiguation
        }

        let eventNames = matchedEvents.map { $0.title }.joined(separator: ", ")
        guard performChanges else {
            return CommandResult(
                success: true,
                message: "Would move \(matchedEvents.count) event(s): \(eventNames)",
                affectedEvents: matchedEvents
            )
        }

        guard let eventKitManager else {
            return CommandResult(
                success: false,
                message: "Calendar manager unavailable.",
                affectedEvents: matchedEvents
            )
        }

        var moved = 0
        var failures: [String] = []
        for event in matchedEvents {
            guard let newStart = resolveDate(newTime, relativeTo: event.startDate, preservingTimeFrom: event.startDate) else {
                failures.append("Could not resolve target time for '\(event.title)'")
                continue
            }

            let duration = event.endDate.timeIntervalSince(event.startDate)
            let newEnd = newStart.addingTimeInterval(duration)

            switch eventKitManager.updateEvent(withId: event.id, startDate: newStart, endDate: newEnd) {
            case .success:
                moved += 1
            case .failure(let error):
                failures.append("'\(event.title)': \(error.localizedDescription)")
            }
        }

        let summary = failures.isEmpty
            ? "Moved \(moved) event(s)."
            : "Moved \(moved) event(s). Failed: \(failures.joined(separator: " | "))"

        return CommandResult(
            success: moved > 0,
            message: summary,
            affectedEvents: matchedEvents
        )
    }

    private func executeCancelCommand(
        query: String,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        let matchedEvents = findMatchingEvents(query: query, in: events)

        guard !matchedEvents.isEmpty else {
            return CommandResult(
                success: false,
                message: "No events found matching '\(query)'",
                affectedEvents: []
            )
        }

        if let disambiguation = disambiguationResultIfNeeded(
            query: query,
            matchedEvents: matchedEvents,
            performChanges: performChanges,
            actionVerb: "cancel"
        ) {
            return disambiguation
        }

        let eventNames = matchedEvents.map { $0.title }.joined(separator: ", ")
        guard performChanges else {
            return CommandResult(
                success: true,
                message: "Would cancel \(matchedEvents.count) event(s): \(eventNames)",
                affectedEvents: matchedEvents
            )
        }

        guard let eventKitManager else {
            return CommandResult(
                success: false,
                message: "Calendar manager unavailable.",
                affectedEvents: matchedEvents
            )
        }

        var deleted = 0
        var failures: [String] = []
        for event in matchedEvents {
            switch eventKitManager.deleteEventResult(withId: event.id) {
            case .success:
                deleted += 1
            case .failure(let error):
                failures.append("'\(event.title)': \(error.localizedDescription)")
            }
        }

        let summary = failures.isEmpty
            ? "Cancelled \(deleted) event(s)."
            : "Cancelled \(deleted) event(s). Failed: \(failures.joined(separator: " | "))"

        return CommandResult(
            success: deleted > 0,
            message: summary,
            affectedEvents: matchedEvents
        )
    }

    private func executeRescheduleCommand(
        query: String,
        newTime: CalendarCommand.DateQuery,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        return executeMoveCommand(query: query, newTime: newTime, events: events, eventKitManager: eventKitManager, performChanges: performChanges)
    }

    private func executeFindCommand(query: String, events: [EventSummary]) -> CommandResult {
        // Extract duration from query
        let duration = extractDuration(from: query) ?? 60

        let (rangeStart, rangeEnd) = findSearchRange(for: query)
        let slots = findFreeSlots(
            durationMinutes: duration,
            in: DateInterval(start: rangeStart, end: rangeEnd),
            events: events,
            limit: 3
        )

        if slots.isEmpty {
            return CommandResult(
                success: false,
                message: "No free slots found for \(duration) minutes in the selected range.",
                affectedEvents: []
            )
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let slotsText = slots.map { "\(formatter.string(from: $0.start)) - \(formatter.string(from: $0.end))" }.joined(separator: " | ")

        return CommandResult(
            success: true,
            message: "Found \(slots.count) slot(s) for \(duration) minutes: \(slotsText)",
            affectedEvents: []
        )
    }

    private func executeBlockCommand(
        duration: Int,
        when: CalendarCommand.DateQuery,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        guard performChanges else {
            return CommandResult(
                success: true,
                message: "Would block \(duration) minutes for focus time",
                affectedEvents: []
            )
        }

        guard let eventKitManager else {
            return CommandResult(
                success: false,
                message: "Calendar manager unavailable.",
                affectedEvents: []
            )
        }

        let now = Date()
        let start = resolveDate(when, relativeTo: now, preservingTimeFrom: now) ?? roundUpToNextQuarterHour(now)
        let end = start.addingTimeInterval(TimeInterval(duration * 60))

        let saveResult = eventKitManager.createEventResult(
            title: "Focus Time",
            startDate: start,
            endDate: end,
            location: nil,
            notes: "Created via calendar++ voice command.",
            calendar: nil
        )

        if case .failure(let error) = saveResult {
            return CommandResult(
                success: false,
                message: error.errorDescription ?? "Failed to create focus-time event.",
                affectedEvents: []
            )
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return CommandResult(
            success: true,
            message: "Blocked \(duration) minutes starting \(formatter.string(from: start)).",
            affectedEvents: []
        )
    }

    private func executeShortenCommand(
        query: String,
        minutes: Int,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        let matchedEvents = findMatchingEvents(query: query, in: events)

        guard !matchedEvents.isEmpty else {
            return CommandResult(
                success: false,
                message: "No events found matching '\(query)'",
                affectedEvents: []
            )
        }

        if let disambiguation = disambiguationResultIfNeeded(
            query: query,
            matchedEvents: matchedEvents,
            performChanges: performChanges,
            actionVerb: "shorten"
        ) {
            return disambiguation
        }

        guard performChanges else {
            return CommandResult(
                success: true,
                message: "Would shorten \(matchedEvents.count) event(s) by \(minutes) minutes",
                affectedEvents: matchedEvents
            )
        }

        guard let eventKitManager else {
            return CommandResult(
                success: false,
                message: "Calendar manager unavailable.",
                affectedEvents: matchedEvents
            )
        }

        var updated = 0
        var failures: [String] = []
        for event in matchedEvents {
            let newEnd = event.endDate.addingTimeInterval(TimeInterval(-minutes * 60))
            if newEnd <= event.startDate.addingTimeInterval(5 * 60) {
                failures.append("'\(event.title)': resulting duration would be too short")
                continue
            }

            switch eventKitManager.updateEvent(withId: event.id, startDate: event.startDate, endDate: newEnd) {
            case .success:
                updated += 1
            case .failure(let error):
                failures.append("'\(event.title)': \(error.localizedDescription)")
            }
        }

        let summary = failures.isEmpty
            ? "Shortened \(updated) event(s) by \(minutes) minutes."
            : "Shortened \(updated) event(s). Failed: \(failures.joined(separator: " | "))"

        return CommandResult(
            success: updated > 0,
            message: summary,
            affectedEvents: matchedEvents
        )
    }

    private func executeExtendCommand(
        query: String,
        minutes: Int,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        let matchedEvents = findMatchingEvents(query: query, in: events)

        guard !matchedEvents.isEmpty else {
            return CommandResult(
                success: false,
                message: "No events found matching '\(query)'",
                affectedEvents: []
            )
        }

        if let disambiguation = disambiguationResultIfNeeded(
            query: query,
            matchedEvents: matchedEvents,
            performChanges: performChanges,
            actionVerb: "extend"
        ) {
            return disambiguation
        }

        guard performChanges else {
            return CommandResult(
                success: true,
                message: "Would extend \(matchedEvents.count) event(s) by \(minutes) minutes",
                affectedEvents: matchedEvents
            )
        }

        guard let eventKitManager else {
            return CommandResult(
                success: false,
                message: "Calendar manager unavailable.",
                affectedEvents: matchedEvents
            )
        }

        var updated = 0
        var failures: [String] = []
        for event in matchedEvents {
            let newEnd = event.endDate.addingTimeInterval(TimeInterval(minutes * 60))
            switch eventKitManager.updateEvent(withId: event.id, startDate: event.startDate, endDate: newEnd) {
            case .success:
                updated += 1
            case .failure(let error):
                failures.append("'\(event.title)': \(error.localizedDescription)")
            }
        }

        let summary = failures.isEmpty
            ? "Extended \(updated) event(s) by \(minutes) minutes."
            : "Extended \(updated) event(s). Failed: \(failures.joined(separator: " | "))"

        return CommandResult(
            success: updated > 0,
            message: summary,
            affectedEvents: matchedEvents
        )
    }

    private func executeAddBufferCommand(
        query: String,
        minutes: Int,
        events: [EventSummary],
        eventKitManager: EventKitManager?,
        performChanges: Bool
    ) -> CommandResult {
        let matchedEvents = findMatchingEvents(query: query, in: events)
            .filter { !$0.isAllDay && !$0.id.hasPrefix("google-") }

        guard !matchedEvents.isEmpty else {
            return CommandResult(
                success: false,
                message: "No editable events found matching '\(query)'",
                affectedEvents: []
            )
        }

        if let disambiguation = disambiguationResultIfNeeded(
            query: query,
            matchedEvents: matchedEvents,
            performChanges: performChanges,
            actionVerb: "add a buffer to"
        ) {
            return disambiguation
        }

        guard performChanges else {
            return CommandResult(
                success: true,
                message: "Would add a \(minutes)-minute buffer after \(matchedEvents.count) event(s)",
                affectedEvents: matchedEvents
            )
        }

        guard let eventKitManager, eventKitManager.hasCalendarAccess else {
            return CommandResult(
                success: false,
                message: "Calendar access is not available.",
                affectedEvents: matchedEvents
            )
        }

        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        var created = 0
        var failures: [String] = []

        for event in matchedEvents {
            let start = event.endDate
            var end = start.addingTimeInterval(TimeInterval(minutes * 60))

            if let next = sortedEvents.first(where: { $0.startDate >= event.endDate && $0.id != event.id }) {
                end = min(end, next.startDate)
            }

            guard end.timeIntervalSince(start) >= 60 else { continue }

            switch eventKitManager.createEventResult(
                title: "Buffer",
                startDate: start,
                endDate: end,
                location: nil,
                notes: "Created via calendar++ natural language command after: \(event.title)",
                calendar: nil
            ) {
            case .success:
                created += 1
            case .failure(let error):
                failures.append("'\(event.title)': \(error.errorDescription ?? "save failed")")
            }
        }

        return CommandResult(
            success: created > 0,
            message: {
                if created == 0 {
                    if failures.isEmpty {
                        return "No room to add buffer events without conflicts."
                    }
                    return "No buffer events added. Failed: \(failures.joined(separator: " | "))"
                }
                if failures.isEmpty {
                    return "Added \(created) buffer event(s)."
                }
                return "Added \(created) buffer event(s). Failed: \(failures.joined(separator: " | "))"
            }(),
            affectedEvents: matchedEvents
        )
    }

    private func disambiguationResultIfNeeded(
        query: String,
        matchedEvents: [EventSummary],
        performChanges: Bool,
        actionVerb: String
    ) -> CommandResult? {
        guard performChanges else { return nil }
        guard matchedEvents.count > 1 else { return nil }
        guard !isBulkQuery(query) else { return nil }

        let preview = matchedEvents
            .prefix(3)
            .map { "\($0.title) (\(formatDateForDisambiguation($0.startDate)))" }
            .joined(separator: ", ")

        let suffix = matchedEvents.count > 3 ? ", +\(matchedEvents.count - 3) more" : ""
        return CommandResult(
            success: false,
            message: "For safety, I won't \(actionVerb) \(matchedEvents.count) events from an ambiguous command. Be more specific (title/date/time), or include 'all meetings'. Matches: \(preview)\(suffix).",
            affectedEvents: matchedEvents
        )
    }

    private func isBulkQuery(_ query: String) -> Bool {
        let lower = query.lowercased()
        return lower.contains("all meetings") ||
            lower.contains("all events") ||
            lower.contains("every meeting") ||
            lower.contains("all of my meetings")
    }

    private func formatDateForDisambiguation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Date Resolution & Scheduling Helpers

    private func resolveDate(
        _ query: CalendarCommand.DateQuery,
        relativeTo referenceDate: Date,
        preservingTimeFrom timeSource: Date
    ) -> Date? {
        let now = Date()

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let preservedHour = calendar.component(.hour, from: timeSource)
        let preservedMinute = calendar.component(.minute, from: timeSource)

        func buildDate(day: Date, hour: Int, minute: Int) -> Date? {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }

        switch query {
        case .absolute(let timeOnly):
            let hour = calendar.component(.hour, from: timeOnly)
            let minute = calendar.component(.minute, from: timeOnly)
            guard var candidate = buildDate(day: referenceDay, hour: hour, minute: minute) else { return nil }
            if candidate < now {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            return candidate

        case .timeOfDay(let bucket):
            let (hour, minute): (Int, Int) = {
                switch bucket {
                case "morning": return (9, 0)
                case "afternoon": return (14, 0)
                case "evening": return (18, 0)
                case "tonight": return (20, 0)
                default: return (preservedHour, preservedMinute)
                }
            }()

            // Time-of-day only is treated as "next occurrence" relative to now.
            let day = calendar.startOfDay(for: now)
            guard var candidate = buildDate(day: day, hour: hour, minute: minute) else { return nil }
            if candidate < now {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            return candidate

        case .relative(let expr):
            let lower = expr.lowercased()
            let weekdays: [(String, Int)] = [
                ("sunday", 1),
                ("monday", 2),
                ("tuesday", 3),
                ("wednesday", 4),
                ("thursday", 5),
                ("friday", 6),
                ("saturday", 7)
            ]
            let hasWeekdayReference = weekdays.contains { lower.contains($0.0) }

            let baseDay = calendar.startOfDay(for: now)
            let targetDay: Date = {
                if lower.contains("tomorrow") {
                    return calendar.date(byAdding: .day, value: 1, to: baseDay) ?? baseDay
                }
                if lower.contains("today") {
                    return baseDay
                }
                if lower.contains("next week") {
                    return calendar.date(byAdding: .day, value: 7, to: baseDay) ?? baseDay
                }

                if let match = weekdays.first(where: { lower.contains($0.0) }) {
                    let targetWeekday = match.1
                    let currentWeekday = calendar.component(.weekday, from: baseDay)
                    let delta = (targetWeekday - currentWeekday + 7) % 7
                    return calendar.date(byAdding: .day, value: delta, to: baseDay) ?? baseDay
                }

                // Fallback to the reference date's day.
                return referenceDay
            }()

            let (hour, minute): (Int, Int) = {
                if let timeOnly = extractTime(from: lower) {
                    return (calendar.component(.hour, from: timeOnly), calendar.component(.minute, from: timeOnly))
                }
                if lower.contains("morning") { return (9, 0) }
                if lower.contains("afternoon") { return (14, 0) }
                if lower.contains("evening") { return (18, 0) }
                if lower.contains("tonight") { return (20, 0) }
                return (preservedHour, preservedMinute)
            }()

            guard var candidate = buildDate(day: targetDay, hour: hour, minute: minute) else { return nil }
            if candidate < now {
                if lower.contains("today") || lower.contains("tomorrow") || lower.contains("next week") {
                    // Ensure obvious-forward-looking queries don't resolve into the past.
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                } else if hasWeekdayReference {
                    // For weekday references ("friday 2pm"), move to next week if today's occurrence already passed.
                    candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
                }
            }
            return candidate
        }
    }

    private func roundUpToNextQuarterHour(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let base = calendar.date(from: comps) else { return date }

        let minute = calendar.component(.minute, from: base)
        let remainder = minute % 15
        let add = remainder == 0 ? 0 : (15 - remainder)
        return calendar.date(byAdding: .minute, value: add, to: base) ?? base
    }

    private func findSearchRange(for query: String) -> (Date, Date) {
        let lower = query.lowercased()
        let now = Date()
        let today = calendar.startOfDay(for: now)

        if lower.contains("tomorrow") {
            let start = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
            return (start, end)
        }

        if lower.contains("today") {
            let start = today
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
            return (start, end)
        }

        if lower.contains("next week") {
            let start = calendar.date(byAdding: .day, value: 7, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
            return (start, end)
        }

        // Default: next 7 days.
        let start = now
        let end = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 3600)
        return (start, end)
    }

    private func findFreeSlots(
        durationMinutes: Int,
        in range: DateInterval,
        events: [EventSummary],
        limit: Int
    ) -> [DateInterval] {
        guard durationMinutes > 0 else { return [] }

        var results: [DateInterval] = []
        var day = calendar.startOfDay(for: range.start)

        while day < range.end && results.count < limit {
            // Working hours: 9am-5pm
            guard let defaultWorkStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                  let defaultWorkEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) else {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
                continue
            }

            let workStart = max(defaultWorkStart, range.start)
            let workEnd = min(defaultWorkEnd, range.end)
            if workEnd <= workStart {
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
                continue
            }

            let dayEvents = events
                .filter { !$0.isAllDay }
                .filter { $0.startDate < workEnd && $0.endDate > workStart }
                .sorted { $0.startDate < $1.startDate }

            let busy = dayEvents.map { event in
                DateInterval(start: max(event.startDate, workStart), end: min(event.endDate, workEnd))
            }
            .sorted { $0.start < $1.start }

            // Merge overlaps.
            var merged: [DateInterval] = []
            for interval in busy {
                guard interval.end > interval.start else { continue }
                if let last = merged.last, interval.start <= last.end {
                    merged.removeLast()
                    merged.append(DateInterval(start: last.start, end: max(last.end, interval.end)))
                } else {
                    merged.append(interval)
                }
            }

            let needed = TimeInterval(durationMinutes * 60)
            var cursor = workStart

            for interval in merged where results.count < limit {
                let gap = interval.start.timeIntervalSince(cursor)
                if gap >= needed {
                    results.append(DateInterval(start: cursor, end: cursor.addingTimeInterval(needed)))
                    if results.count >= limit { break }
                }
                cursor = max(cursor, interval.end)
            }

            if results.count < limit, workEnd.timeIntervalSince(cursor) >= needed {
                results.append(DateInterval(start: cursor, end: cursor.addingTimeInterval(needed)))
            }

            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
        }

        return results
    }

    // MARK: - Event Matching

    private func findMatchingEvents(query: String, in events: [EventSummary]) -> [EventSummary] {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let constraints = parseEventQueryConstraints(from: lowercasedQuery)

        var candidates = events.sorted { $0.startDate < $1.startDate }

        if let dayInterval = constraints.dayInterval {
            candidates = candidates.filter { event in
                event.startDate < dayInterval.end && event.endDate > dayInterval.start
            }
        }

        if let bucket = constraints.timeBucket {
            candidates = candidates.filter { event in
                bucket.hourRange.contains(calendar.component(.hour, from: event.startDate))
            }
        }

        if let explicitTime = constraints.explicitTime {
            let timeMatches = candidates.filter { event in
                let eventHour = calendar.component(.hour, from: event.startDate)
                guard eventHour == explicitTime.hour else { return false }
                if explicitTime.hasExplicitMinute {
                    return calendar.component(.minute, from: event.startDate) == explicitTime.minute
                }
                return true
            }

            if !timeMatches.isEmpty {
                let ranked = rankMatches(
                    candidates: timeMatches,
                    rawQuery: lowercasedQuery,
                    queryTerms: constraints.searchTerms
                )
                return ranked.isEmpty ? timeMatches : ranked
            }
        }

        let rankedByTitle = rankMatches(
            candidates: candidates,
            rawQuery: lowercasedQuery,
            queryTerms: constraints.searchTerms
        )
        if !rankedByTitle.isEmpty {
            return rankedByTitle
        }

        if constraints.isBulk {
            return candidates.filter { !$0.isAllDay }
        }

        return []
    }

    private struct EventQueryConstraints {
        struct ExplicitTime {
            let hour: Int
            let minute: Int
            let hasExplicitMinute: Bool
        }

        enum TimeBucket {
            case morning
            case afternoon
            case evening
            case tonight

            var hourRange: Range<Int> {
                switch self {
                case .morning:
                    return 5..<12
                case .afternoon:
                    return 12..<17
                case .evening:
                    return 17..<24
                case .tonight:
                    return 19..<24
                }
            }
        }

        let dayInterval: DateInterval?
        let timeBucket: TimeBucket?
        let explicitTime: ExplicitTime?
        let isBulk: Bool
        let searchTerms: [String]
    }

    private func parseEventQueryConstraints(from query: String) -> EventQueryConstraints {
        EventQueryConstraints(
            dayInterval: extractDayInterval(from: query),
            timeBucket: extractTimeBucket(from: query),
            explicitTime: extractTimeComponents(from: query).map {
                EventQueryConstraints.ExplicitTime(
                    hour: $0.hour,
                    minute: $0.minute,
                    hasExplicitMinute: $0.hasExplicitMinute
                )
            },
            isBulk: isBulkQuery(query),
            searchTerms: normalizedSearchTerms(from: query)
        )
    }

    private func extractTimeBucket(from query: String) -> EventQueryConstraints.TimeBucket? {
        if query.contains("morning") { return .morning }
        if query.contains("afternoon") { return .afternoon }
        if query.contains("evening") { return .evening }
        if query.contains("tonight") { return .tonight }
        return nil
    }

    private func extractDayInterval(from query: String) -> DateInterval? {
        let now = Date()
        let today = calendar.startOfDay(for: now)

        if query.contains("tomorrow") {
            let start = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
            return DateInterval(start: start, end: end)
        }

        if query.contains("today") {
            let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(24 * 3600)
            return DateInterval(start: today, end: end)
        }

        if query.contains("this week") {
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
                ?? today
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
            return DateInterval(start: start, end: end)
        }

        if query.contains("next week") {
            let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
                ?? today
            let start = calendar.date(byAdding: .day, value: 7, to: startOfThisWeek) ?? today
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
            return DateInterval(start: start, end: end)
        }

        let weekdays: [(name: String, value: Int)] = [
            ("sunday", 1),
            ("monday", 2),
            ("tuesday", 3),
            ("wednesday", 4),
            ("thursday", 5),
            ("friday", 6),
            ("saturday", 7)
        ]
        if let target = weekdays.first(where: { query.contains($0.name) }) {
            let currentWeekday = calendar.component(.weekday, from: today)
            let delta = (target.value - currentWeekday + 7) % 7
            let start = calendar.date(byAdding: .day, value: delta, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 3600)
            return DateInterval(start: start, end: end)
        }

        return nil
    }

    private func extractTimeComponents(from text: String) -> (hour: Int, minute: Int, hasExplicitMinute: Bool)? {
        let textRange = NSRange(text.startIndex..<text.endIndex, in: text)

        // 3:30pm
        if let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2}):(\d{2})\s*(am|pm)\b"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: textRange),
           let hourRange = Range(match.range(at: 1), in: text),
           let minuteRange = Range(match.range(at: 2), in: text),
           let meridiemRange = Range(match.range(at: 3), in: text) {
            var hour = Int(text[hourRange]) ?? 0
            let minute = Int(text[minuteRange]) ?? 0
            let meridiem = text[meridiemRange].lowercased()

            if meridiem == "pm" && hour < 12 { hour += 12 }
            if meridiem == "am" && hour == 12 { hour = 0 }
            return (hour: hour, minute: minute, hasExplicitMinute: true)
        }

        // 2pm
        if let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2})\s*(am|pm)\b"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: textRange),
           let hourRange = Range(match.range(at: 1), in: text),
           let meridiemRange = Range(match.range(at: 2), in: text) {
            var hour = Int(text[hourRange]) ?? 0
            let meridiem = text[meridiemRange].lowercased()

            if meridiem == "pm" && hour < 12 { hour += 12 }
            if meridiem == "am" && hour == 12 { hour = 0 }
            return (hour: hour, minute: 0, hasExplicitMinute: false)
        }

        // 14:30
        if let regex = try? NSRegularExpression(pattern: #"\b(\d{1,2}):(\d{2})\b"#, options: []),
           let match = regex.firstMatch(in: text, range: textRange),
           let hourRange = Range(match.range(at: 1), in: text),
           let minuteRange = Range(match.range(at: 2), in: text) {
            let hour = Int(text[hourRange]) ?? 0
            let minute = Int(text[minuteRange]) ?? 0
            return (hour: hour, minute: minute, hasExplicitMinute: true)
        }

        return nil
    }

    private func normalizedSearchTerms(from query: String) -> [String] {
        var text = query.lowercased()

        // Strip time expressions and durations.
        text = text.replacingOccurrences(of: #"\b\d{1,2}(:\d{2})?\s*(am|pm)\b"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\b\d{1,2}:\d{2}\b"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\b\d+\s*(minutes?|mins?|hours?|hrs?)\b"#, with: " ", options: .regularExpression)

        let stopwords = [
            "move", "cancel", "reschedule", "find", "block", "shorten", "extend", "add", "buffer", "to", "by", "for",
            "my", "the", "a", "an", "all", "meetings", "meeting", "event", "events",
            "today", "tomorrow", "tonight", "morning", "afternoon", "evening", "this", "next", "week",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
        ]

        for word in stopwords {
            text = text.replacingOccurrences(of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", with: " ", options: .regularExpression)
        }

        return text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    private func rankMatches(
        candidates: [EventSummary],
        rawQuery: String,
        queryTerms: [String]
    ) -> [EventSummary] {
        let scored: [(event: EventSummary, score: Int)] = candidates.compactMap { event in
            let title = event.title.lowercased()
            let notes = (event.notes ?? "").lowercased()
            let haystack = "\(title) \(notes)"

            var score = 0
            if !rawQuery.isEmpty && haystack.contains(rawQuery) {
                score += 6
            }

            var matchedTerms = 0
            for term in queryTerms where haystack.contains(term) {
                matchedTerms += 1
                score += 2
            }

            if !queryTerms.isEmpty && matchedTerms == queryTerms.count {
                score += 3
            }

            return score > 0 ? (event: event, score: score) : nil
        }

        guard !scored.isEmpty else { return [] }

        return scored
            .sorted {
                if $0.score == $1.score {
                    return $0.event.startDate < $1.event.startDate
                }
                return $0.score > $1.score
            }
            .map(\.event)
    }

    // MARK: - Public Interface

    func processCommand(
        _ input: String,
        events: [EventSummary],
        eventKitManager: EventKitManager,
        performChanges: Bool
    ) -> CommandResult {
        let command = parseCommand(input)
        let result = executeCommand(
            command,
            events: events,
            eventKitManager: eventKitManager,
            performChanges: performChanges
        )

        // Save to history
        commandHistory.append(input)
        if commandHistory.count > 20 {
            commandHistory.removeFirst()
        }

        DispatchQueue.main.async {
            self.lastCommand = command
            self.lastResult = result
        }

        return result
    }

    func getSuggestions() -> [String] {
        [
            "Move my 2pm to tomorrow",
            "Cancel all meetings Friday afternoon",
            "Find me 2 hours for project work this week",
            "Block 90 minutes tomorrow morning",
            "Shorten team standup by 15 minutes",
            "Reschedule 1:1 with Sarah to next week"
        ]
    }
}
