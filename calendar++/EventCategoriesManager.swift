//
//  EventCategoriesManager.swift
//  calendar++
//
//  Manages event categories, tags, and color-coding
//

import Foundation
import SwiftUI
import Combine

struct EventCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: CodableColor
    var icon: String
    var keywords: [String]

    init(id: UUID = UUID(), name: String, color: Color, icon: String, keywords: [String] = []) {
        self.id = id
        self.name = name
        self.color = CodableColor(color: color)
        self.icon = icon
        self.keywords = keywords
    }

    var displayColor: Color {
        color.color
    }
}

// Helper for Codable Color
struct CodableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        // `NSColor(Color.*)` can be a dynamic/catalog color that will throw if we try to
        // extract RGBA without first converting to an RGB color space.
        let nsColor = NSColor(color)
        let rgb = nsColor.usingColorSpace(.deviceRGB)
            ?? nsColor.usingColorSpace(.sRGB)
            ?? NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)

        self.red = Double(rgb.redComponent)
        self.green = Double(rgb.greenComponent)
        self.blue = Double(rgb.blueComponent)
        self.alpha = Double(rgb.alphaComponent)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

class EventCategoriesManager: ObservableObject {
    @Published var categories: [EventCategory] = []
    @Published var eventCategoryMapping: [String: UUID] = [:] // eventID -> categoryID

    private let categoriesKey = "event_categories"
    private let mappingKey = "event_category_mapping"

    init() {
        loadCategories()
        loadMapping()
        if categories.isEmpty {
            setupDefaultCategories()
        }
    }

    // MARK: - Default Categories

    private func setupDefaultCategories() {
        categories = [
            EventCategory(
                name: "Work",
                color: .blue,
                icon: "briefcase.fill",
                keywords: ["meeting", "work", "office", "team", "project"]
            ),
            EventCategory(
                name: "Personal",
                color: .green,
                icon: "person.fill",
                keywords: ["personal", "self", "me"]
            ),
            EventCategory(
                name: "Health",
                color: .red,
                icon: "heart.fill",
                keywords: ["gym", "workout", "doctor", "health", "exercise", "fitness"]
            ),
            EventCategory(
                name: "Family",
                color: .orange,
                icon: "house.fill",
                keywords: ["family", "home", "kids", "children", "parents"]
            ),
            EventCategory(
                name: "Social",
                color: .purple,
                icon: "person.3.fill",
                keywords: ["lunch", "dinner", "coffee", "drinks", "party", "friends"]
            ),
            EventCategory(
                name: "Learning",
                color: .yellow,
                icon: "book.fill",
                keywords: ["class", "course", "study", "learn", "training"]
            ),
            EventCategory(
                name: "Travel",
                color: .cyan,
                icon: "airplane",
                keywords: ["flight", "trip", "travel", "vacation", "hotel"]
            )
        ]
        saveCategories()
    }

    // MARK: - Category Management

    func addCategory(_ category: EventCategory) {
        categories.append(category)
        saveCategories()
    }

    func updateCategory(_ category: EventCategory) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
        }
    }

    func deleteCategory(_ category: EventCategory) {
        categories.removeAll { $0.id == category.id }
        // Remove all mappings to this category
        eventCategoryMapping = eventCategoryMapping.filter { $0.value != category.id }
        saveCategories()
        saveMapping()
    }

    // MARK: - Event-Category Mapping

    func assignCategory(_ categoryID: UUID, to eventID: String) {
        eventCategoryMapping[eventID] = categoryID
        saveMapping()
    }

    func removeCategory(from eventID: String) {
        eventCategoryMapping.removeValue(forKey: eventID)
        saveMapping()
    }

    func getCategory(for eventID: String) -> EventCategory? {
        guard let categoryID = eventCategoryMapping[eventID] else { return nil }
        return categories.first { $0.id == categoryID }
    }

    // MARK: - Auto-Categorization

    func suggestCategory(for eventTitle: String) -> EventCategory? {
        let lowercasedTitle = eventTitle.lowercased()

        for category in categories {
            for keyword in category.keywords {
                if lowercasedTitle.contains(keyword.lowercased()) {
                    return category
                }
            }
        }

        return nil
    }

    func autoCategorizeLegacyEvents(events: [EventSummary]) {
        for event in events {
            // Skip if already categorized
            if eventCategoryMapping[event.id] != nil {
                continue
            }

            // Try to suggest a category
            if let suggested = suggestCategory(for: event.title) {
                assignCategory(suggested.id, to: event.id)
            }
        }
    }

    // MARK: - Filtering

    func getEvents(in category: EventCategory, from allEvents: [EventSummary]) -> [EventSummary] {
        allEvents.filter { event in
            eventCategoryMapping[event.id] == category.id
        }
    }

    func getUncategorizedEvents(from allEvents: [EventSummary]) -> [EventSummary] {
        allEvents.filter { event in
            eventCategoryMapping[event.id] == nil
        }
    }

    // MARK: - Statistics

    func getCategoryStatistics(from events: [EventSummary]) -> [EventCategory: Int] {
        var stats: [EventCategory: Int] = [:]

        for event in events {
            if let category = getCategory(for: event.id) {
                stats[category, default: 0] += 1
            }
        }

        return stats
    }

    func getTotalTimePerCategory(from events: [EventSummary]) -> [EventCategory: TimeInterval] {
        var timeStats: [EventCategory: TimeInterval] = [:]

        for event in events {
            if let category = getCategory(for: event.id) {
                let duration = event.endDate.timeIntervalSince(event.startDate)
                timeStats[category, default: 0] += duration
            }
        }

        return timeStats
    }

    // MARK: - Persistence

    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }

    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([EventCategory].self, from: data) {
            categories = decoded
        }
    }

    private func saveMapping() {
        if let encoded = try? JSONEncoder().encode(eventCategoryMapping) {
            UserDefaults.standard.set(encoded, forKey: mappingKey)
        }
    }

    private func loadMapping() {
        if let data = UserDefaults.standard.data(forKey: mappingKey),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            eventCategoryMapping = decoded
        }
    }
}
