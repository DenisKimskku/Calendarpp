//
//  EventTemplatesManager.swift
//  calendar++
//
//  Manage saved event templates for quick creation
//

import Foundation
import Combine

struct EventTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var title: String
    var durationMinutes: Int
    var location: String?
    var notes: String?

    init(id: UUID = UUID(), name: String, title: String, durationMinutes: Int, location: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.title = title
        self.durationMinutes = durationMinutes
        self.location = location
        self.notes = notes
    }
}

class EventTemplatesManager: ObservableObject {
    @Published var templates: [EventTemplate] = []

    private let userDefaultsKey = "savedEventTemplates"

    init() {
        loadTemplates()
    }

    // MARK: - Template Management

    func addTemplate(_ template: EventTemplate) {
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(_ template: EventTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
        }
    }

    func deleteTemplate(_ template: EventTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }

    // MARK: - Persistence

    private func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error saving templates: \(error)")
        }
    }

    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            // Load default templates on first launch
            loadDefaultTemplates()
            return
        }

        do {
            templates = try JSONDecoder().decode([EventTemplate].self, from: data)
        } catch {
            print("Error loading templates: \(error)")
            loadDefaultTemplates()
        }
    }

    private func loadDefaultTemplates() {
        templates = [
            EventTemplate(
                name: "Daily Standup",
                title: "Daily Standup",
                durationMinutes: 15,
                location: nil,
                notes: "Team sync-up meeting"
            ),
            EventTemplate(
                name: "1-on-1",
                title: "1-on-1 Meeting",
                durationMinutes: 30,
                location: nil,
                notes: "Regular one-on-one check-in"
            ),
            EventTemplate(
                name: "Lunch Break",
                title: "Lunch",
                durationMinutes: 60,
                location: nil,
                notes: nil
            ),
            EventTemplate(
                name: "Focus Time",
                title: "Focus Time - Deep Work",
                durationMinutes: 120,
                location: nil,
                notes: "Uninterrupted focus session"
            )
        ]
        saveTemplates()
    }
}
