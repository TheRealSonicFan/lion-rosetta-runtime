#!/bin/bash
set -u

EXE="${1:-./ppc-carbon-gui-smoketest-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_COMPAT="${3:-./pm-carbon-gui-backing-sync-compat.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
OBSERVER="${5:-./cgwindowlist-pid-observer}"
OBSERVER_SHA_FILE="${6:-$OBSERVER.sha256}"
SUBJECT_LOG="${7:-./ppc-carbon-gui-artfile-bsearch-allkeys-trace-snow.log}"
OBSERVER_LOG="${8:-./ppc-carbon-gui-artfile-bsearch-allkeys-trace-snow-observer.log}"

PRIVATE_DYLD="/usr/oah/dyld"
EXPECTED_EXE_SHA="fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v6"
EXPECTED_OBSERVER_BUILD_ID="cgwindowlist-pid-observer-v1"

ARTFILE_TRACE="${ROSETTA_COREUI_ARTFILE_BSEARCH_TRACE_PATH:-./pm-artfile-bsearch-exact-six-allkeys-trace.dylib}"
ARTFILE_TRACE_SHA_FILE="${ROSETTA_COREUI_ARTFILE_BSEARCH_TRACE_SHA256_FILE:-$ARTFILE_TRACE.sha256}"
EXPECTED_ARTFILE_TRACE_BUILD_ID="coreui-artfile-bsearch-exact-six-allkeys-trace-v1"

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

echo "== Snow Leopard PPC Carbon GUI all-ArtFile bsearch passive-trace control ==" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "product_version=$PRODUCT_VERSION" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "build_version=$BUILD_VERSION" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "current_user=$CURRENT_USER" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "console_user=$CONSOLE_USER" | /usr/bin/tee -a "$SUBJECT_LOG"

[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from logged-in Aqua console user's Terminal"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

for file in "$EXE" "$EXE_SHA_FILE" "$CORE_COMPAT" "$CORE_COMPAT_SHA_FILE" "$ARTFILE_TRACE" "$ARTFILE_TRACE_SHA_FILE" "$OBSERVER" "$OBSERVER_SHA_FILE" "$PRIVATE_DYLD"; do
    [ -e "$file" ] || fail "missing $file"
done
[ -x "$EXE" ] || fail "historical subject is not executable"
[ -x "$OBSERVER" ] || fail "observer is not executable"

EXE_SHA="$(sha256 "$EXE")"
CORE_SHA="$(sha256 "$CORE_COMPAT")"
OBSERVER_SHA="$(sha256 "$OBSERVER")"
ARTFILE_TRACE_SHA="$(sha256 "$ARTFILE_TRACE")"
DYLD_SHA="$(sha256 "$PRIVATE_DYLD")"

echo "subject_sha256=$EXE_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "core_compat_sha256=$CORE_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_sha256=$OBSERVER_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_sha256=$ARTFILE_TRACE_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "private_dyld_sha256=$DYLD_SHA" | /usr/bin/tee -a "$SUBJECT_LOG"

[ "$EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "historical subject hash mismatch"
[ "$(sidecar_sha "$EXE_SHA_FILE")" = "$EXPECTED_EXE_SHA" ] || fail "subject sidecar mismatch"
[ "$(sidecar_sha "$CORE_COMPAT_SHA_FILE")" = "$CORE_SHA" ] || fail "core compatibility sidecar mismatch"
[ "$(sidecar_sha "$OBSERVER_SHA_FILE")" = "$OBSERVER_SHA" ] || fail "observer sidecar mismatch"
[ "$(sidecar_sha "$ARTFILE_TRACE_SHA_FILE")" = "$ARTFILE_TRACE_SHA" ] || fail "all-ArtFile trace sidecar mismatch"
[ "$DYLD_SHA" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"

/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || fail "core compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PASSTHROUGH' || fail "shape passthrough marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_BACKING_SYNC_COMPAT_RESULT:PASSTHROUGH' || fail "backing-sync passthrough marker missing"
/usr/bin/strings "$OBSERVER" | /usr/bin/grep -Fq "CGWINDOW_OBSERVER_BUILD_ID:$EXPECTED_OBSERVER_BUILD_ID" || fail "observer build marker missing"
/usr/bin/strings "$ARTFILE_TRACE" | /usr/bin/grep -Fq "PM_COREUI_ARTFILE_BSEARCH_BUILD_ID:$EXPECTED_ARTFILE_TRACE_BUILD_ID" || fail "all-ArtFile trace build marker missing"
/usr/bin/strings "$ARTFILE_TRACE" | /usr/bin/grep -Fq "PM_COREUI_ARTFILE_BSEARCH_TRACE:" || fail "all-ArtFile trace marker missing"

EXE_ARCHS="$(macho_archs "$EXE" 2>/dev/null || true)"
CORE_ARCHS="$(macho_archs "$CORE_COMPAT" 2>/dev/null || true)"
OBSERVER_ARCHS="$(macho_archs "$OBSERVER" 2>/dev/null || true)"
ARTFILE_TRACE_ARCHS="$(macho_archs "$ARTFILE_TRACE" 2>/dev/null || true)"
echo "subject_archs=$EXE_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "core_compat_archs=$CORE_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "observer_archs=$OBSERVER_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_archs=$ARTFILE_TRACE_ARCHS" | /usr/bin/tee -a "$SUBJECT_LOG"
has_ppc32_arch "$EXE" || fail "historical subject is not 32-bit PPC"
has_ppc32_arch "$CORE_COMPAT" || fail "compatibility dylib is not 32-bit PPC"
has_ppc32_arch "$ARTFILE_TRACE" || fail "all-ArtFile trace dylib is not 32-bit PPC"
has_i386_arch "$OBSERVER" || fail "observer is not i386"

echo "== one exact Snow passive all-ArtFile-key trace control ==" | /usr/bin/tee -a "$SUBJECT_LOG"
DYLD_INSERT_LIBRARIES="$CORE_COMPAT:$ARTFILE_TRACE" \
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
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=snow-passive-allkeys-v1 \
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

ARTFILE_TRACE_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_ARTFILE_BSEARCH_TRACE:unique_index=[0-9]+ mode=snow-passive-allkeys-v1 raw_key=[0-9a-f]{16} .*known_exact_six=(YES|NO) action=PASSTHROUGH .*result=(HIT|MISS) result_index=' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_TRACE_OUTSIDE_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_ARTFILE_BSEARCH_TRACE:.* mode=snow-passive-allkeys-v1 .*known_exact_six=NO action=PASSTHROUGH ' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_TRACE_MISS_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_ARTFILE_BSEARCH_TRACE:.* mode=snow-passive-allkeys-v1 .* result=MISS result_index=NONE$' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_TRACE_LIMIT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_ARTFILE_BSEARCH_TRACE_LIMIT:unique_limit=256$' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_DISABLED_CLEAR_COUNT="$(/usr/bin/grep -Ec 'raw_key=a613161f7a000000 .*known_exact_six=YES action=PASSTHROUGH .*result=HIT ' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_DISABLED_MINUS_COUNT="$(/usr/bin/grep -Ec 'raw_key=a6161f567a000000 .*known_exact_six=YES action=PASSTHROUGH .*result=HIT ' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_DISABLED_ZOOM_COUNT="$(/usr/bin/grep -Ec 'raw_key=a6161f7ab6000000 .*known_exact_six=YES action=PASSTHROUGH .*result=HIT ' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_ACTIVE_CLEAR_COUNT="$(/usr/bin/grep -Ec 'raw_key=a60113167a000000 .*known_exact_six=YES action=PASSTHROUGH .*result=HIT ' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_ACTIVE_MINUS_COUNT="$(/usr/bin/grep -Ec 'raw_key=a60116567a000000 .*known_exact_six=YES action=PASSTHROUGH .*result=HIT ' "$SUBJECT_LOG" 2>/dev/null || true)"
ARTFILE_ACTIVE_ZOOM_COUNT="$(/usr/bin/grep -Ec 'raw_key=a601167ab6000000 .*known_exact_six=YES action=PASSTHROUGH .*result=HIT ' "$SUBJECT_LOG" 2>/dev/null || true)"

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
echo "artfile_trace_unique_count=$ARTFILE_TRACE_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_outside_six_unique_count=$ARTFILE_TRACE_OUTSIDE_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_miss_unique_count=$ARTFILE_TRACE_MISS_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_limit_count=$ARTFILE_TRACE_LIMIT_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_disabled_clear_count=$ARTFILE_DISABLED_CLEAR_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_disabled_minus_count=$ARTFILE_DISABLED_MINUS_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_disabled_zoom_count=$ARTFILE_DISABLED_ZOOM_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_active_clear_count=$ARTFILE_ACTIVE_CLEAR_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_active_minus_count=$ARTFILE_ACTIVE_MINUS_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "artfile_trace_active_zoom_count=$ARTFILE_ACTIVE_ZOOM_COUNT" | /usr/bin/tee -a "$SUBJECT_LOG"

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
   [ "$ARTFILE_TRACE_COUNT" -ge 6 ] &&
   [ "$ARTFILE_TRACE_LIMIT_COUNT" -eq 0 ] &&
   [ "$ARTFILE_DISABLED_CLEAR_COUNT" -ge 1 ] &&
   [ "$ARTFILE_DISABLED_MINUS_COUNT" -ge 1 ] &&
   [ "$ARTFILE_DISABLED_ZOOM_COUNT" -ge 1 ] &&
   [ "$ARTFILE_ACTIVE_CLEAR_COUNT" -ge 1 ] &&
   [ "$ARTFILE_ACTIVE_MINUS_COUNT" -ge 1 ] &&
   [ "$ARTFILE_ACTIVE_ZOOM_COUNT" -ge 1 ]; then
    echo "RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_SNOW_CONTROL_PASS" | /usr/bin/tee -a "$SUBJECT_LOG"
    echo "manual_window_observation=REQUIRED" | /usr/bin/tee -a "$SUBJECT_LOG"
    echo "RESULT: PASS" | /usr/bin/tee -a "$SUBJECT_LOG"
    exit 0
fi

echo "RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_SNOW_CONTROL_FAIL" | /usr/bin/tee -a "$SUBJECT_LOG"
echo "RESULT: FAIL" | /usr/bin/tee -a "$SUBJECT_LOG"
exit 1
