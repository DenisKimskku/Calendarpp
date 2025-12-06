# Info.plist Configuration for calendar++

Add these entries to your app's Info.plist file for full functionality:

## 1. URL Scheme (Required for automation)

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>CalenderPlusURL</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>calenderplus</string>
    </array>
  </dict>
</array>
```

## 2. Calendar & Reminder Permissions (Required)

```xml
<key>NSCalendarsUsageDescription</key>
<string>calendar++ needs access to your calendars to show and manage your events.</string>

<key>NSRemindersUsageDescription</key>
<string>calendar++ needs access to your reminders to show them in your unified timeline.</string>
```

## 3. App Groups (Required for Widget Extension)

```xml
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.yourcompany.calenderplus</string>
</array>
```

## 4. Background Modes (Optional, for better refresh)

```xml
<key>UIBackgroundModes</key>
<array>
  <string>processing</string>
  <string>fetch</string>
</array>
```

## URL Scheme Usage Examples

### Show specific date:
```
calenderplus://show-date?timestamp=1702080000
```

### Create new event:
```
calenderplus://new-event?title=Meeting&start=1702080000&end=1702083600&location=Office
```

### Set calendar focus:
```
calenderplus://set-focus?set=work
calenderplus://set-focus?set=personal
calenderplus://set-focus?set=all
```

## Shortcuts Integration

After adding CalenderPlusIntents.swift to your project, these actions will be available in Shortcuts app:

1. **Create Calendar Event** - Create events with Siri/Shortcuts
2. **Get Next Event** - Query upcoming events
3. **Start Deep Work** - Begin focus session
4. **Set Calendar Focus** - Switch between Work/Personal/All

## Widget Extension Setup

1. In Xcode: File > New > Target > Widget Extension
2. Name it "CalenderPlusWidget"
3. Add CalenderPlusWidget.swift to the widget target
4. Configure App Groups in both targets:
   - Main app: Signing & Capabilities > App Groups
   - Widget: Signing & Capabilities > App Groups
   - Use same group ID: group.com.yourcompany.calenderplus

## Testing URL Schemes

Test in Terminal:
```bash
open "calenderplus://show-date?timestamp=$(date +%s)"
```

Test with Shortcuts:
1. Open Shortcuts app
2. Create new shortcut
3. Add "Open URL" action
4. Use calenderplus:// URLs
