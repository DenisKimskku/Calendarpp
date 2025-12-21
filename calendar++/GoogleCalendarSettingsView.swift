import SwiftUI

struct GoogleCalendarSettingsView: View {
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    var body: some View {
        Form {
            Section {
                if googleCalendar.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to Google Calendar")
                            .font(.subheadline)
                    }

                    Text("Your Google Calendar events are being synced.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Sign Out") {
                        googleCalendar.signOut()
                    }
                    .foregroundColor(.red)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect Google Calendar")
                            .font(.headline)

                        Text("Sign in with your Google account to sync your Google Calendar events.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Sign In with Google") {
                            googleCalendar.startOAuthFlow()
                        }
                        .buttonStyle(.borderedProminent)

                        if let error = googleCalendar.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Divider()
                            .padding(.vertical, 4)

                        Text("Setup Instructions:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Go to Google Cloud Console")
                            Text("2. Create a new project or select existing")
                            Text("3. Enable Google Calendar API")
                            Text("4. Create OAuth 2.0 credentials")
                            Text("5. Add 'calenderplus://oauth2callback' as redirect URI")
                            Text("6. Update CLIENT_ID in GoogleCalendarManager.swift")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)

                        Link("Open Google Cloud Console", destination: URL(string: "https://console.cloud.google.com")!)
                            .font(.caption)
                    }
                }
            }
        }
    }
}
