#!/usr/bin/env bash
# University Sandbox - headless test runner (Linux).
#
# Usage:
#   Tests/run_tests.sh --godot /path/to/Godot_v3.6.2-stable_linux_headless.64 [--keep] [--timeout SECONDS]
#   GODOT_BIN=/path/to/godot Tests/run_tests.sh
#
# All Godot user data (user://, editor data, config, cache, logs) is redirected into a new
# temporary folder named university_sandbox_tests.XXXXXXXX. Your normal University Sandbox
# and BDCC user-data folders are never used. The folder is deleted after a passing run
# (unless --keep is given) and preserved after a failing run.
#
# Exit codes: 0 = pass, 1 = test failure, 2 = setup error.

set -u

GODOT_BIN="${GODOT_BIN:-}"
KEEP=0
TIMEOUT_SECONDS=600
EXPECTED_VERSION_PREFIX="3.6.2."

usage() {
	sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

setup_error() {
	echo "SETUP ERROR: $*" >&2
	exit 2
}

while [ $# -gt 0 ]; do
	case "$1" in
		--godot) [ $# -ge 2 ] || setup_error "--godot needs a path"; GODOT_BIN="$2"; shift 2 ;;
		--keep) KEEP=1; shift ;;
		--timeout) [ $# -ge 2 ] || setup_error "--timeout needs a number"; TIMEOUT_SECONDS="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) setup_error "unknown argument: $1 (see --help)" ;;
	esac
done

case "$TIMEOUT_SECONDS" in
	''|*[!0-9]*) setup_error "--timeout must be a whole number of seconds" ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
[ -f "$REPO_DIR/project.godot" ] || setup_error "project.godot not found in $REPO_DIR"
[ -f "$REPO_DIR/Tests/run_tests.gd" ] || setup_error "Tests/run_tests.gd not found in $REPO_DIR"

[ -n "$GODOT_BIN" ] || setup_error "no Godot executable given. Use --godot PATH or set GODOT_BIN."
[ -f "$GODOT_BIN" ] && [ -x "$GODOT_BIN" ] || setup_error "Godot executable not found or not executable: $GODOT_BIN"
GODOT_BIN="$(cd "$(dirname "$GODOT_BIN")" && pwd)/$(basename "$GODOT_BIN")"

# PortableModeDetector redirects user data next to the executable if this folder exists.
# That would bypass the temporary test root, so refuse to run.
if [ -e "$(dirname "$GODOT_BIN")/UniversitySandboxData" ]; then
	setup_error "$(dirname "$GODOT_BIN")/UniversitySandboxData exists, so portable mode would redirect user data. Use a Godot executable in a folder without it."
fi

TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="$(cd "$TMP_BASE" && pwd)" || setup_error "temporary folder base is not usable: $TMP_BASE"
TEST_ROOT="$(mktemp -d "$TMP_BASE/university_sandbox_tests.XXXXXXXX")" || setup_error "could not create a temporary test folder"
MARKER="$TEST_ROOT/.university_sandbox_test_root"
: > "$MARKER" || setup_error "could not write marker file in $TEST_ROOT"
mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/data" "$TEST_ROOT/config" "$TEST_ROOT/cache"
OUTPUT_LOG="$TEST_ROOT/harness_output.log"
EXPECTED_USER_DIR="$TEST_ROOT/data/university_sandbox"

safe_remove_test_root() {
	# Only ever removes the exact folder this script created.
	[ -n "${TEST_ROOT:-}" ] || return 1
	[ -d "$TEST_ROOT" ] || return 1
	[ -f "$TEST_ROOT/.university_sandbox_test_root" ] || return 1
	case "$(basename "$TEST_ROOT")" in
		university_sandbox_tests.????????) ;;
		*) return 1 ;;
	esac
	[ "$(cd "$(dirname "$TEST_ROOT")" && pwd)" = "$TMP_BASE" ] || return 1
	rm -rf -- "$TEST_ROOT"
}

interrupted() {
	echo ""
	echo "Interrupted. Test folder preserved: $TEST_ROOT"
	exit 1
}
trap interrupted INT TERM

run_isolated() {
	env -u APPDATA \
		HOME="$TEST_ROOT/home" \
		XDG_DATA_HOME="$TEST_ROOT/data" \
		XDG_CONFIG_HOME="$TEST_ROOT/config" \
		XDG_CACHE_HOME="$TEST_ROOT/cache" \
		US_TEST_ROOT="$TEST_ROOT" \
		"$@"
}

echo "University Sandbox test runner"
echo "  project:   $REPO_DIR"
echo "  godot:     $GODOT_BIN"
echo "  test root: $TEST_ROOT"

GODOT_VERSION="$(run_isolated "$GODOT_BIN" --version 2>/dev/null | tail -n 1)"
echo "  version:   ${GODOT_VERSION:-unknown}"
case "$GODOT_VERSION" in
	"$EXPECTED_VERSION_PREFIX"*) ;;
	*) echo "SETUP ERROR: expected Godot ${EXPECTED_VERSION_PREFIX}x, got '${GODOT_VERSION}'. Test folder preserved: $TEST_ROOT" >&2; exit 2 ;;
esac

TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT_CMD=(timeout "$TIMEOUT_SECONDS")
else
	echo "  note:      'timeout' not available; running without a time limit"
fi

echo ""
run_isolated ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} "$GODOT_BIN" --path "$REPO_DIR" --no-window -s res://Tests/run_tests.gd > "$OUTPUT_LOG" 2>&1
GODOT_EXIT=$?

# Harness output (script errors are shown in full; dummy-renderer noise is only counted).
grep -E '^(HARNESS|==|  \[|         (expected|observed)|====)' "$OUTPUT_LOG"

SCRIPT_ERRORS="$(grep -cE 'SCRIPT ERROR|Parse Error' "$OUTPUT_LOG")"
NETWORK_ERRORS="$(grep -cE 'TLS handshake|Couldn.t get data from github|Couldn.t get the latest release' "$OUTPUT_LOG")"
# Classify each engine "ERROR:" line together with the "at:" line that follows it.
CLASSIFIED="$TEST_ROOT/engine_errors_classified.txt"
awk '
	/^ERROR: / { if (pending != "") classify(pending, ""); pending = $0; next }
	pending != "" && /^ +at: / { classify(pending, $0); pending = ""; next }
	END { if (pending != "") classify(pending, "") }
	function classify(msg, at) {
		if (msg ~ /NULL RID/ || at ~ /rasterizer_dummy/) print "DUMMY"
		else if (msg ~ /TLS handshake/) print "NETWORK"
		else print "OTHER\t" msg "  " at
	}
' "$OUTPUT_LOG" > "$CLASSIFIED"
DUMMY_RENDERER_ERRORS="$(grep -c '^DUMMY$' "$CLASSIFIED")"
OTHER_ENGINE_ERRORS="$(grep -c '^OTHER' "$CLASSIFIED")"

echo ""
echo "Runner checks"
echo "  godot exit code:              $GODOT_EXIT"
echo "  script/parse errors:          $SCRIPT_ERRORS"
echo "  startup network errors:       $NETWORK_ERRORS"
echo "  dummy-renderer messages:      $DUMMY_RENDERER_ERRORS (expected with headless builds; ignored)"
echo "  other engine ERROR lines:     $OTHER_ENGINE_ERRORS (shown below, not treated as failures)"
if [ "$OTHER_ENGINE_ERRORS" -gt 0 ]; then
	grep '^OTHER' "$CLASSIFIED" | cut -f2- | sort | uniq -c | head -n 20 | sed 's/^/    /'
fi
if [ "$SCRIPT_ERRORS" -gt 0 ]; then
	echo "  script errors:"
	grep -E -A2 'SCRIPT ERROR|Parse Error' "$OUTPUT_LOG" | head -n 40 | sed 's/^/    /'
fi

RESULT=PASS
FAIL_REASONS=()
[ "$GODOT_EXIT" -eq 0 ] || { RESULT=FAIL; FAIL_REASONS+=("Godot exited with $GODOT_EXIT (124 means the $TIMEOUT_SECONDS s time limit was hit)"); }
grep -q '^HARNESS RESULT: PASS$' "$OUTPUT_LOG" || { RESULT=FAIL; FAIL_REASONS+=("harness did not report PASS"); }
[ "$SCRIPT_ERRORS" -eq 0 ] || { RESULT=FAIL; FAIL_REASONS+=("$SCRIPT_ERRORS script/parse error line(s)"); }
[ "$NETWORK_ERRORS" -eq 0 ] || { RESULT=FAIL; FAIL_REASONS+=("$NETWORK_ERRORS startup network line(s)"); }
[ -d "$EXPECTED_USER_DIR" ] || { RESULT=FAIL; FAIL_REASONS+=("expected isolated user folder was not created: $EXPECTED_USER_DIR"); }

echo ""
if [ "$RESULT" = PASS ]; then
	echo "OVERALL: PASS"
	if [ "$KEEP" -eq 1 ]; then
		echo "Test folder kept (--keep): $TEST_ROOT"
	elif safe_remove_test_root; then
		echo "Test folder removed: $TEST_ROOT"
	else
		echo "WARNING: test folder was not removed because a safety check failed: $TEST_ROOT"
	fi
	exit 0
fi

echo "OVERALL: FAIL"
for reason in "${FAIL_REASONS[@]}"; do
	echo "  - $reason"
done
echo "Test folder preserved for inspection: $TEST_ROOT"
echo "  full output:  $OUTPUT_LOG"
echo "  godot log:    $EXPECTED_USER_DIR/logs/godot.log"
exit 1
