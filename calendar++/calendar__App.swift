//
//  calendar__App.swift
//  calendar++
//
//  Created by den on 12/6/25.
//

import SwiftUI

@main
struct calendar__App: App {
    @StateObject private var eventKit = EventKitManager()
    @StateObject private var settings = SettingsViewModel()
    @StateObject private var calendarVM = CalendarViewModel()
    @StateObject private var googleCalendar = GoogleCalendarManager()
    @StateObject private var templatesManager = EventTemplatesManager()
    @StateObject private var filterManager = CalendarFilterManager()

    var body: some Scene {
        MenuBarExtra("calendar++", systemImage: "calendar") {
            MenuBarRootView()
                .environmentObject(eventKit)
                .environmentObject(settings)
                .environmentObject(calendarVM)
                .environmentObject(googleCalendar)
                .environmentObject(templatesManager)
                .environmentObject(filterManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(settings)
                .environmentObject(googleCalendar)
        }
    }
}
