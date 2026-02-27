import SwiftUI
import AppKit

private enum FeaturesHubRoute: Hashable {
    case timeAnalytics
    case focusProtection
    case dailyBriefing
    case bufferTime
    case energyScheduling
    case meetingCost
    case availability
    case meetingPrep
    case inbox
    case commands
    case achievements
    case aiAssistant
}

struct FeaturesHubView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.openWindow) private var openWindow

    @State private var path: [FeaturesHubRoute] = []

    private var hasAnyFeaturesEnabled: Bool {
        settings.enableTimeAnalytics ||
            settings.enableMeetingPrep ||
            settings.enableFocusProtection ||
            settings.enableDailyBriefing ||
            settings.enableSmartBuffer ||
            settings.enableEnergyScheduling ||
            settings.enableMeetingCost ||
            settings.enableAvailabilitySharing ||
            (settings.isPhase7Visible && (
                settings.enableCalendarInbox ||
                    settings.enableNaturalLanguageCommands ||
                    settings.enableAchievements
            )) ||
            (settings.isPhase8Visible && settings.enableAIAssistant)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(settings.showExperimentalFeatures
                         ? "Explore advanced capabilities across Phase 6 to Phase 8."
                         : "Core features are available here. Enable advanced mode in Settings to unlock Phase 7 and 8.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                        if settings.enableTimeAnalytics {
                            FeatureCard(
                                icon: "chart.bar.fill",
                                title: "Time Analytics",
                                description: "See where your time goes",
                                color: .blue,
                                badge: "Phase 6"
                            ) { path.append(.timeAnalytics) }
                        }

                        if settings.enableFocusProtection {
                            FeatureCard(
                                icon: "shield.fill",
                                title: "Focus Protection",
                                description: "Defend your deep work time",
                                color: .green,
                                badge: "Phase 6"
                            ) { path.append(.focusProtection) }
                        }

                        if settings.enableDailyBriefing {
                            FeatureCard(
                                icon: "sunrise.fill",
                                title: "Daily Briefing",
                                description: "Start your day informed",
                                color: .orange,
                                badge: "Phase 6"
                            ) { path.append(.dailyBriefing) }
                        }

                        if settings.enableSmartBuffer {
                            FeatureCard(
                                icon: "hourglass",
                                title: "Buffer Time",
                                description: "Prevent meeting burnout",
                                color: .purple,
                                badge: "Phase 6"
                            ) { path.append(.bufferTime) }
                        }

                        if settings.enableEnergyScheduling {
                            FeatureCard(
                                icon: "bolt.fill",
                                title: "Energy Scheduling",
                                description: "Schedule at peak times",
                                color: .yellow,
                                badge: "Phase 6"
                            ) { path.append(.energyScheduling) }
                        }

                        if settings.enableMeetingCost {
                            FeatureCard(
                                icon: "dollarsign.circle.fill",
                                title: "Meeting Costs",
                                description: "See the true cost",
                                color: .green,
                                badge: "Phase 6"
                            ) { path.append(.meetingCost) }
                        }

                        if settings.enableAvailabilitySharing {
                            FeatureCard(
                                icon: "link.circle.fill",
                                title: "Availability Links",
                                description: "Share booking links",
                                color: .blue,
                                badge: "Phase 6"
                            ) { path.append(.availability) }
                        }

                        if settings.enableMeetingPrep {
                            FeatureCard(
                                icon: "doc.text.fill",
                                title: "Meeting Prep",
                                description: "Never unprepared",
                                color: .indigo,
                                badge: "Phase 6"
                            ) { path.append(.meetingPrep) }
                        }

                        if settings.isPhase7Visible {
                            if settings.enableCalendarInbox {
                                FeatureCard(
                                    icon: "tray.fill",
                                    title: "Calendar Inbox",
                                    description: "Review invites and jump to Calendar.app",
                                    color: .red,
                                    badge: "Phase 7"
                                ) { path.append(.inbox) }
                            }

                            if settings.enableNaturalLanguageCommands {
                                FeatureCard(
                                    icon: "waveform.and.mic",
                                    title: "Natural Language",
                                    description: "Control your calendar with plain English",
                                    color: .teal,
                                    badge: "Phase 7"
                                ) { path.append(.commands) }
                            }

                            if settings.enableAchievements {
                                FeatureCard(
                                    icon: "trophy.fill",
                                    title: "Achievements",
                                    description: "Track streaks and productivity milestones",
                                    color: .orange,
                                    badge: "Phase 7"
                                ) { path.append(.achievements) }
                            }
                        }

                        if settings.isPhase8Visible {
                            if settings.enableAIAssistant {
                                FeatureCard(
                                    icon: "brain.head.profile",
                                    title: "Planning Assistant",
                                    description: "Scheduling, categorization, conflicts, and buffer strategy",
                                    color: .indigo,
                                    badge: "Phase 8"
                                ) { path.append(.aiAssistant) }
                            }
                        }
                    }

                    if !hasAnyFeaturesEnabled {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 52))
                                .foregroundColor(.secondary)

                            Text("No Features Enabled")
                                .font(.title3.weight(.semibold))

                            Text("Enable features in Settings to see them here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button("Open Settings") {
                                openWindow(id: "settings")
                                NSApp.activate(ignoringOtherApps: true)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Features")
            .navigationDestination(for: FeaturesHubRoute.self) { route in
                switch route {
                case .timeAnalytics:
                    TimeAnalyticsDashboardView()
                case .focusProtection:
                    FocusTimeProtectionView()
                case .dailyBriefing:
                    DailyBriefingView()
                case .bufferTime:
                    SmartBufferTimeView()
                case .energyScheduling:
                    EnergyAwareSchedulingView()
                case .meetingCost:
                    MeetingCostView()
                case .availability:
                    AvailabilitySharingView()
                case .meetingPrep:
                    MeetingPrepDashboardView()
                case .inbox:
                    CalendarInboxView()
                case .commands:
                    NaturalLanguageCommandsView()
                case .achievements:
                    ProductivityAchievementsView()
                case .aiAssistant:
                    AIAssistantDashboard()
                }
            }
        }
    }
}
