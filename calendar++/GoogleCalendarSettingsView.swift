import SwiftUI

struct GoogleCalendarSettingsView: View {
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    var body: some View {
        Form {
            Section {
                if googleCalendar.isAuthenticating {
                    // Authenticating state
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Signing in to Google Calendar...")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 8)

                    if let error = googleCalendar.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)

                        Button("Try Again") {
                            googleCalendar.startOAuthFlow()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if googleCalendar.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected to Google Calendar")
                                .font(.subheadline)
                            if googleCalendar.isLoading {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Loading events...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("\(googleCalendar.googleEvents.count) events synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button("Sign Out") {
                        googleCalendar.signOut()
                    }
                    .foregroundColor(.red)

                    if let error = googleCalendar.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
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
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}
