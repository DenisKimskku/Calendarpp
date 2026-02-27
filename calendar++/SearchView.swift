//
//  SearchView.swift
//  calendar++
//
//  UI for searching and filtering events
//

import SwiftUI

struct SearchView: View {
    @StateObject private var searchManager = SearchManager()
    @EnvironmentObject var categoriesManager: EventCategoriesManager
    @EnvironmentObject var eventKit: EventKitManager

    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var currentFilter = SearchFilter()

    @State private var showingFilterSheet = false
    @State private var showingHistory = false
    @State private var showingSaveFilterSheet = false

    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            // Search Bar
            searchBar

            // Quick Filters
            quickFiltersBar

            // Search Results
            if searchManager.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                emptyResultsView
            } else {
                searchResultsList
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search events...", text: $searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchQuery) { _ in
                    // Real-time search for queries > 2 chars
                    if searchQuery.count > 2 {
                        performSearch()
                    } else if searchQuery.isEmpty {
                        searchResults = []
                    }
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }

            Spacer(minLength: 0)

            Button {
                showingHistory.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(showingHistory ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("History")
            .popover(isPresented: $showingHistory) {
                searchHistoryPopover
            }

            Button {
                showingFilterSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")

                    if hasActiveFilters {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                }
                .foregroundStyle(hasActiveFilters ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Filters")
            .calendarppModal(isPresented: $showingFilterSheet) {
                FilterSheetView(filter: $currentFilter, onApply: {
                    performSearch()
                })
                .environmentObject(categoriesManager)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }

    // MARK: - Quick Filters

    private var quickFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickFilterButton(title: "Today", icon: "calendar") {
                    currentFilter.dateRange = .today
                    performSearch()
                }

                QuickFilterButton(title: "This Week", icon: "calendar.badge.clock") {
                    currentFilter.dateRange = .thisWeek
                    performSearch()
                }

                QuickFilterButton(title: "This Month", icon: "calendar.circle") {
                    currentFilter.dateRange = .thisMonth
                    performSearch()
                }

                QuickFilterButton(title: "Uncategorized", icon: "tag.slash") {
                    let events = eventKit.fetchEvents()
                    searchResults = searchManager.quickFilterUncategorized(events: events, categoriesManager: categoriesManager)
                        .map { SearchResult(id: $0.id, event: $0, matchedFields: [], relevanceScore: 1.0) }
                }

                QuickFilterButton(title: "Recurring", icon: "repeat") {
                    let events = eventKit.fetchEvents()
                    searchResults = searchManager.quickFilterRecurring(events: events)
                        .map { SearchResult(id: $0.id, event: $0, matchedFields: [], relevanceScore: 1.0) }
                }

                // Saved Filters
                ForEach(searchManager.favoriteFilters) { filter in
                    QuickFilterButton(title: filter.name, icon: "star.fill") {
                        currentFilter = filter
                        searchQuery = filter.query
                        performSearch()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(searchResults) { result in
                    SearchResultRow(result: result, categoriesManager: categoriesManager)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Empty Results

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No results found")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try adjusting your search or filters")
                .font(.caption)
                .foregroundStyle(.secondary)

            if hasActiveFilters {
                Button("Clear Filters") {
                    currentFilter = SearchFilter()
                    performSearch()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search History Popover

    private var searchHistoryPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    searchManager.clearHistory()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()

            Divider()

            if searchManager.searchHistory.isEmpty {
                Text("No recent searches")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(searchManager.searchHistory, id: \.self) { query in
                            Button {
                                searchQuery = query
                                showingHistory = false
                                performSearch()
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text(query)
                                    Spacer()
                                    Button {
                                        searchManager.removeFromHistory(query)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 400)
    }

    // MARK: - Helper Properties

    private var hasActiveFilters: Bool {
        currentFilter.dateRange != nil ||
        !currentFilter.calendarIDs.isEmpty ||
        !currentFilter.categoryIDs.isEmpty ||
        !currentFilter.includeAllDay ||
        currentFilter.includeRecurring != nil
    }

    // MARK: - Actions

    private func performSearch() {
        searchResults = searchManager.search(
            query: searchQuery,
            filter: currentFilter,
            categoriesManager: categoriesManager
        )
    }
}

// MARK: - Quick Filter Button

struct QuickFilterButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(CalendarPPZenStyle.stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    let categoriesManager: EventCategoriesManager

    var category: EventCategory? {
        categoriesManager.getCategory(for: result.event.id)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Calendar color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(result.event.calendarColor))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                // Title with matched indicator
                HStack(spacing: 6) {
                    Text(result.event.title)
                        .font(.headline)

                    if result.matchedFields.contains(.title) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }

                    Spacer()

                    // Relevance indicator
                    if result.relevanceScore > 80 {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                // Date & Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatDateTime(result.event.startDate, result.event.endDate))
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                // Location
                if let location = result.event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)

                        if result.matchedFields.contains(.location) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .foregroundColor(.secondary)
                }

                // Category
                if let category = category {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .foregroundColor(category.displayColor)
                            .font(.caption2)
                        Text(category.name)
                            .font(.caption)
                            .foregroundColor(category.displayColor)
                    }
                }

                // Calendar name
                Text(result.event.calendarName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }

    private func formatDateTime(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        return "\(formatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @Binding var filter: SearchFilter
    let onApply: () -> Void

    @EnvironmentObject var categoriesManager: EventCategoriesManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedDateRange: DateRangeFilter?
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date().addingTimeInterval(7 * 24 * 3600)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Advanced Filters")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Spacer(minLength: 0)

                Button("Reset") {
                    filter = SearchFilter()
                    selectedDateRange = nil
                }
                .buttonStyle(.borderless)

                Button("Done") {
                    applyFilters()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .calendarPPZenCard(cornerRadius: 14, strong: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Section {
                        Text("Date Range")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Picker("Range", selection: $selectedDateRange) {
                            Text("All").tag(nil as DateRangeFilter?)
                            Text("Today").tag(DateRangeFilter.today as DateRangeFilter?)
                            Text("This Week").tag(DateRangeFilter.thisWeek as DateRangeFilter?)
                            Text("This Month").tag(DateRangeFilter.thisMonth as DateRangeFilter?)
                            Text("Custom").tag(DateRangeFilter.custom(start: customStartDate, end: customEndDate) as DateRangeFilter?)
                        }
                        .pickerStyle(.radioGroup)

                        if case .custom = selectedDateRange {
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)

                                DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                            .padding(.leading)
                        }
                    }

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    Section {
                        Text("Categories")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        if categoriesManager.categories.isEmpty {
                            Text("No categories available")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(categoriesManager.categories) { category in
                                    Toggle(isOn: Binding(
                                        get: { filter.categoryIDs.contains(category.id) },
                                        set: { isOn in
                                            if isOn {
                                                filter.categoryIDs.append(category.id)
                                            } else {
                                                filter.categoryIDs.removeAll { $0 == category.id }
                                            }
                                        }
                                    )) {
                                        HStack(spacing: 8) {
                                            Image(systemName: category.icon)
                                                .foregroundStyle(category.displayColor)
                                            Text(category.name)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    Section {
                        Text("Event Type")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Toggle("Include all-day events", isOn: $filter.includeAllDay)

                        Picker("Recurring events", selection: $filter.includeRecurring) {
                            Text("All").tag(nil as Bool?)
                            Text("Only recurring").tag(true as Bool?)
                            Text("Only non-recurring").tag(false as Bool?)
                        }
                        .pickerStyle(.radioGroup)
                    }

                    Divider()
                        .overlay(CalendarPPZenStyle.stroke)

                    Section {
                        Text("Save This Filter")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField("Filter name", text: $filter.name)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Add to favorites", isOn: $filter.isFavorite)

                        Button("Save Filter") {
                            if !filter.name.isEmpty {
                                SearchManager().saveFilter(filter)
                            }
                        }
                        .disabled(filter.name.isEmpty)
                    }
                }
                .padding(14)
            }
            .calendarPPZenCard(cornerRadius: 14, strong: false)
        }
        .padding(16)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 640, idealHeight: 700)
        .onAppear {
            selectedDateRange = filter.dateRange
        }
    }

    private func applyFilters() {
        // Update date range based on selection
        if case .custom = selectedDateRange {
            filter.dateRange = .custom(start: customStartDate, end: customEndDate)
        } else {
            filter.dateRange = selectedDateRange
        }

        onApply()
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environmentObject(EventCategoriesManager())
        .environmentObject(EventKitManager())
}
