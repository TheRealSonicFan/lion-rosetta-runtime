#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-security-session-bootstrap-compat-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
INTERPOSER="${3:-$ROOT/payload/ppc-process-manager-security-session-bootstrap-compat.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
REPORT="${5:-$ROOT/payload/lion-ppc-process-manager-security-session-bootstrap-compat.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-security-session-bootstrap-compat.raw.log"

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
EXPECTED_BUILD_ID="security-session-bootstrap-compat-v1"
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

log "== Lion PPC Security session bootstrap compatibility integration =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${SECURITYSERVER+x}" ] || die 68 "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset before the runner"
[ -z "${ROSETTA_SECURITY_SESSION_COMPAT_MODE+x}" ] || die 68 "ROSETTA_SECURITY_SESSION_COMPAT_MODE must be unset before the runner"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 kernel hash"
for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$SECURITY" "$SECURITYD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$EXE" "$EXE_SHA_FILE" "$INTERPOSER" "$INTERPOSER_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"

KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
SECURITYD_BEFORE="$(sha256 "$SECURITYD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
EXE_BEFORE="$(sha256 "$EXE")"
INTERPOSER_BEFORE="$(sha256 "$INTERPOSER")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "security_sha256_before=$SECURITY_BEFORE"
log "securityd_sha256_before=$SECURITYD_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"
log "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA"
log "actual_interposer_sha256=$INTERPOSER_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ -n "$EXPECTED_EXE_SHA" ] || die 68 "could not read expected executable SHA-256"
[ -n "$EXPECTED_INTERPOSER_SHA" ] || die 68 "could not read expected interposer SHA-256"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "probe hash mismatch"
[ "$INTERPOSER_BEFORE" = "$EXPECTED_INTERPOSER_SHA" ] || die 68 "interposer hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

/usr/bin/grep -Fq "$SECURITY" "$ROSETTA_CACHE_MAP" || die 68 "Security is absent from the validated Rosetta cache map"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     "PM_SECURITY_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || die 68 "interposer build marker missing"

INTERPOSER_ABS="$(abspath "$INTERPOSER")"
[ -n "$INTERPOSER_ABS" ] || die 68 "could not resolve interposer absolute path"
log "interposer_absolute_path=$INTERPOSER_ABS"

MARKER="$(/usr/bin/mktemp /tmp/lion-security-bootstrap-compat-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with normal crash reporting"
fi

log ""
log "== SINGLE PPC SECURITY SESSION RUN WITH SECURITYSERVER BOOTSTRAP ADAPTER =="
log "+ ROSETTA_SECURITY_SESSION_COMPAT_MODE=lion-bootstrap-v1 DYLD_INSERT_LIBRARIES=$INTERPOSER_ABS DYLD_SHARED_CACHE_DONT_VALIDATE=1 $EXE"
ROSETTA_SECURITY_SESSION_COMPAT_MODE=lion-bootstrap-v1 DYLD_INSERT_LIBRARIES="$INTERPOSER_ABS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1     "$EXE" > "$RAW_LOG" 2>&1
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
SYSTEM_AFTER="$(sha256 "$SYSTEM_DYLD")"
SECURITY_AFTER="$(sha256 "$SECURITY")"
SECURITYD_AFTER="$(sha256 "$SECURITYD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
EXE_AFTER="$(sha256 "$EXE")"
INTERPOSER_AFTER="$(sha256 "$INTERPOSER")"

log "mach_kernel_sha256_after=$KERNEL_AFTER"
log "translator_sha256_after=$TRANSLATOR_AFTER"
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "system_dyld_sha256_after=$SYSTEM_AFTER"
log "security_sha256_after=$SECURITY_AFTER"
log "securityd_sha256_after=$SECURITYD_AFTER"
log "rosetta_cache_sha256_after=$CACHE_AFTER"
log "probe_sha256_after=$EXE_AFTER"
log "interposer_sha256_after=$INTERPOSER_AFTER"

[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || die 70 "kernel changed"
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || die 70 "translator changed"
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || die 70 "system dyld changed"
[ "$SECURITY_AFTER" = "$SECURITY_BEFORE" ] || die 70 "Security changed"
[ "$SECURITYD_AFTER" = "$SECURITYD_BEFORE" ] || die 70 "securityd changed"
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$EXE_AFTER" = "$EXPECTED_EXE_SHA" ] || die 70 "probe changed"
[ "$INTERPOSER_AFTER" = "$EXPECTED_INTERPOSER_SHA" ] || die 70 "interposer changed"

log ""
if ! /usr/bin/grep -Fq "dyld: loaded: $INTERPOSER_ABS" "$RAW_LOG"; then
    log "RESULT: SECURITY_COMPAT_INTERPOSER_NOT_LOADED"
    exit 1
fi
if ! /usr/bin/grep -Fq "PM_SECURITY_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" "$RAW_LOG"; then
    log "RESULT: SECURITY_COMPAT_STALE_INTERPOSER"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_RESULT:PASS' "$RAW_LOG"; then
    log "RESULT: SECURITY_BOOTSTRAP_ADAPTER_DID_NOT_PASS"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_SECURITY_SESSION_MILESTONE:M01_BEFORE_SessionGetInfo' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_PRE_CALL_FAILURE"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_SECURITY_SESSION_MILESTONE:M02_AFTER_SessionGetInfo' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_ABORT_OR_CRASH"
    exit 1
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=0' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_RESULT:PASS' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_AFTER_BOOTSTRAP_PASS"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=1' "$RAW_LOG"; then
    log "RESULT: SECURITY_SESSION_AFTER_BOOTSTRAP_STATUS1_TRACE_CAPTURED"
    exit 0
fi

log "RESULT: SECURITY_SESSION_AFTER_BOOTSTRAP_UNCLASSIFIED"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
