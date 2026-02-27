//
//  CalendarFilterView.swift
//  calendar++
//
//  UI for managing calendar visibility
//

import SwiftUI
import EventKit

struct CalendarFilterView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    @Environment(\.dismiss) var dismiss

    private let googleCalendarId = "google-primary"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Calendar Visibility")
                    .font(.headline)

                Spacer()

                Button {
                    filterManager.showAllCalendars()
                } label: {
                    Text("Show All")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(filterManager.hiddenCalendarIds.isEmpty)
            }

            Divider()

            // Calendar list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // macOS Calendars
                    if !availableCalendars.isEmpty {
                        Text("macOS Calendars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                            CalendarToggleRow(
                                title: calendar.title,
                                color: Color(calendar.color),
                                isVisible: filterManager.isCalendarVisible(calendarId: calendar.calendarIdentifier, calendarName: calendar.title),
                                onToggle: {
                                    filterManager.toggleCalendar(calendarId: calendar.calendarIdentifier, calendarName: calendar.title)
                                }
                            )
                        }

                        Divider()
                            .padding(.vertical, 4)
                    }

                    // Google Calendar
                    if googleCalendar.isAuthenticated {
                        Text("Google Calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        CalendarToggleRow(
                            title: "Google Calendar",
                            color: .blue,
                            isVisible: filterManager.isCalendarVisible(calendarId: googleCalendarId, calendarName: "Google Calendar"),
                            onToggle: {
                                filterManager.toggleCalendar(calendarId: googleCalendarId, calendarName: "Google Calendar")
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)

            Spacer()

            // Footer
            HStack {
                Text("\(visibleCalendarCount) of \(totalCalendarCount) calendars visible")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 400)
    }

    private var availableCalendars: [EKCalendar] {
        eventKit.calendars()
    }

    private var totalCalendarCount: Int {
        var count = availableCalendars.count
        if googleCalendar.isAuthenticated {
            count += 1
        }
        return count
    }

    private var visibleCalendarCount: Int {
        var count = availableCalendars.filter {
            filterManager.isCalendarVisible(calendarId: $0.calendarIdentifier, calendarName: $0.title)
        }.count
        if googleCalendar.isAuthenticated && filterManager.isCalendarVisible(calendarId: googleCalendarId, calendarName: "Google Calendar") {
            count += 1
        }
        return count
    }
}

// MARK: - Calendar Toggle Row

struct CalendarToggleRow: View {
    let title: String
    let color: Color
    let isVisible: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isVisible ? .accentColor : .secondary)
                    .font(.body)

                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isVisible ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isVisible ? Color.accentColor.opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
