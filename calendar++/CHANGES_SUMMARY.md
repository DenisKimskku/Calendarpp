# Changes Summary for den-kim/calendarplusplus

## ✅ Completed Updates

### 1. Branding & Naming
- **Company:** den-kim
- **Bundle ID:** com.den-kim.calendarplusplus
- **App Group:** group.com.den-kim.calendarplusplus
- **URL Scheme:** calendarplusplus:// (updated from calenderplus://)

### 2. Files Created/Updated

#### Created Files:
1. **Info.plist** - Complete configuration with all required keys
2. **calendar-plus-plus.rb** - Homebrew Cask formula ready for distribution
3. **HOMEBREW_DISTRIBUTION.md** - Comprehensive guide for Homebrew distribution
4. **QUICK_START_HOMEBREW.md** - Step-by-step quick start guide
5. **exportOptions.plist** - Build export configuration template

#### Updated Files:
1. **INFO_PLIST_CONFIGURATION.md** - Updated all references:
   - calenderplus → calendarplusplus
   - com.yourcompany → com.den-kim
   - All URL scheme examples updated
   
2. **calendar__App.swift** - Updated URL scheme handler:
   - Changed from `calenderplus://` to `calendarplusplus://`

## 📦 Distribution via Homebrew

### Quick Setup (Recommended)

1. **Create GitHub repository:** `den-kim/homebrew-tap`
2. **Add the cask formula** to `Casks/calendar-plus-plus.rb`
3. **Users install with:**
   ```bash
   brew tap den-kim/tap
   brew install --cask calendar-plus-plus
   ```

### Two Distribution Options:

#### Option A: Your Own Tap (Faster, recommended to start)
- Full control over updates
- No approval process
- Can update immediately
- Great for beta testing
- Command: `brew tap den-kim/tap`

#### Option B: Official Homebrew Cask
- Appears in main Homebrew search
- Wider discoverability
- Requires PR approval
- Follows strict guidelines
- Command: `brew install --cask calendar-plus-plus`

## 🚀 Next Steps to Publish

### 1. Code Signing (Required)
```bash
# In Xcode:
# Signing & Capabilities → Team → Select your team
# Signing Certificate → Developer ID Application
```

### 2. Notarization (Required for distribution)
```bash
# After building, notarize with:
xcrun notarytool submit calendar++.zip \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

### 3. Create First Release
```bash
# Tag and push
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0

# Build
xcodebuild archive -scheme "calendar++" -archivePath "build/calendar++.xcarchive"

# Export  
xcodebuild -exportArchive -archivePath "build/calendar++.xcarchive" \
  -exportPath "build" -exportOptionsPlist exportOptions.plist

# Create ZIP
cd build
ditto -c -k --sequesterRsrc --keepParent "calendar++.app" "calendar++-v1.0.0.zip"

# Get SHA256
shasum -a 256 calendar++-v1.0.0.zip
```

### 4. Upload to GitHub Releases
1. Go to https://github.com/den-kim/calendarplusplus/releases/new
2. Choose tag v1.0.0
3. Upload calendar++-v1.0.0.zip
4. Publish release

### 5. Update Homebrew Formula
```ruby
# In calendar-plus-plus.rb, update:
version "1.0.0"
sha256 "PASTE_YOUR_SHA256_HERE"
```

### 6. Push to Homebrew Tap
```bash
cd homebrew-tap
git add Casks/calendar-plus-plus.rb
git commit -m "Update calendar++ to v1.0.0"
git push
```

## 🔧 Configuration Files Reference

### Info.plist Key Settings
```xml
Bundle ID: com.den-kim.calendarplusplus
URL Scheme: calendarplusplus
App Group: group.com.den-kim.calendarplusplus
Min macOS: 13.0 (Ventura)
```

### URL Scheme Examples
```bash
# Show specific date
open "calendarplusplus://show-date?timestamp=$(date +%s)"

# Create event
open "calendarplusplus://new-event?title=Meeting&start=1702080000&end=1702083600"

# Set focus
open "calendarplusplus://set-focus?set=work"
```

## 📝 Checklist for First Release

- [ ] Update Xcode project bundle ID to `com.den-kim.calendarplusplus`
- [ ] Add Info.plist to Xcode project
- [ ] Configure App Groups in Signing & Capabilities
- [ ] Set up Developer ID code signing
- [ ] Configure notarization credentials
- [ ] Update exportOptions.plist with your Team ID
- [ ] Create GitHub repository: calendarplusplus
- [ ] Create GitHub repository: homebrew-tap
- [ ] Build and test app locally
- [ ] Create v1.0.0 tag
- [ ] Build release version
- [ ] Create ZIP and calculate SHA256
- [ ] Upload to GitHub Releases
- [ ] Update Homebrew formula with SHA256
- [ ] Test installation: `brew tap den-kim/tap && brew install --cask calendar-plus-plus`
- [ ] Test URL schemes
- [ ] Update README with installation instructions

## 🎯 User Installation Experience

Once published, users will install calendar++ with these simple commands:

```bash
# Add your tap (one-time)
brew tap den-kim/tap

# Install calendar++
brew install --cask calendar-plus-plus

# calendar++ launches automatically and appears in menu bar
```

To update:
```bash
brew upgrade --cask calendar-plus-plus
```

## 📚 Documentation Files

1. **HOMEBREW_DISTRIBUTION.md** - Complete distribution guide with:
   - Cask vs Formula differences
   - GitHub Actions automation
   - Code signing & notarization
   - Release workflow

2. **QUICK_START_HOMEBREW.md** - Quick reference for:
   - Release process
   - Building commands
   - Testing steps
   - Troubleshooting

3. **INFO_PLIST_CONFIGURATION.md** - App configuration for:
   - URL schemes
   - Permissions
   - App groups
   - Widget setup

## 🔗 Important URLs

- App Repository: https://github.com/den-kim/calendarplusplus
- Homebrew Tap: https://github.com/den-kim/homebrew-tap
- Releases: https://github.com/den-kim/calendarplusplus/releases

## 💡 Tips

1. **Semantic Versioning**: Use v1.0.0, v1.1.0, v2.0.0 format
2. **Changelog**: Keep CHANGELOG.md for each release
3. **Testing**: Test cask formula before pushing: `brew audit --cask --online`
4. **Automation**: Use GitHub Actions for automatic builds on tag push
5. **Communication**: Add release notes to GitHub releases

## 🐛 Common Issues

### "App is damaged and can't be opened"
- Solution: App must be code signed and notarized

### "Permission denied" when accessing calendars
- Solution: Info.plist must include NSCalendarsUsageDescription

### URL scheme not working
- Solution: Verify CFBundleURLSchemes in Info.plist matches "calendarplusplus"

### Homebrew SHA mismatch
- Solution: Recalculate SHA256 from actual release ZIP file

## 🎉 You're Ready!

All configuration files are ready. Follow QUICK_START_HOMEBREW.md to publish your first release!
