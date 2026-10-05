#!/bin/bash
set -u

APP="${1:-./RosettaProcessManagerNoASN.app}"
MANIFEST="${2:-$APP.manifest.txt}"
LOG="${3:-./ppc-process-manager-noasn-snowleopard-control.log}"
MILESTONE_COPY="${4:-./ppc-process-manager-noasn-snowleopard-milestone.log}"

MILESTONE_LOG="/tmp/rosetta-processmanager-noasn-milestone.log"
PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXEC="$APP/Contents/MacOS/RosettaProcessManagerNoASN"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

: > "$LOG" || exit 73
/bin/rm -f "$MILESTONE_COPY"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)" | /usr/bin/tee -a "$LOG"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$LOG"

[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

[ -d "$APP" ] || fail "missing app bundle: $APP"
[ -f "$MANIFEST" ] || fail "missing bundle manifest: $MANIFEST"
[ -x "$EXEC" ] || fail "missing bundled PPC executable: $EXEC"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld"

DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

EXPECTED_EXE_SHA="$(/usr/bin/awk -F= '/^executable_sha256=/ {print $2}' "$MANIFEST" | /usr/bin/head -1)"
[ -n "$EXPECTED_EXE_SHA" ] || fail "could not read executable hash from manifest"
ACTUAL_EXE_SHA="$(sha256 "$EXEC")"
echo "expected_executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_EXE_SHA" | /usr/bin/tee -a "$LOG"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "bundled executable hash mismatch"

/usr/bin/file "$EXEC" 2>&1 | /usr/bin/tee -a "$LOG"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXEC" 2>&1 | /usr/bin/tee -a "$LOG" || true
fi

/bin/rm -f "$MILESTONE_LOG"

echo "== Snow Leopard no-ASN discriminator control ==" | /usr/bin/tee -a "$LOG"
/usr/bin/open -n "$APP" >> "$LOG" 2>&1
OPEN_RC=$?
echo "open_status=$OPEN_RC" | /usr/bin/tee -a "$LOG"

/bin/sleep 5

if [ -f "$MILESTONE_LOG" ]; then
    /bin/cp "$MILESTONE_LOG" "$MILESTONE_COPY"
    echo "== milestone log ==" | /usr/bin/tee -a "$LOG"
    /bin/cat "$MILESTONE_COPY" | /usr/bin/tee -a "$LOG"
else
    echo "milestone_log=missing" | /usr/bin/tee -a "$LOG"
fi

if [ -f "$MILESTONE_COPY" ] &&
   /usr/bin/grep -Fq 'PM_NOASN_ENV:LSDONOTABORTIFNOASN=0' "$MILESTONE_COPY" &&
   /usr/bin/grep -Fq 'PM_NOASN_STATUS:GetProcessForPID=0' "$MILESTONE_COPY" &&
   /usr/bin/grep -Fq 'PM_NOASN_MILESTONE:M06_NOERR_NONZERO_PSN' "$MILESTONE_COPY"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
exit 1
