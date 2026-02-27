//
//  ExportImportView.swift
//  calendar++
//
//  UI for exporting and importing calendar data
//

import SwiftUI

struct ExportImportView: View {
    @StateObject private var exportManager = ExportImportManager()
    @EnvironmentObject var eventKit: EventKitManager

    @State private var selectedTab: Tab = .export

    enum Tab {
        case export
        case importEvents
        case backup
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export & Import")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Tab Bar
            Picker("Section", selection: $selectedTab) {
                Text("Export").tag(Tab.export)
                Text("Import").tag(Tab.importEvents)
                Text("Backup").tag(Tab.backup)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .export:
                        ExportView(manager: exportManager)
                    case .importEvents:
                        ImportView(manager: exportManager)
                    case .backup:
                        BackupView(manager: exportManager)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 600)
    }
}

// MARK: - Export View

struct ExportView: View {
    @ObservedObject var manager: ExportImportManager
    @EnvironmentObject var eventKit: EventKitManager

    @State private var selectedFormat: ExportFormat = .ics
    @State private var includeNotes = true
    @State private var includeLocation = true
    @State private var includeAttendees = true
    @State private var includeAlarms = true
    @State private var useDateRange = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 24 * 3600)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export Events")
                .font(.title3.bold())

            // Format Selection
            Section {
                Text("Format")
                    .font(.subheadline.bold())

                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Divider()

            // Options
            Section {
                Text("Include")
                    .font(.subheadline.bold())

                Toggle("Notes", isOn: $includeNotes)
                Toggle("Location", isOn: $includeLocation)
                Toggle("Attendees", isOn: $includeAttendees)
                Toggle("Alarms/Reminders", isOn: $includeAlarms)
            }

            Divider()

            // Date Range
            Section {
                Toggle("Export specific date range", isOn: $useDateRange)

                if useDateRange {
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)

                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    .padding(.leading)
                }
            }

            Divider()

            // Export Button
            Button {
                exportEvents()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Events")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            // Info
            Text("Export events from all calendars to \(selectedFormat.rawValue) format")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func exportEvents() {
        let events = eventKit.fetchEvents()

        let options = ExportOptions(
            format: selectedFormat,
            includeNotes: includeNotes,
            includeLocation: includeLocation,
            includeAttendees: includeAttendees,
            includeAlarms: includeAlarms,
            dateRange: useDateRange ? DateInterval(start: startDate, end: endDate) : nil
        )

        let content = manager.exportEvents(events, options: options)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let fileName = "calendar-export-\(dateFormatter.string(from: Date()))"

        manager.saveFile(
            content: content,
            fileName: fileName,
            fileExtension: selectedFormat.fileExtension
        )
    }
}

// MARK: - Import View

struct ImportView: View {
    @ObservedObject var manager: ExportImportManager

    @State private var importResult: ImportResult?
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import Events")
                .font(.title3.bold())

            Text("Import events from an ICS (iCalendar) file")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Button {
                importICS()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Select ICS File...")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isImporting)

            if isImporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Importing...")
                        .font(.caption)
                }
            }

            // Import Result
            if let result = importResult {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Complete")
                        .font(.subheadline.bold())

                    HStack {
                        Label("\(result.successCount) imported", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Spacer()
                    }

                    if result.failedCount > 0 {
                        HStack {
                            Label("\(result.failedCount) failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }

                    if result.duplicateCount > 0 {
                        HStack {
                            Label("\(result.duplicateCount) duplicates", systemImage: "doc.on.doc.fill")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }

                    if !result.errors.isEmpty {
                        Divider()

                        Text("Errors:")
                            .font(.caption.bold())

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(result.errors.prefix(5), id: \.self) { error in
                                    Text("• \(error)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .frame(height: 100)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }

            Spacer()
        }
    }

    private func importICS() {
        isImporting = true
        importResult = nil

        manager.openFile { data in
            guard let data = data else {
                isImporting = false
                return
            }

            let result = manager.importFromICS(data: data)
            importResult = result
            isImporting = false
        }
    }
}

// MARK: - Backup View

struct BackupView: View {
    @ObservedObject var manager: ExportImportManager

    @State private var showingRestoreAlert = false
    @State private var restoreData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Backup & Restore")
                .font(.title3.bold())

            Text("Backup your settings, categories, notes, and preferences")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Create Backup
            Section {
                Text("Create Backup")
                    .font(.subheadline.bold())

                Button {
                    createBackup()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Create Backup")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Text("Creates a backup file containing:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach([
                        "Event categories and tags",
                        "Saved searches and filters",
                        "World clocks",
                        "Meeting notes",
                        "Teams and members",
                        "Calendar subscriptions",
                        "App preferences"
                    ], id: \.self) { item in
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                            Text(item)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }

            Divider()

            // Restore Backup
            Section {
                Text("Restore Backup")
                    .font(.subheadline.bold())

                Button {
                    selectBackupFile()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("Restore from Backup")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Text("⚠️ This will overwrite your current settings")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .alert("Restore Backup?", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) {
                restoreData = nil
            }
            Button("Restore", role: .destructive) {
                if let data = restoreData {
                    restoreBackup(data: data)
                }
            }
        } message: {
            Text("This will overwrite your current settings with the backup data. This action cannot be undone.")
        }
    }

    private func createBackup() {
        guard let backupData = manager.createBackup() else {
            print("Failed to create backup")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "calendar++-backup-\(dateFormatter.string(from: Date()))"

        manager.saveDataFile(
            data: backupData,
            fileName: fileName,
            fileExtension: "calbackup"
        )
    }

    private func selectBackupFile() {
        manager.openFile { data in
            guard let data = data else { return }

            restoreData = data
            showingRestoreAlert = true
        }
    }

    private func restoreBackup(data: Data) {
        do {
            try manager.restoreBackup(data: data)
            // Show success message
        } catch {
            print("Failed to restore backup: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ExportImportView()
        .environmentObject(EventKitManager())
}
