//
//  CalendarWidget.swift
//  calendar++
//
//  macOS Sonoma Widget for displaying today's events
//

import WidgetKit
import SwiftUI

// Note: Widget requires a separate widget extension target to run
// This file provides the widget structure for when that target is created
struct CalendarWidget: Widget {
    let kind: String = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarWidgetProvider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calendar++")
        .description("View today's events at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CalendarWidgetEntryView: View {
    var entry: CalendarWidgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Previews

struct CalendarWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEvents = [
            EventSummary(
                id: "1",
                title: "Team Meeting",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                isAllDay: false,
                calendarName: "Work",
                calendarColor: .blue,
                location: "Conference Room A"
            ),
            EventSummary(
                id: "2",
                title: "Lunch with Sarah",
                startDate: Date().addingTimeInterval(7200),
                endDate: Date().addingTimeInterval(10800),
                isAllDay: false,
                calendarName: "Personal",
                calendarColor: .green,
                location: "Cafe Downtown"
            )
        ]

        let entry = CalendarWidgetEntry(date: Date(), events: sampleEvents)

        Group {
            CalendarWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            CalendarWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            CalendarWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
