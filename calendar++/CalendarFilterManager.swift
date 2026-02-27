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
    private let focusSetKey = "calendarFocusSet"
    private let hiddenCalendarMigrationKey = "didMigrateHiddenCalendarsToStableIds_v1"
    private let workKeywords = ["work", "office", "company", "client", "project", "team", "business", "corp"]
    private let personalKeywords = ["personal", "home", "family", "private", "life", "birthday"]
    private let eventStore = EKEventStore()

    private var localFocusObserver: NSObjectProtocol?
    private var distributedFocusObserver: NSObjectProtocol?

    init() {
        loadHiddenCalendars()
        migrateLegacyHiddenCalendarNamesIfNeeded()
        registerFocusObservers()
        applyStoredFocusIfNeeded()
    }

    deinit {
        if let localFocusObserver {
            NotificationCenter.default.removeObserver(localFocusObserver)
        }
        if let distributedFocusObserver {
            DistributedNotificationCenter.default().removeObserver(distributedFocusObserver)
        }
    }

    // MARK: - Visibility Management

    private func isCalendarHidden(calendarId: String) -> Bool {
        hiddenCalendarIds.contains(calendarId)
    }

    func isCalendarVisible(calendarId: String, calendarName: String? = nil) -> Bool {
        return !isCalendarHidden(calendarId: calendarId)
    }

    func toggleCalendar(calendarId: String, calendarName: String? = nil) {
        updateHiddenCalendars { hidden in
            if isCalendarHidden(calendarId: calendarId) {
                hidden.remove(calendarId)
            } else {
                hidden.insert(calendarId)
            }
            if let calendarName { hidden.remove(calendarName) }
        }
    }

    func showCalendar(calendarId: String, calendarName: String? = nil) {
        updateHiddenCalendars { hidden in
            hidden.remove(calendarId)
            if let calendarName { hidden.remove(calendarName) }
        }
    }

    func hideCalendar(calendarId: String, calendarName: String? = nil) {
        updateHiddenCalendars { hidden in
            hidden.insert(calendarId)
            if let calendarName { hidden.remove(calendarName) }
        }
    }

    func showAllCalendars() {
        updateHiddenCalendars { hidden in
            hidden.removeAll()
        }
    }

    // MARK: - Filtering

    func filterEvents(_ events: [EventSummary]) -> [EventSummary] {
        return events.filter { event in
            guard let calendarId = event.calendarId else {
                return true
            }
            if hiddenCalendarIds.contains(calendarId) {
                return false
            }
            return true
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

    private func updateHiddenCalendars(_ transform: (inout Set<String>) -> Void) {
        var updated = hiddenCalendarIds
        transform(&updated)
        hiddenCalendarIds = updated
        saveHiddenCalendars()
    }

    // MARK: - Focus Integration

    private func registerFocusObservers() {
        localFocusObserver = NotificationCenter.default.addObserver(
            forName: .setCalendarFocusIntent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFocusNotification(notification)
        }

        distributedFocusObserver = DistributedNotificationCenter.default().addObserver(
            forName: .setCalendarFocusIntent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFocusNotification(notification)
        }
    }

    private func handleFocusNotification(_ notification: Notification) {
        guard let focusSetRaw = notification.userInfo?["focusSet"] as? String else {
            return
        }
        applyCalendarFocusSet(focusSetRaw, persist: true)
    }

    private func applyStoredFocusIfNeeded() {
        guard let stored = UserDefaults.standard.string(forKey: focusSetKey) else {
            return
        }
        applyCalendarFocusSet(stored, persist: false)
    }

    func applyCalendarFocusSet(_ rawValue: String, persist: Bool = true) {
        let normalized = rawValue.lowercased()
        let focusSet = CalendarSet(rawValue: normalized) ?? .all

        if persist {
            UserDefaults.standard.set(focusSet.rawValue, forKey: focusSetKey)
        }

        switch focusSet {
        case .all:
            showAllCalendars()
        case .work, .personal:
            applyFocusedCalendarVisibility(for: focusSet)
        }
    }

    private func applyFocusedCalendarVisibility(for focusSet: CalendarSet) {
        let calendars = eventStore.calendars(for: .event)
        guard !calendars.isEmpty else { return }

        let allCalendarIds = Set(calendars.map(\.calendarIdentifier))
        let matchingIds = Set(
            calendars
                .filter { calendarMatchesFocusSet($0, focusSet: focusSet) }
                .map(\.calendarIdentifier)
        )

        // Avoid an accidental "hide everything" outcome when heuristics don't match.
        guard !matchingIds.isEmpty else {
            showAllCalendars()
            return
        }

        updateHiddenCalendars { hidden in
            for id in allCalendarIds {
                if matchingIds.contains(id) {
                    hidden.remove(id)
                } else {
                    hidden.insert(id)
                }
            }
        }
    }

    private func calendarMatchesFocusSet(_ calendar: EKCalendar, focusSet: CalendarSet) -> Bool {
        let searchable = "\(calendar.title) \(calendar.source.title)".lowercased()
        let hasWorkKeyword = workKeywords.contains { searchable.contains($0) }
        let hasPersonalKeyword = personalKeywords.contains { searchable.contains($0) }

        switch focusSet {
        case .all:
            return true
        case .work:
            if hasPersonalKeyword { return false }
            if hasWorkKeyword { return true }
            return calendar.source.sourceType == .exchange
        case .personal:
            if hasPersonalKeyword { return true }
            if hasWorkKeyword { return false }
            return calendar.type == .birthday || calendar.source.sourceType == .local
        }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyHiddenCalendarNamesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hiddenCalendarMigrationKey) else { return }

        let localCalendarNames = Set(eventStore.calendars(for: .event).map(\.title))
        let cleaned = hiddenCalendarIds.subtracting(localCalendarNames)
        if cleaned != hiddenCalendarIds {
            hiddenCalendarIds = cleaned
            saveHiddenCalendars()
        }

        defaults.set(true, forKey: hiddenCalendarMigrationKey)
    }
}
