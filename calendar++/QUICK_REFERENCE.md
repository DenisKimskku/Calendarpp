# 🚀 Quick Reference Card

Essential information for calendar++ at a glance.

## 📱 App Information

| Item | Value |
|------|-------|
| **App Name** | calendar++ |
| **Bundle ID** | `com.den-kim.calendarplusplus` |
| **App Group** | `group.com.den-kim.calendarplusplus` |
| **URL Scheme** | `calendarplusplus://` |
| **Min macOS** | 13.0 (Ventura) |
| **Platform** | macOS (menu bar app) |

## 🔗 Repositories

| Repository | URL |
|------------|-----|
| **Main** | `github.com/den-kim/calendarplusplus` |
| **Homebrew Tap** | `github.com/den-kim/homebrew-tap` |

## 🍺 Installation

```bash
# Add tap
brew tap den-kim/tap

# Install
brew install --cask calendar-plus-plus

# Update
brew upgrade --cask calendar-plus-plus

# Uninstall
brew uninstall --cask calendar-plus-plus
```

## 🔗 URL Schemes

```bash
# Show date
open "calendarplusplus://show-date?timestamp=UNIX_TIMESTAMP"

# Create event
open "calendarplusplus://new-event?title=TITLE&start=TIMESTAMP&end=TIMESTAMP&location=LOCATION"

# Focus modes
open "calendarplusplus://set-focus?set=work"
open "calendarplusplus://set-focus?set=personal"
open "calendarplusplus://set-focus?set=all"

# Test with current time
open "calendarplusplus://show-date?timestamp=$(date +%s)"
```

## 🛠️ Build Commands

```bash
# Build release
./build-release.sh 1.0.0

# Calculate SHA256
shasum -a 256 build/calendar++-v1.0.0.zip

# Test app
open build/export/calendar++.app
```

## 🏷️ Git Commands

```bash
# Create tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Push tag
git push origin v1.0.0

# Delete tag (if needed)
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

## 🔐 Code Signing

```bash
# Sign app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: YOUR NAME (TEAM_ID)" \
  build/export/calendar++.app

# Verify signature
codesign --verify --verbose=4 build/export/calendar++.app

# Submit for notarization
xcrun notarytool submit build/calendar++-v1.0.0.zip \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Staple ticket
xcrun stapler staple build/export/calendar++.app
```

## 📝 File Locations

| File | Purpose |
|------|---------|
| `Info.plist` | App configuration |
| `calendar-plus-plus.rb` | Homebrew formula |
| `build-release.sh` | Build script |
| `.gitignore` | Git ignore rules |
| `README.md` | User documentation |
| `CONTRIBUTING.md` | Developer guide |

## 🔧 Xcode Settings

| Setting | Value |
|---------|-------|
| **Bundle Identifier** | `com.den-kim.calendarplusplus` |
| **Version** | `1.0.0` |
| **Build** | `1` |
| **Min macOS** | `13.0` |
| **Info.plist Path** | `$(SRCROOT)/Info.plist` |
| **App Groups** | `group.com.den-kim.calendarplusplus` |

## 🔑 GitHub Secrets

| Secret | Description |
|--------|-------------|
| `DEVELOPER_ID_CERTIFICATE` | Certificate as Base64 |
| `CERTIFICATE_PASSWORD` | Certificate export password |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | App-specific password |
| `TEAM_ID` | 10-character Team ID |

## 📊 Release Checklist

- [ ] Update version in Xcode
- [ ] Run `build-release.sh VERSION`
- [ ] Calculate SHA256
- [ ] Create git tag
- [ ] Push tag to GitHub
- [ ] Create GitHub Release
- [ ] Upload ZIP to release
- [ ] Update Homebrew formula
- [ ] Test installation
- [ ] Update CHANGELOG.md

## 🐛 Debugging

```bash
# Check app signature
codesign -dv --verbose=4 /Applications/calendar++.app

# View system logs
log stream --predicate 'process == "calendar++"' --level debug

# Test URL scheme
open "calendarplusplus://show-date?timestamp=$(date +%s)"

# Check Homebrew formula
brew audit --cask --online calendar-plus-plus
brew style calendar-plus-plus
```

## 📱 Permissions

```xml
<!-- In Info.plist -->
<key>NSCalendarsUsageDescription</key>
<string>calendar++ needs access to your calendars...</string>

<key>NSRemindersUsageDescription</key>
<string>calendar++ needs access to your reminders...</string>
```

## 🎯 Support Resources

| Resource | Link |
|----------|------|
| **Documentation** | README.md, SETUP_COMPLETE.md |
| **Distribution** | HOMEBREW_DISTRIBUTION_GUIDE.md |
| **Contributing** | CONTRIBUTING.md |
| **Issues** | github.com/den-kim/calendarplusplus/issues |

## ⚡ Quick Tips

✅ **Always test on clean macOS** before public release  
✅ **Keep Team ID and credentials secure**  
✅ **Update SHA256 in formula** after each build  
✅ **Tag format:** `v1.0.0` (with 'v' prefix)  
✅ **Test URL schemes** before releasing  
✅ **Check permissions** work on first launch  

## 🎉 One-Line Install

```bash
brew tap den-kim/tap && brew install --cask calendar-plus-plus
```

---

**Save this file for quick reference!** 📌
