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
CORE_SHA_FILE="$CORE_COMPAT.sha256"
SEC_SHA_FILE="$SEC_INTERPOSER.sha256"
CGS_SHA_FILE="$CGS_INTERPOSER.sha256"
EXPECTED_KERNEL_SHA="fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_COREGRAPHICS_SHA="fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192"
EXPECTED_CORE_COMPAT_SHA="28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578"
EXPECTED_SEC_SHA="9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51"
EXPECTED_CGS_SHA="f7dbcb98cbf5d64f95a33af222432d5a86ba273b475f5e3de83fff6d6c3c931b"
: > "$REPORT" || exit 73
: > "$RAW" || exit 73
log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail() { log "ERROR: $*"; log "RESULT: PATCH_PLACEMENT_PREFLIGHT_LION_FAIL"; log "RESULT: FAIL"; exit 1; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
sidecar_sha() { /usr/bin/awk 'NR==1 {print $1}' "$1"; }
is_ppc32() { /usr/bin/lipo -verify_arch ppc "$1" >/dev/null 2>&1 && return 0; /usr/bin/lipo "$1" -verify_arch ppc >/dev/null 2>&1 && return 0; return 1; }
verify_hash_pair() { file="$1"; sha_file="$2"; expected="$3"; label="$4"; [ -f "$file" ] || fail "missing $label: $file"; [ -f "$sha_file" ] || fail "missing $label SHA: $sha_file"; actual="$(sha256 "$file")"; declared="$(sidecar_sha "$sha_file")"; log "$label.sha256=$actual"; [ "$actual" = "$expected" ] || fail "$label hash mismatch"; [ "$declared" = "$expected" ] || fail "$label sidecar hash mismatch"; }
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
for p in "$PROBE" "$PROBE_SHA" "$MARKER" "$MARKER_SHA" "$CORE_COMPAT" "$CORE_SHA_FILE" "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$CGS_INTERPOSER" "$CGS_SHA_FILE" "$KERNEL" "$TRANSLATOR" "$PRIVATE_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS"; do [ -f "$p" ] || fail "missing required file: $p"; done
is_ppc32 "$PROBE" || fail "probe is not 32-bit PPC"
is_ppc32 "$MARKER" || fail "marker is not 32-bit PPC"
OT="$(/usr/bin/otool -l "$PROBE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "probe LC_LOAD_DYLINKER is not /usr/oah/dyld"
PROBE_EXPECTED="$(sidecar_sha "$PROBE_SHA")"; PROBE_ACTUAL="$(sha256 "$PROBE")"
MARKER_EXPECTED="$(sidecar_sha "$MARKER_SHA")"; MARKER_ACTUAL="$(sha256 "$MARKER")"
[ "$PROBE_EXPECTED" = "$PROBE_ACTUAL" ] || fail "probe hash mismatch"
[ "$MARKER_EXPECTED" = "$MARKER_ACTUAL" ] || fail "marker hash mismatch"
verify_hash_pair "$CORE_COMPAT" "$CORE_SHA_FILE" "$EXPECTED_CORE_COMPAT_SHA" "coreservices_compat"
verify_hash_pair "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$EXPECTED_SEC_SHA" "security_interposer"
verify_hash_pair "$CGS_INTERPOSER" "$CGS_SHA_FILE" "$EXPECTED_CGS_SHA" "cgs_interposer"
KERNEL_BEFORE="$(sha256 "$KERNEL")"; TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"; DYLD_BEFORE="$(sha256 "$PRIVATE_DYLD")"; CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"; CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"; CORE_BEFORE="$(sha256 "$COREGRAPHICS")"
[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || fail "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || fail "translator hash mismatch"
[ "$DYLD_BEFORE" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || fail "Rosetta cache hash mismatch"
[ "$CACHE_MAP_BEFORE" = "$EXPECTED_CACHE_MAP_SHA" ] || fail "Rosetta cache map hash mismatch"
[ "$CORE_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || fail "CoreGraphics hash mismatch"
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
