import SwiftUI
import AppKit
import EventKit

private enum MainWindowSection: Hashable {
    case calendar
    case features
    case search
}

struct MainWindowView: View {
    @EnvironmentObject private var calendarVM: CalendarViewModel
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.openWindow) private var openWindow

    @StateObject private var keyboardHandler = KeyboardShortcutHandler.shared
    @State private var selection: MainWindowSection? = .calendar
    @State private var showingQuickAdd = false

    private var splitViewVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { settings.uiSidebarHidden ? .detailOnly : .all },
            set: { newValue in
                settings.uiSidebarHidden = (newValue == .detailOnly)
            }
        )
    }

    var body: some View {
        ZStack {
            CalendarPPZenBackground()

            NavigationSplitView(columnVisibility: splitViewVisibility) {
                ZenSidebarView(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                Group {
                    switch selection ?? .calendar {
                    case .calendar:
                        CalendarMainView()
                    case .features:
                        FeaturesHubView()
                    case .search:
                        SearchView()
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .calendarPPZenCard(cornerRadius: CalendarPPZenStyle.cornerRadius, strong: true)
                .padding(14)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button {
                            settings.uiSidebarHidden.toggle()
                        } label: {
                            Image(systemName: "sidebar.leading")
                        }
                        .help(settings.uiSidebarHidden ? "Show sidebar" : "Hide sidebar")

                        Button {
                            showingQuickAdd = true
                        } label: {
                            Label("New Event", systemImage: "plus")
                        }
                        .help("Create a new event")

                        Button {
                            openSettingsWindow()
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showingQuickAdd) {
                    QuickAddEventView(isPresented: $showingQuickAdd)
                        .padding(16)
                        .frame(width: 540)
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .tint(settings.resolvedTintColor)
        .accentColor(settings.resolvedTintColor)
        .onChange(of: keyboardHandler.showQuickAdd) { show in
            if show {
                showingQuickAdd = true
                keyboardHandler.showQuickAdd = false
            }
        }
        .onChange(of: keyboardHandler.shouldOpenSettings) { open in
            if open {
                openSettingsWindow()
            }
        }
        .onChange(of: keyboardHandler.shouldNavigateToToday) { navigate in
            if navigate {
                calendarVM.goToToday()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMainSearch)) { _ in
            selection = .search
            settings.uiSidebarHidden = false
        }
    }

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private struct CalendarMainView: View {
    @EnvironmentObject private var calendarVM: CalendarViewModel
    @EnvironmentObject private var eventKit: EventKitManager
    @EnvironmentObject private var googleCalendar: GoogleCalendarManager
    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var reminders: ReminderManager
    @EnvironmentObject private var filterManager: CalendarFilterManager

    @State private var showWeekView = false
    @State private var inspectedEvent: EventSummary?

    private let calendar = Calendar.current

    private var weekdaySymbols: [String] {
        var cal = calendar
        cal.firstWeekday = settings.firstWeekdayIsMonday ? 2 : 1
        let symbols = cal.shortWeekdaySymbols
        let startIndex = cal.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    var body: some View {
        GeometryReader { proxy in
            let shouldShowInspector = {
                switch settings.resolvedInspectorMode {
                case .auto:
                    return proxy.size.width >= 1120
                case .always:
                    return true
                case .never:
                    return false
                }
            }()
            let selectedDayEvents = filterManager.filterEvents(eventKit.events(on: calendarVM.selectedDate))

            Group {
                if shouldShowInspector {
                    HSplitView {
                        calendarColumn(totalHeight: proxy.size.height)
                            .frame(minWidth: 620)
                            .layoutPriority(1)

                        EventInspectorPanel(
                            date: calendarVM.selectedDate,
                            events: selectedDayEvents,
                            inspectedEvent: $inspectedEvent
                        )
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                        .padding(.leading, 8)
                    }
                } else {
                    calendarColumn(totalHeight: proxy.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .popover(
                item: Binding<EventSummary?>(
                    get: { shouldShowInspector ? nil : inspectedEvent },
                    set: { inspectedEvent = $0 }
                )
            ) { event in
                EventDetailPopover(event: event)
            }
        }
        .onAppear {
            eventKit.requestAccessIfNeeded()
            eventKit.reloadAllEvents(around: calendarVM.currentMonth)
            googleCalendar.refreshEventsIfNeeded(around: calendarVM.currentMonth, force: false)
            refreshReminders()
        }
        .onChange(of: calendarVM.selectedDate) { newDate in
            guard let inspectedEvent else { return }
            if !calendar.isDate(inspectedEvent.startDate, inSameDayAs: newDate) {
                self.inspectedEvent = nil
            }
        }
        .onChange(of: calendarVM.currentMonth) { newMonth in
            eventKit.reloadAllEvents(around: newMonth)
            googleCalendar.refreshEventsIfNeeded(around: newMonth, force: false)
            refreshReminders()
        }
        .onChange(of: googleCalendar.googleEvents) { newEvents in
            eventKit.setGoogleEvents(newEvents)
        }
        .onChange(of: settings.showRemindersInAgenda) { _ in
            refreshReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshCalendar)) { _ in
            refreshCalendars()
        }
    }

    private func calendarColumn(totalHeight: CGFloat) -> some View {
        let agendaHeight = max(168, min(260, totalHeight * 0.26))

        return GeometryReader { proxy in
            let compactHeader = proxy.size.width < 960

            VStack(spacing: 12) {
                header(compact: compactHeader)
                    .frame(height: compactHeader ? 86 : 48, alignment: .top)

                Group {
                    if showWeekView {
                        WeekView(weekStartDate: startOfWeek, maxHeight: nil, inspectedEvent: $inspectedEvent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        monthGrid()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .clipped()

                Divider()
                    .overlay(CalendarPPZenStyle.stroke)

                AgendaListView(date: calendarVM.selectedDate, maxHeight: nil, inspectedEvent: $inspectedEvent)
                    .padding(10)
                    .calendarPPZenCard(cornerRadius: 14, strong: false)
                    .frame(minHeight: agendaHeight, maxHeight: agendaHeight, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 0) {
            if compact {
                HStack(spacing: 10) {
                    monthTitleLabel
                    Spacer(minLength: 0)
                    monthNavigationControl
                }

                HStack(spacing: 8) {
                    todayControl
                    viewModeControl
                    Spacer(minLength: 0)
                    refreshControl
                }
            } else {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        todayControl
                        viewModeControl
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    monthTitleLabel
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack(spacing: 8) {
                        refreshControl
                        monthNavigationControl
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.top, 2)
    }

    private var monthTitleLabel: some View {
        Text(calendarVM.monthTitle)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .layoutPriority(1)
    }

    private var todayControl: some View {
        Button {
            calendarVM.goToToday()
        } label: {
            Text("Today")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .calendarPPZenCard(cornerRadius: 999, strong: false)
        .frame(height: 30)
        .keyboardShortcut("t", modifiers: .command)
    }

    private var viewModeControl: some View {
        Picker("View", selection: $showWeekView) {
            Text("Month").tag(false)
            Text("Week").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 140)
        .controlSize(.small)
        .frame(height: 30)
    }

    private var refreshControl: some View {
        Button {
            refreshCalendars()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .calendarPPZenCard(cornerRadius: 999, strong: false)
        .help("Refresh calendars")
    }

    private var monthNavigationControl: some View {
        HStack(spacing: 6) {
            Button {
                calendarVM.changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Previous month")

            Button {
                calendarVM.changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Next month")
        }
        .calendarPPZenCard(cornerRadius: 999, strong: false)
        .frame(width: 76, height: 30, alignment: .trailing)
    }

    private func monthGrid() -> some View {
        let dates = calendarVM.daysForCurrentMonth(firstWeekdayIsMonday: settings.firstWeekdayIsMonday)
        let weekRows = CGFloat(max(1, Int(ceil(Double(dates.count) / 7.0))))
        let weekdayHeaderHeight: CGFloat = 18
        return GeometryReader { proxy in
            let availableHeight = max(1, proxy.size.height)
            let rowSpacing: CGFloat = availableHeight < 450 ? 6 : 8
            let rawCellHeight = (availableHeight - weekdayHeaderHeight - 8 - (rowSpacing * (weekRows - 1))) / weekRows
            let dayCellHeight = max(32, min(132, rawCellHeight))
            let eventRowLimit = dayCellHeight < 52 ? 0 : (dayCellHeight < 70 ? 1 : (dayCellHeight < 92 ? 2 : (dayCellHeight < 114 ? 3 : 4)))

            VStack(spacing: 8) {
                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: monthColumns, spacing: rowSpacing) {
                    ForEach(dates, id: \.self) { date in
                        let allEvents = filterManager.filterEvents(eventKit.events(on: date))
                        let remindersForDay = settings.showRemindersInAgenda ? reminders.reminders(on: date) : []

                        LargeDayCellView(
                            date: date,
                            isInCurrentMonth: calendarVM.isInCurrentMonth(date),
                            isSelected: calendarVM.isSameDay(date, calendarVM.selectedDate),
                            isToday: calendar.isDateInToday(date),
                            events: allEvents,
                            maxVisibleEvents: eventRowLimit,
                            dayCellHeight: dayCellHeight,
                            remindersCount: remindersForDay.count,
                            onSelectEvent: { event in
                                calendarVM.selectedDate = date
                                inspectedEvent = event
                            }
                        )
                        .onTapGesture {
                            calendarVM.selectedDate = date
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
    }

    private var monthColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 88, maximum: 260), spacing: 8), count: 7)
    }

    private var startOfWeek: Date {
        var cal = calendar
        cal.firstWeekday = settings.firstWeekdayIsMonday ? 2 : 1
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: calendarVM.selectedDate)
        return cal.date(from: components) ?? calendarVM.selectedDate
    }

    private func refreshCalendars() {
        eventKit.reloadAllEvents(around: calendarVM.currentMonth)
        googleCalendar.refreshEventsIfNeeded(around: calendarVM.currentMonth, force: true)
    }

    private func refreshReminders() {
        guard settings.showRemindersInAgenda else { return }
        reminders.requestAccessIfNeeded()
        reminders.reloadReminders(range: remindersRange(around: calendarVM.currentMonth))
    }

    private func remindersRange(around anchorDate: Date) -> DateInterval {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate))
            ?? calendar.startOfDay(for: anchorDate)

        let start = calendar.date(byAdding: .day, value: -14, to: startOfMonth) ?? startOfMonth
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? anchorDate
        let end = calendar.date(byAdding: .day, value: 14, to: endOfMonth) ?? endOfMonth

        return DateInterval(start: start, end: end)
    }
}

private struct LargeDayCellView: View {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let events: [EventSummary]
    let maxVisibleEvents: Int
    let dayCellHeight: CGFloat
    let remindersCount: Int
    let onSelectEvent: ((EventSummary) -> Void)?

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var compactTimeFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .autoupdatingCurrent
        df.dateFormat = "HH:mm"
        return df
    }

    private var visibleEvents: [EventSummary] {
        Array(events.prefix(maxVisibleEvents))
    }

    private var additionalCount: Int {
        max(0, events.count - visibleEvents.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(dayString)
                    .font(.system(size: 13, weight: isToday || isSelected ? .semibold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isInCurrentMonth ? .primary : .secondary)

                if isToday {
                    Text("Today")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                        )
                }

                Spacer(minLength: 0)

                if remindersCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "checklist")
                        Text("\(remindersCount)")
                            .monospacedDigit()
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(visibleEvents, id: \.id) { event in
                    Button {
                        onSelectEvent?(event)
                    } label: {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(event.calendarColor))
                                .frame(width: 3, height: 10)

                            Text(event.isAllDay ? "All-day" : compactTimeFormatter.string(from: event.startDate))
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(width: 44, alignment: .leading)

                            Text(event.title)
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }

                if additionalCount > 0 {
                    Text("+\(additionalCount) more")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(minHeight: dayCellHeight, maxHeight: dayCellHeight)
        .background(background)
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isInCurrentMonth ? 1.0 : 0.58)
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(isSelected ? 0.12 : 0.0))
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(
                isSelected ? Color.accentColor.opacity(0.5) :
                (isToday ? Color.accentColor.opacity(0.85) : CalendarPPZenStyle.stroke),
                lineWidth: isSelected || isToday ? 1.6 : 1
            )
    }
}

private struct EventInspectorPanel: View {
    @EnvironmentObject private var eventKit: EventKitManager

    let date: Date
    let events: [EventSummary]
    @Binding var inspectedEvent: EventSummary?

    @State private var confirmDelete = false

    private var dayHeader: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"
        return df.string(from: date)
    }

    private var daySubheader: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayHeader)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(daySubheader)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if inspectedEvent != nil {
                    Button("Clear") {
                        inspectedEvent = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }

            Divider()
                .overlay(CalendarPPZenStyle.stroke)

            if let event = inspectedEvent {
                inspectedEventView(event)
            } else {
                emptyInspectorView
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .calendarPPZenCard(cornerRadius: 16, strong: false)
        .alert("Delete Event?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let inspectedEvent {
                    eventKit.deleteEvent(withId: inspectedEvent.id)
                    self.inspectedEvent = nil
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func inspectedEventView(_ event: EventSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(event.calendarColor))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.calendarName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                inspectorRow(systemImage: "clock", title: timeText(for: event))

                if let location = event.location, !location.isEmpty {
                    inspectorRow(systemImage: "mappin.and.ellipse", title: location)
                }

                if let notes = event.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inspectorRow(systemImage: "note.text", title: notes, isMultiline: true)
                }
            }

            Divider()
                .overlay(CalendarPPZenStyle.stroke)

            HStack(spacing: 10) {
                Button {
                    copyEventDetails(event)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderless)

                Button {
                    openCalendarApp()
                } label: {
                    Label("Open Calendar", systemImage: "calendar")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderless)

                if let url = extractMeetingURL(from: event) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Join", systemImage: "video.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.borderless)
                }

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    if event.id.hasPrefix("google-") {
                        // read-only
                    } else {
                        confirmDelete = true
                    }
                } label: {
                    Image(systemName: event.id.hasPrefix("google-") ? "lock" : "trash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help(event.id.hasPrefix("google-") ? "Google events are read-only." : "Delete event")
                .disabled(event.id.hasPrefix("google-"))
            }
        }
    }

    private var emptyInspectorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            if events.isEmpty {
                Text("Select an event to see details.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events.prefix(6)) { event in
                        Button {
                            inspectedEvent = event
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color(event.calendarColor))
                                    .frame(width: 3, height: 12)

                                Text(timeTextCompact(for: event))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 58, alignment: .leading)

                                Text(event.title)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .calendarPPZenCard(cornerRadius: 12, strong: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func inspectorRow(systemImage: String, title: String, isMultiline: Bool = false) -> some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            if isMultiline {
                ScrollView {
                    Text(title)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            } else {
                Text(title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
    }

    private func timeText(for event: EventSummary) -> String {
        if event.isAllDay { return "All day" }

        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        let start = df.string(from: event.startDate)
        let end = df.string(from: event.endDate)
        return "\(start) – \(end)"
    }

    private func timeTextCompact(for event: EventSummary) -> String {
        if event.isAllDay { return "All day" }

        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: event.startDate)
    }

    private func copyEventDetails(_ event: EventSummary) {
        var details = "\(event.title)\n"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if event.isAllDay {
            details += "All day on \(formatter.string(from: event.startDate))\n"
        } else {
            details += "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))\n"
        }

        if let location = event.location, !location.isEmpty {
            details += "Location: \(location)\n"
        }
        details += "Calendar: \(event.calendarName)"

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(details, forType: .string)
    }

    private func openCalendarApp() {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            workspace.openApplication(at: url, configuration: .init(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        }
    }

    private func extractMeetingURL(from event: EventSummary) -> URL? {
        let candidates = [event.location, event.notes].compactMap { $0 }.filter { !$0.isEmpty }
        for text in candidates {
            if text.contains("zoom.us"), let url = urlFrom(text) { return url }
            if text.contains("meet.google.com"), let url = urlFrom(text) { return url }
            if text.contains("teams.microsoft.com"), let url = urlFrom(text) { return url }
            if let url = urlFrom(text) { return url }
        }
        return nil
    }

    private func urlFrom(_ text: String) -> URL? {
        if let direct = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), direct.scheme != nil {
            return direct
        }

        let pattern = "https?://[^\\s]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        guard let range = Range(match.range, in: text) else { return nil }
        return URL(string: String(text[range]))
    }
}

private struct ZenSidebarView: View {
    @Binding var selection: MainWindowSection?

    @EnvironmentObject private var calendarVM: CalendarViewModel
    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var eventKit: EventKitManager
    @EnvironmentObject private var filterManager: CalendarFilterManager
    @EnvironmentObject private var googleCalendar: GoogleCalendarManager

    private let googleCalendarId = "google-primary"

    private var weekdaySymbols: [String] {
        var cal = Calendar.current
        cal.firstWeekday = settings.firstWeekdayIsMonday ? 2 : 1
        let symbols = cal.veryShortWeekdaySymbols
        let startIndex = cal.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private let monthColumns: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 18, maximum: 28), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Navigation")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                if settings.uiSidebarShowsMiniMonth {
                    miniMonth
                }

                VStack(alignment: .leading, spacing: 6) {
                    SidebarNavRow(
                        title: "Calendar",
                        systemImage: "calendar",
                        isSelected: selection == .calendar
                    ) {
                        selection = .calendar
                    }

                    SidebarNavRow(
                        title: "Search",
                        systemImage: "magnifyingglass",
                        isSelected: selection == .search
                    ) {
                        selection = .search
                    }

                    SidebarNavRow(
                        title: "Features",
                        systemImage: "sparkles",
                        isSelected: selection == .features
                    ) {
                        selection = .features
                    }
                }
                .padding(10)
                .calendarPPZenCard(cornerRadius: 14, strong: false)

                calendarsCard
            }
            .padding(16)
        }
    }

    private var availableCalendars: [EKCalendar] {
        eventKit.calendars().sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var miniMonth: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(calendarVM.monthTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Button {
                        calendarVM.changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Button {
                        calendarVM.changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 22)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .calendarPPZenCard(cornerRadius: 999, strong: false)
            }

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: monthColumns, spacing: 6) {
                ForEach(calendarVM.daysForCurrentMonth(firstWeekdayIsMonday: settings.firstWeekdayIsMonday), id: \.self) { day in
                    let isSelected = calendarVM.isSameDay(day, calendarVM.selectedDate)
                    let isToday = Calendar.current.isDateInToday(day)
                    let isInMonth = calendarVM.isInCurrentMonth(day)
                    let visibleEvents = filterManager.filterEvents(eventKit.events(on: day))
                    let hasEvents = !visibleEvents.isEmpty

                    Button {
                        calendarVM.selectedDate = day
                        if !isInMonth {
                            let cal = Calendar.current
                            calendarVM.currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: day)) ?? day
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.system(size: 11, weight: isToday ? .semibold : .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? .white : (isInMonth ? .primary : .secondary))
                                .frame(maxWidth: .infinity)

                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : (hasEvents ? Color.accentColor.opacity(0.9) : Color.clear))
                                .frame(width: 4, height: 4)
                        }
                        .frame(height: 24)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.95) : Color.clear)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(!isSelected && isToday ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1.5)
                                )
                        )
                        .opacity(isInMonth ? 1.0 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }

    private var calendarsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Calendars")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)

                Button("All") {
                    filterManager.showAllCalendars()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(filterManager.hiddenCalendarIds.isEmpty ? .secondary : Color.accentColor)
                .disabled(filterManager.hiddenCalendarIds.isEmpty)
            }

            Divider()
                .overlay(CalendarPPZenStyle.stroke)

            if availableCalendars.isEmpty && !googleCalendar.isAuthenticated {
                Text("No calendars available.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                            CalendarVisibilityRow(
                                title: calendar.title,
                                color: Color(calendar.color),
                                isVisible: filterManager.isCalendarVisible(calendarId: calendar.calendarIdentifier, calendarName: calendar.title)
                            ) {
                                filterManager.toggleCalendar(calendarId: calendar.calendarIdentifier, calendarName: calendar.title)
                            }
                        }

                        if googleCalendar.isAuthenticated {
                            CalendarVisibilityRow(
                                title: "Google Calendar",
                                color: .blue,
                                isVisible: filterManager.isCalendarVisible(calendarId: googleCalendarId, calendarName: "Google Calendar")
                            ) {
                                filterManager.toggleCalendar(calendarId: googleCalendarId, calendarName: "Google Calendar")
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(10)
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }
}

private struct SidebarNavRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarVisibilityRow: View {
    let title: String
    let color: Color
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isVisible ? Color.accentColor : .secondary)

                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isVisible ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isVisible ? Color.clear : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
