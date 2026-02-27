//
//  CalendarSubscriptionManager.swift
//  calendar++
//
//  Manages calendar subscriptions (holidays, sports, public calendars)
//

import Foundation
import EventKit
import Combine
import SwiftUI

// MARK: - Calendar Subscription Model

struct CalendarSubscription: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var category: SubscriptionCategory
    var isEnabled: Bool
    var lastSyncDate: Date?
    var refreshInterval: TimeInterval // in seconds
    var color: CodableColor
    var eventCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        category: SubscriptionCategory,
        isEnabled: Bool = true,
        lastSyncDate: Date? = nil,
        refreshInterval: TimeInterval = 3600, // 1 hour default
        color: CodableColor = CodableColor(color: .blue),
        eventCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.category = category
        self.isEnabled = isEnabled
        self.lastSyncDate = lastSyncDate
        self.refreshInterval = refreshInterval
        self.color = color
        self.eventCount = eventCount
    }
}

enum SubscriptionCategory: String, Codable, CaseIterable {
    case holidays = "Holidays"
    case sports = "Sports"
    case entertainment = "Entertainment"
    case weather = "Weather"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .holidays: return "gift"
        case .sports: return "sportscourt"
        case .entertainment: return "film"
        case .weather: return "cloud.sun"
        case .custom: return "link"
        }
    }
}

// MARK: - Popular Subscriptions

struct PopularSubscription {
    let name: String
    let url: String
    let category: SubscriptionCategory
    let description: String
}

// MARK: - Calendar Subscription Manager

class CalendarSubscriptionManager: ObservableObject {
    @Published var subscriptions: [CalendarSubscription] = []
    @Published var isSyncing: Bool = false

    private let subscriptionsKey = "calendar_subscriptions"
    private let eventStore = EKEventStore()

    // Popular calendar subscriptions
    static let popularSubscriptions: [PopularSubscription] = [
        // US Holidays
        PopularSubscription(
            name: "US Holidays",
            url: "webcal://www.officeholidays.com/ics/usa",
            category: .holidays,
            description: "Official US federal holidays"
        ),
        PopularSubscription(
            name: "UK Holidays",
            url: "webcal://www.officeholidays.com/ics/united-kingdom",
            category: .holidays,
            description: "UK bank holidays and observances"
        ),
        PopularSubscription(
            name: "Korean Holidays",
            url: "webcal://www.officeholidays.com/ics/south-korea",
            category: .holidays,
            description: "Korean public holidays"
        ),

        // Sports
        PopularSubscription(
            name: "NBA Schedule",
            url: "webcal://www.stanza.co/@nba/ics",
            category: .sports,
            description: "NBA game schedule"
        ),
        PopularSubscription(
            name: "Premier League",
            url: "webcal://www.stanza.co/@premierleague/ics",
            category: .sports,
            description: "English Premier League fixtures"
        ),

        // Tech Events
        PopularSubscription(
            name: "WWDC",
            url: "webcal://p63-calendars.icloud.com/published/2/wwdc",
            category: .entertainment,
            description: "Apple WWDC events"
        ),
    ]

    init() {
        loadSubscriptions()
        startAutoRefresh()
    }

    // MARK: - Subscription Management

    func addSubscription(_ subscription: CalendarSubscription) {
        subscriptions.append(subscription)
        saveSubscriptions()

        // Initial sync
        Task {
            await syncSubscription(subscription)
        }
    }

    func updateSubscription(_ subscription: CalendarSubscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveSubscriptions()
        }
    }

    func deleteSubscription(_ subscription: CalendarSubscription) {
        // Remove events from this subscription
        removeEventsFromSubscription(subscription)

        subscriptions.removeAll { $0.id == subscription.id }
        saveSubscriptions()
    }

    func toggleSubscription(_ subscription: CalendarSubscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index].isEnabled.toggle()
            saveSubscriptions()

            if subscriptions[index].isEnabled {
                Task {
                    await syncSubscription(subscriptions[index])
                }
            } else {
                removeEventsFromSubscription(subscriptions[index])
            }
        }
    }

    // MARK: - Syncing

    func syncAllSubscriptions() async {
        isSyncing = true

        for subscription in subscriptions where subscription.isEnabled {
            await syncSubscription(subscription)
        }

        isSyncing = false
    }

    func syncSubscription(_ subscription: CalendarSubscription) async {
        guard subscription.isEnabled else { return }

        do {
            // Convert webcal:// to https://
            let httpsURL = subscription.url.replacingOccurrences(of: "webcal://", with: "https://")

            guard let url = URL(string: httpsURL) else {
                print("Invalid subscription URL: \(subscription.url)")
                return
            }

            // Fetch iCal data
            let (data, _) = try await URLSession.shared.data(from: url)

            // Parse iCal data
            let events = parseiCalData(data)

            // Create/update events in EventKit
            let calendarName = "Subscribed: \(subscription.name)"
            let calendar = getOrCreateSubscriptionCalendar(name: calendarName, color: subscription.color.color)

            // Remove old events from this calendar
            removeEventsFromCalendar(calendar)

            // Add new events
            for event in events {
                createEvent(event, in: calendar)
            }

            // Update subscription
            if var updatedSubscription = subscriptions.first(where: { $0.id == subscription.id }) {
                updatedSubscription.lastSyncDate = Date()
                updatedSubscription.eventCount = events.count
                updateSubscription(updatedSubscription)
            }

            print("Synced \(events.count) events for \(subscription.name)")

        } catch {
            print("Failed to sync subscription \(subscription.name): \(error)")
        }
    }

    // MARK: - iCal Parsing

    private func parseiCalData(_ data: Data) -> [ParsedEvent] {
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var events: [ParsedEvent] = []
        let lines = content.components(separatedBy: .newlines)

        var currentEvent: ParsedEvent?
        var isInEvent = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "BEGIN:VEVENT" {
                isInEvent = true
                currentEvent = ParsedEvent()
            } else if trimmedLine == "END:VEVENT" {
                if let event = currentEvent {
                    events.append(event)
                }
                isInEvent = false
                currentEvent = nil
            } else if isInEvent {
                if let event = currentEvent {
                    currentEvent = parseEventProperty(line: trimmedLine, event: event)
                }
            }
        }

        return events
    }

    private func parseEventProperty(line: String, event: ParsedEvent) -> ParsedEvent {
        var updatedEvent = event

        if line.hasPrefix("SUMMARY:") {
            updatedEvent.title = String(line.dropFirst("SUMMARY:".count))
        } else if line.hasPrefix("DTSTART") {
            if let date = extractDate(from: line) {
                updatedEvent.startDate = date
            }
        } else if line.hasPrefix("DTEND") {
            if let date = extractDate(from: line) {
                updatedEvent.endDate = date
            }
        } else if line.hasPrefix("LOCATION:") {
            updatedEvent.location = String(line.dropFirst("LOCATION:".count))
        } else if line.hasPrefix("DESCRIPTION:") {
            updatedEvent.notes = String(line.dropFirst("DESCRIPTION:".count))
        } else if line.hasPrefix("UID:") {
            updatedEvent.uid = String(line.dropFirst("UID:".count))
        }

        return updatedEvent
    }

    private func extractDate(from line: String) -> Date? {
        // Extract date from DTSTART or DTEND line
        // Format: DTSTART:20240101T120000Z or DTSTART;VALUE=DATE:20240101

        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }

        let dateString = components[1]

        // Try parsing with time (YYYYMMDDTHHmmssZ)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try parsing date only (YYYYMMDD)
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateString)
    }

    struct ParsedEvent {
        var title: String = ""
        var startDate: Date = Date()
        var endDate: Date?
        var location: String?
        var notes: String?
        var uid: String?
    }

    // MARK: - EventKit Integration

    private func getOrCreateSubscriptionCalendar(name: String, color: Color) -> EKCalendar {
        // Check if calendar already exists
        let calendars = eventStore.calendars(for: .event)
        if let existingCalendar = calendars.first(where: { $0.title == name }) {
            return existingCalendar
        }

        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        calendar.cgColor = NSColor(color).cgColor
        calendar.source = eventStore.defaultCalendarForNewEvents?.source

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print("Failed to create calendar: \(error)")
            // Return default calendar as fallback
            return eventStore.defaultCalendarForNewEvents!
        }
    }

    private func createEvent(_ parsedEvent: ParsedEvent, in calendar: EKCalendar) {
        let event = EKEvent(eventStore: eventStore)
        event.title = parsedEvent.title
        event.startDate = parsedEvent.startDate
        event.endDate = parsedEvent.endDate ?? parsedEvent.startDate.addingTimeInterval(3600)
        event.location = parsedEvent.location
        event.notes = parsedEvent.notes
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Failed to save event: \(error)")
        }
    }

    private func removeEventsFromSubscription(_ subscription: CalendarSubscription) {
        let calendarName = "Subscribed: \(subscription.name)"
        let calendars = eventStore.calendars(for: .event)

        guard let calendar = calendars.first(where: { $0.title == calendarName }) else {
            return
        }

        removeEventsFromCalendar(calendar)

        // Delete the calendar
        do {
            try eventStore.removeCalendar(calendar, commit: true)
        } catch {
            print("Failed to remove calendar: \(error)")
        }
    }

    private func removeEventsFromCalendar(_ calendar: EKCalendar) {
        let startDate = Date().addingTimeInterval(-365 * 24 * 3600) // 1 year ago
        let endDate = Date().addingTimeInterval(365 * 24 * 3600) // 1 year ahead

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)

        for event in events {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                print("Failed to remove event: \(error)")
            }
        }
    }

    // MARK: - Auto Refresh

    private func startAutoRefresh() {
        // Check for subscriptions that need refreshing every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAndRefreshSubscriptions()
        }
    }

    private func checkAndRefreshSubscriptions() {
        let now = Date()

        for subscription in subscriptions where subscription.isEnabled {
            // Check if it's time to refresh
            if let lastSync = subscription.lastSyncDate {
                let timeSinceLastSync = now.timeIntervalSince(lastSync)
                if timeSinceLastSync >= subscription.refreshInterval {
                    Task {
                        await syncSubscription(subscription)
                    }
                }
            } else {
                // Never synced before
                Task {
                    await syncSubscription(subscription)
                }
            }
        }
    }

    // MARK: - Import from URL

    func importFromURL(_ urlString: String, name: String? = nil) async throws -> CalendarSubscription {
        // Validate URL
        let httpsURL = urlString.replacingOccurrences(of: "webcal://", with: "https://")
        guard let url = URL(string: httpsURL) else {
            throw SubscriptionError.invalidURL
        }

        // Fetch to validate
        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse to get event count
        let events = parseiCalData(data)

        guard !events.isEmpty else {
            throw SubscriptionError.noEvents
        }

        // Extract calendar name from URL or use provided name
        let calendarName = name ?? url.host ?? "Custom Calendar"

        let subscription = CalendarSubscription(
            name: calendarName,
            url: urlString,
            category: .custom,
            eventCount: events.count
        )

        return subscription
    }

    // MARK: - Statistics

    func getTotalSubscribedEvents() -> Int {
        return subscriptions.reduce(0) { $0 + $1.eventCount }
    }

    func getActiveSubscriptionsCount() -> Int {
        return subscriptions.filter { $0.isEnabled }.count
    }

    func getSubscriptionsByCategory(_ category: SubscriptionCategory) -> [CalendarSubscription] {
        return subscriptions.filter { $0.category == category }
    }

    // MARK: - Persistence

    private func saveSubscriptions() {
        if let encoded = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encoded, forKey: subscriptionsKey)
        }
    }

    private func loadSubscriptions() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder().decode([CalendarSubscription].self, from: data) {
            subscriptions = decoded
        }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case invalidURL
    case noEvents
    case networkError
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The subscription URL is invalid"
        case .noEvents:
            return "No events found in the calendar"
        case .networkError:
            return "Failed to download calendar data"
        case .parseError:
            return "Failed to parse calendar data"
        }
    }
}
