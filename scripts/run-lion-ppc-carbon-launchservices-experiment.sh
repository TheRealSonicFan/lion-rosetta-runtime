#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP="${1:-$ROOT/payload/RosettaCarbonLaunchServices.app}"
MANIFEST="${2:-$APP.manifest.txt}"
REPORT="${3:-$ROOT/payload/lion-ppc-carbon-launchservices-experiment.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
OPEN_LOG="$REPORT_DIR/lion-ppc-carbon-launchservices-open.raw.log"
MILESTONE_COPY="$REPORT_DIR/lion-ppc-carbon-launchservices-milestone.log"
MILESTONE_LOG="/tmp/rosetta-carbon-launchservices-milestone.log"
MARKER=""

EXEC="$APP/Contents/MacOS/RosettaCarbonLaunchServices"
PLIST="$APP/Contents/Info.plist"
TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
APPSERVICES_SHIM="/usr/libexec/oah/Shims/ApplicationServices.framework/Versions/A/ApplicationServices"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$OPEN_LOG" || exit 73
/bin/rm -f "$MILESTONE_COPY"

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

log "== Lion PPC Carbon LaunchServices experiment =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"

[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || die 65 "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || die 65 "WindowServer is not running"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 kernel hash"
[ -f /mach_kernel ] || die 66 "missing /mach_kernel"
KERNEL_SHA="$(sha256 /mach_kernel)"
log "mach_kernel_sha256=$KERNEL_SHA"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
[ "$KERNEL_SHA" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

[ -x "$TRANSLATOR" ] || die 66 "missing translator"
TRANSLATOR_SHA="$(sha256 "$TRANSLATOR")"
log "translator_sha256=$TRANSLATOR_SHA"
[ "$TRANSLATOR_SHA" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"

[ -f "$APPSERVICES_SHIM" ] || die 66 "missing Rosetta ApplicationServices shim"
log "applicationservices_shim_sha256=$(sha256 "$APPSERVICES_SHIM")"

[ -d "$APP" ] || die 66 "missing app bundle: $APP"
[ -f "$MANIFEST" ] || die 66 "missing bundle manifest: $MANIFEST"
[ -x "$EXEC" ] || die 66 "missing bundled PPC executable: $EXEC"
[ -f "$PLIST" ] || die 66 "missing Info.plist"

EXPECTED_EXE_SHA="$(/usr/bin/awk -F= '/^executable_sha256=/ {print $2}' "$MANIFEST" | /usr/bin/head -1)"
[ -n "$EXPECTED_EXE_SHA" ] || die 68 "could not read executable hash from manifest"
ACTUAL_EXE_SHA="$(sha256 "$EXEC")"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$ACTUAL_EXE_SHA"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || die 68 "bundled executable hash mismatch"

has_ppc32_arch "$EXEC" || die 67 "bundled executable is not a 32-bit PowerPC Mach-O"
/usr/bin/file "$EXEC" 2>&1 | /usr/bin/tee -a "$REPORT"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXEC" 2>&1 | /usr/bin/tee -a "$REPORT" || true
fi

OT="$(/usr/bin/otool -l "$EXEC" 2>&1 | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/otool -L "$EXEC" 2>&1 | /usr/bin/tee -a "$REPORT"
/usr/bin/otool -L "$EXEC" | /usr/bin/grep -Fq '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || die 68 "Carbon dependency is absent"

CACHE_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_SHARED_CACHE_DONT_VALIDATE' "$PLIST" 2>/dev/null || true)"
PRINT_ENV="$(/usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_PRINT_LIBRARIES' "$PLIST" 2>/dev/null || true)"
PLIST_EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null || true)"
log "CFBundleExecutable=$PLIST_EXEC"
log "LSEnvironment.DYLD_SHARED_CACHE_DONT_VALIDATE=$CACHE_ENV"
log "LSEnvironment.DYLD_PRINT_LIBRARIES=$PRINT_ENV"
[ "$PLIST_EXEC" = "RosettaCarbonLaunchServices" ] || die 68 "CFBundleExecutable mismatch"
[ "$CACHE_ENV" = "1" ] || die 68 "Info.plist cache-bypass environment missing"
[ "$PRINT_ENV" = "1" ] || die 68 "Info.plist DYLD_PRINT_LIBRARIES missing"

[ -f "$PRIVATE_DYLD" ] || die 66 "missing private dyld"
[ -f "$SYSTEM_DYLD" ] || die 66 "missing Lion system dyld"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "lion_system_dyld_sha256_before=$SYSTEM_BEFORE"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"

[ -f "$ROSETTA_CACHE" ] || die 66 "missing Rosetta cache"
[ -f "$ROSETTA_CACHE_MAP" ] || die 66 "missing Rosetta cache map"
CACHE_SHA="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
log "rosetta_cache_sha256=$CACHE_SHA"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
[ "$CACHE_SHA" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"

if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised"
fi

/bin/rm -f "$MILESTONE_LOG"
MARKER="$(/usr/bin/mktemp /tmp/lion-ppc-carbon-launchservices-marker.XXXXXX)" || die 73 "could not create diagnostic marker"

if [ -x "$LSREGISTER" ]; then
    log "+ $LSREGISTER -f $APP"
    "$LSREGISTER" -f "$APP" >> "$REPORT" 2>&1 || die 69 "lsregister failed"
fi

log ""
log "== LAUNCHSERVICES PPC CARBON TEST =="
log "+ /usr/bin/open -n -W $APP"
/usr/bin/open -n -W "$APP" > "$OPEN_LOG" 2>&1
OPEN_RC=$?
log "open_status=$OPEN_RC"

LS_RESULT="UNKNOWN"
if /usr/bin/grep -Fq 'error -10665' "$OPEN_LOG"; then
    LS_RESULT="NO_ROSETTA_ENVIRONMENT"
elif [ "$OPEN_RC" -eq 0 ]; then
    LS_RESULT="OPEN_ACCEPTED"
else
    LS_RESULT="OTHER_LAUNCH_FAILURE"
fi
log "launchservices_result=$LS_RESULT"

/bin/sleep 2

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
    for m in         M00_MAIN_ENTER         M01_BEFORE_GetCurrentProcess         M02_AFTER_GetCurrentProcess         M03_BEFORE_TransformProcessType         M04_AFTER_TransformProcessType         M05_BEFORE_SetFrontProcess         M06_AFTER_SetFrontProcess         M07_BEFORE_CreateNewWindow         M08_AFTER_CreateNewWindow         M09_BEFORE_CFStringCreateWithCString         M10_AFTER_CFStringCreateWithCString         M11_BEFORE_SetWindowTitleWithCFString         M12_AFTER_SetWindowTitleWithCFString         M13_BEFORE_ShowWindow         M14_AFTER_ShowWindow         M15_BEFORE_SelectWindow         M16_AFTER_SelectWindow         M17_BEFORE_IsWindowVisible         M18_AFTER_IsWindowVisible         M19_BEFORE_NewEventLoopTimerUPP         M20_AFTER_NewEventLoopTimerUPP         M21_BEFORE_InstallEventLoopTimer         M22_AFTER_InstallEventLoopTimer         M25_BEFORE_RunApplicationEventLoop         M23_TIMER_CALLBACK_ENTER         M24_TIMER_CALLBACK_EXIT         M26_AFTER_RunApplicationEventLoop         M27_SUCCESS; do
        if /usr/bin/grep -Fq "CARBON_LS_MILESTONE:$m" "$MILESTONE_COPY"; then
            FURTHEST="$m"
        fi
    done
fi
log "furthest_carbon_ls_milestone=$FURTHEST"

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
BUNDLE_AFTER="$(sha256 "$EXEC")"
log "private_dyld_sha256_after=$PRIVATE_AFTER"
log "lion_system_dyld_sha256_after=$SYSTEM_AFTER"
log "mach_kernel_sha256_after=$KERNEL_AFTER"
log "rosetta_cache_sha256_after=$CACHE_AFTER"
log "bundled_executable_sha256_after=$BUNDLE_AFTER"
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || die 70 "Lion native dyld changed"
[ "$KERNEL_AFTER" = "$EXPECTED_KERNEL_SHA" ] || die 70 "kernel changed"
[ "$CACHE_AFTER" = "$EXPECTED_CACHE_SHA" ] || die 70 "Rosetta cache changed"
[ "$BUNDLE_AFTER" = "$EXPECTED_EXE_SHA" ] || die 70 "bundled executable changed"

log ""
if [ -f "$MILESTONE_COPY" ] &&
   /usr/bin/grep -Fq 'CARBON_LS_ENV:DYLD_SHARED_CACHE_DONT_VALIDATE=1' "$MILESTONE_COPY" &&
   /usr/bin/grep -Fq 'CARBON_LS_MILESTONE:M27_SUCCESS' "$MILESTONE_COPY"; then
    log "RESULT: PASS"
    log "LaunchServices-registered PPC Carbon execution completed successfully."
    log "Stop here and preserve the evidence before any production-path conclusion."
    exit 0
fi

if [ "$LS_RESULT" = "NO_ROSETTA_ENVIRONMENT" ]; then
    log "RESULT: LAUNCHSERVICES_NO_ROSETTA_ENVIRONMENT"
    log "LaunchServices returned -10665 (kLSNoRosettaEnvironmentErr) before the PPC executable was started."
    log "No milestone log is expected in this result class because main() was never entered."
elif [ "$FURTHEST" = "M01_BEFORE_GetCurrentProcess" ]; then
    log "RESULT: SAME_GETCURRENTPROCESS_BOUNDARY"
    log "LaunchServices accepted the app, but registration did not move the immediate GetCurrentProcess boundary."
elif [ "$FURTHEST" = "NONE" ]; then
    log "RESULT: PRE_MAIN_OR_LAUNCH_FAILURE"
else
    log "RESULT: BOUNDARY_MOVED"
    log "LaunchServices changed the observed boundary; preserve the furthest milestone and diagnostics."
fi

log "Preserve this report, the open log, milestone log, and every new diagnostic. Do not change XNU or frameworks yet."
exit 1
