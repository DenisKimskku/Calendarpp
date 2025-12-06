# Homebrew Distribution Guide for calendar++

This guide will help you distribute calendar++ through Homebrew.

## Option 1: Homebrew Cask (Recommended for GUI Apps)

Homebrew Cask is the standard way to distribute macOS GUI applications.

### Step 1: Prepare Your App for Distribution

1. **Archive your app in Xcode:**
   - Product → Archive
   - Export the app (Developer ID signed recommended)
   - Create a `.zip` or `.dmg` of your app

2. **Host the archive:**
   - Upload to GitHub Releases (recommended)
   - Or any stable URL (your own server, S3, etc.)

3. **Get the SHA256 checksum:**
   ```bash
   shasum -a 256 calendar++.zip
   ```

### Step 2: Create a Homebrew Cask Formula

Create a file named `calendar-plus-plus.rb` (or `calendarplusplus.rb`):

```ruby
cask "calendar-plus-plus" do
  version "1.0.0"
  sha256 "YOUR_SHA256_HERE"

  url "https://github.com/den-kim/calendarplusplus/releases/download/v#{version}/calendar++.zip"
  name "calendar++"
  desc "Smart calendar and event management for macOS menu bar"
  homepage "https://github.com/den-kim/calendarplusplus"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "calendar++.app"

  zap trash: [
    "~/Library/Application Support/com.den-kim.calendarplusplus",
    "~/Library/Caches/com.den-kim.calendarplusplus",
    "~/Library/Preferences/com.den-kim.calendarplusplus.plist",
    "~/Library/Saved Application State/com.den-kim.calendarplusplus.savedState",
  ]
end
```

### Step 3: Submit to Homebrew Cask

You have two options:

#### Option A: Official Homebrew Cask Repository (Recommended)

1. **Fork the homebrew-cask repository:**
   ```bash
   # Fork on GitHub first, then:
   git clone https://github.com/YOUR-USERNAME/homebrew-cask
   cd homebrew-cask
   ```

2. **Create a branch for your cask:**
   ```bash
   git checkout -b calendar-plus-plus
   ```

3. **Add your cask:**
   ```bash
   cp calendar-plus-plus.rb Casks/c/calendar-plus-plus.rb
   ```

4. **Test your cask:**
   ```bash
   brew install --cask ./Casks/c/calendar-plus-plus.rb
   brew audit --cask --online calendar-plus-plus
   ```

5. **Submit a pull request:**
   ```bash
   git add Casks/c/calendar-plus-plus.rb
   git commit -m "Add calendar-plus-plus cask"
   git push origin calendar-plus-plus
   ```
   
   Then create a PR on GitHub.

#### Option B: Your Own Homebrew Tap (Faster, Full Control)

This allows users to install via your own tap without approval delays.

1. **Create a repository named `homebrew-tap`:**
   ```bash
   # On GitHub, create: den-kim/homebrew-tap
   git clone https://github.com/den-kim/homebrew-tap
   cd homebrew-tap
   ```

2. **Create the Casks directory:**
   ```bash
   mkdir -p Casks
   ```

3. **Add your cask formula:**
   ```bash
   # Create Casks/calendar-plus-plus.rb with the content above
   ```

4. **Commit and push:**
   ```bash
   git add .
   git commit -m "Add calendar++ cask"
   git push origin main
   ```

5. **Users can now install with:**
   ```bash
   brew tap den-kim/tap
   brew install --cask calendar-plus-plus
   ```

## Option 2: Homebrew Formula (CLI-focused apps)

If you want to distribute a CLI version or need more control:

```ruby
class CalendarPlusPlus < Formula
  desc "Smart calendar and event management for macOS"
  homepage "https://github.com/den-kim/calendarplusplus"
  url "https://github.com/den-kim/calendarplusplus/archive/v1.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    # If you want to build from source
    system "xcodebuild", "-scheme", "calendar++",
           "-configuration", "Release",
           "-derivedDataPath", "build",
           "SYMROOT=build"
    
    app = "build/Release/calendar++.app"
    prefix.install app
    bin.install_symlink "#{prefix}/calendar++.app/Contents/MacOS/calendar++" => "calendarplusplus"
  end

  def caveats
    <<~EOS
      calendar++ has been installed as a menu bar application.
      
      To launch calendar++:
        open -a calendar++
      
      Or use the CLI:
        calendarplusplus://show-date?timestamp=$(date +%s)
    EOS
  end

  test do
    assert_predicate prefix/"calendar++.app/Contents/MacOS/calendar++", :exist?
  end
end
```

## Recommended Workflow

### Initial Setup

1. **Create GitHub repository** for your app
2. **Set up GitHub Actions** for automated builds
3. **Create releases** with semantic versioning (v1.0.0, v1.1.0, etc.)

### For Each Release

1. **Update version** in Xcode
2. **Create a git tag:**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

3. **Build and archive:**
   ```bash
   xcodebuild archive \
     -scheme "calendar++" \
     -archivePath "build/calendar++.xcarchive" \
     -configuration Release
   
   xcodebuild -exportArchive \
     -archivePath "build/calendar++.xcarchive" \
     -exportPath "build" \
     -exportOptionsPlist exportOptions.plist
   ```

4. **Create .zip:**
   ```bash
   cd build
   ditto -c -k --sequesterRsrc --keepParent "calendar++.app" "calendar++-v1.0.0.zip"
   ```

5. **Create GitHub Release:**
   - Go to GitHub → Releases → New Release
   - Upload the .zip file
   - Generate SHA256 and update formula

6. **Update Homebrew formula:**
   ```bash
   # Update version and sha256 in your formula
   git commit -am "Update to v1.0.0"
   git push
   ```

## Automated Release with GitHub Actions

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
    
    - name: Build
      run: |
        xcodebuild archive \
          -scheme "calendar++" \
          -archivePath "build/calendar++.xcarchive" \
          -configuration Release
        
        xcodebuild -exportArchive \
          -archivePath "build/calendar++.xcarchive" \
          -exportPath "build" \
          -exportOptionsPlist exportOptions.plist
    
    - name: Create ZIP
      run: |
        cd build
        ditto -c -k --sequesterRsrc --keepParent "calendar++.app" "calendar++-${{ github.ref_name }}.zip"
    
    - name: Calculate SHA256
      id: sha
      run: |
        echo "sha256=$(shasum -a 256 build/calendar++-${{ github.ref_name }}.zip | awk '{print $1}')" >> $GITHUB_OUTPUT
    
    - name: Create Release
      uses: softprops/action-gh-release@v1
      with:
        files: build/calendar++-${{ github.ref_name }}.zip
        body: |
          SHA256: ${{ steps.sha.outputs.sha256 }}
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Installation Commands for Users

Once published, users can install calendar++ with:

### From Official Homebrew:
```bash
brew install --cask calendar-plus-plus
```

### From Your Tap:
```bash
brew tap den-kim/tap
brew install --cask calendar-plus-plus
```

### Update:
```bash
brew upgrade --cask calendar-plus-plus
```

### Uninstall:
```bash
brew uninstall --cask calendar-plus-plus
```

## Best Practices

1. **Code Signing:** Sign your app with a Developer ID certificate
2. **Notarization:** Notarize your app with Apple for Gatekeeper
3. **Version Consistency:** Keep versions consistent across:
   - Xcode project
   - Git tags
   - GitHub releases
   - Homebrew formula
4. **Changelog:** Maintain a CHANGELOG.md file
5. **Documentation:** Keep README.md updated with features

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Creating Homebrew Taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
