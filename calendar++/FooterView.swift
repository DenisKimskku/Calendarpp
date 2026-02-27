import SwiftUI
import AppKit

struct FooterView: View {
    @EnvironmentObject var keyboardHandler: KeyboardShortcutHandler
    @Environment(\.openWindow) private var openWindow

    @State private var showingTemplates = false
    @State private var showingCalendarFilter = false
    @State private var showingQuickAdd = false
    @State private var showingFeaturesMenu = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                showingQuickAdd = true
            } label: {
                Label("New Event", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)

            HStack(spacing: 8) {
                Button {
                    navigateToToday()
                } label: {
                    Label("Today", systemImage: "calendar")
                }
                .help("Jump to today")
                .buttonStyle(.plain)
                .calendarPPZenCard(cornerRadius: 999, strong: false)

                Button {
                    openSearch()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .calendarPPZenCard(cornerRadius: 999, strong: false)
                .keyboardShortcut("f", modifiers: .command)
                .help("Open search")

                Button {
                    openSettingsWindow()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .calendarPPZenCard(cornerRadius: 999, strong: false)
                .keyboardShortcut(",", modifiers: .command)

                Menu {
                    Button {
                        openMainWindow()
                    } label: {
                        Label("Open Main Window", systemImage: "macwindow")
                    }

                    Button {
                        showingFeaturesMenu = true
                    } label: {
                        Label("Features", systemImage: "sparkles")
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])

                    Button {
                        showingTemplates = true
                    } label: {
                        Label("Templates", systemImage: "doc.text")
                    }

                    Button {
                        showingCalendarFilter = true
                    } label: {
                        Label("Filter Calendars", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Divider()

                    Button {
                        NotificationCenter.default.post(name: .refreshCalendar, object: nil)
                    } label: {
                        Label("Refresh Calendars", systemImage: "arrow.clockwise")
                    }

                    Button {
                        openCalendarApp()
                    } label: {
                        Label("Open Apple Calendar", systemImage: "calendar")
                    }

                    Divider()

                    Button(role: .destructive) {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit calendar++", systemImage: "power")
                    }
                    .keyboardShortcut("q", modifiers: .command)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .help("More actions")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .popover(isPresented: $showingTemplates) {
                EventTemplatesView()
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddEventView(isPresented: $showingQuickAdd)
                    .padding(16)
                    .frame(minWidth: 560, minHeight: 360)
            }
            .popover(isPresented: $showingCalendarFilter) {
                CalendarFilterView()
            }
            .popover(isPresented: $showingFeaturesMenu) {
                FeaturesMenuView()
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)
        }
        .onChange(of: keyboardHandler.showQuickAdd) { show in
            if show {
                showingQuickAdd = true
                keyboardHandler.showQuickAdd = false
            }
        }
        .onChange(of: showingQuickAdd) { isPresented in
            if !isPresented {
                keyboardHandler.showQuickAdd = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showFeaturesMenu)) { _ in
            showingFeaturesMenu = true
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSearch() {
        openMainWindow()
        NotificationCenter.default.post(name: .openMainSearch, object: nil)
    }

    private func navigateToToday() {
        keyboardHandler.shouldNavigateToToday = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            keyboardHandler.shouldNavigateToToday = false
        }
    }

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
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

}
