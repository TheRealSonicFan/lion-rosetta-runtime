#!/bin/bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="${1:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-write-restore-private-dyld}"
SHA_FILE="${2:-$PROBE.sha256}"
REPORT="${3:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-write-restore-snow.txt}"
RAW="$REPORT.raw.log"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
EXPECTED_SLICE_SHA="83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a"
: > "$REPORT" || exit 73
: > "$RAW" || exit 73
log(){ echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail(){ log "ERROR: $*"; log "RESULT: FAIL"; exit 1; }
sha(){ /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$(/usr/bin/sw_vers -buildVersion)" = "10K549" ] || fail "requires build 10K549"
[ -f "$PROBE" ] && [ -f "$SHA_FILE" ] && [ -f "$COREGRAPHICS" ] || fail "missing input"
ACTUAL="$(sha "$PROBE")"
DECLARED="$(/usr/bin/awk 'NR==1{print $1}' "$SHA_FILE")"
[ "$ACTUAL" = "$DECLARED" ] || fail "probe hash mismatch"
TMP="$(/usr/bin/mktemp /tmp/event-unflip-dladdr.XXXXXX)" || fail "mktemp failed"
trap '/bin/rm -f "$TMP"' EXIT HUP INT TERM
/bin/rm -f "$TMP"
/usr/bin/lipo "$COREGRAPHICS" -thin ppc7400 -output "$TMP" >/dev/null 2>&1 || /usr/bin/lipo -thin ppc7400 "$COREGRAPHICS" -output "$TMP" >/dev/null 2>&1 || fail "cannot extract ppc7400 slice"
[ "$(sha "$TMP")" = "$EXPECTED_SLICE_SHA" ] || fail "CoreGraphics slice mismatch"
BEFORE="$(sha "$COREGRAPHICS")"
"$PROBE" > "$RAW" 2>&1
RC=$?
/bin/cat "$RAW" | /usr/bin/tee -a "$REPORT"
AFTER="$(sha "$COREGRAPHICS")"
[ "$BEFORE" = "$AFTER" ] || fail "CoreGraphics file hash changed"
for marker in  "preflight_contract=carbon-gui-event-unflip-dladdr-write-restore-v1"  "preflight_mode=snow-ppc-control"  "candidate_route=EXISTING_DLADDR_PICSYMBOLSTUB1"  "candidate_branch_word=0x48524d51"  "dladdr_stub_runtime_shape_match=YES"  "candidate_write_readback_match=YES"  "original_restore_readback_match=YES"  "final_protection_match=YES"  "loaded_callsite_bytes_restored=YES"  "vm_protect_attempts=2"  "coregraphics_text_write_attempts=2"  "candidate_instruction_executed=NO"  "dladdr_stub_executed=NO"  "preflight_complete=YES"  "RESULT: PASS"; do
 /usr/bin/grep -Fxc "$marker" "$RAW" >/dev/null 2>&1 || fail "missing marker: $marker"
done
[ "$RC" -eq 0 ] || fail "probe failed"
log "protected_hashes_unchanged=YES"
log "RESULT: DLADDR_WRITE_RESTORE_SNOW_PASS"
log "RESULT: PASS"
