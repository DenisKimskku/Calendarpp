#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_PATH="/tmp/calendarpp-nl-command-regression"

swiftc \
  "${ROOT_DIR}/calendar++/CalendarModels.swift" \
  "${ROOT_DIR}/calendar++/AppNotifications.swift" \
  "${ROOT_DIR}/calendar++/NaturalLanguageCommandsManager.swift" \
  "${ROOT_DIR}/scripts/nl_command_regression.swift" \
  -o "${BIN_PATH}"

"${BIN_PATH}"
