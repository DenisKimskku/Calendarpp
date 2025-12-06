# Contributing to calendar++

Thank you for your interest in contributing to calendar++! This document provides guidelines and instructions for contributing.

## 🎯 Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Fix issues
- ✨ Add new features
- 🧪 Write tests
- 🎨 Improve UI/UX

## 📋 Before You Start

1. Check [existing issues](https://github.com/den-kim/calendarplusplus/issues) to avoid duplicates
2. Read through this contributing guide
3. Review the [README](README.md) to understand the project
4. Make sure you can build and run the project locally

## 🛠️ Development Setup

### Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Git

### Getting Started

```bash
# Fork the repository on GitHub

# Clone your fork
git clone https://github.com/YOUR_USERNAME/calendarplusplus.git
cd calendarplusplus

# Add upstream remote
git remote add upstream https://github.com/den-kim/calendarplusplus.git

# Open in Xcode
open calendar++.xcodeproj
```

### Building

1. Open the project in Xcode
2. Select the calendar++ scheme
3. Press Cmd+B to build
4. Press Cmd+R to run

### Testing

```bash
# Test URL schemes
open "calendarplusplus://show-date?timestamp=$(date +%s)"

# Test event creation
open "calendarplusplus://new-event?title=Test&start=$(date +%s)&end=$(($(date +%s) + 3600))"

# Test focus modes
open "calendarplusplus://set-focus?set=work"
```

## 🔄 Contribution Workflow

### 1. Create an Issue (Optional but Recommended)

Before working on a feature or bug fix, create an issue to discuss:
- What you want to change
- Why it's needed
- How you plan to implement it

### 2. Create a Branch

```bash
# Update your local main branch
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### Branch Naming Convention
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions/changes

### 3. Make Your Changes

- Write clean, readable code
- Follow Swift naming conventions
- Add comments for complex logic
- Update documentation if needed
- Test your changes thoroughly

### 4. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a clear message
git commit -m "Add feature: Description of what you did"
```

### Commit Message Guidelines

Format: `Type: Description`

Types:
- `Add:` - New features
- `Fix:` - Bug fixes
- `Update:` - Updates to existing features
- `Refactor:` - Code refactoring
- `Docs:` - Documentation changes
- `Test:` - Test additions/changes
- `Style:` - Code style changes

Examples:
```
Add: Natural language event parsing
Fix: Calendar permission request crash
Update: Improve deep work timer UI
Refactor: Simplify EventKitManager code
Docs: Update README with new features
```

### 5. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 6. Create a Pull Request

1. Go to your fork on GitHub
2. Click "New Pull Request"
3. Select your branch
4. Fill out the PR template:
   - Clear title
   - Description of changes
   - Related issues
   - Screenshots (if UI changes)
   - Testing done

## ✅ Code Guidelines

### Swift Style

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

**Good:**
```swift
func createEvent(title: String, startDate: Date, endDate: Date) {
    // Implementation
}
```

**Bad:**
```swift
func create_event(t: String, s: Date, e: Date) {
    // Implementation
}
```

### SwiftUI Best Practices

- Use meaningful view names
- Extract complex views into separate files
- Use `@StateObject` for view models
- Use `@EnvironmentObject` for shared state
- Keep views focused and small

### EventKit Integration

- Always check authorization status
- Handle errors gracefully
- Respect user privacy
- Use appropriate event stores
- Clean up resources

### Comments

```swift
// MARK: - Public Methods

/// Creates a new calendar event
/// - Parameters:
///   - title: The event title
///   - startDate: When the event starts
///   - endDate: When the event ends
/// - Returns: The created event or nil if failed
func createEvent(title: String, startDate: Date, endDate: Date) -> EKEvent? {
    // Implementation
}
```

## 🧪 Testing

Before submitting a PR:

- [ ] App builds without errors
- [ ] App runs without crashes
- [ ] Calendar access works
- [ ] URL schemes function correctly
- [ ] Focus modes work as expected
- [ ] No memory leaks
- [ ] UI looks correct on different screen sizes
- [ ] Test on clean macOS install (if possible)

## 📝 Documentation

Update documentation for:
- New features
- Changed behavior
- New URL schemes
- New shortcuts
- Configuration changes

Files to update:
- `README.md` - User-facing documentation
- `CHANGELOG.md` - Record changes
- Code comments - Explain complex logic
- `INFO_PLIST_CONFIGURATION.md` - If config changes

## 🐛 Reporting Bugs

### Before Reporting

1. Search existing issues
2. Update to latest version
3. Try to reproduce consistently

### Bug Report Template

```markdown
**Description**
Clear description of the bug

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- macOS version: 13.5
- calendar++ version: 1.0.0
- Xcode version (if building): 15.0

**Screenshots**
If applicable

**Additional Context**
Any other relevant information
```

## 💡 Feature Requests

### Feature Request Template

```markdown
**Feature Description**
Clear description of the feature

**Use Case**
Why is this feature needed?

**Proposed Implementation**
How could this work?

**Alternatives Considered**
Other ways to solve this

**Additional Context**
Any other relevant information
```

## 🔍 Code Review Process

### What We Look For

- ✅ Code quality and readability
- ✅ Proper error handling
- ✅ Performance considerations
- ✅ User privacy and security
- ✅ Documentation updates
- ✅ Tests (when applicable)
- ✅ Follows project conventions

### Review Timeline

- Initial review: Within 1-3 days
- Follow-up reviews: Within 1-2 days
- Merge: After approval and CI passes

## 🎉 After Your PR is Merged

1. Your contribution will be included in the next release
2. You'll be credited in the release notes
3. Your name will appear in the contributors list

## 📜 Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Respect different viewpoints
- Put community first

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Personal attacks
- Publishing private information
- Spam or off-topic content

## 📞 Questions?

- Open a [Discussion](https://github.com/den-kim/calendarplusplus/discussions)
- Create an [Issue](https://github.com/den-kim/calendarplusplus/issues)
- Email: your@email.com

## 🙏 Thank You!

Every contribution, no matter how small, helps make calendar++ better. Thank you for being part of this project!

---

## Quick Reference

### Common Commands

```bash
# Update from upstream
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/new-feature

# Build and test
# (Cmd+B and Cmd+R in Xcode)

# Commit changes
git add .
git commit -m "Add: Description"

# Push to your fork
git push origin feature/new-feature

# Create PR on GitHub
```

### Project Structure

```
calendar++/
├── calendar__App.swift          # App entry point
├── EventKitManager.swift        # Calendar integration
├── CalendarViewModel.swift      # State management
├── FocusManager.swift           # Focus modes
├── Views/                       # SwiftUI views
├── Info.plist                   # Configuration
└── ...
```

Happy contributing! 🚀
