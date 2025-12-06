import SwiftUI

struct SmartSchedulingView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var calendarVM: CalendarViewModel
    
    @State private var duration: Double = 60 // minutes
    @State private var daysAhead: Int = 7
    @State private var showTimeZoneHelper = false
    @State private var selectedTimeZones: [TimeZone] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Smart Scheduling")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $duration, in: 15...240, step: 15)
                            .frame(width: 100)
                        Text("\(Int(duration))m")
                            .font(.caption)
                            .frame(width: 40)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Days ahead")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $daysAhead) {
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                    }
                    .labelsHidden()
                    .font(.caption)
                }
            }
            
            Toggle("Multi-timezone scheduling", isOn: $showTimeZoneHelper)
                .font(.caption2)
            
            if showTimeZoneHelper {
                TimeZoneSelectorView(selectedTimeZones: $selectedTimeZones)
            }
            
            Button("Find Free Slots") {
                findFreeSlots()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            
            FreeSlotsListView(slots: calculatedSlots)
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var calculatedSlots: [TimeSlot] {
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate)!
        
        // Collect all events in range
        var allEvents: [EventSummary] = []
        var currentDate = calendar.startOfDay(for: startDate)
        while currentDate <= endDate {
            allEvents.append(contentsOf: eventKit.events(on: currentDate))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Filter by enabled calendars
        allEvents = allEvents.filter { settings.isCalendarEnabled($0.calendarIdentifier) }
        
        if showTimeZoneHelper && !selectedTimeZones.isEmpty {
            return SmartSchedulingHelper.suggestMeetingTimes(
                events: allEvents,
                participantTimeZones: selectedTimeZones,
                preferredDate: startDate,
                duration: duration * 60
            )
        } else {
            return SmartSchedulingHelper.findFreeSlots(
                events: allEvents,
                startDate: startDate,
                endDate: endDate,
                duration: duration * 60
            )
        }
    }
    
    private func findFreeSlots() {
        // Trigger recalculation by toggling a state variable if needed
    }
}

struct TimeZoneSelectorView: View {
    @Binding var selectedTimeZones: [TimeZone]
    
    private let commonTimeZones = [
        "America/New_York",
        "America/Los_Angeles",
        "Europe/London",
        "Europe/Paris",
        "Asia/Tokyo",
        "Asia/Singapore",
        "Australia/Sydney"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Participant time zones")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            ForEach(commonTimeZones, id: \.self) { tzId in
                if let tz = TimeZone(identifier: tzId) {
                    Toggle(isOn: Binding(
                        get: { selectedTimeZones.contains(where: { $0.identifier == tzId }) },
                        set: { isOn in
                            if isOn {
                                selectedTimeZones.append(tz)
                            } else {
                                selectedTimeZones.removeAll { $0.identifier == tzId }
                            }
                        }
                    )) {
                        Text(cityName(for: tz))
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(6)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func cityName(for tz: TimeZone) -> String {
        if let name = tz.identifier.split(separator: "/").last {
            return String(name).replacingOccurrences(of: "_", with: " ")
        }
        return tz.identifier
    }
}

struct FreeSlotsListView: View {
    let slots: [TimeSlot]
    @EnvironmentObject var eventKit: EventKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Available slots (\(slots.count))")
                .font(.caption.bold())
            
            if slots.isEmpty {
                Text("No free slots found")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(slots.prefix(5)) { slot in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.formattedDate)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(slot.formattedTime)
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                Button {
                                    // Quick book this slot
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(4)
                            .background(Color.green.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
    }
}
