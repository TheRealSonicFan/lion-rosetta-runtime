#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-launchservices-dispatch-setup-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_INTERPOSER="${3:-$ROOT/payload/ppc-process-manager-coreservices-compat-interposer.dylib}"
CORE_SHA_FILE="${4:-$CORE_INTERPOSER.sha256}"
SEC_INTERPOSER="${5:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
REPORT="${7:-$ROOT/payload/lion-ppc-process-manager-launchservices-dispatch-setup.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-launchservices-dispatch-setup.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
CARBONCORE="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
SECURITY="/System/Library/Frameworks/Security.framework/Versions/A/Security"
LAUNCHSERVICES="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
LIBSYSTEM="/usr/lib/libSystem.B.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_CORE_BUILD_ID="dual-bootstrap-servercheckin-v3"
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

log "== Lion PPC LaunchServices process-dispatch setup probe =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

for v in CORESERVICESD_SERVICE_NAME SCDontUseServer ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$CARBONCORE" "$SECURITY" "$LAUNCHSERVICES" "$LIBSYSTEM" "$EXE" "$EXE_SHA_FILE" "$CORE_INTERPOSER" "$CORE_SHA_FILE" "$SEC_INTERPOSER" "$SEC_SHA_FILE"; do
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
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "dispatch setup probe hash mismatch"
[ "$CORE_BEFORE" = "$EXPECTED_CORE_SHA" ] || die 68 "CoreServices interposer hash mismatch"
[ "$SEC_BEFORE" = "$EXPECTED_SEC_SHA" ] || die 68 "Security interposer hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

has_ppc32_arch "$EXE" || die 67 "dispatch setup probe is not 32-bit PPC"
has_ppc32_arch "$CORE_INTERPOSER" || die 67 "CoreServices interposer is not 32-bit PPC"
has_ppc32_arch "$SEC_INTERPOSER" || die 67 "Security interposer is not 32-bit PPC"

/usr/bin/strings "$CORE_INTERPOSER" | /usr/bin/grep -Fq     "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_BUILD_ID" || die 68 "CoreServices build marker missing"
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || die 68 "Security build marker missing"

for image in "$CARBONCORE" "$SECURITY" "$LAUNCHSERVICES" "$LIBSYSTEM"; do
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

MARKER="$(/usr/bin/mktemp /tmp/lion-ls-dispatch-setup-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC LAUNCHSERVICES DISPATCH SETUP RUN =="
log "+ ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 DYLD_INSERT_LIBRARIES=$INSERTED DYLD_SHARED_CACHE_DONT_VALIDATE=1 $EXE"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 DYLD_INSERT_LIBRARIES="$INSERTED" DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 "$EXE" > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "launchservices_dispatch_setup_exec_status=$RC"

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
[ "$(sha256 "$LIBSYSTEM")" = "$LIBSYSTEM_BEFORE" ] || die 70 "libSystem changed"
[ "$(sha256 "$EXE")" = "$EXE_BEFORE" ] || die 70 "dispatch setup probe changed"
[ "$(sha256 "$CORE_INTERPOSER")" = "$CORE_BEFORE" ] || die 70 "CoreServices interposer changed"
[ "$(sha256 "$SEC_INTERPOSER")" = "$SEC_BEFORE" ] || die 70 "Security interposer changed"
log "protected_hashes_unchanged=YES"

if ! /usr/bin/grep -Fq 'PM_LS_DISPATCH_IMAGE:' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_IMAGE_FAILURE"; exit 1
fi
if ! /usr/bin/grep -Fq 'dispatchNValue=0x00018654' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'serverNValue=0x000186a8' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_OFFSET_FAILURE"; exit 1
fi
if /usr/bin/grep -Fq 'PM_LS_DISPATCH_MILESTONE:M01_BEFORE_getProcessDispatchTable' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_LS_DISPATCH_MILESTONE:M02_AFTER_getProcessDispatchTable' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_ABORT_BEFORE_RETURN"; exit 1
fi
if ! /usr/bin/grep -Fq 'PM_LS_DISPATCH_MILESTONE:M02_AFTER_getProcessDispatchTable' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_NO_RETURN"; exit 1
fi
if ! /usr/bin/grep -Eq 'PM_LS_DISPATCH_TABLE:pointer=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_TABLE_NULL"; exit 1
fi
if ! /usr/bin/grep -Fq 'PM_LS_DISPATCH_MILESTONE:M04_AFTER_getProcessesServerPort' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_SERVER_PORT_NO_RETURN"; exit 1
fi
if ! /usr/bin/grep -Eq 'PM_LS_DISPATCH_SERVER_PORT:port=0x0*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_SERVER_PORT_NULL"; exit 1
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:LOOKUP_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_LS_DISPATCH_RESULT:DISPATCH_SETUP_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_LS_DISPATCH_MILESTONE:M05_SUCCESS' "$RAW_LOG"; then
    log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_PASS"
    exit 0
fi

log "RESULT: LAUNCHSERVICES_DISPATCH_SETUP_UNCLASSIFIED_FAILURE"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
