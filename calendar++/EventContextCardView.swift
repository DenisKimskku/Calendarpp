import SwiftUI
import AppKit

struct EventContextCardView: View {
    let event: EventSummary?

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }

    private var dateTimeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }

    var body: some View {
        if let event = event {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    Circle()
                        .fill(Color.fromNSColor(event.calendarColor))
                        .frame(width: 8, height: 8)
                }

                Text(dateTimeRange(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                        Text(location)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button {
                            openLocationInMaps(location)
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                                .labelStyle(.titleAndIcon)
                                .font(.caption2)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        openInCalendar(event)
                    } label: {
                        Label("Open in Calendar", systemImage: "calendar")
                            .font(.caption2)
                    }
                }
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 6)
        } else {
            EmptyView()
        }
    }

    private func dateTimeRange(for event: EventSummary) -> String {
        if event.isAllDay {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            return "All day • \(df.string(from: event.startDate))"
        } else {
            let datePart = DateFormatter.localizedString(from: event.startDate, dateStyle: .medium, timeStyle: .none)
            let start = timeFormatter.string(from: event.startDate)
            let end = timeFormatter.string(from: event.endDate)
            return "\(datePart) • \(start) – \(end)"
        }
    }

    private func openLocationInMaps(_ location: String) {
        let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInCalendar(_ event: EventSummary) {
        // simple way: open Calendar at the event's start date
        let seconds = event.startDate.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(seconds)") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension Color {
    static func fromNSColor(_ nsColor: NSColor) -> Color {
        return Color(nsColor.cgColor)
    }
}
