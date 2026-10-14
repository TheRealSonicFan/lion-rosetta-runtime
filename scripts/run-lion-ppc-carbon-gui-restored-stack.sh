#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-carbon-gui-smoketest-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_COMPAT="${3:-$ROOT/payload/pm-selectwindow-orderfront-compat.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
SEC_INTERPOSER="${5:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
CGS_INTERPOSER="${7:-$ROOT/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib}"
CGS_SHA_FILE="${8:-$CGS_INTERPOSER.sha256}"
BROKER="${9:-$ROOT/dn-runapplicationeventloop-remaining-registration-broker}"
BROKER_SHA_FILE="${10:-$BROKER.sha256}"
REPORT="${11:-$ROOT/payload/lion-ppc-carbon-gui-restored-stack.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="${REPORT%.log}.raw.log"

HITOOLBOX_EXTRAS_COMPAT="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH:-$ROOT/payload/ppc-hitoolbox-extras-resource-compat.dylib}"
HITOOLBOX_EXTRAS_SHA_FILE="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE:-$HITOOLBOX_EXTRAS_COMPAT.sha256}"
HITOOLBOX_EXTRAS_RESOURCE="${ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH:-$ROOT/payload/SnowLeopard-HIToolbox-Extras.rsrc}"
TITLEBAR_COMPAT="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH:-$ROOT/payload/pm-titlebar-bsearch-six-key-compat.dylib}"
TITLEBAR_SHA_FILE="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE:-$TITLEBAR_COMPAT.sha256}"

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
DISTNOTED="/usr/sbin/distnoted"
LIBXPC="/usr/lib/system/libxpc.dylib"
TITLEBAR_ARTFILE="/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"

EXPECTED_EXE_SHA="fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067"
EXPECTED_KERNEL_SHA="fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_COREGRAPHICS_SHA="fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192"
EXPECTED_CORE_COMPAT_SHA="28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578"
EXPECTED_SEC_SHA="9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51"
EXPECTED_CGS_SHA="f7dbcb98cbf5d64f95a33af222432d5a86ba273b475f5e3de83fff6d6c3c931b"
EXPECTED_BROKER_SHA="d7912d9761049f1382028ad0d16854915aa531fe0963df67be5678efb413b5d4"
EXPECTED_HITOOLBOX_EXTRAS_SHA="a5b385d29bb5a6d887122ba0b2a7b1e78c45a1b69bfceb687c9cb2c77cc70572"
EXPECTED_HITOOLBOX_RESOURCE_SHA="a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197"
EXPECTED_TITLEBAR_SHA="6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72"
EXPECTED_TITLEBAR_ARTFILE_SHA="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4"
EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-remaining-registration-broker-v1"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() {
    echo "$*" | /usr/bin/tee -a "$REPORT"
}

die() {
    code="$1"
    shift
    log "ERROR: $*"
    log "RESULT: PPC_CARBON_GUI_RESTORED_STACK_PRECHECK_FAIL"
    exit "$code"
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

sidecar_sha() {
    /usr/bin/awk 'NR==1 {print $1}' "$1"
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

verify_hash_pair() {
    file="$1"
    sha_file="$2"
    expected="$3"
    label="$4"
    [ -f "$file" ] || die 66 "missing $label: $file"
    [ -f "$sha_file" ] || die 66 "missing $label SHA sidecar: $sha_file"
    actual="$(sha256 "$file")"
    declared="$(sidecar_sha "$sha_file")"
    log "${label}_sha256=$actual"
    [ "$actual" = "$expected" ] || die 68 "$label hash mismatch"
    [ "$declared" = "$expected" ] || die 68 "$label sidecar hash mismatch"
}

log "== Lion original PPC Carbon GUI restored-stack retest =="
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
[ "$BUILD_VERSION" = "11G63" ] || die 65 "requires Lion build 11G63"
[ -n "$CURRENT_USER" ] || die 65 "could not determine current user"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || die 65 "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || die 65 "WindowServer is not running"

[ "${ROSETTA_EXPECTED_KERNEL_SHA256:-}" = "$EXPECTED_KERNEL_SHA" ] ||
    die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the accepted Lion kernel hash"
[ -f /mach_kernel ] || die 66 "missing /mach_kernel"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
log "mach_kernel_sha256_before=$KERNEL_BEFORE"
[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"
[ -x "$TRANSLATOR" ] || die 66 "missing translator"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"

verify_hash_pair "$EXE" "$EXE_SHA_FILE" "$EXPECTED_EXE_SHA" "subject"
verify_hash_pair "$CORE_COMPAT" "$CORE_COMPAT_SHA_FILE" "$EXPECTED_CORE_COMPAT_SHA" "coreservices_compat"
verify_hash_pair "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$EXPECTED_SEC_SHA" "security_interposer"
verify_hash_pair "$CGS_INTERPOSER" "$CGS_SHA_FILE" "$EXPECTED_CGS_SHA" "cgs_interposer"
verify_hash_pair "$BROKER" "$BROKER_SHA_FILE" "$EXPECTED_BROKER_SHA" "distributed_notifications_broker"
verify_hash_pair "$HITOOLBOX_EXTRAS_COMPAT" "$HITOOLBOX_EXTRAS_SHA_FILE" "$EXPECTED_HITOOLBOX_EXTRAS_SHA" "hitoolbox_extras_compat"
verify_hash_pair "$TITLEBAR_COMPAT" "$TITLEBAR_SHA_FILE" "$EXPECTED_TITLEBAR_SHA" "titlebar_compat"

[ -f "$HITOOLBOX_EXTRAS_RESOURCE" ] || die 66 "missing Snow HIToolbox Extras resource"
HITOOLBOX_RESOURCE_SHA="$(sha256 "$HITOOLBOX_EXTRAS_RESOURCE")"
log "hitoolbox_extras_resource_sha256=$HITOOLBOX_RESOURCE_SHA"
[ "$HITOOLBOX_RESOURCE_SHA" = "$EXPECTED_HITOOLBOX_RESOURCE_SHA" ] ||
    die 68 "HIToolbox Extras resource hash mismatch"

[ -f "$TITLEBAR_ARTFILE" ] || die 66 "missing CoreUI ArtFile"
TITLEBAR_ARTFILE_SHA="$(sha256 "$TITLEBAR_ARTFILE")"
log "coreui_titlebar_artfile_sha256=$TITLEBAR_ARTFILE_SHA"
[ "$TITLEBAR_ARTFILE_SHA" = "$EXPECTED_TITLEBAR_ARTFILE_SHA" ||
    die 68 "CoreUI ArtFile hash mismatch"

for p in "$EXE" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER" "$HITOOLBOX_EXTRAS_COMPAT" "$TITLEBAR_COMPAT"; do
    has_ppc32_arch "$p" || die 67 "required artifact is not 32-bit PPC: $p"
done
BROKER_ARCH="$(/usr/bin/lipo -info "$BROKER" 2>/dev/null || true)"
echo "$BROKER_ARCH" | /usr/bin/grep -Eq '(^|[[:space:]])i386([[:space:]]|$)' ||
    die 67 "distributed-notifications broker is not i386"
/usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$EXPECTED_BROKER_BUILD_ID" ||
    die 68 "distributed-notifications broker build marker missing"

if [ -x /usr/bin/otool ]; then
    OTOOL_OUT="$(/usr/bin/otool -l "$EXE" 2>&1 | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
    echo "$OTOOL_OUT" | /usr/bin/tee -a "$REPORT"
    echo "$OTOOL_OUT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' ||
        die 68 "subject LC_LOAD_DYLINKER is not /usr/oah/dyld"
    /usr/bin/otool -L "$EXE" | /usr/bin/grep -Fq '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' ||
        die 68 "subject Carbon dependency is absent"
fi

for p in "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS" "$CARBONCORE" "$SECURITY" "$LAUNCHSERVICES" "$HISERVICES" "$DISTNOTED" "$LIBXPC"; do
    [ -f "$p" ] || die 66 "missing protected runtime path: $p"
done

PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"
COREGRAPHICS_BEFORE="$(sha256 "$COREGRAPHICS")"
CARBONCORE_BEFORE="$(sha256 "$CARBONCORE")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
LAUNCHSERVICES_BEFORE="$(sha256 "$LAUNCHSERVICES")"
HISERVICES_BEFORE="$(sha256 "$HISERVICES")"
DISTNOTED_BEFORE="$(sha256 "$DISTNOTED")"
LIBXPC_BEFORE="$(sha256 "$LIBXPC")"

log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256_before=$CACHE_MAP_BEFORE"
log "coregraphics_sha256_before=$COREGRAPHICS_BEFORE"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_BEFORE" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$COREGRAPHICS_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || die 68 "CoreGraphics hash mismatch"

unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_SCHEMA_AUDIT_REPORT

if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
else
    log "core_dump_limit could not be raised; continuing with normal crash reporting"
fi
MARKER="$(/usr/bin/mktemp /tmp/lion-ppc-carbon-gui-restored-stack.XXXXXX)" ||
    die 73 "could not create diagnostic marker"

INSERT_LIBS="$CORE_COMPAT:$SEC_INTERPOSER:$CGS_INTERPOSER:$HITOOLBOX_EXTRAS_COMPAT:$TITLEBAR_COMPAT"
log ""
log "== SINGLE ORIGINAL PPC CARBON GUI RESTORED-STACK RUN =="
log "subject_sha256=$EXPECTED_EXE_SHA"
log "distributed_notifications_policy=exact-21"
log "compatibility_policy=accepted-restored-stack-only"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 \
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1 \
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1 \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=lion-ppc-ingress-v1 \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH="$BROKER" \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1 \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_REGISTRATION_MODE=lion-remaining-register-v1 \
ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1 \
ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1 \
ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1 \
ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1 \
ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1 \
ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1 \
ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1 \
ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1 \
ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1 \
ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-selectwindow-id-v1 \
ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=lion-id-v1 \
ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=lion-id-v1 \
ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=lion-id-v1 \
ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=lion-id-v1 \
ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$HITOOLBOX_EXTRAS_COMPAT" \
ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$HITOOLBOX_EXTRAS_SHA_FILE" \
ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$HITOOLBOX_EXTRAS_RESOURCE" \
ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1 \
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$TITLEBAR_COMPAT" \
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$TITLEBAR_SHA_FILE" \
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=lion-exact-six-v1 \
DYLD_INSERT_LIBRARIES="$INSERT_LIBS" \
DYLD_SHARED_CACHE_DONT_VALIDATE=1 \
DYLD_PRINT_LIBRARIES=1 \
"$EXE" > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "carbon_gui_exec_status=$RC"

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
KERNEL_AFTER="$(sha256 /mach_kernel)"
TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"
PRIVATE_AFTER="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_AFTER="$(sha256 "$SYSTEM_DYLD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_AFTER="$(sha256 "$ROSETTA_CACHE_MAP")"
COREGRAPHICS_AFTER="$(sha256 "$COREGRAPHICS")"
CARBONCORE_AFTER="$(sha256 "$CARBONCORE")"
SECURITY_AFTER="$(sha256 "$SECURITY")"
LAUNCHSERVICES_AFTER="$(sha256 "$LAUNCHSERVICES")"
HISERVICES_AFTER="$(sha256 "$HISERVICES")"
DISTNOTED_AFTER="$(sha256 "$DISTNOTED")"
LIBXPC_AFTER="$(sha256 "$LIBXPC")"

PROTECTED_HASHES_UNCHANGED=YES
[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$CACHE_MAP_AFTER" = "$CACHE_MAP_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$COREGRAPHICS_AFTER" = "$COREGRAPHICS_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$CARBONCORE_AFTER" = "$CARBONCORE_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$SECURITY_AFTER" = "$SECURITY_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$LAUNCHSERVICES_AFTER" = "$LAUNCHSERVICES_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$HISERVICES_AFTER" = "$HISERVICES_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$DISTNOTED_AFTER" = "$DISTNOTED_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$LIBXPC_AFTER" = "$LIBXPC_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
log "protected_hashes_unchanged=$PROTECTED_HASHES_UNCHANGED"

WINDOW_MARKER_COUNT="$(/usr/bin/grep -c '^Rosetta PPC Carbon GUI window shown:' "$RAW_LOG" 2>/dev/null || true)"
SMOKE_MARKER_COUNT="$(/usr/bin/grep -c '^Rosetta PPC Carbon GUI smoke test:' "$RAW_LOG" 2>/dev/null || true)"
REGISTER_ACCEPT_COUNT="$(/usr/bin/grep -c '^PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:' "$RAW_LOG" 2>/dev/null || true)"
BROKER_SUMMARY_COUNT="$(/usr/bin/grep -c '^PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=21 callback=0 rejects=0 exact=YES$' "$RAW_LOG" 2>/dev/null || true)"
BROKER_PASS_COUNT="$(/usr/bin/grep -c '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS$' "$RAW_LOG" 2>/dev/null || true)"
BROKER_REJECT_COUNT="$(/usr/bin/grep -c '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG" 2>/dev/null || true)"
REQUEST22_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_(PPC_INGRESS_MACH_REQUEST|CREATEWINDOW_REGISTER_ACCEPT):index=22([[:space:]]|$)' "$RAW_LOG" 2>/dev/null || true)"
INGRESS_EXIT_COUNT="$(/usr/bin/grep -Ec '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=21 callbacks=0$' "$RAW_LOG" 2>/dev/null || true)"

SEC_PASS_COUNT="$(/usr/bin/grep -c 'PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
SESSION_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SERVER_VERSION_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_PASS_COUNT="$(/usr/bin/grep -c '^PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPS_SETFRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
DOCK_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
NEWWINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RELEASE_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
OPACITY_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "window_backing_info_adapter_pass_count=$WBI_PASS_COUNT"
log "fontserver_bootstrap_adapter_pass_count=$FONTSERVER_PASS_COUNT"
log "fontserver_rendezvous_adapter_pass_count=$RENDEZVOUS_PASS_COUNT"
log "color_profile_client_adapter_pass_count=$CPC_PASS_COUNT"
log "color_profile_resolve_adapter_pass_count=$CPR_PASS_COUNT"
log "add_tracking_area_adapter_pass_count=$ADD_TRACKING_PASS_COUNT"
log "set_front_window_adapter_pass_count=$SET_FRONT_WINDOW_PASS_COUNT"
log "order_front_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
log "titlebar_translated_count=$TITLEBAR_TRANSLATED_COUNT"
log "titlebar_guard_reject_count=$TITLEBAR_GUARD_REJECT_COUNT"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ]; then
    log "RESULT: PPC_CARBON_GUI_RESTORED_STACK_PASS"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_RESTORED_STACK_INCOMPLETE"
log "RESULT: FAIL"
exit 1
