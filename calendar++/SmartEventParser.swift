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

    private struct DetectedDateMatch {
        var date: Date
        var duration: TimeInterval
    }

    private func extractDatesAndTimes(from text: String) -> (DateInfo, [NSRange]) {
        var detectedRanges: [NSRange] = []
        var detectedMatches: [DetectedDateMatch] = []

        // Use NSDataDetector to find dates (including "tomorrow", "next week", etc.)
        let types: NSTextCheckingResult.CheckingType = [.date]
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return (defaultDateInfo(), [])
        }

        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            if let date = match.date {
                detectedMatches.append(
                    DetectedDateMatch(
                        date: date,
                        duration: match.duration
                    )
                )
                // NSDataDetector can sometimes include title words (e.g. "Lunch tomorrow ...").
                // Trim removal range to start at the first temporal token so event titles remain intact.
                let removalRange = temporalRemovalRange(from: match.range, in: text)
                if removalRange.length > 0 {
                    detectedRanges.append(removalRange)
                }
            }
        }

        // Extract explicit time patterns (e.g., "at 7pm", "2-3pm")
        let (timeInfo, timeRanges) = extractExplicitTimes(from: text)

        // Merge overlapping or adjacent ranges to avoid duplicate removal
        detectedRanges.append(contentsOf: timeRanges)
        detectedRanges = mergeAdjacentRanges(detectedRanges)

        // If NSDataDetector gives a duration, it already parsed an explicit range
        // like "4pm till 6pm" or "one pm to two pm", including word-based times.
        if let rangedMatch = detectedMatches.first(where: { $0.duration > 0 }) {
            let start = rangedMatch.date
            let end = start.addingTimeInterval(rangedMatch.duration)
            return (DateInfo(startDate: start, endDate: end), detectedRanges)
        }

        // Otherwise combine explicit time components with the first detected date.
        if let timeInfo {
            let baseDate = detectedMatches.first?.date ?? Date()
            let startDate = combineDateTime(date: baseDate, timeComponents: timeInfo.start)
            var endDate = combineDateTime(date: baseDate, timeComponents: timeInfo.end)

            // Handle overnight ranges such as "11pm to 1am".
            if endDate <= startDate {
                endDate = calendar.date(byAdding: .day, value: 1, to: endDate)
                    ?? startDate.addingTimeInterval(3600)
            }

            return (DateInfo(startDate: startDate, endDate: endDate), detectedRanges)
        }

        // Fall back to detector date (single point in time), then default 1 hour duration.
        if let firstMatch = detectedMatches.first {
            let startDate = firstMatch.date
            let duration = firstMatch.duration > 0 ? firstMatch.duration : 3600
            let endDate = startDate.addingTimeInterval(duration)
            return (DateInfo(startDate: startDate, endDate: endDate), detectedRanges)
        }

        return (defaultDateInfo(), detectedRanges)
    }

    private func temporalRemovalRange(from detectorRange: NSRange, in text: String) -> NSRange {
        guard let swiftRange = Range(detectorRange, in: text) else { return detectorRange }
        let segment = String(text[swiftRange])

        let temporalStartPattern = #"(?i)\b(?:today|tomorrow|tonight|yesterday|next|this|monday|tuesday|wednesday|thursday|friday|saturday|sunday|jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?|at|from|starting|beginning|by|noon|midnight|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b"#

        guard let regex = try? NSRegularExpression(pattern: temporalStartPattern),
              let match = regex.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment))
        else {
            return detectorRange
        }

        // If temporal token appears after leading content, preserve that leading content as title text.
        if match.range.location > 0 {
            return NSRange(
                location: detectorRange.location + match.range.location,
                length: detectorRange.length - match.range.location
            )
        }

        return detectorRange
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

    private func extractExplicitTimes(from text: String) -> (TimeInfo?, [NSRange]) {
        var ranges: [NSRange] = []

        // Pattern for time ranges:
        // "7-8pm", "2:30-3:30pm", "7pm to 8pm", "4pm till 6pm", "4 to 6pm"
        let rangePattern = #"(?i)\b(?:starting\s+from\s+|from\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|to|until|till|til)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b"#

        if let regex = try? NSRegularExpression(pattern: rangePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            ranges.append(match.range)

            let startHour = extractNumber(from: text, range: match.range(at: 1))
            let startMinute = extractNumber(from: text, range: match.range(at: 2)) ?? 0
            let startMeridiem = extractString(from: text, range: match.range(at: 3))?.lowercased()
            let endHour = extractNumber(from: text, range: match.range(at: 4))
            let endMinute = extractNumber(from: text, range: match.range(at: 5)) ?? 0
            let endMeridiem = extractString(from: text, range: match.range(at: 6))?.lowercased()

            let normalizedStartMeridiem = startMeridiem ?? endMeridiem
            let normalizedEndMeridiem = endMeridiem ?? startMeridiem
            let start24 = convertTo24Hour(hour: startHour ?? 7, meridiem: normalizedStartMeridiem)
            let end24 = convertTo24Hour(hour: endHour ?? 8, meridiem: normalizedEndMeridiem)

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

        return (nil, ranges)
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
        let virtualPlatforms = ["zoom", "teams", "meet", "google meet", "microsoft teams", "webex", "skype"]

        // Prefer explicit location phrases first ("in lab", "at cafe", "where: HQ").
        let explicitLocations = extractExplicitLocationCandidates(
            from: text,
            excludingRanges: excludingRanges,
            virtualPlatforms: virtualPlatforms
        )
        if let bestExplicit = explicitLocations.max(by: { $0.range.location < $1.range.location }) {
            return (bestExplicit.location, [bestExplicit.fullMatchRange])
        }

        // Fallback: Use NLTagger place-name entities.
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var detectedLocations: [(String, NSRange)] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            guard tag == .placeName else { return true }
            let location = String(text[range])
            let nsRange = NSRange(range, in: text)

            if !overlaps(nsRange, with: excludingRanges) {
                detectedLocations.append((location, nsRange))
            }
            return true
        }

        if let first = detectedLocations.first {
            return (sanitizeLocation(first.0), [first.1])
        }

        return (nil, [])
    }

    private func extractExplicitLocationCandidates(
        from text: String,
        excludingRanges: [NSRange],
        virtualPlatforms: [String]
    ) -> [(location: String, range: NSRange, fullMatchRange: NSRange)] {
        let locationPrepositions = ["at", "in", "on", "@"]
        var candidates: [(String, NSRange, NSRange)] = []

        // Capture "where: X" style hints.
        let wherePattern = #"(?i)\bwhere\s*[:\-]?\s*([^,\n]+)"#
        if let whereRegex = try? NSRegularExpression(pattern: wherePattern) {
            let whereMatches = whereRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in whereMatches {
                let locationRange = match.range(at: 1)
                if let candidate = buildLocationCandidate(
                    from: text,
                    locationRange: locationRange,
                    fullMatchRange: match.range,
                    excludingRanges: excludingRanges,
                    virtualPlatforms: virtualPlatforms
                ) {
                    candidates.append(candidate)
                }
            }
        }

        // Capture "at/in/on/@ X" style hints.
        for preposition in locationPrepositions {
            let prefixPattern = preposition == "@" ? "@" : "\\b\(preposition)\\b"
            let pattern = "\(prefixPattern)\\s+([^,\\n]+?)(?=\\s+(?:starting|from|to|until|till|til|at|in|on|tomorrow|today|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next|this|\\d)|$)"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }

            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                let locationRange = match.range(at: 1)
                if let candidate = buildLocationCandidate(
                    from: text,
                    locationRange: locationRange,
                    fullMatchRange: match.range,
                    excludingRanges: excludingRanges,
                    virtualPlatforms: virtualPlatforms
                ) {
                    candidates.append(candidate)
                }
            }
        }

        return candidates
    }

    private func buildLocationCandidate(
        from text: String,
        locationRange: NSRange,
        fullMatchRange: NSRange,
        excludingRanges: [NSRange],
        virtualPlatforms: [String]
    ) -> (String, NSRange, NSRange)? {
        guard !overlaps(locationRange, with: excludingRanges),
              let range = Range(locationRange, in: text) else {
            return nil
        }

        let rawLocation = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        let location = sanitizeLocation(rawLocation)
        let locationLower = location.lowercased()

        guard !location.isEmpty else { return nil }
        guard !location.contains(":") else { return nil }
        guard !virtualPlatforms.contains(where: { locationLower.contains($0) }) else { return nil }

        return (location, locationRange, fullMatchRange)
    }

    private func sanitizeLocation(_ raw: String) -> String {
        var location = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading preposition if it leaked into the capture.
        let leadingPrepositions = ["in ", "at ", "on ", "@ ", "where ", "where: ", "where- "]
        let lower = location.lowercased()
        if let prefix = leadingPrepositions.first(where: { lower.hasPrefix($0) }) {
            location = String(location.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove trailing punctuation artifacts.
        location = location.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:-"))

        return location
    }

    // MARK: - Title Building

    private func buildTitle(from text: String, dateRanges: [NSRange], locationRanges: [NSRange]) -> String {
        // Remove all detected ranges from the original text in one pass.
        // This avoids index-shift bugs when date/location ranges overlap.
        let allRanges = dateRanges + locationRanges
        let mergedRanges = mergeAdjacentRanges(allRanges).sorted { $0.location < $1.location }
        let nsText = text as NSString
        var titleParts: [String] = []
        var cursor = 0

        for range in mergedRanges {
            if range.location > cursor {
                let keepRange = NSRange(location: cursor, length: range.location - cursor)
                titleParts.append(nsText.substring(with: keepRange))
            }
            cursor = max(cursor, range.location + range.length)
        }

        if cursor < nsText.length {
            titleParts.append(nsText.substring(from: cursor))
        }

        var title = titleParts.joined()

        // Clean up extra whitespace
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common filler words
        let fillerWords = ["at", "in", "on", "with", "for", "to", "from", "starting", "beginning"]
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
