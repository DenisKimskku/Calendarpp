//
//  WeekView.swift
//  calendar++
//
//  Week-at-a-glance view showing 7 days with events
//

import SwiftUI

struct WeekView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var calendarVM: CalendarViewModel

    let weekStartDate: Date

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Week header with dates
            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { day in
                    WeekDayHeader(
                        date: day,
                        isSelected: calendar.isDate(day, inSameDayAs: calendarVM.selectedDate),
                        onTap: {
                            calendarVM.selectedDate = day
                        }
                    )
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Events list for selected day
            ScrollView {
                VStack(spacing: 8) {
                    let allEvents = eventKit.events(on: calendarVM.selectedDate)
                    let events = filterManager.filterEvents(allEvents)

                    if events.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)

                            Text("No events")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(events) { event in
                            WeekEventRow(event: event)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private var weekDays: [Date] {
        var days: [Date] = []
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: weekStartDate) {
                days.append(day)
            }
        }
        return days
    }
}

// MARK: - Week Day Header

struct WeekDayHeader: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 4) {
                Text(dayOfWeek)
                    .font(.caption2)
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)

                Text("\(dayOfMonth)")
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : (isToday ? .accentColor : .primary))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.1) : Color.clear))
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private var dayOfMonth: Int {
        calendar.component(.day, from: date)
    }

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
}

// MARK: - Week Event Row

struct WeekEventRow: View {
    let event: EventSummary
    @State private var selectedEvent: EventSummary?

    var body: some View {
        Button {
            selectedEvent = event
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 3)
                    .cornerRadius(1.5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(eventTimeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    Text(event.title)
                        .font(.caption)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contextMenu {
            EventContextMenu(event: event)
        }
        .popover(item: $selectedEvent) { event in
            EventDetailPopover(event: event)
        }
    }

    private var eventTimeText: String {
        if event.isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) – \(end)"
    }
}
