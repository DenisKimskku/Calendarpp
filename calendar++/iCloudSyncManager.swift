//
//  iCloudSyncManager.swift
//  calendar++
//
//  Manages iCloud sync for preferences, templates, and user data
//

import Foundation
import CloudKit
import Combine

// MARK: - Syncable Data Models

enum SyncableDataType: String {
    case preferences = "Preferences"
    case eventTemplates = "EventTemplates"
    case categories = "Categories"
    case savedSearches = "SavedSearches"
    case worldClocks = "WorldClocks"
    case meetingNotes = "MeetingNotes"
}

struct SyncStatus {
    var isEnabled: Bool
    var lastSyncDate: Date?
    var isSyncing: Bool
    var error: Error?
}

// MARK: - iCloud Sync Manager

class iCloudSyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = SyncStatus(isEnabled: false, isSyncing: false)
    @Published var isAvailable: Bool = false

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    private let ubiquitousStore: NSUbiquitousKeyValueStore

    // Keys for NSUbiquitousKeyValueStore
    private let preferencesKey = "icloud_preferences"
    private let templatesKey = "icloud_event_templates"
    private let categoriesKey = "icloud_categories"
    private let searchesKey = "icloud_saved_searches"
    private let clocksKey = "icloud_world_clocks"
    private let lastSyncKey = "icloud_last_sync"

    init() {
        // Initialize CloudKit
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase

        // Initialize NSUbiquitousKeyValueStore
        ubiquitousStore = NSUbiquitousKeyValueStore.default

        // Check iCloud availability
        checkiCloudAvailability()

        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )

        // Start syncing
        ubiquitousStore.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - iCloud Availability

    func checkiCloudAvailability() {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self.isAvailable = true
                    self.syncStatus.isEnabled = UserDefaults.standard.bool(forKey: "icloud_sync_enabled")
                    if self.syncStatus.isEnabled {
                        self.performInitialSync()
                    }

                case .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable:
                    self.isAvailable = false
                    self.syncStatus.isEnabled = false

                @unknown default:
                    self.isAvailable = false
                }

                if let error = error {
                    print("iCloud account status error: \(error)")
                    self.syncStatus.error = error
                }
            }
        }
    }

    // MARK: - Sync Control

    func enableSync() {
        guard isAvailable else {
            print("iCloud not available")
            return
        }

        syncStatus.isEnabled = true
        UserDefaults.standard.set(true, forKey: "icloud_sync_enabled")

        performInitialSync()
    }

    func disableSync() {
        syncStatus.isEnabled = false
        UserDefaults.standard.set(false, forKey: "icloud_sync_enabled")
    }

    func performManualSync() {
        guard syncStatus.isEnabled else { return }

        syncStatus.isSyncing = true

        // Sync using NSUbiquitousKeyValueStore
        ubiquitousStore.synchronize()

        // Update last sync time
        syncStatus.lastSyncDate = Date()
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)

        syncStatus.isSyncing = false
    }

    private func performInitialSync() {
        guard !syncStatus.isSyncing else { return }

        syncStatus.isSyncing = true

        // Pull data from iCloud
        pullFromiCloud()

        // Push local data to iCloud
        pushToiCloud()

        syncStatus.lastSyncDate = Date()
        syncStatus.isSyncing = false
    }

    // MARK: - Push Data to iCloud

    func pushToiCloud() {
        // Preferences
        if let preferencesData = UserDefaults.standard.data(forKey: "app_preferences") {
            ubiquitousStore.set(preferencesData, forKey: preferencesKey)
        }

        // Event Templates
        if let templatesData = UserDefaults.standard.data(forKey: "event_templates") {
            ubiquitousStore.set(templatesData, forKey: templatesKey)
        }

        // Categories
        if let categoriesData = UserDefaults.standard.data(forKey: "event_categories") {
            ubiquitousStore.set(categoriesData, forKey: categoriesKey)
        }

        // Saved Searches
        if let searchesData = UserDefaults.standard.data(forKey: "saved_filters") {
            ubiquitousStore.set(searchesData, forKey: searchesKey)
        }

        // World Clocks
        if let clocksData = UserDefaults.standard.data(forKey: "favorite_timezones") {
            ubiquitousStore.set(clocksData, forKey: clocksKey)
        }

        // Sync
        ubiquitousStore.synchronize()
    }

    // MARK: - Pull Data from iCloud

    func pullFromiCloud() {
        // Preferences
        if let preferencesData = ubiquitousStore.data(forKey: preferencesKey) {
            UserDefaults.standard.set(preferencesData, forKey: "app_preferences")
        }

        // Event Templates
        if let templatesData = ubiquitousStore.data(forKey: templatesKey) {
            UserDefaults.standard.set(templatesData, forKey: "event_templates")
        }

        // Categories
        if let categoriesData = ubiquitousStore.data(forKey: categoriesKey) {
            UserDefaults.standard.set(categoriesData, forKey: "event_categories")
        }

        // Saved Searches
        if let searchesData = ubiquitousStore.data(forKey: searchesKey) {
            UserDefaults.standard.set(searchesData, forKey: "saved_filters")
        }

        // World Clocks
        if let clocksData = ubiquitousStore.data(forKey: clocksKey) {
            UserDefaults.standard.set(clocksData, forKey: "favorite_timezones")
        }

        // Notify observers
        NotificationCenter.default.post(name: .iCloudDataDidUpdate, object: nil)
    }

    // MARK: - iCloud Change Handler

    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        guard syncStatus.isEnabled else { return }

        guard let userInfo = notification.userInfo else { return }

        // Get change reason
        if let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
                // Pull updated data
                DispatchQueue.main.async {
                    self.pullFromiCloud()
                }

            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                print("iCloud quota exceeded")
                syncStatus.error = NSError(
                    domain: "iCloudSync",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "iCloud storage quota exceeded"]
                )

            case NSUbiquitousKeyValueStoreAccountChange:
                print("iCloud account changed")
                checkiCloudAvailability()

            default:
                break
            }
        }
    }

    // MARK: - Sync Specific Data

    func syncPreferences(_ preferences: [String: Any]) {
        guard syncStatus.isEnabled else { return }

        if let data = try? JSONSerialization.data(withJSONObject: preferences) {
            ubiquitousStore.set(data, forKey: preferencesKey)
            ubiquitousStore.synchronize()
        }
    }

    func syncEventTemplates(_ templates: Data) {
        guard syncStatus.isEnabled else { return }

        ubiquitousStore.set(templates, forKey: templatesKey)
        ubiquitousStore.synchronize()
    }

    func syncCategories(_ categories: Data) {
        guard syncStatus.isEnabled else { return }

        ubiquitousStore.set(categories, forKey: categoriesKey)
        ubiquitousStore.synchronize()
    }

    func syncSearchFilters(_ filters: Data) {
        guard syncStatus.isEnabled else { return }

        ubiquitousStore.set(filters, forKey: searchesKey)
        ubiquitousStore.synchronize()
    }

    func syncWorldClocks(_ clocks: Data) {
        guard syncStatus.isEnabled else { return }

        ubiquitousStore.set(clocks, forKey: clocksKey)
        ubiquitousStore.synchronize()
    }

    // MARK: - CloudKit Document Sync (for larger data like meeting notes)

    func saveDocument(recordName: String, data: Data, type: SyncableDataType) async throws {
        guard syncStatus.isEnabled else { return }

        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: type.rawValue, recordID: recordID)

        // Save data as asset for larger files
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(recordName)
        try data.write(to: tempURL)

        let asset = CKAsset(fileURL: tempURL)
        record["data"] = asset
        record["modifiedDate"] = Date()

        try await privateDatabase.save(record)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
    }

    func fetchDocument(recordName: String, type: SyncableDataType) async throws -> Data? {
        guard syncStatus.isEnabled else { return nil }

        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await privateDatabase.record(for: recordID)

        guard let asset = record["data"] as? CKAsset,
              let fileURL = asset.fileURL else {
            return nil
        }

        return try Data(contentsOf: fileURL)
    }

    func deleteDocument(recordName: String) async throws {
        guard syncStatus.isEnabled else { return }

        let recordID = CKRecord.ID(recordName: recordName)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Query Documents

    func queryDocuments(type: SyncableDataType) async throws -> [CKRecord] {
        guard syncStatus.isEnabled else { return [] }

        let query = CKQuery(recordType: type.rawValue, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        return results.matchResults.compactMap { _, result in
            try? result.get()
        }
    }

    // MARK: - Conflict Resolution

    func resolveConflict(localData: Data, iCloudData: Data, lastSyncDate: Date?) -> Data {
        // Simple last-write-wins strategy
        // In production, you might want more sophisticated conflict resolution

        let localModifiedDate = Date() // Assume local is most recent
        let iCloudModifiedDate = lastSyncDate ?? Date.distantPast

        return localModifiedDate > iCloudModifiedDate ? localData : iCloudData
    }

    // MARK: - Storage Info

    func getStorageInfo() async throws -> (used: Int64, total: Int64) {
        // This is approximate - CloudKit doesn't provide exact quota info for key-value store
        // The actual limit is 1 MB per app

        var totalSize: Int64 = 0

        if let preferencesData = ubiquitousStore.data(forKey: preferencesKey) {
            totalSize += Int64(preferencesData.count)
        }

        if let templatesData = ubiquitousStore.data(forKey: templatesKey) {
            totalSize += Int64(templatesData.count)
        }

        if let categoriesData = ubiquitousStore.data(forKey: categoriesKey) {
            totalSize += Int64(categoriesData.count)
        }

        if let searchesData = ubiquitousStore.data(forKey: searchesKey) {
            totalSize += Int64(searchesData.count)
        }

        if let clocksData = ubiquitousStore.data(forKey: clocksKey) {
            totalSize += Int64(clocksData.count)
        }

        // 1 MB limit for NSUbiquitousKeyValueStore
        let totalLimit: Int64 = 1024 * 1024

        return (totalSize, totalLimit)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let iCloudDataDidUpdate = Notification.Name("iCloudDataDidUpdate")
}

// MARK: - Sync Error

enum SyncError: LocalizedError {
    case notAvailable
    case notEnabled
    case quotaExceeded
    case networkError
    case conflictResolutionFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available. Please sign in to iCloud in System Settings."
        case .notEnabled:
            return "iCloud sync is not enabled for this app."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Please free up space or upgrade your iCloud plan."
        case .networkError:
            return "Network error occurred while syncing with iCloud."
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflict."
        }
    }
}

// MARK: - Sync Settings

struct SyncSettings: Codable {
    var syncPreferences: Bool = true
    var syncEventTemplates: Bool = true
    var syncCategories: Bool = true
    var syncSearchFilters: Bool = true
    var syncWorldClocks: Bool = true
    var syncMeetingNotes: Bool = true
    var autoSync: Bool = true
    var syncInterval: TimeInterval = 300 // 5 minutes

    static let key = "sync_settings"

    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
    }

    static func load() -> SyncSettings {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(SyncSettings.self, from: data) else {
            return SyncSettings()
        }
        return settings
    }
}
