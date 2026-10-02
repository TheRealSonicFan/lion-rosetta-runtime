#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-smoketest-private-dyld}"
DYLD_SRC="${2:-$ROOT/payload/snowleopard-10.6.8-dyld}"
CACHE_BYPASS="${ROSETTA_CACHE_BYPASS_VALIDATION:-0}"
case "$CACHE_BYPASS" in
    0) DEFAULT_REPORT="$ROOT/payload/lion-private-dyld-experiment.log"
       DEFAULT_RAW_LOG="lion-private-dyld-direct.raw.log" ;;
    1) DEFAULT_REPORT="$ROOT/payload/lion-private-dyld-cache-bypass-experiment.log"
       DEFAULT_RAW_LOG="lion-private-dyld-cache-bypass-direct.raw.log" ;;
    *) echo "error: ROSETTA_CACHE_BYPASS_VALIDATION must be 0 or 1" >&2; exit 64 ;;
esac
REPORT="${3:-$DEFAULT_REPORT}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/$DEFAULT_RAW_LOG"
MARKER=""
PRIVATE_DIR="/usr/oah"
PRIVATE_DYLD="$PRIVATE_DIR/dyld"
TRANSLATOR="/usr/libexec/oah/translate"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_EXE_SHA="b34e7c4b1ffe9750ae866c4a1e2d732e5dd90aa44c3f79d15359d58076987b0a"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"

/bin/mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73

log() {
    echo "$*" | /usr/bin/tee -a "$REPORT"
}

run_log() {
    log "+ $*"
    "$@" 2>&1 | /usr/bin/tee -a "$REPORT"
    return ${PIPESTATUS[0]}
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

log "== Lion private-dyld Rosetta experiment =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
log "rosetta_cache_bypass_validation=$CACHE_BYPASS"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "this experiment requires the Lion 10.7.5 target (found $PRODUCT_VERSION)"

if command -v git >/dev/null 2>&1 && [ -d "$ROOT/.git" ]; then
    GIT_HEAD="$(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || true)"
    log "runtime_repo_head=$GIT_HEAD"
fi

[ -x "$TRANSLATOR" ] || die 66 "missing or non-executable translator: $TRANSLATOR"
[ -f "$SYSTEM_DYLD" ] || die 66 "missing Lion system dyld: $SYSTEM_DYLD"
[ -f "$EXE" ] || die 66 "missing experimental PPC executable: $EXE"
[ -f "$DYLD_SRC" ] || die 66 "missing Snow Leopard dyld source: $DYLD_SRC"

log ""
log "== Experimental PPC executable =="
run_log /usr/bin/file "$EXE" || die 67 "file(1) could not inspect $EXE"
if [ -x /usr/bin/lipo ]; then
    run_log /usr/bin/lipo -info "$EXE" || true
fi
has_ppc32_arch "$EXE" || die 67 "experimental executable is not a 32-bit PowerPC Mach-O"
EXE_SHA="$(sha256 "$EXE")"
log "experimental_executable_sha256=$EXE_SHA"
[ "$EXE_SHA" = "$EXPECTED_EXE_SHA" ] || die 68 "experimental executable hash mismatch; expected $EXPECTED_EXE_SHA"

if [ ! -x "$EXE" ]; then
    log "Executable bit is absent; restoring it on the local test copy."
    /bin/chmod +x "$EXE" || die 73 "could not mark $EXE executable"
fi

if [ -x /usr/bin/otool ]; then
    log ""
    log "== LC_LOAD_DYLINKER check =="
    OTOOL_OUT="$(/usr/bin/otool -l "$EXE" 2>&1 | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
    echo "$OTOOL_OUT" | /usr/bin/tee -a "$REPORT"
    echo "$OTOOL_OUT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"
else
    log "otool unavailable on Lion; exact executable SHA-256 match is used as the load-command identity check."
fi

log ""
log "== Snow Leopard dyld source =="
run_log /usr/bin/file "$DYLD_SRC" || die 68 "file(1) could not inspect $DYLD_SRC"
if [ -x /usr/bin/lipo ]; then
    run_log /usr/bin/lipo -info "$DYLD_SRC" || true
fi
DYLD_SRC_SHA="$(sha256 "$DYLD_SRC")"
log "snowleopard_dyld_source_sha256=$DYLD_SRC_SHA"
[ "$DYLD_SRC_SHA" = "$EXPECTED_DYLD_SHA" ] || die 68 "Snow Leopard dyld hash mismatch; expected $EXPECTED_DYLD_SHA"

log ""
log "== Lion native dyld baseline =="
run_log /usr/bin/file "$SYSTEM_DYLD" || true
if [ -x /usr/bin/lipo ]; then
    run_log /usr/bin/lipo -info "$SYSTEM_DYLD" || true
fi
SYSTEM_DYLD_BEFORE="$(sha256 "$SYSTEM_DYLD")"
log "lion_system_dyld_sha256_before=$SYSTEM_DYLD_BEFORE"

log ""
log "== Stage private Snow Leopard dyld =="
if [ -L "$PRIVATE_DIR" ]; then
    die 69 "$PRIVATE_DIR is a symbolic link; refusing to stage into it"
fi
if [ -e "$PRIVATE_DIR" ] && [ ! -d "$PRIVATE_DIR" ]; then
    die 69 "$PRIVATE_DIR exists but is not a directory"
fi
if [ -L "$PRIVATE_DYLD" ]; then
    die 69 "$PRIVATE_DYLD is a symbolic link; refusing to use or replace it"
fi

if [ -e "$PRIVATE_DYLD" ]; then
    EXISTING_SHA="$(sha256 "$PRIVATE_DYLD" 2>/dev/null || true)"
    log "existing_private_dyld_sha256=$EXISTING_SHA"
    [ "$EXISTING_SHA" = "$EXPECTED_DYLD_SHA" ] || die 69 "$PRIVATE_DYLD already exists with an unexpected hash; it was not overwritten"
    log "Existing private dyld matches the validated Snow Leopard artifact; reusing it."
else
    log "Creating $PRIVATE_DIR and copying the validated dyld. Lion's /usr/lib/dyld is not modified."
    sudo /bin/mkdir -p "$PRIVATE_DIR" || die 77 "sudo mkdir failed"
    sudo /usr/bin/ditto --rsrc --extattr "$DYLD_SRC" "$PRIVATE_DYLD" || die 74 "copy to $PRIVATE_DYLD failed"
fi

sudo /usr/sbin/chown root:wheel "$PRIVATE_DYLD" || die 77 "could not set root:wheel ownership on $PRIVATE_DYLD"
sudo /bin/chmod 755 "$PRIVATE_DYLD" || die 77 "could not set mode 0755 on $PRIVATE_DYLD"
run_log /bin/ls -ld "$PRIVATE_DIR" "$PRIVATE_DYLD" || true
PRIVATE_SHA="$(sha256 "$PRIVATE_DYLD")"
log "private_dyld_sha256=$PRIVATE_SHA"
[ "$PRIVATE_SHA" = "$EXPECTED_DYLD_SHA" ] || die 68 "staged private dyld hash mismatch"

SYSTEM_DYLD_AFTER_STAGE="$(sha256 "$SYSTEM_DYLD")"
log "lion_system_dyld_sha256_after_stage=$SYSTEM_DYLD_AFTER_STAGE"
[ "$SYSTEM_DYLD_AFTER_STAGE" = "$SYSTEM_DYLD_BEFORE" ] || die 70 "Lion's native /usr/lib/dyld changed during staging; stop immediately"

log ""
log "== Translator/kernel context =="
run_log /usr/sbin/sysctl kern.exec.archhandler.powerpc || true
run_log /usr/bin/file "$TRANSLATOR" || true

if [ "$CACHE_BYPASS" = "1" ]; then
    log ""
    log "== Rosetta shared-cache bypass preflight =="
    [ -f "$ROSETTA_CACHE" ] || die 66 "missing Rosetta shared cache: $ROSETTA_CACHE"
    [ -f "$ROSETTA_CACHE_MAP" ] || die 66 "missing Rosetta shared cache map: $ROSETTA_CACHE_MAP"

    CACHE_SHA="$(sha256 "$ROSETTA_CACHE")"
    CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
    log "rosetta_cache_sha256=$CACHE_SHA"
    log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
    [ "$CACHE_SHA" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta shared-cache hash mismatch; expected $EXPECTED_CACHE_SHA"
    [ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta shared-cache map hash mismatch; expected $EXPECTED_CACHE_MAP_SHA"

    log "== Rosetta shared-cache map membership audit =="
    for image in \
        /usr/lib/libgcc_s.1.dylib \
        /usr/lib/libSystem.B.dylib \
        /usr/lib/system/libmathCommon.A.dylib; do
        MATCH="$(/usr/bin/grep -F "$image" "$ROSETTA_CACHE_MAP" 2>/dev/null || true)"
        if [ -n "$MATCH" ]; then
            log "cache_map_contains=YES $image"
            echo "$MATCH" | /usr/bin/tee -a "$REPORT"
        else
            log "cache_map_contains=NO $image"
        fi
    done
    log "Cache-map membership is diagnostic, not an identity check; the exact cache/map SHA-256 values above define the validated baseline."
    log "The validated map is known not to contain /usr/lib/libgcc_s.1.dylib, so a successful validation bypass may still stop later on that uncached guest dependency."

    log "Guest dyld will receive DYLD_SHARED_CACHE_DONT_VALIDATE=1."
    log "This is process-local; no dyld cache or Lion /usr/lib file is modified."
fi

log ""
log "== Core/crash capture preparation =="
run_log /bin/df -h / || true
if [ -d /cores ]; then
    run_log /bin/df -h /cores || true
fi
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with the normal crash reporter"
fi
MARKER="$(/usr/bin/mktemp /tmp/lion-private-dyld-marker.XXXXXX)" || die 73 "could not create diagnostic marker"

log ""
log "== DIRECT TRANSLATOR TEST =="
if [ "$CACHE_BYPASS" = "1" ]; then
    log "+ DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 $TRANSLATOR $EXE"
    DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 \
        "$TRANSLATOR" "$EXE" > "$RAW_LOG" 2>&1
    RC=$?
else
    log "+ $TRANSLATOR $EXE"
    "$TRANSLATOR" "$EXE" > "$RAW_LOG" 2>&1
    RC=$?
fi
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "direct_translate_status=$RC"

# Give ReportCrash a short opportunity to write a diagnostic if translate failed.
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
SYSTEM_DYLD_AFTER="$(sha256 "$SYSTEM_DYLD")"
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "lion_system_dyld_sha256_after=$SYSTEM_DYLD_AFTER"
[ "$PRIVATE_AFTER" = "$EXPECTED_DYLD_SHA" ] || die 70 "private dyld changed during the run"
[ "$SYSTEM_DYLD_AFTER" = "$SYSTEM_DYLD_BEFORE" ] || die 70 "Lion's native /usr/lib/dyld changed during the run"

log ""
if [ "$RC" -eq 0 ] && /usr/bin/grep -Fq 'Rosetta PPC smoke test: pid=' "$RAW_LOG"; then
    log "RESULT: PASS"
    if [ "$CACHE_BYPASS" = "1" ]; then
        log "The private-dyld experiment succeeded with Rosetta cache validation bypassed process-locally."
    else
        log "The private-dyld direct translator experiment succeeded on Lion."
    fi
    log "Do not run the normal PPC exec path yet; preserve this report and raw log first."
    log "report=$REPORT"
    log "raw_log=$RAW_LOG"
    exit 0
fi

log "RESULT: FAIL"
if [ "$CACHE_BYPASS" = "1" ]; then
    if /usr/bin/grep -Fq 'ignoring cache' "$RAW_LOG"; then
        log "cache_validation_result=REJECTED_OR_BYPASS_INEFFECTIVE"
        log "The guest dyld still reported that it ignored the shared cache."
    else
        log "cache_validation_result=NO_CACHE_REJECTION_MESSAGE_OBSERVED"
        if /usr/bin/grep -Fq 'Library not loaded: /usr/lib/libgcc_s.1.dylib' "$RAW_LOG"; then
            log "next_guest_boundary=UNCACHED_LIBGCC_S_1"
            log "The exact validated cache map does not contain /usr/lib/libgcc_s.1.dylib; preserve this result for the private-library follow-up."
        fi
    fi
fi
if [ "$RC" -eq 0 ]; then
    log "translate exited 0 but the expected PPC smoke-test message was absent."
else
    log "translate exited nonzero (status $RC). Preserve the report, raw log, and any new crash/core files listed above before changing anything."
fi
log "report=$REPORT"
log "raw_log=$RAW_LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
