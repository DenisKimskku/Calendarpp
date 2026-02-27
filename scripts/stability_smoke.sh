#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="calendar++.app"
APP_PATH="/Applications/${APP_NAME}"
APP_BINARY="${APP_PATH}/Contents/MacOS/calendar++"
BUNDLE_ID="den-kim.calendar--"

MONTH_SWITCH_ITERATIONS="${MONTH_SWITCH_ITERATIONS:-36}"
SETTINGS_OPEN_ITERATIONS="${SETTINGS_OPEN_ITERATIONS:-20}"
FEATURE_TOGGLE_ITERATIONS="${FEATURE_TOGGLE_ITERATIONS:-24}"
STEP_DELAY_SECONDS="${STEP_DELAY_SECONDS:-0.08}"

feature_toggle_keys=(
  enableTimeAnalytics
  enableMeetingPrep
  enableFocusProtection
  enableDailyBriefing
  enableSmartBuffer
  enableEnergyScheduling
  enableMeetingCost
  enableAvailabilitySharing
  showExperimentalFeatures
  enableCalendarInbox
  enableNaturalLanguageCommands
  enableAchievements
  enableAIAssistant
  enableSmartScheduling
  enableAutoCategorization
  enableConflictPrediction
)

is_alive() {
  ps ax -o command= | grep -F "${APP_BINARY}" | grep -v grep >/dev/null
}

assert_alive() {
  if ! is_alive; then
    echo "[stability] FAIL: calendar++ is not running." >&2
    exit 1
  fi
}

reset_feature_defaults() {
  defaults write "${BUNDLE_ID}" enableTimeAnalytics -bool true
  defaults write "${BUNDLE_ID}" enableMeetingPrep -bool true
  defaults write "${BUNDLE_ID}" enableFocusProtection -bool false
  defaults write "${BUNDLE_ID}" enableDailyBriefing -bool false
  defaults write "${BUNDLE_ID}" enableSmartBuffer -bool false
  defaults write "${BUNDLE_ID}" enableEnergyScheduling -bool false
  defaults write "${BUNDLE_ID}" enableMeetingCost -bool false
  defaults write "${BUNDLE_ID}" enableAvailabilitySharing -bool false
  defaults write "${BUNDLE_ID}" showExperimentalFeatures -bool false
  defaults write "${BUNDLE_ID}" enableCalendarInbox -bool false
  defaults write "${BUNDLE_ID}" enableNaturalLanguageCommands -bool false
  defaults write "${BUNDLE_ID}" enableAchievements -bool false
  defaults write "${BUNDLE_ID}" enableAIAssistant -bool false
  defaults write "${BUNDLE_ID}" enableSmartScheduling -bool false
  defaults write "${BUNDLE_ID}" enableAutoCategorization -bool false
  defaults write "${BUNDLE_ID}" enableConflictPrediction -bool false
}

echo "[stability] Ensuring app binary exists..."
if [[ ! -x "${APP_BINARY}" ]]; then
  echo "[stability] App not installed. Running terminal smoke install first..."
  SMOKE_SIGNING_MODE="${SMOKE_SIGNING_MODE:-unsigned}" "${ROOT_DIR}/scripts/terminal_smoke.sh"
fi

echo "[stability] Stopping any previous process..."
existing_pids="$(ps ax -o pid=,command= | grep -F "${APP_BINARY}" | grep -v grep | awk '{print $1}' || true)"
if [[ -n "${existing_pids}" ]]; then
  kill ${existing_pids} || true
  sleep 1
fi

echo "[stability] Launching app..."
open -na "${APP_PATH}"
sleep 3
assert_alive

echo "[stability] Stress: switching months via deep link (${MONTH_SWITCH_ITERATIONS} iterations)..."
for i in $(seq 1 "${MONTH_SWITCH_ITERATIONS}"); do
  offset=$((i - (MONTH_SWITCH_ITERATIONS / 2)))
  timestamp=$(( $(date +%s) + (offset * 2629746) ))
  open "calendarplusplus://show-date?timestamp=${timestamp}"
  sleep "${STEP_DELAY_SECONDS}"
done
assert_alive

echo "[stability] Stress: opening settings repeatedly (${SETTINGS_OPEN_ITERATIONS} iterations)..."
for _ in $(seq 1 "${SETTINGS_OPEN_ITERATIONS}"); do
  open "calendarplusplus://settings"
  sleep "${STEP_DELAY_SECONDS}"
done
assert_alive

echo "[stability] Stress: toggling feature defaults (${FEATURE_TOGGLE_ITERATIONS} iterations)..."
for i in $(seq 1 "${FEATURE_TOGGLE_ITERATIONS}"); do
  if (( i % 2 == 0 )); then
    value="true"
  else
    value="false"
  fi
  for key in "${feature_toggle_keys[@]}"; do
    defaults write "${BUNDLE_ID}" "${key}" -bool "${value}"
  done
  sleep "${STEP_DELAY_SECONDS}"
done
reset_feature_defaults
assert_alive

echo "[stability] Verifying normal quit + relaunch path..."
osascript -e 'tell application "calendar++" to quit' || true
sleep 2
open -na "${APP_PATH}"
sleep 3
assert_alive

recent_errors="$(log show --last 2m --style compact --predicate 'process == "calendar++" AND (messageType == error OR messageType == fault OR eventMessage CONTAINS[c] "crash" OR eventMessage CONTAINS[c] "fatal")' 2>/dev/null || true)"
recent_errors_body="$(printf "%s\n" "${recent_errors}" | tail -n +2 | sed '/^[[:space:]]*$/d')"
if [[ -n "${recent_errors_body}" ]]; then
  echo "[stability] WARN: runtime errors/faults were observed:"
  echo "${recent_errors_body}"
fi

echo "[stability] PASS: stress smoke completed without process death."
