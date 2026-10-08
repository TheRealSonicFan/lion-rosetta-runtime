#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-postdispatch-getprocessforpid-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_INTERPOSER="${3:-$ROOT/payload/ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib}"
CORE_SHA_FILE="${4:-$CORE_INTERPOSER.sha256}"
SEC_INTERPOSER="${5:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
REPORT="${7:-$ROOT/payload/lion-ppc-process-manager-session-universe-init-adapter.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-session-universe-init-adapter.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
CARBONCORE="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
SECURITY="/System/Library/Frameworks/Security.framework/Versions/A/Security"
LAUNCHSERVICES="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
HISERVICES="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
LIBSYSTEM="/usr/lib/libSystem.B.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_CORE_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v4"
EXPECTED_SEC_BUILD_ID="security-session-auditinfo-api-v1"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() {
    code="$1"
    shift
    log "ERROR: $*"
    exit "$code"
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

log "== Lion PPC SCSessionUniverse InitConnection adapter experiment =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

for v in CORESERVICESD_SERVICE_NAME SCDontUseServer LSDONOTABORTIFNOASN ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$CARBONCORE" "$SECURITY" "$LAUNCHSERVICES" "$HISERVICES" "$LIBSYSTEM" "$EXE" "$EXE_SHA_FILE" "$CORE_INTERPOSER" "$CORE_SHA_FILE" "$SEC_INTERPOSER" "$SEC_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_CORE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"

KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
CARBONCORE_BEFORE="$(sha256 "$CARBONCORE")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
LAUNCHSERVICES_BEFORE="$(sha256 "$LAUNCHSERVICES")"
HISERVICES_BEFORE="$(sha256 "$HISERVICES")"
LIBSYSTEM_BEFORE="$(sha256 "$LIBSYSTEM")"
EXE_BEFORE="$(sha256 "$EXE")"
CORE_BEFORE="$(sha256 "$CORE_INTERPOSER")"
SEC_BEFORE="$(sha256 "$SEC_INTERPOSER")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "carboncore_sha256_before=$CARBONCORE_BEFORE"
log "security_sha256_before=$SECURITY_BEFORE"
log "launchservices_sha256_before=$LAUNCHSERVICES_BEFORE"
log "hiservices_sha256_before=$HISERVICES_BEFORE"
log "libsystem_sha256_before=$LIBSYSTEM_BEFORE"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"
log "expected_coreservices_interposer_sha256=$EXPECTED_CORE_SHA"
log "actual_coreservices_interposer_sha256=$CORE_BEFORE"
log "expected_security_interposer_sha256=$EXPECTED_SEC_SHA"
log "actual_security_interposer_sha256=$SEC_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "post-dispatch probe hash mismatch"
[ "$CORE_BEFORE" = "$EXPECTED_CORE_SHA" ] || die 68 "CoreServices interposer hash mismatch"
[ "$SEC_BEFORE" = "$EXPECTED_SEC_SHA" ] || die 68 "Security interposer hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

has_ppc32_arch "$EXE" || die 67 "post-dispatch probe is not 32-bit PPC"
has_ppc32_arch "$CORE_INTERPOSER" || die 67 "CoreServices interposer is not 32-bit PPC"
has_ppc32_arch "$SEC_INTERPOSER" || die 67 "Security interposer is not 32-bit PPC"

/usr/bin/strings "$CORE_INTERPOSER" | /usr/bin/grep -Fq     "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_BUILD_ID" || die 68 "CoreServices build marker missing"
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || die 68 "Security build marker missing"

for image in "$CARBONCORE" "$SECURITY" "$LAUNCHSERVICES" "$HISERVICES" "$LIBSYSTEM"; do
    /usr/bin/grep -Fq "$image" "$ROSETTA_CACHE_MAP" || die 68 "required image absent from Rosetta cache map: $image"
done

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

CORE_ABS="$(abspath "$CORE_INTERPOSER")"
SEC_ABS="$(abspath "$SEC_INTERPOSER")"
[ -n "$CORE_ABS" ] || die 68 "could not resolve CoreServices interposer path"
[ -n "$SEC_ABS" ] || die 68 "could not resolve Security interposer path"
INSERTED="$CORE_ABS:$SEC_ABS"
log "coreservices_interposer_absolute_path=$CORE_ABS"
log "security_interposer_absolute_path=$SEC_ABS"

MARKER="$(/usr/bin/mktemp /tmp/lion-pm-postdispatch-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC SESSION-UNIVERSE INIT ADAPTER RUN =="
log "+ ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 DYLD_INSERT_LIBRARIES=$INSERTED DYLD_SHARED_CACHE_DONT_VALIDATE=1 $EXE"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 DYLD_INSERT_LIBRARIES="$INSERTED" DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 "$EXE" > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "session_universe_init_adapter_exec_status=$RC"

/bin/sleep 3
log ""
log "== New diagnostics since test start =="
FOUND=0
if [ -d "$HOME/Library/Logs/DiagnosticReports" ]; then
    NEW="$(/usr/bin/find "$HOME/Library/Logs/DiagnosticReports" -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW" ]; then log "$NEW"; FOUND=1; fi
fi
if [ -d /cores ]; then
    NEW="$(/usr/bin/find /cores -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW" ]; then log "$NEW"; FOUND=1; fi
fi
[ "$FOUND" -eq 1 ] || log "none detected"
/bin/rm -f "$MARKER"

log ""
log "== Post-test integrity =="
[ "$(sha256 /mach_kernel)" = "$KERNEL_BEFORE" ] || die 70 "kernel changed"
[ "$(sha256 "$TRANSLATOR")" = "$TRANSLATOR_BEFORE" ] || die 70 "translator changed"
[ "$(sha256 "$PRIVATE_DYLD")" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$(sha256 "$SYSTEM_DYLD")" = "$SYSTEM_BEFORE" ] || die 70 "system dyld changed"
[ "$(sha256 "$ROSETTA_CACHE")" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$(sha256 "$CARBONCORE")" = "$CARBONCORE_BEFORE" ] || die 70 "CarbonCore changed"
[ "$(sha256 "$SECURITY")" = "$SECURITY_BEFORE" ] || die 70 "Security changed"
[ "$(sha256 "$LAUNCHSERVICES")" = "$LAUNCHSERVICES_BEFORE" ] || die 70 "LaunchServices changed"
[ "$(sha256 "$HISERVICES")" = "$HISERVICES_BEFORE" ] || die 70 "HIServices changed"
[ "$(sha256 "$LIBSYSTEM")" = "$LIBSYSTEM_BEFORE" ] || die 70 "libSystem changed"
[ "$(sha256 "$EXE")" = "$EXE_BEFORE" ] || die 70 "post-dispatch probe changed"
[ "$(sha256 "$CORE_INTERPOSER")" = "$CORE_BEFORE" ] || die 70 "CoreServices interposer changed"
[ "$(sha256 "$SEC_INTERPOSER")" = "$SEC_BEFORE" ] || die 70 "Security interposer changed"
log "protected_hashes_unchanged=YES"

if ! /usr/bin/grep -Fq 'PM_POSTDISPATCH_ENV:LSDONOTABORTIFNOASN=(unset)' "$RAW_LOG"; then
    log "RESULT: POSTDISPATCH_IDENTITY_ENVIRONMENT_FAILURE"; exit 1
fi
if ! /usr/bin/grep -Fq 'headerMatchesTextVMAddr=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'dispatchTextOffset=0x00018654' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'serverTextOffset=0x000186a8' "$RAW_LOG"; then
    log "RESULT: POSTDISPATCH_IDENTITY_OFFSET_FAILURE"; exit 1
fi
if ! /usr/bin/grep -Fq 'PM_POSTDISPATCH_PROLOGUE:expected=0x7c0802a6 setup=0x7c0802a6 dispatch=0x7c0802a6 server=0x7c0802a6' "$RAW_LOG"; then
    log "RESULT: POSTDISPATCH_IDENTITY_PROLOGUE_FAILURE"; exit 1
fi
if ! /usr/bin/grep -Eq 'PM_POSTDISPATCH_TABLE:pointer=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_POSTDISPATCH_SERVER_PORT:port=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$RAW_LOG"; then
    log "RESULT: POSTDISPATCH_IDENTITY_SETUP_REGRESSION"; exit 1
fi
if ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:LOOKUP_PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
    log "RESULT: POSTDISPATCH_IDENTITY_COMPAT_REGRESSION"; exit 1
fi

if ! /usr/bin/grep -Eq 'PM_CORESERVICES_COMPAT_SESSION_PORT:source=adapter port=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_SESSION_PORT_CAPTURE_FAILURE"; exit 1
fi

if ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=1 mode=lion-dual-sessioninit-adapter' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_LEGACY_REQUEST_NOT_OBSERVED"; exit 1
fi

if ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REQUEST:id=0x00002712 legacySend=0x0000002c adaptedSend=0x00000028 recv=0x00000034' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_REQUEST_ADAPTATION_FAILURE"; exit 1
fi

if ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_MACH_MSG:kr=0 hex=0x00000000' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_MACH_MSG_FAILURE"; exit 1
fi

if ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REPLY:size=0x0000002c id=0x00002776 retcodeRaw=0x00000000' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_SERVER_REJECTED_OR_REPLY_UNEXPECTED"; exit 1
fi

if /usr/bin/grep -Fq 'PM_POSTDISPATCH_MILESTONE:M05_BEFORE_GetProcessForPID' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID' "$RAW_LOG"; then
    if [ "$RC" -eq 134 ]; then
        log "RESULT: SESSIONINIT_ADAPTER_PASS_THEN_SIGABRT_BEFORE_GETPROCESSFORPID_RETURN"
    else
        log "RESULT: SESSIONINIT_ADAPTER_PASS_THEN_TERMINATED_BEFORE_GETPROCESSFORPID_RETURN exit_status=$RC"
    fi
    [ "$RC" -ne 0 ] && exit "$RC"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTDISPATCH_STATUS:GetProcessForPID=0' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_ADAPTER_PASS_GETPROCESSFORPID_RETURNED_ERROR"
    [ "$RC" -ne 0 ] && exit "$RC"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_POSTDISPATCH_STATUS:GetProcessForPID=0' "$RAW_LOG" &&
   ! /usr/bin/grep -Eq 'PM_POSTDISPATCH_PSN:high=0x[0-9a-fA-F]{8} low=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_ADAPTER_PASS_GETPROCESSFORPID_ZERO_PSN"
    [ "$RC" -ne 0 ] && exit "$RC"
    exit 1
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_POSTDISPATCH_STATUS:GetProcessForPID=0' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_POSTDISPATCH_PSN:high=0x[0-9a-fA-F]{8} low=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_POSTDISPATCH_MILESTONE:M07_SUCCESS' "$RAW_LOG"; then
    log "RESULT: SESSIONINIT_ADAPTER_GETPROCESSFORPID_PASS"
    exit 0
fi

log "RESULT: SESSIONINIT_ADAPTER_UNCLASSIFIED_FAILURE"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
