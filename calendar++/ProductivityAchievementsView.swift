//
//  ProductivityAchievementsView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct ProductivityAchievementsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.calendarPPPresentationContext) private var presentationContext
    @EnvironmentObject var achievementsManager: ProductivityAchievementsManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Close button header
            HStack {
                Text("Achievements")
                    .font(.system(size: 22, weight: .bold))

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

        ScrollView {
            VStack(spacing: 20) {
                headerSection
                profileCard
                streaksSection
                achievementsList
            }
            .padding()
        }
        }
        .frame(
            maxWidth: presentationContext == .menuBar ? nil : .infinity,
            maxHeight: presentationContext == .menuBar ? nil : .infinity,
            alignment: .topLeading
        )
        .frame(
            width: presentationContext == .menuBar ? 700 : nil,
            height: presentationContext == .menuBar ? 700 : nil
        )
        .onAppear {
            refreshProgress()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshProgress()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshProgress()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshProgress()
        }
    }

    private func refreshProgress() {
        guard eventKitManager.hasCalendarAccess else { return }
        achievementsManager.refreshComputedProgress(events: visibleEvents)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievements")
                    .font(.system(size: 24, weight: .bold))
                Text("Level up your calendar game")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.bottom, 10)
    }

    private var profileCard: some View {
        HStack(spacing: 20) {
            // Level badge
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                VStack(spacing: 2) {
                    Text("Level")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(achievementsManager.level)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(achievementsManager.totalPoints)")
                        .font(.system(size: 24, weight: .bold))
                    Text("points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("\(achievementsManager.getUnlockedCount())/\(achievementsManager.getTotalCount()) achievements unlocked")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Progress to next level
                let pointsToNext = (achievementsManager.level * 500) - achievementsManager.totalPoints
                if pointsToNext > 0 {
                    Text("\(pointsToNext) points to Level \(achievementsManager.level + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(achievementsManager.streaks, id: \.streakType.rawValue) { streak in
                    StreakCard(streak: streak)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var achievementsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.headline)

            ForEach(Achievement.Category.allCases, id: \.rawValue) { category in
                CategorySection(
                    category: category,
                    achievements: achievementsManager.achievements.filter { $0.category == category }
                )
            }
        }
    }
}

struct StreakCard: View {
    let streak: ProductivityStreak

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text(streak.streakType.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Text("\(streak.currentStreak)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.orange)

            Text("Best: \(streak.longestStreak) days")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct CategorySection: View {
    let category: Achievement.Category
    let achievements: [Achievement]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)

                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ForEach(achievements) { achievement in
                AchievementCard(achievement: achievement)
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.category.color : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)

                Image(systemName: achievement.icon)
                    .foregroundColor(achievement.isUnlocked ? .white : .secondary)
                    .font(.title3)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Progress bar
                if !achievement.isUnlocked {
                    VStack(alignment: .leading, spacing: 2) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(achievement.category.color)
                                    .frame(width: geometry.size.width * (achievement.progressPercentage / 100))
                            }
                        }
                        .frame(height: 4)

                        Text("\(achievement.progress)/\(achievement.requirement)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if let unlockedDate = achievement.unlockedDate {
                    Text("Unlocked \(formatDate(unlockedDate))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Checkmark
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(achievement.isUnlocked ? achievement.category.color.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(achievement.isUnlocked ? achievement.category.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ProductivityAchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        ProductivityAchievementsView()
            .environmentObject(ProductivityAchievementsManager())
            .environmentObject(EventKitManager())
            .environmentObject(CalendarFilterManager())
    }
}
