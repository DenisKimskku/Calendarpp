import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel

    var body: some View {
        HStack {
            Button("Today") {
                calendarVM.goToToday()
            }

            Spacer()

            Text(calendarVM.monthTitle)
                .font(.headline)

            Spacer()

            HStack(spacing: 8) {
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
}
