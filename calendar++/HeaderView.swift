import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    var body: some View {
        HStack {
            Button("Today") {
                calendarVM.goToToday()
            }
            .keyboardShortcut("t", modifiers: .command)

            Spacer()

            Text(calendarVM.monthTitle)
                .font(.headline)

            Spacer()

            HStack(spacing: 8) {
                // Refresh button
                Button {
                    refreshCalendars()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh calendars")

                Button {
                    calendarVM.changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                Button {
                    calendarVM.changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
    }

    private func refreshCalendars() {
        eventKit.reloadAllEvents()
        googleCalendar.refreshEventsIfNeeded()
    }
}
