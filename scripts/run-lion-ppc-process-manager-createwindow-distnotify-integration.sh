#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUBJECT="${1:-$ROOT/payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
SUBJECT_SHA_FILE="${2:-$SUBJECT.sha256}"
CORE_COMPAT="${3:-$ROOT/payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
SEC_INTERPOSER="${5:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
CGS_INTERPOSER="${7:-$ROOT/payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib}"
CGS_SHA_FILE="${8:-$CGS_INTERPOSER.sha256}"
BROKER="${9:-$ROOT/native-distributed-notifications-ppc-ingress-broker}"
BROKER_SHA_FILE="${10:-$BROKER.sha256}"
REPORT="${11:-$ROOT/payload/lion-ppc-process-manager-createwindow-distnotify-integration.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-createwindow-distnotify-integration.raw.log"

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
DISTNOTED="/usr/sbin/distnoted"
LIBXPC="/usr/lib/system/libxpc.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_COREGRAPHICS_SHA="fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192"
EXPECTED_SUBJECT_BUILD_ID="cps-createwindow-validation-v1"
EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-v1"
EXPECTED_SEC_BUILD_ID="security-session-auditinfo-api-v1"
EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-compat-v1"
EXPECTED_BROKER_BUILD_ID="distributed-notifications-ppc-ingress-broker-v1"
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

log "== Lion PPC restored-stack CreateNewWindow distributed-notifications integration =="
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
         ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE \
         ROSETTA_CPS_REGISTRATION_COMPAT_MODE ROSETTA_CPS_SETFRONT_COMPAT_MODE \
         ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH \
         ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" \
         "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS" "$CARBONCORE" \
         "$SECURITY" "$LAUNCHSERVICES" "$HISERVICES" "$LIBSYSTEM" "$DISTNOTED" "$LIBXPC" \
         "$SUBJECT" "$SUBJECT_SHA_FILE" "$CORE_COMPAT" "$CORE_COMPAT_SHA_FILE" \
         "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$CGS_INTERPOSER" "$CGS_SHA_FILE" \
         "$BROKER" "$BROKER_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_SUBJECT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SUBJECT_SHA_FILE")"
EXPECTED_CORE_COMPAT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_COMPAT_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"
EXPECTED_CGS_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CGS_SHA_FILE")"
EXPECTED_BROKER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$BROKER_SHA_FILE")"

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
DISTNOTED_BEFORE="$(sha256 "$DISTNOTED")"
LIBXPC_BEFORE="$(sha256 "$LIBXPC")"
BROKER_BEFORE="$(sha256 "$BROKER")"
SUBJECT_BEFORE="$(sha256 "$SUBJECT")"
CORE_COMPAT_BEFORE="$(sha256 "$CORE_COMPAT")"
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
log "distnoted_sha256_before=$DISTNOTED_BEFORE"
log "libxpc_sha256_before=$LIBXPC_BEFORE"
log "expected_subject_sha256=$EXPECTED_SUBJECT_SHA"
log "actual_subject_sha256=$SUBJECT_BEFORE"
log "expected_coreservices_cps_registration_compat_sha256=$EXPECTED_CORE_COMPAT_SHA"
log "actual_coreservices_cps_registration_compat_sha256=$CORE_COMPAT_BEFORE"
log "expected_security_interposer_sha256=$EXPECTED_SEC_SHA"
log "actual_security_interposer_sha256=$SEC_BEFORE"
log "expected_cgs_interposer_sha256=$EXPECTED_CGS_SHA"
log "actual_cgs_interposer_sha256=$CGS_BEFORE"
log "expected_broker_sha256=$EXPECTED_BROKER_SHA"
log "actual_broker_sha256=$BROKER_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$CG_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || die 68 "CoreGraphics baseline hash mismatch"
[ "$SUBJECT_BEFORE" = "$EXPECTED_SUBJECT_SHA" ] || die 68 "subject hash mismatch"
[ "$CORE_COMPAT_BEFORE" = "$EXPECTED_CORE_COMPAT_SHA" ] || die 68 "CoreServices CPS registration compatibility hash mismatch"
[ "$SEC_BEFORE" = "$EXPECTED_SEC_SHA" ] || die 68 "Security interposer hash mismatch"
[ "$CGS_BEFORE" = "$EXPECTED_CGS_SHA" ] || die 68 "CGS interposer hash mismatch"
[ "$BROKER_BEFORE" = "$EXPECTED_BROKER_SHA" ] || die 68 "broker hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

for p in "$SUBJECT" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER"; do
    has_ppc32_arch "$p" || die 67 "required artifact is not 32-bit PPC: $p"
done

BROKER_ARCH="$(/usr/bin/lipo -info "$BROKER" 2>/dev/null || true)"
echo "$BROKER_ARCH" | /usr/bin/grep -Eq '(^|[[:space:]])i386([[:space:]]|$)' ||
    die 67 "broker is not i386"

/usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq \
    "PM_CPS_CREATEWINDOW_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID" || die 68 "subject build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_COMPAT_BUILD_ID" || die 68 "CoreServices CPS registration compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:distributed-notifications-ppc-ingress-interposer-v2" || die 68 "embedded distributed-notifications ingress marker missing"
/usr/bin/strings "$BROKER" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:$EXPECTED_BROKER_BUILD_ID" || die 68 "broker build marker missing"
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

CORE_ABS="$(abspath "$CORE_COMPAT")"
SEC_ABS="$(abspath "$SEC_INTERPOSER")"
CGS_ABS="$(abspath "$CGS_INTERPOSER")"
BROKER_ABS="$(abspath "$BROKER")"
[ -n "$CORE_ABS" ] || die 68 "could not resolve CoreServices CPS registration compatibility path"
[ -n "$SEC_ABS" ] || die 68 "could not resolve Security interposer path"
[ -n "$CGS_ABS" ] || die 68 "could not resolve CGS interposer path"
[ -n "$BROKER_ABS" ] || die 68 "could not resolve native notification broker path"
INSERTED="$CORE_ABS:$SEC_ABS:$CGS_ABS"
log "coreservices_cps_registration_compat_absolute_path=$CORE_ABS"
log "security_interposer_absolute_path=$SEC_ABS"
log "cgs_interposer_absolute_path=$CGS_ABS"
log "distributed_notifications_broker_absolute_path=$BROKER_ABS"

MARKER="$(/usr/bin/mktemp /tmp/lion-createwindow-validation-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC RESTORED-STACK CREATENEWWINDOW + DISTRIBUTED-NOTIFICATIONS INTEGRATION RUN =="
log "+ ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1 ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1 ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=lion-ppc-ingress-v1 ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH=$BROKER_ABS DYLD_INSERT_LIBRARIES=$INSERTED DYLD_SHARED_CACHE_DONT_VALIDATE=1 $SUBJECT"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 \
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1 \
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1 \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=lion-ppc-ingress-v1 \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH="$BROKER_ABS" \
DYLD_INSERT_LIBRARIES="$INSERTED" \
DYLD_SHARED_CACHE_DONT_VALIDATE=1 \
DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 \
"$SUBJECT" > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "createwindow_validation_exec_status=$RC"

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
[ "$(sha256 "$DISTNOTED")" = "$DISTNOTED_BEFORE" ] || die 70 "distnoted changed"
[ "$(sha256 "$LIBXPC")" = "$LIBXPC_BEFORE" ] || die 70 "libxpc changed"
[ "$(sha256 "$BROKER")" = "$BROKER_BEFORE" ] || die 70 "broker changed"
[ "$(sha256 "$SUBJECT")" = "$SUBJECT_BEFORE" ] || die 70 "subject changed"
[ "$(sha256 "$CORE_COMPAT")" = "$CORE_COMPAT_BEFORE" ] || die 70 "CoreServices CPS registration compatibility changed"
[ "$(sha256 "$SEC_INTERPOSER")" = "$SEC_BEFORE" ] || die 70 "Security interposer changed"
[ "$(sha256 "$CGS_INTERPOSER")" = "$CGS_BEFORE" ] || die 70 "CGS interposer changed"
log "protected_hashes_unchanged=YES"

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M05_BEFORE_GetProcessForPID' "$RAW_LOG"; then
    log "RESULT: COMPAT_DID_NOT_REACH_GETPROCESSFORPID"
    exit 1
fi
if ! /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
    log "RESULT: COMPAT_SESSION_BOOTSTRAP_ADAPTER_NOT_PASSED"
    exit 1
fi
if ! /usr/bin/grep -Fq 'kind=SERVER_VERSION' "$RAW_LOG"; then
    log "RESULT: COMPAT_NO_SERVER_VERSION_AFTER_SESSION_ADAPTER"
    exit 0
fi
if ! /usr/bin/grep -Fq 'kind=SERVER_VERSION kr=0 hex=0x00000000' "$RAW_LOG"; then
    log "RESULT: COMPAT_SERVER_VERSION_MACH_FAILURE"
    exit 0
fi
if ! /usr/bin/grep -Fq 'id=0x000071ac expected=0x000071ac idMatch=YES' "$RAW_LOG"; then
    log "RESULT: COMPAT_SERVER_VERSION_REPLY_ID_MISMATCH"
    exit 0
fi
if ! /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:index=1 kind=SERVER_VERSION' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'off30=0x58020000' "$RAW_LOG"; then
    log "RESULT: COMPAT_SERVER_VERSION_ORIGINAL_VALUE_UNEXPECTED"
    exit 0
fi
if ! /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_CALL:index=1 mode=lion-server-version-v1' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'ndrSwapped=YES major=600 minor=0 aux=0x69333836 flags=0x00000001' "$RAW_LOG"; then
    log "RESULT: COMPAT_SERVER_VERSION_POLICY_PREDICATE_NOT_MET"
    exit 0
fi
if ! /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_ADAPTER:index=1 originalMajor=600 originalMinor=0 adaptedMajor=545 adaptedMinor=0 changedBytes=1 outsideVersionBytesChanged=0 raw30Before=0x58020000 raw30After=0x21020000 raw34Before=0x00000000 raw34After=0x00000000' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
    log "RESULT: COMPAT_SERVER_VERSION_ADAPTER_NOT_PASSED"
    exit 0
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
    if [ "$RC" -eq 1 ] && [ "$FOUND" -eq 0 ]; then
        log "RESULT: CGS_SERVER_VERSION_COMPAT_ADAPTER_PASS_NO_NEWCONNECTION_CLEAN_RC1"
        exit 0
    fi
    log "RESULT: CGS_SERVER_VERSION_COMPAT_ADAPTER_PASS_NO_NEWCONNECTION rc=$RC diagnostics=$FOUND"
    exit 0
fi

if ! /usr/bin/grep -Fq 'kind=NEW_CONNECTION kr=0 hex=0x00000000' "$RAW_LOG"; then
    log "RESULT: CGS_SERVER_VERSION_COMPAT_NEWCONNECTION_MACH_FAILURE"
    exit 0
fi

if ! /usr/bin/grep -Fq 'id=0x000074cd expected=0x000074cd idMatch=YES' "$RAW_LOG"; then
    log "RESULT: CGS_SERVER_VERSION_COMPAT_NEWCONNECTION_REPLY_ID_MISMATCH"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M06_AFTER_GetProcessForPID' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_POSTIDENTITY_CONNECTION_OR_IDENTITY_PREREQUISITE_REGRESSION"
    exit 0
fi

if /usr/bin/grep -Fq '_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304' "$RAW_LOG"; then
    log "registerapplication_err_minus304_observed=YES"
else
    log "registerapplication_err_minus304_observed=NO"
fi

if ! /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'id=0x00007372 expectedReply=0x000073d6' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_LEGACY_REQUEST_NOT_OBSERVED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=lion-create-application-v1 exact=YES' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_PREDICATE_NOT_MET"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x00007372 lionId=0x000073c1 legacySend=0x00000084 lionSend=0x00000090 changedCommonBytes=1 sourceChangedBytes=0 tailByte=0x00 tailU32_0=0x00000000 tailU32_1=0x00000010' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_NATIVE_MACH_FAILURE"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x00007425 result=0 ndrSwapped=YES raw20=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_NATIVE_REPLY_REJECTED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x00007425 legacyId=0x000073d6 size=0x00000024 changedBytes=2 result=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_REPLY_ADAPTER_NOT_PASSED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION kr=0 hex=0x00000000' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'id=0x000073d6 expected=0x000073d6 idMatch=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'off20=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_LEGACY_FACING_REPLY_NOT_ACCEPTED"
    exit 0
fi

if /usr/bin/grep -Fq '_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_ADAPTER_PASS_ERR_MINUS304_PERSISTS"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_POSTIDENTITY_GETPROCESSFORPID_REGRESSION"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M07_BEFORE_GetProcessPID' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M08_AFTER_GetProcessPID' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_POSTIDENTITY_GETPROCESSPID_NO_RETURN"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetProcessPID=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_POSTIDENTITY_ROUNDTRIP:self=[0-9]+ returned=[0-9]+ match=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_POSTIDENTITY_GETPROCESSPID_FAILED"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M09_BEFORE_TransformProcessType' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M10_AFTER_TransformProcessType' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_TRANSFORM_NO_RETURN"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:TransformProcessType=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_TRANSFORM_PREREQUISITE_FAILED"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=2' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_SECOND_REGISTRATION_CALL"
    exit 0
fi

if /usr/bin/grep -Fq '_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_REGISTRATION_DIAGNOSTIC_RECURRED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_SETFRONTPROCESS_NOT_REACHED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_CALL:index=1 mode=lion-setfront-v1 exact=YES' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_PREDICATE_NOT_MET"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x0000729e lionId=0x000072a1 send=0x00000030 recv=0x0000002c changedBytes=1 sourceChangedBytes=0 psnHigh=0x00000000' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'arg2=0x00000000 arg3=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_NATIVE_MACH_FAILURE"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x00007305 result=0 ndrSwapped=YES raw20=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_NATIVE_REPLY_REJECTED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x00007305 legacyId=0x00007302 size=0x00000024 changedBytes=1 result=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_REPLY_ADAPTER_NOT_PASSED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'id=0x0000729e expectedReply=0x00007302' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'option=0x00000003 send=0x00000030 recv=0x0000002c' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'id=0x00007302 expected=0x00007302 idMatch=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY off18=0x00000000 off1c=0x01000000 off20=0x00000000' "$RAW_LOG"; then
    log "RESULT: CPS_SETFRONT_COMPAT_LEGACY_FACING_REPLY_NOT_ACCEPTED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:SetFrontProcess=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M13_SETFRONTPROCESS_SUCCESS' "$RAW_LOG"; then
    log "RESULT: GETFRONTPROCESS_SETFRONT_PREREQUISITE_FAILED"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_CALL:index=2' "$RAW_LOG"; then
    log "RESULT: GETFRONTPROCESS_SECOND_SETFRONT_CALL"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=2' "$RAW_LOG"; then
    log "RESULT: GETFRONTPROCESS_SECOND_REGISTRATION_CALL"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M14_BEFORE_GetFrontProcess' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M15_AFTER_GetFrontProcess' "$RAW_LOG"; then
    log "RESULT: GETCURRENTPROCESS_GETFRONT_NO_RETURN"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetFrontProcess=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_POSTIDENTITY_FRONT_PSN:expectedHigh=0x[0-9a-fA-F]+ expectedLow=0x[0-9a-fA-F]+ returnedHigh=0x[0-9a-fA-F]+ returnedLow=0x[0-9a-fA-F]+ match=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETFRONTPROCESS_MATCH_PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M16_GETFRONTPROCESS_SUCCESS' "$RAW_LOG"; then
    log "RESULT: GETCURRENTPROCESS_GETFRONT_PREREQUISITE_FAILED"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M17_BEFORE_GetCurrentProcess' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M18_AFTER_GetCurrentProcess' "$RAW_LOG"; then
    log "RESULT: CREATEWINDOW_GETCURRENTPROCESS_NO_RETURN"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetCurrentProcess=0' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_POSTIDENTITY_CURRENT_PSN:expectedHigh=0x[0-9a-fA-F]+ expectedLow=0x[0-9a-fA-F]+ returnedHigh=0x[0-9a-fA-F]+ returnedLow=0x[0-9a-fA-F]+ match=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETCURRENTPROCESS_MATCH_PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M19_GETCURRENTPROCESS_SUCCESS' "$RAW_LOG"; then
    log "RESULT: CREATEWINDOW_GETCURRENTPROCESS_PREREQUISITE_FAILED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:index=1 mode=lion-ppc-ingress-v1 name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_INGRESS_NOT_ESTABLISHED"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M21_AFTER_CreateNewWindow' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_NO_RETURN"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_NOT_REACHED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:CreateNewWindow=0' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_RETURNED_ERROR"
    exit 0
fi

if ! /usr/bin/grep -Eq 'PM_POSTIDENTITY_WINDOW:pointer=0x[0-9a-fA-F]+ nonzero=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:CREATENEWWINDOW_PASS' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_NULL_OR_INVALID"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M22_BEFORE_DisposeWindow' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M23_AFTER_DisposeWindow' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISPOSE_OR_SUCCESS_MILESTONE_MISSING"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=2' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_SECOND_REGISTRATION_CALL"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_CALL:index=2' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_SECOND_SETFRONT_CALL"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REJECT:' "$RAW_LOG" ||
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_IPC_REQUEST:FAIL' "$RAW_LOG" ||
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_IPC_CALLBACK:REJECT' "$RAW_LOG" ||
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_PROTOCOL_REJECTED"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:pid=[0-9]+ exit=0$' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=[0-9]+ callbacks=[0-9]+$' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_LIFECYCLE_INCOMPLETE"
    exit 0
fi

if [ "$RC" -eq 0 ] && [ "$FOUND" -eq 0 ]; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_INTEGRATION_PASS"
    exit 0
fi

log "RESULT: CREATENEWWINDOW_PROCESS_STATE_UNEXPECTED rc=$RC diagnostics=$FOUND"
exit 0
