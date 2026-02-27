//
//  CalendarWidgetProvider.swift
//  calendar++
//
//  Timeline provider for Calendar Widget
//

import WidgetKit
import SwiftUI
import EventKit

struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let events: [EventSummary]
}

struct CalendarWidgetProvider: TimelineProvider {
    typealias Entry = CalendarWidgetEntry

    func placeholder(in context: Context) -> CalendarWidgetEntry {
        CalendarWidgetEntry(date: Date(), events: sampleEvents())
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        let entry = CalendarWidgetEntry(date: Date(), events: sampleEvents())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        // Fetch real events from EventKit
        let events = fetchTodaysEvents()
        let currentDate = Date()

        // Create entry with current events
        let entry = CalendarWidgetEntry(date: currentDate, events: events)

        // Refresh timeline every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))

        completion(timeline)
    }

    // MARK: - Event Fetching

    private func fetchTodaysEvents() -> [EventSummary] {
        let eventStore = EKEventStore()
        let calendar = Calendar.current

        // Get start and end of today
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        // Create predicate for today's events
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        // Fetch events
        let ekEvents = eventStore.events(matching: predicate)

	        // Convert to EventSummary
	        let events = ekEvents.prefix(10).map { event in
	            EventSummary(
	                id: event.eventIdentifier ?? UUID().uuidString,
	                title: event.title ?? "No Title",
	                startDate: event.startDate,
	                endDate: event.endDate,
	                isAllDay: event.isAllDay,
	                calendarId: event.calendar.calendarIdentifier,
	                calendarName: event.calendar.title,
	                calendarColor: NSColor(cgColor: event.calendar.cgColor ?? NSColor.blue.cgColor) ?? .blue,
	                location: event.location
	            )
	        }

        return Array(events)
    }

    private func sampleEvents() -> [EventSummary] {
        return [
            EventSummary(
                id: "1",
                title: "Team Standup",
                startDate: Date(),
                endDate: Date().addingTimeInterval(1800),
                isAllDay: false,
                calendarName: "Work",
                calendarColor: .blue,
                location: nil
            ),
            EventSummary(
                id: "2",
                title: "Lunch Break",
                startDate: Date().addingTimeInterval(7200),
                endDate: Date().addingTimeInterval(10800),
                isAllDay: false,
                calendarName: "Personal",
                calendarColor: .green,
                location: "Cafe"
            ),
            EventSummary(
                id: "3",
                title: "Project Review",
                startDate: Date().addingTimeInterval(14400),
                endDate: Date().addingTimeInterval(18000),
                isAllDay: false,
                calendarName: "Work",
                calendarColor: .blue,
                location: "Conference Room"
            )
        ]
    }
}
