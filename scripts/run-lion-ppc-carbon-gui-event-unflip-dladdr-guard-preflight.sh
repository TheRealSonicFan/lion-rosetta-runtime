#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INTERPOSER="${1:-$ROOT/payload/ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib}"
INTERPOSER_SHA="${2:-$INTERPOSER.sha256}"
PROBE="${3:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld}"
PROBE_SHA="${4:-$PROBE.sha256}"
REPORT="${5:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-preflight-lion.txt}"
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
fail() { log "ERROR: $*"; log "RESULT: DLADDR_GUARD_PREFLIGHT_LION_FAIL"; log "RESULT: FAIL"; exit 1; }
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

verify_exact() {
    file="$1"; expected="$2"; label="$3"
    [ -f "$file" ] || fail "missing $label: $file"
    actual="$(sha256 "$file")"
    log "$label.sha256=$actual"
    [ "$actual" = "$expected" ] || fail "$label hash mismatch"
}

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

log "== Lion translated-PPC event-unflip dladdr guard preflight =="
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || fail "requires Lion 10.7.5"
[ "$BUILD_VERSION" = "11G63" ] || fail "requires Lion build 11G63"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from logged-in Aqua console user"

for p in "$INTERPOSER" "$INTERPOSER_SHA" "$PROBE" "$PROBE_SHA" "$CORE_COMPAT" "$SEC_INTERPOSER" "$CGS_INTERPOSER"; do
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

verify_exact "$KERNEL" "$EXPECTED_KERNEL_SHA" "kernel"
verify_exact "$TRANSLATOR" "$EXPECTED_TRANSLATOR_SHA" "translator"
verify_exact "$PRIVATE_DYLD" "$EXPECTED_DYLD_SHA" "private_dyld"
verify_exact "$ROSETTA_CACHE" "$EXPECTED_CACHE_SHA" "rosetta_cache"
verify_exact "$ROSETTA_CACHE_MAP" "$EXPECTED_CACHE_MAP_SHA" "rosetta_cache_map"
verify_exact "$COREGRAPHICS" "$EXPECTED_COREGRAPHICS_SHA" "coregraphics"
verify_exact "$CORE_COMPAT" "$EXPECTED_CORE_COMPAT_SHA" "coreservices_compat"
verify_exact "$SEC_INTERPOSER" "$EXPECTED_SEC_SHA" "security_interposer"
verify_exact "$CGS_INTERPOSER" "$EXPECTED_CGS_SHA" "cgs_interposer"

KERNEL_BEFORE="$(sha256 "$KERNEL")"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
DYLD_BEFORE="$(sha256 "$PRIVATE_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"
CORE_BEFORE="$(sha256 "$COREGRAPHICS")"

INSERT_LIBS="$CORE_COMPAT:$SEC_INTERPOSER:$CGS_INTERPOSER:$INTERPOSER"
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 ROSETTA_EVENT_UNFLIP_DLADDR_GUARD_MODE=lion-guard-v1 DYLD_INSERT_LIBRARIES="$INSERT_LIBS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PROBE" > "$RAW" 2>&1
RC=$?
/bin/cat "$RAW" | /usr/bin/tee -a "$REPORT"
log "probe_exit_status=$RC"

UNCHANGED=YES
[ "$(sha256 "$KERNEL")" = "$KERNEL_BEFORE" ] || UNCHANGED=NO
[ "$(sha256 "$TRANSLATOR")" = "$TRANSLATOR_BEFORE" ] || UNCHANGED=NO
[ "$(sha256 "$PRIVATE_DYLD")" = "$DYLD_BEFORE" ] || UNCHANGED=NO
[ "$(sha256 "$ROSETTA_CACHE")" = "$CACHE_BEFORE" ] || UNCHANGED=NO
[ "$(sha256 "$ROSETTA_CACHE_MAP")" = "$CACHE_MAP_BEFORE" ] || UNCHANGED=NO
[ "$(sha256 "$COREGRAPHICS")" = "$CORE_BEFORE" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"

require_one() {
    /usr/bin/grep -Fxc "$1" "$RAW" >/dev/null 2>&1 || fail "missing probe marker: $1"
}

require_one "probe_contract=carbon-gui-event-unflip-dladdr-guard-preflight-v1"
require_one "preflight_mode=lion-ppc-translated"
require_one "guard_mode=lion-guard-v1"
require_one "target_return_resolved=YES"
require_one "guard_exact_match=YES"
require_one "guard_minus4_reject=YES"
require_one "guard_plus4_reject=YES"
require_one "original_replacee_available=YES"
require_one "passthrough_result_match=YES"
require_one "passthrough_info_match=YES"
require_one "interposer_target_wrapper_count=0"
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
COUNT="$(/usr/bin/awk -F= '/^interposer_non_target_forward_count=/{print $2; exit}' "$RAW")"
case "$COUNT" in
    ''|*[!0-9]*) fail "invalid non-target forward count: $COUNT" ;;
esac
[ "$COUNT" -ge 1 ] || fail "no non-target dladdr call was forwarded"

[ "$RC" -eq 0 ] || fail "probe returned nonzero"
[ "$UNCHANGED" = "YES" ] || fail "protected hash changed"

log "RESULT: DLADDR_GUARD_PREFLIGHT_LION_PASS"
log "RESULT: PASS"
exit 0
