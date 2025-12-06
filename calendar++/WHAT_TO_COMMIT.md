# 📋 What to Commit vs Ignore

This guide explains which files should be committed to your repository and which are for personal use only.

## ✅ Files to COMMIT (Public Repository)

These files should be committed to `github.com/den-kim/calendarplusplus`:

### Essential Files
- ✅ **README.md** - Users need installation instructions
- ✅ **LICENSE** - Required for open source
- ✅ **CONTRIBUTING.md** - Helps contributors
- ✅ **CHANGELOG.md** - Version history
- ✅ **.gitignore** - Git configuration
- ✅ **Info.plist** - App configuration
- ✅ **build-release.sh** - Build script

### Source Code
- ✅ All `.swift` files
- ✅ Xcode project files (`.xcodeproj`)
- ✅ Assets and resources

### Optional (If Using GitHub Features)
You can move these to `.github/` directory if you want to use them:
- ⚠️ **workflows/release.yml** (from `.github-workflows-release.yml`)
- ⚠️ **PULL_REQUEST_TEMPLATE.md** (from `.github-PULL_REQUEST_TEMPLATE.md`)
- ⚠️ **ISSUE_TEMPLATE/bug_report.md** (from `.github-ISSUE_TEMPLATE-bug_report.md`)
- ⚠️ **ISSUE_TEMPLATE/feature_request.md** (from `.github-ISSUE_TEMPLATE-feature_request.md`)

## 🚫 Files to IGNORE (Already in .gitignore)

These files are **already ignored** and won't be committed:

### Setup Guides (For Your Reference Only)
- 🚫 **SETUP_COMPLETE.md** - Your personal setup guide
- 🚫 **FILES_CREATED.md** - Summary of generated files
- 🚫 **QUICK_REFERENCE.md** - Your command reference
- 🚫 **GITHUB_SECRETS_SETUP.md** - Contains security info
- 🚫 **HOMEBREW_DISTRIBUTION_GUIDE.md** - Your distribution guide
- 🚫 **INFO_PLIST_CONFIGURATION.md** - Configuration reference
- 🚫 **HOMEBREW_TAP_README.md** - Goes in tap repo, not main repo

### Homebrew Formula (Goes in Separate Repo)
- 🚫 **calendar-plus-plus.rb** - Belongs in `homebrew-tap` repo

### Build Artifacts
- 🚫 **build/** directory
- 🚫 **\*.zip** files
- 🚫 **\*.dmg** files

### Personal Files
- 🚫 Checklists (*CHECKLIST.md)
- 🚫 Notes (notes.md, TODO.md)
- 🚫 Credentials (*.secrets, .env)

### Xcode User Data
- 🚫 DerivedData/
- 🚫 *.xcuserdata

## 📦 Separate Repository: homebrew-tap

Create a separate repo `github.com/den-kim/homebrew-tap` with these files:

```
homebrew-tap/
├── README.md (use HOMEBREW_TAP_README.md content)
└── Casks/
    └── calendar-plus-plus.rb
```

## 🎯 Quick Setup

### For Main Repository

```bash
# Initialize repository
git init
git add .

# These files will be committed:
# - README.md
# - LICENSE
# - CONTRIBUTING.md
# - CHANGELOG.md
# - .gitignore
# - Info.plist
# - build-release.sh
# - All .swift files

# These files will be IGNORED automatically:
# - SETUP_COMPLETE.md
# - FILES_CREATED.md
# - QUICK_REFERENCE.md
# - All personal guides
# - calendar-plus-plus.rb
# - Build artifacts

git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/den-kim/calendarplusplus.git
git push -u origin main
```

### For Homebrew Tap Repository

```bash
# Create tap repository
mkdir ~/homebrew-tap
cd ~/homebrew-tap

# Create structure
mkdir Casks

# Copy files (not from git, manually)
# 1. Copy calendar-plus-plus.rb to Casks/
# 2. Copy HOMEBREW_TAP_README.md content to README.md

# Initialize
git init
git add .
git commit -m "Add calendar++ cask"
git branch -M main
git remote add origin https://github.com/den-kim/homebrew-tap.git
git push -u origin main
```

## 🔧 Using GitHub Templates (Optional)

If you want to use the GitHub templates, create this structure:

```bash
# In your main repository
mkdir -p .github/workflows
mkdir -p .github/ISSUE_TEMPLATE

# Move files
mv .github-workflows-release.yml .github/workflows/release.yml
mv .github-PULL_REQUEST_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE.md
mv .github-ISSUE_TEMPLATE-bug_report.md .github/ISSUE_TEMPLATE/bug_report.md
mv .github-ISSUE_TEMPLATE-feature_request.md .github/ISSUE_TEMPLATE/feature_request.md

# Then commit
git add .github/
git commit -m "Add GitHub templates"
```

## 📝 Summary

### Keep Private (Ignored by .gitignore)
- Personal setup guides
- Security documentation
- Build artifacts
- Personal notes and checklists

### Make Public (Commit to main repo)
- Source code
- README and documentation
- LICENSE and CONTRIBUTING
- Info.plist
- Build scripts

### Separate Repo (homebrew-tap)
- Homebrew formula (calendar-plus-plus.rb)
- Tap README

## ✅ Current Status

Your `.gitignore` is now configured to:
- ✅ Keep your personal guides private
- ✅ Exclude build artifacts
- ✅ Exclude credentials and secrets
- ✅ Exclude Homebrew formula (goes in tap repo)
- ✅ Allow essential files to be committed

You can safely run `git add .` and only the appropriate files will be staged!

## 🎉 Ready to Commit!

```bash
# Check what will be committed
git status

# Add files (personal guides are automatically excluded)
git add .

# Commit
git commit -m "Initial commit: calendar++ menu bar app"

# Push
git push
```

Perfect! Your repository is now properly configured! 🚀
