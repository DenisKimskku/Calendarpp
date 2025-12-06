# calendar++ 📅

A smart, menu bar calendar app for macOS with deep work sessions, unified timeline, and powerful automation.

## Features

- 🗓️ **Smart Calendar Management** - View and manage your events from the menu bar
- ⏰ **Unified Timeline** - Combine calendar events and reminders in one view
- 🎯 **Deep Work Sessions** - Focus mode with timer and distraction blocking
- 🔄 **Calendar Focus** - Switch between work, personal, or all calendars
- 🔗 **URL Scheme Automation** - Control calendar++ from anywhere
- ⌨️ **Shortcuts Integration** - Automate with Siri and Shortcuts app
- 📊 **Event Energy Tracking** - Monitor your schedule's energy levels

## Installation

### Via Homebrew (Recommended)

```bash
# Add the tap
brew tap den-kim/tap

# Install calendar++
brew install --cask calendar-plus-plus
```

### Direct Download

Download the latest release from [Releases](https://github.com/den-kim/calendarplusplus/releases), extract the ZIP, and move `calendar++.app` to your Applications folder.

## Usage

### Menu Bar

Click the calendar++ icon in your menu bar to:
- View today's events and upcoming schedule
- Create new events quickly
- Start deep work sessions
- Switch calendar focus modes
- Access preferences

### URL Scheme

Automate calendar++ with URL schemes:

```bash
# Show specific date
open "calendarplusplus://show-date?timestamp=1702080000"

# Create new event
open "calendarplusplus://new-event?title=Meeting&start=1702080000&end=1702083600&location=Office"

# Set calendar focus
open "calendarplusplus://set-focus?set=work"
open "calendarplusplus://set-focus?set=personal"
open "calendarplusplus://set-focus?set=all"
```

### Shortcuts Integration

Use these actions in the Shortcuts app:
- **Create Calendar Event** - Add events with Siri
- **Get Next Event** - Query your schedule
- **Start Deep Work** - Begin a focus session
- **Set Calendar Focus** - Switch calendar sets

## Requirements

- macOS 13.0 (Ventura) or later
- Calendar access permission
- Reminders access permission (optional, for unified timeline)

## Configuration

calendar++ requires permissions for:
- **Calendar** - To display and manage your events
- **Reminders** - To show reminders in your timeline (optional)

Permissions will be requested on first launch.

## Building from Source

### Prerequisites

- Xcode 15.0 or later
- macOS 14.0 or later (for development)
- Apple Developer account (for code signing)

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/den-kim/calendarplusplus.git
   cd calendarplusplus
   ```

2. Open in Xcode:
   ```bash
   open calendar++.xcodeproj
   ```

3. Configure signing:
   - Select the calendar++ target
   - Go to Signing & Capabilities
   - Select your team
   - Update bundle identifier if needed

4. Build:
   - Product → Build (⌘B)
   - Product → Run (⌘R)

### Build for Release

Use the included build script:

```bash
chmod +x build-release.sh
./build-release.sh 1.0.0
```

This will:
- Build an optimized release version
- Create a distributable ZIP
- Calculate SHA256 checksum
- Generate release notes

## Development

### Project Structure

```
calendar++/
├── calendar__App.swift          # Main app entry point
├── EventKitManager.swift        # Calendar/EventKit integration
├── CalendarViewModel.swift      # Calendar state management
├── FocusManager.swift           # Calendar focus modes
├── EventContextCardView.swift   # Event details UI
├── AgendaListView.swift         # Timeline/agenda view
├── SmartSchedulingView.swift    # Smart scheduling features
└── CalenderPlusIntents.swift    # Shortcuts/Siri integration
```

### Key Technologies

- **SwiftUI** - Modern UI framework
- **EventKit** - Calendar and reminders access
- **AppIntents** - Shortcuts and Siri integration
- **MenuBarExtra** - Native menu bar integration

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Guidelines

1. Follow Swift style guidelines
2. Test on latest macOS version
3. Update documentation for new features
4. Add tests where applicable

## Distribution

### For Users

Install via Homebrew:
```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
```

### For Maintainers

See detailed distribution guides:
- [Quick Start Guide](QUICK_START_HOMEBREW.md) - Fast release process
- [Complete Distribution Guide](HOMEBREW_DISTRIBUTION.md) - Detailed instructions
- [Changes Summary](CHANGES_SUMMARY.md) - Recent updates

## Privacy

calendar++ runs entirely on your device:
- ✅ All data stays local
- ✅ No analytics or tracking
- ✅ No internet connection required
- ✅ No data collection

Your calendar data is only accessed with your explicit permission and never leaves your Mac.

## License

[Add your license here - MIT, Apache, etc.]

## Support

- 🐛 [Report Issues](https://github.com/den-kim/calendarplusplus/issues)
- 💬 [Discussions](https://github.com/den-kim/calendarplusplus/discussions)
- 📧 Contact: [your email]

## Roadmap

- [ ] Widget support for macOS Sonoma
- [ ] iCloud sync for preferences
- [ ] Advanced natural language event creation
- [ ] Meeting notes integration
- [ ] Team calendar support

## Acknowledgments

Built with:
- SwiftUI and EventKit
- Love for productivity tools
- Coffee ☕

---

Made with ❤️ by den-kim

**Install now:** `brew tap den-kim/tap && brew install --cask calendar-plus-plus`
