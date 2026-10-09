#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-cps-registration-compat-protocol-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
LOG="${3:-./ppc-process-manager-cps-registration-compat-protocol-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_BUILD_ID="cps-registration-compat-protocol-v1"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

: > "$LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"

[ -e "$EXE" ] || fail "missing executable: $EXE"
[ -e "$SHA_FILE" ] || fail "missing SHA sidecar: $SHA_FILE"
[ -e "$PRIVATE_DYLD" ] || fail "missing private dyld"

EXPECTED_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
ACTUAL_SHA="$(sha256 "$EXE")"
echo "expected_executable_sha256=$EXPECTED_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_SHA" | /usr/bin/tee -a "$LOG"
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] || fail "executable hash mismatch"
[ "$(sha256 "$PRIVATE_DYLD")" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/strings "$EXE" | /usr/bin/grep -Fq     "PM_CPS_REGISTRATION_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || fail "build marker missing"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "LC_LOAD_DYLINKER is not /usr/oah/dyld"

for v in DYLD_INSERT_LIBRARIES LSDONOTABORTIFNOASN; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || fail "$v must be unset"
done

echo "== Snow Leopard CPS registration compatibility policy control ==" | /usr/bin/tee -a "$LOG"
"$EXE" snow-control >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_SNOW_LAYOUT:bits=0x00001513 id=0x00007372 send=0x00000084 recv=0x0000002c stringLength=0x00000043' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CAPTURED_ERROR_MODEL:raw=0xd0feffff decoded=-304 ndrSwapped=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:SNOW_CONTROL_PASS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
