# Changelog

All notable changes to calendar++ will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Features planned for next release

### Changed
- Changes planned for next release

### Fixed
- Bug fixes planned for next release

## [1.0.0] - 2024-12-07

### Added
- 📅 Menu bar calendar with quick event access
- 🎯 Focus modes (Work/Personal/All calendars)
- ⏱️ Deep work timer and productivity tracking
- 🔗 URL scheme automation (`calendarplusplus://`)
- ✅ Unified reminders and events timeline
- 🚀 Shortcuts app integration
- 📱 Native EventKit integration for calendar access
- 🎨 Beautiful native macOS interface with SwiftUI
- 🔒 Privacy-focused (all data stays on device)
- 🌐 Open source and auditable code

### URL Schemes
- `calendarplusplus://show-date?timestamp=<unix_timestamp>` - Show specific date
- `calendarplusplus://new-event?title=<title>&start=<timestamp>&end=<timestamp>&location=<location>` - Create event
- `calendarplusplus://set-focus?set=<work|personal|all>` - Set focus mode

### Technical
- macOS 13.0+ support
- Swift 5.9+ codebase
- SwiftUI for modern UI
- EventKit for calendar integration
- Homebrew cask distribution
- Developer ID code signing
- Notarization support

### Distribution
- Available via Homebrew: `brew install --cask calendar-plus-plus`
- Manual installation via GitHub Releases
- Automated builds with GitHub Actions

---

## Release Types

### Major (x.0.0)
- Breaking changes
- Major new features
- Architecture changes

### Minor (0.x.0)
- New features
- Enhancements
- Non-breaking changes

### Patch (0.0.x)
- Bug fixes
- Security patches
- Minor improvements

---

## Future Roadmap

### v1.1.0 (Planned)
- [ ] Widget extension for Notification Center
- [ ] Natural language event parsing
- [ ] Weather integration
- [ ] Meeting conflict detection
- [ ] Custom event templates

### v1.2.0 (Planned)
- [ ] Multiple timezone support
- [ ] Calendar syncing improvements
- [ ] Advanced deep work analytics
- [ ] Event insights dashboard

### v2.0.0 (Future)
- [ ] visionOS support
- [ ] Team calendar sharing
- [ ] AI-powered scheduling suggestions
- [ ] Calendar insights and predictions

---

[Unreleased]: https://github.com/den-kim/calendarplusplus/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/den-kim/calendarplusplus/releases/tag/v1.0.0
