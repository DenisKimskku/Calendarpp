import SwiftUI
import Combine

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

enum AgendaRange: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case threeMonths

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        }
    }
}

final class SettingsViewModel: ObservableObject {
    @AppStorage("menuBarDateFormat") private var storedFormatRaw: String = MenuBarDateFormat.monthDay.rawValue
    @AppStorage("agendaRangeRaw") private var storedAgendaRangeRaw: String = AgendaRange.week.rawValue

    @Published var menuBarDateFormat: MenuBarDateFormat = .monthDay {
        didSet {
            storedFormatRaw = menuBarDateFormat.rawValue
        }
    }

    @Published var agendaRange: AgendaRange = .week {
        didSet {
            storedAgendaRangeRaw = agendaRange.rawValue
        }
    }

    @AppStorage("showNextEventDot") var showNextEventDot: Bool = true
    @AppStorage("startAtLogin") var startAtLogin: Bool = false
    @AppStorage("firstWeekdayIsMonday") var firstWeekdayIsMonday: Bool = false
    @AppStorage("showBusyBar") var showBusyBar: Bool = true
    @AppStorage("busyBarMaxHours") var busyBarMaxHours: Double = 8.0
    @AppStorage("worldClockTimeZones") var worldClockTimeZones: String = ""

    init() {
        menuBarDateFormat = MenuBarDateFormat(rawValue: storedFormatRaw) ?? .monthDay
        agendaRange = AgendaRange(rawValue: storedAgendaRangeRaw) ?? .week
    }

    func isCalendarEnabled(_ calendarIdentifier: String) -> Bool {
        // always return true for now
        return true
    }
}

