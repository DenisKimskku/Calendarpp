# Setup Complete! 🎉

All files have been configured for calendar++ distribution via Homebrew.

## ✅ What's Been Done

### 1. Bundle Identifiers Updated
- **Bundle ID:** `com.den-kim.calendarplusplus`
- **App Group:** `group.com.den-kim.calendarplusplus`
- **URL Scheme:** `calendarplusplus://`

### 2. Files Created

#### Configuration Files
- ✅ `Info.plist` - App configuration with proper IDs
- ✅ `.gitignore` - Ignores build artifacts, checklists, personal info

#### Homebrew Distribution
- ✅ `calendar-plus-plus.rb` - Homebrew cask formula
- ✅ `HOMEBREW_DISTRIBUTION_GUIDE.md` - Complete distribution guide
- ✅ `HOMEBREW_TAP_README.md` - README for tap repository

#### Documentation
- ✅ `README.md` - Main repository README with features & usage
- ✅ `INFO_PLIST_CONFIGURATION.md` - Updated with correct IDs
- ✅ `GITHUB_SECRETS_SETUP.md` - GitHub Actions secrets guide

#### Automation
- ✅ `.github-workflows-release.yml` - GitHub Actions workflow

### 3. Updated Documentation
- All references changed from `calenderplus` to `calendarplusplus`
- All bundle IDs changed to `com.den-kim.calendarplusplus`
- URL schemes updated throughout

## 🚀 Next Steps

### Step 1: Update Xcode Project

1. Open your Xcode project
2. Select your target → General:
   - Bundle Identifier: `com.den-kim.calendarplusplus`
   - Version: `1.0.0`
3. Drag `Info.plist` into your project
4. Build Settings → Info.plist File: `$(SRCROOT)/Info.plist`
5. Signing & Capabilities:
   - Add App Groups: `group.com.den-kim.calendarplusplus`

### Step 2: Create GitHub Repositories

```bash
# Main repository
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/den-kim/calendarplusplus.git
git push -u origin main

# Homebrew tap repository
mkdir -p ~/homebrew-tap/Casks
cp calendar-plus-plus.rb ~/homebrew-tap/Casks/
cp HOMEBREW_TAP_README.md ~/homebrew-tap/README.md
cd ~/homebrew-tap
git init
git add .
git commit -m "Add calendar++ cask"
git branch -M main
git remote add origin https://github.com/den-kim/homebrew-tap.git
git push -u origin main
```

### Step 3: Setup Code Signing

1. Get Developer ID certificate from developer.apple.com
2. Install certificate in Keychain
3. Update `exportOptions.plist` with your Team ID
4. Setup notarization credentials (see GITHUB_SECRETS_SETUP.md)

### Step 4: Build First Release

```bash
# Make build script executable
chmod +x build-release.sh

# Build version 1.0.0
./build-release.sh 1.0.0

# Test the app
open build/export/calendar++.app

# Test URL schemes
open "calendarplusplus://show-date?timestamp=$(date +%s)"
```

### Step 5: Create GitHub Release

```bash
# Calculate SHA256
shasum -a 256 build/calendar++-v1.0.0.zip

# Create and push tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Create release on GitHub
# Upload calendar++-v1.0.0.zip
# Note the SHA256 hash
```

### Step 6: Update Homebrew Formula

```bash
cd ~/homebrew-tap
nano Casks/calendar-plus-plus.rb

# Update:
# version "1.0.0"
# sha256 "YOUR_CALCULATED_SHA256"

git add Casks/calendar-plus-plus.rb
git commit -m "Release calendar++ v1.0.0"
git push origin main
```

### Step 7: Test Installation

```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
open -a "calendar++"
```

## 📋 Important Files Reference

### For Xcode Configuration
- `Info.plist` - Add to your Xcode project
- `INFO_PLIST_CONFIGURATION.md` - Configuration reference

### For Distribution
- `calendar-plus-plus.rb` - Homebrew cask formula
- `build-release.sh` - Build and sign script
- `HOMEBREW_DISTRIBUTION_GUIDE.md` - Complete guide

### For GitHub
- `README.md` - Main repository documentation
- `.gitignore` - Git ignore rules
- `.github-workflows-release.yml` - Automated releases (optional)
- `GITHUB_SECRETS_SETUP.md` - Setup GitHub Actions

### For Homebrew Tap
- `HOMEBREW_TAP_README.md` - Use as README in tap repo
- `calendar-plus-plus.rb` - Goes in `Casks/` directory

## 🎯 Quick Commands

### Build and Release
```bash
# Build
./build-release.sh 1.0.0

# Tag and push
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Calculate SHA256
shasum -a 256 build/calendar++-v1.0.0.zip
```

### Test URL Schemes
```bash
# Show today
open "calendarplusplus://show-date?timestamp=$(date +%s)"

# Create event
open "calendarplusplus://new-event?title=Test&start=$(date +%s)&end=$(($(date +%s) + 3600))"

# Set focus
open "calendarplusplus://set-focus?set=work"
```

### Homebrew Commands
```bash
# Install
brew tap den-kim/tap
brew install --cask calendar-plus-plus

# Update
brew update
brew upgrade --cask calendar-plus-plus

# Uninstall
brew uninstall --cask calendar-plus-plus

# Audit
brew audit --cask --online calendar-plus-plus
```

## 📚 Documentation Files

All guides are ready:
1. **HOMEBREW_DISTRIBUTION_GUIDE.md** - Step-by-step Homebrew setup
2. **INFO_PLIST_CONFIGURATION.md** - Xcode configuration
3. **GITHUB_SECRETS_SETUP.md** - GitHub Actions setup
4. **PRE_RELEASE_CHECKLIST.md** - Release checklist (your existing file)
5. **README.md** - User-facing documentation

## 🔒 .gitignore Coverage

Your `.gitignore` now excludes:
- ✅ Build artifacts (build/, *.zip, *.dmg)
- ✅ Xcode user data (*.xcuserdata, DerivedData/)
- ✅ Personal checklists (*CHECKLIST.md, CHANGES_SUMMARY.md)
- ✅ Credentials and secrets (*.credentials, .env)
- ✅ Editor files (.vscode/, .idea/)
- ✅ macOS system files (.DS_Store)
- ✅ Export options (may contain Team IDs)

## ✨ What Makes This Special

Your app now has:
- 🎯 Professional bundle IDs following Apple conventions
- 🍺 Easy installation via Homebrew
- 🔗 Powerful URL scheme automation
- 📱 Shortcuts app integration
- 🔒 Proper code signing and notarization
- 📦 Automated releases (optional)
- 🛡️ Privacy-focused (no data leaves device)

## 🎉 Ready to Ship!

Follow the numbered steps above, and you'll have:
1. A signed, notarized macOS app
2. A GitHub release
3. A Homebrew tap
4. Users installing with: `brew install --cask calendar-plus-plus`

## 💡 Pro Tips

- Test on a clean Mac (or new user account) before public release
- Keep your Team ID and credentials secure
- Update version numbers in both Xcode and git tags
- Document changes in release notes
- Respond to GitHub Issues promptly

## 🆘 Need Help?

Refer to these guides:
- First time setup → **HOMEBREW_DISTRIBUTION_GUIDE.md**
- Xcode issues → **INFO_PLIST_CONFIGURATION.md**
- GitHub Actions → **GITHUB_SECRETS_SETUP.md**
- Pre-release → **PRE_RELEASE_CHECKLIST.md**

## 🎊 Success!

Everything is configured! Your calendar++ app is ready for distribution.

**Installation command users will use:**
```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
```

Good luck with your release! 🚀
