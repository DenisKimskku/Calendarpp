// CalenderPlusIntents.swift
// App Intents for Shortcuts integration

import AppIntents
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
        // Use shared event bridge to create event
        await EventKitBridge.shared.createEvent(
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
        await EventKitBridge.shared.startDeepWork(duration: duration)
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
    
    private init() {}
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        location: String?,
        isAllDay: Bool
    ) async {
        // Post notification to main app to create event
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateEventIntent"),
                object: nil,
                userInfo: [
                    "title": title,
                    "startDate": startDate,
                    "endDate": endDate,
                    "location": location as Any,
                    "isAllDay": isAllDay
                ]
            )
        }
    }
    
    func getNextEvent() async -> (title: String, startDate: Date)? {
        // In production, use App Groups to share data
        // For now, return nil - app should listen to notifications
        return nil
    }
    
    func startDeepWork(duration: Int) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("StartDeepWorkIntent"),
                object: nil,
                userInfo: ["duration": duration]
            )
        }
    }
    
    func setCalendarFocus(_ focusSet: String) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("SetCalendarFocusIntent"),
                object: nil,
                userInfo: ["focusSet": focusSet]
            )
        }
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
                "What's my next event",
                "Show next meeting in \(.applicationName)"
            ],
            shortTitle: "Next Event",
            systemImageName: "calendar"
        )
        
        AppShortcut(
            intent: StartDeepWorkIntent(),
            phrases: [
                "Start deep work in \(.applicationName)",
                "Begin focus session"
            ],
            shortTitle: "Deep Work",
            systemImageName: "brain.head.profile"
        )
        
        AppShortcut(
            intent: SetCalendarFocusIntent(),
            phrases: [
                "Switch to work calendar",
                "Show personal calendar"
            ],
            shortTitle: "Switch Calendar",
            systemImageName: "calendar.badge.clock"
        )
    }
}
