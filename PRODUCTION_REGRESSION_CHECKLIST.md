# calendar++ Production Regression Checklist

## Step 1 Audit (2026-02-20)

- `SMOKE_SIGNING_MODE=unsigned ./scripts/terminal_smoke.sh`: PASS
- `./scripts/release_gate.sh`: PASS (includes quick-add + NL command regressions)
- `xcodebuild -project calendar++.xcodeproj -scheme calendar++ -configuration Debug -derivedDataPath /tmp/calendarpp-build clean build`: PASS
- `xcodebuild -project calendar++.xcodeproj -scheme calendar++ -configuration Debug -derivedDataPath /tmp/calendarpp-signed-build clean build`: PASS
- Duplicate `Info.plist` warning check in build logs: NOT FOUND
- `/Applications/calendar++.app/Contents/Resources` duplicate `Info.plist` scan: NONE

## Step 2 Audit (2026-02-20)

- `./scripts/stability_smoke.sh`: PASS (month-switch deep-link stress, settings open loop, feature-toggle stress, quit/relaunch liveness)
- Stress log status: no crash/fault output in the final run window.

## Build & Packaging

- [x] Automated terminal smoke check passes in non-interactive mode: `SMOKE_SIGNING_MODE=unsigned ./scripts/terminal_smoke.sh`
- [x] Automated release gate passes: `./scripts/release_gate.sh`
- [x] Build succeeds with DerivedData outside Desktop:
  `xcodebuild -project calendar++.xcodeproj -scheme calendar++ -configuration Debug -derivedDataPath /tmp/calendarpp-build clean build`
- [x] App launches from `/Applications/calendar++.app` without immediate crash/reopen loop.
- [x] Bundle resources are clean (no duplicate `Info.plist` in `Contents/Resources`).
- [x] Code signing succeeds without Finder metadata/resource-fork errors.

## Startup & Permissions

- [x] First launch requests Calendar permission only when needed.
- [x] Start-at-login toggle changes state without requiring double-click.
- [x] If Start-at-login requires approval, user sees a clear actionable message.
- [x] Keychain prompts do not loop when opening Google settings/auth states.

## Core Calendar UX (Window)

- [ ] Main window opens at expected size and sidebar does not overlap calendar content.
- [ ] Month/week switch works and day selection updates agenda and inspector.
- [x] Event inspector appears automatically on wide windows and hides on narrow windows.
- [x] Quick Add opens in a usable sheet size and event creation refreshes views.

## Menu Bar UX

- [x] Menu bar popover opens with readable controls (no ambiguous icon-only critical actions).
- [x] `Quick Add`, `Filter Calendars`, `Features`, and `Settings` actions are accessible from footer controls and `More`.
- [x] Settings opens reliably on first click (no double-click behavior).

## Calendar Filtering

- [x] Hiding a calendar updates:
  - [x] month/day grids
  - [x] agenda lists
  - [x] menu bar indicators/dot/busy bar
  - [x] Phase 6 analytics panels (where applicable)
- [x] Google calendar visibility toggle matches local calendar toggle behavior.

## Google Calendar Integration

- [ ] OAuth sign-in completes and tokens persist correctly.
- [x] Sign-out clears auth state and events.
- [x] Visible-month browsing fetches Google events for non-current months.
- [x] Baseline current-range events still power menu bar next-event behavior while browsing other months.

## Phase 6 Feature Hardening

- [ ] Each Phase 6 view renders correctly when embedded in the main window (no forced modal frame clipping).
- [x] Each Phase 6 view shows a clear "grant calendar access" state if calendar permission is missing.
- [x] Time Analytics refreshes after calendar/filter changes.
- [x] Meeting Prep updates upcoming meetings after calendar/filter changes.
- [x] Focus Protection conflict detection refreshes after calendar/filter changes.
- [x] Smart Buffer suggestions refresh after calendar/filter/preference changes.
- [x] Meeting Cost report refreshes after calendar/filter changes and settings updates.
- [x] Availability slot computation updates with calendar/filter changes and handles missing permission gracefully.
- [x] Daily Briefing updates after calendar/filter changes.

## Experimental Features Gating

- [x] Phase 7/8 feature sections remain hidden unless `Enable experimental features` is on.
- [x] Existing installs migrate to stable defaults (experimental toggles off).

## Stability Smoke

- [ ] App remains stable while:
  - [x] switching month repeatedly
  - [x] toggling multiple feature switches quickly
  - [x] opening/closing Settings repeatedly
  - [ ] signing in/out of Google multiple times
- [x] No persistent crash dialog on relaunch after normal quit.
