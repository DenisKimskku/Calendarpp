import SwiftUI

enum MenuBarDateFormat: String, CaseIterable, Identifiable {
    case dayOnly       // 26
    case monthDay      // Dec 26
    case weekdayDay    // Thu 26
    case yearMonthDay  // 2025-12-26
    case iconOnly      // Only icon, no text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dayOnly:      return "Day only (26)"
        case .monthDay:     return "Month + Day (Dec 26)"
        case .weekdayDay:   return "Weekday + Day (Thu 26)"
        case .yearMonthDay: return "Year-Month-Day (2025-12-26)"
        case .iconOnly:     return "Icon only"
        }
    }
}

final class SettingsViewModel: ObservableObject {
    @AppStorage("menuBarDateFormat") private var storedFormatRaw: String = MenuBarDateFormat.monthDay.rawValue

    @Published var menuBarDateFormat: MenuBarDateFormat = .monthDay {
        didSet {
            storedFormatRaw = menuBarDateFormat.rawValue
        }
    }

    @AppStorage("showNextEventDot") var showNextEventDot: Bool = true
    @AppStorage("startAtLogin") var startAtLogin: Bool = false
    @AppStorage("firstWeekdayIsMonday") var firstWeekdayIsMonday: Bool = false

    init() {
        menuBarDateFormat = MenuBarDateFormat(rawValue: storedFormatRaw) ?? .monthDay
    }
}
