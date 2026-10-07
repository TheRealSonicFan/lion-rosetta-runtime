#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-security-session-auditinfo-api-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
INTERPOSER="${3:-./ppc-process-manager-security-session-auditinfo-api.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
LOG="${5:-./ppc-process-manager-security-session-auditinfo-api-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_BUILD_ID="security-session-auditinfo-api-v1"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
abspath() {
    file="$1"
    dir="$(/usr/bin/dirname "$file")"
    base="$(/usr/bin/basename "$file")"
    (cd "$dir" 2>/dev/null && echo "$(pwd)/$base")
}

: > "$LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"

[ -z "${SECURITYSERVER+x}" ] || fail "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || fail "DYLD_INSERT_LIBRARIES must be unset before the runner"
[ -z "${ROSETTA_SECURITY_SESSION_API_COMPAT_MODE+x}" ] || fail "compat mode must be unset before the runner"

for p in "$EXE" "$EXE_SHA_FILE" "$INTERPOSER" "$INTERPOSER_SHA_FILE" "$PRIVATE_DYLD"; do
    [ -e "$p" ] || fail "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"
ACTUAL_EXE_SHA="$(sha256 "$EXE")"
ACTUAL_INTERPOSER_SHA="$(sha256 "$INTERPOSER")"
DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"

echo "expected_executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_interposer_sha256=$ACTUAL_INTERPOSER_SHA" | /usr/bin/tee -a "$LOG"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"

[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "probe hash mismatch"
[ "$ACTUAL_INTERPOSER_SHA" = "$EXPECTED_INTERPOSER_SHA" ] || fail "interposer hash mismatch"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || fail "build marker missing"

INTERPOSER_ABS="$(abspath "$INTERPOSER")"
[ -n "$INTERPOSER_ABS" ] || fail "could not resolve interposer path"

echo "interposer_absolute_path=$INTERPOSER_ABS" | /usr/bin/tee -a "$LOG"
echo "== Snow Leopard SessionGetInfo adapter passthrough control ==" | /usr/bin/tee -a "$LOG"

ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=passthrough DYLD_INSERT_LIBRARIES="$INTERPOSER_ABS" DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 "$EXE" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq "dyld: loaded: $INTERPOSER_ABS" "$LOG" &&
   /usr/bin/grep -Fq "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_CALL:' "$LOG" &&
   /usr/bin/grep -Fq 'mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'targetCaller=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_PASSTHROUGH_RETURN:status=0' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=0' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_RESULT:PASS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
