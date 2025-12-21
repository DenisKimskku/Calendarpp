import SwiftUI
import AppKit

struct FooterView: View {
    var body: some View {
        HStack(spacing: 12) {
            Button {
                openCalendarApp()
            } label: {
                Label("Open Calendar", systemImage: "calendar")
            }

            Spacer()

            Button {
                openPreferences()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .labelStyle(.iconOnly)
        .controlSize(.small)
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
