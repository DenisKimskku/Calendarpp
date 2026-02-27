//
//  AvailabilitySharingManager.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import Foundation
import Combine
import AppKit

struct AvailabilitySlot: Identifiable, Codable {
    var id = UUID()
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

struct BookingLink: Identifiable, Codable {
    var id = UUID()
    var title: String
    var durationMinutes: Int
    var daysInAdvance: Int
    var workingHours: ClosedRange<Int> // e.g., 9...17 for 9am-5pm
    var bufferMinutes: Int // Buffer time before/after meetings
    var maxBookingsPerDay: Int
    var isActive: Bool
    var linkCode: String

    var shareableURL: String {
        "calendarplusplus://book/\(linkCode)"
    }
}

class AvailabilitySharingManager: ObservableObject {
    @Published var bookingLinks: [BookingLink] = []
    @Published var availableSlots: [AvailabilitySlot] = []

    private let calendar = Calendar.current
    private let userDefaults = UserDefaults.standard

    init() {
        loadBookingLinks()
    }

    // MARK: - Booking Links

    func createBookingLink(
        title: String,
        durationMinutes: Int,
        daysInAdvance: Int = 14,
        workingHours: ClosedRange<Int> = 9...17
    ) -> BookingLink {
        let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = sanitizedTitle.isEmpty ? "Booking Link" : sanitizedTitle
        let normalizedDuration = max(15, durationMinutes)
        let normalizedDays = max(1, daysInAdvance)

        let link = BookingLink(
            title: resolvedTitle,
            durationMinutes: normalizedDuration,
            daysInAdvance: normalizedDays,
            workingHours: workingHours,
            bufferMinutes: 10,
            maxBookingsPerDay: 5,
            isActive: true,
            linkCode: generateLinkCode()
        )

        bookingLinks.append(link)
        saveBookingLinks()
        return link
    }

    func updateBookingLink(_ link: BookingLink) {
        if let index = bookingLinks.firstIndex(where: { $0.id == link.id }) {
            bookingLinks[index] = link
            saveBookingLinks()
        }
    }

    func deleteBookingLink(_ link: BookingLink) {
        bookingLinks.removeAll { $0.id == link.id }
        saveBookingLinks()
    }

    func toggleLinkActive(_ link: BookingLink) {
        if let index = bookingLinks.firstIndex(where: { $0.id == link.id }) {
            bookingLinks[index].isActive.toggle()
            saveBookingLinks()
        }
    }

    private func generateLinkCode() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var code = ""
        repeat {
            code = String((0..<8).compactMap { _ in characters.randomElement() })
        } while bookingLinks.contains(where: { $0.linkCode == code })
        return code
    }

    private func saveBookingLinks() {
        if let encoded = try? JSONEncoder().encode(bookingLinks) {
            userDefaults.set(encoded, forKey: "bookingLinks")
        }
    }

    private func loadBookingLinks() {
        if let data = userDefaults.data(forKey: "bookingLinks"),
           let links = try? JSONDecoder().decode([BookingLink].self, from: data) {
            bookingLinks = links
        }
    }

    // MARK: - Availability Finding

    func findAvailableSlots(
        for link: BookingLink,
        events: [EventSummary],
        startingFrom date: Date = Date()
    ) {
        var slots: [AvailabilitySlot] = []

        // Find available slots for the next N days
        for dayOffset in 0..<link.daysInAdvance {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }

            let daySlots = findSlotsForDay(
                day: day,
                startingFrom: date,
                events: events,
                workingHours: link.workingHours,
                durationMinutes: link.durationMinutes,
                bufferMinutes: link.bufferMinutes,
                maxSlots: link.maxBookingsPerDay
            )

            slots.append(contentsOf: daySlots)
        }

        DispatchQueue.main.async {
            self.availableSlots = slots
        }
    }

    private func findSlotsForDay(
        day: Date,
        startingFrom earliestDate: Date,
        events: [EventSummary],
        workingHours: ClosedRange<Int>,
        durationMinutes: Int,
        bufferMinutes: Int,
        maxSlots: Int
    ) -> [AvailabilitySlot] {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)

        // Filter events for this day
        let dayEvents = events.filter { event in
            event.startDate < dayEnd && event.endDate > dayStart
        }
        .sorted { $0.startDate < $1.startDate }

        // Create working hours boundaries
        guard let workStart = calendar.date(bySettingHour: workingHours.lowerBound, minute: 0, second: 0, of: day),
              let workEnd = calendar.date(bySettingHour: workingHours.upperBound, minute: 0, second: 0, of: day) else {
            return []
        }

        var slots: [AvailabilitySlot] = []
        var currentTime = workStart
        if calendar.isDate(day, inSameDayAs: earliestDate) {
            let rounded = roundUpToQuarterHour(earliestDate)
            currentTime = max(currentTime, rounded)
        }

        while currentTime < workEnd && slots.count < maxSlots {
            let slotEnd = calendar.date(byAdding: .minute, value: durationMinutes, to: currentTime)
                ?? currentTime.addingTimeInterval(TimeInterval(durationMinutes * 60))

            // Check if this slot is free
            let isFree = !dayEvents.contains { event in
                // Check for overlap with buffer time
                let bufferedStart = calendar.date(byAdding: .minute, value: -bufferMinutes, to: event.startDate)
                    ?? event.startDate.addingTimeInterval(TimeInterval(-bufferMinutes * 60))
                let bufferedEnd = calendar.date(byAdding: .minute, value: bufferMinutes, to: event.endDate)
                    ?? event.endDate.addingTimeInterval(TimeInterval(bufferMinutes * 60))

                return currentTime < bufferedEnd && slotEnd > bufferedStart
            }

            if isFree && slotEnd <= workEnd {
                let slot = AvailabilitySlot(
                    startTime: currentTime,
                    endTime: slotEnd,
                    durationMinutes: durationMinutes
                )
                slots.append(slot)
            }

            // Move to next potential slot (15-minute increments)
            currentTime = calendar.date(byAdding: .minute, value: 15, to: currentTime)
                ?? currentTime.addingTimeInterval(15 * 60)
        }

        return slots
    }

    private func roundUpToQuarterHour(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let base = calendar.date(from: components) else { return date }

        let minute = calendar.component(.minute, from: base)
        let remainder = minute % 15
        let add = remainder == 0 ? 0 : (15 - remainder)
        return calendar.date(byAdding: .minute, value: add, to: base) ?? base
    }

    // MARK: - Sharing

    func getShareableText(for link: BookingLink) -> String {
        """
        Book a meeting with me!

        Duration: \(link.durationMinutes) minutes
        Available times: Next \(link.daysInAdvance) days

        Click here to book: \(link.shareableURL)
        """
    }

    func copyLinkToClipboard(_ link: BookingLink) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link.shareableURL, forType: .string)
    }
}
