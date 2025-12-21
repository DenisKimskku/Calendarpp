# Google Calendar Integration Guide for calendar++

## What's Been Fixed and Added

### ✅ Calendar Permissions Fixed
- The app now properly requests calendar access on first launch
- Your local Calendar app events will now display correctly
- Calendar and Reminder permissions are now included in the app's Info.plist

### ✅ Google Calendar Integration Added
- Full OAuth 2.0 integration with PKCE for security
- Securely stores credentials in macOS Keychain
- Auto-refreshes access tokens
- Merges Google Calendar events with local Calendar events
- Events show with proper color coding

## How to Set Up Google Calendar

### Step 1: Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click "Select a project" → "New Project"
3. Name it "calendar++ Integration" (or anything you like)
4. Click "Create"

### Step 2: Enable Google Calendar API
1. In your project, go to "APIs & Services" → "Library"
2. Search for "Google Calendar API"
3. Click on it and click "Enable"

### Step 3: Create OAuth 2.0 Credentials
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - User Type: External
   - App name: "calendar++"
   - User support email: your email
   - Developer contact: your email
   - Click "Save and Continue" through all steps
4. Back to "Create OAuth client ID":
   - Application type: "Desktop app"
   - Name: "calendar++ macOS"
   - Click "Create"
5. **IMPORTANT**: Copy the "Client ID" that appears

### Step 4: Add Client ID to the App
1. Open `/Users/den/Desktop/calendar++/calendar++/GoogleCalendarManager.swift`
2. Find line 66: `private let clientId = "YOUR_CLIENT_ID"`
3. Replace `YOUR_CLIENT_ID` with your actual Client ID from Step 3
4. Save the file

### Step 5: Rebuild the App
```bash
cd /Users/den/Desktop/calendar++
xcodebuild clean build -project calendar++.xcodeproj -scheme calendar++ -configuration Release -derivedDataPath build
dot_clean build/Build/Products/Release/calendar++.app
xattr -cr build/Build/Products/Release/calendar++.app
codesign --force --deep --sign - build/Build/Products/Release/calendar++.app
open build/Build/Products/Release/calendar++.app
```

### Step 6: Sign In with Google
1. Click the calendar++ icon in your menu bar
2. Click the Settings (gear) icon
3. Go to the "Google Calendar" tab
4. Click "Sign In with Google"
5. Your browser will open - sign in with your Google account
6. Grant calendar read permissions
7. You'll be redirected back to the app
8. Your Google Calendar events will now appear!

## Using the App

### Menu Bar
- Shows current date (format customizable in Settings)
- Busy bar indicator showing your daily schedule
- Dot indicator for upcoming events (within 30 minutes)

### Calendar View
- Click the menu bar icon to open
- Month view with today highlighted
- Click any day to see its events
- Events are color-coded by calendar
- Shows both local Calendar app events AND Google Calendar events

### Settings
- **General**: Start at login, week start day
- **Menu Bar**: Date format options, event indicators
- **Google Calendar**: Sign in/out, connection status

## Troubleshooting

### Events from Calendar app not showing
- Grant calendar permissions when prompted on first launch
- Check System Settings → Privacy & Security → Calendars
- Make sure calendar++ is checked

### Google Calendar sign-in doesn't work
- Make sure you've replaced `YOUR_CLIENT_ID` in GoogleCalendarManager.swift
- Rebuild the app after changing the Client ID
- Check that the redirect URI `calenderplus://oauth2callback` is added in Google Cloud Console (it should work automatically with the desktop app type)

### Events not refreshing
- Close and reopen the menu bar popup
- Click Settings → Google Calendar to see connection status
- If signed out, sign in again

## Security
- All credentials are stored securely in macOS Keychain
- Uses OAuth 2.0 with PKCE (no client secrets exposed)
- Only requests read-only access to your calendars
- Tokens are automatically refreshed

## File Locations
- App: `/Users/den/Desktop/calendar++/build/Build/Products/Release/calendar++.app`
- Source: `/Users/den/Desktop/calendar++/calendar++/`
- Build script: `/Users/den/Desktop/calendar++/calendar++/build-release.sh`

## Summary of Changes

### Files Modified:
1. `calendar__App.swift` - Added GoogleCalendarManager, OAuth URL handling
2. `EventKitManager.swift` - Added Google events merging
3. `MenuBarRootView.swift` - Added Google Calendar sync
4. `PreferencesView.swift` - Added Google Calendar settings tab
5. `CalendarModels.swift` - Made EventSummary Equatable
6. `project.pbxproj` - Added calendar permissions to Info.plist

### Files Created:
1. `GoogleCalendarManager.swift` - Complete Google Calendar API integration
2. `GoogleCalendarSettingsView.swift` - Google Calendar settings UI

Enjoy your enhanced calendar++ app! 🎉
