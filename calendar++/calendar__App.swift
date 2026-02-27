//
//  calendar__App.swift
//  calendar++
//
//  Created by den on 12/6/25.
//

import SwiftUI
import AppKit

@main
struct calendar__App: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var eventKit = EventKitManager()
    @StateObject private var settings = SettingsViewModel()
    @StateObject private var calendarVM = CalendarViewModel()
    @StateObject private var googleCalendar = GoogleCalendarManager()
    @StateObject private var templatesManager = EventTemplatesManager()
    @StateObject private var filterManager = CalendarFilterManager()
    @StateObject private var reminders = ReminderManager()
    @StateObject private var categoriesManager = EventCategoriesManager()

    // Phase 6 Features
    @StateObject private var analyticsManager = TimeAnalyticsManager()
    @StateObject private var prepManager = MeetingPrepManager()
    @StateObject private var focusProtection = FocusTimeProtectionManager()
    @StateObject private var briefingManager = DailyBriefingManager()
    @StateObject private var bufferManager = SmartBufferTimeManager()
    @StateObject private var costCalculator = MeetingCostCalculator()
    @StateObject private var availabilityManager = AvailabilitySharingManager()

    // Phase 7 Features
    @StateObject private var inboxManager = CalendarInboxManager()
    @StateObject private var commandsManager = NaturalLanguageCommandsManager()
    @StateObject private var achievementsManager = ProductivityAchievementsManager()

	    // Phase 8 AI/ML Features
	    @StateObject private var smartScheduler = SmartSchedulingAssistant()
	    @StateObject private var eventCategorizer = EventCategorizationML()
	    @StateObject private var conflictPredictor = SmartConflictPredictor()
    @State private var lastHandledURLSignature = ""
    @State private var lastHandledURLAt = Date.distantPast

    init() {
        // Keep the system login-item state aligned with the stored preference.
        StartAtLoginManager.syncToStoredPreferenceIfPossible()
        DispatchQueue.main.async {
            DynamicAppIconManager.shared.start()
        }
    }

    var body: some Scene {
        Window("calendar++", id: "main") {
            MainWindowView()
                .environmentObject(eventKit)
                .environmentObject(settings)
                .environmentObject(calendarVM)
                .environmentObject(googleCalendar)
                .environmentObject(templatesManager)
                .environmentObject(filterManager)
                .environmentObject(reminders)
                .environmentObject(categoriesManager)
                .environmentObject(analyticsManager)
                .environmentObject(prepManager)
                .environmentObject(focusProtection)
                .environmentObject(briefingManager)
                .environmentObject(bufferManager)
                .environmentObject(costCalculator)
                .environmentObject(availabilityManager)
                .environmentObject(inboxManager)
                .environmentObject(commandsManager)
                .environmentObject(achievementsManager)
                .environmentObject(smartScheduler)
                .environmentObject(eventCategorizer)
                .environmentObject(conflictPredictor)
                .environment(\.calendarPPPresentationContext, .window)
                .tint(settings.resolvedTintColor)
                .accentColor(settings.resolvedTintColor)
                .onOpenURL(perform: handleIncomingURL)
        }
        .defaultSize(width: 1240, height: 800)
        .commands {
            CalendarPPAppCommands()
        }

        Window("Settings", id: "settings") {
            PreferencesView()
                .environmentObject(settings)
                .environmentObject(googleCalendar)
                .environment(\.calendarPPPresentationContext, .window)
                .tint(settings.resolvedTintColor)
                .accentColor(settings.resolvedTintColor)
        }
        .defaultSize(width: 680, height: 560)

        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(eventKit)
                .environmentObject(settings)
                .environmentObject(calendarVM)
                .environmentObject(googleCalendar)
                .environmentObject(templatesManager)
                .environmentObject(filterManager)
                .environmentObject(reminders)
                .environmentObject(categoriesManager)
                .environmentObject(analyticsManager)
                .environmentObject(prepManager)
                .environmentObject(focusProtection)
                .environmentObject(briefingManager)
                .environmentObject(bufferManager)
                .environmentObject(costCalculator)
                .environmentObject(availabilityManager)
                .environmentObject(inboxManager)
                .environmentObject(commandsManager)
                .environmentObject(achievementsManager)
                .environmentObject(smartScheduler)
                .environmentObject(eventCategorizer)
                .environmentObject(conflictPredictor)
                .environment(\.calendarPPPresentationContext, .menuBar)
                .tint(settings.resolvedTintColor)
                .accentColor(settings.resolvedTintColor)
                .onOpenURL(perform: handleIncomingURL)
        } label: {
            MenuBarLabelView()
                .environmentObject(eventKit)
                .environmentObject(filterManager)
                .environmentObject(settings)
                .environment(\.calendarPPPresentationContext, .menuBar)
                .tint(settings.resolvedTintColor)
                .accentColor(settings.resolvedTintColor)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "calendarplusplus" else { return }

        let signature = url.absoluteString
        let now = Date()
        if signature == lastHandledURLSignature, now.timeIntervalSince(lastHandledURLAt) < 0.7 {
            return
        }
        lastHandledURLSignature = signature
        lastHandledURLAt = now

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let action = (
            components?.host?.lowercased()
            ?? url.pathComponents.dropFirst().first?.lowercased()
            ?? ""
        )
        let queryItems = components?.queryItems ?? []
        let query: [String: String] = Dictionary(
            uniqueKeysWithValues: queryItems.map { item in
                (item.name.lowercased(), item.value ?? "")
            }
        )

        switch action {
        case "show-date":
            handleShowDate(query: query)
        case "new-event":
            handleCreateEvent(query: query)
        case "set-focus":
            let requested = query["set"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let requested, !requested.isEmpty {
                filterManager.applyCalendarFocusSet(requested)
            } else {
                filterManager.applyCalendarFocusSet(CalendarSet.all.rawValue)
            }
        case "settings", "preferences":
            openWindow(id: "settings")
        default:
            break
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func handleShowDate(query: [String: String]) {
        let targetDate = unixTimestamp(from: query["timestamp"]) ?? Date()
        calendarVM.selectedDate = targetDate
        calendarVM.currentMonth = monthAnchor(for: targetDate)
        eventKit.reloadAllEvents(around: targetDate)
    }

    @MainActor
    private func handleCreateEvent(query: [String: String]) {
        let trimmedTitle = query["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmedTitle.isEmpty ? "New Event" : trimmedTitle
        let startDate = unixTimestamp(from: query["start"]) ?? Date()
        let parsedEnd = unixTimestamp(from: query["end"])
        let endDate = parsedEnd ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600)
        let safeEndDate = endDate > startDate
            ? endDate
            : (Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600))

        let location = query["location"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = query["notes"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        eventKit.requestAccessIfNeeded()
        let result = eventKit.createEventResult(
            title: title,
            startDate: startDate,
            endDate: safeEndDate,
            location: location?.isEmpty == true ? nil : location,
            notes: notes?.isEmpty == true ? nil : notes,
            calendar: nil
        )

        if case .success = result {
            calendarVM.selectedDate = startDate
            calendarVM.currentMonth = monthAnchor(for: startDate)
            eventKit.reloadAllEvents(around: startDate)
        }
    }

    private func unixTimestamp(from rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        guard let value = Double(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private func monthAnchor(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct CalendarPPAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
