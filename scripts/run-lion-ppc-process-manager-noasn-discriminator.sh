#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP="${1:-$ROOT/payload/RosettaProcessManagerNoASN.app}"
APP_MANIFEST="${2:-$ROOT/payload/RosettaProcessManagerNoASN.app.manifest.txt}"
PRIVATE_ROOT="${3:-$ROOT/payload/private-launchservices-ppc-compat}"
REPORT="${4:-$ROOT/payload/lion-ppc-process-manager-noasn-discriminator.log}"

REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
PREFLIGHT_LOG="$REPORT_DIR/lion-ppc-process-manager-noasn-load-preflight.log"
OPEN_LOG="$REPORT_DIR/lion-ppc-process-manager-noasn-open.raw.log"
MILESTONE_COPY="$REPORT_DIR/lion-ppc-process-manager-noasn-milestone.log"
MILESTONE_LOG="/tmp/rosetta-processmanager-noasn-milestone.log"
MARKER=""

PRIVATE_BINARY="$PRIVATE_ROOT/LaunchServices.framework/Versions/A/LaunchServices"
PRIVATE_MANIFEST="$PRIVATE_ROOT/manifest.txt"
PATCHER="$SCRIPT_DIR/patch-lion-launchservices-ppc-compat.py"
SYSTEM_LS="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"

EXEC="$APP/Contents/MacOS/RosettaProcessManagerNoASN"
PLIST="$APP/Contents/Info.plist"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_SYSTEM_LS_SHA="ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$PREFLIGHT_LOG" || exit 73
: > "$OPEN_LOG" || exit 73
/bin/rm -f "$MILESTONE_COPY"

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() {
    code="$1"; shift
    log "ERROR: $*"
    log "Experiment stopped; preserve all generated logs before changing anything."
    exit "$code"
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

log "== Lion PPC no-ASN discriminator experiment =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"

[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || die 65 "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || die 65 "WindowServer is not running"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 kernel hash"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
log "mach_kernel_sha256=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

TRANSLATOR_SHA="$(sha256 "$TRANSLATOR")"
log "translator_sha256=$TRANSLATOR_SHA"
[ "$TRANSLATOR_SHA" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"

SYSTEM_LS_BEFORE="$(sha256 "$SYSTEM_LS")"
log "system_launchservices_sha256_before=$SYSTEM_LS_BEFORE"
[ "$SYSTEM_LS_BEFORE" = "$EXPECTED_SYSTEM_LS_SHA" ] || die 68 "system LaunchServices hash mismatch"

[ -f "$PRIVATE_BINARY" ] || die 66 "missing private patched LaunchServices"
[ -f "$PRIVATE_MANIFEST" ] || die 66 "missing private LaunchServices manifest"
PRIVATE_LS_BEFORE="$(sha256 "$PRIVATE_BINARY")"
EXPECTED_PRIVATE_LS_SHA="$(/usr/bin/awk -F= '/^private_launchservices_sha256=/ {print $2}' "$PRIVATE_MANIFEST" | /usr/bin/head -1)"
[ -n "$EXPECTED_PRIVATE_LS_SHA" ] || die 68 "could not read private LaunchServices hash from manifest"
log "private_launchservices_sha256_before=$PRIVATE_LS_BEFORE"
log "expected_private_launchservices_sha256=$EXPECTED_PRIVATE_LS_SHA"
[ "$PRIVATE_LS_BEFORE" = "$EXPECTED_PRIVATE_LS_SHA" ] || die 68 "private LaunchServices hash mismatch"
/usr/bin/python "$PATCHER" --check "$PRIVATE_BINARY" >> "$REPORT" 2>&1 || die 68 "private LaunchServices patch verification failed"
/usr/bin/python "$PATCHER" --check "$PRIVATE_BINARY" 2>/dev/null | /usr/bin/grep -Fq 'RESULT: ALREADY_PATCHED' || die 68 "private LaunchServices not in patched state"

PRIVATE_DYLD_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_DYLD_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
log "private_dyld_sha256_before=$PRIVATE_DYLD_BEFORE"
log "lion_system_dyld_sha256_before=$SYSTEM_DYLD_BEFORE"
log "rosetta_cache_sha256=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
[ "$PRIVATE_DYLD_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"

[ -d "$APP" ] || die 66 "missing no-ASN discriminator app bundle"
[ -f "$APP_MANIFEST" ] || die 66 "missing app manifest"
[ -x "$EXEC" ] || die 66 "missing bundled PPC executable"
[ -f "$PLIST" ] || die 66 "missing app Info.plist"

EXPECTED_EXE_SHA="$(/usr/bin/awk -F= '/^executable_sha256=/ {print $2}' "$APP_MANIFEST" | /usr/bin/head -1)"
[ -n "$EXPECTED_EXE_SHA" ] || die 68 "could not read executable hash from app manifest"
EXEC_BEFORE="$(sha256 "$EXEC")"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXEC_BEFORE"
[ "$EXEC_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "bundled executable hash mismatch"

/usr/bin/file "$EXEC" 2>&1 | /usr/bin/tee -a "$REPORT"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXEC" 2>&1 | /usr/bin/tee -a "$REPORT" || true
fi

CACHE_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_SHARED_CACHE_DONT_VALIDATE' "$PLIST" 2>/dev/null || true)"
PRINT_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_PRINT_LIBRARIES' "$PLIST" 2>/dev/null || true)"
NOASN_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:LSDONOTABORTIFNOASN' "$PLIST" 2>/dev/null || true)"
[ "$CACHE_ENV" = "1" ] || die 68 "app cache-bypass environment missing"
[ "$PRINT_ENV" = "1" ] || die 68 "app DYLD_PRINT_LIBRARIES missing"
[ "$NOASN_ENV" = "0" ] || die 68 "app LSDONOTABORTIFNOASN=0 missing"

log ""
log "== PRIVATE FRAMEWORK LOAD PREFLIGHT =="
DYLD_FRAMEWORK_PATH="$PRIVATE_ROOT" DYLD_PRINT_LIBRARIES=1     /usr/bin/arch -i386 /usr/bin/open > "$PREFLIGHT_LOG" 2>&1
PREFLIGHT_RC=$?
log "preflight_open_status=$PREFLIGHT_RC"
/bin/cat "$PREFLIGHT_LOG" | /usr/bin/tee -a "$REPORT"
if ! /usr/bin/grep -Fq "$PRIVATE_BINARY" "$PREFLIGHT_LOG"; then
    die 69 "private LaunchServices was not loaded; no PPC app launch attempted"
fi
log "private_launchservices_override=CONFIRMED"

if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised"
fi

/bin/rm -f "$MILESTONE_LOG"
MARKER="$(/usr/bin/mktemp /tmp/lion-pm-noasn-marker.XXXXXX)" || die 73 "could not create diagnostic marker"

log ""
log "== NO-ASN DISCRIMINATOR TEST =="
log "+ DYLD_FRAMEWORK_PATH=$PRIVATE_ROOT /usr/bin/arch -i386 /usr/bin/open -n $APP"
DYLD_FRAMEWORK_PATH="$PRIVATE_ROOT"     /usr/bin/arch -i386 /usr/bin/open -n "$APP" > "$OPEN_LOG" 2>&1
OPEN_RC=$?
log "open_status=$OPEN_RC"

/bin/sleep 3

if [ -f "$MILESTONE_LOG" ]; then
    /bin/cp "$MILESTONE_LOG" "$MILESTONE_COPY"
    log "== milestone log =="
    /bin/cat "$MILESTONE_COPY" | /usr/bin/tee -a "$REPORT"
else
    log "milestone_log=missing"
fi

if [ -s "$OPEN_LOG" ]; then
    log "== open stdout/stderr =="
    /bin/cat "$OPEN_LOG" | /usr/bin/tee -a "$REPORT"
fi

FURTHEST="NONE"
if [ -f "$MILESTONE_COPY" ]; then
    for m in \
        M00_MAIN_ENTER \
        M01_OVERRIDE_INVALID \
        M02_BEFORE_GetProcessForPID \
        M03_AFTER_GetProcessForPID \
        M04_RETURNED_ERROR \
        M05_NOERR_ZERO_PSN \
        M06_NOERR_NONZERO_PSN; do
        if /usr/bin/grep -Fq "PM_NOASN_MILESTONE:$m" "$MILESTONE_COPY"; then
            FURTHEST="$m"
        fi
    done
fi
log "furthest_pm_noasn_milestone=$FURTHEST"

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
SYSTEM_LS_AFTER="$(sha256 "$SYSTEM_LS")"
PRIVATE_LS_AFTER="$(sha256 "$PRIVATE_BINARY")"
PRIVATE_DYLD_AFTER="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_DYLD_AFTER="$(sha256 "$SYSTEM_DYLD")"
KERNEL_AFTER="$(sha256 /mach_kernel)"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
EXEC_AFTER="$(sha256 "$EXEC")"
log "system_launchservices_sha256_after=$SYSTEM_LS_AFTER"
log "private_launchservices_sha256_after=$PRIVATE_LS_AFTER"
log "private_dyld_sha256_after=$PRIVATE_DYLD_AFTER"
log "lion_system_dyld_sha256_after=$SYSTEM_DYLD_AFTER"
log "mach_kernel_sha256_after=$KERNEL_AFTER"
log "rosetta_cache_sha256_after=$CACHE_AFTER"
log "bundled_executable_sha256_after=$EXEC_AFTER"

[ "$SYSTEM_LS_AFTER" = "$SYSTEM_LS_BEFORE" ] || die 70 "system LaunchServices changed"
[ "$PRIVATE_LS_AFTER" = "$PRIVATE_LS_BEFORE" ] || die 70 "private LaunchServices changed"
[ "$PRIVATE_DYLD_AFTER" = "$PRIVATE_DYLD_BEFORE" ] || die 70 "private dyld changed"
[ "$SYSTEM_DYLD_AFTER" = "$SYSTEM_DYLD_BEFORE" ] || die 70 "system dyld changed"
[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || die 70 "kernel changed"
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$EXEC_AFTER" = "$EXEC_BEFORE" ] || die 70 "bundled executable changed"

log ""
if [ -f "$MILESTONE_COPY" ] && /usr/bin/grep -Fq 'PM_NOASN_MILESTONE:M06_NOERR_NONZERO_PSN' "$MILESTONE_COPY"; then
    log "RESULT: NOASN_OVERRIDE_NONZERO_PSN"
    log "GetProcessForPID returned noErr with a nonzero PSN after the exact process-local no-ASN override."
    exit 0
fi

if /usr/bin/grep -Fq 'error -10665' "$OPEN_LOG"; then
    log "RESULT: LAUNCHSERVICES_GATE_REGRESSION"
elif [ "$FURTHEST" = "M02_BEFORE_GetProcessForPID" ]; then
    log "RESULT: ABORT_BEFORE_GETPROCESSFORPID_RETURN"
elif [ "$FURTHEST" = "M03_AFTER_GetProcessForPID" ] || [ "$FURTHEST" = "M04_RETURNED_ERROR" ]; then
    log "RESULT: NOASN_OVERRIDE_RETURNED_ERROR"
elif [ "$FURTHEST" = "M05_NOERR_ZERO_PSN" ]; then
    log "RESULT: NOASN_OVERRIDE_ZERO_PSN"
elif [ "$FURTHEST" = "M01_OVERRIDE_INVALID" ]; then
    log "RESULT: OVERRIDE_ENVIRONMENT_FAILURE"
elif [ "$FURTHEST" = "NONE" ]; then
    log "RESULT: PRE_MAIN_OR_LAUNCH_FAILURE"
else
    log "RESULT: LOCALIZED_OR_UNEXPECTED"
fi

log "Preserve this report, preflight/open/milestone logs, and every new diagnostic."
log "Do not make a second PPC launch and do not modify system LaunchServices, HIServices, Rosetta, or XNU."
exit 1
