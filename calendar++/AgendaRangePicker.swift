import SwiftUI

struct AgendaRangePicker: View {
    @EnvironmentObject var settings: SettingsViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AgendaRange.allCases) { range in
                Button {
                    settings.agendaRange = range
                } label: {
                    Text(range.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(settings.agendaRange == range ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 4)
    }
}
