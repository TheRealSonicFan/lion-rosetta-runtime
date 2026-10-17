#!/bin/bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="${1:-$ROOT/ppc-carbon-gui-event-unflip-patch-placement-preflight-private-dyld}"
PROBE_SHA="${2:-$PROBE.sha256}"
MARKER="${3:-$ROOT/ppc-carbon-gui-event-unflip-placement-marker.dylib}"
MARKER_SHA="${4:-$MARKER.sha256}"
REPORT="${5:-$ROOT/ppc-carbon-gui-event-unflip-patch-placement-preflight-snow.txt}"
RAW="$REPORT.raw.log"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
EXPECTED_SLICE_SHA="83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a"
: > "$REPORT" || exit 73
: > "$RAW" || exit 73
log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail() { log "ERROR: $*"; log "RESULT: PATCH_PLACEMENT_PREFLIGHT_SNOW_FAIL"; log "RESULT: FAIL"; exit 1; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
sidecar_sha() { /usr/bin/awk 'NR==1 {print $1}' "$1"; }
is_ppc32() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    desc="${desc#*: }"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}
PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "== Snow event-unflip patch placement preflight =="
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"
for p in "$PROBE" "$PROBE_SHA" "$MARKER" "$MARKER_SHA" "$COREGRAPHICS"; do [ -f "$p" ] || fail "missing required file: $p"; done
is_ppc32 "$PROBE" || fail "probe is not 32-bit PPC"
is_ppc32 "$MARKER" || fail "marker is not 32-bit PPC"
OT="$(/usr/bin/otool -l "$PROBE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "probe LC_LOAD_DYLINKER is not /usr/oah/dyld"
PROBE_EXPECTED="$(sidecar_sha "$PROBE_SHA")"; PROBE_ACTUAL="$(sha256 "$PROBE")"
MARKER_EXPECTED="$(sidecar_sha "$MARKER_SHA")"; MARKER_ACTUAL="$(sha256 "$MARKER")"
[ "$PROBE_EXPECTED" = "$PROBE_ACTUAL" ] || fail "probe hash mismatch"
[ "$MARKER_EXPECTED" = "$MARKER_ACTUAL" ] || fail "marker hash mismatch"
TMP_SLICE="$(/usr/bin/mktemp /tmp/event-unflip-placement-coregraphics.XXXXXX)" || fail "mktemp failed"
trap '/bin/rm -f "$TMP_SLICE"' EXIT HUP INT TERM
/usr/bin/lipo "$COREGRAPHICS" -thin ppc -output "$TMP_SLICE" >/dev/null 2>&1 || fail "could not thin CoreGraphics PPC slice"
SLICE_SHA="$(sha256 "$TMP_SLICE")"
log "coregraphics_ppc_slice_sha256=$SLICE_SHA"
[ "$SLICE_SHA" = "$EXPECTED_SLICE_SHA" ] || fail "CoreGraphics PPC slice mismatch"
CORE_BEFORE="$(sha256 "$COREGRAPHICS")"
DYLD_INSERT_LIBRARIES="$MARKER" "$PROBE" > "$RAW" 2>&1
RC=$?
/bin/cat "$RAW" | /usr/bin/tee -a "$REPORT"
log "probe_exit_status=$RC"
CORE_AFTER="$(sha256 "$COREGRAPHICS")"
UNCHANGED=YES; [ "$CORE_AFTER" = "$CORE_BEFORE" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"
require_one() { /usr/bin/grep -Fxc "$1" "$RAW" >/dev/null 2>&1 || fail "missing probe marker: $1"; }
require_one "preflight_contract=carbon-gui-event-unflip-patch-placement-preflight-v1"
require_one "preflight_mode=snow-ppc-control"
require_one "bounds_call_runtime_word_match=YES"
require_one "decoded_bounds_target_match=YES"
require_one "coregraphics_text_write_attempts=0"
require_one "vm_protect_attempts=0"
require_one "vm_allocate_attempts=0"
require_one "preflight_complete=YES"
require_one "RESULT: PASS"
[ "$RC" -eq 0 ] || fail "probe returned nonzero"
[ "$UNCHANGED" = "YES" ] || fail "protected hash changed"
log "RESULT: PATCH_PLACEMENT_PREFLIGHT_SNOW_PASS"
log "RESULT: PASS"
exit 0
