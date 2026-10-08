#!/bin/bash
set -u

EXE="${1:-./ppc-process-manager-cps-connection-discriminator-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_INTERPOSER="${3:-./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib}"
CORE_SHA_FILE="${4:-$CORE_INTERPOSER.sha256}"
SEC_INTERPOSER="${5:-./ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
LOG="${7:-./ppc-process-manager-cps-connection-discriminator-snowleopard-control.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_CORE_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5"
EXPECTED_SEC_BUILD_ID="security-session-auditinfo-api-v1"

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
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$LOG"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

for v in CORESERVICESD_SERVICE_NAME SCDontUseServer LSDONOTABORTIFNOASN ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || fail "$v must be unset before the runner"
done

for p in "$EXE" "$EXE_SHA_FILE" "$CORE_INTERPOSER" "$CORE_SHA_FILE" "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$PRIVATE_DYLD"; do
    [ -e "$p" ] || fail "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_CORE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"

[ "$(sha256 "$EXE")" = "$EXPECTED_EXE_SHA" ] || fail "probe hash mismatch"
[ "$(sha256 "$CORE_INTERPOSER")" = "$EXPECTED_CORE_SHA" ] || fail "CoreServices interposer hash mismatch"
[ "$(sha256 "$SEC_INTERPOSER")" = "$EXPECTED_SEC_SHA" ] || fail "Security interposer hash mismatch"
[ "$(sha256 "$PRIVATE_DYLD")" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/strings "$CORE_INTERPOSER" | /usr/bin/grep -Fq     "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_BUILD_ID" || fail "CoreServices build marker missing"
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || fail "Security build marker missing"

CORE_ABS="$(abspath "$CORE_INTERPOSER")"
SEC_ABS="$(abspath "$SEC_INTERPOSER")"
[ -n "$CORE_ABS" ] || fail "could not resolve CoreServices interposer path"
[ -n "$SEC_ABS" ] || fail "could not resolve Security interposer path"
INSERTED="$CORE_ABS:$SEC_ABS"

echo "executable_sha256=$EXPECTED_EXE_SHA" | /usr/bin/tee -a "$LOG"
echo "coreservices_interposer_sha256=$EXPECTED_CORE_SHA" | /usr/bin/tee -a "$LOG"
echo "security_interposer_sha256=$EXPECTED_SEC_SHA" | /usr/bin/tee -a "$LOG"
echo "private_dyld_sha256=$EXPECTED_DYLD_SHA" | /usr/bin/tee -a "$LOG"

echo "== Snow Leopard CPS connection-state discriminator control ==" | /usr/bin/tee -a "$LOG"

ROSETTA_CORESERVICES_COMPAT_MODE=passthrough ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=passthrough DYLD_INSERT_LIBRARIES="$INSERTED" DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 "$EXE" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_ENV:LSDONOTABORTIFNOASN=(unset)' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_LAYOUT:' "$LOG" &&
   /usr/bin/grep -Fq 'headerMatchesTextVMAddr=YES' "$LOG" &&
   /usr/bin/grep -Fq 'dispatchTextOffset=0x00018654' "$LOG" &&
   /usr/bin/grep -Fq 'serverTextOffset=0x000186a8' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_PROLOGUE:expected=0x7c0802a6 setup=0x7c0802a6 dispatch=0x7c0802a6 server=0x7c0802a6' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Eq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_REPLY_PORT:source=passthrough port=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=2' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_ROUTE:' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_PASSTHROUGH_RETURN:kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_CALL:index=1 mode=passthrough requested=0xffffffff targetCaller=YES' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_TABLE:pointer=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_SERVER_PORT:port=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M05_BEFORE_GetProcessForPID' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M06_AFTER_GetProcessForPID' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetProcessForPID=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_PSN:high=0x[0-9a-fA-F]{8} low=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
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
   /usr/bin/grep -Eq 'PM_CPS_IMAGE:.*headerMatchesTextVMAddr=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_PROLOGUE:expected=0x7c0802a6 actual=0x7c0802a6' "$LOG" &&
   /usr/bin/grep -Fq 'cpsWithOptionsOffset=0x001fcfdc' "$LOG" &&
   /usr/bin/grep -Fq 'cpsSetFrontOffset=0x001fd0cc' "$LOG" &&
   /usr/bin/grep -Fq 'connectionSlotOffset=0x007007c8' "$LOG" &&
   /usr/bin/grep -Eq 'PM_CPS_CONNECTION_STATE:phase=posttransform slot=0x[0-9a-fA-F]{8} pointer=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_DISCRIMINATOR_MILESTONE:M11_BEFORE_CPSSetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_DISCRIMINATOR_MILESTONE:M12_AFTER_CPSSetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_DISCRIMINATOR_STATUS:CPSSetFrontProcess=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_ZERO' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_DISCRIMINATOR_MILESTONE:M13_SUCCESS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
