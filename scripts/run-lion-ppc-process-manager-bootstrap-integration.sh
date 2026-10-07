#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

STAGE_EXE="${1:-$ROOT/payload/ppc-process-manager-bootstrap-integration-stage-private-dyld}"
STAGE_SHA_FILE="${2:-$STAGE_EXE.sha256}"
INTERPOSER="${3:-$ROOT/payload/ppc-process-manager-bootstrap-compat-interposer.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
REPORT="${5:-$ROOT/payload/lion-ppc-process-manager-bootstrap-integration.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-bootstrap-integration.raw.log"
MARKER=""

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
CARBONCORE_PATH="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
LIBSYSTEM_PATH="/usr/lib/libSystem.B.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_COMPAT_BUILD_ID="interpose-replacee-v3"
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

abspath() {
    file="$1"
    dir="$(/usr/bin/dirname "$file")"
    base="$(/usr/bin/basename "$file")"
    (cd "$dir" 2>/dev/null && echo "$(pwd)/$base")
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

log "== Lion PPC Process Manager bootstrap integration discriminator =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${CORESERVICESD_SERVICE_NAME+x}" ] || die 68 "CORESERVICESD_SERVICE_NAME must be unset"
[ -z "${SCDontUseServer+x}" ] || die 68 "SCDontUseServer must be unset"
[ -z "${ROSETTA_BOOTSTRAP_COMPAT_MODE+x}" ] || die 68 "ROSETTA_BOOTSTRAP_COMPAT_MODE must be unset before the runner"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset before the runner"
log "CORESERVICESD_SERVICE_NAME=UNSET"
log "SCDontUseServer=UNSET"
log "ROSETTA_BOOTSTRAP_COMPAT_MODE=UNSET_IN_PARENT"
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
TRANSLATOR_SHA="$(sha256 "$TRANSLATOR")"
log "translator_sha256=$TRANSLATOR_SHA"
[ "$TRANSLATOR_SHA" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"

[ -x "$STAGE_EXE" ] || die 66 "missing or non-executable PPC stage subject: $STAGE_EXE"
[ -f "$STAGE_SHA_FILE" ] || die 66 "missing stage SHA-256 sidecar: $STAGE_SHA_FILE"
[ -f "$INTERPOSER" ] || die 66 "missing PPC bootstrap compatibility interposer: $INTERPOSER"
[ -f "$INTERPOSER_SHA_FILE" ] || die 66 "missing interposer SHA-256 sidecar: $INTERPOSER_SHA_FILE"

EXPECTED_STAGE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$STAGE_SHA_FILE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"
[ -n "$EXPECTED_STAGE_SHA" ] || die 68 "could not read expected stage SHA-256"
[ -n "$EXPECTED_INTERPOSER_SHA" ] || die 68 "could not read expected interposer SHA-256"

STAGE_BEFORE="$(sha256 "$STAGE_EXE")"
INTERPOSER_BEFORE="$(sha256 "$INTERPOSER")"
log "expected_stage_sha256=$EXPECTED_STAGE_SHA"
log "actual_stage_sha256=$STAGE_BEFORE"
log "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA"
log "actual_interposer_sha256=$INTERPOSER_BEFORE"
[ "$STAGE_BEFORE" = "$EXPECTED_STAGE_SHA" ] || die 68 "stage executable hash mismatch"
[ "$INTERPOSER_BEFORE" = "$EXPECTED_INTERPOSER_SHA" ] || die 68 "interposer hash mismatch"

/usr/bin/file "$STAGE_EXE" 2>&1 | /usr/bin/tee -a "$REPORT"
/usr/bin/file "$INTERPOSER" 2>&1 | /usr/bin/tee -a "$REPORT"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$STAGE_EXE" 2>&1 | /usr/bin/tee -a "$REPORT" || true
    /usr/bin/lipo -info "$INTERPOSER" 2>&1 | /usr/bin/tee -a "$REPORT" || true
fi
has_ppc32_arch "$STAGE_EXE" || die 67 "stage subject is not a 32-bit PowerPC Mach-O"
has_ppc32_arch "$INTERPOSER" || die 67 "interposer is not a 32-bit PowerPC Mach-O"

OTOOL_OUT="$(/usr/bin/otool -l "$STAGE_EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OTOOL_OUT" | /usr/bin/tee -a "$REPORT"
echo "$OTOOL_OUT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "stage LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/otool -L "$STAGE_EXE" 2>&1 | /usr/bin/tee -a "$REPORT"
/usr/bin/otool -L "$STAGE_EXE" | /usr/bin/grep -Fq '/CoreServices.framework/Versions/A/CoreServices' || die 68 "CoreServices umbrella dependency is absent"

/usr/bin/otool -l "$INTERPOSER" | /usr/bin/grep -A10 -B2 '__interpose' | /usr/bin/tee -a "$REPORT" || die 68 "interposer section missing"

if /usr/bin/nm -m "$INTERPOSER" | /usr/bin/grep -Fq '_dlsym'; then
    die 68 "stale interposer detected: _dlsym import is present"
fi
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq "PM_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_COMPAT_BUILD_ID" ||     die 68 "corrected interposer build marker is missing"

INTERPOSER_ABS="$(abspath "$INTERPOSER")"
[ -n "$INTERPOSER_ABS" ] || die 68 "could not resolve interposer absolute path"
log "interposer_absolute_path=$INTERPOSER_ABS"

[ -f "$PRIVATE_DYLD" ] || die 66 "missing private dyld"
[ -f "$SYSTEM_DYLD" ] || die 66 "missing Lion system dyld"
[ -f "$ROSETTA_CACHE" ] || die 66 "missing Rosetta cache"
[ -f "$ROSETTA_CACHE_MAP" ] || die 66 "missing Rosetta cache map"

PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "lion_system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"

/usr/bin/grep -Fq "$CARBONCORE_PATH" "$ROSETTA_CACHE_MAP" || die 68 "CarbonCore is absent from the validated Rosetta cache map"
/usr/bin/grep -Fq "$LIBSYSTEM_PATH" "$ROSETTA_CACHE_MAP" || die 68 "libSystem is absent from the validated Rosetta cache map"
log "rosetta_cache_contains_carboncore=YES"
log "rosetta_cache_contains_libsystem=YES"

log ""
log "== CoreServices service state before test =="
/bin/launchctl list 2>&1 | /usr/bin/grep -i 'coreservicesd\|pbs' | /usr/bin/tee -a "$REPORT" || log "(no matching active jobs; launchd on-demand activation remains possible)"

if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with normal crash reporting"
fi
MARKER="$(/usr/bin/mktemp /tmp/lion-bootstrap-integration-marker.XXXXXX)" || die 73 "could not create diagnostic marker"

log ""
log "== SINGLE PPC BOOTSTRAP-INTEGRATED CORESERVICES TEST =="
log "+ ROSETTA_BOOTSTRAP_COMPAT_MODE=lion-adapter DYLD_INSERT_LIBRARIES=$INTERPOSER_ABS DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 $STAGE_EXE"
ROSETTA_BOOTSTRAP_COMPAT_MODE=lion-adapter DYLD_INSERT_LIBRARIES="$INTERPOSER_ABS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1     "$STAGE_EXE" > "$RAW_LOG" 2>&1
RC=$?
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "integration_exec_status=$RC"

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
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
STAGE_AFTER="$(sha256 "$STAGE_EXE")"
INTERPOSER_AFTER="$(sha256 "$INTERPOSER")"
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "lion_system_dyld_sha256_after=$SYSTEM_AFTER"
log "mach_kernel_sha256_after=$KERNEL_AFTER"
log "rosetta_cache_sha256_after=$CACHE_AFTER"
log "stage_sha256_after=$STAGE_AFTER"
log "interposer_sha256_after=$INTERPOSER_AFTER"
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || die 70 "Lion native dyld changed"
[ "$KERNEL_AFTER" = "$EXPECTED_KERNEL_SHA" ] || die 70 "kernel changed"
[ "$CACHE_AFTER" = "$EXPECTED_CACHE_SHA" ] || die 70 "Rosetta cache changed"
[ "$STAGE_AFTER" = "$EXPECTED_STAGE_SHA" ] || die 70 "stage executable changed"
[ "$INTERPOSER_AFTER" = "$EXPECTED_INTERPOSER_SHA" ] || die 70 "interposer changed"

log ""
if ! /usr/bin/grep -Fq "dyld: loaded: $INTERPOSER_ABS" "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_INTERPOSER_NOT_LOADED"
    exit 1
fi

if ! /usr/bin/grep -Fq "PM_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_COMPAT_BUILD_ID" "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_STALE_INTERPOSER"
    exit 1
fi

if ! /usr/bin/grep -Fq 'PM_BOOTSTRAP_COMPAT_EXACT_CALL:index=1 mode=lion-adapter' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_INTERPOSER_NOT_TRIGGERED"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:SECOND_EXACT_CALL_BLOCKED' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_MULTIPLE_EXACT_LOOKUPS"
    exit 1
fi

if /usr/bin/grep -Eq 'PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:(MODE_INVALID|REPLY_PORT_NULL|LAYOUT_BUILD_FAILED|AUDIT_TRAILER_INVALID|SERVER_NOT_PRIVILEGED)' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_ADAPTER_INTERNAL_OR_POLICY_FAILURE"
    exit 1
fi

if ! /usr/bin/grep -Eq 'PM_BOOTSTRAP_COMPAT_ADAPTER_RESULT:LOOKUP_PASS servicePort=0x0*[1-9a-fA-F][0-9a-fA-F]* serverEuid=0' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_LOOKUP_NOT_ESTABLISHED"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_MILESTONE:M01_BEFORE_scCreateSystemServiceVersion' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_MILESTONE:M02_AFTER_scCreateSystemServiceVersion' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_SYSTEMSERVICE_ABORT_OR_CRASH"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_RESULT:CHECKIN_SESSION_UNAVAILABLE' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_RESULT:SERVICE_LOOKUP_FAILURE_AFTER_CHECKIN' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_FIND_SERVICE_FAILURE"
    exit 1
fi

if /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_RESULT:INCONSISTENT_SERVICE_WITHOUT_CHECKIN' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_INCONSISTENT_SERVICE_STATE"
    exit 1
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_SYSTEMSERVICE_STAGE_SERVICE:port=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_SYSTEMSERVICE_STAGE_CHECKIN:port=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG"; then
    log "RESULT: BOOTSTRAP_COMPAT_SYSTEMSERVICE_PASS"
    exit 0
fi

log "RESULT: BOOTSTRAP_COMPAT_PRE_MAIN_OR_UNCLASSIFIED_FAILURE"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
