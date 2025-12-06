import SwiftUI

struct QuickAddEventView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var calendarVM: CalendarViewModel

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Double = 60
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick add")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("Title (e.g. Lunch)", text: $title)
                    .textFieldStyle(.roundedBorder)

                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 80)

                Stepper(value: $durationMinutes, in: 15...240, step: 15) {
                    Text("\(Int(durationMinutes))m")
                        .font(.caption2)
                        .frame(width: 40)
                }
                .frame(width: 80)

                Button {
                    createEvent()
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }

            TextField("Location (optional)", text: $location)
                .textFieldStyle(.roundedBorder)

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
    }

    private func createEvent() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        // Merge selectedDate's Y/M/D with chosen time's hour/minute
        let comps = calendar.dateComponents([.hour, .minute], from: startTime)
        let baseDate = calendarVM.selectedDate
        var baseComps = calendar.dateComponents([.year, .month, .day], from: baseDate)
        baseComps.hour = comps.hour
        baseComps.minute = comps.minute

        guard let start = calendar.date(from: baseComps) else {
            isSaving = false
            errorMessage = "Could not build start date."
            return
        }

        let end = start.addingTimeInterval(durationMinutes * 60)

        eventKit.createEvent(
            title: trimmedTitle,
            startDate: start,
            endDate: end,
            location: location.isEmpty ? nil : location
        ) { result in
            isSaving = false
            switch result {
            case .success:
                title = ""
                location = ""
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
