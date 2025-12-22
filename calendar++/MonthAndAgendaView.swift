import SwiftUI

struct MonthAndAgendaView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel

    @State private var showWeekView = false

    private let columns = Array(repeating: GridItem(.flexible(minimum: 24, maximum: 40)), count: 7)
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
        VStack(spacing: 8) {
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
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Month grid
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(calendarVM.daysForCurrentMonth(firstWeekdayIsMonday: settings.firstWeekdayIsMonday), id: \.self) { date in
                            DayCellView(
                                date: date,
                                isInCurrentMonth: calendarVM.isInCurrentMonth(date),
                                isSelected: calendarVM.isSameDay(date, calendarVM.selectedDate),
                                hasEvents: !eventKit.events(on: date).isEmpty
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
    }

    private var startOfWeek: Date {
        var cal = calendar
        cal.firstWeekday = settings.firstWeekdayIsMonday ? 2 : 1

        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: calendarVM.selectedDate)
        return cal.date(from: components) ?? calendarVM.selectedDate
    }
}
