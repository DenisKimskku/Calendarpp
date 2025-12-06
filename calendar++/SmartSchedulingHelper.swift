import Foundation

struct TimeSlot: Identifiable, Equatable {
    let id = UUID()
    let start: Date
    let end: Date
    let duration: TimeInterval
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start)
    }
}

struct SmartSchedulingHelper {
    
    /// Find free time slots for a given duration within a date range
    static func findFreeSlots(
        events: [EventSummary],
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        workingHoursStart: Int = 9,
        workingHoursEnd: Int = 17
    ) -> [TimeSlot] {
        let calendar = Calendar.current
        var freeSlots: [TimeSlot] = []
        
        // Group events by day
        let eventsByDay = Dictionary(grouping: events) { event -> Date in
            calendar.startOfDay(for: event.startDate)
        }
        
        // Iterate through each day in the range
        var currentDate = calendar.startOfDay(for: startDate)
        let finalDate = calendar.startOfDay(for: endDate)
        
        while currentDate <= finalDate {
            // Skip weekends (optional)
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }
            
            // Get working hours for this day
            var workStart = calendar.date(bySettingHour: workingHoursStart, minute: 0, second: 0, of: currentDate)!
            let workEnd = calendar.date(bySettingHour: workingHoursEnd, minute: 0, second: 0, of: currentDate)!
            
            // Get events for this day
            let dayEvents = eventsByDay[currentDate]?.filter { !$0.isAllDay }.sorted(by: { $0.startDate < $1.startDate }) ?? []
            
            // Find gaps between events
            for event in dayEvents {
                let eventStart = max(event.startDate, workStart)
                let eventEnd = min(event.endDate, workEnd)
                
                // Check if there's a free slot before this event
                if eventStart.timeIntervalSince(workStart) >= duration {
                    freeSlots.append(TimeSlot(
                        start: workStart,
                        end: eventStart,
                        duration: eventStart.timeIntervalSince(workStart)
                    ))
                }
                
                // Move work start to after this event
                workStart = max(workStart, eventEnd)
            }
            
            // Check if there's time at the end of the day
            if workEnd.timeIntervalSince(workStart) >= duration {
                freeSlots.append(TimeSlot(
                    start: workStart,
                    end: workEnd,
                    duration: workEnd.timeIntervalSince(workStart)
                ))
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return freeSlots
    }
    
    /// Suggest optimal meeting times across multiple time zones
    static func suggestMeetingTimes(
        events: [EventSummary],
        participantTimeZones: [TimeZone],
        preferredDate: Date,
        duration: TimeInterval = 60 * 60 // 1 hour default
    ) -> [TimeSlot] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: preferredDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Find slots that work in all time zones (9 AM - 5 PM in each zone)
        let allSlots = findFreeSlots(
            events: events,
            startDate: startOfDay,
            endDate: endOfDay,
            duration: duration
        )
        
        // Filter to slots that are reasonable in all time zones
        return allSlots.filter { slot in
            participantTimeZones.allSatisfy { tz in
                let hour = calendar.component(.hour, from: slot.start.addingTimeInterval(TimeInterval(tz.secondsFromGMT())))
                return hour >= 8 && hour <= 18 // 8 AM to 6 PM
            }
        }
    }
}
