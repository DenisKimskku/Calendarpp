//
//  MultiAccountManager.swift
//  calendar++
//
//  Manage multiple Google Calendar accounts
//

import Foundation
import Combine

struct GoogleAccount: Identifiable, Codable {
    let id: UUID
    var email: String
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var isActive: Bool

    init(id: UUID = UUID(), email: String, accessToken: String, refreshToken: String, expiresAt: Date, isActive: Bool = true) {
        self.id = id
        self.email = email
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.isActive = isActive
    }
}

class MultiAccountManager: ObservableObject {
    @Published var accounts: [GoogleAccount] = []
    @Published var selectedAccountId: UUID?

    private let userDefaultsKey = "googleAccounts"
    private let selectedAccountKey = "selectedGoogleAccountId"

    // Keychain service identifiers
    private let keychainService = "den-kim.calendar--"

    init() {
        loadAccounts()
    }

    // MARK: - Account Management

    var selectedAccount: GoogleAccount? {
        guard let selectedId = selectedAccountId else { return nil }
        return accounts.first { $0.id == selectedId }
    }

    var activeAccounts: [GoogleAccount] {
        accounts.filter { $0.isActive }
    }

    func addAccount(email: String, accessToken: String, refreshToken: String, expiresAt: Date) {
        // Check if account already exists
        if let existingIndex = accounts.firstIndex(where: { $0.email == email }) {
            // Update existing account
            accounts[existingIndex].accessToken = accessToken
            accounts[existingIndex].refreshToken = refreshToken
            accounts[existingIndex].expiresAt = expiresAt
            accounts[existingIndex].isActive = true
        } else {
            // Add new account
            let account = GoogleAccount(
                email: email,
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
            accounts.append(account)

            // Select first account by default
            if selectedAccountId == nil {
                selectedAccountId = account.id
            }
        }

        saveAccounts()
    }

    func updateAccount(_ account: GoogleAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }

    func removeAccount(_ account: GoogleAccount) {
        accounts.removeAll { $0.id == account.id }

        // Update selection if removed account was selected
        if selectedAccountId == account.id {
            selectedAccountId = accounts.first?.id
        }

        saveAccounts()
    }

    func toggleAccount(_ account: GoogleAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index].isActive.toggle()
            saveAccounts()
        }
    }

    func selectAccount(_ account: GoogleAccount) {
        selectedAccountId = account.id
        UserDefaults.standard.set(account.id.uuidString, forKey: selectedAccountKey)
    }

    // MARK: - Token Management

    func updateTokens(for accountId: UUID, accessToken: String, expiresAt: Date) {
        if let index = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[index].accessToken = accessToken
            accounts[index].expiresAt = expiresAt
            saveAccounts()
        }
    }

    func isTokenExpired(for account: GoogleAccount) -> Bool {
        return Date() >= account.expiresAt
    }

    // MARK: - Persistence

    private func saveAccounts() {
        // Save account metadata (without tokens) to UserDefaults
        let accountMetadata = accounts.map { account in
            [
                "id": account.id.uuidString,
                "email": account.email,
                "expiresAt": ISO8601DateFormatter().string(from: account.expiresAt),
                "isActive": account.isActive
            ] as [String: Any]
        }

        UserDefaults.standard.set(accountMetadata, forKey: userDefaultsKey)

        // Save tokens to Keychain
        for account in accounts {
            saveToKeychain(accountId: account.id, accessToken: account.accessToken, refreshToken: account.refreshToken)
        }
    }

    private func loadAccounts() {
        guard let metadata = UserDefaults.standard.array(forKey: userDefaultsKey) as? [[String: Any]] else {
            return
        }

        accounts = metadata.compactMap { dict in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let email = dict["email"] as? String,
                  let expiresAtString = dict["expiresAt"] as? String,
                  let expiresAt = ISO8601DateFormatter().date(from: expiresAtString),
                  let isActive = dict["isActive"] as? Bool else {
                return nil
            }

            // Load tokens from Keychain
            guard let (accessToken, refreshToken) = loadFromKeychain(accountId: id) else {
                return nil
            }

            return GoogleAccount(
                id: id,
                email: email,
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt,
                isActive: isActive
            )
        }

        // Load selected account
        if let selectedIdString = UserDefaults.standard.string(forKey: selectedAccountKey),
           let selectedId = UUID(uuidString: selectedIdString),
           accounts.contains(where: { $0.id == selectedId }) {
            selectedAccountId = selectedId
        } else {
            selectedAccountId = accounts.first?.id
        }
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(accountId: UUID, accessToken: String, refreshToken: String) {
        let accessTokenKey = "\(keychainService).accessToken.\(accountId.uuidString)"
        let refreshTokenKey = "\(keychainService).refreshToken.\(accountId.uuidString)"

        saveStringToKeychain(key: accessTokenKey, value: accessToken)
        saveStringToKeychain(key: refreshTokenKey, value: refreshToken)
    }

    private func loadFromKeychain(accountId: UUID) -> (accessToken: String, refreshToken: String)? {
        let accessTokenKey = "\(keychainService).accessToken.\(accountId.uuidString)"
        let refreshTokenKey = "\(keychainService).refreshToken.\(accountId.uuidString)"

        guard let accessToken = loadStringFromKeychain(key: accessTokenKey),
              let refreshToken = loadStringFromKeychain(key: refreshTokenKey) else {
            return nil
        }

        return (accessToken, refreshToken)
    }

    private func saveStringToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadStringFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    func deleteFromKeychain(accountId: UUID) {
        let accessTokenKey = "\(keychainService).accessToken.\(accountId.uuidString)"
        let refreshTokenKey = "\(keychainService).refreshToken.\(accountId.uuidString)"

        deleteStringFromKeychain(key: accessTokenKey)
        deleteStringFromKeychain(key: refreshTokenKey)
    }

    private func deleteStringFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
