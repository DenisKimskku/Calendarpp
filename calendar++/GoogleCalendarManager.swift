import Foundation
import Combine
import AppKit
import Network

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
    private let keychainService = "den-kim.calendar--"
    private let accessTokenKey = "google_access_token"
    private let refreshTokenKey = "google_refresh_token"
    private let tokenExpiryKey = "google_token_expiry"

    private var cancellables = Set<AnyCancellable>()
    private var localServer: NWListener?
    private var redirectUri: String = ""
    private var serverPort: UInt16 = 0

    init() {
        // Load OAuth credentials from plist
        if let path = Bundle.main.path(forResource: "GoogleOAuthConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let id = config["clientId"] as? String,
           let secret = config["clientSecret"] as? String {
            self.clientId = id
            self.clientSecret = secret
        } else {
            fatalError("GoogleOAuthConfig.plist not found or invalid")
        }

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
        // Clear any previous errors
        DispatchQueue.main.async {
            self.errorMessage = nil
            self.isAuthenticating = true
        }

        // Generate code verifier and challenge for PKCE
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Save code verifier for later
        saveToKeychain(key: "code_verifier", value: codeVerifier)

        // Start local server first
        startLocalServer { [weak self] port in
            guard let self = self else { return }

            self.serverPort = port
            self.redirectUri = "http://127.0.0.1:\(port)"

            // Build OAuth URL with loopback redirect
            var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
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

        guard let codeVerifier = getFromKeychain(key: "code_verifier") else {
            sendHTMLResponse(to: connection, html: "<h1>Error</h1><p>Authentication failed</p>")
            DispatchQueue.main.async {
                self.errorMessage = "Authentication failed: Security verification error. Please try signing in again."
                self.isAuthenticating = false
            }
            stopLocalServer()
            return
        }

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

        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func stopLocalServer() {
        localServer?.cancel()
        localServer = nil
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) {
        // Write debug info to file
        let debugInfo = """
        === Google OAuth Token Exchange ===
        Timestamp: \(Date())
        Redirect URI: \(redirectUri)
        Client ID: \(clientId)
        Code: \(code)
        Code verifier: \(codeVerifier)

        """

        if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? {
            let logPath = "\(homeDir)/Desktop/calendar-oauth-debug.log"
            try? debugInfo.write(toFile: logPath, atomically: true, encoding: .utf8)
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
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

                // Write error to file
                if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? {
                    let logPath = "\(homeDir)/Desktop/calendar-oauth-debug.log"
                    let errorInfo = """

                    === ERROR Response ===
                    Status Code: \(httpResponse.statusCode)
                    Error Body: \(errorBody)
                    """
                    if let existing = try? String(contentsOfFile: logPath) {
                        try? (existing + errorInfo).write(toFile: logPath, atomically: true, encoding: .utf8)
                    }
                }

                DispatchQueue.main.async {
                    // Parse error details from Google's response
                    var detailedError = "Error \(httpResponse.statusCode)"
                    if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
                       let errorDesc = errorData["error_description"] ?? errorData["error"] {
                        detailedError = errorDesc
                    }

                    self.errorMessage = "Authentication failed: \(detailedError). Check Desktop/calendar-oauth-debug.log for details."
                    self.isAuthenticating = false
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
                    self.isAuthenticating = false
                    self.errorMessage = nil
                    self.fetchGoogleCalendarEvents()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Authentication failed: Unable to process Google's response. Please try again."
                    self.isAuthenticating = false
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
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.isLoading = false
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
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
            guard let self = self else { return }

            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to fetch events: \(error?.localizedDescription ?? "Network error"). Please check your connection."
                    self.isLoading = false
                }
                return
            }

            // Check for 401 Unauthorized
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                self.refreshAccessToken()
                return
            }

            // Check for other HTTP errors
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load events from Google Calendar (Error \(httpResponse.statusCode)). Please try again later."
                    self.isLoading = false
                }
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
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                print("Error decoding Google Calendar events: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to process calendar data. Please try refreshing."
                    self.isLoading = false
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
            "client_secret": clientSecret,
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
