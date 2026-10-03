#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-smoketest-private-dyld}"
REPORT="${2:-$ROOT/payload/lion-normal-ppc-exec-experiment.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-normal-ppc-exec.raw.log"
MARKER=""

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_EXE_SHA="b34e7c4b1ffe9750ae866c4a1e2d732e5dd90aa44c3f79d15359d58076987b0a"
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
    log "Experiment stopped; preserve the report before changing anything."
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

log "== Lion normal PPC exec experiment =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "this experiment requires Lion 10.7.5 (found $PRODUCT_VERSION)"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 experiment kernel hash"
[ -f /mach_kernel ] || die 66 "missing /mach_kernel"
KERNEL_SHA="$(sha256 /mach_kernel)"
log "mach_kernel_sha256=$KERNEL_SHA"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
[ "$KERNEL_SHA" = "$EXPECTED_KERNEL_SHA" ] || die 68 "running /mach_kernel hash does not match the validated experiment kernel"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC architecture handler is not $TRANSLATOR"

[ -x "$TRANSLATOR" ] || die 66 "missing translator: $TRANSLATOR"
TRANSLATOR_SHA="$(sha256 "$TRANSLATOR")"
log "translator_sha256=$TRANSLATOR_SHA"
[ "$TRANSLATOR_SHA" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"

[ -f "$EXE" ] || die 66 "missing PPC executable: $EXE"
run_desc="$(/usr/bin/file "$EXE" 2>&1)"
log "$run_desc"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" 2>&1 | /usr/bin/tee -a "$REPORT" || true
fi
has_ppc32_arch "$EXE" || die 67 "experimental executable is not a 32-bit PowerPC Mach-O"
EXE_SHA="$(sha256 "$EXE")"
log "experimental_executable_sha256=$EXE_SHA"
[ "$EXE_SHA" = "$EXPECTED_EXE_SHA" ] || die 68 "experimental executable hash mismatch"

if [ -x /usr/bin/otool ]; then
    OTOOL_OUT="$(/usr/bin/otool -l "$EXE" 2>&1 | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
    echo "$OTOOL_OUT" | /usr/bin/tee -a "$REPORT"
    echo "$OTOOL_OUT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"
fi

[ -f "$PRIVATE_DYLD" ] || die 66 "missing staged private dyld: $PRIVATE_DYLD"
[ ! -L "$PRIVATE_DYLD" ] || die 69 "$PRIVATE_DYLD is a symbolic link"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"

[ -f "$ROSETTA_CACHE" ] || die 66 "missing Rosetta cache"
[ -f "$ROSETTA_CACHE_MAP" ] || die 66 "missing Rosetta cache map"
CACHE_SHA="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
log "rosetta_cache_sha256=$CACHE_SHA"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
[ "$CACHE_SHA" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"

SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
log "lion_system_dyld_sha256_before=$SYSTEM_BEFORE"

if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with normal crash reporting"
fi
MARKER="$(/usr/bin/mktemp /tmp/lion-normal-ppc-exec-marker.XXXXXX)" || die 73 "could not create diagnostic marker"

log ""
log "== NORMAL PPC EXEC TEST =="
log "+ DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 $EXE"
DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1     "$EXE" > "$RAW_LOG" 2>&1
RC=$?
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "normal_ppc_exec_status=$RC"

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
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "lion_system_dyld_sha256_after=$SYSTEM_AFTER"
log "mach_kernel_sha256_after=$KERNEL_AFTER"
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed during the test"
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || die 70 "Lion native /usr/lib/dyld changed during the test"
[ "$KERNEL_AFTER" = "$EXPECTED_KERNEL_SHA" ] || die 70 "/mach_kernel changed during the test"

log ""
if [ "$RC" -eq 0 ] && /usr/bin/grep -Fq 'Rosetta PPC smoke test: pid=' "$RAW_LOG"; then
    log "RESULT: PASS"
    log "Normal PowerPC exec reached the PPC smoke test and exited 0."
    log "This validates the kernel PowerPC activation/subject-path layer with the private dyld, cache-validation bypass, and syscall-295 compatibility kernel."
    log "Stop here and preserve the report and raw log before any broader PPC test."
    exit 0
fi

log "RESULT: FAIL"
if /usr/bin/grep -Eiq 'usage:|translate.*usage' "$RAW_LOG"; then
    log "failure_class=TRANSLATOR_SUBJECT_PATH_OR_ACTIVATION"
fi
if [ "$RC" -eq 0 ]; then
    log "normal PPC exec exited 0 but the expected smoke-test message was absent"
else
    log "normal PPC exec exited nonzero (status $RC)"
fi
log "Preserve this report, raw log, and every new diagnostic listed above. Do not change the runtime or kernel yet."
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
