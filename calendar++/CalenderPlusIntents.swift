// CalenderPlusIntents.swift
// App Intents for Shortcuts integration

import AppIntents
import EventKit
import Foundation

// MARK: - Create Event Intent

struct CreateEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Calendar Event"
    static var description: IntentDescription? = "Create a new event in calendar++"
    
    @Parameter(title: "Title")
    var title: String
    
    @Parameter(title: "Start Date")
    var startDate: Date
    
    @Parameter(title: "End Date")
    var endDate: Date
    
    @Parameter(title: "Location", default: nil)
    var location: String?
    
    @Parameter(title: "All Day", default: false)
    var isAllDay: Bool
    
    func perform() async throws -> some IntentResult {
        try await EventKitBridge.shared.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            isAllDay: isAllDay
        )
        
        return .result()
    }
}

// MARK: - Get Next Event Intent

struct GetNextEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Next Event"
    static var description: IntentDescription? = "Get details about your next upcoming event"
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let nextEvent = await EventKitBridge.shared.getNextEvent()
        
        if let event = nextEvent {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .short
            
            let message = "\(event.title) at \(formatter.string(from: event.startDate))"
            return .result(value: message)
        } else {
            return .result(value: "No upcoming events")
        }
    }
}

// MARK: - Start Deep Work Intent

struct StartDeepWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Deep Work"
    static var description: IntentDescription? = "Start a deep work session"
    
    @Parameter(title: "Duration (minutes)", default: 60)
    var duration: Int
    
    func perform() async throws -> some IntentResult {
        try await EventKitBridge.shared.startDeepWork(duration: duration)
        return .result()
    }
}

// MARK: - Set Calendar Focus Intent

struct SetCalendarFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Calendar Focus"
    static var description: IntentDescription? = "Switch between Work, Personal, or All calendars"
    
    @Parameter(title: "Focus Set")
    var focusSet: CalendarSetEntity
    
    func perform() async throws -> some IntentResult {
        await EventKitBridge.shared.setCalendarFocus(focusSet.rawValue)
        return .result()
    }
}

// MARK: - Calendar Set Entity

enum CalendarSetEntity: String, AppEnum {
    case all = "all"
    case work = "work"
    case personal = "personal"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar Set"
    
    static var caseDisplayRepresentations: [CalendarSetEntity: DisplayRepresentation] = [
        .all: "All Calendars",
        .work: "Work",
        .personal: "Personal"
    ]
}

// MARK: - Event Bridge (Shared Access)

actor EventKitBridge {
    static let shared = EventKitBridge()
    private let eventStore = EKEventStore()
    
    private init() {}

    enum BridgeError: LocalizedError {
        case calendarAccessNotGranted
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .calendarAccessNotGranted:
                return "Calendar access is not granted. Enable it in System Settings and try again."
            case .saveFailed(let message):
                return message
            }
        }
    }
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        isAllDay: Bool
    ) async throws {
        guard await ensureEventAccess(forWrite: true) else {
            throw BridgeError.calendarAccessNotGranted
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.isAllDay = isAllDay
        event.location = location

        let start = startDate
        var end = endDate
        if end <= start {
            end = Calendar.current.date(byAdding: .minute, value: 30, to: start) ?? start.addingTimeInterval(30 * 60)
        }
        event.startDate = start
        event.endDate = end
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            throw BridgeError.saveFailed("Could not save event: \(error.localizedDescription)")
        }
    }
    
    func getNextEvent() async -> (title: String, startDate: Date)? {
        guard await ensureEventAccess(forWrite: false) else {
            return nil
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now.addingTimeInterval(2 * 24 * 3600)
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)

        let upcoming = eventStore.events(matching: predicate)
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }

        guard let next = upcoming.first else { return nil }
        return (next.title, next.startDate)
    }
    
    func startDeepWork(duration: Int) async throws {
        guard await ensureEventAccess(forWrite: true) else {
            throw BridgeError.calendarAccessNotGranted
        }

        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(max(5, duration) * 60))

        let event = EKEvent(eventStore: eventStore)
        event.title = "Deep Work"
        event.startDate = start
        event.endDate = end
        event.notes = "Created by calendar++ shortcut."
        event.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            throw BridgeError.saveFailed("Could not start deep work: \(error.localizedDescription)")
        }
    }
    
    func setCalendarFocus(_ focusSet: String) async {
        let normalizedFocusSet = CalendarSet(rawValue: focusSet.lowercased())?.rawValue ?? CalendarSet.all.rawValue
        UserDefaults.standard.set(normalizedFocusSet, forKey: "calendarFocusSet")

        let focusNotification = Notification.Name("calendarPP.setCalendarFocusIntent")
        let userInfo: [AnyHashable: Any] = ["focusSet": normalizedFocusSet]
        NotificationCenter.default.post(name: focusNotification, object: nil, userInfo: userInfo)
        DistributedNotificationCenter.default().postNotificationName(
            focusNotification,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    private func ensureEventAccess(forWrite: Bool) async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)

        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else { return false }
            return await ensureEventAccess(forWrite: forWrite)
        }

        if status == .authorized {
            return true
        }

        if #available(macOS 14.0, *) {
            if status == .fullAccess { return true }
            if forWrite, status == .writeOnly { return true }
        }

        return false
    }
}

// MARK: - App Shortcuts Provider

struct CalenderPlusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateEventIntent(),
            phrases: [
                "Create an event in \(.applicationName)",
                "Add event to \(.applicationName)"
            ],
            shortTitle: "Create Event",
            systemImageName: "calendar.badge.plus"
        )
        
        AppShortcut(
            intent: GetNextEventIntent(),
            phrases: [
                "What's my next event in \(.applicationName)",
                "Show next meeting in \(.applicationName)"
            ],
            shortTitle: "Next Event",
            systemImageName: "calendar"
        )
        
        AppShortcut(
            intent: StartDeepWorkIntent(),
            phrases: [
                "Start deep work in \(.applicationName)",
                "Begin focus session in \(.applicationName)"
            ],
            shortTitle: "Deep Work",
            systemImageName: "brain.head.profile"
        )
        
        AppShortcut(
            intent: SetCalendarFocusIntent(),
            phrases: [
                "Switch to work calendar in \(.applicationName)",
                "Show personal calendar in \(.applicationName)"
            ],
            shortTitle: "Switch Calendar",
            systemImageName: "calendar.badge.clock"
        )
    }
}
