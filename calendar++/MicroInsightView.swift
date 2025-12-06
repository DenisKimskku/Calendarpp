import SwiftUI

struct MicroInsightView: View {
    @EnvironmentObject var eventKit: EventKitManager

    var body: some View {
        if let insight = eventKit.simpleInsight() {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.caption)
                Text(insight)
                    .font(.caption2)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.top, 4)
        }
    }
}
