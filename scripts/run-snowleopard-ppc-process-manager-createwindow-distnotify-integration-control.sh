#!/bin/bash
set -u

SUBJECT="${1:-./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
SUBJECT_SHA_FILE="${2:-$SUBJECT.sha256}"
CORE_COMPAT="${3:-./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
SEC_INTERPOSER="${5:-./ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
CGS_INTERPOSER="${7:-./ppc-process-manager-cgs-session-bootstrap-compat.dylib}"
CGS_SHA_FILE="${8:-$CGS_INTERPOSER.sha256}"
LOG="${9:-./ppc-process-manager-createwindow-distnotify-integration-snowleopard-control.log}"
HITOOLBOX_TRACE="${ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH:-}"
HITOOLBOX_TRACE_SHA_FILE="${ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE:-}"
HITOOLBOX_EXTRAS_COMPAT="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH:-}"
HITOOLBOX_EXTRAS_COMPAT_SHA_FILE="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE:-}"
HITOOLBOX_EXTRAS_RESOURCE="${ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH:-}"
HITOOLBOX_EXTRAS_MODE="${ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE:-}"
DOCKSERVER_COMPAT_MODE="${ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE:-}"
NEWWINDOW_TRACE_MODE="${ROSETTA_CGS_NEWWINDOW_TRACE_MODE:-}"
NEWWINDOW_COMPAT_MODE="${ROSETTA_CGS_NEWWINDOW_COMPAT_MODE:-}"
RELEASEBACKING_TRACE_MODE="${ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE:-}"
RELEASEBACKING_COMPAT_MODE="${ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE:-}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_SUBJECT_BUILD_ID="cps-createwindow-validation-v1"
EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-v1"
EXPECTED_SEC_BUILD_ID="security-session-auditinfo-api-v1"
EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-compat-v1"
EXPECTED_HITOOLBOX_TRACE_BUILD_ID="hitoolbox-cfbundle-resource-trace-v1"
EXPECTED_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID="hitoolbox-extras-resource-compat-v1"
EXPECTED_HITOOLBOX_EXTRAS_RESOURCE_SHA="a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$LOG" >&2
    exit 1
}

if [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
    [ "$DOCKSERVER_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow DockServer compatibility mode must be passthrough"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-compat-v2"
fi
if [ -n "$NEWWINDOW_TRACE_MODE" ]; then
    [ "$NEWWINDOW_TRACE_MODE" = "passthrough" ] ||
        fail "Snow CGS NewWindow trace mode must be passthrough"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-trace-v1"
fi
if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    [ "$NEWWINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGS NewWindow compatibility mode must be passthrough"
    [ -z "$NEWWINDOW_TRACE_MODE" ] ||
        fail "Snow NewWindow compatibility and passive-trace runner modes are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-v1"
fi
if [ -n "$RELEASEBACKING_TRACE_MODE" ]; then
    [ "$RELEASEBACKING_TRACE_MODE" = "passthrough" ] ||
        fail "Snow post-NewWindow release-backing trace mode must be passthrough"
    [ "$NEWWINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow post-NewWindow release-backing trace requires NewWindow compatibility passthrough mode"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-trace-v1"
fi
if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    [ "$RELEASEBACKING_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow release-backing compatibility mode must be passthrough"
    [ "$NEWWINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow release-backing compatibility requires NewWindow compatibility passthrough mode"
    [ -z "$RELEASEBACKING_TRACE_MODE" ] ||
        fail "Snow release-backing compatibility and passive-trace runner modes are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-v1"
fi
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

: > "$LOG" || exit 73

if { [ -n "$HITOOLBOX_TRACE" ] && [ -z "$HITOOLBOX_TRACE_SHA_FILE" ]; } ||
   { [ -z "$HITOOLBOX_TRACE" ] && [ -n "$HITOOLBOX_TRACE_SHA_FILE" ]; }; then
    fail "set both ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH and ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE, or neither"
fi
if [ -n "$HITOOLBOX_TRACE" ] && [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    fail "HIToolbox trace and Extras compatibility modes are mutually exclusive"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ] || [ -n "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE" ] ||
   [ -n "$HITOOLBOX_EXTRAS_RESOURCE" ] || [ -n "$HITOOLBOX_EXTRAS_MODE" ]; then
    [ -n "$HITOOLBOX_EXTRAS_COMPAT" ] ||
        fail "set ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH"
    [ -n "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE" ] ||
        fail "set ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE"
    [ -n "$HITOOLBOX_EXTRAS_RESOURCE" ] ||
        fail "set ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH"
    [ "$HITOOLBOX_EXTRAS_MODE" = "snow-force-external-v1" ] ||
        fail "Snow Extras compatibility mode must be snow-force-external-v1"
fi

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$LOG"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"

CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$LOG"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

for v in CORESERVICESD_SERVICE_NAME SCDontUseServer LSDONOTABORTIFNOASN \
         ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE \
         ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE \
         ROSETTA_CPS_REGISTRATION_COMPAT_MODE ROSETTA_CPS_SETFRONT_COMPAT_MODE \
         ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH \
         ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || fail "$v must be unset before the runner"
done

for p in "$SUBJECT" "$SUBJECT_SHA_FILE" "$CORE_COMPAT" "$CORE_COMPAT_SHA_FILE" \
         "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$CGS_INTERPOSER" "$CGS_SHA_FILE" \
         "$PRIVATE_DYLD"; do
    [ -e "$p" ] || fail "missing required path: $p"
done
if [ -n "$HITOOLBOX_TRACE" ]; then
    [ -e "$HITOOLBOX_TRACE" ] || fail "missing HIToolbox trace dylib: $HITOOLBOX_TRACE"
    [ -e "$HITOOLBOX_TRACE_SHA_FILE" ] || fail "missing HIToolbox trace SHA file: $HITOOLBOX_TRACE_SHA_FILE"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    [ -e "$HITOOLBOX_EXTRAS_COMPAT" ] || fail "missing HIToolbox Extras compatibility dylib: $HITOOLBOX_EXTRAS_COMPAT"
    [ -e "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE" ] || fail "missing HIToolbox Extras compatibility SHA file: $HITOOLBOX_EXTRAS_COMPAT_SHA_FILE"
    [ -f "$HITOOLBOX_EXTRAS_RESOURCE" ] || fail "missing staged Snow Leopard Extras.rsrc: $HITOOLBOX_EXTRAS_RESOURCE"
fi

EXPECTED_SUBJECT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SUBJECT_SHA_FILE")"
EXPECTED_CORE_COMPAT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_COMPAT_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"
EXPECTED_CGS_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CGS_SHA_FILE")"
if [ -n "$HITOOLBOX_TRACE" ]; then
    EXPECTED_HITOOLBOX_TRACE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$HITOOLBOX_TRACE_SHA_FILE")"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    EXPECTED_HITOOLBOX_EXTRAS_COMPAT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE")"
fi

[ "$(sha256 "$SUBJECT")" = "$EXPECTED_SUBJECT_SHA" ] || fail "subject hash mismatch"
[ "$(sha256 "$CORE_COMPAT")" = "$EXPECTED_CORE_COMPAT_SHA" ] || fail "CoreServices CPS registration compatibility hash mismatch"
[ "$(sha256 "$SEC_INTERPOSER")" = "$EXPECTED_SEC_SHA" ] || fail "Security interposer hash mismatch"
[ "$(sha256 "$CGS_INTERPOSER")" = "$EXPECTED_CGS_SHA" ] || fail "CGS interposer hash mismatch"
[ "$(sha256 "$PRIVATE_DYLD")" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"
if [ -n "$HITOOLBOX_TRACE" ]; then
    [ "$(sha256 "$HITOOLBOX_TRACE")" = "$EXPECTED_HITOOLBOX_TRACE_SHA" ] ||
        fail "HIToolbox trace hash mismatch"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    [ "$(sha256 "$HITOOLBOX_EXTRAS_COMPAT")" = "$EXPECTED_HITOOLBOX_EXTRAS_COMPAT_SHA" ] ||
        fail "HIToolbox Extras compatibility hash mismatch"
    [ "$(sha256 "$HITOOLBOX_EXTRAS_RESOURCE")" = "$EXPECTED_HITOOLBOX_EXTRAS_RESOURCE_SHA" ] ||
        fail "staged Snow Leopard Extras.rsrc hash mismatch"
fi

for p in "$SUBJECT" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER"; do
    has_ppc32_arch "$p" || fail "required artifact is not 32-bit PPC: $p"
done
if [ -n "$HITOOLBOX_TRACE" ]; then
    has_ppc32_arch "$HITOOLBOX_TRACE" || fail "HIToolbox trace is not 32-bit PPC"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    has_ppc32_arch "$HITOOLBOX_EXTRAS_COMPAT" || fail "HIToolbox Extras compatibility dylib is not 32-bit PPC"
fi

/usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq \
    "PM_CPS_CREATEWINDOW_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID" || fail "subject build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_COMPAT_BUILD_ID" || fail "CoreServices CPS registration compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:distributed-notifications-ppc-ingress-interposer-v2" || fail "embedded distributed-notifications ingress marker missing"
if [ -n "$NEWWINDOW_TRACE_MODE" ] || [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_CREATE_WINDOW_INLINE_LEGACY' ||
        fail "CGS NewWindow legacy trace marker missing"
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_CREATE_WINDOW_INLINE_LION' ||
        fail "CGS NewWindow Lion trace marker missing"
fi
if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:' ||
        fail "CGS NewWindow compatibility call marker missing"
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' ||
        fail "CGS NewWindow compatibility passthrough marker missing"
fi
if [ -n "$RELEASEBACKING_TRACE_MODE" ]; then
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_SET_WINDOW_RELEASE_BACKING_LEGACY' ||
        fail "CGS release-backing legacy trace marker missing"
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_SET_WINDOW_RELEASE_BACKING_LION' ||
        fail "CGS release-backing Lion trace marker missing"
fi
if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    for marker in         'CGS_SET_WINDOW_RELEASE_BACKING_LEGACY'         'CGS_SET_WINDOW_RELEASE_BACKING_LION'         'PM_CGS_RELEASEBACKING_COMPAT_CALL:'         'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REQUEST:'         'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:'         'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:'         'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS'         'PM_CGS_RELEASEBACKING_COMPAT_RESULT:PASSTHROUGH'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            fail "CGS release-backing compatibility marker missing: $marker"
    done
fi
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || fail "Security build marker missing"
/usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_CGS_BUILD_ID" || fail "CGS build marker missing"
if [ -n "$HITOOLBOX_TRACE" ]; then
    /usr/bin/strings "$HITOOLBOX_TRACE" | /usr/bin/grep -Fq \
        "PM_HITOOLBOX_CFBUNDLE_TRACE_BUILD_ID:$EXPECTED_HITOOLBOX_TRACE_BUILD_ID" ||
        fail "HIToolbox trace build marker missing"
    /usr/bin/nm -u "$HITOOLBOX_TRACE" | /usr/bin/grep -Fq '_dlsym' &&
        fail "HIToolbox trace unexpectedly imports dlsym"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    /usr/bin/strings "$HITOOLBOX_EXTRAS_COMPAT" | /usr/bin/grep -Fq \
        "PM_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID:$EXPECTED_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID" ||
        fail "HIToolbox Extras compatibility build marker missing"
    /usr/bin/nm -u "$HITOOLBOX_EXTRAS_COMPAT" | /usr/bin/grep -Fq '_dlsym' &&
        fail "HIToolbox Extras compatibility dylib unexpectedly imports dlsym"
fi

OT="$(/usr/bin/otool -l "$SUBJECT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$LOG"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "LC_LOAD_DYLINKER is not /usr/oah/dyld"

CORE_ABS="$(abspath "$CORE_COMPAT")"
SEC_ABS="$(abspath "$SEC_INTERPOSER")"
CGS_ABS="$(abspath "$CGS_INTERPOSER")"
[ -n "$CORE_ABS" ] || fail "could not resolve CoreServices CPS registration compatibility path"
[ -n "$SEC_ABS" ] || fail "could not resolve Security interposer path"
[ -n "$CGS_ABS" ] || fail "could not resolve CGS interposer path"
INSERTED="$CORE_ABS:$SEC_ABS:$CGS_ABS"
if [ -n "$HITOOLBOX_TRACE" ]; then
    HITOOLBOX_TRACE_ABS="$(abspath "$HITOOLBOX_TRACE")"
    [ -n "$HITOOLBOX_TRACE_ABS" ] || fail "could not resolve HIToolbox trace path"
    INSERTED="$INSERTED:$HITOOLBOX_TRACE_ABS"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    HITOOLBOX_EXTRAS_COMPAT_ABS="$(abspath "$HITOOLBOX_EXTRAS_COMPAT")"
    HITOOLBOX_EXTRAS_RESOURCE_ABS="$(abspath "$HITOOLBOX_EXTRAS_RESOURCE")"
    [ -n "$HITOOLBOX_EXTRAS_COMPAT_ABS" ] || fail "could not resolve HIToolbox Extras compatibility path"
    [ -n "$HITOOLBOX_EXTRAS_RESOURCE_ABS" ] || fail "could not resolve staged Extras.rsrc path"
    INSERTED="$INSERTED:$HITOOLBOX_EXTRAS_COMPAT_ABS"
fi

echo "subject_sha256=$EXPECTED_SUBJECT_SHA" | /usr/bin/tee -a "$LOG"
echo "coreservices_cps_registration_compat_sha256=$EXPECTED_CORE_COMPAT_SHA" | /usr/bin/tee -a "$LOG"
echo "security_interposer_sha256=$EXPECTED_SEC_SHA" | /usr/bin/tee -a "$LOG"
echo "cgs_interposer_sha256=$EXPECTED_CGS_SHA" | /usr/bin/tee -a "$LOG"
if [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
    echo "dockserver_bootstrap_compat_mode=$DOCKSERVER_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$NEWWINDOW_TRACE_MODE" ]; then
    echo "cgs_newwindow_trace_mode=$NEWWINDOW_TRACE_MODE" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    echo "cgs_newwindow_compat_mode=$NEWWINDOW_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE="$NEWWINDOW_COMPAT_MODE"
else
    unset ROSETTA_CGS_NEWWINDOW_COMPAT_MODE
fi
if [ -n "$RELEASEBACKING_TRACE_MODE" ]; then
    echo "cgs_post_newwindow_releasebacking_trace_mode=$RELEASEBACKING_TRACE_MODE" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    echo "cgs_releasebacking_compat_mode=$RELEASEBACKING_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE="$RELEASEBACKING_COMPAT_MODE"
else
    unset ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE
fi
echo "private_dyld_sha256=$EXPECTED_DYLD_SHA" | /usr/bin/tee -a "$LOG"
if [ -n "$HITOOLBOX_TRACE" ]; then
    echo "hitoolbox_cfbundle_trace_path=$HITOOLBOX_TRACE_ABS" | /usr/bin/tee -a "$LOG"
    echo "hitoolbox_cfbundle_trace_sha256=$EXPECTED_HITOOLBOX_TRACE_SHA" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    echo "hitoolbox_extras_compat_path=$HITOOLBOX_EXTRAS_COMPAT_ABS" | /usr/bin/tee -a "$LOG"
    echo "hitoolbox_extras_compat_sha256=$EXPECTED_HITOOLBOX_EXTRAS_COMPAT_SHA" | /usr/bin/tee -a "$LOG"
    echo "hitoolbox_extras_resource_path=$HITOOLBOX_EXTRAS_RESOURCE_ABS" | /usr/bin/tee -a "$LOG"
    echo "hitoolbox_extras_resource_sha256=$EXPECTED_HITOOLBOX_EXTRAS_RESOURCE_SHA" | /usr/bin/tee -a "$LOG"
    export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE="$HITOOLBOX_EXTRAS_MODE"
    export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$HITOOLBOX_EXTRAS_RESOURCE_ABS"
fi

echo "== Snow Leopard restored-stack CreateNewWindow validation control ==" | /usr/bin/tee -a "$LOG"
ROSETTA_CORESERVICES_COMPAT_MODE=passthrough \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=passthrough \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=passthrough \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=passthrough \
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=passthrough \
ROSETTA_CPS_SETFRONT_COMPAT_MODE=passthrough \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=passthrough \
DYLD_INSERT_LIBRARIES="$INSERTED" \
DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 \
"$SUBJECT" >> "$LOG" 2>&1
RC=$?
echo "control_status=$RC" | /usr/bin/tee -a "$LOG"

if /usr/bin/grep -Fq 'kind=SERVER_VERSION' "$LOG"; then
    echo "server_version_observed=YES" | /usr/bin/tee -a "$LOG"
else
    echo "server_version_observed=NO" | /usr/bin/tee -a "$LOG"
fi
if /usr/bin/grep -Fq 'kind=DEATHWATCH' "$LOG"; then
    echo "deathwatch_observed=YES" | /usr/bin/tee -a "$LOG"
else
    echo "deathwatch_observed=NO" | /usr/bin/tee -a "$LOG"
fi
if /usr/bin/grep -Fq 'kind=NEW_CONNECTION' "$LOG"; then
    echo "new_connection_observed=YES" | /usr/bin/tee -a "$LOG"
else
    echo "new_connection_observed=NO" | /usr/bin/tee -a "$LOG"
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:index=1 mode=passthrough name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008' "$LOG" &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:PASSTHROUGH kr=0 hex=0x00000000' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
   { [ -z "$DOCKSERVER_COMPAT_MODE" ] ||
     { /usr/bin/grep -Fq 'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=DOCK_SNOW_PASSTHROUGH' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=0 hex=0x00000000' "$LOG" &&
       ! /usr/bin/grep -Fq 'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$LOG"; }; } &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_RESULT:PASSTHROUGH major=545 minor=0' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'kind=SERVER_VERSION' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x00007148 expectedReply=0x000071ac' "$LOG" &&
   /usr/bin/grep -Fq 'kind=SERVER_VERSION kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000071ac expected=0x000071ac idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REQUEST_WORDS:' "$LOG" &&
   /usr/bin/grep -Fq 'kind=NEW_CONNECTION' "$LOG" &&
   /usr/bin/grep -Fq 'kind=NEW_CONNECTION kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000074cd expected=0x000074cd idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x00007372 expectedReply=0x000073d6' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION bits=' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x000073d6 expected=0x000073d6 idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_CHECKIN_APPLICATION' "$LOG" &&
   /usr/bin/grep -Fq 'off20=0x00000000' "$LOG" &&
   ! /usr/bin/grep -Fq 'kind=CPS_CREATE_APPLICATION' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M07_BEFORE_GetProcessPID' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M08_AFTER_GetProcessPID' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetProcessPID=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_ROUNDTRIP:self=[0-9]+ returned=[0-9]+ match=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M09_BEFORE_TransformProcessType' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M10_AFTER_TransformProcessType' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:TransformProcessType=0' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:SetFrontProcess=0' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M13_SETFRONTPROCESS_SUCCESS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M14_BEFORE_GetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M15_AFTER_GetFrontProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetFrontProcess=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_FRONT_PSN:expectedHigh=0x[0-9a-fA-F]+ expectedLow=0x[0-9a-fA-F]+ returnedHigh=0x[0-9a-fA-F]+ returnedLow=0x[0-9a-fA-F]+ match=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETFRONTPROCESS_MATCH_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M16_GETFRONTPROCESS_SUCCESS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M17_BEFORE_GetCurrentProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M18_AFTER_GetCurrentProcess' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:GetCurrentProcess=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_CURRENT_PSN:expectedHigh=0x[0-9a-fA-F]+ expectedLow=0x[0-9a-fA-F]+ returnedHigh=0x[0-9a-fA-F]+ returnedLow=0x[0-9a-fA-F]+ match=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:GETCURRENTPROCESS_MATCH_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M19_GETCURRENTPROCESS_SUCCESS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M21_AFTER_CreateNewWindow' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:CreateNewWindow=0' "$LOG" &&
   /usr/bin/grep -Eq 'PM_POSTIDENTITY_WINDOW:pointer=0x[0-9a-fA-F]+ nonzero=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:CREATENEWWINDOW_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M22_BEFORE_DisposeWindow' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M23_AFTER_DisposeWindow' "$LOG" &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x0000729e expectedReply=0x00007302' "$LOG" &&
   /usr/bin/grep -Fq 'option=0x00000003 send=0x00000030 recv=0x0000002c' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'id=0x00007302 expected=0x00007302 idMatch=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:' "$LOG" &&
   /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LEGACY' "$LOG" &&
   /usr/bin/grep -Fq 'off20=0x00000000' "$LOG" &&
   ! /usr/bin/grep -Fq 'kind=CPS_SET_FRONT_PROCESS_LION' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_CALL:index=2' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_CPS_SETFRONT_COMPAT_CALL:index=2' "$LOG" &&
   ! /usr/bin/grep -Fq '_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer' "$LOG" &&
   { [ -z "$HITOOLBOX_TRACE" ] ||
     { [ "$(/usr/bin/grep -c 'PM_HITOOLBOX_CFBUNDLE_TRACE_TARGET:.*bundle=com.apple.HIToolbox name=Extras type=rsrc subdir=NULL localization=NULL' "$LOG" 2>/dev/null || true)" -ge 1 ] &&
       /usr/bin/grep -Fq 'PM_HITOOLBOX_CFBUNDLE_TRACE_RESULT:' "$LOG" &&
       /usr/bin/grep -Fq ' url=NONNULL ' "$LOG" &&
       ! /usr/bin/grep -F 'PM_HITOOLBOX_CFBUNDLE_TRACE_RESULT:' "$LOG" | /usr/bin/grep -Fq ' url=NULL '; }; } &&
   { [ -z "$HITOOLBOX_EXTRAS_COMPAT" ] ||
     { [ "$(/usr/bin/grep -c 'PM_HITOOLBOX_EXTRAS_COMPAT_TARGET:.*mode=snow-force-external-v1.*bundle=com.apple.HIToolbox name=Extras type=rsrc' "$LOG" 2>/dev/null || true)" -ge 1 ] &&
       /usr/bin/grep -Fq 'PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:' "$LOG" &&
       /usr/bin/grep -Fq 'mode=snow-force-external-v1 original=SKIPPED fallback=NONNULL' "$LOG" &&
       ! /usr/bin/grep -Fq 'mode=snow-force-external-v1 original=SKIPPED fallback=NULL' "$LOG" &&
       ! /usr/bin/grep -Fq 'HIToolbox: failed to copy resource URL for framework bundle.' "$LOG"; }; }; then
    if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
        RELEASEBACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_RELEASEBACKING_COMPAT_CALL:' "$LOG" 2>/dev/null || true)"
        if /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           [ "$RELEASEBACKING_COMPAT_COUNT" -eq 1 ] &&
           /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=1 mode=passthrough exact=YES .*releaseFlag=0x00000001 newWindowCompatCalls=1' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY bits=0x00001513' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x0000724b expectedReply=0x000072af option=0x00000003 send=0x00000028 recv=0x0000002c' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY kr=0 hex=0x00000000' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$LOG"; then
            echo "cgs_releasebacking_compat_call_count=$RELEASEBACKING_COMPAT_COUNT" | /usr/bin/tee -a "$LOG"
            echo "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
        else
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    elif [ -n "$RELEASEBACKING_TRACE_MODE" ]; then
        RELEASEBACKING_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY' "$LOG" 2>/dev/null || true)"
        if /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
           [ "$RELEASEBACKING_TRACE_COUNT" -eq 1 ] &&
           /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY bits=0x00001513' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x0000724b expectedReply=0x000072af option=0x00000003 send=0x00000028 recv=0x0000002c' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY kr=0 hex=0x00000000' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$LOG"; then
            echo "cgs_releasebacking_legacy_trace_count=$RELEASEBACKING_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
            echo "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
        else
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    elif [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
        if /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x00007394 expectedReply=0x000073f8' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY kr=0 hex=0x00000000' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x000073f8 expected=0x000073f8 idMatch=YES' "$LOG"; then
            echo "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
        else
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    elif [ -n "$NEWWINDOW_TRACE_MODE" ]; then
        if /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x00007394 expectedReply=0x000073f8' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY kr=0 hex=0x00000000' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x000073f8 expected=0x000073f8 idMatch=YES' "$LOG"; then
            echo "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
        else
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    elif [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
        echo "RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
    elif [ -n "$HITOOLBOX_TRACE" ]; then
        echo "RESULT: CREATENEWWINDOW_HITOOLBOX_CFBUNDLE_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
    else
        echo "RESULT: CREATENEWWINDOW_DISTNOTIFY_INTEGRATION_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
    fi
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
