//
//  OpenCalendarChoiceDialog.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI
import AppKit

struct OpenCalendarChoiceDialog: View {
    @Environment(\.dismiss) var dismiss
    let event: EventSummary?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Open Calendar")
                        .font(.headline)
                    if let event = event {
                        Text("Open '\(event.title)'")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Choose which calendar to open")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Options
            VStack(spacing: 12) {
                ChoiceButton(
                    icon: "apple.logo",
                    title: "Native Calendar",
                    description: "Open in macOS Calendar app",
                    color: .blue,
                    action: {
                        openNativeCalendar()
                        dismiss()
                    }
                )

                ChoiceButton(
                    icon: "sparkles",
                    title: "calendar++ Features",
                    description: "Use calendar++ advanced features",
                    color: .purple,
                    action: {
                        openCalendarPlusPlus()
                        dismiss()
                    }
                )
            }

            // Cancel
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .frame(width: 400)
    }

    private func openNativeCalendar() {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else if let url = URL(string: "/System/Applications/Calendar.app"), FileManager.default.fileExists(atPath: url.path) {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else if let url = URL(string: "/Applications/Calendar.app"), FileManager.default.fileExists(atPath: url.path) {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        }
    }

    private func openCalendarPlusPlus() {
        // Post notification to show features menu
        NotificationCenter.default.post(name: .showFeaturesMenu, object: nil)
    }
}

struct ChoiceButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? color.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// Notification extension
extension Notification.Name {
    static let showFeaturesMenu = Notification.Name("showFeaturesMenu")
}

struct OpenCalendarChoiceDialog_Previews: PreviewProvider {
    static var previews: some View {
        OpenCalendarChoiceDialog(event: nil)
    }
}
