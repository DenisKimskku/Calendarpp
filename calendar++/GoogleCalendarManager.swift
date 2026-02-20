import Foundation
import Combine
import AppKit
import Network
import LocalAuthentication

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
    @Published var isLoading = false
    @Published var isAuthenticating = false

    private let clientId: String
    private let clientSecret: String
    private let oauthConfigErrorMessage: String?
    // Keychain items store an access control list bound to the app's code signature.
    // During development (especially when using ad-hoc / changing signatures), reading
    // previously-saved items can trigger repetitive Keychain permission prompts.
    //
    // Bump the service namespace to avoid older items that were created under a
    // different signature/config.
    private let keychainService: String = {
        let base = Bundle.main.bundleIdentifier ?? "den-kim.calendar--"
        return "\(base).google-oauth.v3"
    }()
    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let tokenExpiryKey = "google_token_expiry"
    private var pendingCodeVerifier: String?
    private var keychainAccessBlockedForSession = false

    private var cancellables = Set<AnyCancellable>()
    private var localServer: NWListener?
    private var redirectUri: String = ""
    private var serverPort: UInt16 = 0

    private enum FetchKind {
        case baseline
        case visible
    }

    private var inFlightFetches: Int = 0
    private var lastBaselineRange: DateInterval?
    private var lastVisibleRange: DateInterval?
    private var baselineEventsById: [String: EventSummary] = [:]
    private var visibleEventsById: [String: EventSummary] = [:]
    private var isRefreshingToken = false

    private var isOAuthConfigured: Bool {
        oauthConfigErrorMessage == nil && !clientId.isEmpty && !clientSecret.isEmpty
    }

    private struct OAuthConfig {
        let clientId: String
        let clientSecret: String
        let errorMessage: String?
    }

    private static func loadOAuthConfig() -> OAuthConfig {
        // Load OAuth credentials from plist bundled with the app.
        // Missing config should not crash the app; Google sync should simply be disabled.
        guard let path = Bundle.main.path(forResource: "GoogleOAuthConfig", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let id = config["clientId"] as? String,
              let secret = config["clientSecret"] as? String,
              !id.isEmpty,
              !secret.isEmpty else {
            return OAuthConfig(
                clientId: "",
                clientSecret: "",
                errorMessage: "Google Calendar is not configured. Add GoogleOAuthConfig.plist to the app bundle (see GoogleOAuthConfig.plist.template)."
            )
        }

        return OAuthConfig(clientId: id, clientSecret: secret, errorMessage: nil)
    }

    init() {
        let config = Self.loadOAuthConfig()
        self.clientId = config.clientId
        self.clientSecret = config.clientSecret
        self.oauthConfigErrorMessage = config.errorMessage

        if let errorMessage = config.errorMessage {
            self.errorMessage = errorMessage
        }

        checkAuthentication()
    }

    // MARK: - Authentication

    func checkAuthentication() {
        guard isOAuthConfigured else {
            isAuthenticated = false
            return
        }
        guard !keychainAccessBlockedForSession else {
            isAuthenticated = false
            return
        }

        // Consider the user authenticated if we can refresh an expired token.
        // Avoid showing Keychain UI during app startup. If Keychain requires interaction
        // (locked or ACL mismatch), we'll treat the user as signed out and let them
        // reconnect from Preferences.
        if let _ = getFromKeychain(key: accessTokenKey, allowUI: false), !isAccessTokenExpired(allowUI: false) {
            isAuthenticated = true
            refreshEventsIfNeeded()
        } else if getRefreshToken(allowUI: false) != nil {
            isAuthenticated = true
            refreshAccessToken()
        } else {
            isAuthenticated = false
        }
    }

    func startOAuthFlow() {
        guard isOAuthConfigured else {
            DispatchQueue.main.async {
                self.errorMessage = self.oauthConfigErrorMessage
                self.isAuthenticating = false
            }
            return
        }

        // Clear any previous errors
        DispatchQueue.main.async {
            self.keychainAccessBlockedForSession = false
            self.errorMessage = nil
            self.isAuthenticating = true
        }

        // Generate code verifier and challenge for PKCE
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Keep verifier in-memory for this auth flow to avoid unnecessary keychain prompts.
        pendingCodeVerifier = codeVerifier

        // Start local server first
        startLocalServer { [weak self] port in
            guard let self = self else { return }

            self.serverPort = port
            self.redirectUri = "http://127.0.0.1:\(port)"

            // Build OAuth URL with loopback redirect
            guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to construct Google authentication URL."
                    self.isAuthenticating = false
                }
                return
            }
            components.queryItems = [
                URLQueryItem(name: "client_id", value: self.clientId),
                URLQueryItem(name: "redirect_uri", value: self.redirectUri),
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
    }

    // MARK: - Local Server for OAuth Callback

    private func startLocalServer(completion: @escaping (UInt16) -> Void) {
        do {
            // Create listener on loopback with random port
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            let listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: 0))
            self.localServer = listener

            listener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }

                switch state {
                case .ready:
                    if let port = listener.port {
                        DispatchQueue.main.async {
                            completion(port.rawValue)
                        }
                    }
                case .failed(let error):
                    print("Server failed: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Unable to start authentication server. Please check your network settings and try again."
                        self.isAuthenticating = false
                    }
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            print("Failed to create listener: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to start authentication server. Please ensure Calendar++ has network permissions."
                self.isAuthenticating = false
            }
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data else { return }

            if let request = String(data: data, encoding: .utf8) {
                self.parseOAuthCallback(from: request, connection: connection)
            }

            if isComplete {
                connection.cancel()
            }
        }
    }

    private func parseOAuthCallback(from request: String, connection: NWConnection) {
        // Parse HTTP request to extract code
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first,
              let urlPart = firstLine.components(separatedBy: " ").dropFirst().first,
              let url = URL(string: "http://localhost\(urlPart)"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            sendHTMLResponse(to: connection, html: "<h1>Error</h1><p>Failed to process callback</p>")
            DispatchQueue.main.async {
                self.errorMessage = "Authentication failed: Invalid response from Google. Please try again."
                self.isAuthenticating = false
            }
            stopLocalServer()
            return
        }

        guard let codeVerifier = pendingCodeVerifier else {
            sendHTMLResponse(to: connection, html: "<h1>Error</h1><p>Authentication failed</p>")
            DispatchQueue.main.async {
                self.errorMessage = "Authentication failed: Security verification error. Please try signing in again."
                self.isAuthenticating = false
            }
            stopLocalServer()
            return
        }
        pendingCodeVerifier = nil

        // Send success response to browser
        sendHTMLResponse(to: connection, html: """
            <html>
            <head><title>Calendar++ Authentication</title></head>
            <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; text-align: center; padding: 50px;">
                <h1>✅ Authentication Successful!</h1>
                <p>You can close this window and return to Calendar++</p>
            </body>
            </html>
        """)

        // Exchange code for token
        exchangeCodeForToken(code: code, codeVerifier: codeVerifier)

        // Stop server after handling callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.stopLocalServer()
        }
    }

    private func sendHTMLResponse(to connection: NWConnection, html: String) {
        let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(html.utf8.count)\r
            Connection: close\r
            \r
            \(html)
            """

        let data = Data(response.utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func stopLocalServer() {
        localServer?.cancel()
        localServer = nil
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) {
        guard isOAuthConfigured else {
            DispatchQueue.main.async {
                self.errorMessage = self.oauthConfigErrorMessage
                self.isAuthenticating = false
            }
            return
        }

#if DEBUG
        // Avoid logging sensitive values (auth codes/verifiers) to disk.
        print("Google OAuth: exchanging code for token (redirectUri=\(redirectUri))")
#endif

        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start authentication (invalid token endpoint URL)."
                self.isAuthenticating = false
            }
            return
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]

        let bodyString = bodyParams.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error?.localizedDescription ?? "Unable to connect to Google"). Please check your internet connection."
                    self.isAuthenticating = false
                }
                return
            }

            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"

#if DEBUG
                print("Google OAuth token exchange failed (\(httpResponse.statusCode)): \(errorBody)")
#endif

                DispatchQueue.main.async {
                    // Parse error details from Google's response
                    var detailedError = "Error \(httpResponse.statusCode)"
                    if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                       let errorDesc = errorData["error_description"] ?? errorData["error"] {
                        detailedError = errorDesc
                    }

                    self.errorMessage = "Authentication failed: \(detailedError)."
                    self.isAuthenticating = false
                }
                return
            }

            DispatchQueue.main.async {
                do {
                    let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
                    self.saveTokens(accessToken: tokenResponse.access_token,
                                   refreshToken: tokenResponse.refresh_token,
                                   expiresIn: tokenResponse.expires_in)

                    self.isAuthenticated = true
                    self.isAuthenticating = false
                    self.errorMessage = nil
                    self.refreshEventsIfNeeded(around: Date(), force: true)
                } catch {
                    self.errorMessage = "Authentication failed: Unable to process Google's response. Please try again."
                    self.isAuthenticating = false
                }
            }
        }.resume()
    }

    func signOut() {
        performSignOut(reason: nil)
    }

    private func performSignOut(reason: String?) {
        keychainAccessBlockedForSession = false
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        deleteFromKeychain(key: tokenExpiryKey)
        pendingCodeVerifier = nil
        isAuthenticated = false
        if let reason {
            errorMessage = reason
        } else {
            errorMessage = nil
        }
        googleEvents = []
        baselineEventsById = [:]
        visibleEventsById = [:]
        lastBaselineRange = nil
        lastVisibleRange = nil
        inFlightFetches = 0
        isLoading = false
        isRefreshingToken = false
    }

    // MARK: - Fetch Events

    func refreshEventsIfNeeded() {
        guard isAuthenticated && isOAuthConfigured else { return }
        refreshBaselineIfNeeded(range: rangeForVisibleMonth(around: Date()), force: false)
    }

    func refreshEventsIfNeeded(around anchorDate: Date, force: Bool = false) {
        guard isAuthenticated && isOAuthConfigured else { return }

        let visibleRange = rangeForVisibleMonth(around: anchorDate)
        let baselineRange = rangeForVisibleMonth(around: Date())

        refreshVisibleIfNeeded(range: visibleRange, force: force)

        // Keep a baseline "now" window so the menu bar dot / next event continues to work while browsing other months.
        if !(visibleRange.start <= baselineRange.start && visibleRange.end >= baselineRange.end) {
            refreshBaselineIfNeeded(range: baselineRange, force: force)
        }
    }

    private func refreshBaselineIfNeeded(range: DateInterval, force: Bool) {
        if !force, let last = lastBaselineRange, last.start <= range.start, last.end >= range.end {
            return
        }

        lastBaselineRange = range
        fetchGoogleCalendarEvents(range: range, kind: .baseline)
    }

    private func refreshVisibleIfNeeded(range: DateInterval, force: Bool) {
        if !force, let last = lastVisibleRange, last.start <= range.start, last.end >= range.end {
            return
        }

        lastVisibleRange = range
        fetchGoogleCalendarEvents(range: range, kind: .visible)
    }

    private func rangeForVisibleMonth(around anchorDate: Date) -> DateInterval {
        let calendar = Calendar.current

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate))
            ?? calendar.startOfDay(for: anchorDate)

        // Month grid can spill over into adjacent months; fetch a bit extra on both sides.
        let start = calendar.date(byAdding: .day, value: -14, to: startOfMonth) ?? startOfMonth
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? anchorDate
        let end = calendar.date(byAdding: .day, value: 14, to: endOfMonth) ?? endOfMonth

        return DateInterval(start: start, end: end)
    }

    private func fetchGoogleCalendarEvents(range: DateInterval, kind: FetchKind) {
        guard let accessToken = getAccessToken() else {
            DispatchQueue.main.async {
                // If we have a refresh token, a refresh may already be in-flight.
                if self.getRefreshToken(allowUI: false) == nil {
                    self.isAuthenticated = false
                } else {
                    self.isAuthenticated = true
                }
            }
            return
        }

        DispatchQueue.main.async {
            self.inFlightFetches += 1
            self.isLoading = self.inFlightFetches > 0
            self.errorMessage = nil
        }

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: range.start)
        let timeMax = formatter.string(from: range.end)

        guard var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events") else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to construct Google Calendar request URL."
                self.inFlightFetches = max(0, self.inFlightFetches - 1)
                self.isLoading = self.inFlightFetches > 0
            }
            return
        }
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        guard let requestURL = components.url else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to construct Google Calendar request URL."
                self.inFlightFetches = max(0, self.inFlightFetches - 1)
                self.isLoading = self.inFlightFetches > 0
            }
            return
        }
        var request = URLRequest(url: requestURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to fetch events: \(error?.localizedDescription ?? "Network error"). Please check your connection."
                    self.inFlightFetches = max(0, self.inFlightFetches - 1)
                    self.isLoading = self.inFlightFetches > 0
                }
                return
            }

            // Check for 401 Unauthorized
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                DispatchQueue.main.async {
                    self.inFlightFetches = max(0, self.inFlightFetches - 1)
                    self.isLoading = self.inFlightFetches > 0
                }
                self.refreshAccessToken()
                return
            }

            // Check for other HTTP errors
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load events from Google Calendar (Error \(httpResponse.statusCode)). Please try again later."
                    self.inFlightFetches = max(0, self.inFlightFetches - 1)
                    self.isLoading = self.inFlightFetches > 0
                }
                return
            }

            DispatchQueue.main.async {
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
                            calendarId: "google-primary",
                            calendarName: "Google Calendar",
                            calendarColor: NSColor.systemBlue,
                            location: event.location,
                            notes: event.description
                        )
                    }

                    let byId = Dictionary(uniqueKeysWithValues: eventSummaries.map { ($0.id, $0) })
                    switch kind {
                    case .baseline:
                        self.baselineEventsById = byId
                    case .visible:
                        self.visibleEventsById = byId
                    }

                    self.publishMergedEvents()

                    self.inFlightFetches = max(0, self.inFlightFetches - 1)
                    self.isLoading = self.inFlightFetches > 0
                    self.errorMessage = nil
                } catch {
#if DEBUG
                    print("Error decoding Google Calendar events: \(error)")
#endif
                    self.errorMessage = "Unable to process calendar data. Please try refreshing."
                    self.inFlightFetches = max(0, self.inFlightFetches - 1)
                    self.isLoading = self.inFlightFetches > 0
                }
            }
        }.resume()
    }

    private func publishMergedEvents() {
        let merged = baselineEventsById.merging(visibleEventsById) { _, new in new }
        googleEvents = merged.values.sorted { $0.startDate < $1.startDate }
    }

    private func refreshAccessToken() {
        guard isOAuthConfigured else {
            DispatchQueue.main.async {
                self.performSignOut(reason: "Google Calendar is not configured. Add GoogleOAuthConfig.plist and sign in again.")
            }
            return
        }

        guard let refreshToken = getRefreshToken(allowUI: false) else {
            DispatchQueue.main.async {
                self.performSignOut(reason: "Google session expired. Please sign in again.")
            }
            return
        }

        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            DispatchQueue.main.async {
                self.performSignOut(reason: "Failed to refresh Google token. Please sign in again.")
            }
            return
        }

        if isRefreshingToken {
            return
        }
        isRefreshingToken = true

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isRefreshingToken = false

                if let error {
                    self.errorMessage = "Unable to refresh Google session: \(error.localizedDescription)."
                    return
                }

                guard let data = data else {
                    self.errorMessage = "Unable to refresh Google session. Please try again."
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errorDetails = self.oauthErrorDescription(from: data) ?? "Error \(httpResponse.statusCode)"

                    if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                        self.performSignOut(reason: "Google session expired (\(errorDetails)). Please sign in again.")
                        return
                    }

                    self.errorMessage = "Unable to refresh Google session (\(errorDetails))."
                    return
                }

                do {
                    let tokenResponse = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
                    self.saveTokens(accessToken: tokenResponse.access_token,
                                    refreshToken: nil,
                                    expiresIn: tokenResponse.expires_in)
                    self.isAuthenticated = true
                    self.errorMessage = nil

                    // Retry fetching events for the last-known ranges (baseline + visible).
                    let baseline = self.lastBaselineRange ?? self.rangeForVisibleMonth(around: Date())
                    self.refreshBaselineIfNeeded(range: baseline, force: true)

                    if let visible = self.lastVisibleRange {
                        self.refreshVisibleIfNeeded(range: visible, force: true)
                    }
                } catch {
                    self.errorMessage = "Unable to refresh Google session. Please sign in again."
                }
            }
        }.resume()
    }

    private func oauthErrorDescription(from data: Data) -> String? {
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded["error_description"] ?? decoded["error"]
        }
        return String(data: data, encoding: .utf8)
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
        guard isOAuthConfigured else { return nil }

        // If token is expired, try to refresh (if possible) but don't mark the user signed out.
        if isAccessTokenExpired(allowUI: false) {
            if getRefreshToken(allowUI: false) != nil {
                refreshAccessToken()
            }
            return nil
        }

        return getFromKeychain(key: accessTokenKey, allowUI: false)
    }

    private func getRefreshToken(allowUI: Bool) -> String? {
        return getFromKeychain(key: refreshTokenKey, allowUI: allowUI)
    }

    private func isAccessTokenExpired(allowUI: Bool) -> Bool {
        guard let expiryStr = getFromKeychain(key: tokenExpiryKey, allowUI: allowUI),
              let expiryInterval = TimeInterval(expiryStr) else {
            return false
        }

        let expiryDate = Date(timeIntervalSince1970: expiryInterval)
        return Date() > expiryDate
    }

    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let authContext = nonInteractiveAuthContext()
        let itemQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecUseAuthenticationContext as String: authContext,
            kSecValueData as String: data
        ]
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecUseAuthenticationContext as String: authContext
        ]

        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        reportKeychainStatus(deleteStatus, operation: "delete-before-save", key: key)

        let addStatus = SecItemAdd(itemQuery as CFDictionary, nil)
        reportKeychainStatus(addStatus, operation: "save", key: key)
    }

    private func getFromKeychain(key: String, allowUI: Bool) -> String? {
        if !allowUI && keychainAccessBlockedForSession {
            return nil
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        if !allowUI {
            query[kSecUseAuthenticationContext as String] = nonInteractiveAuthContext()
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            reportKeychainStatus(status, operation: "read", key: key)
            return nil
        }

        guard
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) {
        let authContext = nonInteractiveAuthContext()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecUseAuthenticationContext as String: authContext
        ]
        let status = SecItemDelete(query as CFDictionary)
        reportKeychainStatus(status, operation: "delete", key: key)
    }

    private func nonInteractiveAuthContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }

    private func reportKeychainStatus(_ status: OSStatus, operation: String, key: String) {
        guard status != errSecSuccess && status != errSecItemNotFound else { return }

#if DEBUG
        print("Google Keychain \(operation) failed for \(key): \(status)")
#endif

        if status == errSecInteractionNotAllowed || status == errSecAuthFailed || status == errSecUserCanceled {
            keychainAccessBlockedForSession = true
            DispatchQueue.main.async {
                if self.errorMessage == nil || self.errorMessage?.contains("Keychain") == false {
                    self.errorMessage = "Google Calendar credentials couldn't be accessed from Keychain. Please sign in again from Settings."
                }
                self.isAuthenticated = false
            }
        }
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
