#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-security-session-rpc-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
TRACE="${3:-./ppc-process-manager-security-session-rpc-trace.dylib}"
TRACE_SHA_FILE="${4:-$TRACE.sha256}"
LOG="${5:-./ppc-process-manager-security-session-rpc-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRACE_BUILD_ID="security-session-rpc-trace-v1"

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

[ -z "${SECURITYSERVER+x}" ] || fail "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || fail "DYLD_INSERT_LIBRARIES must be unset before the runner"

[ -x "$EXE" ] || fail "missing or non-executable PPC Security probe: $EXE"
[ -f "$EXE_SHA_FILE" ] || fail "missing probe SHA-256 sidecar: $EXE_SHA_FILE"
[ -f "$TRACE" ] || fail "missing PPC Security RPC tracer: $TRACE"
[ -f "$TRACE_SHA_FILE" ] || fail "missing tracer SHA-256 sidecar: $TRACE_SHA_FILE"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld: $PRIVATE_DYLD"

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_TRACE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$TRACE_SHA_FILE")"
ACTUAL_EXE_SHA="$(sha256 "$EXE")"
ACTUAL_TRACE_SHA="$(sha256 "$TRACE")"
DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"

echo "expected_executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_executable_sha256=$ACTUAL_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "expected_tracer_sha256=$EXPECTED_TRACE_SHA" | /usr/bin/tee -a "$LOG"
echo "actual_tracer_sha256=$ACTUAL_TRACE_SHA" | /usr/bin/tee -a "$LOG"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$LOG"

[ -n "$EXPECTED_EXE_SHA" ] || fail "could not read expected executable SHA-256"
[ -n "$EXPECTED_TRACE_SHA" ] || fail "could not read expected tracer SHA-256"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "probe hash mismatch"
[ "$ACTUAL_TRACE_SHA" = "$EXPECTED_TRACE_SHA" ] || fail "tracer hash mismatch"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/file "$EXE" 2>&1 | /usr/bin/tee -a "$LOG"
/usr/bin/file "$TRACE" 2>&1 | /usr/bin/tee -a "$LOG"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" 2>&1 | /usr/bin/tee -a "$LOG" || true
    /usr/bin/lipo -info "$TRACE" 2>&1 | /usr/bin/tee -a "$LOG" || true
fi

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/otool -L "$EXE" | /usr/bin/tee -a "$LOG"
/usr/bin/otool -L "$EXE" | /usr/bin/grep -Fq '/Security.framework/Versions/A/Security' || fail "Security dependency is absent"

/usr/bin/strings "$TRACE" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_TRACE_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" || fail "tracer build marker is missing"

TRACE_ABS="$(abspath "$TRACE")"
[ -n "$TRACE_ABS" ] || fail "could not resolve tracer absolute path"
echo "tracer_absolute_path=$TRACE_ABS" | /usr/bin/tee -a "$LOG"

echo "== Snow Leopard PPC Security session RPC positive control ==" | /usr/bin/tee -a "$LOG"
DYLD_INSERT_LIBRARIES="$TRACE_ABS" DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1     "$EXE" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq "dyld: loaded: $TRACE_ABS" "$LOG" &&
   /usr/bin/grep -Fq "PM_SECURITY_SESSION_TRACE_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REQUEST:' "$LOG" &&
   /usr/bin/grep -Eq 'PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REPLY:.* kr=0 .*servicePort=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'name=getSessionInfo id=0x00000428' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_SECURITY_SESSION_VALUE:ID=0x0*[1-9a-fA-F][0-9a-fA-F]* ' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_RESULT:PASS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
