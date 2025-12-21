import Foundation
import Combine
import Combine

enum EventEnergy: String, CaseIterable, Identifiable {
    case low
    case normal
    case high
    case deepWork

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .low:      return "🔋"
        case .normal:   return "⚪️"
        case .high:     return "⚡️"
        case .deepWork: return "🧠"
        }
    }

    var label: String {
        switch self {
        case .low:      return "Low"
        case .normal:   return "Normal"
        case .high:     return "High"
        case .deepWork: return "Deep work"
        }
    }
}

final class EventEnergyStore: ObservableObject {
    // eventID -> energy
    @Published var energyByEventId: [String: EventEnergy] = [:]

    func energy(for eventId: String) -> EventEnergy? {
        energyByEventId[eventId]
    }

    func setEnergy(_ energy: EventEnergy?, for eventId: String) {
        if let energy {
            energyByEventId[eventId] = energy
        } else {
            energyByEventId.removeValue(forKey: eventId)
        }
    }
}
