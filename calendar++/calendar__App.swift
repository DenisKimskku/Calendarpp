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

    var body: some Scene {
        MenuBarExtra("calendar++", systemImage: "calendar") {
            MenuBarRootView()
                .environmentObject(eventKit)
                .environmentObject(settings)
                .environmentObject(calendarVM)
                .environmentObject(googleCalendar)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(settings)
                .environmentObject(googleCalendar)
        }
    }
}

// Handle OAuth callback URL
extension calendar__App {
    func handleURL(_ url: URL) {
        googleCalendar.handleOAuthCallback(url: url)
    }
}

// Add NSApplicationDelegate to handle URL scheme
class AppDelegate: NSObject, NSApplicationDelegate {
    var app: calendar__App?

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            app?.handleURL(url)
        }
    }
}
