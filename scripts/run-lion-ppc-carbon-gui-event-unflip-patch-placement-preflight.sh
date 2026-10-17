#!/bin/bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="${1:-$ROOT/ppc-carbon-gui-event-unflip-patch-placement-preflight-private-dyld}"
PROBE_SHA="${2:-$PROBE.sha256}"
MARKER="${3:-$ROOT/ppc-carbon-gui-event-unflip-placement-marker.dylib}"
MARKER_SHA="${4:-$MARKER.sha256}"
REPORT="${5:-$ROOT/ppc-carbon-gui-event-unflip-patch-placement-preflight-lion.txt}"
RAW="$REPORT.raw.log"
CORE_COMPAT="$ROOT/payload/pm-selectwindow-orderfront-compat.dylib"
SEC_INTERPOSER="$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib"
CGS_INTERPOSER="$ROOT/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib"
KERNEL="/mach_kernel"
TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
: > "$REPORT" || exit 73
: > "$RAW" || exit 73
log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail() { log "ERROR: $*"; log "RESULT: PATCH_PLACEMENT_PREFLIGHT_LION_FAIL"; log "RESULT: FAIL"; exit 1; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
sidecar_sha() { /usr/bin/awk 'NR==1 {print $1}' "$1"; }
PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
log "== Lion translated-PPC event-unflip patch placement preflight =="
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || fail "requires Lion 10.7.5"
[ "$BUILD_VERSION" = "11G63" ] || fail "requires Lion build 11G63"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from logged-in Aqua console user"
for p in "$PROBE" "$PROBE_SHA" "$MARKER" "$MARKER_SHA" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER" "$KERNEL" "$TRANSLATOR" "$PRIVATE_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS"; do [ -f "$p" ] || fail "missing required file: $p"; done
PROBE_EXPECTED="$(sidecar_sha "$PROBE_SHA")"; PROBE_ACTUAL="$(sha256 "$PROBE")"
MARKER_EXPECTED="$(sidecar_sha "$MARKER_SHA")"; MARKER_ACTUAL="$(sha256 "$MARKER")"
[ "$PROBE_EXPECTED" = "$PROBE_ACTUAL" ] || fail "probe hash mismatch"
[ "$MARKER_EXPECTED" = "$MARKER_ACTUAL" ] || fail "marker hash mismatch"
KERNEL_BEFORE="$(sha256 "$KERNEL")"; TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"; DYLD_BEFORE="$(sha256 "$PRIVATE_DYLD")"; CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"; CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"; CORE_BEFORE="$(sha256 "$COREGRAPHICS")"
INSERT_LIBS="$CORE_COMPAT:$SEC_INTERPOSER:$CGS_INTERPOSER:$MARKER"
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 DYLD_INSERT_LIBRARIES="$INSERT_LIBS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PROBE" > "$RAW" 2>&1
RC=$?
/bin/cat "$RAW" | /usr/bin/tee -a "$REPORT"
log "probe_exit_status=$RC"
KERNEL_AFTER="$(sha256 "$KERNEL")"; TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"; DYLD_AFTER="$(sha256 "$PRIVATE_DYLD")"; CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"; CACHE_MAP_AFTER="$(sha256 "$ROSETTA_CACHE_MAP")"; CORE_AFTER="$(sha256 "$COREGRAPHICS")"
UNCHANGED=YES
[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || UNCHANGED=NO
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || UNCHANGED=NO
[ "$DYLD_AFTER" = "$DYLD_BEFORE" ] || UNCHANGED=NO
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || UNCHANGED=NO
[ "$CACHE_MAP_AFTER" = "$CACHE_MAP_BEFORE" ] || UNCHANGED=NO
[ "$CORE_AFTER" = "$CORE_BEFORE" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"
require_one() { /usr/bin/grep -Fxc "$1" "$RAW" >/dev/null 2>&1 || fail "missing probe marker: $1"; }
require_one "preflight_contract=carbon-gui-event-unflip-patch-placement-preflight-v1"
require_one "preflight_mode=lion-ppc-translated"
require_one "bounds_call_runtime_word_match=YES"
require_one "decoded_bounds_target_match=YES"
require_one "coregraphics_text_write_attempts=0"
require_one "vm_protect_attempts=0"
require_one "vm_allocate_attempts=0"
require_one "loaded_callsite_bytes_unchanged=YES"
require_one "preflight_complete=YES"
require_one "RESULT: PASS"
[ "$RC" -eq 0 ] || fail "probe returned nonzero"
[ "$UNCHANGED" = "YES" ] || fail "protected hash changed"
ROUTE="$(/usr/bin/awk -F= '/^placement_route=/{print $2; exit}' "$RAW")"
MAX_WRITE="$(/usr/bin/awk -F= '/^callsite_region_max_write=/{print $2; exit}' "$RAW")"
log "observed_placement_route=$ROUTE"
log "observed_callsite_region_max_write=$MAX_WRITE"
log "RESULT: PATCH_PLACEMENT_PREFLIGHT_LION_PASS"
log "RESULT: PASS"
exit 0
