import SwiftUI

struct DayCellView: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let hasEvents: Bool

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.3))
            } else if isToday {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }

            VStack(spacing: 2) {
                Text(dayString)
                    .font(.caption)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(isInCurrentMonth ? .primary : .secondary)

                if hasEvents {
                    Circle()
                        .frame(width: 4, height: 4)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .padding(4)
        }
        .frame(height: 24)
    }
}
