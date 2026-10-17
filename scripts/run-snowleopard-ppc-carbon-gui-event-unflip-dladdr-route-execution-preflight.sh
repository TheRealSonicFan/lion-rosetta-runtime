#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INTERPOSER="${1:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-route-leaf-interposer.dylib}"
INTERPOSER_SHA="${2:-$INTERPOSER.sha256}"
PROBE="${3:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld}"
PROBE_SHA="${4:-$PROBE.sha256}"
REPORT="${5:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-route-execution-snow.txt}"
RAW="$REPORT.raw.log"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
EXPECTED_COREGRAPHICS_PPC_SHA="83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a"
EXPECTED_INTERPOSER_BUILD_ID="event-unflip-dladdr-route-leaf-guard-v1"
EXPECTED_PROBE_CONTRACT="carbon-gui-event-unflip-dladdr-route-execution-v3"

: > "$REPORT" || exit 73
: > "$RAW" || exit 73
log(){ echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail(){ log "ERROR: $*"; log "RESULT: DLADDR_ROUTE_EXECUTION_SNOW_FAIL"; log "RESULT: FAIL"; exit 1; }
sha256(){ /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
sidecar_sha(){ /usr/bin/awk 'NR==1{print $1}' "$1"; }
is_ppc32(){
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"; desc="${desc#*: }"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc([0-9]+)?|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}
require_one(){ /usr/bin/grep -Fxc "$1" "$RAW" >/dev/null 2>&1 || fail "missing probe marker: $1"; }

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "== Snow event-unflip dladdr patched-route execution preflight =="
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"

for p in "$INTERPOSER" "$INTERPOSER_SHA" "$PROBE" "$PROBE_SHA" "$COREGRAPHICS"; do [ -f "$p" ] || fail "missing required file: $p"; done
is_ppc32 "$INTERPOSER" || fail "route leaf interposer is not 32-bit PPC"
is_ppc32 "$PROBE" || fail "route probe is not 32-bit PPC"

INTERPOSER_ACTUAL="$(sha256 "$INTERPOSER")"
PROBE_ACTUAL="$(sha256 "$PROBE")"
log "dladdr_route_leaf_interposer.sha256=$INTERPOSER_ACTUAL"
log "dladdr_route_execution_probe.sha256=$PROBE_ACTUAL"
[ "$INTERPOSER_ACTUAL" = "$(sidecar_sha "$INTERPOSER_SHA")" ] || fail "route leaf interposer sidecar mismatch"
[ "$PROBE_ACTUAL" = "$(sidecar_sha "$PROBE_SHA")" ] || fail "route probe sidecar mismatch"
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq "PM_EVENT_UNFLIP_DLADDR_ROUTE_GUARD_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || fail "route leaf interposer marker missing"
/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq "$EXPECTED_PROBE_CONTRACT" || fail "route probe contract marker missing"

TMP="$(/usr/bin/mktemp /tmp/event-unflip-route-coregraphics.XXXXXX)" || fail "mktemp failed"
trap '/bin/rm -f "$TMP"' EXIT HUP INT TERM
/bin/rm -f "$TMP"
/usr/bin/lipo "$COREGRAPHICS" -thin ppc7400 -output "$TMP" >/dev/null 2>&1 || /usr/bin/lipo -thin ppc7400 "$COREGRAPHICS" -output "$TMP" >/dev/null 2>&1 || fail "cannot extract ppc7400 CoreGraphics slice"
[ "$(sha256 "$TMP")" = "$EXPECTED_COREGRAPHICS_PPC_SHA" ] || fail "CoreGraphics PPC slice mismatch"

CORE_BEFORE="$(sha256 "$COREGRAPHICS")"
ROSETTA_EVENT_UNFLIP_DLADDR_GUARD_MODE=passthrough DYLD_INSERT_LIBRARIES="$INTERPOSER" "$PROBE" > "$RAW" 2>&1
RC=$?
/bin/cat "$RAW" | /usr/bin/tee -a "$REPORT"
log "probe_exit_status=$RC"
CORE_AFTER="$(sha256 "$COREGRAPHICS")"
UNCHANGED=YES
[ "$CORE_BEFORE" = "$CORE_AFTER" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"

for marker in \
 "probe_contract=carbon-gui-event-unflip-dladdr-route-execution-v3" \
 "preflight_mode=snow-ppc-control" \
 "guard_mode=passthrough" \
 "guard_target_leaf_contract_dlsym=PASS" \
 "guard_target_leaf_contract=PASS" \
 "target_return_matches_callsite_plus4=YES" \
 "candidate_branch_reachable=YES" \
 "candidate_branch_word=0x48524d51" \
 "event_unflip_prologue_match=YES" \
 "bounds_call_original_word_match=YES" \
 "selected_dladdr_stub_runtime_shape_match=YES" \
 "original_replacee_helper_dlsym=PASS" \
 "selected_stub_warmup_result_match=YES" \
 "selected_stub_warmup_info_match=YES" \
 "selected_stub_warmup_non_target_delta=1" \
 "selected_stub_warmup_target_delta=0" \
 "selected_dladdr_stub_direct_probe_calls=1" \
 "selected_stub_warmup_complete=YES" \
 "callsite_region_max_write=YES" \
 "vm_protect_enable_candidate_kr=0" \
 "candidate_install_readback_match=YES" \
 "vm_protect_candidate_lockdown_kr=0" \
 "candidate_execution_protection_match=YES" \
 "candidate_instruction_execution_attempts=1" \
 "vm_protect_enable_restore_kr=0" \
 "original_restore_readback_match=YES" \
 "vm_protect_final_restore_kr=0" \
 "final_protection_match=YES" \
 "loaded_callsite_bytes_restored=YES" \
 "patched_route_target_wrapper_delta=1" \
 "patched_route_non_target_delta=0" \
 "event_return_matches_output=YES" \
 "event_output_x_preserved=YES" \
 "event_output_y_preserved=YES" \
 "event_cache_extent_unchanged_zero=YES" \
 "patched_target_wrapper_executed=YES" \
 "failclosed_event_path_preserved=YES" \
 "vm_protect_attempts=4" \
 "coregraphics_text_write_attempts=2" \
 "dcache_flush_attempts=2" \
 "icache_invalidate_attempts=2" \
 "synthetic_event_unflip_calls=1" \
 "functional_source_helper_executed=NO" \
 "preflight_complete=YES" \
 "RESULT: PASS"
do
    require_one "$marker"
done

BUILD_ID_COUNT="$(/usr/bin/grep -Fxc "PM_EVENT_UNFLIP_DLADDR_ROUTE_GUARD_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" "$RAW" || true)"
[ "$BUILD_ID_COUNT" = "1" ] || fail "expected exactly one route leaf interposer build marker, saw $BUILD_ID_COUNT"
[ "$RC" -eq 0 ] || fail "route probe returned nonzero"
[ "$UNCHANGED" = "YES" ] || fail "CoreGraphics file hash changed"

log "RESULT: DLADDR_ROUTE_EXECUTION_SNOW_PASS"
log "RESULT: PASS"
exit 0
