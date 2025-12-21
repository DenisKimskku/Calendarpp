import Foundation
import Combine
import AppKit

struct GoogleCalendarEvent: Identifiable, Codable {
    let id: String
    let summary: String?
    let start: GoogleDateTime
    let end: GoogleDateTime
    let location: String?
    let description: String?

    var title: String {
        summary ?? "(No title)"
    }

    struct GoogleDateTime: Codable {
        let dateTime: String?
        let date: String?

        var asDate: Date {
            if let dateTime = dateTime {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateTime) {
                    return date
                }
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: dateTime) ?? Date()
            } else if let dateStr = date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: dateStr) ?? Date()
            }
            return Date()
        }

        var isAllDay: Bool {
            date != nil
        }
    }
}

struct GoogleCalendarEventsResponse: Codable {
    let items: [GoogleCalendarEvent]?
}

struct GoogleTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
    let token_type: String
}

final class GoogleCalendarManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var googleEvents: [EventSummary] = []
    @Published var errorMessage: String?

    private let clientId = "YOUR_CLIENT_ID" // User needs to replace this
    private let redirectUri = "calenderplus://oauth2callback"
    private let keychainService = "den-kim.calendar--"
    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let tokenExpiryKey = "google_token_expiry"

    private var cancellables = Set<AnyCancellable>()

    init() {
        checkAuthentication()
    }

    // MARK: - Authentication

    func checkAuthentication() {
        if let _ = getAccessToken() {
            isAuthenticated = true
            refreshEventsIfNeeded()
        } else {
            isAuthenticated = false
        }
    }

    func startOAuthFlow() {
        // Generate code verifier and challenge for PKCE
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Save code verifier for later
        saveToKeychain(key: "code_verifier", value: codeVerifier)

        // Build OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/calendar.readonly"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    func handleOAuthCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let codeVerifier = getFromKeychain(key: "code_verifier") else {
            errorMessage = "Failed to process OAuth callback"
            return
        }

        exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientId,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.errorMessage = error?.localizedDescription ?? "Unknown error"
                }
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
                self.saveTokens(accessToken: tokenResponse.access_token,
                               refreshToken: tokenResponse.refresh_token,
                               expiresIn: tokenResponse.expires_in)

                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    self.fetchGoogleCalendarEvents()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to decode token: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func signOut() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        deleteFromKeychain(key: tokenExpiryKey)
        isAuthenticated = false
        googleEvents = []
    }

    // MARK: - Fetch Events

    func refreshEventsIfNeeded() {
        guard isAuthenticated else { return }
        fetchGoogleCalendarEvents()
    }

    private func fetchGoogleCalendarEvents() {
        guard let accessToken = getAccessToken() else {
            isAuthenticated = false
            return
        }

        // Get events from now to 30 days in future
        let now = Date()
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 30, to: now)!

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: now)
        let timeMax = formatter.string(from: endDate)

        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Error fetching Google Calendar events: \(error?.localizedDescription ?? "unknown")")
                return
            }

            // Check for 401 Unauthorized
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                self.refreshAccessToken()
                return
            }

            do {
                let eventsResponse = try JSONDecoder().decode(GoogleCalendarEventsResponse.self, from: data)
                let events = eventsResponse.items ?? []

                let eventSummaries = events.map { event in
                    EventSummary(
                        id: "google-\(event.id)",
                        title: event.title,
                        startDate: event.start.asDate,
                        endDate: event.end.asDate,
                        isAllDay: event.start.isAllDay,
                        calendarName: "Google Calendar",
                        calendarColor: NSColor.systemBlue,
                        location: event.location
                    )
                }

                DispatchQueue.main.async {
                    self.googleEvents = eventSummaries
                }
            } catch {
                print("Error decoding Google Calendar events: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse calendar events"
                }
            }
        }.resume()
    }

    private func refreshAccessToken() {
        guard let refreshToken = getRefreshToken() else {
            signOut()
            return
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }

            do {
                let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
                self.saveTokens(accessToken: tokenResponse.access_token,
                               refreshToken: nil,
                               expiresIn: tokenResponse.expires_in)

                // Retry fetching events
                self.fetchGoogleCalendarEvents()
            } catch {
                DispatchQueue.main.async {
                    self.signOut()
                }
            }
        }.resume()
    }

    // MARK: - Keychain Helpers

    private func saveTokens(accessToken: String, refreshToken: String?, expiresIn: Int) {
        saveToKeychain(key: accessTokenKey, value: accessToken)
        if let refreshToken = refreshToken {
            saveToKeychain(key: refreshTokenKey, value: refreshToken)
        }

        let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
        saveToKeychain(key: tokenExpiryKey, value: String(expiry.timeIntervalSince1970))
    }

    private func getAccessToken() -> String? {
        // Check if token is expired
        if let expiryStr = getFromKeychain(key: tokenExpiryKey),
           let expiryInterval = TimeInterval(expiryStr) {
            let expiryDate = Date(timeIntervalSince1970: expiryInterval)
            if Date() > expiryDate {
                // Token expired, try to refresh
                refreshAccessToken()
                return nil
            }
        }

        return getFromKeychain(key: accessTokenKey)
    }

    private func getRefreshToken() -> String? {
        return getFromKeychain(key: refreshTokenKey)
    }

    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
