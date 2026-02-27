import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var calendarVM: CalendarViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                calendarVM.goToToday()
            } label: {
                Text("Today")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .calendarPPZenCard(cornerRadius: 999, strong: false)
            .keyboardShortcut("t", modifiers: .command)

            Spacer()

            Text(calendarVM.monthTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                Button {
                    calendarVM.changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
                .calendarPPZenCard(cornerRadius: 999, strong: false)
                .help("Go to previous month")

                Button {
                    calendarVM.changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 20)
                }
                .buttonStyle(.plain)
                .calendarPPZenCard(cornerRadius: 999, strong: false)
                .help("Go to next month")
            }
        }
    }
}
