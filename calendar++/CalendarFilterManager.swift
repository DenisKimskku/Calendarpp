//
//  CalendarFilterManager.swift
//  calendar++
//
//  Manage which calendars are visible in the app
//

import Foundation
import EventKit
import Combine

class CalendarFilterManager: ObservableObject {
    @Published var hiddenCalendarIds: Set<String> = []

    private let userDefaultsKey = "hiddenCalendarIds"

    init() {
        loadHiddenCalendars()
    }

    // MARK: - Visibility Management

    func isCalendarVisible(calendarId: String) -> Bool {
        return !hiddenCalendarIds.contains(calendarId)
    }

    func toggleCalendar(calendarId: String) {
        if hiddenCalendarIds.contains(calendarId) {
            hiddenCalendarIds.remove(calendarId)
        } else {
            hiddenCalendarIds.insert(calendarId)
        }
        saveHiddenCalendars()
    }

    func showCalendar(calendarId: String) {
        hiddenCalendarIds.remove(calendarId)
        saveHiddenCalendars()
    }

    func hideCalendar(calendarId: String) {
        hiddenCalendarIds.insert(calendarId)
        saveHiddenCalendars()
    }

    func showAllCalendars() {
        hiddenCalendarIds.removeAll()
        saveHiddenCalendars()
    }

    // MARK: - Filtering

    func filterEvents(_ events: [EventSummary]) -> [EventSummary] {
        return events.filter { event in
            // For now, we'll filter by calendar name since EventSummary doesn't have calendarId
            // In a full implementation, we'd add calendarId to EventSummary
            return !hiddenCalendarIds.contains(event.calendarName)
        }
    }

    // MARK: - Persistence

    private func saveHiddenCalendars() {
        UserDefaults.standard.set(Array(hiddenCalendarIds), forKey: userDefaultsKey)
    }

    private func loadHiddenCalendars() {
        if let savedIds = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            hiddenCalendarIds = Set(savedIds)
        }
    }
}
