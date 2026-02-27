//
//  CalendarSubscriptionView.swift
//  calendar++
//
//  UI for managing calendar subscriptions
//

import SwiftUI

struct CalendarSubscriptionView: View {
    @StateObject private var subscriptionManager = CalendarSubscriptionManager()
    @State private var showingAddSubscription = false
    @State private var showingPopularCalendars = false
    @State private var selectedCategory: SubscriptionCategory? = nil

    var filteredSubscriptions: [CalendarSubscription] {
        if let category = selectedCategory {
            return subscriptionManager.getSubscriptionsByCategory(category)
        }
        return subscriptionManager.subscriptions
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Calendar Subscriptions")
                    .font(.headline)
                Spacer()

                if subscriptionManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button {
                    showingPopularCalendars = true
                } label: {
                    Image(systemName: "star.circle")
                }
                .buttonStyle(.plain)
                .help("Browse popular calendars")

                Button {
                    showingAddSubscription = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryFilterButton(
                        title: "All",
                        icon: "calendar",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                        CategoryFilterButton(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color.gray.opacity(0.05))

            // Subscriptions List
            if filteredSubscriptions.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSubscriptions) { subscription in
                            SubscriptionCard(
                                subscription: subscription,
                                manager: subscriptionManager
                            )
                        }
                    }
                    .padding()
                }
            }

            // Stats Footer
            statsFooter
        }
        .frame(width: 600, height: 600)
        .calendarppModal(isPresented: $showingAddSubscription) {
            AddSubscriptionView(manager: subscriptionManager)
        }
        .calendarppModal(isPresented: $showingPopularCalendars) {
            PopularCalendarsView(manager: subscriptionManager)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No subscriptions yet")
                .foregroundColor(.secondary)
            Button("Browse Popular Calendars") {
                showingPopularCalendars = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statsFooter: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                Text("\(subscriptionManager.getActiveSubscriptionsCount()) active")
                    .font(.caption)
            }
            .foregroundColor(.green)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text("\(subscriptionManager.getTotalSubscribedEvents()) events")
                    .font(.caption)
            }
            .foregroundColor(.blue)

            Spacer()

            Button {
                Task {
                    await subscriptionManager.syncAllSubscriptions()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("Sync All")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isSyncing)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Category Filter Button

struct CategoryFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Card

struct SubscriptionCard: View {
    let subscription: CalendarSubscription
    @ObservedObject var manager: CalendarSubscriptionManager

    @State private var showingDetails = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: subscription.category.icon)
                .font(.title2)
                .foregroundColor(subscription.color.color)
                .frame(width: 40, height: 40)
                .background(subscription.color.color.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(subscription.name)
                    .font(.headline)

                // URL
                Text(subscription.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Stats
                HStack(spacing: 12) {
                    if let lastSync = subscription.lastSyncDate {
                        Text("Synced \(formatLastSync(lastSync))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not synced")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if subscription.eventCount > 0 {
                        Text("\(subscription.eventCount) events")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { subscription.isEnabled },
                set: { _ in manager.toggleSubscription(subscription) }
            ))
            .labelsHidden()

            // More button
            Button {
                showingDetails = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .calendarppModal(isPresented: $showingDetails) {
            SubscriptionDetailView(subscription: subscription, manager: manager)
        }
    }

    private func formatLastSync(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Add Subscription View

struct AddSubscriptionView: View {
    @ObservedObject var manager: CalendarSubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var selectedCategory: SubscriptionCategory = .custom
    @State private var selectedColor: Color = .blue
    @State private var isImporting: Bool = false
    @State private var errorMessage: String?

    private let availableColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .yellow,
        .pink, .cyan, .indigo, .mint, .teal, .brown
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Calendar Subscription")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // URL
                    Section {
                        Text("Calendar URL")
                            .font(.subheadline.bold())

                        TextField("webcal://example.com/calendar.ics", text: $url)
                            .textFieldStyle(.roundedBorder)

                        Text("Paste a webcal:// or https:// iCal (.ics) URL")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Name
                    Section {
                        Text("Display Name")
                            .font(.subheadline.bold())

                        TextField("e.g. US Holidays", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Category
                    Section {
                        Text("Category")
                            .font(.subheadline.bold())

                        Picker("Category", selection: $selectedCategory) {
                            ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    // Color
                    Section {
                        Text("Color")
                            .font(.subheadline.bold())

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableColors, id: \.description) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor.description == color.description ? 3 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Add Button
                    Button {
                        importSubscription()
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isImporting ? "Importing..." : "Add Subscription")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(url.isEmpty || isImporting ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(url.isEmpty || isImporting)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }

    private func importSubscription() {
        isImporting = true
        errorMessage = nil

        Task {
            do {
                var subscription = try await manager.importFromURL(url, name: name.isEmpty ? nil : name)
                subscription.category = selectedCategory
                subscription.color = CodableColor(color: selectedColor)

                await MainActor.run {
                    manager.addSubscription(subscription)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Subscription Detail View

struct SubscriptionDetailView: View {
    let subscription: CalendarSubscription
    @ObservedObject var manager: CalendarSubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(subscription.name)
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Info
                    Section {
                        InfoRow(label: "Category", value: subscription.category.rawValue)
                        InfoRow(label: "URL", value: subscription.url)
                        if let lastSync = subscription.lastSyncDate {
                            InfoRow(label: "Last Synced", value: formatDate(lastSync))
                        }
                        InfoRow(label: "Events", value: "\(subscription.eventCount)")
                        InfoRow(label: "Status", value: subscription.isEnabled ? "Active" : "Paused")
                    }

                    Divider()

                    // Actions
                    Section {
                        Button {
                            Task {
                                await manager.syncSubscription(subscription)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Now")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }

                        Button {
                            manager.deleteSubscription(subscription)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Subscription")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 400)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Popular Calendars View

struct PopularCalendarsView: View {
    @ObservedObject var manager: CalendarSubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Popular Calendars")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(CalendarSubscriptionManager.popularSubscriptions, id: \.url) { popular in
                        PopularCalendarCard(popular: popular) {
                            addPopularSubscription(popular)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }

    private func addPopularSubscription(_ popular: PopularSubscription) {
        let subscription = CalendarSubscription(
            name: popular.name,
            url: popular.url,
            category: popular.category
        )
        manager.addSubscription(subscription)
        dismiss()
    }
}

struct PopularCalendarCard: View {
    let popular: PopularSubscription
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: popular.category.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(popular.name)
                        .font(.headline)

                    Text(popular.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(popular.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CalendarSubscriptionView()
}
