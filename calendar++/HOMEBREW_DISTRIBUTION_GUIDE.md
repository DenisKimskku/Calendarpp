# Homebrew Distribution Guide for calendar++

This guide walks you through distributing your calendar++ app via Homebrew.

## 📦 Overview

**Main Repository:** `github.com/den-kim/calendarplusplus`  
**Homebrew Tap:** `github.com/den-kim/homebrew-tap`  
**Bundle ID:** `com.den-kim.calendarplusplus`  
**App Group:** `group.com.den-kim.calendarplusplus`  
**URL Scheme:** `calendarplusplus://`

## 🎯 Step 1: GitHub Repositories Setup

### Create Main Repository

```bash
# Create on GitHub: den-kim/calendarplusplus
# Then locally:
cd /path/to/your/calendar++/project
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/den-kim/calendarplusplus.git
git push -u origin main
```

### Create Homebrew Tap Repository

```bash
# Create on GitHub: den-kim/homebrew-tap
# Then locally:
mkdir -p ~/homebrew-tap
cd ~/homebrew-tap
mkdir Casks
git init
```

Create `README.md`:
```markdown
# den-kim's Homebrew Tap

## Installation

\`\`\`bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
\`\`\`

## Available Casks

- **calendar-plus-plus** - Smart calendar menu bar app with focus modes
```

Copy the cask formula:
```bash
# Copy calendar-plus-plus.rb to Casks/
cp /path/to/calendar-plus-plus.rb Casks/

# Commit and push
git add .
git commit -m "Add calendar++ cask"
git branch -M main
git remote add origin https://github.com/den-kim/homebrew-tap.git
git push -u origin main
```

## 🔧 Step 2: Xcode Configuration

### Update Project Settings

1. **Open your Xcode project**

2. **Select your target** → General tab:
   - Bundle Identifier: `com.den-kim.calendarplusplus`
   - Version: `1.0.0`
   - Build: `1`
   - Minimum macOS: `13.0` or higher

3. **Add Info.plist:**
   - Drag `Info.plist` from Finder into your Xcode project
   - Target → Build Settings → Search "Info.plist"
   - Set "Info.plist File" to: `$(SRCROOT)/Info.plist`

4. **Signing & Capabilities:**
   - Select your development team
   - Enable "Automatically manage signing" (or configure manual signing)
   - Add "App Groups" capability
   - Add app group: `group.com.den-kim.calendarplusplus`

### Verify URL Scheme

The code already uses `calendarplusplus://` - verified in `calendar__App.swift` ✅

## 🔐 Step 3: Code Signing Setup

### Get Developer ID Certificate

1. Go to [developer.apple.com](https://developer.apple.com)
2. Certificates, Identifiers & Profiles → Certificates
3. Click "+" to create new certificate
4. Select "Developer ID Application"
5. Follow prompts, download, and install in Keychain

### Create Export Options

Create `exportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

**Find your Team ID:** Go to developer.apple.com → Membership → Team ID

### Setup Notarization

1. **Generate app-specific password:**
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Sign In → Security → App-Specific Passwords
   - Click "+" and generate password
   - Save it securely!

2. **Store credentials in Keychain:**
```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

## 🏗️ Step 4: Build Script

Make the build script executable:
```bash
chmod +x build-release.sh
```

The `build-release.sh` script will:
1. Clean build folder
2. Archive the app
3. Export with Developer ID signing
4. Create ZIP file
5. Sign and notarize
6. Staple notarization ticket

## 🚀 Step 5: First Release

### Build and Test

```bash
# Build version 1.0.0
./build-release.sh 1.0.0

# Test the app
open build/export/calendar++.app

# Test all features:
# - Calendar permissions
# - Create events
# - URL schemes
# - Focus modes
```

### Test URL Scheme

```bash
# Show today
open "calendarplusplus://show-date?timestamp=$(date +%s)"

# Create test event
open "calendarplusplus://new-event?title=Test&start=$(date +%s)&end=$(($(date +%s) + 3600))"
```

### Create GitHub Release

1. **Calculate SHA256:**
```bash
shasum -a 256 build/calendar++-v1.0.0.zip
```

2. **Create and push tag:**
```bash
cd /path/to/calendarplusplus
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

3. **Create Release on GitHub:**
   - Go to your repo → Releases → New Release
   - Choose tag: `v1.0.0`
   - Release title: `calendar++ v1.0.0`
   - Description:
     ```markdown
     ## Features
     - 📅 Menu bar calendar with event management
     - 🎯 Focus modes (Work/Personal/All)
     - ⏱️ Deep work timer integration
     - 🔗 URL scheme automation
     - ✅ Reminders integration
     
     ## Installation
     \`\`\`bash
     brew tap den-kim/tap
     brew install --cask calendar-plus-plus
     \`\`\`
     
     ## Requirements
     - macOS 13.0 or later
     - Calendar permissions
     ```
   - Upload `calendar++-v1.0.0.zip`
   - Publish release

### Update Homebrew Formula

```bash
# Update Casks/calendar-plus-plus.rb with:
# 1. version "1.0.0"
# 2. sha256 from the calculated hash above

cd ~/homebrew-tap
nano Casks/calendar-plus-plus.rb
# Update version and sha256

git add Casks/calendar-plus-plus.rb
git commit -m "Release calendar++ v1.0.0"
git push origin main
```

## 📥 Step 6: Test Installation

```bash
# Tap your repository
brew tap den-kim/tap

# Install the cask
brew install --cask calendar-plus-plus

# Verify installation
ls -la /Applications/calendar++.app

# Launch
open -a "calendar++"
```

## ✅ Step 7: Validation

```bash
# Run Homebrew audit
brew audit --cask --online calendar-plus-plus

# Style check
brew style --fix calendar-plus-plus

# Test upgrade path
brew upgrade --cask calendar-plus-plus
```

## 🔄 Future Updates

### Release Process for v1.0.1, v1.0.2, etc.

1. **Update version in Xcode** (General tab)

2. **Build new release:**
```bash
./build-release.sh 1.0.1
```

3. **Calculate new SHA256:**
```bash
shasum -a 256 build/calendar++-v1.0.1.zip
```

4. **Create new tag and GitHub release:**
```bash
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1
# Then create GitHub Release with the ZIP
```

5. **Update Homebrew formula:**
```bash
cd ~/homebrew-tap
nano Casks/calendar-plus-plus.rb
# Update version and sha256
git add Casks/calendar-plus-plus.rb
git commit -m "Update calendar++ to v1.0.1"
git push origin main
```

6. **Users can update with:**
```bash
brew update
brew upgrade --cask calendar-plus-plus
```

## 📊 Monitoring

### Check tap stats
```bash
brew tap-info den-kim/tap
```

### View formula info
```bash
brew info --cask calendar-plus-plus
```

## 🐛 Troubleshooting

### Common Issues

**"App is damaged" error:**
- App wasn't properly notarized
- Run notarization again and staple the ticket

**URL scheme not working:**
- Check Info.plist is properly configured
- Verify `calendarplusplus://` scheme is registered
- Test with: `open "calendarplusplus://show-date?timestamp=$(date +%s)"`

**Permissions not requested:**
- Verify `NSCalendarsUsageDescription` and `NSRemindersUsageDescription` are in Info.plist
- Delete app and reinstall to trigger fresh permission requests

**Cask audit failures:**
```bash
# Fix common issues
brew style --fix calendar-plus-plus

# Check for specific errors
brew audit --cask --strict --online calendar-plus-plus
```

## 🎉 Success!

Once complete, users can install your app with:

```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
```

Share this with users:
- Add installation instructions to your README
- Tweet/post about your release
- Submit to Product Hunt (optional)

## 📚 Additional Resources

- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Homebrew Formula Writing](https://docs.brew.sh/Formula-Cookbook)

## 🔗 Quick Links

- Main repo: `https://github.com/den-kim/calendarplusplus`
- Homebrew tap: `https://github.com/den-kim/homebrew-tap`
- Releases: `https://github.com/den-kim/calendarplusplus/releases`
