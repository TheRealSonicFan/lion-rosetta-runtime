#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "$#" -ge 1 ]; then PPC_EXE="$1"; else PPC_EXE="$ROOT/ppc-carbon-gui-display-shmem-projection-proof-private-dyld"; fi
if [ "$#" -ge 2 ]; then PPC_SHA_FILE="$2"; else PPC_SHA_FILE="$PPC_EXE.sha256"; fi
if [ "$#" -ge 3 ]; then I386_EXE="$3"; else I386_EXE="$ROOT/lion-i386-display-shmem-projection-proof"; fi
if [ "$#" -ge 4 ]; then I386_SHA_FILE="$4"; else I386_SHA_FILE="$I386_EXE.sha256"; fi
if [ "$#" -ge 5 ]; then REPORT="$5"; else REPORT="$ROOT/ppc-carbon-gui-display-shmem-projection-proof-lion.txt"; fi

NATIVE_RAW="$REPORT.native.raw.log"
PPC_RAW="$REPORT.ppc.raw.log"

CORE_COMPAT="$ROOT/payload/pm-selectwindow-orderfront-compat.dylib"
CORE_SHA_FILE="$CORE_COMPAT.sha256"
SEC_INTERPOSER="$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib"
SEC_SHA_FILE="$SEC_INTERPOSER.sha256"
CGS_INTERPOSER="$ROOT/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib"
CGS_SHA_FILE="$CGS_INTERPOSER.sha256"

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
: > "$NATIVE_RAW" || exit 73
: > "$PPC_RAW" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail() {
    log "ERROR: $*"
    log "RESULT: DISPLAY_SHMEM_PROJECTION_PROOF_LION_FAIL"
    log "RESULT: FAIL"
    exit 1
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
sidecar_sha() { /usr/bin/awk 'NR==1 {print $1}' "$1"; }

verify_hash_pair() {
    file="$1"; sha_file="$2"; expected="$3"; label="$4"
    [ -f "$file" ] || fail "missing $label: $file"
    [ -f "$sha_file" ] || fail "missing $label SHA sidecar: $sha_file"
    actual="$(sha256 "$file")"
    declared="$(sidecar_sha "$sha_file")"
    log "$label.sha256=$actual"
    [ "$actual" = "$expected" ] || fail "$label hash mismatch"
    [ "$declared" = "$expected" ] || fail "$label sidecar hash mismatch"
}

is_ppc32() {
    /usr/bin/lipo -verify_arch ppc "$1" >/dev/null 2>&1 && return 0
    /usr/bin/lipo "$1" -verify_arch ppc >/dev/null 2>&1 && return 0
    return 1
}
is_i386() {
    /usr/bin/lipo -verify_arch i386 "$1" >/dev/null 2>&1 && return 0
    /usr/bin/lipo "$1" -verify_arch i386 >/dev/null 2>&1 && return 0
    return 1
}

log "== Lion display-shmem projection proof: native reference + translated PPC =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"

[ "$PRODUCT_VERSION" = "10.7.5" ] || fail "requires Lion 10.7.5"
[ "$BUILD_VERSION" = "11G63" ] || fail "requires Lion build 11G63"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

for p in "$PPC_EXE" "$PPC_SHA_FILE" "$I386_EXE" "$I386_SHA_FILE" "$KERNEL" "$TRANSLATOR" "$PRIVATE_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS"; do
    [ -f "$p" ] || fail "missing required file: $p"
done

PPC_EXPECTED="$(sidecar_sha "$PPC_SHA_FILE")"
I386_EXPECTED="$(sidecar_sha "$I386_SHA_FILE")"
PPC_ACTUAL="$(sha256 "$PPC_EXE")"
I386_ACTUAL="$(sha256 "$I386_EXE")"
log "ppc_probe_expected_sha256=$PPC_EXPECTED"
log "ppc_probe_actual_sha256=$PPC_ACTUAL"
log "i386_probe_expected_sha256=$I386_EXPECTED"
log "i386_probe_actual_sha256=$I386_ACTUAL"
[ "$PPC_ACTUAL" = "$PPC_EXPECTED" ] || fail "PPC probe hash mismatch"
[ "$I386_ACTUAL" = "$I386_EXPECTED" ] || fail "i386 probe hash mismatch"
is_ppc32 "$PPC_EXE" || fail "PPC probe is not 32-bit PPC"
is_i386 "$I386_EXE" || fail "native probe is not 32-bit i386"

PPC_OT="$(/usr/bin/otool -l "$PPC_EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$PPC_OT" | /usr/bin/tee -a "$REPORT"
echo "$PPC_OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "PPC LC_LOAD_DYLINKER is not /usr/oah/dyld"

KERNEL_BEFORE="$(sha256 "$KERNEL")"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
DYLD_BEFORE="$(sha256 "$PRIVATE_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"
COREGRAPHICS_BEFORE="$(sha256 "$COREGRAPHICS")"
[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || fail "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || fail "translator hash mismatch"
[ "$DYLD_BEFORE" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || fail "Rosetta cache hash mismatch"
[ "$CACHE_MAP_BEFORE" = "$EXPECTED_CACHE_MAP_SHA" ] || fail "Rosetta cache map hash mismatch"
[ "$COREGRAPHICS_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || fail "CoreGraphics hash mismatch"

verify_hash_pair "$CORE_COMPAT" "$CORE_SHA_FILE" "$EXPECTED_CORE_COMPAT_SHA" "coreservices_compat"
verify_hash_pair "$SEC_INTERPOSER" "$SEC_SHA_FILE" "$EXPECTED_SEC_SHA" "security_interposer"
verify_hash_pair "$CGS_INTERPOSER" "$CGS_SHA_FILE" "$EXPECTED_CGS_SHA" "cgs_interposer"

MARKER="$(/usr/bin/mktemp /tmp/display-shmem-projection-proof-lion.XXXXXX)" ||
    fail "could not create diagnostic marker"

log ""
log "== LION NATIVE i386 REFERENCE =="
(
    unset DYLD_INSERT_LIBRARIES
    unset DYLD_SHARED_CACHE_DONT_VALIDATE
    unset ROSETTA_CORESERVICES_COMPAT_MODE
    unset ROSETTA_SECURITY_SESSION_API_COMPAT_MODE
    unset ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE
    unset ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE
    "$I386_EXE"
) > "$NATIVE_RAW" 2>&1
NATIVE_RC=$?
/bin/cat "$NATIVE_RAW" | /usr/bin/tee -a "$REPORT"
log "native_probe_exit_status=$NATIVE_RC"

log ""
log "== LION TRANSLATED PPC ONE-RECORD PROJECTION PROOF =="
INSERT_LIBS="$CORE_COMPAT:$SEC_INTERPOSER:$CGS_INTERPOSER"
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 DYLD_INSERT_LIBRARIES="$INSERT_LIBS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PPC_EXE" > "$PPC_RAW" 2>&1
PPC_RC=$?
/bin/cat "$PPC_RAW" | /usr/bin/tee -a "$REPORT"
log "ppc_probe_exit_status=$PPC_RC"

/bin/sleep 2
FOUND_DIAG=0
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [ -d "$CRASH_DIR" ]; then
    NEW_CRASH="$(/usr/bin/find "$CRASH_DIR" -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CRASH" ]; then log "new_diagnostics=$NEW_CRASH"; FOUND_DIAG=1; fi
fi
if [ -d /cores ]; then
    NEW_CORES="$(/usr/bin/find /cores -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CORES" ]; then log "new_cores=$NEW_CORES"; FOUND_DIAG=1; fi
fi
[ "$FOUND_DIAG" -eq 1 ] || log "new_diagnostics=none"
/bin/rm -f "$MARKER"

KERNEL_AFTER="$(sha256 "$KERNEL")"
TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"
DYLD_AFTER="$(sha256 "$PRIVATE_DYLD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_AFTER="$(sha256 "$ROSETTA_CACHE_MAP")"
COREGRAPHICS_AFTER="$(sha256 "$COREGRAPHICS")"
PROTECTED_HASHES_UNCHANGED=YES
[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$DYLD_AFTER" = "$DYLD_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$CACHE_MAP_AFTER" = "$CACHE_MAP_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$COREGRAPHICS_AFTER" = "$COREGRAPHICS_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
log "protected_hashes_unchanged=$PROTECTED_HASHES_UNCHANGED"

NATIVE_CONTRACT="$(/usr/bin/grep -c '^proof_contract=carbon-gui-display-shmem-projection-proof-v1$' "$NATIVE_RAW" 2>/dev/null || true)"
NATIVE_MODE="$(/usr/bin/grep -c '^proof_mode=lion-i386-native$' "$NATIVE_RAW" 2>/dev/null || true)"
NATIVE_NONZERO="$(/usr/bin/grep -c '^native_main_display_id_zero=NO$' "$NATIVE_RAW" 2>/dev/null || true)"
NATIVE_WRITES="$(/usr/bin/grep -c '^process_local_pointer_write_count=0$' "$NATIVE_RAW" 2>/dev/null || true)"
NATIVE_PASS="$(/usr/bin/grep -c '^RESULT: PASS$' "$NATIVE_RAW" 2>/dev/null || true)"

PPC_CONTRACT="$(/usr/bin/grep -c '^proof_contract=carbon-gui-display-shmem-projection-proof-v1$' "$PPC_RAW" 2>/dev/null || true)"
PPC_MODE="$(/usr/bin/grep -c '^proof_mode=lion-ppc-translated$' "$PPC_RAW" 2>/dev/null || true)"
PPC_HELPERS="$(/usr/bin/grep -c '^helper_address_validation=PASS$' "$PPC_RAW" 2>/dev/null || true)"
PPC_GLOBALS="$(/usr/bin/grep -c '^runtime_globals_in_segments=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_BASE_ZERO="$(/usr/bin/grep -c '^baseline_public_main_display_id_zero=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_AFTER_ZERO="$(/usr/bin/grep -c '^after_public_main_display_id_zero=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_COUNT_ONE="$(/usr/bin/grep -c '^record_count_exactly_one=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_RECORD_MATCH="$(/usr/bin/grep -c '^local_record_matches_source_record=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_GUARD="$(/usr/bin/grep -c '^projection_fast_path_guard=PASS$' "$PPC_RAW" 2>/dev/null || true)"
PPC_PROJECTION="$(/usr/bin/grep -c '^projection_applied=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_WRITES="$(/usr/bin/grep -c '^process_local_pointer_write_count=2$' "$PPC_RAW" 2>/dev/null || true)"
PPC_TARGET="$(/usr/bin/grep -c '^projection_lookup_returned_target_entry=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_SOURCE_UNCHANGED="$(/usr/bin/grep -c '^source_record_unchanged=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_RESTORED="$(/usr/bin/grep -c '^local_record_pointer_restored=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_STATE="$(/usr/bin/grep -c '^selected_state_ready=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_SERVER_WRITES="$(/usr/bin/grep -c '^server_owned_shared_record_write_attempts=0$' "$PPC_RAW" 2>/dev/null || true)"
PPC_COMPLETE="$(/usr/bin/grep -c '^proof_complete=YES$' "$PPC_RAW" 2>/dev/null || true)"
PPC_PASS="$(/usr/bin/grep -c '^RESULT: PASS$' "$PPC_RAW" 2>/dev/null || true)"

NATIVE_ID="$(/usr/bin/awk -F= '/^native_main_display_id=/{print $2; exit}' "$NATIVE_RAW")"
PROJECTED_ID="$(/usr/bin/awk -F= '/^projected_lookup_display_id=/{print $2; exit}' "$PPC_RAW")"
log "native_main_display_id=$NATIVE_ID"
log "projected_lookup_display_id=$PROJECTED_ID"
IDS_MATCH=NO
if [ -n "$NATIVE_ID" ] && [ "$NATIVE_ID" = "$PROJECTED_ID" ] && [ "$NATIVE_ID" != "0x00000000" ]; then
    IDS_MATCH=YES
fi
log "native_projected_ids_match=$IDS_MATCH"

if [ "$NATIVE_RC" -eq 0 ] &&
   [ "$PPC_RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$NATIVE_CONTRACT" -eq 1 ] &&
   [ "$NATIVE_MODE" -eq 1 ] &&
   [ "$NATIVE_NONZERO" -eq 1 ] &&
   [ "$NATIVE_WRITES" -eq 1 ] &&
   [ "$NATIVE_PASS" -eq 1 ] &&
   [ "$PPC_CONTRACT" -eq 1 ] &&
   [ "$PPC_MODE" -eq 1 ] &&
   [ "$PPC_HELPERS" -eq 1 ] &&
   [ "$PPC_GLOBALS" -eq 1 ] &&
   [ "$PPC_BASE_ZERO" -eq 1 ] &&
   [ "$PPC_AFTER_ZERO" -eq 1 ] &&
   [ "$PPC_COUNT_ONE" -eq 1 ] &&
   [ "$PPC_RECORD_MATCH" -eq 1 ] &&
   [ "$PPC_GUARD" -eq 1 ] &&
   [ "$PPC_PROJECTION" -eq 1 ] &&
   [ "$PPC_WRITES" -eq 1 ] &&
   [ "$PPC_TARGET" -eq 1 ] &&
   [ "$PPC_SOURCE_UNCHANGED" -eq 1 ] &&
   [ "$PPC_RESTORED" -eq 1 ] &&
   [ "$PPC_STATE" -eq 1 ] &&
   [ "$PPC_SERVER_WRITES" -eq 1 ] &&
   [ "$PPC_COMPLETE" -eq 1 ] &&
   [ "$PPC_PASS" -eq 1 ] &&
   [ "$IDS_MATCH" = "YES" ]; then
    log "RESULT: DISPLAY_SHMEM_PROJECTION_PROOF_LION_PASS"
    log "RESULT: PASS"
    exit 0
fi

fail "Lion one-record projection proof did not satisfy the gate"
