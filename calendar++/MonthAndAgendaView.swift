import SwiftUI

struct MonthAndAgendaView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel

    private let columns = Array(repeating: GridItem(.flexible(minimum: 24, maximum: 40)), count: 7)

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
