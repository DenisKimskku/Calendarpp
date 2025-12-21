import SwiftUI

struct AgendaListView: View {
    @EnvironmentObject var eventKit: EventKitManager

    let date: Date

    private var formatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }

    var body: some View {
        let events = eventKit.events(on: date)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Events")
                    .font(.subheadline.bold())
                Spacer()
                Text(formattedDate(date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            if events.isEmpty {
                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: 6) {
                                Rectangle()
                                    .fill(Color(event.calendarColor))
                                    .frame(width: 3)
                                    .cornerRadius(1.5)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.caption)
                                        .lineLimit(1)

                                    Text(eventTimeText(for: event))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if let location = event.location, !location.isEmpty {
                                        Text(location)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(4)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func eventTimeText(for event: EventSummary) -> String {
        if event.isAllDay {
            return "All day"
        } else {
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            return "\(start) – \(end)"
        }
    }
}

// Helper to convert NSColor to SwiftUI Color
extension Color {
    init(_ nsColor: NSColor) {
        self.init(cgColor: nsColor.cgColor)
    }
}
