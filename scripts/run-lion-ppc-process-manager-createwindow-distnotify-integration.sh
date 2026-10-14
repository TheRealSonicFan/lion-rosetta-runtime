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
RAW_LOG="${REPORT%.log}.raw.log"
HITOOLBOX_TRACE="${ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH:-}"
HITOOLBOX_TRACE_SHA_FILE="${ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE:-}"
HITOOLBOX_EXTRAS_COMPAT="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH:-}"
HITOOLBOX_EXTRAS_COMPAT_SHA_FILE="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE:-}"
HITOOLBOX_EXTRAS_RESOURCE="${ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH:-}"
HITOOLBOX_EXTRAS_MODE="${ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE:-}"
TITLEBAR_BSEARCH_COMPAT="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH:-}"
TITLEBAR_BSEARCH_SHA_FILE="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE:-}"
TITLEBAR_BSEARCH_MODE="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE:-}"
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
POST_SHOWWINDOW_SELECTWINDOW_MODE="${ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE:-}"
POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE="${ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE:-}"
POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE="${ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE:-}"
POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE="${ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE:-}"
POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE="${ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE:-}"
POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE="${ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE:-}"
POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE="${ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE:-}"
SHOWWINDOW_UNKNOWN_TRACE_MODE="${ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE:-}"
SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE:-}"
SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE:-}"
SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE:-}"
SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE="${ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE:-}"
SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE:-}"
SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE:-}"
SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE="${ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE:-}"

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
EXPECTED_HITOOLBOX_TRACE_BUILD_ID="hitoolbox-cfbundle-resource-trace-v1"
EXPECTED_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID="hitoolbox-extras-resource-compat-v1"
EXPECTED_HITOOLBOX_EXTRAS_RESOURCE_SHA="a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197"
EXPECTED_TITLEBAR_BSEARCH_BUILD_ID="coreui-titlebar-bsearch-exact-six-v2"
TITLEBAR_ARTFILE="/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/ArtFile.bin"
EXPECTED_TITLEBAR_ARTFILE_SHA="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4"
SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT:-}"
POST_EXTRAS_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT:-}"
POST_FONTSERVER_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT:-}"
POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT:-}"
POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT:-}"
RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE:-}"
RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE:-}"
RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE:-}"
RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE:-}"
RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE:-}"
REAL_REGISTRATION_MODE="${ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE:-}"
EXPECTED_REAL_REGISTRATION_COUNT=3
if [ -n "$SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-createwindow-schema-audit-broker-v1"
elif [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-createwindow-post-extras-schema-audit-broker-v1"
elif [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=4
elif [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=5
elif [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-showwindow-seventh-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=6
elif [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-eighth-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=7
elif [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-ninth-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=8
elif [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-tenth-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=9
elif [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-eleventh-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=10
elif [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-twelfth-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=11
elif [ -n "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-thirteenth-schema-audit-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=12
elif [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-twelfth-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=12
elif [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-eleventh-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=11
elif [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-tenth-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=10
elif [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-ninth-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=9
elif [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-runapplicationeventloop-eighth-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=8
elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-showwindow-seventh-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=7
elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=6
elif [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=5
elif [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-createwindow-post-extras-registration-broker-v1"
    EXPECTED_REAL_REGISTRATION_COUNT=4
elif [ -n "$REAL_REGISTRATION_MODE" ]; then
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-createwindow-registration-broker-v1"
else
    EXPECTED_BROKER_BUILD_ID="distributed-notifications-ppc-ingress-broker-v1"
fi
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

if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ]; then
    [ "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" = "lion-eighth-register-v1" ] ||
        die 64 "unsupported ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE: $RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop eighth registration requires the reviewed exact-seven registration base mode"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop eighth registration requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eighth registration and request-8 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eighth registration and request-9 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eighth registration and request-10 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-eight and exact-nine registration modes are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-eight and exact-ten registration modes are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop exact-eight registration and request-11 schema audit are mutually exclusive"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop request-9 schema audit requires the reviewed exact-seven base mode plus the dedicated exact-eight audit broker"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop request-9 schema audit requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-8 and request-9 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-9 schema audit uses its own exact-eight broker; do not enable the exact-eight registration mode separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-9 and request-10 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-9 schema audit and exact-nine registration are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-9 schema audit and exact-ten registration are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-9 and request-11 schema audits are mutually exclusive"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ]; then
    [ "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" = "lion-ninth-register-v1" ] ||
        die 64 "unsupported ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE: $RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop ninth registration requires the reviewed exact-seven registration base mode"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop ninth registration requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop ninth registration and request-8 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop ninth registration and request-9 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-nine registration uses its own first-nine broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop exact-nine registration and request-10 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-nine and exact-ten registration modes are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop exact-nine registration and request-11 schema audit are mutually exclusive"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop request-10 schema audit requires the reviewed exact-seven base mode plus the dedicated exact-nine audit broker"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop request-10 schema audit requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-8 and request-10 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-9 and request-10 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-10 schema audit uses its own exact-nine broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-10 schema audit uses its own exact-nine broker; do not enable exact-nine registration mode separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-10 schema audit and exact-ten registration are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-10 and request-11 schema audits are mutually exclusive"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ]; then
    [ "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" = "lion-tenth-register-v1" ] ||
        die 64 "unsupported ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE: $RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop tenth registration requires the reviewed exact-seven registration base mode"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop tenth registration requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop tenth registration and request-8 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop tenth registration and request-9 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop tenth registration and request-10 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-ten registration uses its own first-ten broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-ten registration uses its own first-ten broker; do not enable exact-nine separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop exact-ten registration and request-11 schema audit are mutually exclusive"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop request-11 schema audit requires the reviewed exact-seven base mode plus the dedicated exact-ten audit broker"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop request-11 schema audit requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-8 and request-11 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-9 and request-11 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-10 and request-11 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-11 schema audit uses its own exact-ten broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-11 schema audit uses its own exact-ten broker; do not enable exact-nine separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-11 schema audit uses its own exact-ten broker; do not enable exact-ten registration mode separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-11 schema audit and exact-eleven registration are mutually exclusive"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ]; then
    [ "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" = "lion-eleventh-register-v1" ] ||
        die 64 "unsupported ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE: $RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop eleventh registration requires the reviewed exact-seven registration base mode"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop eleventh registration requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eleventh registration and request-8 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eleventh registration and request-9 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eleventh registration and request-10 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop eleventh registration and request-11 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-eleven registration uses its own first-eleven broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-eleven registration uses its own first-eleven broker; do not enable exact-nine separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-eleven registration uses its own first-eleven broker; do not enable exact-ten separately"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop request-12 schema audit requires the reviewed exact-seven base mode plus the dedicated exact-eleven audit broker"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop request-12 schema audit requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-8 and request-12 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-9 and request-12 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-10 and request-12 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-11 and request-12 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-12 schema audit uses its own exact-eleven broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-12 schema audit uses its own exact-eleven broker; do not enable exact-nine separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-12 schema audit uses its own exact-eleven broker; do not enable exact-ten separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-12 schema audit uses its own exact-eleven broker; do not enable exact-eleven registration mode separately"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" ]; then
    [ "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" = "lion-twelfth-register-v1" ] ||
        die 64 "unsupported ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE: $RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop twelfth registration requires the reviewed exact-seven registration base mode"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop twelfth registration requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop twelfth registration and request-8 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop twelfth registration and request-9 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop twelfth registration and request-10 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop twelfth registration and request-11 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop twelfth registration and request-12 schema audit are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-twelve registration uses its own first-twelve broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-twelve registration uses its own first-twelve broker; do not enable exact-nine separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-twelve registration uses its own first-twelve broker; do not enable exact-ten separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop exact-twelve registration uses its own first-twelve broker; do not enable exact-eleven separately"
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit requires the reviewed exact-seven base mode plus the dedicated exact-twelve audit broker"
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit requires lion-runapplicationeventloop-timer-quit-v2"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-8 and request-13 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-9 and request-13 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-10 and request-13 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-11 and request-13 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ] ||
        die 64 "RunApplicationEventLoop request-12 and request-13 schema audits are mutually exclusive"
    [ -z "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit uses its own exact-twelve broker; do not enable exact-eight separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit uses its own exact-twelve broker; do not enable exact-nine separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit uses its own exact-twelve broker; do not enable exact-ten separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit uses its own exact-twelve broker; do not enable exact-eleven separately"
    [ -z "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" ] ||
        die 64 "RunApplicationEventLoop request-13 schema audit uses its own exact-twelve broker; do not enable exact-twelve registration mode separately"
fi

if [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
    [ "$DOCKSERVER_COMPAT_MODE" = "lion-dockserver-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE: $DOCKSERVER_COMPAT_MODE"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-compat-v2"
fi
if [ -n "$FONTSERVER_COMPAT_MODE" ]; then
    [ "$FONTSERVER_COMPAT_MODE" = "lion-fontserver-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE: $FONTSERVER_COMPAT_MODE"
    [ "$DOCKSERVER_COMPAT_MODE" = "lion-dockserver-v1" ] ||
        die 64 "FontServer compatibility requires lion-dockserver-v1"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "lion-windowtitle-v1" ] ||
        die 64 "FontServer compatibility requires the post-CreateNewWindow window-title subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "FontServer compatibility requires the reviewed exact-four, exact-five, exact-six, or exact-seven notification broker"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-fontserver-compat-v3"
fi
if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    [ "$FONTSERVER_RPC_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE: $FONTSERVER_RPC_TRACE_MODE"
    [ "$FONTSERVER_COMPAT_MODE" = "lion-fontserver-v1" ] ||
        die 64 "FontServer RPC trace requires lion-fontserver-v1"
    { [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "FontServer RPC trace requires the reviewed exact-five, exact-six, or exact-seven notification broker"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "lion-windowtitle-v1" ] ||
        die 64 "FontServer RPC trace requires the window-title subject"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-fontserver-compat-rpc-trace-v4"
fi
if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    [ "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" = "lion-rendezvous-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE: $FONTSERVER_RENDEZVOUS_COMPAT_MODE"
    [ "$FONTSERVER_COMPAT_MODE" = "lion-fontserver-v1" ] ||
        die 64 "FontServer rendezvous compatibility requires lion-fontserver-v1 bootstrap compatibility"
    [ "$FONTSERVER_RPC_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "FontServer rendezvous compatibility requires lion-passive-v1 RPC tracing"
    { [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "FontServer rendezvous compatibility requires the reviewed exact-five, exact-six, or exact-seven notification broker"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "lion-windowtitle-v1" ] ||
        die 64 "FontServer rendezvous compatibility requires the window-title subject"
    EXPECTED_CGS_BUILD_ID="cgs-session-bootstrap-dockserver-fontserver-rendezvous-compat-v5"
fi
if [ -n "$NEWWINDOW_TRACE_MODE" ]; then
    [ "$NEWWINDOW_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_NEWWINDOW_TRACE_MODE: $NEWWINDOW_TRACE_MODE"
    [ "$DOCKSERVER_COMPAT_MODE" = "lion-dockserver-v1" ] ||
        die 64 "CGS NewWindow passive trace requires lion-dockserver-v1"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-trace-v1"
fi
if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    [ "$NEWWINDOW_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_NEWWINDOW_COMPAT_MODE: $NEWWINDOW_COMPAT_MODE"
    [ -z "$NEWWINDOW_TRACE_MODE" ] ||
        die 64 "CGS NewWindow compatibility integration and passive-trace runner modes are mutually exclusive"
    [ "$DOCKSERVER_COMPAT_MODE" = "lion-dockserver-v1" ] ||
        die 64 "CGS NewWindow compatibility integration requires lion-dockserver-v1"
    { [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "CGS NewWindow compatibility integration requires the reviewed exact-four, exact-five, exact-six, or exact-seven registration mode"
    [ "$HITOOLBOX_EXTRAS_MODE" = "lion-fallback-external-v1" ] ||
        die 64 "CGS NewWindow compatibility integration requires lion-fallback-external-v1"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-v1"
fi
if [ -n "$RELEASEBACKING_TRACE_MODE" ]; then
    [ "$RELEASEBACKING_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE: $RELEASEBACKING_TRACE_MODE"
    [ "$NEWWINDOW_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "post-NewWindow release-backing trace requires lion-inline-id-v1 NewWindow compatibility"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-trace-v1"
fi
if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    [ "$RELEASEBACKING_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE: $RELEASEBACKING_COMPAT_MODE"
    [ "$NEWWINDOW_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "release-backing compatibility requires lion-inline-id-v1 NewWindow compatibility"
    [ -z "$RELEASEBACKING_TRACE_MODE" ] ||
        die 64 "release-backing compatibility and passive-trace runner modes are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-v1"
fi
if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    [ "$OPACITY_ALPHA_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE: $OPACITY_ALPHA_TRACE_MODE"
    [ "$RELEASEBACKING_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "opacity alpha-plane trace requires lion-id-v1 release-backing compatibility"
    [ "$NEWWINDOW_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "opacity alpha-plane trace requires lion-inline-id-v1 NewWindow compatibility"
    [ -z "$RELEASEBACKING_TRACE_MODE" ] ||
        die 64 "opacity alpha-plane trace and release-backing passive trace are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace-v1"
fi
if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE: $OPACITY_ALPHA_CREATE_COMPAT_MODE"
    [ -z "$OPACITY_ALPHA_TRACE_MODE" ] ||
        die 64 "opacity create-alpha compatibility and passive-trace runner modes are mutually exclusive"
    [ "$RELEASEBACKING_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "opacity create-alpha compatibility requires lion-id-v1 release-backing compatibility"
    [ "$NEWWINDOW_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "opacity create-alpha compatibility requires lion-inline-id-v1 NewWindow compatibility"
    [ -z "$RELEASEBACKING_TRACE_MODE" ] ||
        die 64 "opacity create-alpha compatibility and release-backing passive trace are mutually exclusive"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-v1"
fi
if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "lion-windowtitle-v1" ] ||
        die 64 "unsupported ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE: $POST_CREATEWINDOW_TITLE_MODE"
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "post-CreateNewWindow title validation requires lion-id-v1 opacity create-alpha compatibility"
    [ "$RELEASEBACKING_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "post-CreateNewWindow title validation requires lion-id-v1 release-backing compatibility"
    [ "$NEWWINDOW_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "post-CreateNewWindow title validation requires lion-inline-id-v1 NewWindow compatibility"
    [ -z "$OPACITY_ALPHA_TRACE_MODE" ] ||
        die 64 "post-CreateNewWindow title validation requires opacity passive trace unset"
    EXPECTED_SUBJECT_BUILD_ID="cps-windowtitle-validation-v1"
fi
if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "unsupported ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE: $POST_WINDOWTITLE_SHOWWINDOW_MODE"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "lion-windowtitle-v1" ] ||
        die 64 "ShowWindow validation requires the accepted window-title validation mode"
    [ "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" = "lion-rendezvous-v1" ] ||
        die 64 "ShowWindow validation requires the accepted FontServer rendezvous compatibility mode"
    { [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "ShowWindow validation requires the reviewed exact-five, exact-six, or exact-seven notification broker"
    EXPECTED_SUBJECT_BUILD_ID="cps-showwindow-validation-v1"
fi
if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
    [ "$POST_SHOWWINDOW_SELECTWINDOW_MODE" = "lion-selectwindow-v1" ] ||
        die 64 "unsupported ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE: $POST_SHOWWINDOW_SELECTWINDOW_MODE"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "SelectWindow validation requires the accepted ShowWindow validation mode"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "SelectWindow validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "SelectWindow validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "SelectWindow validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-selectwindow-validation-v1"
fi
if [ -n "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" ]; then
    [ "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" = "lion-iswindowvisible-v1" ] ||
        die 64 "unsupported ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE: $POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE"
    [ "$POST_SHOWWINDOW_SELECTWINDOW_MODE" = "lion-selectwindow-v1" ] ||
        die 64 "IsWindowVisible validation requires the accepted SelectWindow validation mode"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "IsWindowVisible validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "IsWindowVisible validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "IsWindowVisible validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-iswindowvisible-validation-v1"
fi
if [ -n "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" ]; then
    [ "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" = "lion-neweventlooptimerupp-v1" ] ||
        die 64 "unsupported ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE: $POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE"
    [ "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" = "lion-iswindowvisible-v1" ] ||
        die 64 "NewEventLoopTimerUPP validation requires the accepted IsWindowVisible validation mode"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "NewEventLoopTimerUPP validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "NewEventLoopTimerUPP validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "NewEventLoopTimerUPP validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-neweventlooptimerupp-validation-v1"
fi
if [ -n "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" ]; then
    [ "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" = "lion-getmaineventloop-v1" ] ||
        die 64 "unsupported ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE: $POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE"
    [ "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" = "lion-neweventlooptimerupp-v1" ] ||
        die 64 "GetMainEventLoop validation requires the accepted NewEventLoopTimerUPP validation mode"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "GetMainEventLoop validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "GetMainEventLoop validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "GetMainEventLoop validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-getmaineventloop-validation-v1"
fi
if [ -n "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" ]; then
    [ "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" = "lion-installeventlooptimer-v1" ] ||
        die 64 "unsupported ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE: $POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE"
    [ "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" = "lion-getmaineventloop-v1" ] ||
        die 64 "InstallEventLoopTimer validation requires the accepted GetMainEventLoop validation mode"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "InstallEventLoopTimer validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "InstallEventLoopTimer validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "InstallEventLoopTimer validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-installeventlooptimer-validation-v1"
fi
if [ -n "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" ]; then
    [ "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" = "lion-quitapplicationeventloop-v1" ] ||
        die 64 "unsupported ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE: $POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE"
    [ "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" = "lion-installeventlooptimer-v1" ] ||
        die 64 "QuitApplicationEventLoop validation requires the accepted InstallEventLoopTimer validation mode"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "QuitApplicationEventLoop validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "QuitApplicationEventLoop validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "QuitApplicationEventLoop validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-quitapplicationeventloop-validation-v1"
fi
if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
    [ "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" = "lion-runapplicationeventloop-timer-quit-v2" ] ||
        die 64 "unsupported ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE: $POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE"
    [ "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" = "lion-installeventlooptimer-v1" ] ||
        die 64 "RunApplicationEventLoop timer-quit validation requires the accepted InstallEventLoopTimer validation mode"
    [ -z "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" ] ||
        die 64 "RunApplicationEventLoop timer-quit validation must not prequeue QuitApplicationEventLoop"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "RunApplicationEventLoop timer-quit validation requires the accepted exact-seven notification broker"
    [ "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "RunApplicationEventLoop timer-quit validation requires accepted ResolveColorProfile compatibility"
    [ "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "RunApplicationEventLoop timer-quit validation requires accepted WindowBackingInfo compatibility"
    EXPECTED_SUBJECT_BUILD_ID="cps-runapplicationeventloop-timer-quit-validation-v2"
fi
if [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE: $SHOWWINDOW_UNKNOWN_TRACE_MODE"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "ShowWindow CGS passive trace requires the ShowWindow subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "ShowWindow CGS passive trace requires the accepted exact-six or exact-seven notification broker"
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "ShowWindow CGS passive trace requires accepted opacity create-alpha compatibility"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace-v1"
fi
if [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE: $SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE"
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "CGSAddTrackingArea compatibility requires lion-passive-v1 ShowWindow CGS tracing"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "CGSAddTrackingArea compatibility requires the ShowWindow subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "CGSAddTrackingArea compatibility requires the accepted exact-six or exact-seven notification broker"
    [ "$OPACITY_ALPHA_CREATE_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "CGSAddTrackingArea compatibility requires accepted opacity create-alpha compatibility"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat-v1"
fi
if [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
    if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
        [ "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" = "lion-selectwindow-id-v1" ] ||
            die 64 "SelectWindow validation requires lion-selectwindow-id-v1 OrderFront compatibility"
    else
        [ "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" = "lion-id-v1" ] ||
            die 64 "unsupported ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE: $SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE"
    fi
    [ "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "CGSOrderFrontConditionally compatibility requires accepted CGSAddTrackingArea compatibility"
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "CGSOrderFrontConditionally compatibility requires lion-passive-v1 ShowWindow CGS tracing"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "CGSOrderFrontConditionally compatibility requires the ShowWindow subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "CGSOrderFrontConditionally compatibility requires the accepted exact-six or exact-seven notification broker"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat-v1"
fi
if [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE: $SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE"
    { [ "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" = "lion-id-v1" ] ||
      { [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ] &&
        [ "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" = "lion-selectwindow-id-v1" ]; }; } ||
        die 64 "CGSSetFrontWindow compatibility requires accepted CGSOrderFrontConditionally compatibility"
    [ "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" = "lion-inline-id-v1" ] ||
        die 64 "CGSSetFrontWindow compatibility requires accepted CGSAddTrackingArea compatibility"
    [ "$SHOWWINDOW_UNKNOWN_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "CGSSetFrontWindow compatibility requires lion-passive-v1 ShowWindow CGS tracing"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "CGSSetFrontWindow compatibility requires the ShowWindow subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "CGSSetFrontWindow compatibility requires the accepted exact-six or exact-seven notification broker"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat-v1"
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
    [ "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE: $SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE"
    [ "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "ColorProfileClient trace requires accepted CGSSetFrontWindow compatibility"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "ColorProfileClient trace requires the ShowWindow subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "ColorProfileClient trace requires the accepted exact-six or exact-seven notification broker"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace-v1"
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    [ "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "unsupported ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE: $SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE"
    [ -z "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ] ||
        die 64 "ColorProfileClient compatibility and passive-trace runner modes are mutually exclusive"
    [ "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" = "lion-id-v1" ] ||
        die 64 "ColorProfileClient compatibility requires accepted CGSSetFrontWindow compatibility"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "ColorProfileClient compatibility requires the ShowWindow subject"
    { [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
      [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; } ||
        die 64 "ColorProfileClient compatibility requires the accepted exact-six or exact-seven notification broker"
    EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v3"
fi
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

if [ -n "$SCHEMA_AUDIT_REPORT" ] && [ -n "$REAL_REGISTRATION_MODE" ]; then
    die 64 "schema-audit and real-registration modes are mutually exclusive"
fi
if [ -n "$SCHEMA_AUDIT_REPORT" ] && [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ]; then
    die 64 "initial schema-audit and post-Extras schema-audit modes are mutually exclusive"
fi
if [ -n "$SCHEMA_AUDIT_REPORT" ] && [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ]; then
    die 64 "initial schema-audit and post-FontServer schema-audit modes are mutually exclusive"
fi
if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] && [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ]; then
    die 64 "post-Extras and post-FontServer schema-audit modes are mutually exclusive"
fi
if [ -n "$SCHEMA_AUDIT_REPORT" ] && [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    die 64 "initial and post-ShowWindow schema-audit modes are mutually exclusive"
fi
if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] && [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    die 64 "post-Extras and post-ShowWindow schema-audit modes are mutually exclusive"
fi
if [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ] && [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    die 64 "post-FontServer and post-ShowWindow schema-audit modes are mutually exclusive"
fi
if [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ] &&
   { [ -n "$SCHEMA_AUDIT_REPORT" ] ||
     [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] ||
     [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ] ||
     [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; }; then
    die 64 "seventh-request schema audit is mutually exclusive with other schema-audit modes"
fi
if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] && [ -z "$REAL_REGISTRATION_MODE" ]; then
    die 64 "post-Extras schema audit requires the reviewed real-registration mode"
fi
if [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ] ||
        die 64 "post-FontServer schema audit requires the exact-four real-registration mode"
    [ "$FONTSERVER_COMPAT_MODE" = "lion-fontserver-v1" ] ||
        die 64 "post-FontServer schema audit requires lion-fontserver-v1"
    [ "$POST_CREATEWINDOW_TITLE_MODE" = "lion-windowtitle-v1" ] ||
        die 64 "post-FontServer schema audit requires the window-title subject"
fi
if [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] ||
        die 64 "post-ShowWindow schema audit requires the reviewed exact-five registration mode"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "post-ShowWindow schema audit requires the ShowWindow subject"
    [ "$FONTSERVER_COMPAT_MODE" = "lion-fontserver-v1" ] ||
        die 64 "post-ShowWindow schema audit requires FontServer bootstrap compatibility"
    [ "$FONTSERVER_RPC_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "post-ShowWindow schema audit requires FontServer passive tracing"
    [ "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" = "lion-rendezvous-v1" ] ||
        die 64 "post-ShowWindow schema audit requires FontServer rendezvous compatibility"
fi
if [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
        die 64 "seventh-request schema audit requires the reviewed exact-six registration mode"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "seventh-request schema audit requires the ShowWindow subject"
    [ "$FONTSERVER_COMPAT_MODE" = "lion-fontserver-v1" ] ||
        die 64 "seventh-request schema audit requires FontServer bootstrap compatibility"
    [ "$FONTSERVER_RPC_TRACE_MODE" = "lion-passive-v1" ] ||
        die 64 "seventh-request schema audit requires FontServer passive tracing"
    [ "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" = "lion-rendezvous-v1" ] ||
        die 64 "seventh-request schema audit requires FontServer rendezvous compatibility"
fi
if [ -n "$REAL_REGISTRATION_MODE" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-createwindow-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-createwindow-post-extras-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-windowtitle-fontserver-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-showwindow-sixth-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-showwindow-seventh-register-v1" ]; then
    die 64 "unsupported ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE: $REAL_REGISTRATION_MODE"
fi

if [ -n "$DOCKSERVER_COMPAT_MODE" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-createwindow-post-extras-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-windowtitle-fontserver-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-showwindow-sixth-register-v1" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-showwindow-seventh-register-v1" ]; then
    die 64 "DockServer bootstrap compatibility requires the reviewed exact-four, exact-five, exact-six, or exact-seven registration mode"
fi
if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] &&
   [ "$REAL_REGISTRATION_MODE" != "lion-createwindow-register-v1" ]; then
    die 64 "post-Extras schema audit requires lion-createwindow-register-v1"
fi
if { [ -n "$HITOOLBOX_TRACE" ] && [ -z "$HITOOLBOX_TRACE_SHA_FILE" ]; } ||
   { [ -z "$HITOOLBOX_TRACE" ] && [ -n "$HITOOLBOX_TRACE_SHA_FILE" ]; }; then
    die 64 "set both ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH and ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE, or neither"
fi
if [ -n "$HITOOLBOX_TRACE" ] && [ -z "$REAL_REGISTRATION_MODE" ]; then
    die 64 "HIToolbox CFBundle trace requires the reviewed real-registration mode"
fi
if [ -n "$HITOOLBOX_TRACE" ] && [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    die 64 "HIToolbox trace and Extras compatibility modes are mutually exclusive"
fi
if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] && [ -z "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    die 64 "post-Extras schema audit requires the exact HIToolbox Extras compatibility path"
fi
if [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ] && [ -z "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    die 64 "post-FontServer schema audit requires the exact HIToolbox Extras compatibility path"
fi
if [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ] && [ -z "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    die 64 "post-ShowWindow schema audit requires the exact HIToolbox Extras compatibility path"
fi
if [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ] && [ -z "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    die 64 "seventh-request schema audit requires the exact HIToolbox Extras compatibility path"
fi

if [ -n "$DOCKSERVER_COMPAT_MODE" ] && [ -z "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    die 64 "DockServer bootstrap compatibility requires the exact HIToolbox Extras compatibility path"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ] || [ -n "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE" ] ||
   [ -n "$HITOOLBOX_EXTRAS_RESOURCE" ] || [ -n "$HITOOLBOX_EXTRAS_MODE" ]; then
    [ -n "$REAL_REGISTRATION_MODE" ] ||
        die 64 "HIToolbox Extras compatibility requires the reviewed real-registration mode"
    [ -n "$HITOOLBOX_EXTRAS_COMPAT" ] ||
        die 64 "set ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH"
    [ -n "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE" ] ||
        die 64 "set ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE"
    [ -n "$HITOOLBOX_EXTRAS_RESOURCE" ] ||
        die 64 "set ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH"
    [ "$HITOOLBOX_EXTRAS_MODE" = "lion-fallback-external-v1" ] ||
        die 64 "Lion Extras compatibility mode must be lion-fallback-external-v1"
fi

if [ -n "$TITLEBAR_BSEARCH_COMPAT" ] || [ -n "$TITLEBAR_BSEARCH_SHA_FILE" ] ||
   [ -n "$TITLEBAR_BSEARCH_MODE" ]; then
    [ -n "$TITLEBAR_BSEARCH_COMPAT" ] || die 64 "set ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH"
    [ -n "$TITLEBAR_BSEARCH_SHA_FILE" ] || die 64 "set ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE"
    [ "$TITLEBAR_BSEARCH_MODE" = "lion-exact-six-v1" ] ||
        die 64 "Lion titlebar bsearch mode must be lion-exact-six-v1"
    [ "$POST_WINDOWTITLE_SHOWWINDOW_MODE" = "lion-showwindow-v1" ] ||
        die 64 "titlebar bsearch compatibility requires the ShowWindow subject"
    [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] ||
        die 64 "titlebar bsearch compatibility requires the accepted exact-seven notification mode"
fi

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
if [ -n "$HITOOLBOX_TRACE" ]; then
    [ -e "$HITOOLBOX_TRACE" ] || die 66 "missing HIToolbox trace dylib: $HITOOLBOX_TRACE"
    [ -e "$HITOOLBOX_TRACE_SHA_FILE" ] || die 66 "missing HIToolbox trace SHA file: $HITOOLBOX_TRACE_SHA_FILE"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    [ -e "$HITOOLBOX_EXTRAS_COMPAT" ] || die 66 "missing HIToolbox Extras compatibility dylib: $HITOOLBOX_EXTRAS_COMPAT"
    [ -e "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE" ] || die 66 "missing HIToolbox Extras compatibility SHA file: $HITOOLBOX_EXTRAS_COMPAT_SHA_FILE"
    [ -f "$HITOOLBOX_EXTRAS_RESOURCE" ] || die 66 "missing staged Snow Leopard Extras.rsrc: $HITOOLBOX_EXTRAS_RESOURCE"
fi

EXPECTED_SUBJECT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SUBJECT_SHA_FILE")"
EXPECTED_CORE_COMPAT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CORE_COMPAT_SHA_FILE")"
EXPECTED_SEC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SEC_SHA_FILE")"
EXPECTED_CGS_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$CGS_SHA_FILE")"
EXPECTED_BROKER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$BROKER_SHA_FILE")"
if [ -n "$HITOOLBOX_TRACE" ]; then
    EXPECTED_HITOOLBOX_TRACE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$HITOOLBOX_TRACE_SHA_FILE")"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    EXPECTED_HITOOLBOX_EXTRAS_COMPAT_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$HITOOLBOX_EXTRAS_COMPAT_SHA_FILE")"
fi

if [ -n "$TITLEBAR_BSEARCH_COMPAT" ]; then
    [ -e "$TITLEBAR_BSEARCH_COMPAT" ] || die 66 "missing titlebar bsearch compatibility dylib: $TITLEBAR_BSEARCH_COMPAT"
    [ -e "$TITLEBAR_BSEARCH_SHA_FILE" ] || die 66 "missing titlebar bsearch compatibility SHA file: $TITLEBAR_BSEARCH_SHA_FILE"
    [ -f "$TITLEBAR_ARTFILE" ] || die 66 "missing Lion ArtFile.bin"
    EXPECTED_TITLEBAR_BSEARCH_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$TITLEBAR_BSEARCH_SHA_FILE")"
fi

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
if [ -n "$HITOOLBOX_TRACE" ]; then
    HITOOLBOX_TRACE_BEFORE="$(sha256 "$HITOOLBOX_TRACE")"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    HITOOLBOX_EXTRAS_COMPAT_BEFORE="$(sha256 "$HITOOLBOX_EXTRAS_COMPAT")"
    HITOOLBOX_EXTRAS_RESOURCE_BEFORE="$(sha256 "$HITOOLBOX_EXTRAS_RESOURCE")"
fi

if [ -n "$TITLEBAR_BSEARCH_COMPAT" ]; then
    TITLEBAR_BSEARCH_BEFORE="$(sha256 "$TITLEBAR_BSEARCH_COMPAT")"
    TITLEBAR_ARTFILE_BEFORE="$(sha256 "$TITLEBAR_ARTFILE")"
    [ "$TITLEBAR_BSEARCH_BEFORE" = "$EXPECTED_TITLEBAR_BSEARCH_SHA" ] ||
        die 68 "titlebar bsearch compatibility hash mismatch"
    [ "$TITLEBAR_ARTFILE_BEFORE" = "$EXPECTED_TITLEBAR_ARTFILE_SHA" ] ||
        die 68 "Lion ArtFile.bin hash mismatch for titlebar compatibility"
    has_ppc32_arch "$TITLEBAR_BSEARCH_COMPAT" ||
        die 68 "titlebar bsearch compatibility dylib is not 32-bit PPC"
    /usr/bin/strings "$TITLEBAR_BSEARCH_COMPAT" |
        /usr/bin/grep -Fq "PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:$EXPECTED_TITLEBAR_BSEARCH_BUILD_ID" ||
        die 68 "titlebar bsearch compatibility build marker missing"
    TITLEBAR_INTERPOSE_SECTION="$(/usr/bin/otool -l "$TITLEBAR_BSEARCH_COMPAT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
    echo "$TITLEBAR_INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' ||
        die 68 "titlebar bsearch compatibility does not contain exactly one PPC interpose tuple"
fi

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
if [ -n "$HITOOLBOX_TRACE" ]; then
    log "expected_hitoolbox_trace_sha256=$EXPECTED_HITOOLBOX_TRACE_SHA"
    log "actual_hitoolbox_trace_sha256=$HITOOLBOX_TRACE_BEFORE"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    log "expected_hitoolbox_extras_compat_sha256=$EXPECTED_HITOOLBOX_EXTRAS_COMPAT_SHA"
    log "actual_hitoolbox_extras_compat_sha256=$HITOOLBOX_EXTRAS_COMPAT_BEFORE"
    log "expected_hitoolbox_extras_resource_sha256=$EXPECTED_HITOOLBOX_EXTRAS_RESOURCE_SHA"
    log "actual_hitoolbox_extras_resource_sha256=$HITOOLBOX_EXTRAS_RESOURCE_BEFORE"
fi

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
if [ -n "$HITOOLBOX_TRACE" ]; then
    [ "$HITOOLBOX_TRACE_BEFORE" = "$EXPECTED_HITOOLBOX_TRACE_SHA" ] ||
        die 68 "HIToolbox trace hash mismatch"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    [ "$HITOOLBOX_EXTRAS_COMPAT_BEFORE" = "$EXPECTED_HITOOLBOX_EXTRAS_COMPAT_SHA" ] ||
        die 68 "HIToolbox Extras compatibility hash mismatch"
    [ "$HITOOLBOX_EXTRAS_RESOURCE_BEFORE" = "$EXPECTED_HITOOLBOX_EXTRAS_RESOURCE_SHA" ] ||
        die 68 "staged Snow Leopard Extras.rsrc hash mismatch"
fi

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

for p in "$SUBJECT" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER"; do
    has_ppc32_arch "$p" || die 67 "required artifact is not 32-bit PPC: $p"
done
if [ -n "$HITOOLBOX_TRACE" ]; then
    has_ppc32_arch "$HITOOLBOX_TRACE" || die 67 "HIToolbox trace is not 32-bit PPC"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    has_ppc32_arch "$HITOOLBOX_EXTRAS_COMPAT" || die 67 "HIToolbox Extras compatibility dylib is not 32-bit PPC"
fi

BROKER_ARCH="$(/usr/bin/lipo -info "$BROKER" 2>/dev/null || true)"
echo "$BROKER_ARCH" | /usr/bin/grep -Eq '(^|[[:space:]])i386([[:space:]]|$)' ||
    die 67 "broker is not i386"

/usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq \
    "PM_CPS_CREATEWINDOW_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID" || die 68 "subject build marker missing"
if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' \
        'PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow' \
        'PM_POSTWINDOWSHOW_RESULT:SHOWWINDOW_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "ShowWindow subject marker missing: $marker"
    done
fi
if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWSELECT_MILESTONE:S02_BEFORE_SelectWindow' \
        'PM_POSTWINDOWSELECT_MILESTONE:S03_AFTER_SelectWindow' \
        'PM_POSTWINDOWSELECT_RESULT:SELECTWINDOW_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "SelectWindow subject marker missing: $marker"
    done
fi
if [ -n "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWVISIBLE_MILESTONE:S04_BEFORE_IsWindowVisible' \
        'PM_POSTWINDOWVISIBLE_MILESTONE:S05_AFTER_IsWindowVisible' \
        'PM_POSTWINDOWVISIBLE_VALUE:visible=' \
        'PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "IsWindowVisible subject marker missing: $marker"
    done
fi
if [ -n "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP' \
        'PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP' \
        'PM_POSTWINDOWTIMERUPP_POINTER:pointer=' \
        'PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "NewEventLoopTimerUPP subject marker missing: $marker"
    done
fi
if [ -n "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S08_BEFORE_GetMainEventLoop' \
        'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S09_AFTER_GetMainEventLoop' \
        'PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=' \
        'PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "GetMainEventLoop subject marker missing: $marker"
    done
fi
if [ -n "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWTIMERINSTALL_MILESTONE:S10_BEFORE_InstallEventLoopTimer' \
        'PM_POSTWINDOWTIMERINSTALL_MILESTONE:S11_AFTER_InstallEventLoopTimer' \
        'PM_POSTWINDOWTIMERINSTALL_STATUS:InstallEventLoopTimer=' \
        'PM_POSTWINDOWTIMERINSTALL_POINTER:pointer=' \
        'PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=' \
        'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "InstallEventLoopTimer subject marker missing: $marker"
    done
fi
if [ -n "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S12_BEFORE_QuitApplicationEventLoop' \
        'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S13_AFTER_QuitApplicationEventLoop' \
        'PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=' \
        'PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "QuitApplicationEventLoop subject marker missing: $marker"
    done
fi
if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
    for marker in \
        'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' \
        'PM_POSTWINDOWTIMER_CALLBACK:ENTER' \
        'PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop' \
        'PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop' \
        'PM_POSTWINDOWTIMER_CALLBACK:EXIT' \
        'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' \
        'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=' \
        'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS'; do
        /usr/bin/strings "$SUBJECT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop timer-quit subject marker missing: $marker"
    done
fi
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_COMPAT_BUILD_ID" || die 68 "CoreServices CPS registration compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:distributed-notifications-ppc-ingress-interposer-v2" || die 68 "embedded distributed-notifications ingress marker missing"
if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
    for marker in \
        'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:color-profile-resolve-passive-trace-v1' \
        'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1' \
        'PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1' \
        'lion-selectwindow-id-v1'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "SelectWindow full-stack compatibility marker missing: $marker"
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
            die 68 "ShowWindow CGS passive trace marker missing: $marker"
    done
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ] || [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    for marker in \
        'CGS_COLOR_PROFILE_CLIENT_LEGACY' \
        'CGS_COLOR_PROFILE_CLIENT_LION' \
        'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "ColorProfileClient trace marker missing: $marker"
    done
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    for marker in \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REQUEST:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_MACH_RETURN:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REPLY:' \
        'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "ColorProfileClient compatibility marker missing: $marker"
    done
fi
if [ -n "$NEWWINDOW_TRACE_MODE" ] || [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_CREATE_WINDOW_INLINE_LEGACY' ||
        die 68 "CGS NewWindow legacy trace marker missing"
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_CREATE_WINDOW_INLINE_LION' ||
        die 68 "CGS NewWindow Lion trace marker missing"
fi
if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    for marker in         'PM_CGS_NEWWINDOW_COMPAT_CALL:'         'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REQUEST:'         'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:'         'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REPLY:'         'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "CGS NewWindow compatibility marker missing: $marker"
    done
fi
if [ -n "$RELEASEBACKING_TRACE_MODE" ]; then
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_SET_WINDOW_RELEASE_BACKING_LEGACY' ||
        die 68 "CGS release-backing legacy trace marker missing"
    /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_SET_WINDOW_RELEASE_BACKING_LION' ||
        die 68 "CGS release-backing Lion trace marker missing"
fi
if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    for marker in         'CGS_SET_WINDOW_RELEASE_BACKING_LEGACY'         'CGS_SET_WINDOW_RELEASE_BACKING_LION'         'PM_CGS_RELEASEBACKING_COMPAT_CALL:'         'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REQUEST:'         'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:'         'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:'         'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "CGS release-backing compatibility marker missing: $marker"
    done
fi
if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    for marker in \
        'CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' \
        'CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY' \
        'PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "CGS opacity alpha-plane trace marker missing: $marker"
    done
fi
if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    for marker in \
        'CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REQUEST:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:' \
        'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS'; do
        /usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "$marker" ||
            die 68 "CGS opacity create-alpha compatibility marker missing: $marker"
    done
fi
/usr/bin/strings "$BROKER" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:$EXPECTED_BROKER_BUILD_ID" || die 68 "broker build marker missing"
if [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; then
    /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' ||
        die 68 "exact-seven broker missing inherited exact-six policy marker"
    /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' ||
        die 68 "exact-seven ShowWindow registration policy marker missing"
elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ]; then
    /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' ||
        die 68 "exact-six ShowWindow registration policy marker missing"
fi
if [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_SHOWWINDOW_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "post-ShowWindow schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_SHOWWINDOW_SEVENTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "seventh-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_TAIL_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_EIGHTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop eighth-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_TAIL_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_NINTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop ninth-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_TAIL_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_TENTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop tenth-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'AppleNumberPreferencesChangedNotification' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_TAIL_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_ELEVENTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop eleventh-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'AppleNumberPreferencesChangedNotification' \
        'AppleTextBehaviorPreferencesChangedNotification' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_TAIL_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_TWELFTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop twelfth-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_POLICY:index=12 allowed=10 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'AppleNumberPreferencesChangedNotification' \
        'AppleTextBehaviorPreferencesChangedNotification' \
        'AppleLanguagePreferencesChangedNotification' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_CAPTURE:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_TAIL_REJECT:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_SUMMARY:' \
        'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_THIRTEENTH_AUDIT_PASS'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop thirteenth-request schema-audit broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_POLICY:index=12 allowed=10 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'AppleNumberPreferencesChangedNotification' \
        'AppleTextBehaviorPreferencesChangedNotification' \
        'AppleLanguagePreferencesChangedNotification'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop exact-twelve registration broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'AppleNumberPreferencesChangedNotification' \
        'AppleTextBehaviorPreferencesChangedNotification'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop exact-eleven registration broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification' \
        'AppleNumberPreferencesChangedNotification'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop exact-ten registration broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1' \
        'AppleDatePreferencesChangedNotification' \
        'AppleTimePreferencesChangedNotification'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop exact-nine registration broker marker missing: $marker"
    done
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ]; then
    for marker in \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SIXTH_REGISTRATION_POLICY:index=6 allowed=3 counter=2' \
        'PM_DISTRIBUTED_NOTIFICATIONS_SHOWWINDOW_SEVENTH_REGISTRATION_POLICY:index=7 allowed=5 counter=1' \
        'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1' \
        'AppleDatePreferencesChangedNotification'; do
        /usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "RunApplicationEventLoop exact-eight registration broker marker missing: $marker"
    done
fi
/usr/bin/strings "$SEC_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_SEC_BUILD_ID" || die 68 "Security build marker missing"
/usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_CGS_BUILD_ID" || die 68 "CGS build marker missing"
if [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'com.apple.dock.server' ||
        die 68 "DockServer service marker missing from CGS interposer"
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' ||
        die 68 "DockServer adapter PASS marker missing from CGS interposer"
fi
if [ -n "$FONTSERVER_COMPAT_MODE" ]; then
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'com.apple.FontServer' ||
        die 68 "FontServer service marker missing from CGS interposer"
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' ||
        die 68 "FontServer adapter PASS marker missing from CGS interposer"
fi
if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:' ||
        die 68 "FontServer RPC trace request marker missing from CGS interposer"
    /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REPLY:' ||
        die 68 "FontServer RPC trace reply marker missing from CGS interposer"
fi
if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    for marker in \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_CALL:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REQUEST:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_MACH_RETURN:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_REPLY:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REPLY:' \
        'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS'; do
        /usr/bin/strings "$CGS_INTERPOSER" | /usr/bin/grep -Fq "$marker" ||
            die 68 "FontServer rendezvous compatibility marker missing from CGS interposer: $marker"
    done
fi
if [ -n "$HITOOLBOX_TRACE" ]; then
    /usr/bin/strings "$HITOOLBOX_TRACE" | /usr/bin/grep -Fq \
        "PM_HITOOLBOX_CFBUNDLE_TRACE_BUILD_ID:$EXPECTED_HITOOLBOX_TRACE_BUILD_ID" ||
        die 68 "HIToolbox trace build marker missing"
    /usr/bin/nm -u "$HITOOLBOX_TRACE" | /usr/bin/grep -Fq '_dlsym' &&
        die 68 "HIToolbox trace unexpectedly imports dlsym"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    /usr/bin/strings "$HITOOLBOX_EXTRAS_COMPAT" | /usr/bin/grep -Fq \
        "PM_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID:$EXPECTED_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID" ||
        die 68 "HIToolbox Extras compatibility build marker missing"
    /usr/bin/nm -u "$HITOOLBOX_EXTRAS_COMPAT" | /usr/bin/grep -Fq '_dlsym' &&
        die 68 "HIToolbox Extras compatibility dylib unexpectedly imports dlsym"
fi

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
if [ -n "$HITOOLBOX_TRACE" ]; then
    HITOOLBOX_TRACE_ABS="$(abspath "$HITOOLBOX_TRACE")"
    [ -n "$HITOOLBOX_TRACE_ABS" ] || die 68 "could not resolve HIToolbox trace path"
    INSERTED="$INSERTED:$HITOOLBOX_TRACE_ABS"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    HITOOLBOX_EXTRAS_COMPAT_ABS="$(abspath "$HITOOLBOX_EXTRAS_COMPAT")"
    HITOOLBOX_EXTRAS_RESOURCE_ABS="$(abspath "$HITOOLBOX_EXTRAS_RESOURCE")"
    [ -n "$HITOOLBOX_EXTRAS_COMPAT_ABS" ] || die 68 "could not resolve HIToolbox Extras compatibility path"
    [ -n "$HITOOLBOX_EXTRAS_RESOURCE_ABS" ] || die 68 "could not resolve staged Extras.rsrc path"
    INSERTED="$INSERTED:$HITOOLBOX_EXTRAS_COMPAT_ABS"
fi
if [ -n "$TITLEBAR_BSEARCH_COMPAT" ]; then
    TITLEBAR_BSEARCH_ABS="$(abspath "$TITLEBAR_BSEARCH_COMPAT")"
    [ -n "$TITLEBAR_BSEARCH_ABS" ] || die 68 "could not resolve titlebar bsearch compatibility path"
    INSERTED="$INSERTED:$TITLEBAR_BSEARCH_ABS"
fi
log "coreservices_cps_registration_compat_absolute_path=$CORE_ABS"
log "security_interposer_absolute_path=$SEC_ABS"
log "cgs_interposer_absolute_path=$CGS_ABS"
log "distributed_notifications_broker_absolute_path=$BROKER_ABS"
if [ -n "$HITOOLBOX_TRACE" ]; then
    log "hitoolbox_cfbundle_trace_absolute_path=$HITOOLBOX_TRACE_ABS"
fi
if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    log "hitoolbox_extras_compat_absolute_path=$HITOOLBOX_EXTRAS_COMPAT_ABS"
    log "hitoolbox_extras_resource_absolute_path=$HITOOLBOX_EXTRAS_RESOURCE_ABS"
    export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE="$HITOOLBOX_EXTRAS_MODE"
    export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$HITOOLBOX_EXTRAS_RESOURCE_ABS"
fi
if [ -n "$TITLEBAR_BSEARCH_COMPAT" ]; then
    log "coreui_titlebar_bsearch_compat_absolute_path=$TITLEBAR_BSEARCH_ABS"
    log "coreui_titlebar_bsearch_compat_sha256=$TITLEBAR_BSEARCH_BEFORE"
    log "coreui_titlebar_bsearch_mode=$TITLEBAR_BSEARCH_MODE"
    log "coreui_titlebar_artfile_sha256=$TITLEBAR_ARTFILE_BEFORE"
    export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE="$TITLEBAR_BSEARCH_MODE"
fi
if [ -n "$SCHEMA_AUDIT_REPORT" ]; then
    : > "$SCHEMA_AUDIT_REPORT" || die 73 "could not initialize schema audit report: $SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_schema_audit_report=$SCHEMA_AUDIT_REPORT"
fi
if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ]; then
    : > "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize post-Extras schema audit report: $POST_EXTRAS_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT="$POST_EXTRAS_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_post_extras_schema_audit_report=$POST_EXTRAS_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ]; then
    : > "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize post-FontServer schema audit report: $POST_FONTSERVER_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT="$POST_FONTSERVER_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_post_fontserver_schema_audit_report=$POST_FONTSERVER_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    : > "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize post-ShowWindow schema audit report: $POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT="$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_post_showwindow_schema_audit_report=$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize seventh-request schema audit report: $POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT="$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_post_showwindow_seventh_schema_audit_report=$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize RunApplicationEventLoop eighth-request schema audit report: $RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT="$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_runapplicationeventloop_eighth_schema_audit_report=$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize RunApplicationEventLoop ninth-request schema audit report: $RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT="$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_runapplicationeventloop_ninth_schema_audit_report=$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize RunApplicationEventLoop tenth-request schema audit report: $RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT="$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_runapplicationeventloop_tenth_schema_audit_report=$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize RunApplicationEventLoop eleventh-request schema audit report: $RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT="$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_runapplicationeventloop_eleventh_schema_audit_report=$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize RunApplicationEventLoop twelfth-request schema audit report: $RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT="$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_runapplicationeventloop_twelfth_schema_audit_report=$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ]; then
    : > "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ||
        die 73 "could not initialize RunApplicationEventLoop thirteenth-request schema audit report: $RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT"
    export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT="$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT"
    log "distributed_notifications_runapplicationeventloop_thirteenth_schema_audit_report=$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT"
fi
if [ -n "$REAL_REGISTRATION_MODE" ]; then
    log "distributed_notifications_real_registration_mode=$REAL_REGISTRATION_MODE"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ]; then
    log "distributed_notifications_runapplicationeventloop_eighth_registration_mode=$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ]; then
    log "distributed_notifications_runapplicationeventloop_ninth_registration_mode=$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ]; then
    log "distributed_notifications_runapplicationeventloop_tenth_registration_mode=$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ]; then
    log "distributed_notifications_runapplicationeventloop_eleventh_registration_mode=$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE"
fi
if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" ]; then
    log "distributed_notifications_runapplicationeventloop_twelfth_registration_mode=$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE"
fi
if [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
    log "dockserver_bootstrap_compat_mode=$DOCKSERVER_COMPAT_MODE"
    export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE="$DOCKSERVER_COMPAT_MODE"
else
    unset ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE
fi
if [ -n "$FONTSERVER_COMPAT_MODE" ]; then
    log "fontserver_bootstrap_compat_mode=$FONTSERVER_COMPAT_MODE"
    export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE="$FONTSERVER_COMPAT_MODE"
else
    unset ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE
fi
if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    log "fontserver_rpc_trace_mode=$FONTSERVER_RPC_TRACE_MODE"
    export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE="$FONTSERVER_RPC_TRACE_MODE"
else
    unset ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE
fi
if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    log "fontserver_rendezvous_compat_mode=$FONTSERVER_RENDEZVOUS_COMPAT_MODE"
    export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE="$FONTSERVER_RENDEZVOUS_COMPAT_MODE"
else
    unset ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE
fi
if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    log "cgs_newwindow_compat_mode=$NEWWINDOW_COMPAT_MODE"
    export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE="$NEWWINDOW_COMPAT_MODE"
else
    unset ROSETTA_CGS_NEWWINDOW_COMPAT_MODE
fi
if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    log "cgs_releasebacking_compat_mode=$RELEASEBACKING_COMPAT_MODE"
    export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE="$RELEASEBACKING_COMPAT_MODE"
else
    unset ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE
fi
if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    log "cgs_post_releasebacking_opacity_alpha_trace_mode=$OPACITY_ALPHA_TRACE_MODE"
fi
if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    log "cgs_opacity_alpha_create_compat_mode=$OPACITY_ALPHA_CREATE_COMPAT_MODE"
    export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE="$OPACITY_ALPHA_CREATE_COMPAT_MODE"
else
    unset ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE
fi
if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
    log "post_createwindow_title_validation_mode=$POST_CREATEWINDOW_TITLE_MODE"
fi
if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
    log "post_windowtitle_showwindow_validation_mode=$POST_WINDOWTITLE_SHOWWINDOW_MODE"
fi
if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
    log "post_showwindow_selectwindow_validation_mode=$POST_SHOWWINDOW_SELECTWINDOW_MODE"
fi
if [ -n "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" ]; then
    log "post_selectwindow_iswindowvisible_validation_mode=$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE"
fi
if [ -n "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" ]; then
    log "post_iswindowvisible_neweventlooptimerupp_validation_mode=$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE"
fi
if [ -n "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" ]; then
    log "post_neweventlooptimerupp_getmaineventloop_validation_mode=$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE"
fi
if [ -n "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" ]; then
    log "post_getmaineventloop_installeventlooptimer_validation_mode=$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE"
fi
if [ -n "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" ]; then
    log "post_installeventlooptimer_quitapplicationeventloop_validation_mode=$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE"
fi
if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
    log "post_quitapplicationeventloop_runapplicationeventloop_validation_mode=$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE"
fi
if [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
    log "showwindow_unknown_cgs_trace_mode=$SHOWWINDOW_UNKNOWN_TRACE_MODE"
    export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE="$SHOWWINDOW_UNKNOWN_TRACE_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE
fi
if [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
    log "showwindow_add_tracking_area_compat_mode=$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE"
    export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE="$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
    log "showwindow_order_front_conditionally_compat_mode=$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE"
    export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE="$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
    log "showwindow_set_front_window_compat_mode=$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE"
    export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE="$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
    log "showwindow_color_profile_client_trace_mode=$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE"
    export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE="$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    log "showwindow_color_profile_client_compat_mode=$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE"
    export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE="$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE" ]; then
    log "showwindow_color_profile_resolve_compat_mode=$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE"
    export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE="$SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE
fi
if [ -n "$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE" ]; then
    log "showwindow_window_backing_info_compat_mode=$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE"
    export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE="$SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE"
else
    unset ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE
fi

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

if [ -n "$TITLEBAR_BSEARCH_COMPAT" ]; then
    TITLEBAR_DISABLED_CLEAR_TRANSLATED="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=disabled-clear mode=lion-exact-six-v1 action=TRANSLATED' "$RAW_LOG" 2>/dev/null || true)"
    TITLEBAR_DISABLED_MINUS_TRANSLATED="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=disabled-minus mode=lion-exact-six-v1 action=TRANSLATED' "$RAW_LOG" 2>/dev/null || true)"
    TITLEBAR_DISABLED_ZOOM_TRANSLATED="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=disabled-zoom mode=lion-exact-six-v1 action=TRANSLATED' "$RAW_LOG" 2>/dev/null || true)"
    TITLEBAR_ACTIVE_CLEAR_TRANSLATED="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=active-clear mode=lion-exact-six-v1 action=TRANSLATED' "$RAW_LOG" 2>/dev/null || true)"
    TITLEBAR_ACTIVE_MINUS_TRANSLATED="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=active-minus mode=lion-exact-six-v1 action=TRANSLATED' "$RAW_LOG" 2>/dev/null || true)"
    TITLEBAR_ACTIVE_ZOOM_TRANSLATED="$(/usr/bin/grep -c 'PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=active-zoom mode=lion-exact-six-v1 action=TRANSLATED' "$RAW_LOG" 2>/dev/null || true)"
    TITLEBAR_GUARD_REJECTS="$(/usr/bin/grep -c 'GUARD_REJECT_PASSTHROUGH' "$RAW_LOG" 2>/dev/null || true)"
    log "coreui_titlebar_disabled_clear_translated_count=$TITLEBAR_DISABLED_CLEAR_TRANSLATED"
    log "coreui_titlebar_disabled_minus_translated_count=$TITLEBAR_DISABLED_MINUS_TRANSLATED"
    log "coreui_titlebar_disabled_zoom_translated_count=$TITLEBAR_DISABLED_ZOOM_TRANSLATED"
    log "coreui_titlebar_active_clear_translated_count=$TITLEBAR_ACTIVE_CLEAR_TRANSLATED"
    log "coreui_titlebar_active_minus_translated_count=$TITLEBAR_ACTIVE_MINUS_TRANSLATED"
    log "coreui_titlebar_active_zoom_translated_count=$TITLEBAR_ACTIVE_ZOOM_TRANSLATED"
    log "coreui_titlebar_guard_reject_count=$TITLEBAR_GUARD_REJECTS"
    if [ "$TITLEBAR_DISABLED_CLEAR_TRANSLATED" -lt 1 ] ||
       [ "$TITLEBAR_DISABLED_MINUS_TRANSLATED" -lt 1 ] ||
       [ "$TITLEBAR_DISABLED_ZOOM_TRANSLATED" -lt 1 ] ||
       [ "$TITLEBAR_ACTIVE_CLEAR_TRANSLATED" -lt 1 ] ||
       [ "$TITLEBAR_ACTIVE_MINUS_TRANSLATED" -lt 1 ] ||
       [ "$TITLEBAR_ACTIVE_ZOOM_TRANSLATED" -lt 1 ] ||
       [ "$TITLEBAR_GUARD_REJECTS" -ne 0 ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COREUI_TITLEBAR_BSEARCH_COMPAT_PREDICATE_NOT_PASSED"
        exit 0
    fi
fi

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
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=1' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_INGRESS_NOT_ESTABLISHED"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS' "$RAW_LOG"; then
    log "distributed_notifications_lookup_result_marker_status=PASS"
else
    log "distributed_notifications_lookup_result_marker_status=NOT_OBSERVED_OR_INTERLEAVED"
fi

if [ -n "$SCHEMA_AUDIT_REPORT" ]; then
    CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_CAPTURE:' "$RAW_LOG" 2>/dev/null || true)"
    REQUEST_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' "$RAW_LOG" 2>/dev/null || true)"
    log "schema_audit_capture_count=$CAPTURE_COUNT"
    log "legacy_mach_request_count=$REQUEST_COUNT"
    if [ -s "$SCHEMA_AUDIT_REPORT" ] &&
       [ "$CAPTURE_COUNT" -eq 3 ] &&
       [ "$REQUEST_COUNT" -eq 3 ] &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_REAL_SCHEMA_AUDIT_SUMMARY:requests=3 failures=0' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' "$RAW_LOG"; then
        log "schema_audit_output_sha256=$(sha256 "$SCHEMA_AUDIT_REPORT")"
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ]; then
    POST_EXTRAS_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    REQUEST_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' "$RAW_LOG" 2>/dev/null || true)"
    HITOOLBOX_EXTRAS_TARGET_COUNT="$(/usr/bin/grep -c 'PM_HITOOLBOX_EXTRAS_COMPAT_TARGET:.*mode=lion-fallback-external-v1.*bundle=com.apple.HIToolbox name=Extras type=rsrc' "$RAW_LOG" 2>/dev/null || true)"
    log "post_extras_schema_audit_capture_count=$POST_EXTRAS_CAPTURE_COUNT"
    log "legacy_mach_request_count=$REQUEST_COUNT"
    log "hitoolbox_extras_compat_target_count=$HITOOLBOX_EXTRAS_TARGET_COUNT"
    if [ -s "$POST_EXTRAS_SCHEMA_AUDIT_REPORT" ] &&
       [ "$POST_EXTRAS_CAPTURE_COUNT" -eq 1 ] &&
       [ "$REQUEST_COUNT" -eq 4 ] &&
       [ "$HITOOLBOX_EXTRAS_TARGET_COUNT" -ge 1 ] &&
       /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NULL fallback=NONNULL' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REJECT:status=25 intentional=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=3 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_EXTRAS_AUDIT_PASS' "$RAW_LOG"; then
        log "post_extras_schema_audit_output_sha256=$(sha256 "$POST_EXTRAS_SCHEMA_AUDIT_REPORT")"
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_POST_EXTRAS_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_POST_EXTRAS_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ]; then
    POST_FONTSERVER_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    REQUEST_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' "$RAW_LOG" 2>/dev/null || true)"
    FONT_CALLS="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_CALL:' "$RAW_LOG" 2>/dev/null || true)"
    FONT_PASSES="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "post_fontserver_schema_audit_capture_count=$POST_FONTSERVER_CAPTURE_COUNT"
    log "legacy_mach_request_count=$REQUEST_COUNT"
    log "fontserver_bootstrap_compat_call_count=$FONT_CALLS"
    log "fontserver_bootstrap_compat_pass_count=$FONT_PASSES"
    if [ -s "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT" ] &&
       [ "$POST_FONTSERVER_CAPTURE_COUNT" -eq 1 ] &&
       [ "$REQUEST_COUNT" -eq 5 ] &&
       [ "$FONT_CALLS" -ge 1 ] &&
       [ "$FONT_CALLS" -eq "$FONT_PASSES" ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T02_BEFORE_SetWindowTitleWithCFString' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=5 bits=0x00001111 id=4 size=356 payload=321' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REJECT:status=25 intentional=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=4 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_FONTSERVER_AUDIT_PASS' "$RAW_LOG"; then
        log "post_fontserver_schema_audit_output_sha256=$(sha256 "$POST_FONTSERVER_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ]; then
    POST_SHOWWINDOW_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    REQUEST_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' "$RAW_LOG" 2>/dev/null || true)"
    FIFTH_ACCEPT_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=5 allowed=4 behavior=1 publicBehavior=4 anyObject=YES' "$RAW_LOG" 2>/dev/null || true)"
    RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "post_showwindow_schema_audit_capture_count=$POST_SHOWWINDOW_CAPTURE_COUNT"
    log "legacy_mach_request_count=$REQUEST_COUNT"
    log "fifth_notification_registration_accept_count=$FIFTH_ACCEPT_COUNT"
    log "fontserver_rendezvous_compat_pass_count=$RENDEZVOUS_PASS_COUNT"
    if [ -s "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT" ] &&
       [ "$POST_SHOWWINDOW_CAPTURE_COUNT" -eq 1 ] &&
       [ "$REQUEST_COUNT" -eq 6 ] &&
       [ "$FIFTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_STATUS:SetWindowTitleWithCFString=0' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_RESULT:SETWINDOWTITLE_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=6 bits=0x00001111 id=4 size=320 payload=287' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REJECT:status=20 intentional=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=5 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_SHOWWINDOW_AUDIT_PASS' "$RAW_LOG"; then
        log "post_showwindow_schema_audit_output_sha256=$(sha256 "$POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    SEVENTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    REQUEST_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' "$RAW_LOG" 2>/dev/null || true)"
    FIFTH_ACCEPT_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=5 allowed=4 behavior=1 publicBehavior=4 anyObject=YES' "$RAW_LOG" 2>/dev/null || true)"
    SIXTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=6 allowed=3 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x2$' "$RAW_LOG" 2>/dev/null || true)"
    RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "post_showwindow_seventh_schema_audit_capture_count=$SEVENTH_CAPTURE_COUNT"
    log "legacy_mach_request_count=$REQUEST_COUNT"
    log "fifth_notification_registration_accept_count=$FIFTH_ACCEPT_COUNT"
    log "sixth_notification_registration_accept_count=$SIXTH_ACCEPT_COUNT"
    log "fontserver_rendezvous_compat_pass_count=$RENDEZVOUS_PASS_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    if [ -s "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$SEVENTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$REQUEST_COUNT" -eq 7 ] &&
       [ "$FIFTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$SIXTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       ! /usr/bin/grep -Fq '_CGSBindWindowBacking: cannot map backing data shmem' "$RAW_LOG" &&
       ! /usr/bin/grep -Fq '_CGSLockWindow: Unable to lock window' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=7 bits=0x00001111 id=4 size=356 payload=322' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=6 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_SHOWWINDOW_SEVENTH_AUDIT_PASS' "$RAW_LOG"; then
        log "post_showwindow_seventh_schema_audit_output_sha256=$(sha256 "$POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ]; then
    EIGHTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    SEVENTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=7 allowed=5 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "runapplicationeventloop_eighth_schema_audit_capture_count=$EIGHTH_CAPTURE_COUNT"
    log "seventh_notification_registration_accept_count=$SEVENTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ -s "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$EIGHTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$SEVENTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$TIMER_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       [ "$RC" -eq 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=8 bits=0x00001111 id=4 size=332 payload=298' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES' "$RAW_LOG" &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=[0-9]+ exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=7 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_EIGHTH_AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
        log "runapplicationeventloop_eighth_schema_audit_output_sha256=$(sha256 "$RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ]; then
    NINTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    EIGHTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=8 allowed=6 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "runapplicationeventloop_ninth_schema_audit_capture_count=$NINTH_CAPTURE_COUNT"
    log "eighth_notification_registration_accept_count=$EIGHTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ -s "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$NINTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$EIGHTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$TIMER_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       [ "$RC" -eq 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=9 bits=0x00001111 id=4 size=332 payload=298' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES' "$RAW_LOG" &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=[0-9]+ exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=8 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_NINTH_AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
        log "runapplicationeventloop_ninth_schema_audit_output_sha256=$(sha256 "$RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NINTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NINTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ]; then
    TENTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    NINTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=9 allowed=7 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "runapplicationeventloop_tenth_schema_audit_capture_count=$TENTH_CAPTURE_COUNT"
    log "ninth_notification_registration_accept_count=$NINTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ -s "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$TENTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$NINTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$TIMER_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       [ "$RC" -eq 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=10 bits=0x00001111 id=4 size=332 payload=300' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES' "$RAW_LOG" &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=[0-9]+ exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=9 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_TENTH_AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
        log "runapplicationeventloop_tenth_schema_audit_output_sha256=$(sha256 "$RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TENTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TENTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ]; then
    THIRTEENTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    TWELFTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=12 allowed=10 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "runapplicationeventloop_thirteenth_schema_audit_capture_count=$THIRTEENTH_CAPTURE_COUNT"
    log "twelfth_notification_registration_accept_count=$TWELFTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ -s "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$THIRTEENTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$TWELFTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$TIMER_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       [ "$RC" -eq 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=13 bits=0x00001111 id=4 size=356 payload=323' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES' "$RAW_LOG" &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=[0-9]+ exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=12 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_THIRTEENTH_AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
        log "runapplicationeventloop_thirteenth_schema_audit_output_sha256=$(sha256 "$RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi


if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ]; then
    TWELFTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    ELEVENTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=11 allowed=9 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "runapplicationeventloop_twelfth_schema_audit_capture_count=$TWELFTH_CAPTURE_COUNT"
    log "eleventh_notification_registration_accept_count=$ELEVENTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ -s "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$TWELFTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$ELEVENTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$TIMER_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       [ "$RC" -eq 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=12 bits=0x00001111 id=4 size=336 payload=302' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES' "$RAW_LOG" &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=[0-9]+ exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=11 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_TWELFTH_AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
        log "runapplicationeventloop_twelfth_schema_audit_output_sha256=$(sha256 "$RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi


if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ]; then
    ELEVENTH_CAPTURE_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_CAPTURE:index=' "$RAW_LOG" 2>/dev/null || true)"
    TENTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=10 allowed=8 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "runapplicationeventloop_eleventh_schema_audit_capture_count=$ELEVENTH_CAPTURE_COUNT"
    log "tenth_notification_registration_accept_count=$TENTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ -s "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT" ] &&
       [ "$ELEVENTH_CAPTURE_COUNT" -eq 1 ] &&
       [ "$TENTH_ACCEPT_COUNT" -eq 1 ] &&
       [ "$TIMER_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       [ "$RC" -eq 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=11 bits=0x00001111 id=4 size=356 payload=323' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES' "$RAW_LOG" &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=[0-9]+ exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=10 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_ELEVENTH_AUDIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
       /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
        log "runapplicationeventloop_eleventh_schema_audit_output_sha256=$(sha256 "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT")"
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_SCHEMA_AUDIT_PASS"
        exit 0
    fi
    log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_SCHEMA_AUDIT_INCOMPLETE"
    exit 0
fi

if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ] &&
   /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T02_BEFORE_SetWindowTitleWithCFString' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T03_AFTER_SetWindowTitleWithCFString' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=NON_TARGET' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'name=com.apple.FontServer' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=-304 hex=0xfffffed0 servicePort=0x00000000' "$RAW_LOG"; then
    log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_BOOTSTRAP_MINUS304"
    exit 0
fi

if [ -n "$FONTSERVER_COMPAT_MODE" ]; then
    FONT_CALLS="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_CALL:' "$RAW_LOG" 2>/dev/null || true)"
    FONT_PASSES="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "fontserver_bootstrap_compat_call_count=$FONT_CALLS"
    log "fontserver_bootstrap_compat_pass_count=$FONT_PASSES"
    if [ "$FONT_CALLS" -lt 1 ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_LOOKUP_NOT_REACHED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_FAIL' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_ADAPTER_FAILED"
        exit 0
    fi
    if [ "$FONT_PASSES" -lt 1 ] || [ "$FONT_PASSES" -ne "$FONT_CALLS" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_ADAPTER_INCOMPLETE"
        exit 0
    fi
fi

if [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ]; then
    FIFTH_ACCEPT_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=5 allowed=4 behavior=1 publicBehavior=4 anyObject=YES' "$RAW_LOG" 2>/dev/null || true)"
    log "fifth_notification_registration_accept_count=$FIFTH_ACCEPT_COUNT"
    if [ "$FIFTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
fi

if [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] ||
   [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; then
    FIFTH_ACCEPT_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=5 allowed=4 behavior=1 publicBehavior=4 anyObject=YES' "$RAW_LOG" 2>/dev/null || true)"
    SIXTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=6 allowed=3 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x2$' "$RAW_LOG" 2>/dev/null || true)"
    log "fifth_notification_registration_accept_count=$FIFTH_ACCEPT_COUNT"
    log "sixth_notification_registration_accept_count=$SIXTH_ACCEPT_COUNT"
    if [ "$FIFTH_ACCEPT_COUNT" -ne 1 ] || [ "$SIXTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
fi
if [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ]; then
    SEVENTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=7 allowed=5 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    log "seventh_notification_registration_accept_count=$SEVENTH_ACCEPT_COUNT"
    if [ "$SEVENTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
    if [ "$RC" -ne 0 ] &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' "$RAW_LOG" &&
       ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=7 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG" &&
       ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=8 ' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_TERMINATED_BEFORE_RETURN exit_status=$RC"
        exit 0
    fi
fi

if [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
    FONT_RPC_COUNT="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:index=' "$RAW_LOG" 2>/dev/null || true)"
    FONT_RPC_RETURN_COUNT="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_RPC_TRACE_MACH_RETURN:index=' "$RAW_LOG" 2>/dev/null || true)"
    log "fontserver_rpc_trace_request_count=$FONT_RPC_COUNT"
    log "fontserver_rpc_trace_return_count=$FONT_RPC_RETURN_COUNT"
    if [ "$FONT_RPC_COUNT" -lt 1 ] || [ "$FONT_RPC_RETURN_COUNT" -ne "$FONT_RPC_COUNT" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_INCOMPLETE"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:index=1 mode=lion-passive-v1' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST_HEX:index=1' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_FIRST_REQUEST_MISSING"
        exit 0
    fi
fi

if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
    FONTSERVER_RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "fontserver_rendezvous_compat_pass_count=$FONTSERVER_RENDEZVOUS_PASS_COUNT"

    if ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_CALL:index=1 rpcIndex=1 mode=lion-rendezvous-v1 exact=YES' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x000032c8 lionId=0x000032e7 send=0x00000018 legacyRecv=0x0000003c lionRecv=0x00000040 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
        exit 0
    fi

    if ! /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_MACH_FAILURE"
        exit 0
    fi

    if /usr/bin/grep -F 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_REPLY:index=1 ' "$RAW_LOG" |
       /usr/bin/grep -F 'bits=0x80001200 size=0x00000038 id=0x0000334b complex=YES descriptorCount=1 ' |
       /usr/bin/grep -Fq 'protocolVersion=5 explicitSize=0x00001000'; then
        if [ "$FONTSERVER_RENDEZVOUS_PASS_COUNT" -ne 1 ] ||
           ! /usr/bin/grep -F 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REPLY:index=1 replyClass=SUCCESS nativeId=0x0000334b legacyId=0x0000332c nativeSize=0x00000038 legacySize=0x00000034 protocolVersion=5 ' "$RAW_LOG" |
                /usr/bin/grep -F 'nativeExplicitSize=0x00001000 legacyExplicitSize=0x00001000 preservedPrefixChangedBytes=0 sourceChangedBytes=0 descriptorPreserved=YES ndrPreserved=YES explicitSizeRelocated=YES removedProtocolBytes=4' >/dev/null; then
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "fontserver_rendezvous_native_reply_class=SUCCESS"
    elif /usr/bin/grep -F 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_REPLY:index=1 ' "$RAW_LOG" |
         /usr/bin/grep -Fq 'bits=0x00001200 size=0x00000024 id=0x0000334b complex=NO'; then
        if [ "$FONTSERVER_RENDEZVOUS_PASS_COUNT" -ne 1 ] ||
           ! /usr/bin/grep -Eq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REPLY:index=1 replyClass=ERROR nativeId=0x0000334b legacyId=0x0000332c size=0x00000024 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 result=-?[1-9][0-9]* ndrSwapped=(YES|NO)' "$RAW_LOG"; then
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_ERROR_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "fontserver_rendezvous_native_reply_class=ERROR"
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE" ]; then
    TWELFTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=12 allowed=10 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "twelfth_notification_registration_accept_count=$TWELFTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_CB_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_CB_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_CB_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_CB_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ "$TWELFTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
        if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=13 bits=0x00001111 id=4 size=356 payload=323' "$RAW_LOG" &&
           [ "$RC" -eq 0 ] &&
           [ "$FOUND" -eq 0 ] &&
           [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
           [ "$WBI_PASS_COUNT" -eq 1 ] &&
           [ "$CPC_PASS_COUNT" -eq 1 ] &&
           [ "$CPR_PASS_COUNT" -eq 1 ] &&
           [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_PASS_THIRTEENTH_PROTOCOL_REJECTED"
        else
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_PASS_LATER_PROTOCOL_REJECTED_INHERITED_CHAIN_MISMATCH"
        fi
        exit 0
    fi
    if [ "$RC" -eq 0 ] &&
       [ "$FOUND" -eq 0 ] &&
       [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=12 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT"; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    else
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_INTEGRATION_INCOMPLETE"
    fi
    exit 0
fi


if [ -n "$RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE" ]; then
    ELEVENTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=11 allowed=9 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "eleventh_notification_registration_accept_count=$ELEVENTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_CB_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_CB_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_CB_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_CB_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ "$ELEVENTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
        if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=12 bits=0x00001111 id=4 size=336 payload=302' "$RAW_LOG" &&
           [ "$RC" -eq 0 ] &&
           [ "$FOUND" -eq 0 ] &&
           [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
           [ "$WBI_PASS_COUNT" -eq 1 ] &&
           [ "$CPC_PASS_COUNT" -eq 1 ] &&
           [ "$CPR_PASS_COUNT" -eq 1 ] &&
           [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_PASS_TWELFTH_PROTOCOL_REJECTED"
        else
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_PASS_LATER_PROTOCOL_REJECTED_INHERITED_CHAIN_MISMATCH"
        fi
        exit 0
    fi
    if [ "$RC" -eq 0 ] &&
       [ "$FOUND" -eq 0 ] &&
       [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
       [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
       [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
       [ "$WBI_PASS_COUNT" -eq 1 ] &&
       [ "$CPC_PASS_COUNT" -eq 1 ] &&
       [ "$CPR_PASS_COUNT" -eq 1 ] &&
       [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=11 callback=0 rejects=0 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT"; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    else
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_INCOMPLETE"
    fi
    exit 0
fi


if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ]; then
    TENTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=10 allowed=8 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "tenth_notification_registration_accept_count=$TENTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_CB_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_CB_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_CB_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_CB_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ "$TENTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TENTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
        if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=11 bits=0x00001111 id=4 size=356 payload=323' "$RAW_LOG" &&
           [ "$RC" -eq 0 ] &&
           [ "$FOUND" -eq 0 ] &&
           [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
           [ "$WBI_PASS_COUNT" -eq 1 ] &&
           [ "$CPC_PASS_COUNT" -eq 1 ] &&
           [ "$CPR_PASS_COUNT" -eq 1 ] &&
           [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TENTH_NOTIFICATION_REGISTRATION_PASS_ELEVENTH_PROTOCOL_REJECTED"
        else
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TENTH_NOTIFICATION_REGISTRATION_PASS_LATER_PROTOCOL_REJECTED_INHERITED_CHAIN_MISMATCH"
        fi
        exit 0
    fi
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ]; then
    NINTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=9 allowed=7 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "ninth_notification_registration_accept_count=$NINTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_CB_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_CB_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_CB_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_CB_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ "$NINTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NINTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
        if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=10 bits=0x00001111 id=4 size=332 payload=300' "$RAW_LOG" &&
           [ "$RC" -eq 0 ] &&
           [ "$FOUND" -eq 0 ] &&
           [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
           [ "$WBI_PASS_COUNT" -eq 1 ] &&
           [ "$CPC_PASS_COUNT" -eq 1 ] &&
           [ "$CPR_PASS_COUNT" -eq 1 ] &&
           [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NINTH_NOTIFICATION_REGISTRATION_PASS_TENTH_PROTOCOL_REJECTED"
        else
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NINTH_NOTIFICATION_REGISTRATION_PASS_LATER_PROTOCOL_REJECTED_INHERITED_CHAIN_MISMATCH"
        fi
        exit 0
    fi
fi

if [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ]; then
    EIGHTH_ACCEPT_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=8 allowed=6 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
    TIMER_CB_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPC_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "eighth_notification_registration_accept_count=$EIGHTH_ACCEPT_COUNT"
    log "runapplicationeventloop_timer_callback_enter_count=$TIMER_CB_ENTER_COUNT"
    log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_CB_BEFORE_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_CB_AFTER_QUIT_COUNT"
    log "runapplicationeventloop_timer_callback_exit_count=$TIMER_CB_EXIT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    log "color_profile_client_compat_pass_count=$CPC_PASS_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_PASS_COUNT"
    if [ "$EIGHTH_ACCEPT_COUNT" -ne 1 ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_REGISTRATION_NOT_ACCEPTED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
        if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=9 ' "$RAW_LOG" &&
           [ "$RC" -eq 0 ] &&
           [ "$FOUND" -eq 0 ] &&
           [ "$TIMER_CB_ENTER_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_BEFORE_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_AFTER_QUIT_COUNT" -eq 1 ] &&
           [ "$TIMER_CB_EXIT_COUNT" -eq 1 ] &&
           [ "$WBI_PASS_COUNT" -eq 1 ] &&
           [ "$CPC_PASS_COUNT" -eq 1 ] &&
           [ "$CPR_PASS_COUNT" -eq 1 ] &&
           [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_disabled_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_clear_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_minus_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_active_zoom_translated_count=1' "$REPORT" &&
           /usr/bin/grep -Fq 'coreui_titlebar_guard_reject_count=0' "$REPORT"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_REGISTRATION_PASS_NINTH_PROTOCOL_REJECTED"
        else
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_REGISTRATION_PASS_LATER_PROTOCOL_REJECTED_INHERITED_CHAIN_MISMATCH"
        fi
        exit 0
    fi
fi

if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REJECT:' "$RAW_LOG" ||
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_IPC_REQUEST:FAIL' "$RAW_LOG" ||
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_IPC_CALLBACK:REJECT' "$RAW_LOG" ||
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG"; then
    if [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=7 allowed=5 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_EIGHTH_PROTOCOL_REJECTED"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] &&
       /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=6 allowed=3 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x2$' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_REGISTRATION_PASS_SEVENTH_PROTOCOL_REJECTED"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=5 allowed=4 behavior=1 publicBehavior=4 anyObject=YES' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_PASS_SIXTH_PROTOCOL_REJECTED"
    elif [ -n "$FONTSERVER_COMPAT_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_PASS_NOTIFICATION_PROTOCOL_REJECTED"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ]; then
        log "RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATION_PROTOCOL_REJECTED"
    elif [ -n "$REAL_REGISTRATION_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PROTOCOL_REJECTED"
    elif /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:status=20' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_BROKER_SCHEMA_REJECTED"
    else
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_PROTOCOL_REJECTED"
    fi
    exit 0
fi

if /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M21_AFTER_CreateNewWindow' "$RAW_LOG"; then
    if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000038 id=0x000073fe result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b0 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        OPACITY_CREATE_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
        OPACITY_CREATE_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
        log "cgs_opacity_alpha_create_compat_call_count=$OPACITY_CREATE_COMPAT_COUNT"
        log "cgs_opacity_alpha_create_legacy_trace_count=$OPACITY_CREATE_TRACE_COUNT"
        if [ "$OPACITY_CREATE_COMPAT_COUNT" -ne 1 ] || [ "$OPACITY_CREATE_TRACE_COUNT" -ne 1 ]; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_PREDICATE_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES .*releaseBackingCompatCalls=1 newWindowCompatCalls=1' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x0000724f lionId=0x00007250 send=0x00000024 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_MACH_FAILURE"
            exit 0
        fi
        if /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b4 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
            if /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b4 legacyId=0x000072b3 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" &&
               /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
               /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" &&
               /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001200 size=0x00000024 id=0x000072b3 expected=0x000072b3 idMatch=YES' "$RAW_LOG"; then
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
            else
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            fi
            exit 0
        fi
        if /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b4 result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG" &&
           /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b4 legacyId=0x000072b3 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'id=0x000072b3 expected=0x000072b3 idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_ERROR_PRESERVED"
            exit 0
        fi
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
    if [ -n "$OPACITY_ALPHA_TRACE_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000038 id=0x000073fe result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b0 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        OPACITY_CREATE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
        OPACITY_TERMINATE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
        OPACITY_TOTAL_COUNT=$((OPACITY_CREATE_COUNT + OPACITY_TERMINATE_COUNT))
        log "cgs_opacity_alpha_create_legacy_trace_count=$OPACITY_CREATE_COUNT"
        log "cgs_opacity_alpha_terminate_legacy_trace_count=$OPACITY_TERMINATE_COUNT"
        log "cgs_opacity_alpha_legacy_trace_count=$OPACITY_TOTAL_COUNT"
        if [ "$OPACITY_TOTAL_COUNT" -ne 1 ]; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_REQUEST_NOT_REACHED"
            exit 0
        fi
        if [ "$OPACITY_CREATE_COUNT" -eq 1 ]; then
            OPACITY_KIND="CREATE"
            if ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'id=0x0000724f expectedReply=0x000072b3 option=0x00000003 send=0x00000024 recv=0x0000002c' "$RAW_LOG"; then
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_CREATE_REQUEST_UNEXPECTED"
                exit 0
            fi
            MACH_KIND="CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY"
            EXPECTED_REPLY="0x000072b3"
        else
            OPACITY_KIND="TERMINATE"
            if ! /usr/bin/grep -Fq 'kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'id=0x00007250 expectedReply=0x000072b4 option=0x00000003 send=0x00000024 recv=0x0000002c' "$RAW_LOG"; then
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_TERMINATE_REQUEST_UNEXPECTED"
                exit 0
            fi
            MACH_KIND="CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY"
            EXPECTED_REPLY="0x000072b4"
        fi
        log "cgs_opacity_alpha_legacy_kind=$OPACITY_KIND"
        if /usr/bin/grep -Fq "kind=$MACH_KIND kr=268451844 hex=0x10004004" "$RAW_LOG"; then
            if /usr/bin/grep -Fq "PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:" "$RAW_LOG" &&
               /usr/bin/grep -Fq "kind=$MACH_KIND kr=268451844 hex=0x10004004" "$RAW_LOG"; then
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_${OPACITY_KIND}_MACH_RCV_TOO_LARGE_OBSERVED"
            else
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER_MISSING"
            fi
            exit 0
        fi
        if /usr/bin/grep -Fq "kind=$MACH_KIND kr=0 hex=0x00000000" "$RAW_LOG"; then
            if /usr/bin/grep -F "PM_CGS_CONNECTION_TRACE_REPLY:" "$RAW_LOG" | /usr/bin/grep -F "kind=$MACH_KIND" | /usr/bin/grep -Fq "size=0x00000024 id=$EXPECTED_REPLY expected=$EXPECTED_REPLY idMatch=YES"; then
                if [ "$OPACITY_KIND" = "TERMINATE" ]; then
                    log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_TERMINATE_ID_COLLISION_REPLY_OBSERVED"
                else
                    log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_CREATE_LEGACY_REPLY_OBSERVED"
                fi
            else
                log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_REPLY_UNEXPECTED"
            fi
            exit 0
        fi
        if /usr/bin/grep -Fq "PM_CGS_CONNECTION_TRACE_MACH_RETURN:" "$RAW_LOG" &&
           /usr/bin/grep -F "PM_CGS_CONNECTION_TRACE_MACH_RETURN:" "$RAW_LOG" | /usr/bin/grep -Fq "kind=$MACH_KIND"; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_${OPACITY_KIND}_MACH_FAILURE_OBSERVED"
        else
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_MACH_RETURN_MISSING"
        fi
        exit 0
    fi
    if [ -n "$RELEASEBACKING_COMPAT_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000038 id=0x000073fe result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        RELEASEBACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
        log "cgs_releasebacking_compat_call_count=$RELEASEBACKING_COMPAT_COUNT"
        if [ "$RELEASEBACKING_COMPAT_COUNT" -ne 1 ]; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_PREDICATE_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES .*releaseFlag=0x00000001 newWindowCompatCalls=1' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x0000724b lionId=0x0000724c send=0x00000028 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_ADAPTER_NOT_PASSED"
            exit 0
        fi
        if /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b0 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
            if /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b0 legacyId=0x000072af size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" &&
               /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
               /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$RAW_LOG"; then
                log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
            else
                log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            fi
            exit 0
        fi
        if /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b0 result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG" &&
           /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b0 legacyId=0x000072af size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_ERROR_PRESERVED"
            exit 0
        fi
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
    if [ -n "$RELEASEBACKING_TRACE_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000038 id=0x000073fe result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        RELEASEBACKING_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
        log "cgs_releasebacking_legacy_trace_count=$RELEASEBACKING_TRACE_COUNT"
        if [ "$RELEASEBACKING_TRACE_COUNT" -ne 1 ]; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_REQUEST_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY bits=0x00001513' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x0000724b expectedReply=0x000072af option=0x00000003 send=0x00000028 recv=0x0000002c' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_REQUEST_UNEXPECTED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY kr=0 hex=0x00000000' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_MACH_FAILURE"
            exit 0
        fi
        if /usr/bin/grep -Fq 'kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY bits=' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_LEGACY_REPLY_OBSERVED"
        else
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_TRACE_REPLY_UNEXPECTED"
        fi
        exit 0
    fi
    if [ -n "$NEWWINDOW_COMPAT_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=lion-inline-id-v1 exact=YES' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000038 id=0x000073fe result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000073fe legacyId=0x000073f8 size=0x00000038 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_CGS_CONNECTION_TRACE_REPLY:index=5 kind=CGS_CREATE_WINDOW_INLINE_LEGACY bits=0x00001200 size=0x00000038 id=0x000073f8 expected=0x000073f8 idMatch=YES' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
        exit 0
    fi
    if [ -n "$DOCKSERVER_COMPAT_MODE" ] &&
       /usr/bin/grep -Fq 'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_PASS_NO_RETURN"
        exit 0
    fi
    if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
        HITOOLBOX_EXTRAS_TARGET_COUNT="$(/usr/bin/grep -c 'PM_HITOOLBOX_EXTRAS_COMPAT_TARGET:.*mode=lion-fallback-external-v1.*bundle=com.apple.HIToolbox name=Extras type=rsrc' "$RAW_LOG" 2>/dev/null || true)"
        log "hitoolbox_extras_compat_target_count=$HITOOLBOX_EXTRAS_TARGET_COUNT"
        if [ "$HITOOLBOX_EXTRAS_TARGET_COUNT" -ge 1 ] &&
           /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NULL fallback=NONNULL' "$RAW_LOG" &&
           ! /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NULL fallback=NULL' "$RAW_LOG" &&
           ! /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NONNULL fallback=NOT_USED' "$RAW_LOG" &&
           /usr/bin/grep -Eq "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=$EXPECTED_REAL_REGISTRATION_COUNT callback=[0-9]+ rejects=0 exact=YES" "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_NO_RETURN"
        else
            log "RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_INCOMPLETE"
        fi
        exit 0
    fi
    if [ -n "$HITOOLBOX_TRACE" ]; then
        HITOOLBOX_TRACE_TARGET_COUNT="$(/usr/bin/grep -c 'PM_HITOOLBOX_CFBUNDLE_TRACE_TARGET:.*bundle=com.apple.HIToolbox name=Extras type=rsrc subdir=NULL localization=NULL' "$RAW_LOG" 2>/dev/null || true)"
        log "hitoolbox_cfbundle_trace_target_count=$HITOOLBOX_TRACE_TARGET_COUNT"
    fi
    if [ -n "$REAL_REGISTRATION_MODE" ] &&
       [ -n "$HITOOLBOX_TRACE" ] &&
       [ "$HITOOLBOX_TRACE_TARGET_COUNT" -ge 1 ] &&
       /usr/bin/grep -F 'PM_HITOOLBOX_CFBUNDLE_TRACE_RESULT:' "$RAW_LOG" | /usr/bin/grep -Fq ' url=NULL ' &&
       ! /usr/bin/grep -F 'PM_HITOOLBOX_CFBUNDLE_TRACE_RESULT:' "$RAW_LOG" | /usr/bin/grep -Fq ' url=NONNULL ' &&
       /usr/bin/grep -Fq 'HIToolbox: failed to copy resource URL for framework bundle.' "$RAW_LOG" &&
       /usr/bin/grep -Eq "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=$EXPECTED_REAL_REGISTRATION_COUNT callback=[0-9]+ rejects=0 exact=YES" "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_LOOKUP_CONFIRMED_NO_RETURN"
    elif [ -n "$REAL_REGISTRATION_MODE" ] &&
       /usr/bin/grep -Eq "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=$EXPECTED_REAL_REGISTRATION_COUNT callback=[0-9]+ rejects=0 exact=YES" "$RAW_LOG" &&
       /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REGISTRATIONS_ESTABLISHED_CREATEWINDOW_NO_RETURN"
    elif [ -n "$REAL_REGISTRATION_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_INCOMPLETE"
    else
        log "RESULT: CREATENEWWINDOW_NO_RETURN"
    fi
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_NOT_REACHED"
    exit 0
fi

if [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
    if ! /usr/bin/grep -Fq 'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_CALL:index=1 mode=lion-dockserver-v1' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_LOOKUP_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_ADAPTER_FAILED"
        exit 0
    fi
fi

if [ -n "$NEWWINDOW_TRACE_MODE" ]; then
    NEWWINDOW_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_INLINE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_newwindow_legacy_trace_count=$NEWWINDOW_TRACE_COUNT"
    if [ "$NEWWINDOW_TRACE_COUNT" -ne 1 ]; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_REQUEST_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY bits=0x00001513' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'id=0x00007394 expectedReply=0x000073f8 option=0x00000003' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'recv=0x00000040' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_REQUEST_UNEXPECTED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_MACH_FAILURE"
        exit 0
    fi
    if /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY bits=' "$RAW_LOG" &&
       /usr/bin/grep -Fq 'id=0x000073f8 expected=0x000073f8 idMatch=YES' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_LEGACY_REPLY_OBSERVED"
    else
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_REPLY_UNEXPECTED"
    fi
    exit 0
fi


if [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
    NEWWINDOW_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    NEWWINDOW_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_INLINE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_newwindow_compat_call_count=$NEWWINDOW_COMPAT_COUNT"
    log "cgs_newwindow_legacy_trace_count=$NEWWINDOW_TRACE_COUNT"

    if [ "$NEWWINDOW_COMPAT_COUNT" -ne 1 ] || [ "$NEWWINDOW_TRACE_COUNT" -ne 1 ]; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_PREDICATE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_CALL:index=1 mode=lion-inline-id-v1 exact=YES' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'registrationCalls=1 setFrontCalls=1' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_PREDICATE_NOT_MET"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x00007394 lionId=0x0000739a send=0x00000068 recv=0x00000040 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_NATIVE_MACH_FAILURE"
        exit 0
    fi

    if /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000038 id=0x000073fe result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
        if ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000073fe legacyId=0x000073f8 size=0x00000038 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_INLINE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x000073f8 expected=0x000073f8 idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_LEGACY_FACING_SUCCESS_REPLY_NOT_ACCEPTED"
            exit 0
        fi
        log "cgs_newwindow_native_reply_class=SUCCESS"
    elif /usr/bin/grep -Eq 'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000073fe result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG"; then
        if ! /usr/bin/grep -Eq 'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000073fe legacyId=0x000073f8 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x000073f8 expected=0x000073f8 idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_ERROR_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_newwindow_native_reply_class=ERROR"
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
    RELEASEBACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    RELEASEBACKING_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_SET_WINDOW_RELEASE_BACKING_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_releasebacking_compat_call_count=$RELEASEBACKING_COMPAT_COUNT"
    log "cgs_releasebacking_legacy_trace_count=$RELEASEBACKING_TRACE_COUNT"

    if [ "$RELEASEBACKING_COMPAT_COUNT" -ne 1 ] || [ "$RELEASEBACKING_TRACE_COUNT" -ne 1 ]; then
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_PREDICATE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES .*releaseFlag=0x00000001 newWindowCompatCalls=1' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_PREDICATE_NOT_MET"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x0000724b lionId=0x0000724c send=0x00000028 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_MACH_FAILURE"
        exit 0
    fi

    if /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b0 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
        if ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b0 legacyId=0x000072af size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_releasebacking_native_reply_class=SUCCESS"
    elif /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b0 result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG"; then
        if ! /usr/bin/grep -Eq 'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b0 legacyId=0x000072af size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x000072af expected=0x000072af idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_ERROR_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_releasebacking_native_reply_class=ERROR"
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
    OPACITY_CREATE_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    OPACITY_CREATE_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_opacity_alpha_create_compat_call_count=$OPACITY_CREATE_COMPAT_COUNT"
    log "cgs_opacity_alpha_create_legacy_trace_count=$OPACITY_CREATE_TRACE_COUNT"
    if [ "$OPACITY_CREATE_COMPAT_COUNT" -ne 1 ] || [ "$OPACITY_CREATE_TRACE_COUNT" -ne 1 ]; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_PREDICATE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES .*releaseBackingCompatCalls=1 newWindowCompatCalls=1' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x0000724f lionId=0x00007250 send=0x00000024 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTER_NOT_PASSED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b4 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
        if ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b4 legacyId=0x000072b3 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001200 size=0x00000024 id=0x000072b3 expected=0x000072b3 idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_opacity_alpha_create_native_reply_class=SUCCESS"
    elif /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b4 result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG"; then
        if ! /usr/bin/grep -Eq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b4 legacyId=0x000072b3 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x000072b3 expected=0x000072b3 idMatch=YES' "$RAW_LOG"; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_ERROR_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_opacity_alpha_create_native_reply_class=ERROR"
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
    OPACITY_CREATE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    OPACITY_TERMINATE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    OPACITY_TOTAL_COUNT=$((OPACITY_CREATE_COUNT + OPACITY_TERMINATE_COUNT))
    log "cgs_opacity_alpha_create_legacy_trace_count=$OPACITY_CREATE_COUNT"
    log "cgs_opacity_alpha_terminate_legacy_trace_count=$OPACITY_TERMINATE_COUNT"
    log "cgs_opacity_alpha_legacy_trace_count=$OPACITY_TOTAL_COUNT"

    if [ "$OPACITY_TOTAL_COUNT" -ne 1 ]; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_REQUEST_NOT_REACHED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_UNEXPECTED_MACH_FAILURE"
        exit 0
    fi

    if [ "$OPACITY_CREATE_COUNT" -eq 1 ]; then
        OPACITY_KIND="CREATE"
        if ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x0000724f expectedReply=0x000072b3 option=0x00000003 send=0x00000024 recv=0x0000002c' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -F "PM_CGS_CONNECTION_TRACE_REPLY:" "$RAW_LOG" | /usr/bin/grep -F "kind=CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY" | /usr/bin/grep -Fq 'size=0x00000024 id=0x000072b3 expected=0x000072b3 idMatch=YES'; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_CREATE_SUCCESS_UNEXPECTED"
            exit 0
        fi
        log "cgs_opacity_alpha_legacy_kind=CREATE"
    elif [ "$OPACITY_TERMINATE_COUNT" -eq 1 ]; then
        OPACITY_KIND="TERMINATE"
        if ! /usr/bin/grep -Fq 'kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY bits=0x00001513' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'id=0x00007250 expectedReply=0x000072b4 option=0x00000003 send=0x00000024 recv=0x0000002c' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -F "PM_CGS_CONNECTION_TRACE_REPLY:" "$RAW_LOG" | /usr/bin/grep -F "kind=CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY" | /usr/bin/grep -Fq 'size=0x00000024 id=0x000072b4 expected=0x000072b4 idMatch=YES'; then
            log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_TERMINATE_SUCCESS_UNEXPECTED"
            exit 0
        fi
        log "cgs_opacity_alpha_legacy_kind=TERMINATE"
        log "cgs_opacity_alpha_id_collision=SNOW_TERMINATE_EQUALS_LION_CREATE"
    fi
fi

if [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
    SET_FRONT_WINDOW_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_SET_FRONT_WINDOW_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    SET_FRONT_WINDOW_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_SET_FRONT_WINDOW_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_set_front_window_compat_call_count=$SET_FRONT_WINDOW_COMPAT_COUNT"
    log "cgs_set_front_window_legacy_trace_count=$SET_FRONT_WINDOW_TRACE_COUNT"
    if [ "$SET_FRONT_WINDOW_COMPAT_COUNT" -ne 1 ] || [ "$SET_FRONT_WINDOW_TRACE_COUNT" -lt 1 ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_PREDICATE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* .*opacityCreateCompatCalls=1 orderFrontCompatCalls=1 addTrackingCompatCalls=1' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x000072f2 lionId=0x000072f5 send=0x00000024 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x00007359 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
        if ! /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x00007359 legacyId=0x00007356 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_SET_FRONT_WINDOW_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_SET_FRONT_WINDOW_LEGACY bits=0x00001200 size=0x00000024 id=0x00007356 expected=0x00007356 idMatch=YES' "$RAW_LOG"; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_set_front_window_native_reply_class=SUCCESS"
    elif /usr/bin/grep -Eq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x00007359 result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG" &&
         /usr/bin/grep -Eq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x00007359 legacyId=0x00007356 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" &&
         /usr/bin/grep -Fq 'PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
         /usr/bin/grep -Fq 'id=0x00007356 expected=0x00007356 idMatch=YES' "$RAW_LOG"; then
        log "cgs_set_front_window_native_reply_class=ERROR"
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
    COLOR_PROFILE_CLIENT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_color_profile_client_legacy_trace_count=$COLOR_PROFILE_CLIENT_TRACE_COUNT"
    if [ "$COLOR_PROFILE_CLIENT_TRACE_COUNT" -lt 1 ] ||
       ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY exact=YES bits=0x80001513 id=0x000074d4 send=0x00000034 recv=0x00000030' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000024 id=0x00007538 expected=0x00007538 idMatch=YES' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000024 id=0x00007538 expected=0x00007538 resultRaw=0xd0feffff clientIdRaw=0x00000000' "$RAW_LOG" ||
       /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LION' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_UNEXPECTED"
        exit 0
    fi
    log "cgs_color_profile_client_live_result=LEGACY_MINUS304"
fi

if [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ]; then
    COLOR_PROFILE_CLIENT_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    COLOR_PROFILE_CLIENT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_color_profile_client_compat_call_count=$COLOR_PROFILE_CLIENT_COMPAT_COUNT"
    log "cgs_color_profile_client_legacy_trace_count=$COLOR_PROFILE_CLIENT_TRACE_COUNT"
    if [ "$COLOR_PROFILE_CLIENT_COMPAT_COUNT" -lt 1 ] || [ "$COLOR_PROFILE_CLIENT_TRACE_COUNT" -lt 1 ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_PREDICATE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES lionPortExact=YES applicationPort=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* .*descriptorCount=1 .*disposition=0x13 type=0x00 .*newWindowCompatCalls=1 releaseBackingCompatCalls=1 opacityCreateCompatCalls=1 orderFrontCompatCalls=0 addTrackingCompatCalls=0 setFrontWindowCompatCalls=0' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x000074d4 lionId=0x000074d6 send=0x00000034 recv=0x00000030 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*pid=[1-9][0-9]*' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
        exit 0
    fi
    if /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000028 id=0x0000753a resultRaw=0x00000000 clientIdRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* replyClass=SUCCESS' "$RAW_LOG"; then
        if ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x0000753a legacyId=0x00007538 size=0x00000028 changedBytes=1 bodyChangedBytes=0 resultRaw=0x00000000 clientIdRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000028 id=0x00007538 expected=0x00007538 idMatch=YES' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:kind=CGS_COLOR_PROFILE_CLIENT_LEGACY bits=0x00001200 size=0x00000028 id=0x00007538 expected=0x00007538 resultRaw=0x00000000 clientIdRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG"; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_color_profile_client_native_reply_class=SUCCESS"
        if [ "$COLOR_PROFILE_CLIENT_COMPAT_COUNT" -ne 1 ] || [ "$COLOR_PROFILE_CLIENT_TRACE_COUNT" -ne 1 ]; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_RETRY_AFTER_ADAPTER"
            exit 0
        fi
    elif /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x0000753a resultRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* clientIdRaw=0x00000000 replyClass=ERROR' "$RAW_LOG" &&
         /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x0000753a legacyId=0x00007538 size=0x00000024 changedBytes=1 bodyChangedBytes=0 resultRaw=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* clientIdRaw=0x00000000 replyClass=ERROR' "$RAW_LOG" &&
         /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
        log "cgs_color_profile_client_native_reply_class=ERROR"
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
    WBI_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    WBI_PASSTHROUGH_COUNT="$(/usr/bin/grep -c 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:PASSTHROUGH' "$RAW_LOG" 2>/dev/null || true)"
    CPR_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    CPR_PASSTHROUGH_COUNT="$(/usr/bin/grep -c 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:PASSTHROUGH' "$RAW_LOG" 2>/dev/null || true)"
    WBI_EXPECTED_COUNT=1
    RUNAPPLICATIONEVENTLOOP_WBI_COUNT=0
    if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        WBI_EXPECTED_COUNT=2
        RUNAPPLICATIONEVENTLOOP_WBI_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop/{seen=1; next} seen && /PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop/{exit} seen && /PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:index=/{n++} END{print n+0}' "$RAW_LOG" 2>/dev/null)"
    fi
    log "window_backing_info_compat_call_count=$WBI_COMPAT_COUNT"
    log "window_backing_info_compat_pass_count=$WBI_PASS_COUNT"
    if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        log "runapplicationeventloop_window_backing_info_call_count=$RUNAPPLICATIONEVENTLOOP_WBI_COUNT"
    fi
    log "color_profile_resolve_compat_call_count=$CPR_COMPAT_COUNT"
    log "color_profile_resolve_compat_pass_count=$CPR_PASS_COUNT"
    if [ "$WBI_COMPAT_COUNT" -ne "$WBI_EXPECTED_COUNT" ] ||
       [ "$WBI_PASS_COUNT" -ne "$WBI_EXPECTED_COUNT" ] ||
       [ "$WBI_PASSTHROUGH_COUNT" -ne 0 ] ||
       { [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ] &&
         [ "$RUNAPPLICATIONEVENTLOOP_WBI_COUNT" -ne 1 ]; } ||
       [ "$CPR_COMPAT_COUNT" -ne 1 ] || [ "$CPR_PASS_COUNT" -ne 1 ] || [ "$CPR_PASSTHROUGH_COUNT" -ne 0 ]; then
        log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_ACCEPTED_FULL_STACK_COUNT_MISMATCH"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:index=1 adapted=0 mode=lion-id-v1 exact=YES applicationPortExact=YES .*newWindowCompatCalls=1 releaseBackingCompatCalls=1 opacityCreateCompatCalls=1 orderFrontCompatCalls=0 addTrackingCompatCalls=0 setFrontWindowCompatCalls=0 colorProfileClientCompatCalls=0 colorProfileResolveCompatCalls=0' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x00007263 lionId=0x00007264 send=0x00000024 recv=0x0000003c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 windowId=[1-9][0-9]*' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000034 id=0x000072c8 resultRaw=0x00000000 .*replyClass=SUCCESS' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072c8 legacyId=0x000072c7 size=0x00000034 changedBytes=1 bodyChangedBytes=0 resultRaw=0x00000000 .*replyClass=SUCCESS' "$RAW_LOG"; then
        log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_WINDOW_BACKING_INFO_BASELINE_NOT_PASSED"
        exit 0
    fi
    if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        if ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:index=2 adapted=0 mode=lion-id-v1 exact=YES applicationPortExact=YES .*' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REQUEST:index=2 legacyId=0x00007263 lionId=0x00007264 send=0x00000024 recv=0x0000003c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 windowId=[1-9][0-9]*' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_MACH_RETURN:index=2 kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_REPLY:index=2 bits=0x00001200 size=0x00000034 id=0x000072c8 resultRaw=0x00000000 .*replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REPLY:index=2 nativeId=0x000072c8 legacyId=0x000072c7 size=0x00000034 changedBytes=1 bodyChangedBytes=0 resultRaw=0x00000000 .*replyClass=SUCCESS' "$RAW_LOG"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_WINDOW_BACKING_INFO_NOT_PASSED"
            exit 0
        fi
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:index=1 adapted=0 mode=lion-id-v1 exact=YES provenanceExact=YES clientId=[1-9][0-9]* expectedClientId=[1-9][0-9]* profileId=1 .*' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x000074d7 lionId=0x000074d9 send=0x00000038 recv=0x0000003c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 clientId=[1-9][0-9]* profileId=1' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000034 id=0x0000753d resultRaw=0x00000000 ' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x0000753d legacyId=0x0000753b size=0x00000034 changedBytes=1 bodyChangedBytes=0 resultRaw=0x00000000 ' "$RAW_LOG"; then
        log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_COLOR_PROFILE_RESOLVE_BASELINE_NOT_PASSED"
        exit 0
    fi
    log "window_backing_info_native_reply_class=SUCCESS"
    if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        log "runapplicationeventloop_window_backing_info_native_reply_class=SUCCESS"
    fi
    log "color_profile_resolve_native_reply_class=SUCCESS"
fi

if [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
    ORDER_FRONT_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    ORDER_FRONT_ADAPTER_PASS_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_order_front_conditionally_compat_call_count=$ORDER_FRONT_COMPAT_COUNT"
    log "cgs_order_front_conditionally_legacy_trace_count=$ORDER_FRONT_TRACE_COUNT"
    log "cgs_order_front_conditionally_adapter_pass_count=$ORDER_FRONT_ADAPTER_PASS_COUNT"
    if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
        SELECTWINDOW_ORDER_FRONT_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWSELECT_MILESTONE:S02_BEFORE_SelectWindow/{seen=1; next} seen && /PM_POSTWINDOWSELECT_MILESTONE:S03_AFTER_SelectWindow/{exit} seen && /PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=/{n++} END{print n+0}' "$RAW_LOG" 2>/dev/null)"
        ORDER_FRONT_EXPECTED_COUNT=2
        RUNAPPLICATIONEVENTLOOP_ORDER_FRONT_COUNT=0
        if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
            ORDER_FRONT_EXPECTED_COUNT=3
            RUNAPPLICATIONEVENTLOOP_ORDER_FRONT_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop/{seen=1; next} seen && /PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop/{exit} seen && /PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=/{n++} END{print n+0}' "$RAW_LOG" 2>/dev/null)"
        fi
        log "selectwindow_order_front_conditionally_call_count=$SELECTWINDOW_ORDER_FRONT_COUNT"
        if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
            log "runapplicationeventloop_order_front_conditionally_call_count=$RUNAPPLICATIONEVENTLOOP_ORDER_FRONT_COUNT"
        fi
        if [ "$ORDER_FRONT_COMPAT_COUNT" -ne "$ORDER_FRONT_EXPECTED_COUNT" ] ||
           [ "$ORDER_FRONT_TRACE_COUNT" -ne "$ORDER_FRONT_EXPECTED_COUNT" ] ||
           [ "$ORDER_FRONT_ADAPTER_PASS_COUNT" -ne "$ORDER_FRONT_EXPECTED_COUNT" ] ||
           [ "$SELECTWINDOW_ORDER_FRONT_COUNT" -ne 1 ] ||
           { [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ] &&
             [ "$RUNAPPLICATIONEVENTLOOP_ORDER_FRONT_COUNT" -ne 1 ]; }; then
            log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COUNT_MISMATCH"
            exit 0
        fi
        if ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=1 mode=lion-selectwindow-id-v1 exact=YES .*opacityCreateCompatCalls=1 addTrackingCompatCalls=0' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x000072e7 lionId=0x000072ea send=0x00000034 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x0000734e result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x0000734e legacyId=0x0000734b size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=2 mode=lion-selectwindow-id-v1 exact=YES .*opacityCreateCompatCalls=1 addTrackingCompatCalls=1' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST:index=2 legacyId=0x000072e7 lionId=0x000072ea send=0x00000034 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_MACH_RETURN:index=2 kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:index=2 bits=0x00001200 size=0x00000024 id=0x0000734e result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:index=2 nativeId=0x0000734e legacyId=0x0000734b size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           { [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ] &&
             { ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=3 mode=lion-selectwindow-id-v1 exact=YES .*opacityCreateCompatCalls=1 addTrackingCompatCalls=1' "$RAW_LOG" ||
               ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST:index=3 legacyId=0x000072e7 lionId=0x000072ea send=0x00000034 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_MACH_RETURN:index=3 kr=0 hex=0x00000000' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:index=3 bits=0x00001200 size=0x00000024 id=0x0000734e result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:index=3 nativeId=0x0000734e legacyId=0x0000734b size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG"; }; }; then
            log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_order_front_conditionally_native_reply_class=SUCCESS"
        log "selectwindow_order_front_conditionally_native_reply_class=SUCCESS"
        if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
            log "runapplicationeventloop_order_front_conditionally_native_reply_class=SUCCESS"
        fi
    else
        ORDER_FRONT_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
        ORDER_FRONT_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
        log "cgs_order_front_conditionally_compat_call_count=$ORDER_FRONT_COMPAT_COUNT"
        log "cgs_order_front_conditionally_legacy_trace_count=$ORDER_FRONT_TRACE_COUNT"
        if [ "$ORDER_FRONT_COMPAT_COUNT" -ne 1 ] || [ "$ORDER_FRONT_TRACE_COUNT" -ne 1 ]; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_PREDICATE_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=1 mode=lion-id-v1 exact=YES .*opacityCreateCompatCalls=1 addTrackingCompatCalls=0' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x000072e7 lionId=0x000072ea send=0x00000034 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*windowId=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
            exit 0
        fi
        if /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x0000734e result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
            if ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x0000734e legacyId=0x0000734b size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
               ! /usr/bin/grep -Fq 'kind=CGS_ORDER_FRONT_CONDITIONALLY_LEGACY bits=0x00001200 size=0x00000024 id=0x0000734b expected=0x0000734b idMatch=YES' "$RAW_LOG"; then
                log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
                exit 0
            fi
            log "cgs_order_front_conditionally_native_reply_class=SUCCESS"
        elif /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x0000734e result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG" &&
             /usr/bin/grep -Eq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x0000734e legacyId=0x0000734b size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" &&
             /usr/bin/grep -Fq 'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
             /usr/bin/grep -Fq 'id=0x0000734b expected=0x0000734b idMatch=YES' "$RAW_LOG"; then
            log "cgs_order_front_conditionally_native_reply_class=ERROR"
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_ERROR_PRESERVED"
            exit 0
        else
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY_UNEXPECTED"
            exit 0
        fi
    fi
fi
if [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
    ADD_TRACKING_COMPAT_COUNT="$(/usr/bin/grep -c 'PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL:index=' "$RAW_LOG" 2>/dev/null || true)"
    ADD_TRACKING_TRACE_COUNT="$(/usr/bin/grep -c 'PM_CGS_CONNECTION_TRACE_REQUEST:.*kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY' "$RAW_LOG" 2>/dev/null || true)"
    log "cgs_add_tracking_area_compat_call_count=$ADD_TRACKING_COMPAT_COUNT"
    log "cgs_add_tracking_area_legacy_trace_count=$ADD_TRACKING_TRACE_COUNT"
    if [ "$ADD_TRACKING_COMPAT_COUNT" -ne 1 ] || [ "$ADD_TRACKING_TRACE_COUNT" -ne 1 ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_PREDICATE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL:index=1 mode=lion-inline-id-v1 exact=YES .*count=9 opacityCreateCompatCalls=1' "$RAW_LOG" ||
       ! /usr/bin/grep -Eq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x00007388 lionId=0x0000738e send=0x00000060 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*count=9' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0 hex=0x00000000' "$RAW_LOG"; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_REQUEST_ADAPTER_NOT_PASSED"
        exit 0
    fi
    if /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000073f2 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000' "$RAW_LOG"; then
        if ! /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000073f2 legacyId=0x000073ec size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY kr=0 hex=0x00000000' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'kind=CGS_ADD_TRACKING_AREA_INLINE_LEGACY bits=0x00001200 size=0x00000024 id=0x000073ec expected=0x000073ec idMatch=YES' "$RAW_LOG"; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_SUCCESS_REPLY_ADAPTER_NOT_PASSED"
            exit 0
        fi
        log "cgs_add_tracking_area_native_reply_class=SUCCESS"
    elif /usr/bin/grep -Eq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000073f2 result=-?[1-9][0-9]* ndrSwapped=YES replyClass=ERROR raw20=0x[0-9a-fA-F]+' "$RAW_LOG" &&
         /usr/bin/grep -Eq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000073f2 legacyId=0x000073ec size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=-?[1-9][0-9]* replyClass=ERROR' "$RAW_LOG" &&
         /usr/bin/grep -Fq 'PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
         /usr/bin/grep -Fq 'id=0x000073ec expected=0x000073ec idMatch=YES' "$RAW_LOG"; then
        log "cgs_add_tracking_area_native_reply_class=ERROR"
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_ERROR_PRESERVED"
        exit 0
    else
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_REPLY_UNEXPECTED"
        exit 0
    fi
fi

if [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ] &&
   [ "$FOUND" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:CreateNewWindow=-304' "$RAW_LOG" &&
   /usr/bin/grep -Eq "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=$EXPECTED_REAL_REGISTRATION_COUNT callback=[0-9]+ rejects=0 exact=YES" "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NULL fallback=NONNULL' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=NON_TARGET' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'name=com.apple.dock.server' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=-304 hex=0xfffffed0 servicePort=0x00000000' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATIONS_ESTABLISHED_DOCK_SERVER_MINUS304"
    exit 0
fi

if ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_STATUS:CreateNewWindow=0' "$RAW_LOG"; then
    if [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_PUBLIC_ERROR"
    elif [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_PUBLIC_ERROR"
    elif [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_SUCCESS_PUBLIC_ERROR"
    elif [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_NATIVE_SUCCESS_PUBLIC_ERROR"
    elif [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_ADAPTER_PASS_CREATEWINDOW_ERROR"
    else
        log "RESULT: CREATENEWWINDOW_RETURNED_ERROR"
    fi
    exit 0
fi

if ! /usr/bin/grep -Eq 'PM_POSTIDENTITY_WINDOW:pointer=0x[0-9a-fA-F]+ nonzero=YES' "$RAW_LOG" ||
   ! /usr/bin/grep -Fq 'PM_POSTIDENTITY_RESULT:CREATENEWWINDOW_PASS' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_NULL_OR_INVALID"
    exit 0
fi

if [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
    if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T00_BEFORE_CFStringCreateWithCString' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_STAGE_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T01_AFTER_CFStringCreateWithCString' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_CFSTRING_NO_RETURN"
        exit 0
    fi
    if ! /usr/bin/grep -Eq 'PM_POSTWINDOWTITLE_CFSTRING:pointer=0x[0-9a-fA-F]+ nonzero=YES' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_RESULT:CFSTRING_PASS' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_CFSTRING_FAILED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T02_BEFORE_SetWindowTitleWithCFString' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_SET_NOT_REACHED"
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T03_AFTER_SetWindowTitleWithCFString' "$RAW_LOG"; then
        if [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ] &&
           /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
           /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTED_REPLY:index=1 replyClass=SUCCESS' "$RAW_LOG"; then
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
        elif [ -n "$FONTSERVER_RPC_TRACE_MODE" ] &&
           /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:index=1 mode=lion-passive-v1' "$RAW_LOG"; then
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_CAPTURED"
        elif [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ] &&
           /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=5 allowed=4 behavior=1 publicBehavior=4 anyObject=YES' "$RAW_LOG"; then
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_PASS_POST_RPC_NO_RETURN"
        elif [ -n "$FONTSERVER_COMPAT_MODE" ] &&
           /usr/bin/grep -Fq 'PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
        else
            log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_SET_NO_RETURN"
        fi
        exit 0
    fi
    if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_STATUS:SetWindowTitleWithCFString=0' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_RESULT:SETWINDOWTITLE_PASS' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_SET_ERROR"
        exit 0
    fi
    if [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow' "$RAW_LOG"; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow' "$RAW_LOG"; then
            if [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
               /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:index=7 allowed=5 behavior=4 publicBehavior=2 anyObject=YES entry=0x[0-9a-fA-F]+ counter=0x1$' "$RAW_LOG"; then
                log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_SHOWWINDOW_NO_RETURN"
            elif [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ] &&
               /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG"; then
                log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
            elif [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE" ]; then
                log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_LEGACY_MINUS304"
            elif [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ]; then
                SHOWWINDOW_UNKNOWN_REQUEST_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow/{seen=1; next} seen && /PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow/{exit} seen && /PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST:index=/{n++} END{print n+0}' "$RAW_LOG" 2>/dev/null)"
                SHOWWINDOW_UNKNOWN_RETURN_COUNT="$(/usr/bin/awk '/PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow/{seen=1; next} seen && /PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow/{exit} seen && /PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN:index=/{n++} END{print n+0}' "$RAW_LOG" 2>/dev/null)"
                log "showwindow_unknown_cgs_trace_request_count=$SHOWWINDOW_UNKNOWN_REQUEST_COUNT"
                log "showwindow_unknown_cgs_trace_return_count=$SHOWWINDOW_UNKNOWN_RETURN_COUNT"
                if [ "$SHOWWINDOW_UNKNOWN_REQUEST_COUNT" -lt 1 ]; then
                    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_NOT_REACHED"
                elif [ "$SHOWWINDOW_UNKNOWN_RETURN_COUNT" -ne "$SHOWWINDOW_UNKNOWN_REQUEST_COUNT" ]; then
                    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_INCOMPLETE"
                elif [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ]; then
                    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
                elif [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ]; then
                    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
                elif [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ]; then
                    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN"
                else
                    log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_CAPTURED"
                fi
            else
                log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_NO_RETURN"
            fi
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSHOW_RESULT:SHOWWINDOW_PASS' "$RAW_LOG"; then
            log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_MARKER_INCOMPLETE"
            exit 0
        fi
    fi
    if [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSELECT_MILESTONE:S02_BEFORE_SelectWindow' "$RAW_LOG"; then
            log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSELECT_MILESTONE:S03_AFTER_SelectWindow' "$RAW_LOG"; then
            log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_NO_RETURN"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWSELECT_RESULT:SELECTWINDOW_PASS' "$RAW_LOG"; then
            log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_MARKER_INCOMPLETE"
            exit 0
        fi
    fi
    if [ -n "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWVISIBLE_MILESTONE:S04_BEFORE_IsWindowVisible' "$RAW_LOG"; then
            log "RESULT: POST_SELECTWINDOW_ISWINDOWVISIBLE_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWVISIBLE_MILESTONE:S05_AFTER_IsWindowVisible' "$RAW_LOG"; then
            log "RESULT: POST_SELECTWINDOW_ISWINDOWVISIBLE_NO_RETURN"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWVISIBLE_VALUE:visible=1' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_PASS' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_FALSE' "$RAW_LOG"; then
            log "RESULT: POST_SELECTWINDOW_ISWINDOWVISIBLE_VALUE_OR_MARKER_MISMATCH"
            exit 0
        fi
    fi
    if [ -n "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP' "$RAW_LOG"; then
            log "RESULT: POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP' "$RAW_LOG"; then
            log "RESULT: POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_NO_RETURN"
            exit 0
        fi
        if ! /usr/bin/grep -Eq 'PM_POSTWINDOWTIMERUPP_POINTER:pointer=0x[0-9a-fA-F]+ nonzero=YES' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_NULL' "$RAW_LOG"; then
            log "RESULT: POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_POINTER_OR_MARKER_MISMATCH"
            exit 0
        fi
    fi
    if [ -n "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S08_BEFORE_GetMainEventLoop' "$RAW_LOG"; then
            log "RESULT: POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S09_AFTER_GetMainEventLoop' "$RAW_LOG"; then
            log "RESULT: POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_NO_RETURN"
            exit 0
        fi
        if ! /usr/bin/grep -Eq 'PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_NULL' "$RAW_LOG"; then
            log "RESULT: POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_POINTER_OR_MARKER_MISMATCH"
            exit 0
        fi
    fi
    if [ -n "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_MILESTONE:S10_BEFORE_InstallEventLoopTimer' "$RAW_LOG"; then
            log "RESULT: POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_MILESTONE:S11_AFTER_InstallEventLoopTimer' "$RAW_LOG"; then
            log "RESULT: POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_NO_RETURN"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_STATUS:InstallEventLoopTimer=0' "$RAW_LOG" ||
           ! /usr/bin/grep -Eq 'PM_POSTWINDOWTIMERINSTALL_POINTER:pointer=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]* nonzero=YES' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=0' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_RETURNED_ERROR' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_NULL_TIMER' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_CALLBACK_FIRED_UNEXPECTEDLY' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMER_CALLBACK:FIRED' "$RAW_LOG"; then
            log "RESULT: POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_STATUS_POINTER_OR_CALLBACK_MISMATCH"
            exit 0
        fi
    fi
    if [ -n "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S12_BEFORE_QuitApplicationEventLoop' "$RAW_LOG"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_NOT_REACHED"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S13_AFTER_QuitApplicationEventLoop' "$RAW_LOG"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_NO_RETURN"
            exit 0
        fi
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=0' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_CALLBACK_FIRED_UNEXPECTEDLY' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMER_CALLBACK:FIRED' "$RAW_LOG"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MARKER_OR_CALLBACK_MISMATCH"
            exit 0
        fi
    fi
    if [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        if ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' "$RAW_LOG"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NOT_REACHED"
            exit 0
        fi
        TIMER_CB_ENTER_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:ENTER$' "$RAW_LOG" 2>/dev/null || true)"
        TIMER_CB_BEFORE_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
        TIMER_CB_AFTER_QUIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop$' "$RAW_LOG" 2>/dev/null || true)"
        TIMER_CB_EXIT_COUNT="$(/usr/bin/grep -c '^PM_POSTWINDOWTIMER_CALLBACK:EXIT$' "$RAW_LOG" 2>/dev/null || true)"
        log "runapplicationeventloop_timer_callback_enter_count=$TIMER_CB_ENTER_COUNT"
        log "runapplicationeventloop_timer_callback_before_quit_count=$TIMER_CB_BEFORE_QUIT_COUNT"
        log "runapplicationeventloop_timer_callback_after_quit_count=$TIMER_CB_AFTER_QUIT_COUNT"
        log "runapplicationeventloop_timer_callback_exit_count=$TIMER_CB_EXIT_COUNT"
        if [ "$TIMER_CB_ENTER_COUNT" -ne 1 ] ||
           [ "$TIMER_CB_BEFORE_QUIT_COUNT" -ne 1 ] ||
           [ "$TIMER_CB_AFTER_QUIT_COUNT" -ne 1 ] ||
           [ "$TIMER_CB_EXIT_COUNT" -ne 1 ] ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1' "$RAW_LOG" ||
           ! /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_CALLBACK_COUNT_MISMATCH' "$RAW_LOG" ||
           /usr/bin/grep -Fq 'PM_POSTWINDOWTIMER_CALLBACK:FIRED' "$RAW_LOG"; then
            log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_MARKER_OR_CALLBACK_MISMATCH"
            exit 0
        fi
    fi
    if ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T04_BEFORE_CFRelease' "$RAW_LOG" ||
       ! /usr/bin/grep -Fq 'PM_POSTWINDOWTITLE_MILESTONE:T05_AFTER_CFRelease' "$RAW_LOG"; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_CFRELEASE_INCOMPLETE"
        exit 0
    fi
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

if [ -n "$REAL_REGISTRATION_MODE" ] &&
   ! /usr/bin/grep -Eq "PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=$EXPECTED_REAL_REGISTRATION_COUNT callback=[0-9]+ rejects=0 exact=YES" "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_INCOMPLETE"
    exit 0
fi

if [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
    HITOOLBOX_EXTRAS_TARGET_COUNT="$(/usr/bin/grep -c 'PM_HITOOLBOX_EXTRAS_COMPAT_TARGET:.*mode=lion-fallback-external-v1.*bundle=com.apple.HIToolbox name=Extras type=rsrc' "$RAW_LOG" 2>/dev/null || true)"
    if [ "$HITOOLBOX_EXTRAS_TARGET_COUNT" -lt 1 ] ||
       ! /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NULL fallback=NONNULL' "$RAW_LOG" ||
       /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NULL fallback=NULL' "$RAW_LOG" ||
       /usr/bin/grep -Fq 'mode=lion-fallback-external-v1 original=NONNULL fallback=NOT_USED' "$RAW_LOG"; then
        log "RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_INCOMPLETE"
        exit 0
    fi
fi

if ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:pid=[0-9]+ exit=0$' "$RAW_LOG" ||
   ! /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=[0-9]+ callbacks=[0-9]+$' "$RAW_LOG"; then
    log "RESULT: CREATENEWWINDOW_DISTNOTIFY_LIFECYCLE_INCOMPLETE"
    exit 0
fi

if [ "$RC" -eq 0 ] && [ "$FOUND" -eq 0 ]; then
    if [ -n "$RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE" ] &&
       [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    elif [ -n "$RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE" ] &&
       [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_NINTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    elif [ -n "$RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE" ] &&
       [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_MODE" ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_MODE" ]; then
        log "RESULT: POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_MODE" ]; then
        log "RESULT: POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_MODE" ]; then
        log "RESULT: POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_MODE" ]; then
        log "RESULT: POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_SELECTWINDOW_ISWINDOWVISIBLE_MODE" ]; then
        log "RESULT: POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_SHOWWINDOW_SELECTWINDOW_MODE" ]; then
        log "RESULT: POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-seventh-register-v1" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    elif [ -n "$SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION_PASS"
    elif [ -n "$SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_INTEGRATION_PASS"
    elif [ -n "$SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION_PASS"
    elif [ -n "$SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_INTEGRATION_PASS"
    elif [ -n "$SHOWWINDOW_UNKNOWN_TRACE_MODE" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_SHOWWINDOW_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-showwindow-sixth-register-v1" ] &&
       [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    elif [ -n "$POST_WINDOWTITLE_SHOWWINDOW_MODE" ]; then
        log "RESULT: POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_PASS"
    elif [ -n "$FONTSERVER_RENDEZVOUS_COMPAT_MODE" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_INTEGRATION_PASS"
    elif [ -n "$FONTSERVER_RPC_TRACE_MODE" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_TITLE_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-windowtitle-fontserver-register-v1" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS"
    elif [ -n "$FONTSERVER_COMPAT_MODE" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_INTEGRATION_PASS"
    elif [ -n "$POST_CREATEWINDOW_TITLE_MODE" ]; then
        log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_VALIDATION_PASS"
    elif [ -n "$OPACITY_ALPHA_CREATE_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION_PASS"
    elif [ -n "$OPACITY_ALPHA_TRACE_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_CREATEWINDOW_PASS"
    elif [ -n "$RELEASEBACKING_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_INTEGRATION_PASS"
    elif [ -n "$NEWWINDOW_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_INTEGRATION_PASS"
    elif [ -n "$DOCKSERVER_COMPAT_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_DOCKSERVER_BOOTSTRAP_COMPAT_PASS"
    elif [ "$REAL_REGISTRATION_MODE" = "lion-createwindow-post-extras-register-v1" ]; then
        log "RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATION_PASS"
    elif [ -n "$HITOOLBOX_EXTRAS_COMPAT" ]; then
        log "RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_PASS"
    elif [ -n "$REAL_REGISTRATION_MODE" ]; then
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PASS"
    else
        log "RESULT: CREATENEWWINDOW_DISTNOTIFY_INTEGRATION_PASS"
    fi
    exit 0
fi

log "RESULT: CREATENEWWINDOW_PROCESS_STATE_UNEXPECTED rc=$RC diagnostics=$FOUND"
exit 0
