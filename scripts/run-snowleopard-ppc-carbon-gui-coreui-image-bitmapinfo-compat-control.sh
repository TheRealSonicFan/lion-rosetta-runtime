#!/bin/bash
set -u

EXE="${1:-./ppc-carbon-gui-smoketest-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_COMPAT="${3:-./pm-carbon-gui-backing-sync-compat.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
OBSERVER="${5:-./cgwindowlist-pid-observer}"
OBSERVER_SHA_FILE="${6:-$OBSERVER.sha256}"
SUBJECT_LOG="${7:-./ppc-carbon-gui-coreui-image-bitmapinfo-compat-snow.log}"
OBSERVER_LOG="${8:-./ppc-carbon-gui-coreui-image-bitmapinfo-compat-snow-observer.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_EXE_SHA="fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v6"
EXPECTED_OBSERVER_BUILD_ID="cgwindowlist-pid-observer-v1"

TITLEBAR_COMPAT="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH:-./pm-titlebar-bsearch-six-key-compat.dylib}"
TITLEBAR_SHA_FILE="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE:-$TITLEBAR_COMPAT.sha256}"
EXPECTED_TITLEBAR_SHA="6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72"
EXPECTED_TITLEBAR_BUILD_ID="coreui-titlebar-bsearch-exact-six-v2"

IMAGE_COMPAT="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH:-./pm-coreui-image-bitmapinfo-compat.dylib}"
IMAGE_COMPAT_SHA_FILE="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE:-$IMAGE_COMPAT.sha256}"
IMAGE_COMPAT_INFO_FILE="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE:-$IMAGE_COMPAT.info.txt}"
EXPECTED_IMAGE_COMPAT_BUILD_ID="coreui-image-bitmapinfo-compat-v1"
EXPECTED_IMAGE_COMPAT_SOURCE_BLOB="9d44128acbe49de49621104c9ffc2b0c0cd74589"

fail() {
    echo "error: $*" | /usr/bin/tee -a "$SUBJECT_LOG" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

sidecar_sha() {
    /usr/bin/awk 'NR==1 {print $1}' "$1"
}

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

has_ppc32_arch() {
    archs="$(macho_archs "$1")" || return 1
    for arch in $archs; do
        case "$arch" in
            ppc|ppc601|ppc603|ppc603e|ppc603ev|ppc604|ppc604e|ppc750|ppc7400|ppc7450|ppc970)
                return 0
                ;;
        esac
    done
    return 1
}

has_i386_arch() {
    archs="$(macho_archs "$1")" || return 1
    for arch in $archs; do
        [ "$arch" = "i386" ] && return 0
    done
    return 1
}

: > "$SUBJECT_LOG" || exit 73
: > "$OBSERVER_LOG" || exit 73

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

echo "== Snow Leopard PPC Carbon GUI CoreUI bitmap-info compatibility control ==" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$SUBJECT_LOG"

[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from logged-in Aqua console user's Terminal"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

for file in "$EXE" "$EXE_SHA_FILE" "$CORE_COMPAT" "$CORE_COMPAT_SHA_FILE" "$TITLEBAR_COMPAT" "$TITLEBAR_SHA_FILE" "$IMAGE_COMPAT" "$IMAGE_COMPAT_SHA_FILE" "$IMAGE_COMPAT_INFO_FILE" "$OBSERVER" "$OBSERVER_SHA_FILE" "$PRIVATE_DYLD"; do
    [ -e "$file" ] || fail "missing $file"
done
[ -x "$EXE" ] || fail "historical subject is not executable"
[ -x "$OBSERVER" ] || fail "observer is not executable"

EXE_SHA="$(sha256 "$EXE")"
CORE_SHA="$(sha256 "$CORE_COMPAT")"
OBSERVER_SHA="$(sha256 "$OBSERVER")"
TITLEBAR_SHA="$(sha256 "$TITLEBAR_COMPAT")"
IMAGE_COMPAT_SHA="$(sha256 "$IMAGE_COMPAT")"
DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"

echo "subject_sha256=$EXE_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "core_compat_sha256=$CORE_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_sha256=$OBSERVER_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "titlebar_compat_sha256=$TITLEBAR_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_compat_sha256=$IMAGE_COMPAT_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"

[ "$EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "historical subject hash mismatch"
[ "$(sidecar_sha "$EXE_SHA_FILE")" = "$EXPECTED_EXE_SHA" ] || fail "subject sidecar mismatch"
[ "$(sidecar_sha "$CORE_COMPAT_SHA_FILE")" = "$CORE_SHA" ] || fail "core compatibility sidecar mismatch"
[ "$(sidecar_sha "$OBSERVER_SHA_FILE")" = "$OBSERVER_SHA" ] || fail "observer sidecar mismatch"
[ "$TITLEBAR_SHA" = "$EXPECTED_TITLEBAR_SHA" ] || fail "titlebar compatibility hash mismatch"
[ "$(sidecar_sha "$TITLEBAR_SHA_FILE")" = "$EXPECTED_TITLEBAR_SHA" ] || fail "titlebar compatibility sidecar mismatch"
[ "$(sidecar_sha "$IMAGE_COMPAT_SHA_FILE")" = "$IMAGE_COMPAT_SHA" ] || fail "image compatibility sidecar mismatch"
/usr/bin/grep -Fq "compat_build_id=$EXPECTED_IMAGE_COMPAT_BUILD_ID" "$IMAGE_COMPAT_INFO_FILE" || fail "image compatibility info build ID mismatch"
/usr/bin/grep -Fq "interposer_source_git_blob=$EXPECTED_IMAGE_COMPAT_SOURCE_BLOB" "$IMAGE_COMPAT_INFO_FILE" || fail "image compatibility source blob mismatch"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || fail "core compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PASSTHROUGH' || fail "shape passthrough marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_BACKING_SYNC_COMPAT_RESULT:PASSTHROUGH' || fail "backing-sync passthrough marker missing"
/usr/bin/strings "$OBSERVER" | /usr/bin/grep -Fq "CGWINDOW_OBSERVER_BUILD_ID:$EXPECTED_OBSERVER_BUILD_ID" || fail "observer build marker missing"
/usr/bin/strings "$TITLEBAR_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:$EXPECTED_TITLEBAR_BUILD_ID" || fail "titlebar compatibility build marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:$EXPECTED_IMAGE_COMPAT_BUILD_ID" || fail "image compatibility build marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:" || fail "image compatibility call marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH" || fail "image compatibility passthrough marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS" || fail "image compatibility adapter marker missing"

EXE_ARCHS="$(macho_archs "$EXE" 2>/dev/null || true)"
CORE_ARCHS="$(macho_archs "$CORE_COMPAT" 2>/dev/null || true)"
OBSERVER_ARCHS="$(macho_archs "$OBSERVER" 2>/dev/null || true)"
TITLEBAR_ARCHS="$(macho_archs "$TITLEBAR_COMPAT" 2>/dev/null || true)"
IMAGE_COMPAT_ARCHS="$(macho_archs "$IMAGE_COMPAT" 2>/dev/null || true)"
echo "subject_archs=$EXE_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "core_compat_archs=$CORE_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_archs=$OBSERVER_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "titlebar_compat_archs=$TITLEBAR_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_compat_archs=$IMAGE_COMPAT_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
has_ppc32_arch "$EXE" || fail "historical subject is not 32-bit PPC"
has_ppc32_arch "$CORE_COMPAT" || fail "compatibility dylib is not 32-bit PPC"
has_ppc32_arch "$TITLEBAR_COMPAT" || fail "titlebar compatibility dylib is not 32-bit PPC"
has_ppc32_arch "$IMAGE_COMPAT" || fail "image compatibility dylib is not 32-bit PPC"
has_i386_arch "$OBSERVER" || fail "observer is not i386"

echo "== one exact Snow CoreUI bitmap-info passthrough compatibility control ==" | /usr/bin/tee -a "$SUBJECT_LOG"
DYLD_INSERT_LIBRARIES="$CORE_COMPAT:$TITLEBAR_COMPAT:$IMAGE_COMPAT" \
DYLD_PRINT_LIBRARIES=1 \
ROSETTA_CORESERVICES_COMPAT_MODE=passthrough \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=passthrough \
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=passthrough \
ROSETTA_CPS_SETFRONT_COMPAT_MODE=passthrough \
ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=passthrough \
ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough \
ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough \
ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHAPEWINDOW_INLINE_COMPAT_MODE=passthrough \
ROSETTA_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1 \
ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=passthrough \
ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=passthrough \
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=passthrough \
ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_MODE=snow-passthrough-v1 \
"$EXE" >> "$SUBJECT_LOG" 2>&1 &
APP_PID=$!
echo "subject_pid=$APP_PID" | /usr/bin/tee -a "$SUBJECT_LOG"

"$OBSERVER" "$APP_PID" 2800 40 "Rosetta PPC Carbon GUI" > "$OBSERVER_LOG" 2>&1 &
OBSERVER_PID=$!

wait "$APP_PID"
APP_RC=$?
wait "$OBSERVER_PID"
OBSERVER_RC=$?

echo "subject_status=$APP_RC" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_status=$OBSERVER_RC" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "== observer report ==" | /usr/bin/tee -a "$SUBJECT_LOG"
/bin/cat "$OBSERVER_LOG" | /usr/bin/tee -a "$SUBJECT_LOG"

SHAPE_CALL_COUNT="$(/usr/bin/grep -c 'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_CALL:index=1 mode=passthrough exact=YES' "$SUBJECT_LOG" 2>/dev/null || true)"
SHAPE_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PASSTHROUGH$' "$SUBJECT_LOG" 2>/dev/null || true)"
SHAPE_ADAPTER_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:ADAPTER_PASS$' "$SUBJECT_LOG" 2>/dev/null || true)"
SYNC_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=passthrough exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$SUBJECT_LOG" 2>/dev/null || true)"
SYNC_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PASSTHROUGH$' "$SUBJECT_LOG" 2>/dev/null || true)"
SYNC_ADAPTER_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$SUBJECT_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$SUBJECT_LOG" 2>/dev/null || true)"
LEGACY_TRACE_COUNT="$(/usr/bin/grep -c 'kind=CGS_SHAPEWINDOW_INLINE_LEGACY.*id=0x0000724d expectedReply=0x000072b1.*send=0x00000050 recv=0x0000002c' "$SUBJECT_LOG" 2>/dev/null || true)"
WINDOW_MARKER_COUNT="$(/usr/bin/grep -c '^Rosetta PPC Carbon GUI window shown:' "$SUBJECT_LOG" 2>/dev/null || true)"
SMOKE_MARKER_COUNT="$(/usr/bin/grep -c '^Rosetta PPC Carbon GUI smoke test:' "$SUBJECT_LOG" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_LOG" 2>/dev/null || true)"
GEOMETRY_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_LOG" 2>/dev/null || true)"
SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_LOG" 2>/dev/null | /usr/bin/tail -1)"

TITLEBAR_PASSTHROUGH_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=passthrough action=PASSTHROUGH$' "$SUBJECT_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=snow-passthrough-v1 exact=YES width=14 height=16 bpc=8 bpp=32 bpr=56 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$SUBJECT_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$SUBJECT_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$SUBJECT_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$SUBJECT_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$SUBJECT_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$SUBJECT_LOG" 2>/dev/null || true)"

echo "shape_exact_passthrough_call_count=$SHAPE_CALL_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "shape_passthrough_result_count=$SHAPE_PASS_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "shape_adapter_pass_count=$SHAPE_ADAPTER_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "backing_sync_exact_count=$SYNC_EXACT_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "backing_sync_passthrough_count=$SYNC_PASSTHROUGH_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "backing_sync_adapter_pass_count=$SYNC_ADAPTER_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "shape_legacy_trace_count=$LEGACY_TRACE_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_geometry_400x222_count=$GEOMETRY_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_summary=$SUMMARY_LINE" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "titlebar_passthrough_count=$TITLEBAR_PASSTHROUGH_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_bitmapinfo_exact_passthrough_call_count=$IMAGE_COMPAT_EXACT_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"

if [ "$APP_RC" -eq 0 ] &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$SHAPE_CALL_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_ADAPTER_COUNT" -eq 0 ] &&
   [ "$SYNC_EXACT_COUNT" -eq 0 ] &&
   [ "$SYNC_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$SYNC_ADAPTER_COUNT" -eq 0 ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$LEGACY_TRACE_COUNT" -eq 1 ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$GEOMETRY_COUNT" -ge 1 ] &&
   [ "$TITLEBAR_PASSTHROUGH_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ]; then
    echo "RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$SUBJECT_LOG"
    echo "manual_window_observation=REQUIRED" | /usr/bin/tee -a "$SUBJECT_LOG"
    echo "RESULT: PASS" | /usr/bin/tee -a "$SUBJECT_LOG"
    exit 0
fi

echo "RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_SNOW_CONTROL_FAIL" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "RESULT: FAIL" | /usr/bin/tee -a "$SUBJECT_LOG"
exit 1
