# Pre-Release Checklist for calendar++

Use this checklist before publishing to Homebrew.

## ✅ Xcode Configuration

- [ ] Update project bundle identifier to: `com.den-kim.calendarplusplus`
- [ ] Add `Info.plist` to project (drag from Finder into Xcode)
- [ ] Set Info.plist in Build Settings:
  - Target → Build Settings → Search "Info.plist"
  - Set "Info.plist File" to: `$(SRCROOT)/Info.plist`
- [ ] Configure Signing & Capabilities:
  - [ ] Select your development team
  - [ ] Enable "Automatically manage signing" OR configure manual signing
  - [ ] Add App Groups capability
  - [ ] Add app group: `group.com.den-kim.calendarplusplus`
- [ ] Update deployment target to macOS 13.0 or higher
- [ ] Verify scheme is set to "Release" for distribution builds

## ✅ Code Updates

- [ ] Verify URL scheme handler uses `calendarplusplus` (already done ✅)
- [ ] Update any hardcoded bundle IDs or app group names
- [ ] Remove debug logging for production
- [ ] Test calendar and reminder permissions
- [ ] Verify all EventKit operations handle errors

## ✅ Code Signing Setup

### Developer ID Signing (Required for Homebrew)

- [ ] Have Apple Developer account ($99/year)
- [ ] Create Developer ID Application certificate:
  1. Go to developer.apple.com → Certificates
  2. Create → Developer ID Application
  3. Download and install in Keychain
- [ ] Update `exportOptions.plist`:
  - [ ] Set your Team ID (find in developer.apple.com)
  - [ ] Verify method is "developer-id"

### Notarization Setup (Required for distribution)

- [ ] Generate app-specific password:
  1. Go to appleid.apple.com
  2. Sign In → Security → App-Specific Passwords
  3. Generate password → Save securely
- [ ] Store notarization credentials:
  ```bash
  xcrun notarytool store-credentials "AC_PASSWORD" \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "app-specific-password"
  ```

## ✅ GitHub Setup

### Main Repository

- [ ] Create repository: `den-kim/calendarplusplus`
- [ ] Push all code to main branch
- [ ] Add README.md (already created ✅)
- [ ] Add LICENSE file (choose: MIT, Apache, GPL, etc.)
- [ ] Add .gitignore for Xcode:
  ```
  # Xcode
  build/
  *.xcarchive
  *.xcuserdata
  *.xcuserdatad
  DerivedData/
  .DS_Store
  
  # Release artifacts
  *.zip
  *.dmg
  ```

### Homebrew Tap Repository

- [ ] Create repository: `den-kim/homebrew-tap`
- [ ] Create directory structure:
  ```bash
  mkdir -p Casks
  ```
- [ ] Add `calendar-plus-plus.rb` to `Casks/` (already created ✅)
- [ ] Add README.md to tap:
  ```markdown
  # den-kim's Homebrew Tap
  
  ## Install calendar++
  
  \`\`\`bash
  brew tap den-kim/tap
  brew install --cask calendar-plus-plus
  \`\`\`
  ```

### GitHub Actions (Optional but Recommended)

- [ ] Create `.github/workflows/` directory
- [ ] Add `release.yml` from `.github-workflows-release.yml` (already created ✅)
- [ ] Test workflow with a test tag

## ✅ First Build & Test

- [ ] Build locally:
  ```bash
  chmod +x build-release.sh
  ./build-release.sh 1.0.0
  ```
- [ ] Test the built app:
  ```bash
  open build/export/calendar++.app
  ```
- [ ] Verify menu bar icon appears
- [ ] Test calendar access permission flow
- [ ] Create a test event
- [ ] Test URL schemes:
  ```bash
  open "calendarplusplus://show-date?timestamp=$(date +%s)"
  ```
- [ ] Verify app launches on login (if enabled)
- [ ] Test on a clean Mac (or fresh user account)

## ✅ Code Signing & Notarization

- [ ] Sign the app:
  ```bash
  codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: YOUR NAME (TEAM_ID)" \
    build/export/calendar++.app
  ```
- [ ] Verify signature:
  ```bash
  codesign --verify --verbose=4 build/export/calendar++.app
  spctl --assess --verbose=4 build/export/calendar++.app
  ```
- [ ] Create ZIP for notarization:
  ```bash
  ditto -c -k --sequesterRsrc --keepParent \
    build/export/calendar++.app \
    build/calendar++-v1.0.0.zip
  ```
- [ ] Submit for notarization:
  ```bash
  xcrun notarytool submit build/calendar++-v1.0.0.zip \
    --keychain-profile "AC_PASSWORD" \
    --wait
  ```
- [ ] Verify notarization:
  ```bash
  xcrun stapler staple build/export/calendar++.app
  spctl --assess -vv --type install build/export/calendar++.app
  ```

## ✅ Release Preparation

- [ ] Create and push git tag:
  ```bash
  git tag -a v1.0.0 -m "Release version 1.0.0"
  git push origin v1.0.0
  ```
- [ ] Calculate SHA256:
  ```bash
  shasum -a 256 build/calendar++-v1.0.0.zip
  ```
- [ ] Create GitHub Release:
  - [ ] Go to Releases → New Release
  - [ ] Choose tag: v1.0.0
  - [ ] Add release title: "calendar++ v1.0.0"
  - [ ] Write release notes (features, fixes, etc.)
  - [ ] Upload `calendar++-v1.0.0.zip`
  - [ ] Publish release

## ✅ Homebrew Formula Update

- [ ] Update `calendar-plus-plus.rb` in homebrew-tap:
  - [ ] Set `version "1.0.0"`
  - [ ] Update `sha256` with calculated hash
  - [ ] Verify download URL is correct
- [ ] Commit and push to homebrew-tap:
  ```bash
  cd homebrew-tap
  git add Casks/calendar-plus-plus.rb
  git commit -m "Add calendar++ v1.0.0"
  git push origin main
  ```

## ✅ Installation Testing

- [ ] Test tap installation:
  ```bash
  brew tap den-kim/tap
  ```
- [ ] Test cask installation:
  ```bash
  brew install --cask calendar-plus-plus
  ```
- [ ] Verify app installed correctly:
  ```bash
  ls -la /Applications/calendar++.app
  ```
- [ ] Launch and test:
  ```bash
  open -a calendar++
  ```
- [ ] Test all features:
  - [ ] Calendar access granted
  - [ ] Events display correctly
  - [ ] Can create events
  - [ ] URL schemes work
  - [ ] Focus modes work
  - [ ] Preferences save correctly

## ✅ Audit & Validation

- [ ] Run Homebrew audit:
  ```bash
  brew audit --cask --online calendar-plus-plus
  ```
- [ ] Run style check:
  ```bash
  brew style calendar-plus-plus
  ```
- [ ] Fix any warnings or errors
- [ ] Test upgrade path:
  ```bash
  brew upgrade --cask calendar-plus-plus
  ```

## ✅ Documentation

- [ ] Update README.md with:
  - [ ] Installation instructions
  - [ ] Usage examples
  - [ ] URL scheme documentation
  - [ ] Contributing guidelines
  - [ ] License information
- [ ] Add screenshots or GIFs (optional but recommended)
- [ ] Update CHANGELOG.md
- [ ] Verify all documentation links work

## ✅ Post-Release

- [ ] Announce release:
  - [ ] GitHub Discussions
  - [ ] Social media (if applicable)
  - [ ] Product Hunt (optional)
- [ ] Monitor for issues:
  - [ ] GitHub Issues
  - [ ] User feedback
- [ ] Plan next release
- [ ] Update roadmap in README.md

## 📋 Quick Reference

### Files to Update Each Release

1. **Xcode Project** - Version and build number
2. **Git Tag** - Create new version tag
3. **GitHub Release** - Upload new ZIP
4. **Homebrew Formula** - Update version and SHA256
5. **CHANGELOG.md** - Document changes

### Commands You'll Use Often

```bash
# Build release
./build-release.sh 1.0.0

# Create tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Calculate SHA256
shasum -a 256 build/calendar++-v1.0.0.zip

# Test installation
brew install --cask calendar-plus-plus

# Test URL scheme
open "calendarplusplus://show-date?timestamp=$(date +%s)"
```

## 🎯 Success Criteria

Your release is ready when:

✅ App builds without errors  
✅ Code signed with Developer ID  
✅ Notarized by Apple  
✅ GitHub Release published  
✅ Homebrew formula updated  
✅ Installation via Homebrew works  
✅ App launches and runs correctly  
✅ No Gatekeeper warnings  
✅ URL schemes functional  
✅ Permissions requested properly  

## 🚀 First Release Celebration

Once you've completed all steps above, your app is live! Users can install it with:

```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
```

Share your accomplishment! 🎉
