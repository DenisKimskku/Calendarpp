//
//  FocusTimeProtectionManager.swift
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

struct FocusTimeBlock: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var dayOfWeek: Int // 1 = Sunday, 2 = Monday, etc.
    var startHour: Int
    var startMinute: Int
    var durationMinutes: Int
    var isActive: Bool = true
    var autoDeclineConflicts: Bool = false
    var declineMessage: String

    var startTime: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }

    var endTime: String {
        let totalMinutes = startHour * 60 + startMinute + durationMinutes
        let endHour = totalMinutes / 60
        let endMinute = totalMinutes % 60
        return String(format: "%02d:%02d", endHour, endMinute)
    }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        var components = DateComponents()
        components.weekday = dayOfWeek
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "Unknown"
    }
}

struct ConflictingMeeting: Identifiable {
    let id: String
    let event: EventSummary
    let focusBlock: FocusTimeBlock
    let conflictType: ConflictType

    enum ConflictType {
        case partial // Meeting partially overlaps focus time
        case complete // Meeting completely within focus time
    }
}

// MARK: - Manager

class FocusTimeProtectionManager: ObservableObject {
    @Published var focusBlocks: [FocusTimeBlock] = []
    @Published var conflictingMeetings: [ConflictingMeeting] = []
    @Published var focusScore: Double = 100.0 // % of planned focus time that survived
    @Published var protectedHoursThisWeek: Double = 0
    @Published var stolenHoursThisWeek: Double = 0

    private let userDefaults = UserDefaults.standard
    private let calendar = Calendar.current

    init() {
        loadFocusBlocks()
    }

    // MARK: - Focus Block Management

    func addFocusBlock(_ block: FocusTimeBlock) {
        focusBlocks.append(block)
        saveFocusBlocks()
    }

    func updateFocusBlock(_ block: FocusTimeBlock) {
        if let index = focusBlocks.firstIndex(where: { $0.id == block.id }) {
            focusBlocks[index] = block
            saveFocusBlocks()
        }
    }

    func deleteFocusBlock(_ block: FocusTimeBlock) {
        focusBlocks.removeAll { $0.id == block.id }
        saveFocusBlocks()
    }

    func toggleBlockActive(_ block: FocusTimeBlock) {
        if let index = focusBlocks.firstIndex(where: { $0.id == block.id }) {
            focusBlocks[index].isActive.toggle()
            saveFocusBlocks()
        }
    }

    private func saveFocusBlocks() {
        if let encoded = try? JSONEncoder().encode(focusBlocks) {
            userDefaults.set(encoded, forKey: "focusTimeBlocks")
        }
    }

    private func loadFocusBlocks() {
        if let data = userDefaults.data(forKey: "focusTimeBlocks"),
           let blocks = try? JSONDecoder().decode([FocusTimeBlock].self, from: data) {
            focusBlocks = blocks
        } else {
            // Create default focus blocks
            focusBlocks = [
                FocusTimeBlock(
                    title: "Morning Deep Work",
                    dayOfWeek: 2, // Monday
                    startHour: 9,
                    startMinute: 0,
                    durationMinutes: 120,
                    autoDeclineConflicts: false,
                    declineMessage: "I'm protecting this time for deep work. Can we reschedule?"
                ),
                FocusTimeBlock(
                    title: "Afternoon Focus",
                    dayOfWeek: 3, // Tuesday
                    startHour: 14,
                    startMinute: 0,
                    durationMinutes: 90,
                    autoDeclineConflicts: false,
                    declineMessage: "I have focus time blocked. Let's find another time."
                )
            ]
        }
    }

    // MARK: - Conflict Detection

    func checkConflicts(events: [EventSummary]) {
        var conflicts: [ConflictingMeeting] = []

        let activeBlocks = focusBlocks.filter { $0.isActive }

        for event in events {
            for block in activeBlocks {
                if let conflict = detectConflict(event: event, focusBlock: block) {
                    conflicts.append(conflict)
                }
            }
        }

        DispatchQueue.main.async {
            self.conflictingMeetings = conflicts
        }

        calculateFocusScore(events: events)
    }

    private func detectConflict(event: EventSummary, focusBlock: FocusTimeBlock) -> ConflictingMeeting? {
        let eventWeekday = calendar.component(.weekday, from: event.startDate)

        // Check if event is on the same day as focus block
        guard eventWeekday == focusBlock.dayOfWeek else {
            return nil
        }

        let eventDay = calendar.startOfDay(for: event.startDate)
        guard let blockStart = calendar.date(
            bySettingHour: focusBlock.startHour,
            minute: focusBlock.startMinute,
            second: 0,
            of: eventDay
        ) else {
            return nil
        }
        let blockEnd = calendar.date(byAdding: .minute, value: focusBlock.durationMinutes, to: blockStart) ?? blockStart

        // Check for overlap
        let hasOverlap = event.startDate < blockEnd && event.endDate > blockStart

        if hasOverlap {
            let conflictType: ConflictingMeeting.ConflictType =
                (event.startDate >= blockStart && event.endDate <= blockEnd)
                ? .complete
                : .partial

            return ConflictingMeeting(
                id: event.id,
                event: event,
                focusBlock: focusBlock,
                conflictType: conflictType
            )
        }

        return nil
    }

    // MARK: - Focus Score Calculation

    private func calculateFocusScore(events: [EventSummary]) {
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
            ?? calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            ?? weekStart.addingTimeInterval(7 * 24 * 3600)

        // Calculate total planned focus hours this week
        var totalPlannedMinutes = 0
        var protectedMinutes = 0
        var stolenMinutes = 0

        let activeBlocks = focusBlocks.filter { $0.isActive }

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }

            if day < weekEnd {
                let weekday = calendar.component(.weekday, from: day)

                for block in activeBlocks where block.dayOfWeek == weekday {
                    totalPlannedMinutes += block.durationMinutes

                    // Check if this focus block has conflicts
                    guard let blockStart = calendar.date(
                        bySettingHour: block.startHour,
                        minute: block.startMinute,
                        second: 0,
                        of: day
                    ) else {
                        continue
                    }
                    let blockEnd = calendar.date(byAdding: .minute, value: block.durationMinutes, to: blockStart)
                        ?? blockStart.addingTimeInterval(TimeInterval(block.durationMinutes * 60))

                    let conflictsInBlock = events.filter { event in
                        event.startDate < blockEnd && event.endDate > blockStart
                    }

                    if conflictsInBlock.isEmpty {
                        protectedMinutes += block.durationMinutes
                    } else {
                        // Calculate how much of the block is stolen
                        let overlaps = conflictsInBlock.compactMap { event -> DateInterval? in
                            let overlapStart = max(event.startDate, blockStart)
                            let overlapEnd = min(event.endDate, blockEnd)
                            guard overlapEnd > overlapStart else { return nil }
                            return DateInterval(start: overlapStart, end: overlapEnd)
                        }.sorted(by: { $0.start < $1.start })

                        var merged: [DateInterval] = []
                        for overlap in overlaps {
                            if let last = merged.last, overlap.start <= last.end {
                                let extended = DateInterval(start: last.start, end: max(last.end, overlap.end))
                                merged.removeLast()
                                merged.append(extended)
                            } else {
                                merged.append(overlap)
                            }
                        }

                        var occupiedMinutes = merged.reduce(0) { partial, interval in
                            partial + Int(interval.duration / 60)
                        }
                        occupiedMinutes = min(occupiedMinutes, block.durationMinutes)

                        stolenMinutes += occupiedMinutes
                        protectedMinutes += (block.durationMinutes - occupiedMinutes)
                    }
                }
            }
        }

        let score = totalPlannedMinutes > 0
            ? (Double(protectedMinutes) / Double(totalPlannedMinutes)) * 100
            : 100.0

        DispatchQueue.main.async {
            self.focusScore = score
            self.protectedHoursThisWeek = Double(protectedMinutes) / 60.0
            self.stolenHoursThisWeek = Double(stolenMinutes) / 60.0
        }
    }

    // MARK: - Auto-Decline

    func getSuggestedDeclineMessage(for conflict: ConflictingMeeting) -> String {
        var message = conflict.focusBlock.declineMessage

        // Add alternative time suggestion
        message += "\n\nI have availability before or after this block. Would any of these times work instead?"

        return message
    }

    func declineMeeting(_ conflict: ConflictingMeeting) {
        // EventKit on macOS doesn't expose a public API to accept/decline invitations.
        // Best-effort workflow:
        // 1) Copy a suggested message.
        // 2) Open Calendar.app at the meeting time so the user can decline quickly.
        let message = getSuggestedDeclineMessage(for: conflict)
        copyToClipboard(message)
        openCalendar(at: conflict.event.startDate)

        DispatchQueue.main.async {
            self.conflictingMeetings.removeAll { $0.id == conflict.id }
        }
    }

    // MARK: - Quick Actions

    func createFocusBlockNow(durationMinutes: Int) {
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let block = FocusTimeBlock(
            title: "Focus Time",
            dayOfWeek: weekday,
            startHour: hour,
            startMinute: minute,
            durationMinutes: durationMinutes,
            autoDeclineConflicts: false,
            declineMessage: "I'm in deep work mode. Can we reschedule?"
        )

        addFocusBlock(block)
    }

    func suggestFocusBlocks(basedOn events: [EventSummary]) -> [FocusTimeBlock] {
        // Analyze calendar and suggest optimal focus time blocks
        var suggestions: [FocusTimeBlock] = []

        // Find gaps in the calendar that could be focus time
        // This is a simplified version - could be more sophisticated

        for weekday in 2...6 { // Monday to Friday
            // Suggest early morning (9-11 AM)
            suggestions.append(FocusTimeBlock(
                title: "Morning Deep Work",
                dayOfWeek: weekday,
                startHour: 9,
                startMinute: 0,
                durationMinutes: 120,
                autoDeclineConflicts: false,
                declineMessage: "I'm protecting morning time for deep work."
            ))

            // Suggest afternoon (2-4 PM)
            suggestions.append(FocusTimeBlock(
                title: "Afternoon Focus",
                dayOfWeek: weekday,
                startHour: 14,
                startMinute: 0,
                durationMinutes: 120,
                autoDeclineConflicts: false,
                declineMessage: "I have focus time blocked. Let's find another time."
            ))
        }

        return suggestions
    }

    private func openCalendar(at date: Date) {
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
}
