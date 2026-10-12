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
FONTSERVER_COMPAT_MODE="${ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE:-}"
FONTSERVER_RPC_TRACE_MODE="${ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE:-}"
FONTSERVER_RENDEZVOUS_COMPAT_MODE="${ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE:-}"
NEWWINDOW_TRACE_MODE="${ROSETTA_CGS_NEWWINDOW_TRACE_MODE:-}"
NEWWINDOW_COMPAT_MODE="${ROSETTA_CGS_NEWWINDOW_COMPAT_MODE:-}"
RELEASEBACKING_TRACE_MODE="${ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE:-}"
RELEASEBACKING_COMPAT_MODE="${ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE:-}"
OPACITY_ALPHA_TRACE_MODE="${ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE:-}"
OPACITY_ALPHA_CREATE_COMPAT_MODE="${ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE:-}"
POST_CREATEWINDOW_TITLE_MODE="${ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE:-}"
POST_WINDOWTITLE_SHOWWINDOW_MODE="${ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE:-}"
SHOWWINDOW_UNKNOWN_TRACE_MODE="${ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE:-}"
SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE:-}"
SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE:-}"
SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE:-}"
SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE="${ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE:-}"
SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE:-}"

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
if [ -n "$FONTSERVER_COMPAT_MODE" ]; then
    [ "$FONTSERVER_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow FontServer compatibility mode must be passthrough"
    [ "$DOCKSERVER_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow FontServer compatibility requires DockServer passthrough"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-fontserver-compat-v3"
fi
if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    [ "$FONTSERVER_RPC_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow FontServer RPC trace mode must be snow-passive-v1"
    [ "$FONTSERVER_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow FontServer RPC trace requires FontServer passthrough"
    [ -n "$POST_CREATEWINDOW_TITLE_MODE" ] ||
        fail "Snow FontServer RPC trace requires the window-title subject"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-fontserver-compat-rpc-trace-v4"
fi
if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    [ "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow FontServer rendezvous compatibility mode must be passthrough"
    [ "$FONTSERVER_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow FontServer rendezvous compatibility requires FontServer bootstrap passthrough"
    [ "$FONTSERVER_RPC_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow FontServer rendezvous compatibility requires snow-passive-v1 RPC tracing"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "snow-windowtitle-v1" ] ||
        fail "Snow FontServer rendezvous compatibility requires the window-title subject"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-fontserver-rendezvous-compat-v5"
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
if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    [ "$OPACITY_ALPHA_TRACE_MODE" = "passthrough" ] ||
        fail "Snow opacity alpha-plane trace mode must be passthrough"
    [ "$RELEASEBACKING_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow opacity alpha-plane trace requires release-backing compatibility passthrough mode"
    [ "$NEWWINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow opacity alpha-plane trace requires NewWindow compatibility passthrough mode"
    [ -z "$RELEASEBACKING_TRACE_MODE" ] ||
        fail "Snow opacity alpha-plane trace and release-backing passive trace are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace-v1"
fi
if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow opacity create-alpha compatibility mode must be passthrough"
    [ -z "$OPACITY_ALPHA_TRACE_MODE" ] ||
        fail "Snow opacity create-alpha compatibility and passive-trace runner modes are mutually exclusive"
    [ "$RELEASEBACKING_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow opacity create-alpha compatibility requires release-backing passthrough"
    [ "$NEWWINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow opacity create-alpha compatibility requires NewWindow passthrough"
    [ -z "$RELEASEBACKING_TRACE_MODE" ] ||
        fail "Snow opacity create-alpha compatibility and release-backing trace are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-v1"
fi
if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "snow-windowtitle-v1" ] ||
        fail "unsupported Snow post-CreateNewWindow title validation mode: $POST_CREATEWINDOW_TITLE_MODE"
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow window-title validation requires opacity create-alpha passthrough"
    [ "$RELEASEBACKING_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow window-title validation requires release-backing passthrough"
    [ "$NEWWINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow window-title validation requires NewWindow passthrough"
    EXPECTED_SUBJECT_BUILD_ID="cps-windowtitle-validation-v1"
fi
if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "unsupported Snow post-window-title ShowWindow validation mode: $POST_WINDOWTITLE_SHOWWINDOW_MODE"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "snow-windowtitle-v1" ] ||
        fail "Snow ShowWindow validation requires the window-title validation mode"
    [ "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow ShowWindow validation requires FontServer rendezvous passthrough"
    EXPECTED_SUBJECT_BUILD_ID="cps-showwindow-validation-v1"
fi
if [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow ShowWindow CGS passive trace mode must be snow-passive-v1"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "Snow ShowWindow CGS passive trace requires the ShowWindow subject"
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow ShowWindow CGS passive trace requires opacity create-alpha passthrough"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace-v1"
fi
if [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSAddTrackingArea compatibility mode must be passthrough"
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow CGSAddTrackingArea compatibility control requires snow-passive-v1 ShowWindow CGS tracing"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "Snow CGSAddTrackingArea compatibility control requires the ShowWindow subject"
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSAddTrackingArea compatibility control requires opacity create-alpha passthrough"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat-v1"
fi
if [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSOrderFrontConditionally compatibility mode must be passthrough"
    [ "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSOrderFrontConditionally compatibility control requires CGSAddTrackingArea passthrough"
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow CGSOrderFrontConditionally compatibility control requires snow-passive-v1 ShowWindow CGS tracing"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "Snow CGSOrderFrontConditionally compatibility control requires the ShowWindow subject"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat-v1"
fi
if [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSSetFrontWindow compatibility mode must be passthrough"
    [ "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSSetFrontWindow compatibility control requires CGSOrderFrontConditionally passthrough"
    [ "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow CGSSetFrontWindow compatibility control requires CGSAddTrackingArea passthrough"
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow CGSSetFrontWindow compatibility control requires snow-passive-v1 ShowWindow CGS tracing"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "Snow CGSSetFrontWindow compatibility control requires the ShowWindow subject"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat-v1"
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
    [ "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" = "snow-passive-v1" ] ||
        fail "Snow ColorProfileClient trace mode must be snow-passive-v1"
    [ "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow ColorProfileClient trace requires CGSSetFrontWindow passthrough"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "Snow ColorProfileClient trace requires the ShowWindow subject"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace-v1"
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow ColorProfileClient compatibility mode must be passthrough"
    [ -z "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ] ||
        fail "Snow ColorProfileClient compatibility and passive-trace runner modes are mutually exclusive"
    [ "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" = "passthrough" ] ||
        fail "Snow ColorProfileClient compatibility control requires CGSSetFrontWindow passthrough"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "snow-showwindow-v1" ] ||
        fail "Snow ColorProfileClient compatibility control requires the ShowWindow subject"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-v1"
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
if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' \
        'PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow' \
        'PM_POSTWINDOWSHOW_RESULT:SHOWWINDOW_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            fail "ShowWindow subject marker missing: $marker"
    done
fi
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_COMPAT_BUILD_ID" || fail "CoreServices CPS registration compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:distributed-notifications-ppc-ingress-interposer-v2" || fail "embedded distributed-notifications ingress marker missing"
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ] || [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    for marker in \
        'CGS_COLOR_PROFILE_CLIENT_LEGACY' \
        'CGS_COLOR_PROFILE_CLIENT_LION' \
        'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            fail "ColorProfileClient trace marker missing: $marker"
    done
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    for marker in \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REQUEST:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_MACH_RETURN:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REPLY:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:PASSTHROUGH'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            fail "ColorProfileClient compatibility marker missing: $marker"
    done
fi
if [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
    for marker in \
        'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST:' \
        'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST_HEX:' \
        'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN:' \
        'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_FAILURE_BUFFER_HEX:' \
        'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REPLY_HEX:'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            fail "ShowWindow CGS passive trace marker missing: $marker"
    done
fi
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
if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    for marker in \
        'CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' \
        'CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY' \
        'PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            fail "CGS opacity alpha-plane trace marker missing: $marker"
    done
fi
if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    for marker in \
        'CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REQUEST:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:PASSTHROUGH'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            fail "CGS opacity create-alpha compatibility marker missing: $marker"
    done
fi
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || fail "Security build marker missing"
/usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_CGS_BUILD_ID" || fail "CGS build marker missing"
if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:' ||
        fail "FontServer RPC trace request marker missing"
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REPLY:' ||
        fail "FontServer RPC trace reply marker missing"
fi
if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    for marker in \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_CALL:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REQUEST:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_MACH_RETURN:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_REPLY:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REPLY:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:PASSTHROUGH'; do
        /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq "$marker" ||
            fail "FontServer rendezvous compatibility marker missing: $marker"
    done
fi
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
if [ -n "$FONTSERVER_COMPAT_MODE" ]; then
    echo "fontserver_bootstrap_compat_mode=$FONTSERVER_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE="$FONTSERVER_COMPAT_MODE"
else
    unset ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE
fi
if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    echo "fontserver_rpc_trace_mode=$FONTSERVER_RPC_TRACE_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE="$FONTSERVER_RPC_TRACE_MODE"
else
    unset ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE
fi
if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    echo "fontserver_rendezvous_compat_mode=$FONTSERVER_RENDEZVOUS_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE="$FONTSERVER_RENDEZVOUS_COMPAT_MODE"
else
    unset ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE
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
if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    echo "cgs_post_releasebacking_opacity_alpha_trace_mode=$OPACITY_ALPHA_TRACE_MODE" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    echo "cgs_opacity_alpha_create_compat_mode=$OPACITY_ALPHA_CREATE_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE="$OPACITY_ALPHA_CREATE_COMPAT_MODE"
else
    unset ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE
fi
if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
    echo "post_createwindow_title_validation_mode=$POST_CREATEWINDOW_TITLE_MODE" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
    echo "post_windowtitle_showwindow_validation_mode=$POST_WINDOWTITLE_SHOWWINDOW_MODE" | /usr/bin/tee -a "$LOG"
fi
if [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
    echo "showwindow_unknown_cgs_trace_mode=$SHOWWINDOW_UNKNOWN_TRACE_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE="$SHOWWINDOW_UNKNOWN_TRACE_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE
fi
if [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
    echo "showwindow_add_tracking_area_compat_mode=$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE="$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
    echo "showwindow_order_front_conditionally_compat_mode=$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE="$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
    echo "showwindow_set_front_window_compat_mode=$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE="$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
    echo "showwindow_color_profile_client_trace_mode=$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE="$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    echo "showwindow_color_profile_client_compat_mode=$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" | /usr/bin/tee -a "$LOG"
    export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE="$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE
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
   { [ -z "$FONTSERVER_COMPAT_MODE" ] ||
     { /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=FONT_SNOW_PASSTHROUGH' "$LOG" &&
       /usr/bin/grep -Eq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=0 hex=0x00000000 servicePort=0x0*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
       ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$LOG"; }; } &&
   { [ -z "$FONTSERVER_RPC_TRACE_MODE" ] ||
     { /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_PORT:servicePort=' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:index=1 mode=snow-passive-v1' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_MACH_RETURN:index=1' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REPLY:index=1' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST_HEX:index=1' "$LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REPLY_HEX:index=1' "$LOG"; }; } &&
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
    if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T00_BEFORE_CFStringCreateWithCString' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T01_AFTER_CFStringCreateWithCString' "$LOG" ||
           ! /usr/bin/grep -Eq 'PM_POSTWINDOWTITLE_CFSTRING:pointer=0x[0-9a-fA-F]+ nonzero=YES' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_RESULT:CFSTRING_PASS' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T02_BEFORE_SetWindowTitleWithCFString' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T03_AFTER_SetWindowTitleWithCFString' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_STATUS:SetWindowTitleWithCFString=0' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_RESULT:SETWINDOWTITLE_PASS' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T04_BEFORE_CFRelease' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T05_AFTER_CFRelease' "$LOG"; then
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    fi
    if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_RESULT:SHOWWINDOW_PASS' "$LOG"; then
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    fi
    if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
        FONTSERVER_RENDEZVOUS_COMPAT_CALLS="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_CALL:' "$LOG" 2>/dev/null || true)"
        if [ "$FONTSERVER_RENDEZVOUS_COMPAT_CALLS" -ne 1 ] ||
           ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_CALL:index=1 rpcIndex=1 mode=passthrough exact=YES' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
           /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS' "$LOG"; then
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
        echo "fontserver_rendezvous_compat_call_count=$FONTSERVER_RENDEZVOUS_COMPAT_CALLS" | /usr/bin/tee -a "$LOG"
    fi
    if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
        RELEASEBACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_RELEASEBACKING_COMPAT_CALL:' "$LOG" 2>/dev/null || true)"
        OPACITY_CREATE_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:' "$LOG" 2>/dev/null || true)"
        OPACITY_CREATE_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' "$LOG" 2>/dev/null || true)"
        if /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           [ "$RELEASEBACKING_COMPAT_COUNT" -eq 1 ] &&
           /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=1 mode=passthrough exact=YES .*releaseFlag=0x00000001 newWindowCompatCalls=1' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           [ "$OPACITY_CREATE_COMPAT_COUNT" -eq 1 ] &&
           [ "$OPACITY_CREATE_TRACE_COUNT" -eq 1 ] &&
           /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:index=1 mode=passthrough exact=YES .*releaseBackingCompatCalls=1 newWindowCompatCalls=1' "$LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:PASSTHROUGH' "$LOG" &&
           ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$LOG" &&
           /usr/bin/grep -Fq 'id=0x0000724f expectedReply=0x000072b3 option=0x00000003 send=0x00000024 recv=0x0000002c' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$LOG" &&
           /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001200 size=0x00000024 id=0x000072b3 expected=0x000072b3 idMatch=YES' "$LOG" &&
           ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:' "$LOG"; then
            echo "cgs_opacity_alpha_create_compat_call_count=$OPACITY_CREATE_COMPAT_COUNT" | /usr/bin/tee -a "$LOG"
            echo "cgs_opacity_alpha_create_legacy_trace_count=$OPACITY_CREATE_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
            if [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
                ADD_TRACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL:index=' "$LOG" 2>/dev/null || true)"
                ADD_TRACKING_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY' "$LOG" 2>/dev/null || true)"
                echo "cgs_add_tracking_area_compat_call_count=$ADD_TRACKING_COMPAT_COUNT" | /usr/bin/tee -a "$LOG"
                echo "cgs_add_tracking_area_legacy_trace_count=$ADD_TRACKING_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
                if [ "$ADD_TRACKING_COMPAT_COUNT" -ne 1 ] ||
                   [ "$ADD_TRACKING_TRACE_COUNT" -ne 1 ] ||
                   ! /usr/bin/grep -Eq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL:index=1 mode=passthrough exact=YES .*count=9 opacityCreateCompatCalls=1' "$LOG" ||
                   ! /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
                   /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY bits=0x00001513' "$LOG" ||
                   ! /usr/bin/grep -Fq 'id=0x00007388 expectedReply=0x000073ec option=0x00000003 send=0x00000060 recv=0x0000002c' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY kr=0 hex=0x00000000' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY bits=0x00001200 size=0x00000024 id=0x000073ec expected=0x000073ec idMatch=YES' "$LOG"; then
                    echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                    exit 1
                fi
            fi
            if [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
                ORDER_FRONT_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=' "$LOG" 2>/dev/null || true)"
                ORDER_FRONT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY' "$LOG" 2>/dev/null || true)"
                echo "cgs_order_front_conditionally_compat_call_count=$ORDER_FRONT_COMPAT_COUNT" | /usr/bin/tee -a "$LOG"
                echo "cgs_order_front_conditionally_legacy_trace_count=$ORDER_FRONT_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
                if [ "$ORDER_FRONT_COMPAT_COUNT" -ne 1 ] ||
                   [ "$ORDER_FRONT_TRACE_COUNT" -ne 1 ] ||
                   ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=1 mode=passthrough exact=YES .*opacityCreateCompatCalls=1 addTrackingCompatCalls=0' "$LOG" ||
                   ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
                   /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY bits=0x00001513' "$LOG" ||
                   ! /usr/bin/grep -Fq 'id=0x000072e7 expectedReply=0x0000734b option=0x00000003 send=0x00000034 recv=0x0000002c' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY kr=0 hex=0x00000000' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY bits=0x00001200 size=0x00000024 id=0x0000734b expected=0x0000734b idMatch=YES' "$LOG"; then
                    echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                    exit 1
                fi
            fi
            if [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
                SET_FRONT_WINDOW_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_SET_FRONT_WINDOW_COMPAT_CALL:index=' "$LOG" 2>/dev/null || true)"
                SET_FRONT_WINDOW_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_SET_FRONT_WINDOW_LEGACY' "$LOG" 2>/dev/null || true)"
                echo "cgs_set_front_window_compat_call_count=$SET_FRONT_WINDOW_COMPAT_COUNT" | /usr/bin/tee -a "$LOG"
                echo "cgs_set_front_window_legacy_trace_count=$SET_FRONT_WINDOW_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
                if [ "$SET_FRONT_WINDOW_COMPAT_COUNT" -ne 1 ] ||
                   [ "$SET_FRONT_WINDOW_TRACE_COUNT" -ne 2 ] ||
                   ! /usr/bin/grep -Eq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* .*opacityCreateCompatCalls=1 orderFrontCompatCalls=1 addTrackingCompatCalls=1' "$LOG" ||
                   ! /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
                   /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_SET_FRONT_WINDOW_LEGACY bits=0x00001513' "$LOG" ||
                   ! /usr/bin/grep -Fq 'id=0x000072f2 expectedReply=0x00007356 option=0x00000003 send=0x00000024 recv=0x0000002c' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_SET_FRONT_WINDOW_LEGACY kr=0 hex=0x00000000' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_SET_FRONT_WINDOW_LEGACY bits=0x00001200 size=0x00000024 id=0x00007356 expected=0x00007356 idMatch=YES' "$LOG"; then
                    echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                    exit 1
                fi
            fi
            if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
                COLOR_PROFILE_CLIENT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY' "$LOG" 2>/dev/null || true)"
                echo "cgs_color_profile_client_legacy_trace_count=$COLOR_PROFILE_CLIENT_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
                if [ "$COLOR_PROFILE_CLIENT_TRACE_COUNT" -lt 1 ] ||
                   ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY exact=YES bits=0x80001513 id=0x000074d4 send=0x00000034 recv=0x00000030' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY kr=0 hex=0x00000000' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000028 id=0x00007538 expected=0x00007538 idMatch=YES' "$LOG" ||
                   ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000028 id=0x00007538 expected=0x00007538 resultRaw=0x00000000 clientIdRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" ||
                   /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LION' "$LOG"; then
                    echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                    exit 1
                fi
                echo "cgs_color_profile_client_live_result=LEGACY_SUCCESS" | /usr/bin/tee -a "$LOG"
            fi
            if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
                COLOR_PROFILE_CLIENT_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:index=' "$LOG" 2>/dev/null || true)"
                COLOR_PROFILE_CLIENT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY' "$LOG" 2>/dev/null || true)"
                echo "cgs_color_profile_client_compat_call_count=$COLOR_PROFILE_CLIENT_COMPAT_COUNT" | /usr/bin/tee -a "$LOG"
                echo "cgs_color_profile_client_legacy_trace_count=$COLOR_PROFILE_CLIENT_TRACE_COUNT" | /usr/bin/tee -a "$LOG"
                if [ "$COLOR_PROFILE_CLIENT_COMPAT_COUNT" -ne 1 ] ||
                   [ "$COLOR_PROFILE_CLIENT_TRACE_COUNT" -ne 1 ] ||
                   ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:index=1 mode=passthrough exact=YES .*descriptorCount=1 .*disposition=0x13 type=0x00 .*setFrontWindowCompatCalls=1 orderFrontCompatCalls=1 addTrackingCompatCalls=1 opacityCreateCompatCalls=1' "$LOG" ||
                   ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
                   /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY kr=0 hex=0x00000000' "$LOG" ||
                   ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000028 id=0x00007538 expected=0x00007538 idMatch=YES' "$LOG" ||
                   ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000028 id=0x00007538 expected=0x00007538 resultRaw=0x00000000 clientIdRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" ||
                   /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LION' "$LOG"; then
                    echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                    exit 1
                fi
                echo "cgs_color_profile_client_live_result=LEGACY_SUCCESS_COMPAT_PASSTHROUGH" | /usr/bin/tee -a "$LOG"
            fi
            if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
                if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
                    if [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
                        SHOWWINDOW_UNKNOWN_REQUEST_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow/{seen=1; next} seen && /PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow/{exit} seen && /PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST:index=/{n++} END{print n+0}' "$LOG" 2>/dev/null)"
                        SHOWWINDOW_UNKNOWN_RETURN_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow/{seen=1; next} seen && /PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow/{exit} seen && /PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN:index=/{n++} END{print n+0}' "$LOG" 2>/dev/null)"
                        echo "showwindow_unknown_cgs_trace_request_count=$SHOWWINDOW_UNKNOWN_REQUEST_COUNT" | /usr/bin/tee -a "$LOG"
                        echo "showwindow_unknown_cgs_trace_return_count=$SHOWWINDOW_UNKNOWN_RETURN_COUNT" | /usr/bin/tee -a "$LOG"
                        if [ "$SHOWWINDOW_UNKNOWN_REQUEST_COUNT" -lt 1 ] ||
                           [ "$SHOWWINDOW_UNKNOWN_RETURN_COUNT" -ne "$SHOWWINDOW_UNKNOWN_REQUEST_COUNT" ]; then
                            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                            exit 1
                        fi
                        if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
                            echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                        elif [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
                            echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                        elif [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
                            echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                        elif [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
                            echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                        elif [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
                            echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                        else
                            echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                        fi
                    else
                        echo "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                    fi
                elif [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
                    echo "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                elif [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
                    echo "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                elif [ -n "$FONTSERVER_COMPAT_MODE" ]; then
                    echo "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                else
                    echo "RESULT: POST_CREATEWINDOW_WINDOWTITLE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
                fi
            else
                echo "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
            fi
        else
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
    elif [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
        RELEASEBACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_RELEASEBACKING_COMPAT_CALL:' "$LOG" 2>/dev/null || true)"
        OPACITY_CREATE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' "$LOG" 2>/dev/null || true)"
        OPACITY_TERMINATE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY' "$LOG" 2>/dev/null || true)"
        OPACITY_TOTAL_COUNT=$((OPACITY_CREATE_COUNT + OPACITY_TERMINATE_COUNT))
        if ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
           [ "$RELEASEBACKING_COMPAT_COUNT" -ne 1 ] ||
           ! /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=1 mode=passthrough exact=YES .*releaseFlag=0x00000001 newWindowCompatCalls=1' "$LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:PASSTHROUGH' "$LOG" ||
           /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$LOG" ||
           [ "$OPACITY_TOTAL_COUNT" -ne 1 ] ||
           /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:' "$LOG"; then
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
        if [ "$OPACITY_CREATE_COUNT" -eq 1 ]; then
            if /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$LOG" &&
               /usr/bin/grep -Fq 'id=0x0000724f expectedReply=0x000072b3 option=0x00000003 send=0x00000024 recv=0x0000002c' "$LOG" &&
               /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$LOG" &&
               /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001200 size=0x00000024 id=0x000072b3 expected=0x000072b3 idMatch=YES' "$LOG"; then
                echo "cgs_opacity_alpha_legacy_kind=CREATE" | /usr/bin/tee -a "$LOG"
            else
                echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                exit 1
            fi
        elif [ "$OPACITY_TERMINATE_COUNT" -eq 1 ]; then
            if /usr/bin/grep -Fq 'kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$LOG" &&
               /usr/bin/grep -Fq 'id=0x00007250 expectedReply=0x000072b4 option=0x00000003 send=0x00000024 recv=0x0000002c' "$LOG" &&
               /usr/bin/grep -Fq 'kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$LOG" &&
               /usr/bin/grep -Fq 'kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001200 size=0x00000024 id=0x000072b4 expected=0x000072b4 idMatch=YES' "$LOG"; then
                echo "cgs_opacity_alpha_legacy_kind=TERMINATE" | /usr/bin/tee -a "$LOG"
            else
                echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
                exit 1
            fi
        else
            echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
            exit 1
        fi
        echo "cgs_opacity_alpha_legacy_trace_count=$OPACITY_TOTAL_COUNT" | /usr/bin/tee -a "$LOG"
        echo "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$LOG"
    elif [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
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
