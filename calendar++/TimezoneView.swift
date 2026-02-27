//
//  TimezoneView.swift
//  calendar++
//
//  UI for timezone management and world clocks
//

import SwiftUI

// MARK: - Main Timezone View

struct TimezoneView: View {
    @StateObject private var timezoneManager = TimezoneManager()
    @State private var showingAddTimezone = false
    @State private var showingMeetingFinder = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("World Clocks")
                    .font(.headline)
                Spacer()
                Button {
                    showingMeetingFinder = true
                } label: {
                    Image(systemName: "clock.badge.checkmark")
                }
                .buttonStyle(.plain)
                .help("Find best meeting time")

                Button {
                    showingAddTimezone = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // World Clocks List
            if timezoneManager.favoriteTimezones.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(timezoneManager.favoriteTimezones) { timezone in
                            WorldClockRow(timezone: timezone, manager: timezoneManager)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 400, height: 500)
        .calendarppModal(isPresented: $showingAddTimezone) {
            AddTimezoneView(manager: timezoneManager)
        }
        .calendarppModal(isPresented: $showingMeetingFinder) {
            MeetingTimeFinderView(manager: timezoneManager)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No world clocks")
                .foregroundColor(.secondary)
            Button("Add Your First Clock") {
                showingAddTimezone = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - World Clock Row

struct WorldClockRow: View {
    let timezone: TimezoneInfo
    @ObservedObject var manager: TimezoneManager

    @State private var currentTime = Date()
    @State private var timer: Timer?

    var timeDifference: String {
        let systemOffset = TimeZone.current.secondsFromGMT()
        let timezoneOffset = timezone.timeZone?.secondsFromGMT() ?? 0
        let difference = (timezoneOffset - systemOffset) / 3600

        if difference == 0 {
            return "Same time"
        } else if difference > 0 {
            return "+\(difference) hours"
        } else {
            return "\(difference) hours"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Flag emoji
            if !timezone.countryCode.isEmpty {
                Text(manager.flagEmoji(countryCode: timezone.countryCode))
                    .font(.largeTitle)
            } else {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                // City name
                Text(timezone.name)
                    .font(.headline)

                // Time difference
                Text(timeDifference)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // GMT offset
                Text(timezone.offsetFromGMT)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            Spacer()

            // Current time
            VStack(alignment: .trailing, spacing: 2) {
                Text(timezone.formattedTime(date: currentTime))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)

                Text(timezone.formattedDate(date: currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Remove button
            if !timezone.isDefault {
                Button {
                    manager.removeFavorite(timezone)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var statusColor: Color {
        guard let tz = timezone.timeZone else { return .gray }

        if manager.isSleepTime(in: tz, at: currentTime) {
            return .purple
        } else if manager.isBusinessHours(in: tz, at: currentTime) {
            return .green
        } else {
            return .orange
        }
    }

    private var statusText: String {
        guard let tz = timezone.timeZone else { return "" }

        if manager.isSleepTime(in: tz, at: currentTime) {
            return "Sleep time"
        } else if manager.isBusinessHours(in: tz, at: currentTime) {
            return "Business hours"
        } else {
            return "Off hours"
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Add Timezone View

struct AddTimezoneView: View {
    @ObservedObject var manager: TimezoneManager
    @Environment(\.dismiss) var dismiss

    @State private var searchQuery: String = ""
    @State private var selectedTimezone: TimezoneInfo?

    var searchResults: [TimezoneInfo] {
        if searchQuery.isEmpty {
            return TimezoneManager.popularCities
        } else {
            return manager.searchTimezones(searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add World Clock")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search city or timezone", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.05))

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { timezone in
                        Button {
                            selectedTimezone = timezone
                            manager.addFavorite(timezone)
                            dismiss()
                        } label: {
                            HStack {
                                if !timezone.countryCode.isEmpty {
                                    Text(manager.flagEmoji(countryCode: timezone.countryCode))
                                        .font(.title3)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(timezone.city)
                                        .font(.headline)
                                    Text(timezone.timezone)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(timezone.formattedTime())
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(selectedTimezone?.id == timezone.id ? Color.blue.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Event Timezone Converter

struct EventTimezoneConverter: View {
    let event: EventSummary
    @StateObject private var timezoneManager = TimezoneManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Event info
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.title2.bold())

                Text("Original time:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatOriginalTime())
                    .font(.headline)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            Divider()

            // Timezone conversions
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(timezoneManager.favoriteTimezones) { timezone in
                        if let tz = timezone.timeZone {
                            TimezoneConversionRow(
                                timezone: timezone,
                                event: event,
                                timeZone: tz
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }

    private func formatOriginalTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}

struct TimezoneConversionRow: View {
    let timezone: TimezoneInfo
    let event: EventSummary
    let timeZone: TimeZone

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !timezone.countryCode.isEmpty {
                        Text(TimezoneManager().flagEmoji(countryCode: timezone.countryCode))
                    }
                    Text(timezone.name)
                        .font(.headline)
                }

                Text(timezone.offsetFromGMT)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(event.startDate, in: timeZone))
                    .font(.subheadline.monospacedDigit())
                Text(formatTime(event.endDate, in: timeZone))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatTime(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Meeting Time Finder

struct MeetingTimeFinderView: View {
    @ObservedObject var manager: TimezoneManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTimezones: Set<UUID> = []
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 3600) // 1 week
    @State private var duration: TimeInterval = 3600 // 1 hour
    @State private var businessHoursOnly = true
    @State private var suggestedTimes: [Date] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Find Best Meeting Time")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Timezone Selection
                    Section {
                        Text("Select Timezones")
                            .font(.subheadline.bold())

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(manager.favoriteTimezones) { timezone in
                                Toggle(isOn: Binding(
                                    get: { selectedTimezones.contains(timezone.id) },
                                    set: { isOn in
                                        if isOn {
                                            selectedTimezones.insert(timezone.id)
                                        } else {
                                            selectedTimezones.remove(timezone.id)
                                        }
                                    }
                                )) {
                                    HStack {
                                        if !timezone.countryCode.isEmpty {
                                            Text(manager.flagEmoji(countryCode: timezone.countryCode))
                                        }
                                        Text(timezone.name)
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Date Range
                    Section {
                        Text("Date Range")
                            .font(.subheadline.bold())

                        DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)

                        DatePicker("End", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                    }

                    Divider()

                    // Meeting Duration
                    Section {
                        Text("Duration")
                            .font(.subheadline.bold())

                        Picker("Duration", selection: $duration) {
                            Text("30 minutes").tag(TimeInterval(1800))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("1.5 hours").tag(TimeInterval(5400))
                            Text("2 hours").tag(TimeInterval(7200))
                        }
                        .pickerStyle(.radioGroup)
                    }

                    Divider()

                    // Options
                    Section {
                        Toggle("Business hours only (9 AM - 6 PM)", isOn: $businessHoursOnly)
                    }

                    // Find button
                    Button {
                        findMeetingTimes()
                    } label: {
                        Text("Find Available Times")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedTimezones.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(selectedTimezones.isEmpty)

                    // Results
                    if !suggestedTimes.isEmpty {
                        Divider()

                        Section {
                            Text("Suggested Times (\(suggestedTimes.count) found)")
                                .font(.subheadline.bold())

                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(suggestedTimes.prefix(10), id: \.self) { time in
                                        MeetingTimeCard(time: time, duration: duration, timezones: getSelectedTimezones(), manager: manager)
                                    }
                                }
                            }
                            .frame(height: 300)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }

    private func getSelectedTimezones() -> [TimeZone] {
        return manager.favoriteTimezones
            .filter { selectedTimezones.contains($0.id) }
            .compactMap { $0.timeZone }
    }

    private func findMeetingTimes() {
        let timezones = getSelectedTimezones()
        let dateRange = DateInterval(start: startDate, end: endDate)

        suggestedTimes = manager.findBestMeetingTime(
            for: timezones,
            duration: duration,
            within: dateRange,
            businessHoursOnly: businessHoursOnly
        )
    }
}

struct MeetingTimeCard: View {
    let time: Date
    let duration: TimeInterval
    let timezones: [TimeZone]
    let manager: TimezoneManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main time
            Text(formatMainTime())
                .font(.headline)

            // Times in each timezone
            VStack(alignment: .leading, spacing: 4) {
                ForEach(timezones, id: \.identifier) { timezone in
                    HStack {
                        Text(timezone.identifier.components(separatedBy: "/").last ?? timezone.identifier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)

                        Text(manager.formatTimeInTimezone(time, timezone: timezone))
                            .font(.caption.monospacedDigit())

                        Spacer()

                        // Status indicator
                        if manager.isBusinessHours(in: timezone, at: time) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else if manager.isSleepTime(in: timezone, at: time) {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.purple)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    private func formatMainTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let endTime = time.addingTimeInterval(duration)

        return "\(formatter.string(from: time)) - \(DateFormatter.localizedString(from: endTime, dateStyle: .none, timeStyle: .short))"
    }
}

// MARK: - Preview

#Preview {
    TimezoneView()
}
