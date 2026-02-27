#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[gate] Running calendar++ release gate..."

SMOKE_SIGNING_MODE="${SMOKE_SIGNING_MODE:-unsigned}" \
  "${ROOT_DIR}/scripts/terminal_smoke.sh"

"${ROOT_DIR}/scripts/run_quick_add_parser_regression.sh"
"${ROOT_DIR}/scripts/run_nl_command_regression.sh"

if [[ "${RUN_STABILITY_SMOKE:-0}" == "1" ]]; then
  "${ROOT_DIR}/scripts/stability_smoke.sh"
fi

echo "[gate] PASS: smoke + parser regressions all green."
