#!/bin/bash
set -e

# Dedicated full-stack build for the accepted Carbon GUI stack plus exact inline-event and GetWindowShape ID adapters.
OUT="${1:-./pm-carbon-gui-cgs-get-window-shape-compat.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_SRC="$ROOT/tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c"
INGRESS_SRC="$ROOT/tests/ppc-distributed-notifications-ingress-interposer.c"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"

# Keep each generated path component comfortably below legacy HFS+/POSIX NAME_MAX.
for generated in "$OUT" "$INFO" "$SHA"; do
    generated_name="$(/usr/bin/basename "$generated")"
    [ "${#generated_name}" -le 240 ] || {
        echo "error: artifact filename too long: $generated_name" >&2
        exit 64
    }
done

EXPECTED_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-next-event-inline-getwindowshape-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v8"
EXPECTED_INGRESS_BUILD_ID="distributed-notifications-ppc-ingress-interposer-v2"
EXPECTED_RESOLVE_TRACE_BUILD_ID="color-profile-resolve-passive-trace-v1"
EXPECTED_RESOLVE_COMPAT_BUILD_ID="color-profile-resolve-id-compat-v1"
EXPECTED_WBI_COMPAT_BUILD_ID="window-backing-info-id-compat-v1"
EXPECTED_CORE_SOURCE_SHA256="21bdd0214d196cafb58efdf234b64716ace6effc2b0445b1ad31e8bba8cecdca"
EXPECTED_INGRESS_SOURCE_SHA256="64e2896e614099978b0997daa02f17822dfdd8d38ab688634c4a30381739646e"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: build the Carbon smoke backing-sync full-stack compatibility dylib on Snow Leopard 10.6.8" >&2
    exit 65
}
[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
for file in "$CORE_SRC" "$INGRESS_SRC"; do
    [ -f "$file" ] || {
        echo "error: missing $file" >&2
        exit 66
    }
done

/usr/bin/grep -Fq "$EXPECTED_BUILD_ID" "$CORE_SRC" || {
    echo "error: stale CoreServices source; transfer the current verified runtime tree from the staging system" >&2
    exit 66
}
/usr/bin/grep -Fq "$EXPECTED_INGRESS_BUILD_ID" "$INGRESS_SRC" || {
    echo "error: stale distributed-notifications ingress source; transfer the current verified runtime tree from the staging system" >&2
    exit 66
}

CORE_SOURCE_SHA="$(/usr/bin/shasum -a 256 "$CORE_SRC" | /usr/bin/awk '{print $1}')"
INGRESS_SOURCE_SHA="$(/usr/bin/shasum -a 256 "$INGRESS_SRC" | /usr/bin/awk '{print $1}')"
[ "$CORE_SOURCE_SHA" = "$EXPECTED_CORE_SOURCE_SHA256" ] || {
    echo "error: CoreServices source SHA-256 mismatch: $CORE_SOURCE_SHA" >&2
    exit 66
}
[ "$INGRESS_SOURCE_SHA" = "$EXPECTED_INGRESS_SOURCE_SHA256" ] || {
    echo "error: distributed-notifications ingress source SHA-256 mismatch: $INGRESS_SOURCE_SHA" >&2
    exit 66
}

/bin/rm -f "$OUT" "$INFO" "$SHA"

BUILD_COMPLETE=0
cleanup_on_exit() {
    rc=$?
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$OUT" "$INFO" "$SHA"
    fi
    return "$rc"
}
trap cleanup_on_exit EXIT

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib \
    -DPM_CGS_GET_WINDOW_SHAPE_COMPAT_INTEGRATION=1 \
    -DPM_CGS_GET_PORT_STREAM_INLINE_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SHAPEWINDOW_INLINE_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_TRACE=1 \
    -DPM_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SHOWWINDOW_UNKNOWN_TRACE=1 \
    -DPM_CGS_CONNECTION_TRACE=1 \
    -DPM_CGS_NEWWINDOW_TRACE=1 \
    -DPM_CGS_NEWWINDOW_COMPAT_INTEGRATION=1 \
    -DPM_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE=1 \
    -DPM_CGS_RELEASEBACKING_COMPAT_INTEGRATION=1 \
    -DPM_CGS_POST_RELEASEBACKING_OPACITY_TRACE=1 \
    -DPM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION=1 \
    -DPM_CGS_SERVER_VERSION_COMPAT_INTEGRATION=1 \
    -DPM_CPS_REGISTRATION_TRACE=1 \
    -DPM_CPS_REGISTRATION_COMPAT_INTEGRATION=1 \
    -DPM_CPS_REGISTRATION_CARBON_SMOKETEST_COMPAT=1 \
    -DPM_CPS_SETFRONT_TRACE=1 \
    -DPM_CPS_SETFRONT_COMPAT_INTEGRATION=1 \
    -DPM_DISTRIBUTED_NOTIFICATIONS_INGRESS_INTEGRATION=1 \
    -DPM_DISTRIBUTED_NOTIFICATIONS_INGRESS_EMBEDDED=1 \
    "$CORE_SRC" "$INGRESS_SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
    -o "$OUT"

/bin/chmod 755 "$OUT"

macho_archs() {
    file="$1"
    info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
    case "$info" in
        *" is architecture: "*)
            echo "$info" | /usr/bin/sed 's/^.* is architecture: //'
            ;;
        *" are: "*)
            echo "$info" | /usr/bin/sed 's/^.* are: //'
            ;;
        *)
            return 1
            ;;
    esac
}

is_ppc32_arch_name() {
    case "$1" in
        ppc|ppc601|ppc603|ppc603e|ppc603ev|ppc604|ppc604e|ppc750|ppc7400|ppc7450|ppc970)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ARCHS="$(macho_archs "$OUT")" || {
    echo "error: cannot determine combined interposer architecture" >&2
    exit 70
}
FOUND_PPC32=0
for arch in $ARCHS; do
    is_ppc32_arch_name "$arch" && FOUND_PPC32=1
done
[ "$FOUND_PPC32" -eq 1 ] || {
    echo "error: combined interposer is not 32-bit PPC" >&2
    /usr/bin/lipo -info "$OUT" >&2 || true
    exit 70
}

/usr/bin/file "$OUT" | /usr/bin/grep -Fq 'Mach-O' || {
    echo "error: combined interposer is not Mach-O" >&2
    exit 70
}
/usr/bin/file "$OUT" | /usr/bin/grep -Fq ' ppc' || {
    echo "error: combined interposer is not PPC" >&2
    exit 70
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq '__interpose' || {
    echo "error: combined interpose section missing" >&2
    exit 71
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: combined interposer must contain exactly two PPC interpose tuples" >&2
    exit 71
}

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: combined CoreServices build marker missing" >&2
    exit 72
}
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:$EXPECTED_INGRESS_BUILD_ID" || {
    echo "error: embedded distributed-notifications ingress marker missing" >&2
    exit 72
}

for marker in \
    'CGS_GET_WINDOW_SHAPE_LEGACY' \
    'CGS_GET_WINDOW_SHAPE_LION' \
    'PM_CGS_GET_WINDOW_SHAPE_COMPAT_CALL:' \
    'PM_CGS_GET_WINDOW_SHAPE_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_GET_WINDOW_SHAPE_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_GET_WINDOW_SHAPE_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_GET_WINDOW_SHAPE_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_GET_WINDOW_SHAPE_COMPAT_RESULT:PASSTHROUGH' \
    'CGS_NEXT_EVENT_INLINE_LEGACY' \
    'CGS_NEXT_EVENT_INLINE_LION' \
    'PM_CGS_NEXT_EVENT_INLINE_COMPAT_CALL:' \
    'PM_CGS_NEXT_EVENT_INLINE_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_NEXT_EVENT_INLINE_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_NEXT_EVENT_INLINE_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:PASSTHROUGH' \
    'CGS_BACKING_SYNC_LEGACY' \
    'CGS_BACKING_SYNC_LION' \
    'PM_CGS_BACKING_SYNC_COMPAT_CALL:' \
    'PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_BACKING_SYNC_COMPAT_RESULT:PASSTHROUGH' \
    'CGS_SHAPEWINDOW_INLINE_LEGACY' \
    'CGS_SHAPEWINDOW_INLINE_LION' \
    'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_CALL:' \
    'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PASSTHROUGH' \
    'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST:' \
    'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST_HEX:' \
    'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN:' \
    'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_FAILURE_BUFFER_HEX:' \
    'PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REPLY_HEX:' \
    'CGS_ADD_TRACKING_AREA_INLINE_LEGACY' \
    'CGS_ADD_TRACKING_AREA_INLINE_LION' \
    'PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL:' \
    'PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:PASSTHROUGH' \
    'CGS_ORDER_FRONT_CONDITIONALLY_LEGACY' \
    'CGS_ORDER_FRONT_CONDITIONALLY_LION' \
    'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:' \
    'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:PASSTHROUGH' \
    'lion-selectwindow-id-v1' \
    'CGS_SET_FRONT_WINDOW_LEGACY' \
    'CGS_SET_FRONT_WINDOW_LION' \
    'CGS_COLOR_PROFILE_CLIENT_LEGACY' \
    'CGS_COLOR_PROFILE_CLIENT_LION' \
    'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REQUEST:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_TRACE_REPLY:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_CALL:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_MACH_RETURN:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:PASSTHROUGH' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:color-profile-resolve-passive-trace-v1' \
    'CGS_COLOR_PROFILE_RESOLVE_LEGACY' \
    'CGS_COLOR_PROFILE_RESOLVE_LION' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REQUEST:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REPLY:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_PREREQ:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_MACH_RETURN:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:PASSTHROUGH' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1' \
    'CGS_WINDOW_BACKING_INFO_LEGACY' \
    'CGS_WINDOW_BACKING_INFO_LION' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_MACH_RETURN:' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:PASSTHROUGH' \
    'PM_CGS_SET_FRONT_WINDOW_COMPAT_CALL:' \
    'PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:PASSTHROUGH' \
    'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS' \
    'lion-create-application-carbon-smoketest-v1' \
    'ppc-carbon-gui-smoketest-private-dyld' \
    'PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS' \
    'CGS_CREATE_WINDOW_INLINE_LEGACY' \
    'CGS_CREATE_WINDOW_INLINE_LION' \
    'PM_CGS_NEWWINDOW_COMPAT_CALL:' \
    'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_NEWWINDOW_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_NEWWINDOW_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_NEWWINDOW_COMPAT_RESULT:PASSTHROUGH' \
    'CGS_SET_WINDOW_RELEASE_BACKING_LEGACY' \
    'CGS_SET_WINDOW_RELEASE_BACKING_LION' \
    'PM_CGS_RELEASEBACKING_COMPAT_CALL:' \
    'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_RELEASEBACKING_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_RELEASEBACKING_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_RELEASEBACKING_COMPAT_RESULT:PASSTHROUGH' \
    'CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY' \
    'CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY' \
    'PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:' \
    'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_CALL:' \
    'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REQUEST:' \
    'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_REPLY:' \
    'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTED_REPLY:' \
    'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:PASSTHROUGH' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:'
do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: combined interposer marker missing: $marker" >&2
        exit 72
    }
done

if /usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_PASS'; then
    echo "error: obsolete name-only distributed-notifications adapter is present" >&2
    exit 72
fi

UNDEFINED="$(/usr/bin/nm -u "$OUT")"
for sym in \
    _bootstrap_look_up2 \
    _mach_msg \
    _mig_get_reply_port \
    _posix_spawn \
    _pthread_create \
    __NSGetEnviron
do
    echo "$UNDEFINED" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: combined interposer missing import $sym" >&2
        exit 72
    }
done

SOCKETPAIR_IMPORT=""
SOCKETPAIR_IMPORT_COUNT=0
for sym in $(echo "$UNDEFINED" | /usr/bin/awk '{print $NF}'); do
    case "$sym" in
        _socketpair|'_socketpair$UNIX2003')
            SOCKETPAIR_IMPORT="$sym"
            SOCKETPAIR_IMPORT_COUNT=$((SOCKETPAIR_IMPORT_COUNT + 1))
            ;;
    esac
done
[ "$SOCKETPAIR_IMPORT_COUNT" -eq 1 ] || {
    echo "error: combined interposer must import exactly one supported socketpair symbol" >&2
    echo 'expected: _socketpair or _socketpair$UNIX2003' >&2
    echo "$UNDEFINED" | /usr/bin/grep -F 'socketpair' >&2 || true
    exit 72
}

if echo "$UNDEFINED" | /usr/bin/grep -Eq '(^|[[:space:]])_environ$'; then
    echo "error: combined interposer must not import _environ directly" >&2
    exit 72
fi

{
    echo "== PPC Carbon GUI smoke + accepted stack + exact next-event inline + GetWindowShape ID compatibility interposer =="
    echo "resolve_trace_build_id=$EXPECTED_RESOLVE_TRACE_BUILD_ID"
    echo "resolve_compat_build_id=$EXPECTED_RESOLVE_COMPAT_BUILD_ID"
    echo "window_backing_info_compat_build_id=$EXPECTED_WBI_COMPAT_BUILD_ID"
    echo "compiler=$CC_SELECTED"
    echo "core_source=$CORE_SRC"
    echo "core_source_sha256=$CORE_SOURCE_SHA"
    echo "ingress_source=$INGRESS_SRC"
    echo "ingress_source_sha256=$INGRESS_SOURCE_SHA"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "embedded_ingress_build_id=$EXPECTED_INGRESS_BUILD_ID"
    echo "socketpair_import=$SOCKETPAIR_IMPORT"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

/usr/bin/shasum -a 256 "$OUT" > "$SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
