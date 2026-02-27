import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject var eventKit: EventKitManager
    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var calendarVM: CalendarViewModel
    @EnvironmentObject var googleCalendar: GoogleCalendarManager
    @EnvironmentObject var filterManager: CalendarFilterManager
    @EnvironmentObject var prepManager: MeetingPrepManager
    @EnvironmentObject var achievementsManager: ProductivityAchievementsManager
    @EnvironmentObject var reminders: ReminderManager
    @Environment(\.openWindow) private var openWindow
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

            if settings.enableMeetingPrep {
                MeetingPrepOverlay()
            }
        }
        .frame(width: 336, height: 432)
        .tint(settings.resolvedTintColor)
        .accentColor(settings.resolvedTintColor)
        .onAppear {
            eventKit.requestAccessIfNeeded()
            eventKit.reloadAllEvents(around: calendarVM.currentMonth)
            googleCalendar.refreshEventsIfNeeded(around: calendarVM.currentMonth, force: false)

            prepManager.setEnabled(settings.enableMeetingPrep)

            refreshDerivedData()
            refreshRemindersAccess()
        }
        .onChange(of: settings.enableMeetingPrep) { enabled in
            prepManager.setEnabled(enabled)
        }
        .onChange(of: googleCalendar.googleEvents) { newEvents in
            eventKit.setGoogleEvents(newEvents)
        }
        .onChange(of: eventKit.eventsByDay) { _ in
            refreshDerivedData()
        }
        .onChange(of: eventKit.googleEventsByDay) { _ in
            refreshDerivedData()
        }
        .onChange(of: filterManager.hiddenCalendarIds) { _ in
            refreshDerivedData()
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
                openSettingsWindow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshCalendar)) { _ in
            eventKit.reloadAllEvents(around: calendarVM.currentMonth)
            googleCalendar.refreshEventsIfNeeded(around: calendarVM.currentMonth, force: true)
        }
        .onChange(of: settings.showRemindersInAgenda) { _ in
            refreshRemindersAccess()
        }
        .popover(isPresented: $showWelcome) {
            WelcomeView(isPresented: $showWelcome)
                .environmentObject(eventKit)
        }
    }

    private func refreshDerivedData() {
        let visibleEvents = filterManager.filterEvents(eventKit.events)

        if settings.enableMeetingPrep {
            prepManager.updateUpcomingMeetings(events: visibleEvents)
        }

        achievementsManager.refreshComputedProgress(events: visibleEvents)
    }

    private func refreshRemindersAccess() {
        guard settings.showRemindersInAgenda else { return }
        reminders.requestAccessIfNeeded()
    }

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// macOS 26+ liquid glass effect background
struct VisualEffectBackground: View {
    var body: some View {
        ZStack {
            CalendarPPZenBackground()

            // Keep a touch of glass so it still feels like a menubar popover.
            Rectangle()
                .fill(.thinMaterial)
                .opacity(0.28)
        }
        .ignoresSafeArea()
    }
}
