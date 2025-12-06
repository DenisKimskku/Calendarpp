import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: SettingsViewModel

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            menuBarTab
                .tabItem {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }
        }
        .padding(16)
        .frame(width: 420, height: 260)
    }

    private var generalTab: some View {
        Form {
            Toggle("Start Calender+ at login", isOn: $settings.startAtLogin)
            Toggle("Week starts on Monday", isOn: $settings.firstWeekdayIsMonday)
        }
    }

    private var menuBarTab: some View {
        Form {
            Section("Menu bar date format") {
                Picker("Format", selection: $settings.menuBarDateFormat) {
                    ForEach(MenuBarDateFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle("Show next-event indicator dot", isOn: $settings.showNextEventDot)
            }
        }
    }
}
