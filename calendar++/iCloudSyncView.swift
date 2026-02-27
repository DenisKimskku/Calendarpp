//
//  iCloudSyncView.swift
//  calendar++
//
//  UI for managing iCloud sync settings
//

import SwiftUI

struct iCloudSyncView: View {
    @StateObject private var syncManager = iCloudSyncManager()
    @State private var syncSettings = SyncSettings.load()
    @State private var storageUsed: Int64 = 0
    @State private var storageTotal: Int64 = 0
    @State private var showingErrorAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "icloud")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("iCloud Sync")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status Section
                    statusSection

                    Divider()

                    // Sync Options
                    syncOptionsSection

                    Divider()

                    // Storage Info
                    storageSection

                    Divider()

                    // Advanced Settings
                    advancedSection

                    // Manual Sync Button
                    Button {
                        syncManager.performManualSync()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(syncManager.syncStatus.isEnabled ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(!syncManager.syncStatus.isEnabled || syncManager.syncStatus.isSyncing)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadStorageInfo()
        }
        .alert("Sync Error", isPresented: $showingErrorAlert) {
            Button("OK") {}
        } message: {
            if let error = syncManager.syncStatus.error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.subheadline.bold())

            HStack {
                // Availability Status
                HStack(spacing: 8) {
                    Circle()
                        .fill(syncManager.isAvailable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(syncManager.isAvailable ? "iCloud Available" : "iCloud Not Available")
                        .font(.caption)
                }

                Spacer()

                // Sync Status
                if syncManager.syncStatus.isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Syncing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)

            // Enable/Disable Toggle
            Toggle("Enable iCloud Sync", isOn: Binding(
                get: { syncManager.syncStatus.isEnabled },
                set: { isEnabled in
                    if isEnabled {
                        syncManager.enableSync()
                    } else {
                        syncManager.disableSync()
                    }
                }
            ))
            .disabled(!syncManager.isAvailable)

            // Last Sync Time
            if let lastSync = syncManager.syncStatus.lastSyncDate {
                Text("Last synced: \(formatLastSyncTime(lastSync))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if syncManager.syncStatus.isEnabled {
                Text("Never synced")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Error Message
            if let error = syncManager.syncStatus.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - Sync Options

    private var syncOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to Sync")
                .font(.subheadline.bold())

            Toggle("Preferences", isOn: $syncSettings.syncPreferences)
                .onChange(of: syncSettings.syncPreferences) { _ in
                    syncSettings.save()
                }

            Toggle("Event Templates", isOn: $syncSettings.syncEventTemplates)
                .onChange(of: syncSettings.syncEventTemplates) { _ in
                    syncSettings.save()
                }

            Toggle("Categories", isOn: $syncSettings.syncCategories)
                .onChange(of: syncSettings.syncCategories) { _ in
                    syncSettings.save()
                }

            Toggle("Saved Searches", isOn: $syncSettings.syncSearchFilters)
                .onChange(of: syncSettings.syncSearchFilters) { _ in
                    syncSettings.save()
                }

            Toggle("World Clocks", isOn: $syncSettings.syncWorldClocks)
                .onChange(of: syncSettings.syncWorldClocks) { _ in
                    syncSettings.save()
                }

            Toggle("Meeting Notes", isOn: $syncSettings.syncMeetingNotes)
                .onChange(of: syncSettings.syncMeetingNotes) { _ in
                    syncSettings.save()
                }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Used:")
                        .font(.caption)
                    Spacer()
                    Text(formatBytes(storageUsed))
                        .font(.caption.monospacedDigit())
                }

                HStack {
                    Text("Total:")
                        .font(.caption)
                    Spacer()
                    Text(formatBytes(storageTotal))
                        .font(.caption.monospacedDigit())
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(storageColor)
                            .frame(
                                width: geometry.size.width * CGFloat(storageUsed) / CGFloat(storageTotal),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                Text("\(storagePercentage)% used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            Text("iCloud Key-Value Store has a 1 MB limit per app")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.subheadline.bold())

            Toggle("Automatic Sync", isOn: $syncSettings.autoSync)
                .onChange(of: syncSettings.autoSync) { _ in
                    syncSettings.save()
                }

            if syncSettings.autoSync {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Interval")
                        .font(.caption)

                    Picker("Interval", selection: $syncSettings.syncInterval) {
                        Text("1 minute").tag(TimeInterval(60))
                        Text("5 minutes").tag(TimeInterval(300))
                        Text("15 minutes").tag(TimeInterval(900))
                        Text("30 minutes").tag(TimeInterval(1800))
                        Text("1 hour").tag(TimeInterval(3600))
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .onChange(of: syncSettings.syncInterval) { _ in
                        syncSettings.save()
                    }
                }
            }

            // Danger Zone
            VStack(alignment: .leading, spacing: 8) {
                Text("Danger Zone")
                    .font(.caption.bold())
                    .foregroundColor(.red)

                Button {
                    // Reset iCloud data
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear iCloud Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Properties

    private var storagePercentage: Int {
        guard storageTotal > 0 else { return 0 }
        return Int((Double(storageUsed) / Double(storageTotal)) * 100)
    }

    private var storageColor: Color {
        if storagePercentage > 90 {
            return .red
        } else if storagePercentage > 70 {
            return .orange
        } else {
            return .blue
        }
    }

    // MARK: - Helper Functions

    private func formatLastSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func loadStorageInfo() {
        Task {
            do {
                let info = try await syncManager.getStorageInfo()
                await MainActor.run {
                    storageUsed = info.used
                    storageTotal = info.total
                }
            } catch {
                print("Failed to load storage info: \(error)")
            }
        }
    }
}

// MARK: - Sync Status Indicator (for MenuBar)

struct SyncStatusIndicator: View {
    @ObservedObject var syncManager: iCloudSyncManager

    var body: some View {
        Group {
            if syncManager.syncStatus.isSyncing {
                Image(systemName: "icloud.and.arrow.up.and.down")
                    .foregroundColor(.blue)
            } else if syncManager.syncStatus.error != nil {
                Image(systemName: "icloud.slash")
                    .foregroundColor(.red)
            } else if syncManager.syncStatus.isEnabled {
                Image(systemName: "icloud")
                    .foregroundColor(.green)
            }
        }
        .help(syncStatusText)
    }

    private var syncStatusText: String {
        if syncManager.syncStatus.isSyncing {
            return "Syncing with iCloud..."
        } else if let error = syncManager.syncStatus.error {
            return "Sync error: \(error.localizedDescription)"
        } else if syncManager.syncStatus.isEnabled {
            if let lastSync = syncManager.syncStatus.lastSyncDate {
                return "Last synced: \(formatLastSync(lastSync))"
            } else {
                return "iCloud sync enabled"
            }
        } else {
            return "iCloud sync disabled"
        }
    }

    private func formatLastSync(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    iCloudSyncView()
}
