#!/bin/bash
set -u

SUBJECT="${1:-./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
SUBJECT_SHA_FILE="${2:-$SUBJECT.sha256}"
CORE_COMPAT="${3:-./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-protocol.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
SEC_INTERPOSER="${5:-./ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
CGS_INTERPOSER="${7:-./ppc-process-manager-cgs-session-bootstrap-compat.dylib}"
CGS_SHA_FILE="${8:-$CGS_INTERPOSER.sha256}"
LOG="${9:-./ppc-process-manager-setfront-compat-protocol-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_SUBJECT_BUILD_ID="cps-registration-setfront-trace-v1"
EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-protocol-v1"
EXPECTED_SEC_BUILD_ID="security-session-auditinfo-api-v1"
EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-compat-v1"

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

for v in CORESERVICESD_SERVICE_NAME SCDontUseServer LSDONOTABORTIFNOASN \
         ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE \
         ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE \
         ROSETTA_CPS_REGISTRATION_COMPAT_MODE ROSETTA_CPS_SETFRONT_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || fail "$v must be unset before the runner"
done

for p in "$SUBJECT" "$SUBJECT_SHA_FILE" "$CORE_COMPAT" "$CORE_COMPAT_SHA_FILE" \
         "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$CGS_INTERPOSER" "$CGS_SHA_FILE" \
         "$PRIVATE_DYLD"; do
    [ -e "$p" ] || fail "missing required path: $p"
done

EXPECTED_SUBJECT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SUBJECT_SHA_FILE")"
EXPECTED_CORE_COMPAT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_COMPAT_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"
EXPECTED_CGS_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CGS_SHA_FILE")"

[ "$(sha256 "$SUBJECT")" = "$EXPECTED_SUBJECT_SHA" ] || fail "subject hash mismatch"
[ "$(sha256 "$CORE_COMPAT")" = "$EXPECTED_CORE_COMPAT_SHA" ] || fail "CoreServices CPS registration compatibility hash mismatch"
[ "$(sha256 "$SEC_INTERPOSER")" = "$EXPECTED_SEC_SHA" ] || fail "Security interposer hash mismatch"
[ "$(sha256 "$CGS_INTERPOSER")" = "$EXPECTED_CGS_SHA" ] || fail "CGS interposer hash mismatch"
[ "$(sha256 "$PRIVATE_DYLD")" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

for p in "$SUBJECT" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER"; do
    has_ppc32_arch "$p" || fail "required artifact is not 32-bit PPC: $p"
done

/usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq \
    "PM_CPS_REGISTRATION_SETFRONT_TRACE_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID" || fail "subject build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_COMPAT_BUILD_ID" || fail "CoreServices CPS registration compatibility build marker missing"
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || fail "Security build marker missing"
/usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_CGS_BUILD_ID" || fail "CGS build marker missing"

OT="$(/usr/bin/otool -l "$SUBJECT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "LC_LOAD_DYLINKER is not /usr/oah/dyld"

CORE_ABS="$(abspath "$CORE_COMPAT")"
SEC_ABS="$(abspath "$SEC_INTERPOSER")"
CGS_ABS="$(abspath "$CGS_INTERPOSER")"
[ -n "$CORE_ABS" ] || fail "could not resolve CoreServices CPS registration compatibility path"
[ -n "$SEC_ABS" ] || fail "could not resolve Security interposer path"
[ -n "$CGS_ABS" ] || fail "could not resolve CGS interposer path"
INSERTED="$CORE_ABS:$SEC_ABS:$CGS_ABS"

echo "subject_sha256=$EXPECTED_SUBJECT_SHA" | /usr/bin/tee -a "$LOG"
echo "coreservices_cps_registration_compat_sha256=$EXPECTED_CORE_COMPAT_SHA" | /usr/bin/tee -a "$LOG"
echo "security_interposer_sha256=$EXPECTED_SEC_SHA" | /usr/bin/tee -a "$LOG"
echo "cgs_interposer_sha256=$EXPECTED_CGS_SHA" | /usr/bin/tee -a "$LOG"
echo "private_dyld_sha256=$EXPECTED_DYLD_SHA" | /usr/bin/tee -a "$LOG"

echo "== Snow Leopard SetFrontProcess compatibility protocol control ==" | /usr/bin/tee -a "$LOG"
ROSETTA_CORESERVICES_COMPAT_MODE=passthrough \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=passthrough \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=passthrough \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=passthrough \
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=passthrough \
ROSETTA_CPS_SETFRONT_COMPAT_MODE=passthrough \
DYLD_INSERT_LIBRARIES="$INSERTED" \
DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 \
"$SUBJECT" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if /usr/bin/grep -Fq 'kind=SERVER_VERSION' "$LOG"; then
    echo "server_version_observed=YES" | /usr/bin/tee -a "$LOG"
else
    echo "server_version_observed=NO" | /usr/bin/tee -a "$LOG"
fi
if /usr/bin/grep -Fq 'kind=DEATHWATCH' "$LOG"; then
    echo "deathwatch_observed=YES" | /usr/bin/tee -a "$LOG"
else
    echo "deathwatch_observed=NO" | /usr/bin/tee -a "$LOG"
fi
if /usr/bin/grep -Fq 'kind=NEW_CONNECTION' "$LOG"; then
    echo "new_connection_observed=YES" | /usr/bin/tee -a "$LOG"
else
    echo "new_connection_observed=NO" | /usr/bin/tee -a "$LOG"
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_RESULT:PASSTHROUGH major=545 minor=0' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'kind=SERVER_VERSION' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x00007148 expectedReply=0x000071ac' "$LOG" &&
   /usr/bin/grep -Fq 'kind=SERVER_VERSION kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000071ac expected=0x000071ac idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REQUEST_WORDS:' "$LOG" &&
   /usr/bin/grep -Fq 'kind=NEW_CONNECTION' "$LOG" &&
   /usr/bin/grep -Fq 'kind=NEW_CONNECTION kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000074cd expected=0x000074cd idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x00007372 expectedReply=0x000073d6' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION bits=' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000073d6 expected=0x000073d6 idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION' "$LOG" &&
   /usr/bin/grep -Fq 'off20=0x00000000' "$LOG" &&
   ! /usr/bin/grep -Fq 'kind=CPS_CREATE_APPLICATION' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M07_BEFORE_GetProcessPID' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M08_AFTER_GetProcessPID' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetProcessPID=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_ROUNDTRIP:self=[0-9]+ returned=[0-9]+ match=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M09_BEFORE_TransformProcessType' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M10_AFTER_TransformProcessType' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:TransformProcessType=0' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:SetFrontProcess=0' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M13_SUCCESS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x0000729e expectedReply=0x00007302' "$LOG" &&
   /usr/bin/grep -Fq 'option=0x00000003 send=0x00000030 recv=0x0000002c' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x00007302 expected=0x00007302 idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY' "$LOG" &&
   /usr/bin/grep -Fq 'off20=0x00000000' "$LOG" &&
   ! /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LION' "$LOG" &&
   ! /usr/bin/grep -Fq '_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
