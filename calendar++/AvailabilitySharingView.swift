//
//  AvailabilitySharingView.swift
//  calendar++
//
//  Created by Claude on 2025-12-23.
//

import SwiftUI

struct AvailabilitySharingView: View {
    @EnvironmentObject var availabilityManager: AvailabilitySharingManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    @State private var showingCreateLink = false
    @State private var selectedLink: BookingLink?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                if !eventKitManager.hasCalendarAccess {
                    calendarAccessHint
                }
                bookingLinksList
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .calendarppModal(isPresented: $showingCreateLink) {
            CreateBookingLinkView { link in
                _ = availabilityManager.createBookingLink(
                    title: link.title,
                    durationMinutes: link.durationMinutes,
                    daysInAdvance: link.daysInAdvance,
                    workingHours: link.workingHours
                )
                showingCreateLink = false
            }
        }
        .calendarppModal(item: $selectedLink) { link in
            BookingLinkDetailView(link: link)
                .environmentObject(availabilityManager)
                .environmentObject(eventKitManager)
                .environmentObject(filterManager)
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Availability Sharing")
                    .font(.system(size: 24, weight: .bold))
                Text("Share booking links with others")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showingCreateLink = true }) {
                Label("Create Link", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.bottom, 10)
    }

    private var calendarAccessHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
            Text("Calendar permission is needed to compute available booking slots.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            Button("Grant Access") {
                eventKitManager.requestAccessIfNeeded()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    private var bookingLinksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Booking Links")
                .font(.headline)

            if availabilityManager.bookingLinks.isEmpty {
                emptyStateView
            } else {
                ForEach(availabilityManager.bookingLinks) { link in
                    BookingLinkRow(
                        link: link,
                        onToggle: {
                            availabilityManager.toggleLinkActive(link)
                        },
                        onView: {
                            selectedLink = link
                        },
                        onCopy: {
                            availabilityManager.copyLinkToClipboard(link)
                        },
                        onDelete: {
                            availabilityManager.deleteBookingLink(link)
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            Text("No booking links yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Create Your First Link") {
                showingCreateLink = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct BookingLinkRow: View {
    let link: BookingLink
    let onToggle: () -> Void
    let onView: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var showCopiedFeedback = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { link.isActive },
                set: { newValue in
                    // Prevent accidental double-toggles if SwiftUI replays the setter.
                    guard newValue != link.isActive else { return }
                    onToggle()
                }
            ))
                .labelsHidden()
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 4) {
                Text(link.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label("\(link.durationMinutes) min", systemImage: "clock")
                    Label("\(link.daysInAdvance) days", systemImage: "calendar")
                    Label(link.linkCode, systemImage: "link")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if showCopiedFeedback {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }

                Button(action: {
                    onCopy()
                    withAnimation {
                        showCopiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopiedFeedback = false
                        }
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy link to clipboard")

                Button(action: onView) {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
                .help("View details")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("Delete link")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(link.isActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
}

struct CreateBookingLinkView: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (BookingLink) -> Void

    @State private var title = "30-Minute Meeting"
    @State private var duration = 30
    @State private var daysInAdvance = 14
    @State private var startHour = 9
    @State private var endHour = 17

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endHour > startHour
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Booking Link")
                .font(.headline)

            Form {
                TextField("Link Title", text: $title)

                Picker("Duration", selection: $duration) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("45 minutes").tag(45)
                    Text("1 hour").tag(60)
                }

                Stepper("Available for next \(daysInAdvance) days", value: $daysInAdvance, in: 1...30)

                HStack {
                    Text("Working hours:")
                    Spacer()
                    Picker("Start", selection: $startHour) {
                        ForEach(6..<20) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    .frame(width: 100)
                    Text("to")
                    Picker("End", selection: $endHour) {
                        ForEach(10..<24) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    .frame(width: 100)
                }
            }
            .padding()

            if endHour <= startHour {
                Text("End hour must be later than start hour.")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let link = BookingLink(
                        title: title,
                        durationMinutes: duration,
                        daysInAdvance: daysInAdvance,
                        workingHours: startHour...endHour,
                        bufferMinutes: 10,
                        maxBookingsPerDay: 5,
                        isActive: true,
                        linkCode: ""
                    )
                    onCreate(link)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
            }
            .padding()
        }
        .frame(width: 400)
        .padding()
    }
}

struct BookingLinkDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var availabilityManager: AvailabilitySharingManager
    @EnvironmentObject var eventKitManager: EventKitManager
    @EnvironmentObject var filterManager: CalendarFilterManager

    let link: BookingLink

    private var visibleEvents: [EventSummary] {
        filterManager.filterEvents(eventKitManager.events)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(link.title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Shareable Link:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text(link.shareableURL)
                        .font(.caption)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )

                    Button("Copy") {
                        availabilityManager.copyLinkToClipboard(link)
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                Text("Shareable Text:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: .constant(availabilityManager.getShareableText(for: link)))
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.2))
                    .disabled(true)
            }
            .padding()

            if eventKitManager.hasCalendarAccess {
                Button("Find Available Slots") {
                    refreshSlots()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Grant Calendar Access") {
                    eventKitManager.requestAccessIfNeeded()
                }
                .buttonStyle(.borderedProminent)
            }

            if eventKitManager.hasCalendarAccess && !availabilityManager.availableSlots.isEmpty {
                Text("Next \(min(10, availabilityManager.availableSlots.count)) Available Slots:")
                    .font(.subheadline)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(availabilityManager.availableSlots.prefix(10)) { slot in
                            HStack {
                                Text(formatDate(slot.startTime))
                                    .font(.caption)
                                    .frame(width: 100, alignment: .leading)
                                Text(slot.formattedTimeRange)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(height: 200)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 500, height: 600)
        .padding()
        .onAppear {
            refreshSlots()
        }
        .onChange(of: eventKitManager.eventsByDay) { _ in
            refreshSlots()
        }
        .onChange(of: eventKitManager.googleEventsByDay) { _ in
            refreshSlots()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshSlots()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func refreshSlots() {
        guard eventKitManager.hasCalendarAccess else { return }
        availabilityManager.findAvailableSlots(
            for: link,
            events: visibleEvents
        )
    }
}

struct AvailabilitySharingView_Previews: PreviewProvider {
    static var previews: some View {
        AvailabilitySharingView()
            .environmentObject(AvailabilitySharingManager())
            .environmentObject(EventKitManager())
    }
}
