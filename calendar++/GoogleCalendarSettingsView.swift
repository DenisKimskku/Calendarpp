import SwiftUI

struct GoogleCalendarSettingsView: View {
    @EnvironmentObject var googleCalendar: GoogleCalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Google Calendar")
                    .font(.title3.weight(.semibold))
                Text("Connect your Google account to sync events into calendar++.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .calendarPPZenCard(cornerRadius: 14, strong: true)

            accountCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if googleCalendar.isAuthenticating {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Signing in to Google Calendar...")
                        .font(.subheadline)
                }

                Text("Finish sign-in in your browser, then return here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if googleCalendar.isAuthenticated {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected")
                            .font(.subheadline.bold())
                        if googleCalendar.isLoading {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Refreshing events...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("\(googleCalendar.googleEvents.count) events synced")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button("Refresh Now") {
                        googleCalendar.refreshEventsIfNeeded(around: Date(), force: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(googleCalendar.isLoading)

                    Button("Sign Out", role: .destructive) {
                        googleCalendar.signOut()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("Sign in with your Google account to sync your Google Calendar events.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Sign In with Google") {
                    googleCalendar.startOAuthFlow()
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = googleCalendar.errorMessage, !error.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.10))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .calendarPPZenCard(cornerRadius: 14, strong: false)
    }
}
