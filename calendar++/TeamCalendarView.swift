//
//  TeamCalendarView.swift
//  calendar++
//
//  UI for team calendar management
//

import SwiftUI

// MARK: - Teams List View

struct TeamsListView: View {
    @StateObject private var teamManager = TeamCalendarManager()
    @State private var showingCreateTeam = false
    @State private var selectedTeam: Team?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Teams")
                    .font(.headline)
                Spacer()
                Button {
                    showingCreateTeam = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Teams List
            if teamManager.teams.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(teamManager.teams) { team in
                            TeamCard(team: team) {
                                selectedTeam = team
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 600)
        .calendarppModal(isPresented: $showingCreateTeam) {
            CreateTeamView(manager: teamManager)
        }
        .calendarppModal(item: $selectedTeam) { team in
            TeamDetailView(team: team, manager: teamManager)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No teams yet")
                .foregroundColor(.secondary)
            Button("Create Your First Team") {
                showingCreateTeam = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Team Card

struct TeamCard: View {
    let team: Team
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                // Team Icon
                Circle()
                    .fill(team.color.color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(team.name.prefix(2)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)

                    if !team.description.isEmpty {
                        Text(team.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                            Text("\(team.members.count)")
                                .font(.caption2)
                        }

                        if !team.sharedCalendarIDs.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text("\(team.sharedCalendarIDs.count)")
                                    .font(.caption2)
                            }
                        }
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Team View

struct CreateTeamView: View {
    @ObservedObject var manager: TeamCalendarManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedColor: Color = .blue

    private let availableColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .yellow,
        .pink, .cyan, .indigo, .mint, .teal, .brown
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Team")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    Section {
                        Text("Team Name")
                            .font(.subheadline.bold())
                        TextField("e.g. Engineering, Marketing", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Description
                    Section {
                        Text("Description (optional)")
                            .font(.subheadline.bold())
                        TextEditor(text: $description)
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.3))
                    }

                    Divider()

                    // Color
                    Section {
                        Text("Team Color")
                            .font(.subheadline.bold())

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableColors, id: \.description) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor.description == color.description ? 3 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Create Button
                    Button {
                        let team = manager.createTeam(name: name, description: description)
                        var updatedTeam = team
                        updatedTeam.color = CodableColor(color: selectedColor)
                        manager.updateTeam(updatedTeam)
                        dismiss()
                    } label: {
                        Text("Create Team")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(name.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 500)
    }
}

// MARK: - Team Detail View

struct TeamDetailView: View {
    @State var team: Team
    @ObservedObject var manager: TeamCalendarManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: Tab = .members
    @State private var showingAddMember = false
    @State private var showingAvailability = false

    enum Tab {
        case members
        case calendars
        case availability
        case settings
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(team.color.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(team.name.prefix(2)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                Text(team.name)
                    .font(.headline)

                Spacer()

                Button("Done") {
                    manager.updateTeam(team)
                    dismiss()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Tab Bar
            Picker("Section", selection: $selectedTab) {
                Text("Members").tag(Tab.members)
                Text("Calendars").tag(Tab.calendars)
                Text("Availability").tag(Tab.availability)
                Text("Settings").tag(Tab.settings)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .members:
                        membersTab
                    case .calendars:
                        calendarsTab
                    case .availability:
                        availabilityTab
                    case .settings:
                        settingsTab
                    }
                }
                .padding()
            }
        }
        .frame(width: 700, height: 600)
        .calendarppModal(isPresented: $showingAddMember) {
            AddMemberView(team: team, manager: manager)
        }
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Team Members (\(team.members.count))")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    showingAddMember = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if team.members.isEmpty {
                Text("No members yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(team.members) { member in
                    MemberRow(member: member, team: team, manager: manager)
                }
            }
        }
    }

    // MARK: - Calendars Tab

    private var calendarsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shared Calendars")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    // Add calendar
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if team.sharedCalendarIDs.isEmpty {
                Text("No shared calendars")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(team.sharedCalendarIDs, id: \.self) { calendarID in
                    Text(calendarID)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Availability Tab

    private var availabilityTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Availability")
                .font(.subheadline.bold())

            Button {
                showingAvailability = true
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text("Find Best Meeting Time")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            // Quick stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Stats")
                    .font(.caption.bold())

                let stats = manager.getTeamStats(for: team)

                HStack {
                    Text("Weekly Meetings:")
                    Spacer()
                    Text("\(stats.weeklyMeetingCount)")
                        .fontWeight(.semibold)
                }
                .font(.caption)

                HStack {
                    Text("Total Meeting Time:")
                    Spacer()
                    Text("\(Int(stats.totalWeeklyMeetingTime / 3600))h")
                        .fontWeight(.semibold)
                }
                .font(.caption)

                if stats.weeklyMeetingCount > 0 {
                    HStack {
                        Text("Avg. Meeting Duration:")
                        Spacer()
                        Text("\(Int(stats.averageMeetingDuration / 60))m")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .calendarppModal(isPresented: $showingAvailability) {
            TeamAvailabilityView(team: team, manager: manager)
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Settings")
                .font(.subheadline.bold())

            TextField("Team Name", text: $team.name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $team.description)
                .frame(height: 80)
                .border(Color.gray.opacity(0.3))

            Divider()

            // Danger Zone
            VStack(alignment: .leading, spacing: 8) {
                Text("Danger Zone")
                    .font(.caption.bold())
                    .foregroundColor(.red)

                Button {
                    manager.deleteTeam(team)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Team")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: TeamMember
    let team: Team
    @ObservedObject var manager: TeamCalendarManager

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.initials)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.name)
                        .font(.headline)

                    Text(member.role.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor(member.role).opacity(0.2))
                        .foregroundColor(roleColor(member.role))
                        .cornerRadius(4)
                }

                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let timezone = TimeZone(identifier: member.timezone) {
                    Text(timezone.identifier.components(separatedBy: "/").last ?? member.timezone)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                manager.removeMember(member, from: team)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func roleColor(_ role: TeamRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .orange
        case .member: return .blue
        case .guest: return .gray
        }
    }
}

// MARK: - Add Member View

struct AddMemberView: View {
    let team: Team
    @ObservedObject var manager: TeamCalendarManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var selectedRole: TeamRole = .member
    @State private var selectedTimezone: String = TimeZone.current.identifier

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Team Member")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)

                    Picker("Role", selection: $selectedRole) {
                        ForEach(TeamRole.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        let member = TeamMember(
                            name: name,
                            email: email,
                            role: selectedRole,
                            timezone: selectedTimezone
                        )
                        manager.addMember(member, to: team)
                        dismiss()
                    } label: {
                        Text("Add Member")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty || email.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(name.isEmpty || email.isEmpty)
                }
                .padding()
            }
        }
        .frame(width: 400, height: 300)
    }
}

// MARK: - Team Availability View

struct TeamAvailabilityView: View {
    let team: Team
    @ObservedObject var manager: TeamCalendarManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedDate = Date()
    @State private var duration: TimeInterval = 3600
    @State private var availability: TeamAvailability?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Team Availability")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    Picker("Duration", selection: $duration) {
                        Text("30 min").tag(TimeInterval(1800))
                        Text("1 hour").tag(TimeInterval(3600))
                        Text("2 hours").tag(TimeInterval(7200))
                    }
                    .pickerStyle(.segmented)

                    Button("Check Availability") {
                        availability = manager.checkAvailability(for: team, on: selectedDate, duration: duration)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    if let availability = availability {
                        Divider()

                        ForEach(availability.timeSlots.filter { $0.availabilityPercentage >= 50 }, id: \.startTime) { slot in
                            AvailabilitySlotRow(slot: slot)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 600)
    }
}

struct AvailabilitySlotRow: View {
    let slot: TeamAvailability.AvailableTimeSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatTime(slot.startTime))
                    .font(.headline)
                Text("-")
                Text(formatTime(slot.endTime))
                    .font(.headline)

                Spacer()

                Text("\(Int(slot.availabilityPercentage))% available")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(availabilityColor.opacity(0.2))
                    .foregroundColor(availabilityColor)
                    .cornerRadius(12)
            }

            Text("\(slot.availableMembers.count) available, \(slot.unavailableMembers.count) busy")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private var availabilityColor: Color {
        if slot.availabilityPercentage >= 80 {
            return .green
        } else if slot.availabilityPercentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    TeamsListView()
}
