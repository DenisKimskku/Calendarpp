//
//  TimezoneManager.swift
//  calendar++
//
//  Manages timezone conversions and world clock display
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

// MARK: - Timezone Info

struct TimezoneInfo: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var timezone: String // Timezone identifier (e.g., "America/New_York")
    var city: String
    var countryCode: String
    var isDefault: Bool
    var order: Int

    init(
        id: UUID = UUID(),
        name: String? = nil,
        timezone: String,
        city: String,
        countryCode: String = "",
        isDefault: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.name = name ?? city
        self.timezone = timezone
        self.city = city
        self.countryCode = countryCode
        self.isDefault = isDefault
        self.order = order
    }

    var timeZone: TimeZone? {
        TimeZone(identifier: timezone)
    }

    var currentTime: Date {
        Date()
    }

    func formattedTime(date: Date = Date()) -> String {
        guard let tz = timeZone else { return "Invalid" }

        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func formattedDate(date: Date = Date()) -> String {
        guard let tz = timeZone else { return "Invalid" }

        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var offsetFromGMT: String {
        guard let tz = timeZone else { return "" }
        let offset = tz.secondsFromGMT()
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60

        if minutes == 0 {
            return String(format: "GMT%+d", hours)
        } else {
            return String(format: "GMT%+d:%02d", hours, minutes)
        }
    }

    var isDaylightSavingTime: Bool {
        guard let tz = timeZone else { return false }
        return tz.isDaylightSavingTime(for: Date())
    }
}

// MARK: - Event with Timezone Info

struct EventWithTimezone {
    let event: EventSummary
    let originalTimezone: TimeZone
    let displayTimezones: [TimezoneInfo]

    func timeInTimezone(_ timezone: TimeZone) -> (start: Date, end: Date) {
        // EventKit events are already in the correct timezone
        // We just need to format them for display
        return (event.startDate, event.endDate)
    }

    func formattedTimeRange(in timezoneInfo: TimezoneInfo) -> String {
        guard let tz = timezoneInfo.timeZone else { return "" }

        let formatter = DateFormatter()
        formatter.timeZone = tz
        formatter.timeStyle = .short

        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    func timeDifference(to timezone: TimeZone) -> String {
        let originalOffset = originalTimezone.secondsFromGMT(for: event.startDate)
        let targetOffset = timezone.secondsFromGMT(for: event.startDate)
        let difference = (targetOffset - originalOffset) / 3600

        if difference == 0 {
            return "Same time"
        } else if difference > 0 {
            return "+\(difference)h ahead"
        } else {
            return "\(difference)h behind"
        }
    }
}

// MARK: - Timezone Manager

class TimezoneManager: ObservableObject {
    @Published var favoriteTimezones: [TimezoneInfo] = []
    @Published var currentTimezone: TimezoneInfo

    private let favoritesKey = "favorite_timezones"

    // Popular cities with their timezones
    static let popularCities: [TimezoneInfo] = [
        TimezoneInfo(timezone: "America/New_York", city: "New York", countryCode: "US"),
        TimezoneInfo(timezone: "America/Los_Angeles", city: "Los Angeles", countryCode: "US"),
        TimezoneInfo(timezone: "America/Chicago", city: "Chicago", countryCode: "US"),
        TimezoneInfo(timezone: "America/Denver", city: "Denver", countryCode: "US"),
        TimezoneInfo(timezone: "Europe/London", city: "London", countryCode: "GB"),
        TimezoneInfo(timezone: "Europe/Paris", city: "Paris", countryCode: "FR"),
        TimezoneInfo(timezone: "Europe/Berlin", city: "Berlin", countryCode: "DE"),
        TimezoneInfo(timezone: "Asia/Tokyo", city: "Tokyo", countryCode: "JP"),
        TimezoneInfo(timezone: "Asia/Seoul", city: "Seoul", countryCode: "KR"),
        TimezoneInfo(timezone: "Asia/Shanghai", city: "Shanghai", countryCode: "CN"),
        TimezoneInfo(timezone: "Asia/Hong_Kong", city: "Hong Kong", countryCode: "HK"),
        TimezoneInfo(timezone: "Asia/Singapore", city: "Singapore", countryCode: "SG"),
        TimezoneInfo(timezone: "Asia/Dubai", city: "Dubai", countryCode: "AE"),
        TimezoneInfo(timezone: "Australia/Sydney", city: "Sydney", countryCode: "AU"),
        TimezoneInfo(timezone: "Pacific/Auckland", city: "Auckland", countryCode: "NZ"),
        TimezoneInfo(timezone: "America/Toronto", city: "Toronto", countryCode: "CA"),
        TimezoneInfo(timezone: "America/Mexico_City", city: "Mexico City", countryCode: "MX"),
        TimezoneInfo(timezone: "America/Sao_Paulo", city: "São Paulo", countryCode: "BR"),
        TimezoneInfo(timezone: "Africa/Cairo", city: "Cairo", countryCode: "EG"),
        TimezoneInfo(timezone: "Asia/Kolkata", city: "Mumbai", countryCode: "IN"),
    ]

    init() {
        // Set current timezone
        let systemTimezone = TimeZone.current
        currentTimezone = TimezoneInfo(
            name: "Local",
            timezone: systemTimezone.identifier,
            city: systemTimezone.identifier.components(separatedBy: "/").last ?? "Local",
            isDefault: true
        )

        loadFavorites()

        // Add current timezone to favorites if empty
        if favoriteTimezones.isEmpty {
            favoriteTimezones = [currentTimezone]
            saveFavorites()
        }
    }

    // MARK: - Timezone Operations

    func addFavorite(_ timezoneInfo: TimezoneInfo) {
        var newInfo = timezoneInfo
        newInfo.order = favoriteTimezones.count
        favoriteTimezones.append(newInfo)
        saveFavorites()
    }

    func removeFavorite(_ timezoneInfo: TimezoneInfo) {
        favoriteTimezones.removeAll { $0.id == timezoneInfo.id }
        reorderFavorites()
        saveFavorites()
    }

    func reorderFavorites() {
        for (index, _) in favoriteTimezones.enumerated() {
            favoriteTimezones[index].order = index
        }
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favoriteTimezones.move(fromOffsets: source, toOffset: destination)
        reorderFavorites()
        saveFavorites()
    }

    // MARK: - Time Conversions

    func convertTime(_ date: Date, from sourceTimezone: TimeZone, to targetTimezone: TimeZone) -> Date {
        // Dates are absolute points in time, so no conversion needed
        // The display will differ based on timezone
        return date
    }

    func formatTimeInTimezone(_ date: Date, timezone: TimeZone, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.timeStyle = style
        return formatter.string(from: date)
    }

    func formatDateInTimezone(_ date: Date, timezone: TimeZone, dateStyle: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateStyle = dateStyle
        return formatter.string(from: date)
    }

    func timeUntil(_ date: Date, in timezone: TimeZone) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval < 0 {
            return "Past"
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let days = hours / 24
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Timezone Utilities

    func searchTimezones(_ query: String) -> [TimezoneInfo] {
        let lowercasedQuery = query.lowercased()

        return Self.popularCities.filter { info in
            info.city.lowercased().contains(lowercasedQuery) ||
            info.timezone.lowercased().contains(lowercasedQuery) ||
            info.countryCode.lowercased().contains(lowercasedQuery)
        }
    }

    func getTimezoneDifference(from source: TimeZone, to target: TimeZone, at date: Date = Date()) -> Int {
        let sourceOffset = source.secondsFromGMT(for: date)
        let targetOffset = target.secondsFromGMT(for: date)
        return (targetOffset - sourceOffset) / 3600
    }

    func isBusinessHours(in timezone: TimeZone, at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: timezone, from: date)

        guard let hour = components.hour else { return false }

        // Business hours: 9 AM - 6 PM
        return hour >= 9 && hour < 18
    }

    func isSleepTime(in timezone: TimeZone, at date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: timezone, from: date)

        guard let hour = components.hour else { return false }

        // Sleep time: 10 PM - 7 AM
        return hour >= 22 || hour < 7
    }

    // MARK: - Meeting Time Finder

    func findBestMeetingTime(
        for timezones: [TimeZone],
        duration: TimeInterval,
        within dateRange: DateInterval,
        businessHoursOnly: Bool = true
    ) -> [Date] {
        var candidates: [Date] = []
        let interval: TimeInterval = 1800 // Check every 30 minutes

        var currentDate = dateRange.start
        while currentDate < dateRange.end {
            var isGoodTime = true

            for timezone in timezones {
                if businessHoursOnly && !isBusinessHours(in: timezone, at: currentDate) {
                    isGoodTime = false
                    break
                }

                if isSleepTime(in: timezone, at: currentDate) {
                    isGoodTime = false
                    break
                }
            }

            if isGoodTime {
                candidates.append(currentDate)
            }

            currentDate = currentDate.addingTimeInterval(interval)
        }

        return candidates
    }

    // MARK: - Event Timezone Helpers

    func createEventWithTimezone(
        title: String,
        startDate: Date,
        duration: TimeInterval,
        timezone: TimeZone
    ) -> EventWithTimezone {
        let event = EventSummary(
            id: UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(duration),
            isAllDay: false,
            calendarName: "Default",
            calendarColor: .blue
        )

        return EventWithTimezone(
            event: event,
            originalTimezone: timezone,
            displayTimezones: favoriteTimezones
        )
    }

    // MARK: - Persistence

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteTimezones) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([TimezoneInfo].self, from: data) {
            favoriteTimezones = decoded.sorted { $0.order < $1.order }
        }
    }

    // MARK: - Flag Emoji

    func flagEmoji(countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let scalarValue = UnicodeScalar(base + scalar.value) {
                emoji.append(String(scalarValue))
            }
        }
        return emoji
    }
}

// MARK: - Timezone Suggestions

extension TimezoneManager {
    func suggestTimezones(for location: String) -> [TimezoneInfo] {
        // Simple keyword matching for common locations
        let keywords = location.lowercased()

        return Self.popularCities.filter { city in
            city.city.lowercased().contains(keywords) ||
            city.timezone.lowercased().contains(keywords)
        }
    }

    func getTimezoneFromCoordinates(latitude: Double, longitude: Double) -> TimezoneInfo? {
        // Note: This is a simplified version
        // In production, you'd want to use a proper reverse geocoding service
        // or a timezone lookup library

        // For now, return closest popular city (very approximate)
        // This would need a proper geolocation database in production

        return nil
    }
}
