import Foundation
import Combine

enum CalendarSet: String, CaseIterable, Identifiable {
    case all
    case work
    case personal
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All Calendars"
        case .work: return "Work"
        case .personal: return "Personal"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "calendar"
        case .work: return "briefcase.fill"
        case .personal: return "house.fill"
        }
    }
}

final class FocusManager: ObservableObject {
    @Published var currentFocusMode: String? = nil
    @Published var activeCalendarSet: CalendarSet = .all
    @Published var workCalendarIds: Set<String> = []
    @Published var personalCalendarIds: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Monitor for Focus mode changes (macOS 13+)
        if #available(macOS 13.0, *) {
            // DistributedNotificationCenter for Focus mode detection
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(focusModeChanged),
                name: NSNotification.Name("com.apple.focusmode.changed"),
                object: nil
            )
        }
    }
    
    @objc private func focusModeChanged(_ notification: Notification) {
        // Parse Focus mode state
        // This is a simplified version - actual implementation would parse notification userInfo
        updateCalendarSetBasedOnFocus()
    }
    
    func setCalendarSet(_ set: CalendarSet) {
        activeCalendarSet = set
    }
    
    func assignCalendarToSet(calendarId: String, set: CalendarSet) {
        switch set {
        case .work:
            workCalendarIds.insert(calendarId)
            personalCalendarIds.remove(calendarId)
        case .personal:
            personalCalendarIds.insert(calendarId)
            workCalendarIds.remove(calendarId)
        case .all:
            break
        }
    }
    
    func shouldShowCalendar(_ calendarId: String) -> Bool {
        switch activeCalendarSet {
        case .all:
            return true
        case .work:
            return workCalendarIds.contains(calendarId)
        case .personal:
            return personalCalendarIds.contains(calendarId)
        }
    }
    
    private func updateCalendarSetBasedOnFocus() {
        // Auto-switch based on Focus mode
        if let focus = currentFocusMode {
            if focus.contains("Work") || focus.contains("work") {
                activeCalendarSet = .work
            } else if focus.contains("Personal") || focus.contains("personal") {
                activeCalendarSet = .personal
            }
        }
    }
    
    func getFilteredCalendarIds(enabledIds: Set<String>) -> Set<String> {
        switch activeCalendarSet {
        case .all:
            return enabledIds
        case .work:
            return enabledIds.intersection(workCalendarIds)
        case .personal:
            return enabledIds.intersection(personalCalendarIds)
        }
    }
}
