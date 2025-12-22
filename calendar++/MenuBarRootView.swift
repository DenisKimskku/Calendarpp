import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var googleCalendar: GoogleCalendarManager
    @StateObject private var keyboardHandler = KeyboardShortcutHandler.shared
    @State private var showWelcome = !UserDefaults.standard.bool(forKey: "hasSeenWelcome")

    var body: some View {
        ZStack {
            VisualEffectBackground()

            VStack(spacing: 8) {
                HeaderView()
                Divider().padding(.bottom, 4)
                MonthAndAgendaView()
                Spacer(minLength: 4)
                FooterView()
                    .environmentObject(keyboardHandler)
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
        .onChange(of: keyboardHandler.showQuickAdd) { show in
            if show {
                // Quick add will be shown by FooterView
            }
        }
        .onChange(of: keyboardHandler.shouldNavigateToToday) { navigate in
            if navigate {
                calendarVM.selectedDate = Date()
            }
        }
        .onChange(of: keyboardHandler.shouldOpenSettings) { open in
            if open {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshCalendar)) { _ in
            eventKit.reloadAllEvents()
            googleCalendar.refreshEventsIfNeeded()
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView(isPresented: $showWelcome)
                .environmentObject(eventKit)
        }
    }
}

// macOS 26+ liquid glass effect background
struct VisualEffectBackground: View {
    var body: some View {
        ZStack {
            // Base layer - thin material for liquid glass effect
            Rectangle()
                .fill(.thinMaterial)
                .opacity(0.95)

            // Add subtle gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.black.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle noise/grain texture for premium feel
            Rectangle()
                .fill(.white.opacity(0.02))
        }
        .ignoresSafeArea()
    }
}
