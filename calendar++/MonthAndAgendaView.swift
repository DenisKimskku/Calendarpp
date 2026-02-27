import SwiftUI

struct MonthAndAgendaView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var googleCalendar: GoogleCalendarManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var reminders: ReminderManager

    @State private var showWeekView = false

    private let columns = Array(repeating: GridItem(.flexible(minimum: 26, maximum: 44)), count: 7)
    private let calendar = Calendar.current

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.firstWeekday = settings.firstWeekdayIsMonday ? 2 : 1
        let symbols = calendar.veryShortWeekdaySymbols

        // rotate based on first weekday
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    var body: some View {
        VStack(spacing: 10) {
            // View toggle
            HStack {
                Spacer()

                Picker("View", selection: $showWeekView) {
                    Text("Month").tag(false)
                    Text("Week").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }
            .padding(.horizontal, 4)

            if showWeekView {
                // Week view
                WeekView(weekStartDate: startOfWeek)
            } else {
                // Month view
                VStack(spacing: 8) {
                    // Weekday header
                    HStack {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Month grid
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(calendarVM.daysForCurrentMonth(firstWeekdayIsMonday: settings.firstWeekdayIsMonday), id: \.self) { date in
                            let hasReminders = settings.showRemindersInAgenda && !reminders.reminders(on: date).isEmpty
                            let visibleEvents = filterManager.filterEvents(eventKit.events(on: date))
                            DayCellView(
                                date: date,
                                isInCurrentMonth: calendarVM.isInCurrentMonth(date),
                                isSelected: calendarVM.isSameDay(date, calendarVM.selectedDate),
                                hasEvents: hasReminders || !visibleEvents.isEmpty
                            )
                            .onTapGesture {
                                calendarVM.selectedDate = date
                            }
                        }
                    }

                    // Agenda
                    AgendaListView(date: calendarVM.selectedDate)
                }
            }
        }
        .onAppear {
            eventKit.reloadAllEvents(around: calendarVM.currentMonth)
            googleCalendar.refreshEventsIfNeeded(around: calendarVM.currentMonth, force: false)
            refreshReminders()
        }
        .onChange(of: calendarVM.currentMonth) { newMonth in
            eventKit.reloadAllEvents(around: newMonth)
            googleCalendar.refreshEventsIfNeeded(around: newMonth, force: false)
            refreshReminders()
        }
        .onChange(of: settings.showRemindersInAgenda) { _ in
            refreshReminders()
        }
    }

    private func refreshReminders() {
        guard settings.showRemindersInAgenda else { return }

        reminders.requestAccessIfNeeded()
        reminders.reloadReminders(range: remindersRange(around: calendarVM.currentMonth))
    }

    private func remindersRange(around anchorDate: Date) -> DateInterval {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate))
            ?? calendar.startOfDay(for: anchorDate)

        let start = calendar.date(byAdding: .day, value: -14, to: startOfMonth) ?? startOfMonth
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? anchorDate
        let end = calendar.date(byAdding: .day, value: 14, to: endOfMonth) ?? endOfMonth

        return DateInterval(start: start, end: end)
    }

    private var startOfWeek: Date {
        var cal = calendar
        cal.firstWeekday = settings.firstWeekdayIsMonday ? 2 : 1

        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: calendarVM.selectedDate)
        return cal.date(from: components) ?? calendarVM.selectedDate
    }
}
