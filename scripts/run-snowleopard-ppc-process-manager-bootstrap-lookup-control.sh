#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-bootstrap-lookup-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
LOG="${3:-./ppc-process-manager-bootstrap-lookup-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"

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
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"

[ -z "${CORESERVICESD_SERVICE_NAME+x}" ] || fail "CORESERVICESD_SERVICE_NAME must be unset"
[ -z "${SCDontUseServer+x}" ] || fail "SCDontUseServer must be unset"

[ -x "$EXE" ] || fail "missing or non-executable PPC bootstrap-lookup probe: $EXE"
[ -f "$SHA_FILE" ] || fail "missing SHA-256 sidecar: $SHA_FILE"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld: $PRIVATE_DYLD"

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
[ -n "$EXPECTED_EXE_SHA" ] || fail "could not read expected executable SHA-256"
ACTUAL_EXE_SHA="$(sha256 "$EXE")"
echo "expected_executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_EXE_SHA" | /usr/bin/tee -a "$LOG"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "executable hash mismatch"

DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/file "$EXE" | /usr/bin/tee -a "$LOG"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" 2>&1 | /usr/bin/tee -a "$LOG" || true
fi

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/otool -L "$EXE" | /usr/bin/tee -a "$LOG"

echo "== Snow Leopard PPC coreservicesd bootstrap lookup positive control ==" | /usr/bin/tee -a "$LOG"
DYLD_PRINT_LIBRARIES=1 "$EXE" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Eq 'PM_BOOTSTRAP_LOOKUP_BOOTSTRAP_PORT:0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'PM_BOOTSTRAP_LOOKUP_ENV:CORESERVICESD_SERVICE_NAME=UNSET' "$LOG" &&
   /usr/bin/grep -Fq 'PM_BOOTSTRAP_LOOKUP_ENV:SCDontUseServer=UNSET' "$LOG" &&
   /usr/bin/grep -Fq 'PM_BOOTSTRAP_LOOKUP_RETURN:kr=0 ' "$LOG" &&
   /usr/bin/grep -Eq 'servicePort=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'PM_BOOTSTRAP_LOOKUP_RESULT:LOOKUP_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_BOOTSTRAP_LOOKUP_MILESTONE:M03_SUCCESS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
