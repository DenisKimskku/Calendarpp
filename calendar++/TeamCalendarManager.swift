//
//  TeamCalendarManager.swift
//  calendar++
//
//  Manages team calendars and shared availability
//

import Foundation
import EventKit
import Combine
import SwiftUI

// MARK: - Team Model

struct Team: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var members: [TeamMember]
    var sharedCalendarIDs: [String]
    var color: CodableColor
    var isDefault: Bool
    var createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        members: [TeamMember] = [],
        sharedCalendarIDs: [String] = [],
        color: CodableColor = CodableColor(color: .blue),
        isDefault: Bool = false,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.members = members
        self.sharedCalendarIDs = sharedCalendarIDs
        self.color = color
        self.isDefault = isDefault
        self.createdDate = createdDate
    }
}

// MARK: - Team Member

struct TeamMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String
    var role: TeamRole
    var calendarURL: String? // iCal subscription URL for their calendar
    var timezone: String
    var workingHours: WorkingHours?
    var avatarURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        role: TeamRole = .member,
        calendarURL: String? = nil,
        timezone: String = TimeZone.current.identifier,
        workingHours: WorkingHours? = nil,
        avatarURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.calendarURL = calendarURL
        self.timezone = timezone
        self.workingHours = workingHours
        self.avatarURL = avatarURL
    }

    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

enum TeamRole: String, Codable, CaseIterable {
    case owner = "Owner"
    case admin = "Admin"
    case member = "Member"
    case guest = "Guest"

    var canManageTeam: Bool {
        return self == .owner || self == .admin
    }

    var canInviteMembers: Bool {
        return self != .guest
    }
}

// MARK: - Working Hours

struct WorkingHours: Codable, Hashable, Equatable {
    var monday: DaySchedule?
    var tuesday: DaySchedule?
    var wednesday: DaySchedule?
    var thursday: DaySchedule?
    var friday: DaySchedule?
    var saturday: DaySchedule?
    var sunday: DaySchedule?

    struct DaySchedule: Codable, Hashable, Equatable {
        var startTime: TimeInterval // Seconds from midnight
        var endTime: TimeInterval
        var isWorkingDay: Bool

        var startTimeFormatted: String {
            let hours = Int(startTime / 3600)
            let minutes = Int((startTime.truncatingRemainder(dividingBy: 3600)) / 60)
            return String(format: "%02d:%02d", hours, minutes)
        }

        var endTimeFormatted: String {
            let hours = Int(endTime / 3600)
            let minutes = Int((endTime.truncatingRemainder(dividingBy: 3600)) / 60)
            return String(format: "%02d:%02d", hours, minutes)
        }
    }

    static var standard: WorkingHours {
        let workDay = DaySchedule(startTime: 9 * 3600, endTime: 17 * 3600, isWorkingDay: true)
        return WorkingHours(
            monday: workDay,
            tuesday: workDay,
            wednesday: workDay,
            thursday: workDay,
            friday: workDay,
            saturday: nil,
            sunday: nil
        )
    }

    func isWorkingTime(date: Date, timezone: TimeZone) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: timezone, from: date)

        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else {
            return false
        }

        let secondsFromMidnight = TimeInterval(hour * 3600 + minute * 60)

        let schedule: DaySchedule?
        switch weekday {
        case 1: schedule = sunday
        case 2: schedule = monday
        case 3: schedule = tuesday
        case 4: schedule = wednesday
        case 5: schedule = thursday
        case 6: schedule = friday
        case 7: schedule = saturday
        default: schedule = nil
        }

        guard let daySchedule = schedule, daySchedule.isWorkingDay else {
            return false
        }

        return secondsFromMidnight >= daySchedule.startTime && secondsFromMidnight <= daySchedule.endTime
    }
}

// MARK: - Team Availability

struct TeamAvailability {
    let team: Team
    let timeSlots: [AvailableTimeSlot]

    struct AvailableTimeSlot {
        let startTime: Date
        let endTime: Date
        let availableMembers: [TeamMember]
        let unavailableMembers: [TeamMember]

        var availabilityPercentage: Double {
            let total = availableMembers.count + unavailableMembers.count
            guard total > 0 else { return 0 }
            return Double(availableMembers.count) / Double(total) * 100
        }
    }
}

// MARK: - Team Calendar Manager

class TeamCalendarManager: ObservableObject {
    @Published var teams: [Team] = []
    @Published var currentMember: TeamMember?

    private let teamsKey = "teams"
    private let currentMemberKey = "current_member"
    private let eventStore = EKEventStore()

    init() {
        loadTeams()
        loadCurrentMember()
    }

    // MARK: - Team Management

    func createTeam(name: String, description: String = "") -> Team {
        let team = Team(
            name: name,
            description: description,
            members: currentMember != nil ? [currentMember!] : []
        )
        teams.append(team)
        saveTeams()
        return team
    }

    func updateTeam(_ team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            saveTeams()
        }
    }

    func deleteTeam(_ team: Team) {
        teams.removeAll { $0.id == team.id }
        saveTeams()
    }

    func getTeam(id: UUID) -> Team? {
        return teams.first { $0.id == id }
    }

    // MARK: - Member Management

    func addMember(_ member: TeamMember, to team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index].members.append(member)
            saveTeams()
        }
    }

    func removeMember(_ member: TeamMember, from team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index].members.removeAll { $0.id == member.id }
            saveTeams()
        }
    }

    func updateMember(_ member: TeamMember, in team: Team) {
        if let teamIndex = teams.firstIndex(where: { $0.id == team.id }),
           let memberIndex = teams[teamIndex].members.firstIndex(where: { $0.id == member.id }) {
            teams[teamIndex].members[memberIndex] = member
            saveTeams()
        }
    }

    func setCurrentMember(_ member: TeamMember) {
        currentMember = member
        saveCurrentMember()
    }

    // MARK: - Availability Checking

    func checkAvailability(
        for team: Team,
        on date: Date,
        duration: TimeInterval
    ) -> TeamAvailability {
        var timeSlots: [TeamAvailability.AvailableTimeSlot] = []

        // Check each hour of the day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        for hour in 0..<24 {
            guard let slotStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
                  let slotEnd = calendar.date(byAdding: .second, value: Int(duration), to: slotStart) else {
                continue
            }

            var available: [TeamMember] = []
            var unavailable: [TeamMember] = []

            for member in team.members {
                if isMemberAvailable(member, from: slotStart, to: slotEnd) {
                    available.append(member)
                } else {
                    unavailable.append(member)
                }
            }

            let slot = TeamAvailability.AvailableTimeSlot(
                startTime: slotStart,
                endTime: slotEnd,
                availableMembers: available,
                unavailableMembers: unavailable
            )

            timeSlots.append(slot)
        }

        return TeamAvailability(team: team, timeSlots: timeSlots)
    }

    func isMemberAvailable(_ member: TeamMember, from startDate: Date, to endDate: Date) -> Bool {
        // Check working hours
        guard let timezone = TimeZone(identifier: member.timezone),
              let workingHours = member.workingHours else {
            return true // Assume available if no working hours set
        }

        if !workingHours.isWorkingTime(date: startDate, timezone: timezone) {
            return false
        }

        // Check calendar events if calendar URL is available
        if member.calendarURL != nil {
            // In production, fetch and parse iCal feed
            // For now, assume available
            return true
        }

        return true
    }

    func findBestMeetingTime(
        for team: Team,
        duration: TimeInterval,
        within days: Int = 7,
        minimumAttendees: Int? = nil
    ) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        var candidates: [Date] = []

        let minAttendees = minimumAttendees ?? team.members.count

        for day in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: day, to: now) else {
                continue
            }

            let availability = checkAvailability(for: team, on: date, duration: duration)

            for slot in availability.timeSlots {
                if slot.availableMembers.count >= minAttendees {
                    candidates.append(slot.startTime)
                }
            }
        }

        return candidates
    }

    // MARK: - Shared Calendar Management

    func addSharedCalendar(_ calendarID: String, to team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            if !teams[index].sharedCalendarIDs.contains(calendarID) {
                teams[index].sharedCalendarIDs.append(calendarID)
                saveTeams()
            }
        }
    }

    func removeSharedCalendar(_ calendarID: String, from team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index].sharedCalendarIDs.removeAll { $0 == calendarID }
            saveTeams()
        }
    }

    func getSharedEvents(for team: Team, from startDate: Date, to endDate: Date) -> [EventSummary] {
        var allEvents: [EventSummary] = []

        for calendarID in team.sharedCalendarIDs {
            guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
                continue
            }

            let predicate = eventStore.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: [calendar]
            )

            let ekEvents = eventStore.events(matching: predicate)

	            let events = ekEvents.map { event in
	                EventSummary(
	                    id: event.eventIdentifier ?? UUID().uuidString,
	                    title: event.title ?? "No Title",
	                    startDate: event.startDate,
	                    endDate: event.endDate,
	                    isAllDay: event.isAllDay,
	                    calendarId: event.calendar.calendarIdentifier,
	                    calendarName: event.calendar.title,
	                    calendarColor: NSColor(cgColor: event.calendar.cgColor ?? NSColor.blue.cgColor) ?? .blue,
	                    location: event.location,
	                    notes: event.notes
	                )
	            }

            allEvents.append(contentsOf: events)
        }

        return allEvents.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Team Statistics

    func getTeamStats(for team: Team) -> TeamStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!

        let events = getSharedEvents(for: team, from: startOfWeek, to: endOfWeek)

        var totalMeetingTime: TimeInterval = 0
        var meetingCount = 0

        for event in events {
            totalMeetingTime += event.endDate.timeIntervalSince(event.startDate)
            meetingCount += 1
        }

        let avgMeetingDuration = meetingCount > 0 ? totalMeetingTime / Double(meetingCount) : 0

        return TeamStats(
            memberCount: team.members.count,
            sharedCalendarCount: team.sharedCalendarIDs.count,
            weeklyMeetingCount: meetingCount,
            totalWeeklyMeetingTime: totalMeetingTime,
            averageMeetingDuration: avgMeetingDuration
        )
    }

    struct TeamStats {
        let memberCount: Int
        let sharedCalendarCount: Int
        let weeklyMeetingCount: Int
        let totalWeeklyMeetingTime: TimeInterval
        let averageMeetingDuration: TimeInterval
    }

    // MARK: - Persistence

    private func saveTeams() {
        if let encoded = try? JSONEncoder().encode(teams) {
            UserDefaults.standard.set(encoded, forKey: teamsKey)
        }
    }

    private func loadTeams() {
        if let data = UserDefaults.standard.data(forKey: teamsKey),
           let decoded = try? JSONDecoder().decode([Team].self, from: data) {
            teams = decoded
        }
    }

    private func saveCurrentMember() {
        if let encoded = try? JSONEncoder().encode(currentMember) {
            UserDefaults.standard.set(encoded, forKey: currentMemberKey)
        }
    }

    private func loadCurrentMember() {
        if let data = UserDefaults.standard.data(forKey: currentMemberKey),
           let decoded = try? JSONDecoder().decode(TeamMember.self, from: data) {
            currentMember = decoded
        }
    }
}
