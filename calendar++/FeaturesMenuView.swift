//
//  FeaturesMenuView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI
import AppKit

private enum FeatureRoute: Hashable {
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

struct FeaturesMenuView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var settings: SettingsViewModel

    @State private var path: [FeatureRoute] = []

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
            rootView
                .frame(width: 700, height: 600)
                .navigationDestination(for: FeatureRoute.self) { route in
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

    private var rootView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("calendar++ Features")
                        .font(.system(size: 22, weight: .bold))
                    Text(settings.showExperimentalFeatures
                         ? "Advanced calendar intelligence"
                         : "Core features only. Enable advanced mode in Settings for Phase 7/8.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Features Grid
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Core features")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    if !settings.showExperimentalFeatures {
                        Text("Experimental Phase 7/8 features are hidden. Enable advanced mode in Settings when needed.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                    // Phase 6 Features
                    if settings.enableTimeAnalytics {
                        FeatureCard(
                            icon: "chart.bar.fill",
                            title: "Time Analytics",
                            description: "See where your time goes",
                            color: .blue,
                            badge: "Phase 6"
                        ) {
                            path.append(.timeAnalytics)
                        }
                    }

                    if settings.enableFocusProtection {
                        FeatureCard(
                            icon: "shield.fill",
                            title: "Focus Protection",
                            description: "Defend your deep work time",
                            color: .green,
                            badge: "Phase 6"
                        ) {
                            path.append(.focusProtection)
                        }
                    }

                    if settings.enableDailyBriefing {
                        FeatureCard(
                            icon: "sunrise.fill",
                            title: "Daily Briefing",
                            description: "Start your day informed",
                            color: .orange,
                            badge: "Phase 6"
                        ) {
                            path.append(.dailyBriefing)
                        }
                    }

                    if settings.enableSmartBuffer {
                        FeatureCard(
                            icon: "hourglass",
                            title: "Buffer Time",
                            description: "Prevent meeting burnout",
                            color: .purple,
                            badge: "Phase 6"
                        ) {
                            path.append(.bufferTime)
                        }
                    }

                    if settings.enableEnergyScheduling {
                        FeatureCard(
                            icon: "bolt.fill",
                            title: "Energy Scheduling",
                            description: "Schedule at peak times",
                            color: .yellow,
                            badge: "Phase 6"
                        ) {
                            path.append(.energyScheduling)
                        }
                    }

                    if settings.enableMeetingCost {
                        FeatureCard(
                            icon: "dollarsign.circle.fill",
                            title: "Meeting Costs",
                            description: "See the true cost",
                            color: .green,
                            badge: "Phase 6"
                        ) {
                            path.append(.meetingCost)
                        }
                    }

                    if settings.enableAvailabilitySharing {
                        FeatureCard(
                            icon: "link.circle.fill",
                            title: "Availability Links",
                            description: "Share booking links",
                            color: .blue,
                            badge: "Phase 6"
                        ) {
                            path.append(.availability)
                        }
                    }

                    if settings.enableMeetingPrep {
                        FeatureCard(
                            icon: "doc.text.fill",
                            title: "Meeting Prep",
                            description: "Never unprepared",
                            color: .indigo,
                            badge: "Phase 6"
                        ) {
                            path.append(.meetingPrep)
                        }
                    }

                    if settings.isPhase7Visible {
                        // Phase 7 Features
                        if settings.enableCalendarInbox {
                            FeatureCard(
                                icon: "tray.fill",
                                title: "Calendar Inbox",
                                description: "Review invites and jump to Calendar.app",
                                color: .red,
                                badge: "Phase 7"
                            ) {
                                path.append(.inbox)
                            }
                        }

                        if settings.enableNaturalLanguageCommands {
                            FeatureCard(
                                icon: "waveform.and.mic",
                                title: "Natural Language",
                                description: "Control your calendar with plain English",
                                color: .teal,
                                badge: "Phase 7"
                            ) {
                                path.append(.commands)
                            }
                        }

                        if settings.enableAchievements {
                            FeatureCard(
                                icon: "trophy.fill",
                                title: "Achievements",
                                description: "Track streaks and productivity milestones",
                                color: .orange,
                                badge: "Phase 7"
                            ) {
                                path.append(.achievements)
                            }
                        }
                    }

                    if settings.isPhase8Visible {
                        // Phase 8 Features (AI/ML)
                        if settings.enableAIAssistant {
                            FeatureCard(
                                icon: "brain.head.profile",
                                title: "Planning Assistant",
                                description: "Scheduling, categorization, conflicts, and buffer strategy",
                                color: .indigo,
                                badge: "Phase 8"
                            ) {
                                path.append(.aiAssistant)
                            }
                        }
                    }
                }
                }
                .padding()

                // Empty state when no features enabled
                if !hasAnyFeaturesEnabled {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Features Enabled")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Enable features in Settings to see them here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Open Settings") {
                            openWindow(id: "settings")
                            NSApp.activate(ignoringOtherApps: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                NSApp.activate(ignoringOtherApps: true)
                            }
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                }
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let badge: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(description)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Text(badge)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.35))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(CalendarPPZenStyle.stroke, lineWidth: 1)
                                )
                        )
                }
            }
            .padding(14)
            .frame(height: 110)
            .calendarPPZenCard(cornerRadius: 14, strong: false, hovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct FeaturesMenuView_Previews: PreviewProvider {
    static var previews: some View {
        FeaturesMenuView()
            .environmentObject(TimeAnalyticsManager())
            .environmentObject(FocusTimeProtectionManager())
            .environmentObject(DailyBriefingManager())
            .environmentObject(SmartBufferTimeManager())
            .environmentObject(MeetingCostCalculator())
            .environmentObject(AvailabilitySharingManager())
            .environmentObject(CalendarInboxManager())
            .environmentObject(NaturalLanguageCommandsManager())
            .environmentObject(ProductivityAchievementsManager())
            .environmentObject(EventKitManager())
    }
}
