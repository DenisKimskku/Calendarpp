#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-/tmp/calendarpp-smoke}"
BUILD_LOG="${BUILD_LOG:-/tmp/calendarpp-smoke-build.log}"
APP_NAME="calendar++.app"
APP_PATH="/Applications/${APP_NAME}"
APP_BINARY="${APP_PATH}/Contents/MacOS/calendar++"
SMOKE_SIGNING_MODE="${SMOKE_SIGNING_MODE:-unsigned}" # unsigned | signed

echo "[smoke] Building calendar++ (${SMOKE_SIGNING_MODE})..."

XCODEBUILD_ARGS=(
  -project "${ROOT_DIR}/calendar++.xcodeproj"
  -scheme "calendar++"
  -configuration Debug
  -derivedDataPath "${DERIVED_DATA}"
  build
)

if [[ "${SMOKE_SIGNING_MODE}" == "unsigned" ]]; then
  # CI/local smoke should not depend on interactive keychain prompts.
  XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")
elif [[ "${SMOKE_SIGNING_MODE}" != "signed" ]]; then
  echo "[smoke] Invalid SMOKE_SIGNING_MODE: ${SMOKE_SIGNING_MODE} (expected: unsigned|signed)" >&2
  exit 1
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" >"${BUILD_LOG}" 2>&1

BUILT_APP="${DERIVED_DATA}/Build/Products/Debug/${APP_NAME}"
if [[ ! -d "${BUILT_APP}" ]]; then
  echo "[smoke] Build output not found at ${BUILT_APP}" >&2
  exit 1
fi

if rg -q "(Skipping duplicate build file in Copy Bundle Resources build phase|Copy Bundle Resources.*Info\\.plist|contains this target's Info\\.plist file)" "${BUILD_LOG}"; then
  echo "[smoke] Duplicate Info.plist copy warning detected in build log." >&2
  echo "[smoke] Build log: ${BUILD_LOG}" >&2
  exit 1
fi

if find "${BUILT_APP}/Contents/Resources" -name "Info.plist" -print -quit | grep -q .; then
  echo "[smoke] Duplicate Info.plist found in app resources." >&2
  exit 1
fi

echo "[smoke] Installing app to /Applications..."
ditto "${BUILT_APP}" "${APP_PATH}"

echo "[smoke] Stopping previous calendar++ process (if any)..."
existing_pids="$(ps ax -o pid=,command= | grep -F "${APP_BINARY}" | grep -v grep | awk '{print $1}' || true)"
if [[ -n "${existing_pids}" ]]; then
  kill ${existing_pids} || true
  sleep 1
fi

echo "[smoke] Launching app..."
open -na "${APP_PATH}"
sleep 5

if ! ps ax -o command= | grep -F "${APP_BINARY}" | grep -v grep >/dev/null; then
  echo "[smoke] App did not stay alive after launch." >&2
  echo "[smoke] Build log: ${BUILD_LOG}" >&2
  exit 1
fi

recent_errors="$(log show --last 2m --style compact --predicate 'process == "calendar++" AND (messageType == error OR messageType == fault OR eventMessage CONTAINS[c] "crash" OR eventMessage CONTAINS[c] "fatal")' 2>/dev/null || true)"
recent_errors_body="$(printf "%s\n" "${recent_errors}" | tail -n +2 | sed '/^[[:space:]]*$/d')"
if [[ -n "${recent_errors_body}" ]]; then
  echo "[smoke] Runtime warnings detected:"
  echo "${recent_errors_body}"
fi

echo "[smoke] PASS: app builds, launches, and stays alive."
