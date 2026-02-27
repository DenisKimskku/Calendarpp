import SwiftUI
import Combine

struct MenuBarLabelView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var settings: SettingsViewModel

    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            if settings.showBusyBar {
                BusyBarView(fraction: busyFraction)
            }

            if settings.menuBarDateFormat != .iconOnly {
                Text(formattedMenuBarText(for: now))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            } else {
                Image(systemName: "calendar.circle.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 13, weight: .semibold))
            }

            if showNextEventDot {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 4)
        .tint(settings.resolvedTintColor)
        .onReceive(timer) { date in
            self.now = date
        }
        .onAppear {
            // ensure we have event data for Busy Bar / dot
            eventKit.requestAccessIfNeeded()
            eventKit.reloadAllEvents(around: Date())
        }
    }

    // MARK: - Busy Bar logic

    private var busyFraction: CGFloat {
        let busyMinutes = filteredBusyMinutes(on: Date())
        let maxMinutes = max(1.0, settings.busyBarMaxHours * 60.0)
        let fraction = min(1.0, Double(busyMinutes) / maxMinutes)
        return CGFloat(fraction)
    }

    private var showNextEventDot: Bool {
        guard settings.showNextEventDot else { return false }
        guard let next = nextVisibleEvent() else { return false }

        let diff = next.startDate.timeIntervalSince(Date()) / 60.0 // minutes
        return diff >= 0 && diff <= 30 // within 30 minutes
    }

    private func filteredBusyMinutes(on date: Date) -> Int {
        let todayEvents = filterManager.filterEvents(eventKit.events(on: date))
        let now = Date()
        let calendar = Calendar.current
        let isToday = calendar.isDate(date, inSameDayAs: now)

        var totalMinutes = 0
        for event in todayEvents {
            guard !event.isAllDay else { continue }

            let start: Date
            if isToday && event.startDate < now {
                start = now
            } else {
                start = event.startDate
            }

            let end = event.endDate
            guard end > start else { continue }
            totalMinutes += Int(end.timeIntervalSince(start) / 60.0)
        }
        return totalMinutes
    }

    private func nextVisibleEvent() -> EventSummary? {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today) ?? tomorrow

        var upcomingEvents: [EventSummary] = []
        upcomingEvents.append(contentsOf: filterManager.filterEvents(eventKit.events(on: today)))
        upcomingEvents.append(contentsOf: filterManager.filterEvents(eventKit.events(on: tomorrow)))
        upcomingEvents.append(contentsOf: filterManager.filterEvents(eventKit.events(on: dayAfter)))

        return upcomingEvents
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    // MARK: - Date formatting

    private func formattedMenuBarText(for date: Date) -> String {
        switch settings.menuBarDateFormat {
        case .dayOnly:
            return DateFormatter.dayFormatter.string(from: date)
        case .monthDay:
            return DateFormatter.monthDayFormatter.string(from: date)
        case .weekdayDay:
            return DateFormatter.weekdayDayFormatter.string(from: date)
        case .yearMonthDay:
            return DateFormatter.yearMonthDayFormatter.string(from: date)
        case .iconOnly:
            return ""  // unused; we show an icon instead
        }
    }
}

// Simple tiny horizontal Busy Bar
struct BusyBarView: View {
    let fraction: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .frame(width: 22, height: 6)
                .foregroundStyle(.quaternary)

            Capsule()
                .frame(width: 22 * fraction, height: 6)
                .foregroundStyle(Color.accentColor)
        }
    }
}

// MARK: - DateFormatter helpers

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d"
        return df
    }()

    static let monthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()

    static let weekdayDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE d"
        return df
    }()

    static let yearMonthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
