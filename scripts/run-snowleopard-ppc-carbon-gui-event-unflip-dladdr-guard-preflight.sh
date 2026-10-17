#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INTERPOSER="${1:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib}"
INTERPOSER_SHA="${2:-$INTERPOSER.sha256}"
PROBE="${3:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld}"
PROBE_SHA="${4:-$PROBE.sha256}"
REPORT="${5:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-preflight-snow.txt}"
RAW="$REPORT.raw.log"

COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
EXPECTED_SLICE_SHA="83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a"

: > "$REPORT" || exit 73
: > "$RAW" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail() { log "ERROR: $*"; log "RESULT: DLADDR_GUARD_PREFLIGHT_SNOW_FAIL"; log "RESULT: FAIL"; exit 1; }
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
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc([0-9]+)?|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "== Snow event-unflip dladdr guard preflight =="
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"

for p in "$INTERPOSER" "$INTERPOSER_SHA" "$PROBE" "$PROBE_SHA" "$COREGRAPHICS"; do
    [ -f "$p" ] || fail "missing required file: $p"
done
is_ppc32 "$INTERPOSER" || fail "interposer is not 32-bit PPC"
is_ppc32 "$PROBE" || fail "probe is not 32-bit PPC"

INTERPOSER_ACTUAL="$(sha256 "$INTERPOSER")"
INTERPOSER_DECLARED="$(sidecar_sha "$INTERPOSER_SHA")"
PROBE_ACTUAL="$(sha256 "$PROBE")"
PROBE_DECLARED="$(sidecar_sha "$PROBE_SHA")"
log "dladdr_guard_interposer.sha256=$INTERPOSER_ACTUAL"
log "dladdr_guard_probe.sha256=$PROBE_ACTUAL"
[ "$INTERPOSER_ACTUAL" = "$INTERPOSER_DECLARED" ] || fail "interposer hash mismatch"
[ "$PROBE_ACTUAL" = "$PROBE_DECLARED" ] || fail "probe hash mismatch"

/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     'PM_EVENT_UNFLIP_DLADDR_GUARD_BUILD_ID:event-unflip-dladdr-guard-v1' || fail "interposer build marker missing"
/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq     'carbon-gui-event-unflip-dladdr-guard-preflight-v1' || fail "probe contract marker missing"

TMP_SLICE="$(/usr/bin/mktemp /tmp/event-unflip-dladdr-guard-coregraphics.XXXXXX)" || fail "mktemp failed"
trap '/bin/rm -f "$TMP_SLICE"' EXIT HUP INT TERM
/bin/rm -f "$TMP_SLICE"
if ! /usr/bin/lipo "$COREGRAPHICS" -thin ppc7400 -output "$TMP_SLICE" >/dev/null 2>&1; then
    /bin/rm -f "$TMP_SLICE"
    /usr/bin/lipo -thin ppc7400 "$COREGRAPHICS" -output "$TMP_SLICE" >/dev/null 2>&1 || fail "cannot extract ppc7400 slice"
fi
[ "$(sha256 "$TMP_SLICE")" = "$EXPECTED_SLICE_SHA" ] || fail "CoreGraphics PPC slice mismatch"

CORE_BEFORE="$(sha256 "$COREGRAPHICS")"
ROSETTA_EVENT_UNFLIP_DLADDR_GUARD_MODE=passthrough DYLD_INSERT_LIBRARIES="$INTERPOSER" "$PROBE" > "$RAW" 2>&1
RC=$?
/bin/cat "$RAW" | /usr/bin/tee -a "$REPORT"
log "probe_exit_status=$RC"
CORE_AFTER="$(sha256 "$COREGRAPHICS")"
UNCHANGED=YES
[ "$CORE_AFTER" = "$CORE_BEFORE" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"

require_one() {
    /usr/bin/grep -Fxc "$1" "$RAW" >/dev/null 2>&1 || fail "missing probe marker: $1"
}

require_one "probe_contract=carbon-gui-event-unflip-dladdr-guard-preflight-v1"
require_one "preflight_mode=snow-ppc-control"
require_one "guard_mode=passthrough"
require_one "target_return_resolved=YES"
require_one "guard_exact_match=YES"
require_one "guard_minus4_reject=YES"
require_one "guard_plus4_reject=YES"
require_one "original_replacee_available=YES"
require_one "selected_dladdr_stub_runtime_shape_match=YES"
require_one "selected_stub_passthrough_result_match=YES"
require_one "selected_stub_passthrough_info_match=YES"
require_one "selected_stub_interposer_forward_delta=1"
require_one "interposer_target_wrapper_count=0"
require_one "selected_dladdr_stub_direct_probe_calls=1"
require_one "patched_target_wrapper_executed=NO"
require_one "coregraphics_text_write_attempts=0"
require_one "vm_protect_attempts=0"
require_one "vm_allocate_attempts=0"
require_one "candidate_instruction_execution_attempts=0"
require_one "functional_source_helper_load_attempts=0"
require_one "original_gui_launch_count=0"
require_one "preflight_complete=YES"
require_one "RESULT: PASS"

/usr/bin/grep -Fq 'PM_EVENT_UNFLIP_DLADDR_GUARD_BUILD_ID:event-unflip-dladdr-guard-v1' "$RAW" || fail "interposer did not execute"
[ "$RC" -eq 0 ] || fail "probe returned nonzero"
[ "$UNCHANGED" = "YES" ] || fail "CoreGraphics file hash changed"

log "RESULT: DLADDR_GUARD_PREFLIGHT_SNOW_PASS"
log "RESULT: PASS"
exit 0
