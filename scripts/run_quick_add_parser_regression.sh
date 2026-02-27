#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_PATH="/tmp/calendarpp-quick-add-parser-regression"

swiftc \
  "${ROOT_DIR}/calendar++/SmartEventParser.swift" \
  "${ROOT_DIR}/scripts/quick_add_parser_regression.swift" \
  -o "${BIN_PATH}"

"${BIN_PATH}"
