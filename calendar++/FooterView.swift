import SwiftUI
import AppKit

struct FooterView: View {
    @EnvironmentObject var keyboardHandler: KeyboardShortcutHandler

    @State private var showingSettings = false
    @State private var showingTemplates = false
    @State private var showingCalendarFilter = false
    @State private var showingQuickAdd = false

    var body: some View {
        VStack(spacing: 8) {
            // Quick Add Event (shown when keyboard shortcut or button pressed)
            if showingQuickAdd || keyboardHandler.showQuickAdd {
                QuickAddEventView(isPresented: $showingQuickAdd)
                    .padding(.horizontal, 4)
                    .onDisappear {
                        keyboardHandler.showQuickAdd = false
                        showingQuickAdd = false
                    }

                Divider()
            }

            HStack(spacing: 12) {
                Button {
                    openCalendarApp()
                } label: {
                    Label("Open Calendar", systemImage: "calendar")
                }

                Button {
                    showingQuickAdd.toggle()
                } label: {
                    Label("Quick Add", systemImage: "plus.circle")
                }
                .keyboardShortcut("n", modifiers: .command)

            Button {
                showingTemplates = true
            } label: {
                Label("Templates", systemImage: "doc.text")
            }
            .popover(isPresented: $showingTemplates) {
                EventTemplatesView()
            }

            Button {
                showingCalendarFilter = true
            } label: {
                Label("Filter Calendars", systemImage: "line.3.horizontal.decrease.circle")
            }
            .popover(isPresented: $showingCalendarFilter) {
                CalendarFilterView()
            }

            Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
                .popover(isPresented: $showingSettings) {
                    SettingsPopoverView()
                        .frame(width: 500, height: 450)
                }

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .labelStyle(.iconOnly)
            .controlSize(.small)
        }
        .onChange(of: keyboardHandler.showQuickAdd) { show in
            if show {
                showingQuickAdd = true
            }
        }
    }

    private func openCalendarApp() {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else if let url = URL(string: "/System/Applications/Calendar.app"), FileManager.default.fileExists(atPath: url.path) {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else if let url = URL(string: "/Applications/Calendar.app"), FileManager.default.fileExists(atPath: url.path) {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        }
    }

    private func openPreferences() {
        showingSettings = true
    }
}

// Settings popover view
struct SettingsPopoverView: View {
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    var body: some View {
        PreferencesView()
            .environmentObject(settings)
            .environmentObject(googleCalendar)
    }
}
