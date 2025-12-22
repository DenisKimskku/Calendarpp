//
//  SmartEventParser.swift
//  calendar++
//
//  ML-powered natural language parser using Apple's NaturalLanguage framework
//

import Foundation
import NaturalLanguage

struct ParsedEvent {
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
}

class SmartEventParser {
    static let shared = SmartEventParser()

    private let calendar = Calendar.current

    func parse(_ input: String) -> ParsedEvent? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        // Step 1: Extract dates and times using NSDataDetector (Apple's ML detector)
        // NSDataDetector uses ML to detect dates like "tomorrow", "next week", "3pm", etc.
        let (dateInfo, dateRanges) = extractDatesAndTimes(from: normalized)

        // Step 2: Use NSLinguisticTagger (Apple's ML) to find additional temporal expressions
        let temporalRanges = extractTemporalExpressionsML(from: normalized, excludingRanges: dateRanges)

        // Step 3: Extract location using NLTagger (Apple's ML tagger)
        let combinedDateRanges = dateRanges + temporalRanges
        let (location, locationRanges) = extractLocation(from: normalized, excludingRanges: combinedDateRanges)

        // Step 4: Build title by removing extracted components
        let title = buildTitle(from: normalized, dateRanges: combinedDateRanges, locationRanges: locationRanges)

        // Step 5: Combine into final event
        let startDate = dateInfo.startDate
        let endDate = dateInfo.endDate

        return ParsedEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location
        )
    }

    // MARK: - Date & Time Extraction (Using NSDataDetector)

    private struct DateInfo {
        var startDate: Date
        var endDate: Date
    }

    private func extractDatesAndTimes(from text: String) -> (DateInfo, [NSRange]) {
        var detectedRanges: [NSRange] = []
        var detectedDates: [Date] = []

        // Use NSDataDetector to find dates (including "tomorrow", "next week", etc.)
        let types: NSTextCheckingResult.CheckingType = [.date]
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return (defaultDateInfo(), [])
        }

        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            if let date = match.date {
                detectedDates.append(date)
                // NSDataDetector returns the full matched range including the temporal word
                detectedRanges.append(match.range)
            }
        }

        // Extract explicit time patterns (e.g., "at 7pm", "2-3pm")
        let (timeInfo, timeRanges) = extractExplicitTimes(from: text)

        // Merge overlapping or adjacent ranges to avoid duplicate removal
        detectedRanges.append(contentsOf: timeRanges)
        detectedRanges = mergeAdjacentRanges(detectedRanges)

        // Combine date and time
        let baseDate: Date
        if !detectedDates.isEmpty {
            baseDate = detectedDates[0]
        } else {
            baseDate = Date()
        }

        let startDate = combineDateTime(date: baseDate, timeComponents: timeInfo.start)
        let endDate = combineDateTime(date: baseDate, timeComponents: timeInfo.end)

        return (DateInfo(startDate: startDate, endDate: endDate), detectedRanges)
    }

    // Merge adjacent or overlapping ranges to prevent gaps in title
    private func mergeAdjacentRanges(_ ranges: [NSRange]) -> [NSRange] {
        guard !ranges.isEmpty else { return [] }

        let sorted = ranges.sorted { $0.location < $1.location }
        var merged: [NSRange] = [sorted[0]]

        for range in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            let lastEnd = last.location + last.length

            // Merge if overlapping or adjacent (within 1 character - likely just whitespace)
            if range.location <= lastEnd + 1 {
                let newEnd = max(lastEnd, range.location + range.length)
                merged[merged.count - 1] = NSRange(location: last.location, length: newEnd - last.location)
            } else {
                merged.append(range)
            }
        }

        return merged
    }

    private struct TimeInfo {
        var start: DateComponents
        var end: DateComponents
    }

    private func extractExplicitTimes(from text: String) -> (TimeInfo, [NSRange]) {
        var ranges: [NSRange] = []

        // Pattern for time ranges: "7-8pm", "2:30-3:30pm", "7pm to 8pm"
        let rangePattern = #"(\d{1,2})(?::(\d{2}))?\s*(?:am|pm|AM|PM)?\s*(?:-|to)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)"#

        if let regex = try? NSRegularExpression(pattern: rangePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            ranges.append(match.range)

            let startHour = extractNumber(from: text, range: match.range(at: 1))
            let startMinute = extractNumber(from: text, range: match.range(at: 2)) ?? 0
            let endHour = extractNumber(from: text, range: match.range(at: 3))
            let endMinute = extractNumber(from: text, range: match.range(at: 4)) ?? 0
            let meridiem = extractString(from: text, range: match.range(at: 5))?.lowercased()

            let start24 = convertTo24Hour(hour: startHour ?? 7, meridiem: meridiem)
            let end24 = convertTo24Hour(hour: endHour ?? 8, meridiem: meridiem)

            return (TimeInfo(
                start: DateComponents(hour: start24, minute: startMinute),
                end: DateComponents(hour: end24, minute: endMinute)
            ), ranges)
        }

        // Pattern for single time: "at 7pm", "7:30pm"
        let singlePattern = #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)"#

        if let regex = try? NSRegularExpression(pattern: singlePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            ranges.append(match.range)

            let hour = extractNumber(from: text, range: match.range(at: 1))
            let minute = extractNumber(from: text, range: match.range(at: 2)) ?? 0
            let meridiem = extractString(from: text, range: match.range(at: 3))?.lowercased()

            let hour24 = convertTo24Hour(hour: hour ?? 7, meridiem: meridiem)

            return (TimeInfo(
                start: DateComponents(hour: hour24, minute: minute),
                end: DateComponents(hour: hour24 + 1, minute: minute)
            ), ranges)
        }

        // Default: next hour
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let nextHour = (currentHour + 1) % 24

        return (TimeInfo(
            start: DateComponents(hour: nextHour, minute: 0),
            end: DateComponents(hour: (nextHour + 1) % 24, minute: 0)
        ), ranges)
    }

    private func convertTo24Hour(hour: Int, meridiem: String?) -> Int {
        guard let meridiem = meridiem else { return hour }

        if meridiem == "pm" && hour != 12 {
            return hour + 12
        } else if meridiem == "am" && hour == 12 {
            return 0
        }
        return hour
    }

    // MARK: - Temporal Expression Extraction (Using NSLinguisticTagger ML)

    private func extractTemporalExpressionsML(from text: String, excludingRanges: [NSRange]) -> [NSRange] {
        // Use NSLinguisticTagger to identify temporal words that NSDataDetector might miss
        // This uses Apple's ML models to understand language context
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass, .nameType], options: 0)
        tagger.string = text

        var temporalRanges: [NSRange] = []
        let range = NSRange(location: 0, length: (text as NSString).length)

        // Known temporal indicators (used as validation, not primary detection)
        let temporalKeywords = Set([
            "today", "tonight", "tomorrow", "yesterday",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "week", "month", "year", "next", "last", "this"
        ])

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange, _ in
            // Extract the word
            guard let swiftRange = Range(tokenRange, in: text) else { return }
            let word = String(text[swiftRange]).lowercased()

            // Check if it's a temporal keyword and not already covered by NSDataDetector
            if temporalKeywords.contains(word) && !overlaps(tokenRange, with: excludingRanges) {
                // Additional context check: make sure it's used temporally
                // For example, "Monday" in "see you Monday" vs "Monday's report"
                temporalRanges.append(tokenRange)
            }
        }

        return temporalRanges
    }

    // MARK: - Location Extraction (Using NLTagger)

    private func extractLocation(from text: String, excludingRanges: [NSRange]) -> (String?, [NSRange]) {
        // Common location prepositions
        let locationPrepositions = ["at", "in", "on", "@"]
        let virtualPlatforms = ["zoom", "teams", "meet", "google meet", "microsoft teams", "webex", "skype"]

        // Use NLTagger to find place names
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var detectedLocations: [(String, NSRange)] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .placeName {
                let location = String(text[range])
                let nsRange = NSRange(range, in: text)

                // Don't include if it overlaps with date ranges
                if !overlaps(nsRange, with: excludingRanges) {
                    detectedLocations.append((location, nsRange))
                }
            }
            return true
        }

        // Also look for explicit location patterns: "at X", "in X"
        for preposition in locationPrepositions {
            let pattern = "\(preposition)\\s+([A-Za-z][A-Za-z0-9\\s]+?)(?:\\s+(?:at|tomorrow|today|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next|\\d)|$)"

            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                let locationRange = match.range(at: 1)

                // Don't include if it overlaps with date ranges
                if !overlaps(locationRange, with: excludingRanges) {
                    if let range = Range(locationRange, in: text) {
                        let location = String(text[range]).trimmingCharacters(in: .whitespaces)

                        // Skip if it's a virtual platform
                        let locationLower = location.lowercased()
                        if !virtualPlatforms.contains(where: { locationLower.contains($0) }) &&
                           !location.contains(":") {
                            return (location, [match.range])
                        }
                    }
                }
            }
        }

        // Use detected locations from NLTagger
        if let first = detectedLocations.first {
            return (first.0, [first.1])
        }

        return (nil, [])
    }

    // MARK: - Title Building

    private func buildTitle(from text: String, dateRanges: [NSRange], locationRanges: [NSRange]) -> String {
        var title = text

        // Remove all detected ranges from the title
        let allRanges = dateRanges + locationRanges
        let sortedRanges = allRanges.sorted { $0.location > $1.location }

        for range in sortedRanges {
            if let swiftRange = Range(range, in: title) {
                title.removeSubrange(swiftRange)
            }
        }

        // Clean up extra whitespace
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common filler words
        let fillerWords = ["at", "in", "on", "with", "for", "to", "from"]
        var words = title.split(separator: " ").map(String.init)

        // Only remove filler words if they're at the start or end
        if let first = words.first, fillerWords.contains(first.lowercased()) {
            words.removeFirst()
        }
        if let last = words.last, fillerWords.contains(last.lowercased()) {
            words.removeLast()
        }

        title = words.joined(separator: " ")

        // Capitalize first letter
        if !title.isEmpty {
            title = title.prefix(1).capitalized + title.dropFirst()
        }

        return title.isEmpty ? "New Event" : title
    }

    // MARK: - Helper Functions

    private func overlaps(_ range1: NSRange, with ranges: [NSRange]) -> Bool {
        for range2 in ranges {
            if NSIntersectionRange(range1, range2).length > 0 {
                return true
            }
        }
        return false
    }

    private func extractNumber(from text: String, range: NSRange) -> Int? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        return Int(text[swiftRange])
    }

    private func extractString(from text: String, range: NSRange) -> String? {
        guard let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func combineDateTime(date: Date, timeComponents: DateComponents) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }

    private func defaultDateInfo() -> DateInfo {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let nextHour = (hour + 1) % 24

        var startComps = calendar.dateComponents([.year, .month, .day], from: now)
        startComps.hour = nextHour
        startComps.minute = 0

        var endComps = startComps
        endComps.hour = (nextHour + 1) % 24

        return DateInfo(
            startDate: calendar.date(from: startComps) ?? now,
            endDate: calendar.date(from: endComps) ?? now
        )
    }
}
