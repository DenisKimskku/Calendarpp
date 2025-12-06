import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var calendarVM: CalendarViewModel

    var body: some View {
        ZStack {
            VisualEffectBackground()

            VStack(spacing: 8) {
                HeaderView()
                Divider().padding(.bottom, 4)
                MonthAndAgendaView()
                Spacer(minLength: 4)
                FooterView()
            }
            .padding(12)
        }
        .onAppear {
            eventKit.requestAccessIfNeeded()
            eventKit.reloadAllEvents()
        }
    }
}

// Simple material background wrapper for clarity
struct VisualEffectBackground: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThickMaterial)
            .ignoresSafeArea()
    }
}
