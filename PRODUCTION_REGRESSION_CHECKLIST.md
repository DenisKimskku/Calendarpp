# calendar++ Production Regression Checklist

## Build & Packaging

- [x] Automated terminal smoke check passes in non-interactive mode: `SMOKE_SIGNING_MODE=unsigned ./scripts/terminal_smoke.sh`
- [x] Automated release gate passes: `./scripts/release_gate.sh`
- [x] Build succeeds with DerivedData outside Desktop:
  `xcodebuild -project calendar++.xcodeproj -scheme calendar++ -configuration Debug -derivedDataPath /tmp/calendarpp-build clean build`
- [x] App launches from `/Applications/calendar++.app` without immediate crash/reopen loop.
- [x] Bundle resources are clean (no duplicate `Info.plist` in `Contents/Resources`).
- [x] Code signing succeeds without Finder metadata/resource-fork errors.

## Startup & Permissions

- [ ] First launch requests Calendar permission only when needed.
- [ ] Start-at-login toggle changes state without requiring double-click.
- [ ] If Start-at-login requires approval, user sees a clear actionable message.
- [ ] Keychain prompts do not loop when opening Google settings/auth states.

## Core Calendar UX (Window)

- [ ] Main window opens at expected size and sidebar does not overlap calendar content.
- [ ] Month/week switch works and day selection updates agenda and inspector.
- [ ] Event inspector appears automatically on wide windows and hides on narrow windows.
- [ ] Quick Add opens in a usable sheet size and event creation refreshes views.

## Menu Bar UX

- [ ] Menu bar popover opens with readable controls (no ambiguous icon-only critical actions).
- [ ] `Quick Add`, `Filter Calendars`, `Features`, and `Settings` actions work from `More`.
- [ ] Settings opens reliably on first click (no double-click behavior).

## Calendar Filtering

- [ ] Hiding a calendar updates:
  - [ ] month/day grids
  - [ ] agenda lists
  - [ ] menu bar indicators/dot/busy bar
  - [ ] Phase 6 analytics panels (where applicable)
- [ ] Google calendar visibility toggle matches local calendar toggle behavior.

## Google Calendar Integration

- [ ] OAuth sign-in completes and tokens persist correctly.
- [ ] Sign-out clears auth state and events.
- [ ] Visible-month browsing fetches Google events for non-current months.
- [ ] Baseline current-range events still power menu bar next-event behavior while browsing other months.

## Phase 6 Feature Hardening

- [ ] Each Phase 6 view renders correctly when embedded in the main window (no forced modal frame clipping).
- [ ] Each Phase 6 view shows a clear “grant calendar access” state if calendar permission is missing.
- [ ] Time Analytics refreshes after calendar/filter changes.
- [ ] Meeting Prep updates upcoming meetings after calendar/filter changes.
- [ ] Focus Protection conflict detection refreshes after calendar/filter changes.
- [ ] Smart Buffer suggestions refresh after calendar/filter/preference changes.
- [ ] Meeting Cost report refreshes after calendar/filter changes and settings updates.
- [ ] Availability slot computation updates with calendar/filter changes and handles missing permission gracefully.
- [ ] Daily Briefing updates after calendar/filter changes.

## Experimental Features Gating

- [ ] Phase 7/8 feature sections remain hidden unless `Enable experimental features` is on.
- [ ] Existing installs migrate to stable defaults (experimental toggles off).

## Stability Smoke

- [ ] App remains stable while:
  - [ ] switching month repeatedly
  - [ ] toggling multiple feature switches quickly
  - [ ] opening/closing Settings repeatedly
  - [ ] signing in/out of Google multiple times
- [ ] No persistent crash dialog on relaunch after normal quit.
