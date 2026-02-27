//
//  SearchManager.swift
//  calendar++
//
//  Manages event search, filtering, and search history
//

import Foundation
import EventKit
import Combine
import SwiftUI

// MARK: - Search Filter Model

struct SearchFilter: Codable, Identifiable {
    let id: UUID
    var name: String
    var query: String
    var dateRange: DateRangeFilter?
    var calendarIDs: [String]
    var categoryIDs: [UUID]
    var includeAllDay: Bool
    var includeRecurring: Bool?
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        query: String = "",
        dateRange: DateRangeFilter? = nil,
        calendarIDs: [String] = [],
        categoryIDs: [UUID] = [],
        includeAllDay: Bool = true,
        includeRecurring: Bool? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.dateRange = dateRange
        self.calendarIDs = calendarIDs
        self.categoryIDs = categoryIDs
        self.includeAllDay = includeAllDay
        self.includeRecurring = includeRecurring
        self.isFavorite = isFavorite
    }
}

enum DateRangeFilter: Codable, Hashable {
    case today
    case thisWeek
    case thisMonth
    case custom(start: Date, end: Date)

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)

        case .thisWeek:
            let start = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date!
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)

        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)

        case .custom(let start, let end):
            return (start, end)
        }
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id: String
    let event: EventSummary
    let matchedFields: [MatchedField]
    let relevanceScore: Double

    enum MatchedField {
        case title
        case location
        case notes
        case calendar
    }
}

// MARK: - Search Manager

class SearchManager: ObservableObject {
    @Published var searchHistory: [String] = []
    @Published var savedFilters: [SearchFilter] = []
    @Published var isSearching: Bool = false

    private let eventStore = EKEventStore()
    private let maxHistoryItems = 20

    private let historyKey = "search_history"
    private let filtersKey = "saved_filters"

    init() {
        loadSearchHistory()
        loadSavedFilters()
    }

    // MARK: - Search

    func search(
        query: String,
        filter: SearchFilter = SearchFilter(),
        categoriesManager: EventCategoriesManager? = nil
    ) -> [SearchResult] {
        isSearching = true
        defer { isSearching = false }

        // Add to history if not empty
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            addToHistory(query)
        }

        // Get events based on date range
        let events = fetchEvents(dateRange: filter.dateRange)

        // Apply filters
        var filtered = events

        // Text search
        if !query.isEmpty {
            filtered = filterByQuery(events: filtered, query: query)
        }

        // Calendar filter
        if !filter.calendarIDs.isEmpty {
            filtered = filtered.filter { filter.calendarIDs.contains($0.id) }
        }

        // Category filter
        if !filter.categoryIDs.isEmpty, let categoriesManager = categoriesManager {
            filtered = filtered.filter { event in
                if let category = categoriesManager.getCategory(for: event.id) {
                    return filter.categoryIDs.contains(category.id)
                }
                return false
            }
        }

        // All-day filter
        if !filter.includeAllDay {
            filtered = filtered.filter { !$0.isAllDay }
        }

        // Recurring filter
        if let includeRecurring = filter.includeRecurring {
            filtered = filtered.filter { event in
                // Check if event has recurrence rules
                if let ekEvent = getEKEvent(for: event.id) {
                    let isRecurring = ekEvent.hasRecurrenceRules
                    return includeRecurring ? isRecurring : !isRecurring
                }
                return true
            }
        }

        // Convert to search results with relevance scoring
        return filtered.map { event in
            let (matchedFields, score) = calculateRelevance(event: event, query: query)
            return SearchResult(
                id: event.id,
                event: event,
                matchedFields: matchedFields,
                relevanceScore: score
            )
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    // MARK: - Quick Filters

    func quickFilterToday(events: [EventSummary]) -> [EventSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: today)
        }
    }

    func quickFilterThisWeek(events: [EventSummary]) -> [EventSummary] {
        let calendar = Calendar.current
        let weekStart = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!

        return events.filter { event in
            event.startDate >= weekStart && event.startDate < weekEnd
        }
    }

    func quickFilterThisMonth(events: [EventSummary]) -> [EventSummary] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

        return events.filter { event in
            event.startDate >= monthStart && event.startDate < monthEnd
        }
    }

    func quickFilterUncategorized(events: [EventSummary], categoriesManager: EventCategoriesManager) -> [EventSummary] {
        return categoriesManager.getUncategorizedEvents(from: events)
    }

    func quickFilterRecurring(events: [EventSummary]) -> [EventSummary] {
        return events.filter { event in
            if let ekEvent = getEKEvent(for: event.id) {
                return ekEvent.hasRecurrenceRules
            }
            return false
        }
    }

    // MARK: - Private Helpers

    private func fetchEvents(dateRange: DateRangeFilter?) -> [EventSummary] {
        let range: (start: Date, end: Date)

        if let dateRange = dateRange {
            range = dateRange.dateRange
        } else {
            // Default: past month to next year
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .month, value: -1, to: Date())!
            let end = calendar.date(byAdding: .year, value: 1, to: Date())!
            range = (start, end)
        }

        let predicate = eventStore.predicateForEvents(
            withStart: range.start,
            end: range.end,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)

	        return ekEvents.map { event in
	            EventSummary(
	                id: event.eventIdentifier ?? UUID().uuidString,
	                title: event.title ?? "No Title",
	                startDate: event.startDate,
	                endDate: event.endDate,
	                isAllDay: event.isAllDay,
	                calendarId: event.calendar.calendarIdentifier,
	                calendarName: event.calendar.title,
	                calendarColor: NSColor(cgColor: event.calendar.cgColor ?? NSColor.blue.cgColor) ?? .blue,
	                location: event.location,
	                notes: event.notes
	            )
	        }
	    }

    private func filterByQuery(events: [EventSummary], query: String) -> [EventSummary] {
        let lowercasedQuery = query.lowercased()

        return events.filter { event in
            // Search in title
            if event.title.lowercased().contains(lowercasedQuery) {
                return true
            }

            // Search in location
            if let location = event.location, location.lowercased().contains(lowercasedQuery) {
                return true
            }

            // Search in notes
            if let notes = event.notes, notes.lowercased().contains(lowercasedQuery) {
                return true
            }

            // Search in calendar name
            if event.calendarName.lowercased().contains(lowercasedQuery) {
                return true
            }

            return false
        }
    }

    private func calculateRelevance(event: EventSummary, query: String) -> ([SearchResult.MatchedField], Double) {
        guard !query.isEmpty else {
            return ([], 1.0)
        }

        let lowercasedQuery = query.lowercased()
        var matchedFields: [SearchResult.MatchedField] = []
        var score: Double = 0.0

        // Title match (highest weight)
        if event.title.lowercased().contains(lowercasedQuery) {
            matchedFields.append(.title)
            score += event.title.lowercased().starts(with: lowercasedQuery) ? 100.0 : 50.0
        }

        // Location match
        if let location = event.location, location.lowercased().contains(lowercasedQuery) {
            matchedFields.append(.location)
            score += 30.0
        }

        // Notes match
        if let notes = event.notes, notes.lowercased().contains(lowercasedQuery) {
            matchedFields.append(.notes)
            score += 20.0
        }

        // Calendar name match
        if event.calendarName.lowercased().contains(lowercasedQuery) {
            matchedFields.append(.calendar)
            score += 10.0
        }

        // Boost recent events
        let daysSinceEvent = Calendar.current.dateComponents([.day], from: Date(), to: event.startDate).day ?? 0
        if abs(daysSinceEvent) < 7 {
            score += 5.0
        }

        return (matchedFields, score)
    }

    private func getEKEvent(for eventID: String) -> EKEvent? {
        return eventStore.event(withIdentifier: eventID)
    }

    // MARK: - Search History

    func addToHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Remove duplicates
        searchHistory.removeAll { $0 == trimmed }

        // Add to front
        searchHistory.insert(trimmed, at: 0)

        // Limit size
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }

        saveSearchHistory()
    }

    func clearHistory() {
        searchHistory = []
        saveSearchHistory()
    }

    func removeFromHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }

    // MARK: - Saved Filters

    func saveFilter(_ filter: SearchFilter) {
        if let index = savedFilters.firstIndex(where: { $0.id == filter.id }) {
            savedFilters[index] = filter
        } else {
            savedFilters.append(filter)
        }
        saveSavedFilters()
    }

    func deleteFilter(_ filter: SearchFilter) {
        savedFilters.removeAll { $0.id == filter.id }
        saveSavedFilters()
    }

    func toggleFavorite(_ filter: SearchFilter) {
        if let index = savedFilters.firstIndex(where: { $0.id == filter.id }) {
            savedFilters[index].isFavorite.toggle()
            saveSavedFilters()
        }
    }

    var favoriteFilters: [SearchFilter] {
        savedFilters.filter { $0.isFavorite }
    }

    // MARK: - Persistence

    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: historyKey)
    }

    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    private func saveSavedFilters() {
        if let encoded = try? JSONEncoder().encode(savedFilters) {
            UserDefaults.standard.set(encoded, forKey: filtersKey)
        }
    }

    private func loadSavedFilters() {
        if let data = UserDefaults.standard.data(forKey: filtersKey),
           let decoded = try? JSONDecoder().decode([SearchFilter].self, from: data) {
            savedFilters = decoded
        }
    }
}
