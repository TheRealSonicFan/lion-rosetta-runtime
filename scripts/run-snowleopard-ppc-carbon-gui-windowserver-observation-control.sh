#!/bin/bash
set -u

EXE="${1:-./ppc-carbon-gui-smoketest-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
OBSERVER="${3:-./cgwindowlist-pid-observer}"
OBSERVER_SHA_FILE="${4:-$OBSERVER.sha256}"
SUBJECT_LOG="${5:-./ppc-carbon-gui-windowserver-snow-control.log}"
OBSERVER_LOG="${6:-./ppc-carbon-gui-windowserver-snow-observer.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_EXE_SHA="fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_OBSERVER_BUILD_ID="cgwindowlist-pid-observer-v1"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$SUBJECT_LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

sidecar_sha() {
    /usr/bin/awk 'NR==1 {print $1}' "$1"
}

: > "$SUBJECT_LOG" || exit 73
: > "$OBSERVER_LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

echo "== Snow Leopard PPC Carbon GUI WindowServer observation control ==" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$SUBJECT_LOG"

[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"
[ -n "$CURRENT_USER" ] || fail "could not determine current user"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from logged-in Aqua console user's Terminal"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

[ -x "$EXE" ] || fail "missing or non-executable historical subject"
[ -f "$EXE_SHA_FILE" ] || fail "missing subject SHA sidecar"
[ -x "$OBSERVER" ] || fail "missing or non-executable WindowServer observer"
[ -f "$OBSERVER_SHA_FILE" ] || fail "missing observer SHA sidecar"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld"

EXE_SHA="$(sha256 "$EXE")"
EXE_DECLARED_SHA="$(sidecar_sha "$EXE_SHA_FILE")"
OBSERVER_SHA="$(sha256 "$OBSERVER")"
OBSERVER_DECLARED_SHA="$(sidecar_sha "$OBSERVER_SHA_FILE")"
DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"

echo "subject_sha256=$EXE_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_sha256=$OBSERVER_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"

[ "$EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "historical subject hash mismatch"
[ "$EXE_DECLARED_SHA" = "$EXPECTED_EXE_SHA" ] || fail "historical subject sidecar mismatch"
[ "$OBSERVER_SHA" = "$OBSERVER_DECLARED_SHA" ] || fail "observer sidecar mismatch"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/strings "$OBSERVER" | /usr/bin/grep -Fq \
    "CGWINDOW_OBSERVER_BUILD_ID:$EXPECTED_OBSERVER_BUILD_ID" ||
    fail "observer build marker missing"

/usr/bin/file "$EXE" | /usr/bin/tee -a "$SUBJECT_LOG"
/usr/bin/file "$OBSERVER" | /usr/bin/tee -a "$SUBJECT_LOG"
/usr/bin/lipo -verify_arch ppc "$EXE" >/dev/null 2>&1 ||
    /usr/bin/lipo "$EXE" -verify_arch ppc >/dev/null 2>&1 ||
    fail "historical subject is not PPC"
/usr/bin/lipo -verify_arch i386 "$OBSERVER" >/dev/null 2>&1 ||
    /usr/bin/lipo "$OBSERVER" -verify_arch i386 >/dev/null 2>&1 ||
    fail "observer is not i386"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' ||
    fail "subject LC_LOAD_DYLINKER is not /usr/oah/dyld"

echo "== single Snow positive-control run with external CGWindowList observation ==" | /usr/bin/tee -a "$SUBJECT_LOG"
DYLD_PRINT_LIBRARIES=1 "$EXE" >> "$SUBJECT_LOG" 2>&1 &
APP_PID=$!
echo "subject_pid=$APP_PID" | /usr/bin/tee -a "$SUBJECT_LOG"

"$OBSERVER" "$APP_PID" 2800 40 "Rosetta PPC Carbon GUI" > "$OBSERVER_LOG" 2>&1 &
OBSERVER_PID=$!

wait "$APP_PID"
APP_RC=$?
wait "$OBSERVER_PID"
OBSERVER_RC=$?

echo "subject_status=$APP_RC" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_status=$OBSERVER_RC" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "== observer report ==" | /usr/bin/tee -a "$SUBJECT_LOG"
/bin/cat "$OBSERVER_LOG" | /usr/bin/tee -a "$SUBJECT_LOG"

WINDOW_MARKER_COUNT="$(/usr/bin/grep -c '^Rosetta PPC Carbon GUI window shown:' "$SUBJECT_LOG" 2>/dev/null || true)"
SMOKE_MARKER_COUNT="$(/usr/bin/grep -c '^Rosetta PPC Carbon GUI smoke test:' "$SUBJECT_LOG" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_LOG" 2>/dev/null || true)"
SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_LOG" 2>/dev/null | /usr/bin/tail -1)"
MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_LOG" 2>/dev/null || true)"

echo "window_marker_count=$WINDOW_MARKER_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "smoke_marker_count=$SMOKE_MARKER_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_main_display_count=$MAIN_DISPLAY_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_summary=$SUMMARY_LINE" | /usr/bin/tee -a "$SUBJECT_LOG"

echo "$SUMMARY_LINE" | /usr/bin/grep -Eq 'samplesWithWindows=[1-9][0-9]*' ||
    fail "Snow observer never saw a window for the subject PID"
echo "$SUMMARY_LINE" | /usr/bin/grep -Eq 'samplesWithOnscreen=[1-9][0-9]*' ||
    fail "Snow observer never saw an onscreen subject window"
echo "$SUMMARY_LINE" | /usr/bin/grep -Eq 'samplesWithExactTitle=[1-9][0-9]*' ||
    fail "Snow observer never saw the exact window title"

if [ "$APP_RC" -eq 0 ] &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$MAIN_DISPLAY_COUNT" -eq 1 ]; then
    echo "RESULT: PPC_CARBON_GUI_WINDOWSERVER_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$SUBJECT_LOG"
    echo "manual_window_observation=REQUIRED" | /usr/bin/tee -a "$SUBJECT_LOG"
    echo "RESULT: PASS" | /usr/bin/tee -a "$SUBJECT_LOG"
    exit 0
fi

echo "RESULT: PPC_CARBON_GUI_WINDOWSERVER_SNOW_CONTROL_FAIL" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "RESULT: FAIL" | /usr/bin/tee -a "$SUBJECT_LOG"
exit 1
