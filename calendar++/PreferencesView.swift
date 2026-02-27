import SwiftUI
import AppKit

struct PreferencesView: View {
    private enum SettingsSection: String, CaseIterable, Identifiable {
        case general
        case appearance
        case calendars
        case integrations
        case advanced

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return "General"
            case .appearance: return "Appearance"
            case .calendars: return "Calendars"
            case .integrations: return "Integrations"
            case .advanced: return "Advanced"
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .calendars: return "calendar"
            case .integrations: return "link"
            case .advanced: return "slider.horizontal.3"
            }
        }

        var subtitle: String {
            switch self {
            case .general:
                return "Startup preferences and app basics."
            case .appearance:
                return "Theme, layout density, and icon style."
            case .calendars:
                return "Week start, reminders, and agenda behavior."
            case .integrations:
                return "Connect external calendar providers."
            case .advanced:
                return "Phase 6-8 feature flags and experiments."
            }
        }
    }

    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    @State private var startAtLoginAlert: StartAtLoginAlert?
    @State private var isApplyingStartAtLogin = false
    @State private var selectedSection: SettingsSection? = .general

    private struct StartAtLoginAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        ZStack {
            CalendarPPZenBackground()

            HStack(spacing: 14) {
                settingsSidebar

                VStack(alignment: .leading, spacing: 0) {
                    settingsSectionHeader(for: currentSection)

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 2)

                    sectionContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .calendarPPZenCard(cornerRadius: 14, strong: false)
            }
            .padding(16)
            .calendarPPZenCard(cornerRadius: 18, strong: true)
            .padding(16)
        }
        .frame(minWidth: 760, minHeight: 560)
        .tint(settings.resolvedTintColor)
        .accentColor(settings.resolvedTintColor)
        .alert(item: $startAtLoginAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // Ensure the settings window becomes active so section changes respond immediately.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var currentSection: SettingsSection {
        selectedSection ?? .general
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch currentSection {
        case .general:
            generalTab
        case .appearance:
            appearanceTab
        case .calendars:
            calendarsTab
        case .integrations:
            integrationsTab
        case .advanced:
            advancedTab
        }
    }

    private func settingsSectionHeader(for section: SettingsSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
                .font(.system(size: 21, weight: .bold, design: .rounded))

            Text(section.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var settingsSidebar: some View {
        List(SettingsSection.allCases, selection: $selectedSection) { section in
            Label(section.title, systemImage: section.systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tag(Optional(section))
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: 220, alignment: .topLeading)
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }

    private var appearanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.headline)

                    Text("Choose a minimal accent and tune the background intensity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                        ForEach(UIAccentChoice.allCases) { choice in
                            AccentChoiceButton(
                                title: choice.displayName,
                                tint: choice.tintColor,
                                isSelected: settings.uiAccentChoice == choice.rawValue
                            ) {
                                settings.uiAccentChoice = choice.rawValue
                            }
                        }
                    }

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    HStack(spacing: 12) {
                        Text("Background intensity")
                            .font(.subheadline)

                        Slider(value: $settings.uiBackgroundIntensity, in: 0...1, step: 0.05)

                        Text("\(Int(settings.uiBackgroundIntensity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Layout")
                        .font(.headline)

                    Toggle("Hide sidebar", isOn: $settings.uiSidebarHidden)
                    Toggle("Show mini month in sidebar", isOn: $settings.uiSidebarShowsMiniMonth)

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Inspector panel")
                            .font(.subheadline.bold())

                        Picker("Inspector panel", selection: $settings.uiInspectorMode) {
                            ForEach(UIInspectorMode.allCases) { mode in
                                Text(mode.displayName).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        Text((UIInspectorMode(rawValue: settings.uiInspectorMode) ?? .auto).helpText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    HStack {
                        Spacer()
                        Button("Reset Appearance") {
                            settings.resetAppearanceToDefaults()
                        }
                    }
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)

                VStack(alignment: .leading, spacing: 12) {
                    Text("App Icon")
                        .font(.headline)

                    Toggle("Use dynamic date icon in Dock", isOn: $settings.dynamicDockIconEnabled)

                    Toggle("Match icon color to selected accent", isOn: $settings.dynamicDockIconUseAccent)
                        .disabled(!settings.dynamicDockIconEnabled)

                    Text("When disabled, calendar++ uses the bundled static icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Refresh Icon Now") {
                            DynamicAppIconManager.shared.refreshNow()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!settings.dynamicDockIconEnabled)

                        Spacer(minLength: 0)
                    }
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Menu Bar")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date format")
                            .font(.subheadline.bold())

                        Picker("Format", selection: $settings.menuBarDateFormat) {
                            ForEach(MenuBarDateFormat.allCases) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    Toggle("Show next-event indicator dot", isOn: $settings.showNextEventDot)
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Startup")
                        .font(.headline)

                    Toggle("Start calendar++ at login", isOn: $settings.startAtLogin)
                        .onChange(of: settings.startAtLogin) { newValue in
                            // Avoid looping when we revert the toggle after a failure.
                            guard !isApplyingStartAtLogin else { return }
                            isApplyingStartAtLogin = true
                            defer { isApplyingStartAtLogin = false }

                            do {
                                try StartAtLoginManager.setEnabled(newValue)
                                if newValue, StartAtLoginManager.needsUserApproval() {
                                    startAtLoginAlert = StartAtLoginAlert(
                                        title: "Approval Required",
                                        message: "macOS requires approval for Start at Login. Open System Settings > General > Login Items and enable calendar++."
                                    )
                                }
                            } catch {
                                // Revert the toggle and surface the error.
                                settings.startAtLogin = !newValue
                                startAtLoginAlert = StartAtLoginAlert(
                                    title: "Could Not Update Start at Login",
                                    message: error.localizedDescription
                                )
                            }
                        }

                    Text("Start at Login requires calendar++ installed in the Applications folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)

                VStack(alignment: .leading, spacing: 10) {
                    Text("About this app")
                        .font(.headline)

                    Text("calendar++ prioritizes a calm, minimal workflow. Use Appearance and Calendars to shape how much information you see.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
    }

    private var calendarsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Calendar Behavior")
                        .font(.headline)

                    Toggle("Week starts on Monday", isOn: $settings.firstWeekdayIsMonday)
                    Toggle("Show reminders in agenda", isOn: $settings.showRemindersInAgenda)

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default agenda range")
                            .font(.subheadline.bold())

                        Picker("Agenda range", selection: $settings.agendaRange) {
                            ForEach(AgendaRange.allCases) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Calendar Visibility")
                        .font(.headline)

                    Text("Use the calendar filter from the sidebar or menu bar to quickly show or hide specific calendars.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .calendarPPZenCard(cornerRadius: 14, strong: false)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
    }

    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Phase 6 Features
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.accentColor)
                            Text("Phase 6: Calendar Intelligence")
                                .font(.headline)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            FeatureToggle(
                                isOn: $settings.enableTimeAnalytics,
                                title: "Time Analytics",
                                description: "Track where your time goes with weekly insights"
                            )

                            FeatureToggle(
                                isOn: $settings.enableMeetingPrep,
                                title: "Meeting Prep Cards",
                                description: "Get notified before meetings with prep info"
                            )

                            FeatureToggle(
                                isOn: $settings.enableFocusProtection,
                                title: "Focus Time Protection",
                                description: "Block time for deep work and prevent conflicts"
                            )

                            FeatureToggle(
                                isOn: $settings.enableDailyBriefing,
                                title: "Daily Briefing",
                                description: "Morning summary of your day ahead"
                            )

                            FeatureToggle(
                                isOn: $settings.enableSmartBuffer,
                                title: "Smart Buffer Time",
                                description: "Automatic suggestions for gaps between meetings"
                            )

                            FeatureToggle(
                                isOn: $settings.enableEnergyScheduling,
                                title: "Energy-Aware Scheduling",
                                description: "Schedule based on your peak performance times"
                            )

                            FeatureToggle(
                                isOn: $settings.enableMeetingCost,
                                title: "Meeting Cost Calculator",
                                description: "See the true cost of your meetings"
                            )

                            FeatureToggle(
                                isOn: $settings.enableAvailabilitySharing,
                                title: "Availability Sharing",
                                description: "Share booking links like Calendly"
                            )
                        }
                    }
                    .padding()
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show advanced features (Phase 7 / 8)", isOn: $settings.showExperimentalFeatures)

                        Text("Turn this off if you want to focus on the core Phase 6 workflow only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                if settings.isPhase7Visible {
                    // Phase 7 Features
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text("Phase 7: Automation & Gamification")
                                    .font(.headline)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 10) {
                                FeatureToggle(
                                    isOn: $settings.enableCalendarInbox,
                                    title: "Calendar Inbox",
                                    description: "Review invites and open Calendar.app for final responses"
                                )

                                FeatureToggle(
                                    isOn: $settings.enableNaturalLanguageCommands,
                                    title: "Natural Language Commands",
                                    description: "Use plain English to move, cancel, and block events"
                                )

                                FeatureToggle(
                                    isOn: $settings.enableAchievements,
                                    title: "Achievements & Streaks",
                                    description: "Track calendar habits and productivity milestones"
                                )
                            }
                        }
                        .padding()
                    }
                }

                if settings.isPhase8Visible {
                    // Phase 8 Features (AI/ML)
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(Color.accentColor)
                                Text("Phase 8: AI/ML Intelligence")
                                    .font(.headline)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 10) {
                                FeatureToggle(
                                    isOn: $settings.enableAIAssistant,
                                    title: "Planning Assistant",
                                    description: "Unified workspace for scheduling, categorization, conflicts, and buffers"
                                )

                                FeatureToggle(
                                    isOn: $settings.enableSmartScheduling,
                                    title: "Smart Scheduling AI",
                                    description: "ML-powered optimal meeting time suggestions"
                                )

                                FeatureToggle(
                                    isOn: $settings.enableAutoCategorization,
                                    title: "Auto-Categorization",
                                    description: "Automatically classify events by type with confidence scores"
                                )

                                FeatureToggle(
                                    isOn: $settings.enableConflictPrediction,
                                    title: "Conflict Prediction",
                                    description: "Predict and prevent scheduling conflicts"
                                )
                            }
                        }
                        .padding()
                    }
                }

                Text("Enable features to access them from the Features menu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
    }

    private var integrationsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GoogleCalendarSettingsView()
                    .environmentObject(googleCalendar)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Feature Toggle Component

struct FeatureToggle: View {
    @Binding var isOn: Bool
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isOn)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

private struct AccentChoiceButton: View {
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.12 : 0.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.35) : CalendarPPZenStyle.stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
