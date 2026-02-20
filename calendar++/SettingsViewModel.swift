import SwiftUI
import Combine
import AppKit

// MARK: - UI / Appearance

enum UIAccentChoice: String, CaseIterable, Identifiable {
    case system
    case jade
    case ocean
    case rose
    case amber
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .jade: return "Jade"
        case .ocean: return "Ocean"
        case .rose: return "Rose"
        case .amber: return "Amber"
        case .graphite: return "Graphite"
        }
    }

    var tintColor: Color {
        switch self {
        case .system:
            return Color(nsColor: NSColor.controlAccentColor)
        case .jade:
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    return NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.67, alpha: 1.0)
                }
                return NSColor(calibratedRed: 0.15, green: 0.52, blue: 0.44, alpha: 1.0)
            })
        case .ocean:
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    return NSColor(calibratedRed: 0.33, green: 0.66, blue: 0.96, alpha: 1.0)
                }
                return NSColor(calibratedRed: 0.12, green: 0.44, blue: 0.78, alpha: 1.0)
            })
        case .rose:
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    return NSColor(calibratedRed: 0.96, green: 0.48, blue: 0.70, alpha: 1.0)
                }
                return NSColor(calibratedRed: 0.78, green: 0.20, blue: 0.45, alpha: 1.0)
            })
        case .amber:
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    return NSColor(calibratedRed: 0.95, green: 0.74, blue: 0.30, alpha: 1.0)
                }
                return NSColor(calibratedRed: 0.72, green: 0.46, blue: 0.10, alpha: 1.0)
            })
        case .graphite:
            return Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    return NSColor(calibratedWhite: 0.76, alpha: 1.0)
                }
                return NSColor(calibratedWhite: 0.20, alpha: 1.0)
            })
        }
    }
}

enum UIInspectorMode: String, CaseIterable, Identifiable {
    case auto
    case always
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .always: return "Always"
        case .never: return "Never"
        }
    }

    var helpText: String {
        switch self {
        case .auto:
            return "Shows the inspector when there is enough space."
        case .always:
            return "Always shows the inspector (best with a wide window)."
        case .never:
            return "Always uses popovers instead of a right-side inspector."
        }
    }
}

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
    @AppStorage("showRemindersInAgenda") var showRemindersInAgenda: Bool = false
    @AppStorage("startAtLogin") var startAtLogin: Bool = false
    @AppStorage("firstWeekdayIsMonday") var firstWeekdayIsMonday: Bool = false
    @AppStorage("showBusyBar") var showBusyBar: Bool = true
    @AppStorage("busyBarMaxHours") var busyBarMaxHours: Double = 8.0
    @AppStorage("worldClockTimeZones") var worldClockTimeZones: String = ""

    // MARK: - UI / Appearance
    @AppStorage("uiAccentChoice") var uiAccentChoice: String = UIAccentChoice.jade.rawValue
    @AppStorage("uiInspectorMode") var uiInspectorMode: String = UIInspectorMode.auto.rawValue
    @AppStorage("uiSidebarHidden") var uiSidebarHidden: Bool = false
    @AppStorage("uiSidebarShowsMiniMonth") var uiSidebarShowsMiniMonth: Bool = true
    @AppStorage("uiBackgroundIntensity") var uiBackgroundIntensity: Double = 1.0
    @AppStorage("dynamicDockIconEnabled") var dynamicDockIconEnabled: Bool = true
    @AppStorage("dynamicDockIconUseAccent") var dynamicDockIconUseAccent: Bool = true

    // MARK: - Phase 6 Feature Toggles
    @AppStorage("enableTimeAnalytics") var enableTimeAnalytics: Bool = true
    @AppStorage("enableMeetingPrep") var enableMeetingPrep: Bool = true
    @AppStorage("enableFocusProtection") var enableFocusProtection: Bool = false
    @AppStorage("enableDailyBriefing") var enableDailyBriefing: Bool = false
    @AppStorage("enableSmartBuffer") var enableSmartBuffer: Bool = false
    @AppStorage("enableEnergyScheduling") var enableEnergyScheduling: Bool = false
    @AppStorage("enableMeetingCost") var enableMeetingCost: Bool = false
    @AppStorage("enableAvailabilitySharing") var enableAvailabilitySharing: Bool = false

    // MARK: - Phase 7 Feature Toggles
    @AppStorage("showExperimentalFeatures") var showExperimentalFeatures: Bool = false
    @AppStorage("enableCalendarInbox") var enableCalendarInbox: Bool = false
    @AppStorage("enableNaturalLanguageCommands") var enableNaturalLanguageCommands: Bool = false
    @AppStorage("enableAchievements") var enableAchievements: Bool = false

    // MARK: - Phase 8 AI/ML Feature Toggles
    @AppStorage("enableAIAssistant") var enableAIAssistant: Bool = false
    @AppStorage("enableSmartScheduling") var enableSmartScheduling: Bool = false
    @AppStorage("enableAutoCategorization") var enableAutoCategorization: Bool = false
    @AppStorage("enableConflictPrediction") var enableConflictPrediction: Bool = false

    init() {
        menuBarDateFormat = MenuBarDateFormat(rawValue: storedFormatRaw) ?? .monthDay
        agendaRange = AgendaRange(rawValue: storedAgendaRangeRaw) ?? .week

        // Migration: a previous build accidentally used a key with an embedded space.
        let oldKey = "enableAutoCategor ization"
        let newKey = "enableAutoCategorization"
        if UserDefaults.standard.object(forKey: newKey) == nil,
           let oldValue = UserDefaults.standard.object(forKey: oldKey) as? Bool {
            enableAutoCategorization = oldValue
        }

        // Production defaults migration: keep experimental features off by default.
        let productionDefaultsKey = "didApplyFeatureProductionDefaults_v3"
        if !UserDefaults.standard.bool(forKey: productionDefaultsKey) {
            enableTimeAnalytics = true
            enableMeetingPrep = true
            enableFocusProtection = false
            enableDailyBriefing = false
            enableSmartBuffer = false
            enableEnergyScheduling = false
            enableMeetingCost = false
            enableAvailabilitySharing = false

            showExperimentalFeatures = false
            enableCalendarInbox = false
            enableNaturalLanguageCommands = false
            enableAchievements = false

            enableAIAssistant = false
            enableSmartScheduling = false
            enableAutoCategorization = false
            enableConflictPrediction = false

            UserDefaults.standard.set(true, forKey: productionDefaultsKey)
        }

        // v4 migration: reduce surface area for users that still match the old "everything on" defaults.
        let reducedSurfaceDefaultsKey = "didApplyFeatureProductionDefaults_v4"
        if !UserDefaults.standard.bool(forKey: reducedSurfaceDefaultsKey) {
            let looksLikeLegacyAllOnDefaults =
                enableTimeAnalytics &&
                enableMeetingPrep &&
                enableFocusProtection &&
                enableDailyBriefing &&
                enableSmartBuffer &&
                enableEnergyScheduling &&
                enableMeetingCost &&
                enableAvailabilitySharing &&
                !showExperimentalFeatures &&
                !enableCalendarInbox &&
                !enableNaturalLanguageCommands &&
                !enableAchievements &&
                !enableAIAssistant &&
                !enableSmartScheduling &&
                !enableAutoCategorization &&
                !enableConflictPrediction

            if looksLikeLegacyAllOnDefaults {
                enableFocusProtection = false
                enableDailyBriefing = false
                enableSmartBuffer = false
                enableEnergyScheduling = false
                enableMeetingCost = false
                enableAvailabilitySharing = false
            }

            UserDefaults.standard.set(true, forKey: reducedSurfaceDefaultsKey)
        }

    }

    func isCalendarEnabled(_ calendarIdentifier: String) -> Bool {
        let hidden = UserDefaults.standard.array(forKey: "hiddenCalendarIds") as? [String] ?? []
        return !Set(hidden).contains(calendarIdentifier)
    }

    var resolvedTintColor: Color {
        UIAccentChoice(rawValue: uiAccentChoice)?.tintColor ?? UIAccentChoice.jade.tintColor
    }

    var resolvedInspectorMode: UIInspectorMode {
        UIInspectorMode(rawValue: uiInspectorMode) ?? .auto
    }

    var isPhase7Visible: Bool {
        showExperimentalFeatures
    }

    var isPhase8Visible: Bool {
        showExperimentalFeatures
    }

    func resetAppearanceToDefaults() {
        uiAccentChoice = UIAccentChoice.jade.rawValue
        uiInspectorMode = UIInspectorMode.auto.rawValue
        uiSidebarHidden = false
        uiSidebarShowsMiniMonth = true
        uiBackgroundIntensity = 1.0
        dynamicDockIconEnabled = true
        dynamicDockIconUseAccent = true
    }
}
