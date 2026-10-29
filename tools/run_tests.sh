#!/usr/bin/env bash
# Runs every automated check: data validation, touch-input tests and an
# AI-vs-AI smoke match. Fails if any check fails or Godot logs a script error.
#
# Usage: GODOT=/path/to/godot tools/run_tests.sh
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG_DIR="$(mktemp -d)"

echo "== Validating faction data"
python3 tools/validate_data.py

echo "== Importing project"
"$GODOT" --headless --import > "$LOG_DIR/import.log" 2>&1 || true

check_log() {
	if grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$1"; then
		echo "Godot reported script errors (see above)"
		exit 1
	fi
}

echo "== Touch input tests"
set +e
"$GODOT" --headless --fixed-fps 60 -- --run-input-tests 2>&1 | tee "$LOG_DIR/input.log"
status=${PIPESTATUS[0]}
set -e
check_log "$LOG_DIR/input.log"
grep -q "INPUT_TESTS PASSED" "$LOG_DIR/input.log" || { echo "Input tests failed"; exit 1; }
[ "$status" -eq 0 ] || exit "$status"

echo "== AI vs AI smoke match"
"$GODOT" --headless --fixed-fps 30 -- --ai-vs-ai --quit-after-seconds=600 2>&1 | tee "$LOG_DIR/smoke.log"
check_log "$LOG_DIR/smoke.log"
grep -q "MATCH_SUMMARY" "$LOG_DIR/smoke.log" || { echo "Smoke match did not finish"; exit 1; }

echo "All checks passed."
