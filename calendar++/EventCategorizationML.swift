//
//  EventCategorizationML.swift
//  calendar++
//
//  ML-based automatic event categorization
//

import Foundation
import Combine
import NaturalLanguage

// MARK: - Models

enum AIEventCategory: String, Codable, CaseIterable {
    case meeting = "Meeting"
    case focus = "Focus Time"
    case personal = "Personal"
    case social = "Social"
    case travel = "Travel"
    case health = "Health & Fitness"
    case learning = "Learning"
    case work = "Work"
    case interview = "Interview"
    case presentation = "Presentation"
    case oneOnOne = "1:1"
    case standup = "Standup"
    case review = "Review"
    case other = "Other"

    var icon: String {
        switch self {
        case .meeting: return "person.2.fill"
        case .focus: return "brain.head.profile"
        case .personal: return "house.fill"
        case .social: return "star.fill"
        case .travel: return "airplane"
        case .health: return "heart.fill"
        case .learning: return "book.fill"
        case .work: return "briefcase.fill"
        case .interview: return "person.badge.plus"
        case .presentation: return "projector"
        case .oneOnOne: return "person.2"
        case .standup: return "figure.stand"
        case .review: return "checkmark.circle"
        case .other: return "circle"
        }
    }

    var color: String {
        switch self {
        case .meeting: return "blue"
        case .focus: return "purple"
        case .personal: return "green"
        case .social: return "pink"
        case .travel: return "cyan"
        case .health: return "red"
        case .learning: return "orange"
        case .work: return "indigo"
        case .interview: return "yellow"
        case .presentation: return "brown"
        case .oneOnOne: return "teal"
        case .standup: return "mint"
        case .review: return "olive"
        case .other: return "gray"
        }
    }
}

struct CategorizedEvent {
    let event: EventSummary
    let category: AIEventCategory
    let confidence: Double
    let isManuallySet: Bool
}

// MARK: - Event Categorization Manager

class EventCategorizationML: ObservableObject {
    @Published var categorizedEvents: [String: CategorizedEvent] = [:] // eventId -> categorization
    @Published var isProcessing = false

    private let nlTagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
    private var categoryKeywords: [AIEventCategory: [String]] = [:]
    private var manualCategories: [String: AIEventCategory] = [:] // eventId -> category

    init() {
        setupKeywords()
        loadManualCategories()
    }

    // MARK: - Setup

    private func setupKeywords() {
        categoryKeywords = [
            .meeting: ["meeting", "sync", "call", "discussion", "chat", "catchup"],
            .focus: ["focus", "deep work", "coding", "writing", "development", "blocked"],
            .personal: ["personal", "family", "home", "appointment", "errand"],
            .social: ["lunch", "dinner", "coffee", "happy hour", "party", "celebration"],
            .travel: ["flight", "travel", "commute", "drive", "trip"],
            .health: ["gym", "workout", "doctor", "dentist", "therapy", "exercise", "yoga"],
            .learning: ["training", "workshop", "course", "class", "lecture", "study"],
            .work: ["project", "deadline", "client", "task", "work"],
            .interview: ["interview", "hiring", "candidate", "screening"],
            .presentation: ["presentation", "demo", "showcase", "pitch", "present"],
            .oneOnOne: ["1:1", "one-on-one", "1-on-1", "check-in", "catch up"],
            .standup: ["standup", "daily", "scrum", "team sync"],
            .review: ["review", "retrospective", "retro", "feedback", "performance"]
        ]
    }

    private func loadManualCategories() {
        if let data = UserDefaults.standard.data(forKey: "manualEventCategories"),
           let decoded = try? JSONDecoder().decode([String: AIEventCategory].self, from: data) {
            manualCategories = decoded
        }
    }

    private func saveManualCategories() {
        if let encoded = try? JSONEncoder().encode(manualCategories) {
            UserDefaults.standard.set(encoded, forKey: "manualEventCategories")
        }
    }

    // MARK: - Categorization

    func categorizeEvents(_ events: [EventSummary]) {
        // Clear stale classifications when there are no visible events.
        guard !events.isEmpty else {
            DispatchQueue.main.async {
                self.categorizedEvents = [:]
                self.isProcessing = false
            }
            return
        }

        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var newCategorizedEvents: [String: CategorizedEvent] = [:]

            for event in events {
                // Check if manually categorized
                if let manualCategory = self.manualCategories[event.id] {
                    newCategorizedEvents[event.id] = CategorizedEvent(
                        event: event,
                        category: manualCategory,
                        confidence: 1.0,
                        isManuallySet: true
                    )
                    continue
                }

                // Auto-categorize safely
                let (category, confidence) = self.categorize(event: event)
                newCategorizedEvents[event.id] = CategorizedEvent(
                    event: event,
                    category: category,
                    confidence: confidence,
                    isManuallySet: false
                )
            }

            DispatchQueue.main.async {
                self.categorizedEvents = newCategorizedEvents
                self.isProcessing = false
            }
        }
    }

    private func categorize(event: EventSummary) -> (AIEventCategory, Double) {
        let text = "\(event.title) \(event.notes ?? "")".lowercased()

        var scores: [AIEventCategory: Double] = [:]

        // Initialize all categories with base score
        for category in AIEventCategory.allCases {
            scores[category] = 0.0
        }

        // 1. Keyword matching
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if text.contains(keyword) {
                    scores[category, default: 0] += 0.3
                }
            }
        }

        // 2. Natural Language Processing for entity recognition
        let titleText = event.title
        if !titleText.isEmpty && titleText.count > 2 {
            // Set the string to analyze
            nlTagger.string = titleText

            let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]

            // Safely enumerate tags with error handling
            nlTagger.enumerateTags(in: titleText.startIndex..<titleText.endIndex,
                                   unit: .word,
                                   scheme: .nameType,
                                   options: options) { tag, tokenRange in
                guard let tag = tag else { return true }

                switch tag {
                case .personalName:
                    // Personal names suggest 1:1 meetings
                    scores[.oneOnOne, default: 0] += 0.2
                case .organizationName:
                    // Organizations suggest work meetings
                    scores[.work, default: 0] += 0.1
                case .placeName:
                    // Place names suggest travel
                    scores[.travel, default: 0] += 0.15
                default:
                    break
                }

                return true
            }
        }

        // 3. Calendar-specific heuristics
        if event.location?.contains("zoom") == true || event.location?.contains("meet") == true {
            scores[.meeting, default: 0] += 0.2
        }

        if event.location?.contains("gym") == true || event.location?.contains("studio") == true {
            scores[.health, default: 0] += 0.3
        }

        // 4. Duration-based hints
        let duration = event.endDate.timeIntervalSince(event.startDate) / 60
        if duration <= 15 {
            scores[.standup, default: 0] += 0.1
        } else if duration >= 120 {
            scores[.focus, default: 0] += 0.1
            scores[.learning, default: 0] += 0.1
        }

        // 5. Time of day
        let hour = Calendar.current.component(.hour, from: event.startDate)
        if hour >= 12 && hour <= 13 {
            scores[.social, default: 0] += 0.15 // Lunch time
        } else if hour >= 17 {
            scores[.social, default: 0] += 0.1 // After work
            scores[.personal, default: 0] += 0.1
        }

        // Find best category
        let sortedScores = scores.sorted { $0.value > $1.value }
        let bestCategory = sortedScores.first?.key ?? .other
        let confidence = min(sortedScores.first?.value ?? 0.0, 1.0)

        // If confidence too low, default to "meeting" or "other"
        if confidence < 0.2 {
            return (.meeting, 0.3)
        }

        return (bestCategory, confidence)
    }

    // MARK: - Manual Categorization

    func setCategory(_ category: AIEventCategory, for eventId: String) {
        manualCategories[eventId] = category
        saveManualCategories()

        // Update categorized event
        if let event = categorizedEvents[eventId]?.event {
            categorizedEvents[eventId] = CategorizedEvent(
                event: event,
                category: category,
                confidence: 1.0,
                isManuallySet: true
            )
        }
    }

    func removeManualCategory(for eventId: String) {
        manualCategories.removeValue(forKey: eventId)
        saveManualCategories()

        // Re-categorize automatically
        if let event = categorizedEvents[eventId]?.event {
            let (category, confidence) = categorize(event: event)
            categorizedEvents[eventId] = CategorizedEvent(
                event: event,
                category: category,
                confidence: confidence,
                isManuallySet: false
            )
        }
    }

    // MARK: - Statistics

    func getCategoryDistribution() -> [AIEventCategory: Int] {
        var distribution: [AIEventCategory: Int] = [:]

        for categorized in categorizedEvents.values {
            distribution[categorized.category, default: 0] += 1
        }

        return distribution
    }

    func getEventsForCategory(_ category: AIEventCategory) -> [EventSummary] {
        categorizedEvents.values
            .filter { $0.category == category }
            .map { $0.event }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Learning

    func learnFromManualCategories() {
        // Analyze manual categories to improve keyword matching
        for (eventId, category) in manualCategories {
            guard let event = categorizedEvents[eventId]?.event else { continue }

            let words = event.title.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }

            for word in words {
                if !categoryKeywords[category, default: []].contains(word) {
                    categoryKeywords[category, default: []].append(word)
                }
            }
        }
    }
}
