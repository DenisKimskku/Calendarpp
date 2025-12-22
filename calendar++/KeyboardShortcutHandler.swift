//
//  KeyboardShortcutHandler.swift
//  calendar++
//
//  Handles global keyboard shortcuts for the app
//

import SwiftUI
import AppKit
import Combine

class KeyboardShortcutHandler: ObservableObject {
    static let shared = KeyboardShortcutHandler()

    @Published var showQuickAdd = false
    @Published var shouldOpenSettings = false
    @Published var shouldNavigateToToday = false

    private var eventMonitor: Any?

    init() {
        setupKeyboardMonitor()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupKeyboardMonitor() {
        // Monitor for local keyboard events in the app
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let modifiers = event.modifierFlags
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // Cmd+N: New event
            if modifiers.contains(.command) && !modifiers.contains([.shift, .option, .control]) && key == "n" {
                self.showQuickAdd = true
                return nil // Consume the event
            }

            // Cmd+T: Today
            if modifiers.contains(.command) && !modifiers.contains([.shift, .option, .control]) && key == "t" {
                self.shouldNavigateToToday = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shouldNavigateToToday = false
                }
                return nil
            }

            // Cmd+,: Settings
            if modifiers.contains(.command) && !modifiers.contains([.shift, .option, .control]) && key == "," {
                self.shouldOpenSettings = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shouldOpenSettings = false
                }
                return nil
            }

            // Cmd+Q: Quit (let system handle it)
            if modifiers.contains(.command) && !modifiers.contains([.shift, .option, .control]) && key == "q" {
                NSApp.terminate(nil)
                return nil
            }

            // Cmd+R: Refresh
            if modifiers.contains(.command) && !modifiers.contains([.shift, .option, .control]) && key == "r" {
                NotificationCenter.default.post(name: .refreshCalendar, object: nil)
                return nil
            }

            return event
        }
    }
}

// Notification names for keyboard shortcuts
extension Notification.Name {
    static let refreshCalendar = Notification.Name("refreshCalendar")
    static let navigateToToday = Notification.Name("navigateToToday")
}
