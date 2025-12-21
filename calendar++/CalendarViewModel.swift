import Foundation
import SwiftUI
import Combine
import Combine

final class CalendarViewModel: ObservableObject {
    @Published var currentMonth: Date
    @Published var selectedDate: Date

    private let calendar = Calendar.current

    init() {
        let now = Date()
        self.currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        self.selectedDate = now
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentMonth)
    }

    func goToToday() {
        let now = Date()
        selectedDate = now
        currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    }

    func changeMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    func daysForCurrentMonth(firstWeekdayIsMonday: Bool) -> [Date] {
        var calendar = self.calendar
        calendar.firstWeekday = firstWeekdayIsMonday ? 2 : 1 // Monday:2, Sunday:1

        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }

        let firstWeekdayOfMonth = calendar.component(.weekday, from: firstOfMonth)
        let padDays = ((firstWeekdayOfMonth - calendar.firstWeekday) + 7) % 7

        var dates: [Date] = []

        // Previous month days
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
           let prevRange = calendar.range(of: .day, in: .month, for: previousMonth),
           let prevStart = calendar.date(from: calendar.dateComponents([.year, .month], from: previousMonth)) {
            let prevDaysCount = prevRange.count
            for offset in (prevDaysCount - padDays)..<prevDaysCount {
                if let date = calendar.date(byAdding: .day, value: offset, to: prevStart) {
                    dates.append(date)
                }
            }
        }

        // Current month days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                dates.append(date)
            }
        }

        // Next month days to fill 6 rows x 7 columns (42 cells)
        while dates.count < 42 {
            if let last = dates.last,
               let next = calendar.date(byAdding: .day, value: 1, to: last) {
                dates.append(next)
            } else {
                break
            }
        }

        return dates
    }

    func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    func isInCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
}
