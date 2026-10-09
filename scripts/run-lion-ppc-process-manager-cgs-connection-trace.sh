#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUBJECT="${1:-$ROOT/payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
SUBJECT_SHA_FILE="${2:-$SUBJECT.sha256}"
CORE_TRACE="${3:-$ROOT/payload/ppc-process-manager-coreservices-sessioninit-cgs-trace-interposer.dylib}"
CORE_TRACE_SHA_FILE="${4:-$CORE_TRACE.sha256}"
SEC_INTERPOSER="${5:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
CGS_INTERPOSER="${7:-$ROOT/payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib}"
CGS_SHA_FILE="${8:-$CGS_INTERPOSER.sha256}"
REPORT="${9:-$ROOT/payload/lion-ppc-process-manager-cgs-connection-trace.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-cgs-connection-trace.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
CARBONCORE="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/CarbonCore.framework/Versions/A/CarbonCore"
SECURITY="/System/Library/Frameworks/Security.framework/Versions/A/Security"
LAUNCHSERVICES="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/LaunchServices"
HISERVICES="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
LIBSYSTEM="/usr/lib/libSystem.B.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_COREGRAPHICS_SHA="fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192"
EXPECTED_SUBJECT_BUILD_ID="cgs-session-bootstrap-integration-v1"
EXPECTED_CORE_TRACE_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-trace-v1"
EXPECTED_SEC_BUILD_ID="security-session-auditinfo-api-v1"
EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-compat-v1"
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

log "== Lion PPC passive CGS connection transport trace =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || die 65 "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || die 65 "WindowServer is not running"

for v in CORESERVICESD_SERVICE_NAME SCDontUseServer LSDONOTABORTIFNOASN \
         ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE \
         ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" \
         "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS" "$CARBONCORE" \
         "$SECURITY" "$LAUNCHSERVICES" "$HISERVICES" "$LIBSYSTEM" \
         "$SUBJECT" "$SUBJECT_SHA_FILE" "$CORE_TRACE" "$CORE_TRACE_SHA_FILE" \
         "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$CGS_INTERPOSER" "$CGS_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_SUBJECT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SUBJECT_SHA_FILE")"
EXPECTED_CORE_TRACE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_TRACE_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"
EXPECTED_CGS_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CGS_SHA_FILE")"

KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
CG_BEFORE="$(sha256 "$COREGRAPHICS")"
CARBONCORE_BEFORE="$(sha256 "$CARBONCORE")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
LAUNCHSERVICES_BEFORE="$(sha256 "$LAUNCHSERVICES")"
HISERVICES_BEFORE="$(sha256 "$HISERVICES")"
LIBSYSTEM_BEFORE="$(sha256 "$LIBSYSTEM")"
SUBJECT_BEFORE="$(sha256 "$SUBJECT")"
CORE_TRACE_BEFORE="$(sha256 "$CORE_TRACE")"
SEC_BEFORE="$(sha256 "$SEC_INTERPOSER")"
CGS_BEFORE="$(sha256 "$CGS_INTERPOSER")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "coregraphics_sha256_before=$CG_BEFORE"
log "expected_subject_sha256=$EXPECTED_SUBJECT_SHA"
log "actual_subject_sha256=$SUBJECT_BEFORE"
log "expected_coreservices_trace_sha256=$EXPECTED_CORE_TRACE_SHA"
log "actual_coreservices_trace_sha256=$CORE_TRACE_BEFORE"
log "expected_security_interposer_sha256=$EXPECTED_SEC_SHA"
log "actual_security_interposer_sha256=$SEC_BEFORE"
log "expected_cgs_interposer_sha256=$EXPECTED_CGS_SHA"
log "actual_cgs_interposer_sha256=$CGS_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$CG_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || die 68 "CoreGraphics baseline hash mismatch"
[ "$SUBJECT_BEFORE" = "$EXPECTED_SUBJECT_SHA" ] || die 68 "subject hash mismatch"
[ "$CORE_TRACE_BEFORE" = "$EXPECTED_CORE_TRACE_SHA" ] || die 68 "CoreServices trace hash mismatch"
[ "$SEC_BEFORE" = "$EXPECTED_SEC_SHA" ] || die 68 "Security interposer hash mismatch"
[ "$CGS_BEFORE" = "$EXPECTED_CGS_SHA" ] || die 68 "CGS interposer hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

for p in "$SUBJECT" "$CORE_TRACE" "$SEC_INTERPOSER" "$CGS_INTERPOSER"; do
    has_ppc32_arch "$p" || die 67 "required artifact is not 32-bit PPC: $p"
done

/usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_SUBJECT_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID" || die 68 "subject build marker missing"
/usr/bin/strings "$CORE_TRACE" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_TRACE_BUILD_ID" || die 68 "CoreServices trace build marker missing"
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || die 68 "Security build marker missing"
/usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_CGS_BUILD_ID" || die 68 "CGS build marker missing"

for image in "$COREGRAPHICS" "$CARBONCORE" "$SECURITY" "$LAUNCHSERVICES" "$HISERVICES" "$LIBSYSTEM"; do
    /usr/bin/grep -Fq "$image" "$ROSETTA_CACHE_MAP" || die 68 "required image absent from Rosetta cache map: $image"
done

OT="$(/usr/bin/otool -l "$SUBJECT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

CORE_ABS="$(abspath "$CORE_TRACE")"
SEC_ABS="$(abspath "$SEC_INTERPOSER")"
CGS_ABS="$(abspath "$CGS_INTERPOSER")"
[ -n "$CORE_ABS" ] || die 68 "could not resolve CoreServices trace path"
[ -n "$SEC_ABS" ] || die 68 "could not resolve Security interposer path"
[ -n "$CGS_ABS" ] || die 68 "could not resolve CGS interposer path"
INSERTED="$CORE_ABS:$SEC_ABS:$CGS_ABS"
log "coreservices_trace_absolute_path=$CORE_ABS"
log "security_interposer_absolute_path=$SEC_ABS"
log "cgs_interposer_absolute_path=$CGS_ABS"

MARKER="$(/usr/bin/mktemp /tmp/lion-cgs-connection-trace-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC PASSIVE CGS CONNECTION TRACE RUN =="
log "+ ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 DYLD_INSERT_LIBRARIES=$INSERTED DYLD_SHARED_CACHE_DONT_VALIDATE=1 $SUBJECT"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 \
DYLD_INSERT_LIBRARIES="$INSERTED" \
DYLD_SHARED_CACHE_DONT_VALIDATE=1 \
DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 \
"$SUBJECT" > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "cgs_connection_trace_exec_status=$RC"

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
[ "$(sha256 "$COREGRAPHICS")" = "$CG_BEFORE" ] || die 70 "CoreGraphics changed"
[ "$(sha256 "$CARBONCORE")" = "$CARBONCORE_BEFORE" ] || die 70 "CarbonCore changed"
[ "$(sha256 "$SECURITY")" = "$SECURITY_BEFORE" ] || die 70 "Security changed"
[ "$(sha256 "$LAUNCHSERVICES")" = "$LAUNCHSERVICES_BEFORE" ] || die 70 "LaunchServices changed"
[ "$(sha256 "$HISERVICES")" = "$HISERVICES_BEFORE" ] || die 70 "HIServices changed"
[ "$(sha256 "$LIBSYSTEM")" = "$LIBSYSTEM_BEFORE" ] || die 70 "libSystem changed"
[ "$(sha256 "$SUBJECT")" = "$SUBJECT_BEFORE" ] || die 70 "subject changed"
[ "$(sha256 "$CORE_TRACE")" = "$CORE_TRACE_BEFORE" ] || die 70 "CoreServices trace changed"
[ "$(sha256 "$SEC_INTERPOSER")" = "$SEC_BEFORE" ] || die 70 "Security interposer changed"
[ "$(sha256 "$CGS_INTERPOSER")" = "$CGS_BEFORE" ] || die 70 "CGS interposer changed"
log "protected_hashes_unchanged=YES"

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M05_BEFORE_GetProcessForPID' "$RAW_LOG"; then
    log "RESULT: TRACE_DID_NOT_REACH_GETPROCESSFORPID"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
    log "RESULT: TRACE_SESSION_BOOTSTRAP_ADAPTER_NOT_PASSED"
    exit 1
fi

if /usr/bin/grep -Fq 'kind=DEATHWATCH' "$RAW_LOG"; then
    if /usr/bin/grep -Fq 'kind=DEATHWATCH kr=0 hex=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'id=0x000071b0 expected=0x000071b0 idMatch=YES' "$RAW_LOG"; then
        log "deathwatch_optional_status=PASS"
    else
        log "deathwatch_optional_status=OBSERVED_NONPASS"
    fi
else
    log "deathwatch_optional_status=NOT_OBSERVED_EXPECTED_REGISTRATION_PATH"
fi

if ! /usr/bin/grep -Fq 'kind=NEW_CONNECTION' "$RAW_LOG"; then
    log "RESULT: CGS_TRACE_NO_NEWCONNECTION_AFTER_SESSION_ADAPTER"
    exit 0
fi

if ! /usr/bin/grep -Fq 'kind=NEW_CONNECTION kr=0 hex=0x00000000' "$RAW_LOG"; then
    log "RESULT: CGS_TRACE_NEWCONNECTION_MACH_FAILURE"
    exit 0
fi

if ! /usr/bin/grep -Fq 'id=0x000074cd expected=0x000074cd idMatch=YES' "$RAW_LOG"; then
    log "RESULT: CGS_TRACE_NEWCONNECTION_REPLY_ID_MISMATCH"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M06_AFTER_GetProcessForPID' "$RAW_LOG"; then
    if /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_RESULT:CONNECTION_NONZERO' "$RAW_LOG"; then
        log "RESULT: CGS_TRACE_CONNECTION_ESTABLISHED"
        exit 0
    fi
    log "RESULT: CGS_TRACE_GETPROCESSFORPID_RETURNED_AFTER_NEWCONNECTION"
    exit 0
fi

if [ "$RC" -eq 1 ] && [ "$FOUND" -eq 0 ]; then
    log "RESULT: CGS_TRACE_NEWCONNECTION_REPLY_OBSERVED_CLEAN_EARLY_EXIT_RC1"
    exit 0
fi

log "RESULT: CGS_TRACE_NEWCONNECTION_REPLY_OBSERVED_PROCESS_STOPPED rc=$RC diagnostics=$FOUND"
exit 0
