#!/bin/bash
set -u

APP="${1:-./RosettaCarbonLaunchServices.app}"
MANIFEST="${2:-$APP.manifest.txt}"
LOG="${3:-./ppc-carbon-launchservices-snowleopard-control.log}"

MILESTONE_LOG="/tmp/rosetta-carbon-launchservices-milestone.log"
PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXEC="$APP/Contents/MacOS/RosettaCarbonLaunchServices"
PLIST="$APP/Contents/Info.plist"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

: > "$LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$LOG"

[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

[ -d "$APP" ] || fail "missing app bundle: $APP"
[ -f "$MANIFEST" ] || fail "missing bundle manifest: $MANIFEST"
[ -x "$EXEC" ] || fail "missing bundled PPC executable: $EXEC"
[ -f "$PLIST" ] || fail "missing Info.plist: $PLIST"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld: $PRIVATE_DYLD"

DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

EXPECTED_EXE_SHA="$(/usr/bin/awk -F= '/^executable_sha256=/ {print $2}' "$MANIFEST" | /usr/bin/head -1)"
[ -n "$EXPECTED_EXE_SHA" ] || fail "could not read executable hash from manifest"
ACTUAL_EXE_SHA="$(sha256 "$EXEC")"
echo "expected_executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_EXE_SHA" | /usr/bin/tee -a "$LOG"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "bundled executable hash mismatch"

CACHE_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_SHARED_CACHE_DONT_VALIDATE' "$PLIST" 2>/dev/null || true)"
PRINT_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_PRINT_LIBRARIES' "$PLIST" 2>/dev/null || true)"
[ "$CACHE_ENV" = "1" ] || fail "Info.plist cache-bypass environment missing"
[ "$PRINT_ENV" = "1" ] || fail "Info.plist DYLD_PRINT_LIBRARIES missing"

echo "LSEnvironment.DYLD_SHARED_CACHE_DONT_VALIDATE=$CACHE_ENV" | /usr/bin/tee -a "$LOG"
echo "LSEnvironment.DYLD_PRINT_LIBRARIES=$PRINT_ENV" | /usr/bin/tee -a "$LOG"

/usr/bin/file "$EXEC" 2>&1 | /usr/bin/tee -a "$LOG"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXEC" 2>&1 | /usr/bin/tee -a "$LOG" || true
fi

/bin/rm -f "$MILESTONE_LOG"

if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$APP" >> "$LOG" 2>&1 || fail "lsregister failed"
fi

echo "== Snow Leopard LaunchServices Carbon control ==" | /usr/bin/tee -a "$LOG"
/usr/bin/open -n -W "$APP" >> "$LOG" 2>&1
OPEN_RC=$?
echo "open_status=$OPEN_RC" | /usr/bin/tee -a "$LOG"

/bin/sleep 1

if [ -f "$MILESTONE_LOG" ]; then
    echo "== milestone log ==" | /usr/bin/tee -a "$LOG"
    /bin/cat "$MILESTONE_LOG" | /usr/bin/tee -a "$LOG"
else
    echo "milestone_log=missing" | /usr/bin/tee -a "$LOG"
fi

/bin/cat "$LOG"

if [ -f "$MILESTONE_LOG" ] &&
   /usr/bin/grep -Fq 'CARBON_LS_ENV:DYLD_SHARED_CACHE_DONT_VALIDATE=1' "$MILESTONE_LOG" &&
   /usr/bin/grep -Fq 'CARBON_LS_MILESTONE:M00_MAIN_ENTER' "$MILESTONE_LOG" &&
   /usr/bin/grep -Fq 'CARBON_LS_MILESTONE:M27_SUCCESS' "$MILESTONE_LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
exit 1
