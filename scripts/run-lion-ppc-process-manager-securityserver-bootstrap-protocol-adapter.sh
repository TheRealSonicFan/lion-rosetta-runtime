#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-securityserver-bootstrap-protocol-adapter-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
REPORT="${3:-$ROOT/payload/lion-ppc-process-manager-securityserver-bootstrap-protocol-adapter.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-securityserver-bootstrap-protocol-adapter.raw.log"
MARKER=""

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
SECURITYD="/usr/sbin/securityd"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
LIBSYSTEM_PATH="/usr/lib/libSystem.B.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73

log() {
    echo "$*" | /usr/bin/tee -a "$REPORT"
}

die() {
    code="$1"
    shift
    log "ERROR: $*"
    log "Preflight stopped; preserve the report before changing anything."
    exit "$code"
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

has_ppc32_arch() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

log "== Lion PPC SecurityServer bootstrap protocol adapter =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${SECURITYSERVER+x}" ] || die 68 "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset"
log "SECURITYSERVER=UNSET"
log "DYLD_INSERT_LIBRARIES=UNSET_IN_PARENT"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 kernel hash"
[ -f /mach_kernel ] || die 66 "missing /mach_kernel"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

[ -x "$TRANSLATOR" ] || die 66 "missing translator"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"

[ -x "$EXE" ] || die 66 "missing or non-executable PPC SecurityServer bootstrap adapter probe: $EXE"
[ -f "$SHA_FILE" ] || die 66 "missing executable SHA-256 sidecar: $SHA_FILE"
EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
[ -n "$EXPECTED_EXE_SHA" ] || die 68 "could not read expected executable SHA-256"
EXE_BEFORE="$(sha256 "$EXE")"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "adapter probe hash mismatch"

/usr/bin/file "$EXE" 2>&1 | /usr/bin/tee -a "$REPORT"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" 2>&1 | /usr/bin/tee -a "$REPORT" || true
fi
has_ppc32_arch "$EXE" || die 67 "probe is not a 32-bit PowerPC Mach-O"

OTOOL_OUT="$(/usr/bin/otool -l "$EXE" 2>&1 | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OTOOL_OUT" | /usr/bin/tee -a "$REPORT"
echo "$OTOOL_OUT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/otool -L "$EXE" 2>&1 | /usr/bin/tee -a "$REPORT"

[ -f "$PRIVATE_DYLD" ] || die 66 "missing private dyld"
[ -f "$SYSTEM_DYLD" ] || die 66 "missing Lion system dyld"
[ -x "$SECURITYD" ] || die 66 "missing securityd"
[ -f "$ROSETTA_CACHE" ] || die 66 "missing Rosetta cache"
[ -f "$ROSETTA_CACHE_MAP" ] || die 66 "missing Rosetta cache map"

PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
SECURITYD_BEFORE="$(sha256 "$SECURITYD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "lion_system_dyld_sha256_before=$SYSTEM_BEFORE"
log "securityd_sha256_before=$SECURITYD_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"

/usr/bin/grep -Fq "$LIBSYSTEM_PATH" "$ROSETTA_CACHE_MAP" || die 68 "libSystem is absent from the validated Rosetta cache map"
log "rosetta_cache_contains_libsystem=YES"

log ""
log "== SecurityServer service state before test =="
/bin/launchctl list 2>&1 | /usr/bin/grep -i 'securityd\|SecurityServer' | /usr/bin/tee -a "$REPORT" || log "(no matching active job; launchd on-demand activation remains possible)"

if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with normal crash reporting"
fi
MARKER="$(/usr/bin/mktemp /tmp/lion-security-bootstrap-adapter-marker.XXXXXX)" || die 73 "could not create diagnostic marker"

log ""
log "== SINGLE PPC LION-FORMAT SECURITYSERVER BOOTSTRAP TEST =="
log "+ DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 $EXE lion-adapter"
DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1     "$EXE" lion-adapter > "$RAW_LOG" 2>&1
RC=$?
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "security_bootstrap_adapter_exec_status=$RC"

/bin/sleep 3

log ""
log "== New diagnostics since test start =="
FOUND_DIAG=0
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [ -d "$CRASH_DIR" ]; then
    NEW_CRASH="$(/usr/bin/find "$CRASH_DIR" -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CRASH" ]; then
        log "$NEW_CRASH"
        FOUND_DIAG=1
    fi
fi
if [ -d /cores ]; then
    NEW_CORES="$(/usr/bin/find /cores -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CORES" ]; then
        log "$NEW_CORES"
        FOUND_DIAG=1
    fi
fi
[ "$FOUND_DIAG" -eq 1 ] || log "none detected"
/bin/rm -f "$MARKER"

log ""
log "== Post-test integrity =="
PRIVATE_AFTER="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_AFTER="$(sha256 "$SYSTEM_DYLD")"
KERNEL_AFTER="$(sha256 /mach_kernel)"
TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"
SECURITYD_AFTER="$(sha256 "$SECURITYD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
EXE_AFTER="$(sha256 "$EXE")"
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "lion_system_dyld_sha256_after=$SYSTEM_AFTER"
log "mach_kernel_sha256_after=$KERNEL_AFTER"
log "translator_sha256_after=$TRANSLATOR_AFTER"
log "securityd_sha256_after=$SECURITYD_AFTER"
log "rosetta_cache_sha256_after=$CACHE_AFTER"
log "probe_sha256_after=$EXE_AFTER"
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || die 70 "Lion native dyld changed"
[ "$KERNEL_AFTER" = "$EXPECTED_KERNEL_SHA" ] || die 70 "kernel changed"
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || die 70 "translator changed"
[ "$SECURITYD_AFTER" = "$SECURITYD_BEFORE" ] || die 70 "securityd changed"
[ "$CACHE_AFTER" = "$EXPECTED_CACHE_SHA" ] || die 70 "Rosetta cache changed"
[ "$EXE_AFTER" = "$EXPECTED_EXE_SHA" ] || die 70 "probe executable changed"

log ""
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:ENVIRONMENT_NOT_CLEAN' "$RAW_LOG"; then
    log "RESULT: ENVIRONMENT_NOT_CLEAN"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:BOOTSTRAP_PORT_NULL' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_PORT_NULL"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:REPLY_PORT_NULL' "$RAW_LOG"; then
    log "RESULT: REPLY_PORT_NULL"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:LAYOUT_BUILD_FAILED' "$RAW_LOG"; then
    log "RESULT: LAYOUT_BUILD_FAILED"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_MILESTONE:L00_BEFORE_LION_FORMAT_MACH_MSG' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_MILESTONE:L01_AFTER_LION_FORMAT_MACH_MSG' "$RAW_LOG"; then
    log "RESULT: ADAPTER_ABORT_OR_CRASH"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:MACH_MSG_ERROR' "$RAW_LOG"; then
    log "RESULT: ADAPTER_MACH_MSG_ERROR"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_MIG_BAD_ARGUMENTS' "$RAW_LOG"; then
    log "RESULT: ADAPTER_MIG_BAD_ARGUMENTS"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_SERVER_ERROR' "$RAW_LOG"; then
    log "RESULT: ADAPTER_SERVER_ERROR"
    exit 1
fi
if /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_ZERO_PORT' "$RAW_LOG"; then
    log "RESULT: ADAPTER_ZERO_PORT"
    exit 1
fi
if /usr/bin/grep -Eq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:(REPLY_ID_MISMATCH|COMPLEX_REPLY_SHAPE_ERROR|REPLY_SHAPE_ERROR)' "$RAW_LOG"; then
    log "RESULT: ADAPTER_REPLY_SHAPE_ERROR"
    exit 1
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_LAYOUT:PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_BOOTSTRAP_ADAPTER_RESULT:ADAPTER_LOOKUP_PASS' "$RAW_LOG"; then
    log "RESULT: SECURITYSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS"
    exit 0
fi

log "RESULT: PRE_MAIN_OR_UNCLASSIFIED_FAILURE"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
