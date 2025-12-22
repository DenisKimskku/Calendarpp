//
//  WelcomeView.swift
//  calendar++
//
//  Welcome screen shown on first launch
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var eventKit: EventKitManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 40)

                Text("Welcome to Calendar++")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your smart menu bar calendar for macOS")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)

            // Feature list
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(
                        icon: "calendar",
                        title: "Unified Calendar",
                        description: "View events from macOS Calendar and Google Calendar in one place"
                    )

                    FeatureRow(
                        icon: "cloud",
                        title: "Google Calendar Sync",
                        description: "Optional: Connect your Google account for seamless synchronization"
                    )

                    FeatureRow(
                        icon: "keyboard",
                        title: "Keyboard Shortcuts",
                        description: "⌘N for new event, ⌘T for today, ⌘R to refresh"
                    )

                    FeatureRow(
                        icon: "hand.tap",
                        title: "Quick Actions",
                        description: "Right-click events for quick actions like copy, delete, or join meetings"
                    )

                    FeatureRow(
                        icon: "lock.shield",
                        title: "Privacy First",
                        description: "All data stays on your device. OAuth tokens stored securely in macOS Keychain"
                    )

                    Divider()
                        .padding(.vertical, 10)

                    // Permissions explanation
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .foregroundColor(.green)
                            Text("Required Permission")
                                .font(.headline)
                        }

                        Text("Calendar++ needs access to your Calendar to display and manage events. You'll be prompted to grant this permission.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 30)
            }

            // Bottom button
            Button {
                eventKit.requestAccessIfNeeded()
                markWelcomeAsSeen()
                isPresented = false
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(width: 500, height: 600)
    }

    private func markWelcomeAsSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
