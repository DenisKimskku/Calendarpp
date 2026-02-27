# Homebrew Distribution Setup Guide

This guide will help you make calendar++ installable via Homebrew.

## Overview

You now have everything set up to distribute calendar++ via Homebrew. The setup includes:
- ✅ Homebrew cask formula configured
- ✅ Build script ready
- ✅ Tap repository structure created

## One-Time Setup

### Step 1: Create Homebrew Tap Repository on GitHub

1. Go to GitHub and create a new repository named: **`homebrew-tap`**
   - Repository name must be exactly: `homebrew-tap`
   - URL will be: `https://github.com/DenisKimskku/homebrew-tap`
   - Make it public
   - Initialize with a README (optional, we'll replace it)

2. Clone the repository locally:
   ```bash
   cd ~/Desktop  # or wherever you want
   git clone https://github.com/DenisKimskku/homebrew-tap.git
   cd homebrew-tap
   ```

3. Copy the tap files from your project:
   ```bash
   cp -r /Users/den/Desktop/calendar++/homebrew-tap/* .
   ```

4. Commit and push:
   ```bash
   git add .
   git commit -m "Initial homebrew tap setup"
   git push origin main
   ```

### Step 2: Set Up Website for Hosting Releases

You need to host the calendar++ ZIP files at `https://deniskim1.com/releases/`. Options:

**Option A: Static Hosting (Recommended)**
- Create a `/releases` directory on your website
- Upload ZIP files here
- Ensure files are publicly accessible

**Option B: Use GitHub Releases Instead**
If you prefer GitHub releases, update the cask formula:
```ruby
url "https://github.com/DenisKimskku/Calendarpp/releases/download/v#{version}/calendar++-v#{version}.zip"
```

## Release Process

Every time you want to release a new version, follow these steps:

### Step 1: Build the Release

```bash
cd /Users/den/Desktop/calendar++
chmod +x calendar++/build-release.sh
./calendar++/build-release.sh 1.0.0  # Replace with your version
```

This will:
- Build the optimized app
- Create a ZIP file in `build/`
- Generate SHA256 checksum
- Display next steps

### Step 2: Upload the ZIP File

Upload the ZIP file from `build/calendar++-v1.0.0.zip` to:
```
https://deniskim1.com/releases/calendar++-v1.0.0.zip
```

Verify it's accessible:
```bash
curl -I https://deniskim1.com/releases/calendar++-v1.0.0.zip
# Should return 200 OK
```

### Step 3: Update Homebrew Formula

1. Navigate to your homebrew-tap repository:
   ```bash
   cd ~/Desktop/homebrew-tap  # or wherever you cloned it
   ```

2. Edit `Casks/calendar-plus-plus.rb`:
   ```bash
   nano Casks/calendar-plus-plus.rb
   ```

3. Update the version and SHA256 (values from build script output):
   ```ruby
   version "1.0.0"  # Update this
   sha256 "abc123..."  # Update this with the SHA256 from build output
   ```

4. Commit and push:
   ```bash
   git add Casks/calendar-plus-plus.rb
   git commit -m "Update calendar++ to v1.0.0"
   git push origin main
   ```

### Step 4: Test Installation

```bash
# Remove old tap if exists
brew untap DenisKimskku/tap 2>/dev/null || true

# Add tap
brew tap DenisKimskku/tap

# Install
brew install --cask calendar-plus-plus

# Test the app
open -a calendar++
```

Test URL scheme:
```bash
open "calendarplusplus://show-date?timestamp=$(date +%s)"
```

## User Installation Instructions

Share these instructions with your users:

```bash
# Install calendar++
brew tap DenisKimskku/tap
brew install --cask calendar-plus-plus

# Update to latest version
brew upgrade --cask calendar-plus-plus

# Uninstall
brew uninstall --cask calendar-plus-plus
```

## Troubleshooting

### "App is damaged" or "Can't verify developer"

If you do not have paid Apple Developer membership, you can still distribute
via your own tap, but users may need to manually clear quarantine:

```bash
xattr -dr com.apple.quarantine "/Applications/calendar++.app"
open -a "calendar++"
```

You can also right-click the app in Applications and choose **Open** once.

If you do have paid membership, use Developer ID signing + notarization for
best user experience.

### SHA256 Mismatch Error

Regenerate the checksum:
```bash
shasum -a 256 build/calendar++-v1.0.0.zip
```

Update the formula with the new hash.

### Formula Syntax Errors

Validate your formula:
```bash
brew audit --cask --online DenisKimskku/tap/calendar-plus-plus
brew style DenisKimskku/tap/calendar-plus-plus
```

### Can't Download ZIP

Verify the URL is accessible:
```bash
curl -I https://deniskim1.com/releases/calendar++-v1.0.0.zip
```

Should return `200 OK`. If not, check:
- File is uploaded correctly
- Path is correct
- No authentication required
- HTTPS is working

## Quick Reference

### File Locations

- **Cask Formula**: `/Users/den/Desktop/calendar++/homebrew-tap/Casks/calendar-plus-plus.rb`
- **Build Script**: `/Users/den/Desktop/calendar++/calendar++/build-release.sh`
- **Tap Repo**: `https://github.com/DenisKimskku/homebrew-tap`
- **Website**: `https://deniskim1.com`

### Bundle Identifier

```
den-kim.calendar--
```

### URL Scheme

```
calendarplusplus://
```

## Next Steps

1. ✅ **Create homebrew-tap repository** on GitHub
2. ✅ **Push tap files** to the repository
3. 🎯 **Build your first release** using the build script
4. 🎯 **Upload ZIP to your website**
5. 🎯 **Update formula** with version and SHA256
6. 🎯 **Test installation** locally
7. 🎯 **Share with users!**

## Support

For Homebrew tap issues:
- Check formula syntax with `brew audit`
- Review Homebrew documentation: https://docs.brew.sh/Cask-Cookbook

For app-specific issues:
- GitHub: https://github.com/DenisKimskku/Calendarpp
- Website: https://deniskim1.com
