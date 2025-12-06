# Quick Start: Publishing calendar++ to Homebrew

## Step-by-Step Guide

### 1. Prepare Your Release

```bash
# 1. Update version in Xcode project
# 2. Commit all changes
git add .
git commit -m "Release v1.0.0"

# 3. Create and push tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin main
git push origin v1.0.0
```

### 2. Build Your App

```bash
# Archive the app
xcodebuild archive \
  -scheme "calendar++" \
  -archivePath "build/calendar++.xcarchive" \
  -configuration Release

# Export (if not using automated export)
xcodebuild -exportArchive \
  -archivePath "build/calendar++.xcarchive" \
  -exportPath "build" \
  -exportOptionsPlist exportOptions.plist

# Create ZIP for distribution
cd build
ditto -c -k --sequesterRsrc --keepParent "calendar++.app" "calendar++-v1.0.0.zip"

# Get SHA256 checksum
shasum -a 256 calendar++-v1.0.0.zip
# Copy this hash - you'll need it!
```

### 3. Create GitHub Release

1. Go to: https://github.com/den-kim/calendarplusplus/releases/new
2. Choose tag: v1.0.0
3. Release title: "calendar++ v1.0.0"
4. Upload: `calendar++-v1.0.0.zip`
5. Click "Publish release"

### 4. Set Up Your Homebrew Tap (Easiest Method)

```bash
# Create a new repository on GitHub named: homebrew-tap
# Clone it locally
git clone https://github.com/den-kim/homebrew-tap
cd homebrew-tap

# Create Casks directory
mkdir -p Casks

# Copy the cask formula
cp /path/to/calendar-plus-plus.rb Casks/

# Edit the formula and replace SHA256 with the one from step 2
nano Casks/calendar-plus-plus.rb
# Update: sha256 "YOUR_ACTUAL_SHA256_HERE"

# Commit and push
git add Casks/calendar-plus-plus.rb
git commit -m "Add calendar++ cask"
git push origin main
```

### 5. Test Installation

```bash
# Add your tap
brew tap den-kim/tap

# Install your app
brew install --cask calendar-plus-plus

# Test URL scheme
open "calendarplusplus://show-date?timestamp=$(date +%s)"
```

## Users Will Install Like This:

```bash
# One-time tap setup
brew tap den-kim/tap

# Install calendar++
brew install --cask calendar-plus-plus

# Update (when you release new versions)
brew upgrade --cask calendar-plus-plus

# Uninstall
brew uninstall --cask calendar-plus-plus
```

## For Each New Release:

1. Update version in Xcode
2. Create git tag: `git tag -a v1.1.0 -m "Release v1.1.0"`
3. Push: `git push origin v1.1.0`
4. Build and create ZIP
5. Create GitHub Release with ZIP
6. Update `calendar-plus-plus.rb`:
   - Change `version` line
   - Update `sha256` with new checksum
7. Commit to homebrew-tap repo

## Automation Option

Use the GitHub Actions workflow in `HOMEBREW_DISTRIBUTION.md` to automate:
- Building on tag push
- Creating ZIP
- Publishing GitHub Release
- Calculating SHA256

Then you only need to update the Homebrew formula manually.

## Repository Structure

```
den-kim/
├── calendarplusplus/              # Your main app repo
│   ├── calendar__App.swift
│   ├── Info.plist
│   └── ...
│
└── homebrew-tap/                  # Your Homebrew tap
    └── Casks/
        └── calendar-plus-plus.rb  # Cask formula
```

## Bundle Identifiers to Use

- **Bundle ID:** com.den-kim.calendarplusplus
- **App Group:** group.com.den-kim.calendarplusplus
- **URL Scheme:** calendarplusplus://

## Troubleshooting

### "App is damaged" error
Your app needs to be code signed and notarized. See HOMEBREW_DISTRIBUTION.md for details.

### Formula syntax errors
Test with:
```bash
brew audit --cask --online calendar-plus-plus
brew style calendar-plus-plus
```

### SHA256 mismatch
Regenerate the checksum and update the formula:
```bash
shasum -a 256 calendar++-v1.0.0.zip
```

## Next Steps

1. ✅ Update Info.plist (already done)
2. ✅ Update app to use calendarplusplus:// URL scheme (already done)
3. 🎯 Code sign your app with Developer ID
4. 🎯 Set up notarization
5. 🎯 Create GitHub releases
6. 🎯 Set up homebrew-tap repository
7. 🎯 Submit to official Homebrew (optional)

## Resources

- [Homebrew Cask Docs](https://docs.brew.sh/Cask-Cookbook)
- [Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
