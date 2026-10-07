#!/bin/bash
set -u

STAGE_EXE="${1:-./ppc-process-manager-coreservices-compat-integration-stage-private-dyld}"
STAGE_SHA_FILE="${2:-$STAGE_EXE.sha256}"
INTERPOSER="${3:-./ppc-process-manager-coreservices-compat-interposer.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
LOG="${5:-./ppc-process-manager-coreservices-compat-integration-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-v2"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

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

[ -z "${CORESERVICESD_SERVICE_NAME+x}" ] || fail "CORESERVICESD_SERVICE_NAME must be unset"
[ -z "${SCDontUseServer+x}" ] || fail "SCDontUseServer must be unset"
[ -z "${ROSETTA_CORESERVICES_COMPAT_MODE+x}" ] || fail "ROSETTA_CORESERVICES_COMPAT_MODE must be unset before the runner"
[ -z "${ROSETTA_BOOTSTRAP_COMPAT_MODE+x}" ] || fail "ROSETTA_BOOTSTRAP_COMPAT_MODE must be unset before the runner"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || fail "DYLD_INSERT_LIBRARIES must be unset before the runner"

[ -x "$STAGE_EXE" ] || fail "missing or non-executable PPC stage subject: $STAGE_EXE"
[ -f "$STAGE_SHA_FILE" ] || fail "missing stage SHA-256 sidecar: $STAGE_SHA_FILE"
[ -f "$INTERPOSER" ] || fail "missing PPC CoreServices compatibility interposer: $INTERPOSER"
[ -f "$INTERPOSER_SHA_FILE" ] || fail "missing interposer SHA-256 sidecar: $INTERPOSER_SHA_FILE"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld: $PRIVATE_DYLD"

EXPECTED_STAGE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$STAGE_SHA_FILE")"
ACTUAL_STAGE_SHA="$(sha256 "$STAGE_EXE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"
ACTUAL_INTERPOSER_SHA="$(sha256 "$INTERPOSER")"

echo "expected_stage_sha256=$EXPECTED_STAGE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_stage_sha256=$ACTUAL_STAGE_SHA" | /usr/bin/tee -a "$LOG"
echo "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_interposer_sha256=$ACTUAL_INTERPOSER_SHA" | /usr/bin/tee -a "$LOG"

[ -n "$EXPECTED_STAGE_SHA" ] || fail "could not read expected stage SHA-256"
[ -n "$EXPECTED_INTERPOSER_SHA" ] || fail "could not read expected interposer SHA-256"
[ "$ACTUAL_STAGE_SHA" = "$EXPECTED_STAGE_SHA" ] || fail "stage executable hash mismatch"
[ "$ACTUAL_INTERPOSER_SHA" = "$EXPECTED_INTERPOSER_SHA" ] || fail "interposer hash mismatch"

DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/file "$STAGE_EXE" | /usr/bin/tee -a "$LOG"
/usr/bin/file "$INTERPOSER" | /usr/bin/tee -a "$LOG"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$STAGE_EXE" 2>&1 | /usr/bin/tee -a "$LOG" || true
    /usr/bin/lipo -info "$INTERPOSER" 2>&1 | /usr/bin/tee -a "$LOG" || true
fi

OT="$(/usr/bin/otool -l "$STAGE_EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "stage LC_LOAD_DYLINKER is not /usr/oah/dyld"

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/tee -a "$LOG"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || fail "interposer section missing"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || fail "interposer does not contain exactly two PPC interpose tuples"

/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_COMPAT_BUILD_ID" || fail "interposer build marker is missing"
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS' || fail "ServerCheckin adapter marker is missing"

INTERPOSER_ABS="$(abspath "$INTERPOSER")"
[ -n "$INTERPOSER_ABS" ] || fail "could not resolve interposer absolute path"
echo "interposer_absolute_path=$INTERPOSER_ABS" | /usr/bin/tee -a "$LOG"

echo "== Snow Leopard PPC dual CoreServices integration positive control ==" | /usr/bin/tee -a "$LOG"
ROSETTA_CORESERVICES_COMPAT_MODE=passthrough DYLD_INSERT_LIBRARIES="$INTERPOSER_ABS" DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1     "$STAGE_EXE" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq "dyld: loaded: $INTERPOSER_ABS" "$LOG" &&
   /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_COMPAT_BUILD_ID" "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=0 ' "$LOG" &&
   /usr/bin/grep -Eq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:.*servicePort=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE:bits=0x80001513 headerSize=0x00000028 id=0x00002710 option=0x00000003 send=0x00000028 recv=0x0000003c' "$LOG" &&
   /usr/bin/grep -Eq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE:.*descriptorCount=1 descriptorPort=0x0*[1-9a-fA-F][0-9a-fA-F]* disposition=0x13 type=0x00' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_PASSTHROUGH:bits=0x80001513 send=0x00000028 recv=0x0000003c' "$LOG" &&
   /usr/bin/grep -Eq 'PM_SYSTEMSERVICE_STAGE_SERVICE:port=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Eq 'PM_SYSTEMSERVICE_STAGE_CHECKIN:port=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
