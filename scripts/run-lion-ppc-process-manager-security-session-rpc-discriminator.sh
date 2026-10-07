#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-security-session-rpc-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
TRACE="${3:-$ROOT/payload/ppc-process-manager-security-session-rpc-trace.dylib}"
TRACE_SHA_FILE="${4:-$TRACE.sha256}"
REPORT="${5:-$ROOT/payload/lion-ppc-process-manager-security-session-rpc-discriminator.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-security-session-rpc-discriminator.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
SECURITY="/System/Library/Frameworks/Security.framework/Versions/A/Security"
SECURITYD="/usr/sbin/securityd"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_TRACE_BUILD_ID="security-session-rpc-trace-v1"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() {
    code="$1"
    shift
    log "ERROR: $*"
    log "Preflight stopped; preserve the report before changing anything."
    exit "$code"
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

abspath() {
    file="$1"
    dir="$(/usr/bin/dirname "$file")"
    base="$(/usr/bin/basename "$file")"
    (cd "$dir" 2>/dev/null && echo "$(pwd)/$base")
}

log "== Lion PPC Security session RPC discriminator =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${SECURITYSERVER+x}" ] || die 68 "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset before the runner"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 kernel hash"
[ -f /mach_kernel ] || die 66 "missing /mach_kernel"
[ -x "$TRANSLATOR" ] || die 66 "missing translator"
[ -f "$PRIVATE_DYLD" ] || die 66 "missing private dyld"
[ -f "$SYSTEM_DYLD" ] || die 66 "missing system dyld"
[ -f "$SECURITY" ] || die 66 "missing Security framework"
[ -x "$SECURITYD" ] || die 66 "missing securityd"
[ -f "$ROSETTA_CACHE" ] || die 66 "missing Rosetta cache"
[ -f "$ROSETTA_CACHE_MAP" ] || die 66 "missing Rosetta cache map"
[ -x "$EXE" ] || die 66 "missing or non-executable PPC Security probe: $EXE"
[ -f "$EXE_SHA_FILE" ] || die 66 "missing probe SHA-256 sidecar: $EXE_SHA_FILE"
[ -f "$TRACE" ] || die 66 "missing PPC Security RPC tracer: $TRACE"
[ -f "$TRACE_SHA_FILE" ] || die 66 "missing tracer SHA-256 sidecar: $TRACE_SHA_FILE"

KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_DYLD_BEFORE="$(sha256 "$SYSTEM_DYLD")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
SECURITYD_BEFORE="$(sha256 "$SECURITYD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"
EXE_BEFORE="$(sha256 "$EXE")"
TRACE_BEFORE="$(sha256 "$TRACE")"

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_TRACE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$TRACE_SHA_FILE")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_DYLD_BEFORE"
log "security_sha256_before=$SECURITY_BEFORE"
log "securityd_sha256_before=$SECURITYD_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_BEFORE"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"
log "expected_tracer_sha256=$EXPECTED_TRACE_SHA"
log "actual_tracer_sha256=$TRACE_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_BEFORE" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ -n "$EXPECTED_EXE_SHA" ] || die 68 "could not read expected executable SHA-256"
[ -n "$EXPECTED_TRACE_SHA" ] || die 68 "could not read expected tracer SHA-256"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "probe hash mismatch"
[ "$TRACE_BEFORE" = "$EXPECTED_TRACE_SHA" ] || die 68 "tracer hash mismatch"

/usr/bin/grep -Fq "$SECURITY" "$ROSETTA_CACHE_MAP" || die 68 "Security is absent from the validated Rosetta cache map"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

/usr/bin/file "$EXE" 2>&1 | /usr/bin/tee -a "$REPORT"
/usr/bin/file "$TRACE" 2>&1 | /usr/bin/tee -a "$REPORT"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/strings "$TRACE" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_TRACE_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" || die 68 "tracer build marker is missing"

TRACE_ABS="$(abspath "$TRACE")"
[ -n "$TRACE_ABS" ] || die 68 "could not resolve tracer absolute path"
log "tracer_absolute_path=$TRACE_ABS"

MARKER="$(/usr/bin/mktemp /tmp/lion-security-session-rpc-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with normal crash reporting"
fi

log ""
log "== SINGLE PPC SECURITY SESSION RPC DISCRIMINATOR =="
log "+ DYLD_INSERT_LIBRARIES=$TRACE_ABS DYLD_SHARED_CACHE_DONT_VALIDATE=1 $EXE"
DYLD_INSERT_LIBRARIES="$TRACE_ABS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1     "$EXE" > "$RAW_LOG" 2>&1
RC=$?
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "security_session_exec_status=$RC"

/bin/sleep 3
log ""
log "== New diagnostics since test start =="
FOUND_DIAG=0
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [ -d "$CRASH_DIR" ]; then
    NEW_CRASH="$(/usr/bin/find "$CRASH_DIR" -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CRASH" ]; then log "$NEW_CRASH"; FOUND_DIAG=1; fi
fi
if [ -d /cores ]; then
    NEW_CORES="$(/usr/bin/find /cores -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CORES" ]; then log "$NEW_CORES"; FOUND_DIAG=1; fi
fi
[ "$FOUND_DIAG" -eq 1 ] || log "none detected"
/bin/rm -f "$MARKER"

log ""
log "== Post-test integrity =="
KERNEL_AFTER="$(sha256 /mach_kernel)"
TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"
PRIVATE_AFTER="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_DYLD_AFTER="$(sha256 "$SYSTEM_DYLD")"
SECURITY_AFTER="$(sha256 "$SECURITY")"
SECURITYD_AFTER="$(sha256 "$SECURITYD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
EXE_AFTER="$(sha256 "$EXE")"
TRACE_AFTER="$(sha256 "$TRACE")"

log "mach_kernel_sha256_after=$KERNEL_AFTER"
log "translator_sha256_after=$TRANSLATOR_AFTER"
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "system_dyld_sha256_after=$SYSTEM_DYLD_AFTER"
log "security_sha256_after=$SECURITY_AFTER"
log "securityd_sha256_after=$SECURITYD_AFTER"
log "rosetta_cache_sha256_after=$CACHE_AFTER"
log "probe_sha256_after=$EXE_AFTER"
log "tracer_sha256_after=$TRACE_AFTER"

[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || die 70 "kernel changed"
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || die 70 "translator changed"
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$SYSTEM_DYLD_AFTER" = "$SYSTEM_DYLD_BEFORE" ] || die 70 "system dyld changed"
[ "$SECURITY_AFTER" = "$SECURITY_BEFORE" ] || die 70 "Security framework changed"
[ "$SECURITYD_AFTER" = "$SECURITYD_BEFORE" ] || die 70 "securityd changed"
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$EXE_AFTER" = "$EXPECTED_EXE_SHA" ] || die 70 "probe changed"
[ "$TRACE_AFTER" = "$EXPECTED_TRACE_SHA" ] || die 70 "tracer changed"

log ""
if ! /usr/bin/grep -Fq "dyld: loaded: $TRACE_ABS" "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_TRACER_NOT_LOADED"
    exit 1
fi
if ! /usr/bin/grep -Fq "PM_SECURITY_SESSION_TRACE_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_STALE_TRACER"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_SECURITY_SESSION_MILESTONE:M01_BEFORE_SessionGetInfo' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_PRE_CALL_FAILURE"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REQUEST:' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_BOOTSTRAP_NOT_OBSERVED"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_SESSION_MILESTONE:M01_BEFORE_SessionGetInfo' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_SECURITY_SESSION_MILESTONE:M02_AFTER_SessionGetInfo' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_ABORT_OR_CRASH"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=1' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_STATUS1_RPC_TRACE_CAPTURED"
    exit 0
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=0' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_RESULT:PASS' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_UNEXPECTED_PASS"
    exit 0
fi

log "RESULT: SECURITY_SESSION_RPC_TRACE_UNCLASSIFIED"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
