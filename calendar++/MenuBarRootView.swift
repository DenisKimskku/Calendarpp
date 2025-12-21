import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

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
        .frame(width: 320, height: 400)
        .onAppear {
            eventKit.requestAccessIfNeeded()
            eventKit.reloadAllEvents()
            googleCalendar.refreshEventsIfNeeded()
        }
        .onChange(of: googleCalendar.googleEvents) { newEvents in
            eventKit.setGoogleEvents(newEvents)
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
