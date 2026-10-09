#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-cgs-server-version-compat-protocol-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
LOG="${3:-./ppc-process-manager-cgs-server-version-compat-protocol-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_BUILD_ID="cgs-server-version-compat-protocol-v1"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

has_ppc32_arch() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

: > "$LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"

CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$LOG"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || fail "DYLD_INSERT_LIBRARIES must be unset"

for p in "$EXE" "$SHA_FILE" "$PRIVATE_DYLD"; do
    [ -e "$p" ] || fail "missing required path: $p"
done
[ -x "$EXE" ] || fail "probe is not executable"

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
[ -n "$EXPECTED_EXE_SHA" ] || fail "could not read expected executable SHA-256"
ACTUAL_EXE_SHA="$(sha256 "$EXE")"
echo "expected_executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_EXE_SHA" | /usr/bin/tee -a "$LOG"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "executable hash mismatch"

DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

has_ppc32_arch "$EXE" || fail "probe is not a 32-bit PPC Mach-O"

/usr/bin/file "$EXE" | /usr/bin/tee -a "$LOG"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" 2>&1 | /usr/bin/tee -a "$LOG" || true
fi

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/strings "$EXE" | /usr/bin/grep -Fq     "PM_CGS_SERVER_VERSION_BUILD_ID:$EXPECTED_BUILD_ID" || fail "build marker missing"

echo "== Snow Leopard PPC CGS server-version compatibility positive control ==" | /usr/bin/tee -a "$LOG"
DYLD_PRINT_LIBRARIES=1 "$EXE" snow-control >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_LAYOUT:PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_SNOW_LOOKUP_RETURN:kr=0 ' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_MACH_RETURN:kr=0 ' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000071ac kr=0 ' "$LOG" &&
   /usr/bin/grep -Fq 'disposition=0x11 type=0x00' "$LOG" &&
   /usr/bin/grep -Fq 'major=545 minor=0 ' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_RIGHT:label=snow-version-descriptor' "$LOG" &&
   /usr/bin/grep -Fq 'send=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_SNOW_POLICY:serverMajor=545 serverMinor=0 localMajor=545 localMinor=0 match=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_RESULT:SNOW_CONTROL_PASS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
