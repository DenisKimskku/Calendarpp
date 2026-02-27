//
//  SmartConflictPredictor.swift
//  calendar++
//
//  AI-powered conflict prediction and resolution
//

import Foundation
import Combine

// MARK: - Models

enum ConflictSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
}

enum ConflictType: String, Codable {
    case overlap = "Time Overlap"
    case backToBack = "Back-to-Back"
    case travelTime = "Insufficient Travel Time"
    case overload = "Too Many Meetings"
    case energyDrain = "Energy Drain"
    case focusInterruption = "Focus Interruption"
    case recurring = "Recurring Conflict"
}

struct PredictedConflict: Identifiable {
    let id = UUID()
    let type: ConflictType
    let severity: ConflictSeverity
    let events: [EventSummary]
    let description: String
    let prediction: String
    let suggestedResolution: String
    let confidence: Double
}

struct ConflictResolution {
    let type: ResolutionType
    let description: String
    let events: [EventSummary]
    let newTimes: [Date]?

    enum ResolutionType {
        case reschedule
        case decline
        case shorten
        case addBuffer
        case delegate
        case combine
    }
}

// MARK: - Smart Conflict Predictor

class SmartConflictPredictor: ObservableObject {
    @Published var predictedConflicts: [PredictedConflict] = []
    @Published var isAnalyzing = false

    private let calendar = Calendar.current
    private var historicalConflicts: [ConflictPattern] = []

    struct ConflictPattern: Codable {
        let type: ConflictType
        let dayOfWeek: Int
        let hourOfDay: Int
        let frequency: Int
        let resolved: Bool
    }

    // MARK: - Conflict Detection

    func detectConflicts(in events: [EventSummary]) {
        isAnalyzing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let timedEvents = events.filter { !$0.isAllDay }

            var conflicts: [PredictedConflict] = []

            // 1. Direct time overlaps
            conflicts.append(contentsOf: self.detectOverlaps(timedEvents))

            // 2. Back-to-back meetings
            conflicts.append(contentsOf: self.detectBackToBack(timedEvents))

            // 3. Travel time conflicts
            conflicts.append(contentsOf: self.detectTravelConflicts(timedEvents))

            // 4. Meeting overload
            conflicts.append(contentsOf: self.detectOverload(timedEvents))

            // 5. Energy drain patterns
            conflicts.append(contentsOf: self.detectEnergyDrain(timedEvents))

            // 6. Focus time interruptions
            conflicts.append(contentsOf: self.detectFocusInterruptions(timedEvents))

            // 7. Recurring conflicts
            conflicts.append(contentsOf: self.detectRecurringConflicts(timedEvents))

            DispatchQueue.main.async {
                self.predictedConflicts = conflicts.sorted {
                    let lhs = self.severityRank($0.severity)
                    let rhs = self.severityRank($1.severity)
                    if lhs == rhs {
                        return $0.confidence > $1.confidence
                    }
                    return lhs > rhs
                }
                self.isAnalyzing = false
            }
        }
    }

    // MARK: - Detection Methods

    private func detectOverlaps(_ events: [EventSummary]) -> [PredictedConflict] {
        var conflicts: [PredictedConflict] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        for i in 0..<sortedEvents.count {
            for j in (i+1)..<sortedEvents.count {
                let event1 = sortedEvents[i]
                let event2 = sortedEvents[j]

                // Skip if same event
                if event1.id == event2.id { continue }

                // Check overlap
                if event1.endDate > event2.startDate && event1.startDate < event2.endDate {
                    conflicts.append(PredictedConflict(
                        type: .overlap,
                        severity: .critical,
                        events: [event1, event2],
                        description: "Double-booked: '\(event1.title)' and '\(event2.title)'",
                        prediction: "You cannot attend both meetings simultaneously",
                        suggestedResolution: "Decline one meeting or reschedule to a different time",
                        confidence: 1.0
                    ))
                }
            }
        }

        return conflicts
    }

    private func detectBackToBack(_ events: [EventSummary]) -> [PredictedConflict] {
        var conflicts: [PredictedConflict] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        for (event1, event2) in zip(sortedEvents, sortedEvents.dropFirst()) {

            let gap = event2.startDate.timeIntervalSince(event1.endDate)

            if gap == 0 {
                let severity: ConflictSeverity
                let duration = event1.endDate.timeIntervalSince(event1.startDate) / 60

                if duration >= 60 {
                    severity = .high
                } else if duration >= 30 {
                    severity = .medium
                } else {
                    severity = .low
                }

                conflicts.append(PredictedConflict(
                    type: .backToBack,
                    severity: severity,
                    events: [event1, event2],
                    description: "No break between '\(event1.title)' and '\(event2.title)'",
                    prediction: "Back-to-back meetings lead to fatigue and reduced focus",
                    suggestedResolution: "Add a 10-15 minute buffer between meetings",
                    confidence: 0.9
                ))
            } else if gap < 300 { // Less than 5 minutes
                conflicts.append(PredictedConflict(
                    type: .backToBack,
                    severity: .medium,
                    events: [event1, event2],
                    description: "Very short gap (\(Int(gap/60))min) between meetings",
                    prediction: "Barely enough time to prepare for next meeting",
                    suggestedResolution: "Extend gap to at least 10 minutes",
                    confidence: 0.8
                ))
            }
        }

        return conflicts
    }

    private func detectTravelConflicts(_ events: [EventSummary]) -> [PredictedConflict] {
        var conflicts: [PredictedConflict] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }

        for (event1, event2) in zip(sortedEvents, sortedEvents.dropFirst()) {

            // Check if events have different physical locations
            let loc1 = event1.location ?? ""
            let loc2 = event2.location ?? ""

            let hasPhysicalLocation1 = !loc1.isEmpty && !loc1.contains("http") && !loc1.contains("zoom") && !loc1.contains("meet")
            let hasPhysicalLocation2 = !loc2.isEmpty && !loc2.contains("http") && !loc2.contains("zoom") && !loc2.contains("meet")

            if hasPhysicalLocation1 && hasPhysicalLocation2 && loc1 != loc2 {
                let gap = event2.startDate.timeIntervalSince(event1.endDate) / 60

                if gap < 30 {
                    conflicts.append(PredictedConflict(
                        type: .travelTime,
                        severity: gap < 15 ? .high : .medium,
                        events: [event1, event2],
                        description: "Only \(Int(gap)) minutes between locations",
                        prediction: "May not have enough time to travel between '\(loc1)' and '\(loc2)'",
                        suggestedResolution: "Allow at least 30 minutes for travel between locations",
                        confidence: 0.75
                    ))
                }
            }
        }

        return conflicts
    }

    private func detectOverload(_ events: [EventSummary]) -> [PredictedConflict] {
        var conflicts: [PredictedConflict] = []

        // Group events by day
        var eventsByDay: [Date: [EventSummary]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            eventsByDay[day, default: []].append(event)
        }

        // Check each day
        for (day, dayEvents) in eventsByDay {
            let meetingCount = dayEvents.count
            let totalMinutes = dayEvents.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 }

            if meetingCount >= 8 {
                conflicts.append(PredictedConflict(
                    type: .overload,
                    severity: .critical,
                    events: dayEvents,
                    description: "\(meetingCount) meetings scheduled on \(formatDate(day))",
                    prediction: "Excessive meeting load will lead to burnout and low productivity",
                    suggestedResolution: "Decline non-essential meetings or reschedule some to other days",
                    confidence: 0.95
                ))
            } else if meetingCount >= 6 {
                conflicts.append(PredictedConflict(
                    type: .overload,
                    severity: .high,
                    events: dayEvents,
                    description: "\(meetingCount) meetings on \(formatDate(day))",
                    prediction: "Heavy meeting day with little time for focused work",
                    suggestedResolution: "Consider declining optional meetings",
                    confidence: 0.85
                ))
            } else if totalMinutes >= 360 { // 6 hours
                conflicts.append(PredictedConflict(
                    type: .overload,
                    severity: .high,
                    events: dayEvents,
                    description: "\(Int(totalMinutes/60)) hours of meetings on \(formatDate(day))",
                    prediction: "Very little time left for actual work",
                    suggestedResolution: "Try to shorten or combine some meetings",
                    confidence: 0.8
                ))
            }
        }

        return conflicts
    }

    private func detectEnergyDrain(_ events: [EventSummary]) -> [PredictedConflict] {
        var conflicts: [PredictedConflict] = []

        // Check for consecutive long meetings
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        guard sortedEvents.count >= 3 else { return [] }

        for i in 0..<(sortedEvents.count - 2) {
            let event1 = sortedEvents[i]
            let event2 = sortedEvents[i + 1]
            let event3 = sortedEvents[i + 2]

            let duration1 = event1.endDate.timeIntervalSince(event1.startDate) / 60
            let duration2 = event2.endDate.timeIntervalSince(event2.startDate) / 60
            let duration3 = event3.endDate.timeIntervalSince(event3.startDate) / 60

            // Three consecutive meetings of 45+ minutes each
            if duration1 >= 45 && duration2 >= 45 && duration3 >= 45 {
                let gap1 = event2.startDate.timeIntervalSince(event1.endDate) / 60
                let gap2 = event3.startDate.timeIntervalSince(event2.endDate) / 60

                if gap1 < 15 && gap2 < 15 {
                    conflicts.append(PredictedConflict(
                        type: .energyDrain,
                        severity: .high,
                        events: [event1, event2, event3],
                        description: "Three consecutive long meetings with no breaks",
                        prediction: "Energy and focus will significantly decline after second meeting",
                        suggestedResolution: "Add 15-minute breaks between meetings or reschedule one",
                        confidence: 0.85
                    ))
                }
            }
        }

        return conflicts
    }

    private func detectFocusInterruptions(_ events: [EventSummary]) -> [PredictedConflict] {
        var conflicts: [PredictedConflict] = []

        // Group by day and check for fragmented schedules
        var eventsByDay: [Date: [EventSummary]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            eventsByDay[day, default: []].append(event)
        }

        for (day, dayEvents) in eventsByDay {
            let sorted = dayEvents.sorted { $0.startDate < $1.startDate }

            // Find gaps between meetings
            var focusBlocks: [(start: Date, duration: TimeInterval)] = []

            for (current, next) in zip(sorted, sorted.dropFirst()) {
                let gap = next.startDate.timeIntervalSince(current.endDate)
                if gap > 900 { // More than 15 minutes
                    focusBlocks.append((start: current.endDate, duration: gap))
                }
            }

            // Check for many short focus blocks
            let shortBlocks = focusBlocks.filter { $0.duration < 3600 } // Less than 1 hour

            if shortBlocks.count >= 3 {
                conflicts.append(PredictedConflict(
                    type: .focusInterruption,
                    severity: .medium,
                    events: sorted,
                    description: "Fragmented schedule on \(formatDate(day))",
                    prediction: "Multiple short gaps prevent deep focus work",
                    suggestedResolution: "Consolidate meetings to create larger blocks of focus time",
                    confidence: 0.7
                ))
            }
        }

        return conflicts
    }

    private func detectRecurringConflicts(_ events: [EventSummary]) -> [PredictedConflict] {
        guard !events.isEmpty else { return [] }

        struct RecurrenceKey: Hashable {
            let normalizedTitle: String
            let weekday: Int
            let hour: Int
            let minuteBucket: Int
        }

        let recurringBuckets = Dictionary(grouping: events) { event -> RecurrenceKey in
            let weekday = calendar.component(.weekday, from: event.startDate)
            let hour = calendar.component(.hour, from: event.startDate)
            let minute = calendar.component(.minute, from: event.startDate)
            return RecurrenceKey(
                normalizedTitle: normalizeTitle(event.title),
                weekday: weekday,
                hour: hour,
                minuteBucket: (minute / 15) * 15
            )
        }

        var conflicts: [PredictedConflict] = []

        for (key, recurringEvents) in recurringBuckets where recurringEvents.count >= 2 {
            let overlapEvents = recurringEvents.flatMap { occurrence in
                events.filter { candidate in
                    candidate.id != occurrence.id &&
                    calendar.isDate(candidate.startDate, inSameDayAs: occurrence.startDate) &&
                    candidate.startDate < occurrence.endDate &&
                    candidate.endDate > occurrence.startDate
                }
            }

            let uniqueOverlaps = Dictionary(grouping: overlapEvents, by: \.id).compactMap { $0.value.first }
            guard !uniqueOverlaps.isEmpty else { continue }

            let overlapOccurrences = recurringEvents.reduce(0) { count, occurrence in
                let hasOverlap = events.contains { candidate in
                    candidate.id != occurrence.id &&
                    calendar.isDate(candidate.startDate, inSameDayAs: occurrence.startDate) &&
                    candidate.startDate < occurrence.endDate &&
                    candidate.endDate > occurrence.startDate
                }
                return count + (hasOverlap ? 1 : 0)
            }

            guard overlapOccurrences >= 2 else { continue }

            let weekdayName = calendar.weekdaySymbols[max(0, min(6, key.weekday - 1))]
            let title = recurringEvents.first?.title ?? "Recurring meeting"
            let severity: ConflictSeverity = overlapOccurrences >= 3 ? .high : .medium
            let confidence = min(0.95, 0.55 + Double(overlapOccurrences) * 0.1)

            conflicts.append(PredictedConflict(
                type: .recurring,
                severity: severity,
                events: recurringEvents + uniqueOverlaps,
                description: "Recurring conflict: '\(title)' overlaps on \(weekdayName)",
                prediction: "This scheduling conflict repeats \(overlapOccurrences)x and will keep interrupting your week",
                suggestedResolution: "Move the recurring meeting to a safer slot or decline overlapping recurring invites",
                confidence: confidence
            ))
        }

        return conflicts
    }

    // MARK: - Resolution Suggestions

    func suggestResolution(for conflict: PredictedConflict, allEvents: [EventSummary]) -> [ConflictResolution] {
        var resolutions: [ConflictResolution] = []

        switch conflict.type {
        case .overlap:
            // Suggest declining or rescheduling one
            resolutions.append(ConflictResolution(
                type: .decline,
                description: "Decline the less important meeting",
                events: conflict.events.last.map { [$0] } ?? [],
                newTimes: nil
            ))

        case .backToBack:
            // Suggest adding buffer
            resolutions.append(ConflictResolution(
                type: .addBuffer,
                description: "Add 15-minute buffer between meetings",
                events: conflict.events,
                newTimes: nil
            ))

            // Suggest shortening first meeting
            if let first = conflict.events.first {
                resolutions.append(ConflictResolution(
                    type: .shorten,
                    description: "Shorten first meeting by 10 minutes",
                    events: [first],
                    newTimes: nil
                ))
            }

        case .travelTime:
            // Suggest making one virtual
            resolutions.append(ConflictResolution(
                type: .reschedule,
                description: "Request to attend one meeting virtually",
                events: conflict.events,
                newTimes: nil
            ))

        case .overload:
            // Suggest declining optional meetings
            resolutions.append(ConflictResolution(
                type: .decline,
                description: "Decline optional or low-priority meetings",
                events: [],
                newTimes: nil
            ))

        case .energyDrain:
            // Suggest breaks
            resolutions.append(ConflictResolution(
                type: .addBuffer,
                description: "Add 15-minute breaks between meetings",
                events: conflict.events,
                newTimes: nil
            ))

        case .focusInterruption:
            // Suggest consolidating
            resolutions.append(ConflictResolution(
                type: .combine,
                description: "Consolidate meetings to create focus blocks",
                events: conflict.events,
                newTimes: nil
            ))

        case .recurring:
            resolutions.append(ConflictResolution(
                type: .reschedule,
                description: "Permanently reschedule recurring meeting",
                events: conflict.events,
                newTimes: nil
            ))
        }

        return resolutions
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func severityRank(_ severity: ConflictSeverity) -> Int {
        switch severity {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private func normalizeTitle(_ title: String) -> String {
        title
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
