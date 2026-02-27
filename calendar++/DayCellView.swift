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

    private var foregroundColor: Color {
        if isSelected {
            return .primary
        }
        if isToday {
            return Color.accentColor
        }
        return isInCurrentMonth ? .primary : .secondary
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayString)
                .font(.system(size: 11, weight: isToday || isSelected ? .semibold : .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(foregroundColor)

            Capsule(style: .continuous)
                .fill(hasEvents ? Color.accentColor.opacity(isSelected ? 0.95 : 0.75) : Color.clear)
                .frame(width: hasEvents ? 10 : 8, height: 3)
        }
        .padding(.vertical, 3)
        .frame(height: 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(isSelected ? 0.16 : (isToday ? 0.06 : 0.0)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.45) :
                    (isToday ? Color.accentColor.opacity(0.85) : CalendarPPZenStyle.stroke),
                    lineWidth: isToday || isSelected ? 1.4 : 1
                )
        )
        .opacity(isInCurrentMonth ? 1.0 : 0.52)
    }
}
