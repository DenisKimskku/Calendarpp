import Foundation
import Combine

final class DeepWorkManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var endsAt: Date? = nil

    private var timer: Timer?

    func startDeepWork(durationMinutes: Int) {
        let now = Date()
        endsAt = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: now)
        isActive = true

        timer?.invalidate()
        if let endsAt {
            timer = Timer.scheduledTimer(withTimeInterval: endsAt.timeIntervalSince(now), repeats: false) { [weak self] _ in
                self?.endDeepWork()
            }
        }
    }

    func endDeepWork() {
        isActive = false
        endsAt = nil
        timer?.invalidate()
        timer = nil
    }

    var remainingMinutes: Int? {
        guard isActive, let endsAt else { return nil }
        let diff = Int(endsAt.timeIntervalSinceNow / 60)
        return max(diff, 0)
    }
}
