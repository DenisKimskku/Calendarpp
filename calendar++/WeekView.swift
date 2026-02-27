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
    @Environment(\.calendarPPPresentationContext) private var presentationContext

    let weekStartDate: Date
    let maxHeight: CGFloat?
    @Binding var inspectedEvent: EventSummary?
    @State private var popoverEvent: EventSummary?

    private let calendar = Calendar.current

    init(weekStartDate: Date, maxHeight: CGFloat? = 200, inspectedEvent: Binding<EventSummary?> = .constant(nil)) {
        self.weekStartDate = weekStartDate
        self.maxHeight = maxHeight
        self._inspectedEvent = inspectedEvent
    }

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
                .overlay(CalendarPPZenStyle.stroke)

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

                            Text("Nothing scheduled")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(events) { event in
                            WeekEventRow(
                                event: event,
                                isSelected: inspectedEvent?.id == event.id,
                                onSelect: {
                                    if presentationContext == .menuBar {
                                        popoverEvent = event
                                    } else {
                                        inspectedEvent = event
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .applyWeekMaxHeight(maxHeight)
            .popover(item: $popoverEvent) { event in
                EventDetailPopover(event: event)
            }
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

private extension View {
    @ViewBuilder
    func applyWeekMaxHeight(_ maxHeight: CGFloat?) -> some View {
        if let maxHeight {
            self.frame(maxHeight: maxHeight)
        } else {
            self
        }
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
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isToday ? Color.accentColor : .secondary)

                Text("\(dayOfMonth)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 34, height: 24)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.10) : Color.clear))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(!isSelected && isToday ? Color.accentColor.opacity(0.9) : Color.clear, lineWidth: 1.5)
                            )
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
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color(event.calendarColor))
                    .frame(width: 3)
                    .cornerRadius(1.5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(eventTimeText)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    Text(event.title)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .calendarPPZenCard(cornerRadius: 10, strong: false)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            EventContextMenu(event: event)
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
