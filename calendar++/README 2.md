# calendar++ 📅

A smart, menu bar calendar app for macOS with focus modes, deep work tracking, and powerful automation features.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

### 📅 **Smart Calendar Management**
- Quick access to events from your menu bar
- Unified view of calendars and reminders
- Create and edit events without opening Calendar.app
- Beautiful, native macOS interface

### 🎯 **Focus Modes**
- Switch between Work, Personal, or All calendars
- Hide distractions and focus on what matters
- Smart filtering based on calendar sets

### ⏱️ **Deep Work Integration**
- Built-in deep work timer
- Track productivity sessions
- Energy level tracking for optimal scheduling

### 🔗 **URL Scheme Automation**
- Control calendar++ from anywhere
- Integrate with Shortcuts app
- Scriptable with URL schemes

### ✅ **Reminders Integration**
- View reminders alongside events
- Unified timeline view
- Never miss a task or meeting

## 🚀 Installation

### Via Homebrew (Recommended)

```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
```

### Manual Installation

1. Download the latest release from [Releases](https://github.com/den-kim/calendarplusplus/releases)
2. Extract the ZIP file
3. Move `calendar++.app` to `/Applications/`
4. Launch and grant Calendar permissions

## 🎮 Usage

### Basic Operations

- **Open menu bar:** Click the calendar++ icon in your menu bar
- **Create event:** Click "New Event" or use the URL scheme
- **Switch focus:** Use focus mode buttons (Work/Personal/All)
- **View timeline:** Scroll through unified events and reminders

### URL Schemes

calendar++ supports powerful URL scheme automation:

#### Show specific date
```bash
open "calendarplusplus://show-date?timestamp=1702080000"
```

#### Create new event
```bash
open "calendarplusplus://new-event?title=Meeting&start=1702080000&end=1702083600&location=Office"
```

#### Set focus mode
```bash
# Work calendars only
open "calendarplusplus://set-focus?set=work"

# Personal calendars only
open "calendarplusplus://set-focus?set=personal"

# All calendars
open "calendarplusplus://set-focus?set=all"
```

### Shortcuts Integration

calendar++ integrates with the Shortcuts app for automation:

1. Open Shortcuts.app
2. Create a new shortcut
3. Add "Open URL" action
4. Use `calendarplusplus://` URLs
5. Run from anywhere!

**Example Shortcuts:**
- "Show today's events" → `calendarplusplus://show-date?timestamp=$(date +%s)`
- "Start work mode" → `calendarplusplus://set-focus?set=work`
- "Quick meeting" → Create event with predefined parameters

## 🛠️ Development

### Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Apple Developer account (for code signing)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/den-kim/calendarplusplus.git
cd calendarplusplus

# Open in Xcode
open calendar++.xcodeproj

# Build and run
# Cmd+R in Xcode
```

### Project Structure

```
calendar++/
├── calendar__App.swift          # Main app entry point
├── EventKitManager.swift        # EventKit integration
├── CalendarViewModel.swift      # Calendar state management
├── FocusManager.swift           # Focus mode logic
├── CalenderPlusIntents.swift    # Shortcuts integration
├── Views/
│   ├── AgendaListView.swift
│   ├── EventContextCardView.swift
│   ├── SmartSchedulingView.swift
│   └── ...
├── Info.plist                   # App configuration
└── ...
```

### Configuration

The app requires these Info.plist entries:

- `NSCalendarsUsageDescription` - Calendar access
- `NSRemindersUsageDescription` - Reminders access
- `CFBundleURLTypes` - URL scheme (`calendarplusplus://`)
- `com.apple.security.application-groups` - Widget support

See [INFO_PLIST_CONFIGURATION.md](INFO_PLIST_CONFIGURATION.md) for details.

## 📦 Distribution

### Creating a Release

```bash
# Build and sign
./build-release.sh 1.0.0

# Create GitHub release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Upload ZIP to GitHub Releases
# Update Homebrew formula
```

See [HOMEBREW_DISTRIBUTION_GUIDE.md](HOMEBREW_DISTRIBUTION_GUIDE.md) for complete instructions.

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Contribution Guidelines

- Follow Swift naming conventions
- Add tests for new features
- Update documentation as needed
- Ensure code signing works
- Test on clean macOS install

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with SwiftUI and EventKit
- Icons and design inspired by macOS Big Sur+
- Thanks to the Homebrew team for cask distribution

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/den-kim/calendarplusplus/issues)
- **Discussions:** [GitHub Discussions](https://github.com/den-kim/calendarplusplus/discussions)
- **Email:** your@email.com

## 🗺️ Roadmap

### v1.1
- [ ] Widget extension for Notification Center
- [ ] Natural language event parsing
- [ ] Weather integration
- [ ] Meeting conflict detection

### v1.2
- [ ] Multiple timezone support
- [ ] Calendar syncing improvements
- [ ] Custom event templates
- [ ] Advanced deep work analytics

### v2.0
- [ ] visionOS support
- [ ] Team calendar sharing
- [ ] AI-powered scheduling suggestions
- [ ] Calendar insights dashboard

## 🎯 System Requirements

- **macOS:** 13.0 (Ventura) or later
- **RAM:** 4 GB minimum
- **Disk Space:** 50 MB
- **Permissions:** Calendar, Reminders

## ⚙️ Preferences

Access preferences via:
- Menu bar icon → Preferences
- Or: `open "calendarplusplus://preferences"`

**Available Settings:**
- Default calendar for new events
- Focus mode calendar assignments
- Deep work timer duration
- Launch at login
- Menu bar icon style

## 🔒 Privacy

calendar++ respects your privacy:

- ✅ All data stays on your device
- ✅ No analytics or tracking
- ✅ No internet connection required
- ✅ Open source and auditable
- ✅ Uses only Apple's EventKit APIs

## 📊 Stats

![GitHub Stars](https://img.shields.io/github/stars/den-kim/calendarplusplus?style=social)
![GitHub Forks](https://img.shields.io/github/forks/den-kim/calendarplusplus?style=social)
![GitHub Issues](https://img.shields.io/github/issues/den-kim/calendarplusplus)

---

Made with ❤️ by [den-kim](https://github.com/den-kim)

**Star ⭐ this repo if you find it useful!**
