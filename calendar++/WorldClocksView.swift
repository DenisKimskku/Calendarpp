import SwiftUI
import Combine

struct WorldClocksView: View {
    @EnvironmentObject var settings: SettingsViewModel
    @State private var now: Date = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        if settings.worldClockTimeZones.isEmpty { 
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(settings.worldClockTimeZones, id: \.identifier) { tz in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cityName(for: tz))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(timeString(for: tz))
                            .font(.caption2).bold()
                    }
                    .padding(6)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
            }
            .onReceive(timer) { date in
                self.now = date
            }
        }
    }

    private func cityName(for tz: TimeZone) -> String {
        if let name = tz.identifier.split(separator: "/").last {
            return String(name).replacingOccurrences(of: "_", with: " ")
        }
        return tz.identifier
    }

    private func timeString(for tz: TimeZone) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        df.timeZone = tz
        return df.string(from: now)
    }
}
