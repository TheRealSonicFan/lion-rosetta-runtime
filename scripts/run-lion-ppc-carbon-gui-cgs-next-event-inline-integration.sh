#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-carbon-gui-smoketest-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
CORE_COMPAT="${3:-$ROOT/payload/pm-carbon-gui-cgs-next-event-inline-compat.dylib}"
CORE_COMPAT_SHA_FILE="${4:-$CORE_COMPAT.sha256}"
SEC_INTERPOSER="${5:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
SEC_SHA_FILE="${6:-$SEC_INTERPOSER.sha256}"
CGS_INTERPOSER="${7:-$ROOT/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib}"
CGS_SHA_FILE="${8:-$CGS_INTERPOSER.sha256}"
BROKER="${9:-$ROOT/dn-carbon-gui-registration-broker}"
BROKER_SHA_FILE="${10:-$BROKER.sha256}"
REPORT="${11:-$ROOT/payload/lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.log}"
OBSERVER="${12:-$ROOT/payload/cgwindowlist-pid-observer}"
OBSERVER_SHA_FILE="${13:-$OBSERVER.sha256}"
OBSERVER_REPORT="${14:-$ROOT/payload/lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat-observer.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="${REPORT%.log}.raw.log"

HITOOLBOX_EXTRAS_COMPAT="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH:-$ROOT/payload/ppc-hitoolbox-extras-resource-compat.dylib}"
HITOOLBOX_EXTRAS_SHA_FILE="${ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE:-$HITOOLBOX_EXTRAS_COMPAT.sha256}"
HITOOLBOX_EXTRAS_RESOURCE="${ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH:-$ROOT/payload/SnowLeopard-HIToolbox-Extras.rsrc}"
TITLEBAR_COMPAT="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH:-$ROOT/payload/pm-titlebar-bsearch-six-key-compat.dylib}"
TITLEBAR_SHA_FILE="${ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE:-$TITLEBAR_COMPAT.sha256}"

IMAGE_COMPAT="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH:-$ROOT/payload/pm-coreui-image-bitmapinfo-compat.dylib}"
IMAGE_COMPAT_SHA_FILE="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE:-$IMAGE_COMPAT.sha256}"
IMAGE_COMPAT_INFO_FILE="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE:-$IMAGE_COMPAT.info.txt}"
EXPECTED_IMAGE_COMPAT_BUILD_ID="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID:-coreui-image-bitmapinfo-compat-v1}"
EXPECTED_IMAGE_COMPAT_SOURCE_BLOB="${ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB:-9d44128acbe49de49621104c9ffc2b0c0cd74589}"

FRAME_TRACE="${ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_PATH:-}"
FRAME_TRACE_SHA_FILE="${ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_SHA256_FILE:-${FRAME_TRACE:+$FRAME_TRACE.sha256}}"
FRAME_TRACE_INFO_FILE="${ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_INFO_FILE:-${FRAME_TRACE:+$FRAME_TRACE.info.txt}}"
EXPECTED_FRAME_TRACE_BUILD_ID="hitoolbox-windowframe-cuidraw-trace-v2"
EXPECTED_FRAME_TRACE_SOURCE_BLOB="d9419ec4ac62ba651a45eaa2bb515a8bb38c9793"

DRAG_TRACE="${ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH:-}"
DRAG_TRACE_SHA_FILE="${ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE:-${DRAG_TRACE:+$DRAG_TRACE.sha256}}"
DRAG_TRACE_INFO_FILE="${ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_INFO_FILE:-${DRAG_TRACE:+$DRAG_TRACE.info.txt}}"
EXPECTED_DRAG_TRACE_BUILD_ID="hitoolbox-titlebar-drag-trace-v2"
EXPECTED_DRAG_TRACE_SOURCE_BLOB="2c91ae875f0497b7aed96eb8b47a8ca7cbb06768"

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
EXPECTED_CORE_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-next-event-inline-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v7"
EXPECTED_SEC_SHA="9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51"
EXPECTED_CGS_SHA="f7dbcb98cbf5d64f95a33af222432d5a86ba273b475f5e3de83fff6d6c3c931b"
EXPECTED_HITOOLBOX_EXTRAS_SHA="a5b385d29bb5a6d887122ba0b2a7b1e78c45a1b69bfceb687c9cb2c77cc70572"
EXPECTED_HITOOLBOX_RESOURCE_SHA="a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197"
EXPECTED_TITLEBAR_SHA="6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72"
EXPECTED_TITLEBAR_ARTFILE_SHA="0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4"
EXPECTED_BROKER_BUILD_ID="distributed-notifications-carbon-gui-registration-broker-v1"
EXPECTED_OBSERVER_BUILD_ID="cgwindowlist-pid-observer-v1"

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
    log "RESULT: PPC_CARBON_GUI_WINDOWSERVER_OBSERVATION_PRECHECK_FAIL"
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

log "== Lion PPC Carbon GUI CGS next-event inline compatibility integration =="
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
[ -f "$CORE_COMPAT" ] || die 66 "missing CoreServices compatibility artifact: $CORE_COMPAT"
[ -f "$CORE_COMPAT_SHA_FILE" ] || die 66 "missing CoreServices compatibility SHA sidecar: $CORE_COMPAT_SHA_FILE"
CORE_COMPAT_SHA="$(sha256 "$CORE_COMPAT")"
CORE_COMPAT_DECLARED_SHA="$(sidecar_sha "$CORE_COMPAT_SHA_FILE")"
log "coreservices_compat_sha256=$CORE_COMPAT_SHA"
[ "$CORE_COMPAT_SHA" = "$CORE_COMPAT_DECLARED_SHA" ] ||
    die 68 "CoreServices compatibility sidecar mismatch"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_CORE_COMPAT_BUILD_ID" ||
    die 68 "Carbon smoke CoreServices compatibility build marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'lion-create-application-carbon-smoketest-v1' ||
    die 68 "Carbon smoke CPS registration mode marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'ppc-carbon-gui-smoketest-private-dyld' ||
    die 68 "Carbon smoke CPS registration client marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:ADAPTER_PASS' ||
    die 68 "CGSShapeWindow inline adapter marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_SHAPEWINDOW_INLINE_LION' ||
    die 68 "CGSShapeWindow inline Lion trace marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS' ||
    die 68 "backing-sync adapter marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_BACKING_SYNC_LION' ||
    die 68 "backing-sync Lion trace marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:ADAPTER_PASS' ||
    die 68 "CGS next-event inline adapter marker missing"
/usr/bin/strings "$CORE_COMPAT" | /usr/bin/grep -Fq 'CGS_NEXT_EVENT_INLINE_LION' ||
    die 68 "CGS next-event inline Lion trace marker missing"
verify_hash_pair "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$EXPECTED_SEC_SHA" "security_interposer"
verify_hash_pair "$CGS_INTERPOSER" "$CGS_SHA_FILE" "$EXPECTED_CGS_SHA" "cgs_interposer"
[ -f "$BROKER" ] || die 66 "missing Carbon GUI notification broker: $BROKER"
[ -f "$BROKER_SHA_FILE" ] || die 66 "missing Carbon GUI notification broker SHA sidecar: $BROKER_SHA_FILE"
BROKER_SHA="$(sha256 "$BROKER")"
BROKER_DECLARED_SHA="$(sidecar_sha "$BROKER_SHA_FILE")"
log "distributed_notifications_broker_sha256=$BROKER_SHA"
[ "$BROKER_SHA" = "$BROKER_DECLARED_SHA" ] ||
    die 68 "Carbon GUI notification broker sidecar mismatch"
verify_hash_pair "$HITOOLBOX_EXTRAS_COMPAT" "$HITOOLBOX_EXTRAS_SHA_FILE" "$EXPECTED_HITOOLBOX_EXTRAS_SHA" "hitoolbox_extras_compat"
verify_hash_pair "$TITLEBAR_COMPAT" "$TITLEBAR_SHA_FILE" "$EXPECTED_TITLEBAR_SHA" "titlebar_compat"
[ -f "$IMAGE_COMPAT" ] || die 66 "missing image compatibility dylib: $IMAGE_COMPAT"
[ -f "$IMAGE_COMPAT_SHA_FILE" ] || die 66 "missing image compatibility SHA sidecar: $IMAGE_COMPAT_SHA_FILE"
[ -f "$IMAGE_COMPAT_INFO_FILE" ] || die 66 "missing image compatibility info: $IMAGE_COMPAT_INFO_FILE"
IMAGE_COMPAT_SHA="$(sha256 "$IMAGE_COMPAT")"
IMAGE_COMPAT_DECLARED_SHA="$(sidecar_sha "$IMAGE_COMPAT_SHA_FILE")"
log "image_compat_sha256=$IMAGE_COMPAT_SHA"
[ "$IMAGE_COMPAT_DECLARED_SHA" = "$IMAGE_COMPAT_SHA" ] || die 68 "image compatibility sidecar hash mismatch"
/usr/bin/grep -Fq "compat_build_id=$EXPECTED_IMAGE_COMPAT_BUILD_ID" "$IMAGE_COMPAT_INFO_FILE" || die 68 "image compatibility info build ID mismatch"
/usr/bin/grep -Fq "interposer_source_git_blob=$EXPECTED_IMAGE_COMPAT_SOURCE_BLOB" "$IMAGE_COMPAT_INFO_FILE" || die 68 "image compatibility source blob mismatch"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:$EXPECTED_IMAGE_COMPAT_BUILD_ID" || die 68 "image compatibility build marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:" || die 68 "image compatibility call marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002" || die 68 "image compatibility adapted marker missing"
/usr/bin/strings "$IMAGE_COMPAT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS" || die 68 "image compatibility adapter marker missing"
has_ppc32_arch "$IMAGE_COMPAT" || die 68 "image compatibility dylib is not 32-bit PPC"

if [ -n "$FRAME_TRACE" ]; then
    [ -f "$FRAME_TRACE" ] || die 66 "missing window-frame CUIDraw trace: $FRAME_TRACE"
    [ -f "$FRAME_TRACE_SHA_FILE" ] || die 66 "missing window-frame CUIDraw trace SHA sidecar"
    [ -f "$FRAME_TRACE_INFO_FILE" ] || die 66 "missing window-frame CUIDraw trace info"
    FRAME_TRACE_SHA="$(sha256 "$FRAME_TRACE")"
    [ "$(sidecar_sha "$FRAME_TRACE_SHA_FILE")" = "$FRAME_TRACE_SHA" ] || die 68 "window-frame CUIDraw trace sidecar mismatch"
    /usr/bin/grep -Fq "trace_build_id=$EXPECTED_FRAME_TRACE_BUILD_ID" "$FRAME_TRACE_INFO_FILE" || die 68 "window-frame CUIDraw trace info build ID mismatch"
    /usr/bin/grep -Fq "interposer_source_git_blob=$EXPECTED_FRAME_TRACE_SOURCE_BLOB" "$FRAME_TRACE_INFO_FILE" || die 68 "window-frame CUIDraw trace source blob mismatch"
    /usr/bin/strings "$FRAME_TRACE" | /usr/bin/grep -Fq "PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:$EXPECTED_FRAME_TRACE_BUILD_ID" || die 68 "window-frame CUIDraw trace build marker missing"
    has_ppc32_arch "$FRAME_TRACE" || die 68 "window-frame CUIDraw trace is not 32-bit PPC"
    log "windowframe_cuidraw_trace_sha256=$FRAME_TRACE_SHA"
fi

if [ -n "$DRAG_TRACE" ]; then
    [ -f "$DRAG_TRACE" ] || die 66 "missing titlebar drag trace: $DRAG_TRACE"
    [ -f "$DRAG_TRACE_SHA_FILE" ] || die 66 "missing titlebar drag trace SHA sidecar"
    [ -f "$DRAG_TRACE_INFO_FILE" ] || die 66 "missing titlebar drag trace info"
    DRAG_TRACE_SHA="$(sha256 "$DRAG_TRACE")"
    [ "$(sidecar_sha "$DRAG_TRACE_SHA_FILE")" = "$DRAG_TRACE_SHA" ] || die 68 "titlebar drag trace sidecar mismatch"
    /usr/bin/grep -Fq "trace_build_id=$EXPECTED_DRAG_TRACE_BUILD_ID" "$DRAG_TRACE_INFO_FILE" || die 68 "titlebar drag trace info build ID mismatch"
    /usr/bin/grep -Fq "interposer_source_git_blob=$EXPECTED_DRAG_TRACE_SOURCE_BLOB" "$DRAG_TRACE_INFO_FILE" || die 68 "titlebar drag trace source blob mismatch"
    /usr/bin/strings "$DRAG_TRACE" | /usr/bin/grep -Fq "PM_HITOOLBOX_TITLEBAR_DRAG_TRACE_BUILD_ID:$EXPECTED_DRAG_TRACE_BUILD_ID" || die 68 "titlebar drag trace build marker missing"
    has_ppc32_arch "$DRAG_TRACE" || die 68 "titlebar drag trace is not 32-bit PPC"
    log "titlebar_drag_trace_sha256=$DRAG_TRACE_SHA"
fi

[ -f "$HITOOLBOX_EXTRAS_RESOURCE" ] || die 66 "missing Snow HIToolbox Extras resource"
HITOOLBOX_RESOURCE_SHA="$(sha256 "$HITOOLBOX_EXTRAS_RESOURCE")"
log "hitoolbox_extras_resource_sha256=$HITOOLBOX_RESOURCE_SHA"
[ "$HITOOLBOX_RESOURCE_SHA" = "$EXPECTED_HITOOLBOX_RESOURCE_SHA" ] ||
    die 68 "HIToolbox Extras resource hash mismatch"

[ -f "$TITLEBAR_ARTFILE" ] || die 66 "missing CoreUI ArtFile"
TITLEBAR_ARTFILE_SHA="$(sha256 "$TITLEBAR_ARTFILE")"
log "coreui_titlebar_artfile_sha256=$TITLEBAR_ARTFILE_SHA"
[ "$TITLEBAR_ARTFILE_SHA" = "$EXPECTED_TITLEBAR_ARTFILE_SHA" ] ||
    die 68 "CoreUI ArtFile hash mismatch"

for p in "$EXE" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER" "$HITOOLBOX_EXTRAS_COMPAT" "$TITLEBAR_COMPAT"; do
    has_ppc32_arch "$p" || die 67 "required artifact is not 32-bit PPC: $p"
done
BROKER_ARCH="$(/usr/bin/lipo -info "$BROKER" 2>/dev/null || true)"
echo "$BROKER_ARCH" | /usr/bin/grep -Eq '(^|[[:space:]])i386([[:space:]]|$)' ||
    die 67 "distributed-notifications broker is not i386"
/usr/bin/strings "$BROKER" | /usr/bin/grep -Fq "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:$EXPECTED_BROKER_BUILD_ID" ||
    die 68 "distributed-notifications broker build marker missing"
/usr/bin/strings "$BROKER" | /usr/bin/grep -Fq 'ppc-carbon-gui-smoketest-private-dyld' ||
    die 68 "distributed-notifications broker historical client marker missing"

[ -x "$OBSERVER" ] || die 66 "missing or non-executable WindowServer observer: $OBSERVER"
[ -f "$OBSERVER_SHA_FILE" ] || die 66 "missing WindowServer observer SHA sidecar: $OBSERVER_SHA_FILE"
OBSERVER_SHA="$(sha256 "$OBSERVER")"
OBSERVER_DECLARED_SHA="$(sidecar_sha "$OBSERVER_SHA_FILE")"
log "windowserver_observer_sha256=$OBSERVER_SHA"
[ "$OBSERVER_SHA" = "$OBSERVER_DECLARED_SHA" ] ||
    die 68 "WindowServer observer sidecar mismatch"
/usr/bin/strings "$OBSERVER" | /usr/bin/grep -Fq "CGWINDOW_OBSERVER_BUILD_ID:$EXPECTED_OBSERVER_BUILD_ID" ||
    die 68 "WindowServer observer build marker missing"
OBSERVER_ARCH="$(/usr/bin/lipo -info "$OBSERVER" 2>/dev/null || true)"
echo "$OBSERVER_ARCH" | /usr/bin/grep -Eq '(^|[[:space:]])i386([[:space:]]|$)' ||
    die 67 "WindowServer observer is not i386"

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
MARKER="$(/usr/bin/mktemp /tmp/lion-ppc-carbon-gui-windowserver-observation.XXXXXX)" ||
    die 73 "could not create diagnostic marker"

INSERT_LIBS="$CORE_COMPAT:$SEC_INTERPOSER:$CGS_INTERPOSER:$HITOOLBOX_EXTRAS_COMPAT:$TITLEBAR_COMPAT:$IMAGE_COMPAT"
if [ -n "$FRAME_TRACE" ]; then
    INSERT_LIBS="$INSERT_LIBS:$FRAME_TRACE"
fi
if [ -n "$DRAG_TRACE" ]; then
    INSERT_LIBS="$INSERT_LIBS:$DRAG_TRACE"
fi
if [ -n "$DRAG_TRACE" ]; then
    OBSERVER_DURATION_MS="${ROSETTA_HITOOLBOX_TITLEBAR_DRAG_OBSERVER_DURATION_MS:-9000}"
else
    OBSERVER_DURATION_MS="2800"
fi
case "$OBSERVER_DURATION_MS" in
    ''|*[!0-9]*) die 68 "invalid titlebar drag observer duration: $OBSERVER_DURATION_MS" ;;
esac
log ""
log "== SINGLE ORIGINAL PPC CARBON GUI BACKING-SYNC INTEGRATION RUN =="
log "subject_sha256=$EXPECTED_EXE_SHA"
log "distributed_notifications_policy=exact-21"
log "compatibility_policy=accepted-restored-stack-plus-exact-carbon-smoke-cps-registration-plus-shapewindow-inline-plus-exact-backing-sync-id-adapter"
log "notification_policy=exact-21-carbon-gui-client-v1"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 \
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-carbon-smoketest-v1 \
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
ROSETTA_CGS_SHAPEWINDOW_INLINE_COMPAT_MODE=lion-inline-id-v1 \
ROSETTA_CGS_GET_PORT_STREAM_INLINE_COMPAT_MODE=lion-inline-id-v1 \
ROSETTA_CGS_SYNCHRONIZE_WINDOW_BACKING_STORE_COMPAT_MODE=lion-id-v1 \
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
ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_MODE=lion-bitmapinfo-0x2002-v1 \
ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_MODE=lion-passive-v2 \
ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_MODE=lion-passive-v2 \
DYLD_INSERT_LIBRARIES="$INSERT_LIBS" \
DYLD_SHARED_CACHE_DONT_VALIDATE=1 \
DYLD_PRINT_LIBRARIES=1 \
"$EXE" > "$RAW_LOG" 2>&1 &
APP_PID=$!
log "subject_pid=$APP_PID"

"$OBSERVER" "$APP_PID" "$OBSERVER_DURATION_MS" 40 "Rosetta PPC Carbon GUI" > "$OBSERVER_REPORT" 2>&1 &
OBSERVER_PID=$!

wait "$APP_PID"
RC=$?
wait "$OBSERVER_PID"
OBSERVER_RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "carbon_gui_exec_status=$RC"
log "windowserver_observer_status=$OBSERVER_RC"
log ""
log "== WindowServer observer report =="
/bin/cat "$OBSERVER_REPORT" | /usr/bin/tee -a "$REPORT"

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
BROKER_FAIL_COUNT="$(/usr/bin/grep -c '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:FAIL$' "$RAW_LOG" 2>/dev/null || true)"
BROKER_REJECT_COUNT="$(/usr/bin/grep -c '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:' "$RAW_LOG" 2>/dev/null || true)"
BROKER_WAIT_EXIT0_COUNT="$(/usr/bin/grep -Ec '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:pid=[0-9]+ exit=0$' "$RAW_LOG" 2>/dev/null || true)"
REQUEST22_COUNT="$(/usr/bin/grep -Ec 'PM_DISTRIBUTED_NOTIFICATIONS_(PPC_INGRESS_MACH_REQUEST|CREATEWINDOW_REGISTER_ACCEPT):index=22([[:space:]]|$)' "$RAW_LOG" 2>/dev/null || true)"
INGRESS_EXIT_COUNT="$(/usr/bin/grep -Ec '^PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=21 callbacks=0$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=lion-create-application-carbon-smoketest-v1 exact=YES .*send=0x00000068 recv=0x0000002c .*stringLength=0x00000026$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_ADAPTED_REQUEST_COUNT="$(/usr/bin/grep -c '^PM_CPS_REGISTRATION_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x00007372 lionId=0x000073c1 legacySend=0x00000068 lionSend=0x00000074 changedCommonBytes=1 sourceChangedBytes=0 tailByte=0x00 tailU32_0=0x00000000 tailU32_1=0x00000010$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -c '^PM_CPS_REGISTRATION_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x00007425 result=0 ndrSwapped=YES raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_REPLY_COUNT="$(/usr/bin/grep -c '^PM_CPS_REGISTRATION_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x00007425 legacyId=0x000073d6 size=0x00000024 changedBytes=2 result=0$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_PREDICATE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CPS_REGISTRATION_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
REGISTERAPPLICATION_MINUS304_COUNT="$(/usr/bin/grep -c '_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304' "$RAW_LOG" 2>/dev/null || true)"

SEC_PASS_COUNT="$(/usr/bin/grep -c 'PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" 2>/dev/null || true)"
SESSION_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SERVER_VERSION_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPS_REG_PASS_COUNT="$(/usr/bin/grep -c '^PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPS_SETFRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
DOCK_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
NEWWINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_NEWWINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RELEASE_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
OPACITY_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_CALL:index=1 mode=lion-inline-id-v1 exact=YES .*id=0x0000724d send=0x00000050 recv=0x0000002c .*arg1=1 count=9$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REQUEST:index=1 legacyId=0x0000724d lionId=0x0000724e send=0x00000050 recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*count=9$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_NATIVE_REPLY:index=1 bits=0x00001200 size=0x00000024 id=0x000072b2 result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_ADAPTED_REPLY:index=1 nativeId=0x000072b2 legacyId=0x000072b1 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:ADAPTER_PASS"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "next_event_inline_exact_count=$NEXT_EVENT_EXACT_COUNT"
log "next_event_inline_adapted_request_count=$NEXT_EVENT_REQUEST_COUNT"
log "next_event_inline_native_reply_count=$NEXT_EVENT_NATIVE_REPLY_COUNT"
log "next_event_inline_native_stream_count=$NEXT_EVENT_NATIVE_STREAM_COUNT"
log "next_event_inline_adapted_reply_count=$NEXT_EVENT_REPLY_COUNT"
log "next_event_inline_adapter_pass_count=$NEXT_EVENT_PASS_COUNT"
log "next_event_inline_reject_count=$NEXT_EVENT_REJECT_COUNT"
log "next_event_inline_typecheck_diagnostic_count=$NEXT_EVENT_TYPECHECK_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$NEXT_EVENT_EXACT_COUNT" -ge 1 ] &&
   [ "$NEXT_EVENT_REQUEST_COUNT" -eq "$NEXT_EVENT_EXACT_COUNT" ] &&
   [ "$NEXT_EVENT_NATIVE_REPLY_COUNT" -eq "$NEXT_EVENT_EXACT_COUNT" ] &&
   [ "$NEXT_EVENT_NATIVE_STREAM_COUNT" -ge 1 ] &&
   [ "$NEXT_EVENT_REPLY_COUNT" -eq "$NEXT_EVENT_EXACT_COUNT" ] &&
   [ "$NEXT_EVENT_PASS_COUNT" -eq "$NEXT_EVENT_EXACT_COUNT" ] &&
   [ "$NEXT_EVENT_REJECT_COUNT" -eq 0 ] &&
   [ "$NEXT_EVENT_TYPECHECK_COUNT" -eq 0 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_CALL:index=[0-9]+ adaptedIndex=[0-9]+ mode=lion-inline-id-v1 exact=YES .*id=0x00007292 send=0x00000018 recv=0x00004030 ' "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007292 lionId=0x00007295 send=0x00000018 recv=0x00004030 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_NATIVE_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x[0-9a-fA-F]+ size=0x[0-9a-fA-F]+ id=0x000072f9 replyClass=(STREAM|SIMPLE)"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_NATIVE_STREAM_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x[0-9a-fA-F]+ size=0x[0-9a-fA-F]+ id=0x000072f9 replyClass=STREAM"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072f9 legacyId=0x000072f6 size=0x[0-9a-fA-F]+ changedBytes=1 bodyChangedBytes=0 replyClass=(STREAM|SIMPLE)"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:ADAPTER_PASS"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:(PREDICATE_REJECTED_PASSTHROUGH|ALLOC_FAILED_PASSTHROUGH|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|NATIVE_REPLY_REJECTED|REPLY_ALLOC_FAILED_NATIVE_COPIED|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)"$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
 "$RAW_LOG" 2>/dev/null || true)"
NEXT_EVENT_TYPECHECK_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSGetNextEventRecord (Inline)' "$RAW_LOG" 2>/dev/null || true)"
SYNC_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_CALL:index=[0-9]+ exactIndex=[0-9]+ mode=lion-id-v1 exact=YES .*id=0x00007265 send=0x0000002c recv=0x0000002c .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REQUEST_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REQUEST:index=[0-9]+ legacyId=0x00007265 lionId=0x00007266 send=0x0000002c recv=0x0000002c changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 .*arg1=3 arg2=1$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_SUCCESS_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_NATIVE_REPLY:index=[0-9]+ bits=0x00001200 size=0x00000024 id=0x000072ca result=0 ndrSwapped=YES replyClass=SUCCESS raw20=0x00000000$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REPLY_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_ADAPTED_REPLY:index=[0-9]+ nativeId=0x000072ca legacyId=0x000072c9 size=0x00000024 changedBytes=1 bodyChangedBytes=0 result=0 replyClass=SUCCESS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SYNC_NATIVE_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_CGS_BACKING_SYNC_COMPAT_RESULT:(NATIVE_REPLY_REJECTED|REQUEST_POSTCHECK_FAILED_PASSTHROUGH|REPLY_POSTCHECK_FAILED_NATIVE_COPIED)$' "$RAW_LOG" 2>/dev/null || true)"
LOCK_SYNC_FAIL_COUNT="$(/usr/bin/grep -c '_CGSLockWindow: Cannot synchronize window backing store' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_REJECT_COUNT="$(/usr/bin/grep -c '^PM_CGS_SHAPEWINDOW_INLINE_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
SHAPE_DIAG_COUNT="$(/usr/bin/grep -c 'MIG: server type check failure: CGSShapeWindow' "$RAW_LOG" 2>/dev/null || true)"
WBI_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
FONTSERVER_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
RENDEZVOUS_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPC_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
CPR_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ADD_TRACKING_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
SET_FRONT_WINDOW_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
ORDER_FRONT_PASS_COUNT="$(/usr/bin/grep -c '^PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"

TITLEBAR_TRANSLATED_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=(disabled-clear|disabled-minus|disabled-zoom|active-clear|active-minus|active-zoom) mode=lion-exact-six-v1 action=TRANSLATED$' "$RAW_LOG" 2>/dev/null || true)"
TITLEBAR_GUARD_REJECT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=.* mode=lion-exact-six-v1 action=GUARD_REJECT_PASSTHROUGH$|PM_COREUI_TITLEBAR_BSEARCH_GUARD_REJECT' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_EXACT_COUNT="$(/usr/bin/grep -Ec '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:index=[0-9]+ mode=lion-bitmapinfo-0x2002-v1 exact=YES width=16 height=16 bpc=8 bpp=32 bpr=64 bitmapInfo=0x00000002 caller_offset=0x000299e0$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_REJECT_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PREDICATE_REJECTED_PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASSTHROUGH_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_ADAPTED_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_PASS_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS$' "$RAW_LOG" 2>/dev/null || true)"
IMAGE_COMPAT_NULL_COUNT="$(/usr/bin/grep -c '^PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_NULL$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_BUILD_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_BUILD_ID:hitoolbox-windowframe-cuidraw-trace-v2$' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_CALL_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_HITOOLBOX_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_TARGET_SLOT_COUNT="$(/usr/bin/grep -Ec '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:.* hitoolbox=YES slot=[1-6] ' "$RAW_LOG" 2>/dev/null || true)"
FRAME_TRACE_PASS_COUNT="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' "$RAW_LOG" 2>/dev/null || true)"

OBSERVER_BUILD_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_BUILD_ID:cgwindowlist-pid-observer-v1$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_MAIN_DISPLAY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_MAIN_DISPLAY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_PASS_COUNT="$(/usr/bin/grep -c '^CGWINDOW_OBSERVER_RESULT:PASS$' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_GEOMETRY_400X222_COUNT="$(/usr/bin/grep -c 'x=120 y=98 width=400 height=222.*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_ONSCREEN_400X222_COUNT="$(/usr/bin/grep -c 'onscreen=YES .*x=120 y=98 width=400 height=222 .*name=Rosetta PPC Carbon GUI' "$OBSERVER_REPORT" 2>/dev/null || true)"
OBSERVER_SUMMARY_LINE="$(/usr/bin/grep '^CGWINDOW_OBSERVER_SUMMARY:' "$OBSERVER_REPORT" 2>/dev/null | /usr/bin/tail -1)"

log "window_marker_count=$WINDOW_MARKER_COUNT"
log "smoke_marker_count=$SMOKE_MARKER_COUNT"
log "notification_register_accept_count=$REGISTER_ACCEPT_COUNT"
log "notification_broker_summary_count=$BROKER_SUMMARY_COUNT"
log "notification_broker_pass_count=$BROKER_PASS_COUNT"
log "notification_broker_fail_count=$BROKER_FAIL_COUNT"
log "notification_broker_reject_count=$BROKER_REJECT_COUNT"
log "notification_broker_wait_exit0_count=$BROKER_WAIT_EXIT0_COUNT"
log "notification_request22_count=$REQUEST22_COUNT"
log "notification_ingress_exit_count=$INGRESS_EXIT_COUNT"
log "cps_registration_exact_predicate_count=$CPS_REG_EXACT_COUNT"
log "cps_registration_adapted_request_count=$CPS_REG_ADAPTED_REQUEST_COUNT"
log "cps_registration_native_success_count=$CPS_REG_NATIVE_SUCCESS_COUNT"
log "cps_registration_adapted_reply_count=$CPS_REG_REPLY_COUNT"
log "cps_registration_predicate_reject_count=$CPS_REG_PREDICATE_REJECT_COUNT"
log "registerapplication_err_minus304_count=$REGISTERAPPLICATION_MINUS304_COUNT"
log "security_adapter_pass_count=$SEC_PASS_COUNT"
log "session_bootstrap_adapter_pass_count=$SESSION_PASS_COUNT"
log "server_version_adapter_pass_count=$SERVER_VERSION_PASS_COUNT"
log "cps_registration_adapter_pass_count=$CPS_REG_PASS_COUNT"
log "cps_setfront_adapter_pass_count=$CPS_SETFRONT_PASS_COUNT"
log "dockserver_adapter_pass_count=$DOCK_PASS_COUNT"
log "newwindow_adapter_pass_count=$NEWWINDOW_PASS_COUNT"
log "releasebacking_adapter_pass_count=$RELEASE_PASS_COUNT"
log "opacity_alpha_adapter_pass_count=$OPACITY_PASS_COUNT"
log "shapewindow_inline_exact_count=$SHAPE_EXACT_COUNT"
log "shapewindow_inline_adapted_request_count=$SHAPE_REQUEST_COUNT"
log "shapewindow_inline_native_success_count=$SHAPE_NATIVE_SUCCESS_COUNT"
log "shapewindow_inline_adapted_reply_count=$SHAPE_REPLY_COUNT"
log "shapewindow_inline_adapter_pass_count=$SHAPE_PASS_COUNT"
log "backing_sync_exact_count=$SYNC_EXACT_COUNT"
log "backing_sync_adapted_request_count=$SYNC_REQUEST_COUNT"
log "backing_sync_native_success_count=$SYNC_NATIVE_SUCCESS_COUNT"
log "backing_sync_adapted_reply_count=$SYNC_REPLY_COUNT"
log "backing_sync_adapter_pass_count=$SYNC_PASS_COUNT"
log "backing_sync_predicate_reject_count=$SYNC_REJECT_COUNT"
log "backing_sync_native_reject_count=$SYNC_NATIVE_REJECT_COUNT"
log "backing_sync_lock_failure_count=$LOCK_SYNC_FAIL_COUNT"
log "shapewindow_inline_predicate_reject_count=$SHAPE_REJECT_COUNT"
log "shapewindow_typecheck_diagnostic_count=$SHAPE_DIAG_COUNT"
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
log "image_bitmapinfo_exact_call_count=$IMAGE_COMPAT_EXACT_COUNT"
log "image_bitmapinfo_predicate_reject_count=$IMAGE_COMPAT_REJECT_COUNT"
log "image_bitmapinfo_passthrough_result_count=$IMAGE_COMPAT_PASSTHROUGH_COUNT"
log "image_bitmapinfo_adapted_count=$IMAGE_COMPAT_ADAPTED_COUNT"
log "image_bitmapinfo_adapter_pass_count=$IMAGE_COMPAT_PASS_COUNT"
log "image_bitmapinfo_adapter_null_count=$IMAGE_COMPAT_NULL_COUNT"
log "windowframe_cuidraw_trace_build_count=$FRAME_TRACE_BUILD_COUNT"
log "windowframe_cuidraw_trace_call_count=$FRAME_TRACE_CALL_COUNT"
log "windowframe_cuidraw_trace_hitoolbox_count=$FRAME_TRACE_HITOOLBOX_COUNT"
log "windowframe_cuidraw_trace_target_slot_count=$FRAME_TRACE_TARGET_SLOT_COUNT"
log "windowframe_cuidraw_trace_passthrough_count=$FRAME_TRACE_PASS_COUNT"
log "windowserver_observer_build_count=$OBSERVER_BUILD_COUNT"
log "windowserver_observer_main_display_count=$OBSERVER_MAIN_DISPLAY_COUNT"
log "windowserver_observer_summary_count=$OBSERVER_SUMMARY_COUNT"
log "windowserver_observer_pass_count=$OBSERVER_PASS_COUNT"
log "windowserver_observer_geometry_400x222_count=$OBSERVER_GEOMETRY_400X222_COUNT"
log "windowserver_observer_onscreen_400x222_count=$OBSERVER_ONSCREEN_400X222_COUNT"
log "windowserver_observer_summary=$OBSERVER_SUMMARY_LINE"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$WINDOW_MARKER_COUNT" -eq 1 ] &&
   [ "$SMOKE_MARKER_COUNT" -eq 1 ] &&
   [ "$REGISTER_ACCEPT_COUNT" -eq 21 ] &&
   [ "$BROKER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$BROKER_PASS_COUNT" -eq 1 ] &&
   [ "$BROKER_FAIL_COUNT" -eq 0 ] &&
   [ "$BROKER_REJECT_COUNT" -eq 0 ] &&
   [ "$BROKER_WAIT_EXIT0_COUNT" -eq 1 ] &&
   [ "$REQUEST22_COUNT" -eq 0 ] &&
   [ "$INGRESS_EXIT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_EXACT_COUNT" -eq 1 ] &&
   [ "$CPS_REG_ADAPTED_REQUEST_COUNT" -eq 1 ] &&
   [ "$CPS_REG_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_REPLY_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PREDICATE_REJECT_COUNT" -eq 0 ] &&
   [ "$REGISTERAPPLICATION_MINUS304_COUNT" -eq 0 ] &&
   [ "$SEC_PASS_COUNT" -eq 1 ] &&
   [ "$SESSION_PASS_COUNT" -eq 1 ] &&
   [ "$SERVER_VERSION_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_REG_PASS_COUNT" -eq 1 ] &&
   [ "$CPS_SETFRONT_PASS_COUNT" -eq 1 ] &&
   [ "$DOCK_PASS_COUNT" -eq 1 ] &&
   [ "$NEWWINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$RELEASE_PASS_COUNT" -eq 1 ] &&
   [ "$OPACITY_PASS_COUNT" -eq 1 ] &&
   [ "$SHAPE_EXACT_COUNT" -eq 1 ] &&
   [ "$SHAPE_REQUEST_COUNT" -eq 1 ] &&
   [ "$SHAPE_NATIVE_SUCCESS_COUNT" -eq 1 ] &&
   [ "$SHAPE_REPLY_COUNT" -eq 1 ] &&
   [ "$SHAPE_PASS_COUNT" -eq 1 ] &&
   [ "$SYNC_EXACT_COUNT" -ge 1 ] &&
   [ "$SYNC_REQUEST_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_NATIVE_SUCCESS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REPLY_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_PASS_COUNT" -eq "$SYNC_EXACT_COUNT" ] &&
   [ "$SYNC_REJECT_COUNT" -eq 0 ] &&
   [ "$SYNC_NATIVE_REJECT_COUNT" -eq 0 ] &&
   [ "$LOCK_SYNC_FAIL_COUNT" -eq 0 ] &&
   [ "$SHAPE_REJECT_COUNT" -eq 0 ] &&
   [ "$SHAPE_DIAG_COUNT" -eq 0 ] &&
   [ "$WBI_PASS_COUNT" -eq 1 ] &&
   [ "$FONTSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$RENDEZVOUS_PASS_COUNT" -eq 1 ] &&
   [ "$CPC_PASS_COUNT" -eq 1 ] &&
   [ "$CPR_PASS_COUNT" -eq 1 ] &&
   [ "$ADD_TRACKING_PASS_COUNT" -eq 1 ] &&
   [ "$SET_FRONT_WINDOW_PASS_COUNT" -eq 1 ] &&
   [ "$ORDER_FRONT_PASS_COUNT" -eq 2 ] &&
   [ "$TITLEBAR_TRANSLATED_COUNT" -eq 6 ] &&
   [ "$TITLEBAR_GUARD_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_EXACT_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_ADAPTED_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_PASS_COUNT" -eq 6 ] &&
   [ "$IMAGE_COMPAT_REJECT_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_PASSTHROUGH_COUNT" -eq 0 ] &&
   [ "$IMAGE_COMPAT_NULL_COUNT" -eq 0 ] &&
   { [ -z "$FRAME_TRACE" ] || { [ "$FRAME_TRACE_BUILD_COUNT" -eq 1 ] && [ "$FRAME_TRACE_PASS_COUNT" -eq "$FRAME_TRACE_CALL_COUNT" ]; }; } &&
   [ "$OBSERVER_RC" -eq 0 ] &&
   [ "$OBSERVER_BUILD_COUNT" -eq 1 ] &&
   [ "$OBSERVER_MAIN_DISPLAY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_SUMMARY_COUNT" -eq 1 ] &&
   [ "$OBSERVER_PASS_COUNT" -eq 1 ] &&
   [ "$OBSERVER_GEOMETRY_400X222_COUNT" -ge 1 ] &&
   [ "$OBSERVER_ONSCREEN_400X222_COUNT" -ge 1 ]; then
    log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS"
    log "visual_window_observation=MANUAL_REQUIRED"
    log "visual_titlebar_observation=MANUAL_REQUIRED"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_INCOMPLETE"
log "RESULT: FAIL"
exit 1
