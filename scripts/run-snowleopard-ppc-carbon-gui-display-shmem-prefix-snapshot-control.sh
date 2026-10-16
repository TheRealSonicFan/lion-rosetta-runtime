#!/bin/bash
set -u

if [ "$#" -ge 1 ]; then EXE="$1"; else EXE="./ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld"; fi
if [ "$#" -ge 2 ]; then SHA_FILE="$2"; else SHA_FILE="$EXE.sha256"; fi
if [ "$#" -ge 3 ]; then REPORT="$3"; else REPORT="./ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt"; fi

RAW_LOG="$REPORT.raw.log"
PRIVATE_DYLD="/usr/oah/dyld"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_COREGRAPHICS_SHA="2e2fa8b25aff0fd85565d67c585dd368e79eee5d12716eac2b1c3511a1aadd18"

: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
fail() {
    log "ERROR: $*"
    log "RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_SNOW_FAIL"
    log "RESULT: FAIL"
    exit 1
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
sidecar_sha() { /usr/bin/awk 'NR==1 {print $1}' "$1"; }

is_ppc32() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

log "== Snow Leopard PPC display-shmem prefix snapshot control =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"

[ "$PRODUCT_VERSION" = "10.6.8" ] || fail "requires Snow Leopard 10.6.8"
[ "$BUILD_VERSION" = "10K549" ] || fail "requires Snow Leopard build 10K549"
[ -n "$CURRENT_USER" ] || fail "could not determine current user"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || fail "run from the logged-in Aqua console user's Terminal session"
/bin/ps -ax | /usr/bin/grep -q '[W]indowServer' || fail "WindowServer is not running"

[ -x "$EXE" ] || fail "missing PPC snapshot probe: $EXE"
[ -f "$SHA_FILE" ] || fail "missing PPC probe SHA sidecar: $SHA_FILE"
[ -f "$PRIVATE_DYLD" ] || fail "missing private dyld"
[ -f "$COREGRAPHICS" ] || fail "missing CoreGraphics"

EXPECTED_EXE_SHA="$(sidecar_sha "$SHA_FILE")"
ACTUAL_EXE_SHA="$(sha256 "$EXE")"
DYLD_BEFORE="$(sha256 "$PRIVATE_DYLD")"
COREGRAPHICS_BEFORE="$(sha256 "$COREGRAPHICS")"

log "expected_probe_sha256=$EXPECTED_EXE_SHA"
log "actual_probe_sha256=$ACTUAL_EXE_SHA"
log "private_dyld_sha256_before=$DYLD_BEFORE"
log "coregraphics_sha256_before=$COREGRAPHICS_BEFORE"

[ -n "$EXPECTED_EXE_SHA" ] || fail "empty probe SHA sidecar"
[ "$ACTUAL_EXE_SHA" = "$EXPECTED_EXE_SHA" ] || fail "probe hash mismatch"
[ "$DYLD_BEFORE" = "$EXPECTED_DYLD_SHA" ] || fail "private dyld hash mismatch"
[ "$COREGRAPHICS_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || fail "CoreGraphics hash mismatch"
is_ppc32 "$EXE" || fail "probe is not 32-bit PPC"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || fail "PPC LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/otool -L "$EXE" | /usr/bin/tee -a "$REPORT"
/usr/bin/otool -L "$EXE" | /usr/bin/grep -Eq 'ApplicationServices|CoreGraphics' ||
    fail "CoreGraphics/ApplicationServices dependency absent"

MARKER="$(/usr/bin/mktemp /tmp/display-shmem-prefix-snow.XXXXXX)" ||
    fail "could not create diagnostic marker"

log ""
log "== SINGLE READ-ONLY PPC SNAPSHOT CONTROL =="

(
    unset DYLD_INSERT_LIBRARIES
    unset DYLD_SHARED_CACHE_DONT_VALIDATE
    unset ROSETTA_CORESERVICES_COMPAT_MODE
    unset ROSETTA_SECURITY_SESSION_API_COMPAT_MODE
    unset ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE
    unset ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE
    "$EXE"
) > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "probe_exit_status=$RC"

/bin/sleep 2
FOUND_DIAG=0
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
if [ -d "$CRASH_DIR" ]; then
    NEW_CRASH="$(/usr/bin/find "$CRASH_DIR" -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CRASH" ]; then
        log "new_diagnostics=$NEW_CRASH"
        FOUND_DIAG=1
    fi
fi
if [ -d /cores ]; then
    NEW_CORES="$(/usr/bin/find /cores -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW_CORES" ]; then
        log "new_cores=$NEW_CORES"
        FOUND_DIAG=1
    fi
fi
[ "$FOUND_DIAG" -eq 1 ] || log "new_diagnostics=none"
/bin/rm -f "$MARKER"

DYLD_AFTER="$(sha256 "$PRIVATE_DYLD")"
COREGRAPHICS_AFTER="$(sha256 "$COREGRAPHICS")"
log "private_dyld_sha256_after=$DYLD_AFTER"
log "coregraphics_sha256_after=$COREGRAPHICS_AFTER"

PROTECTED_HASHES_UNCHANGED=YES
[ "$DYLD_AFTER" = "$DYLD_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
[ "$COREGRAPHICS_AFTER" = "$COREGRAPHICS_BEFORE" ] || PROTECTED_HASHES_UNCHANGED=NO
log "protected_hashes_unchanged=$PROTECTED_HASHES_UNCHANGED"

CONTRACT_COUNT="$(/usr/bin/grep -c '^snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v3$' "$RAW_LOG" 2>/dev/null || true)"
MODE_COUNT="$(/usr/bin/grep -c '^snapshot_mode=snow-ppc-control$' "$RAW_LOG" 2>/dev/null || true)"
SELECTOR_DIRECT="$(/usr/bin/grep -c '^selector_direct_read=PASS$' "$RAW_LOG" 2>/dev/null || true)"
SELECTOR_VALID="$(/usr/bin/grep -c '^selector_index_valid=YES$' "$RAW_LOG" 2>/dev/null || true)"
SOURCE_COUNT="$(/usr/bin/grep -c '^source_after_nonnull=YES$' "$RAW_LOG" 2>/dev/null || true)"
SOURCE_DIRECT="$(/usr/bin/grep -c '^source_direct_read=PASS$' "$RAW_LOG" 2>/dev/null || true)"
COUNT_VALID="$(/usr/bin/grep -c '^record_count_valid=YES$' "$RAW_LOG" 2>/dev/null || true)"
MAIN_NONZERO="$(/usr/bin/grep -c '^main_display_id_zero=NO$' "$RAW_LOG" 2>/dev/null || true)"
SNAPSHOT_COMPLETE="$(/usr/bin/grep -c '^snapshot_complete=YES$' "$RAW_LOG" 2>/dev/null || true)"
WRITE_ZERO="$(/usr/bin/grep -c '^write_attempts=0$' "$RAW_LOG" 2>/dev/null || true)"
PROBE_PASS="$(/usr/bin/grep -c '^RESULT: PASS$' "$RAW_LOG" 2>/dev/null || true)"

log "contract_v3_count=$CONTRACT_COUNT"
log "mode_count=$MODE_COUNT"
log "selector_direct_read_pass_count=$SELECTOR_DIRECT"
log "selector_index_valid_count=$SELECTOR_VALID"
log "source_nonnull_count=$SOURCE_COUNT"
log "source_direct_read_pass_count=$SOURCE_DIRECT"
log "record_count_valid_count=$COUNT_VALID"
log "main_display_nonzero_count=$MAIN_NONZERO"
log "snapshot_complete_count=$SNAPSHOT_COMPLETE"
log "write_attempts_zero_count=$WRITE_ZERO"
log "probe_pass_count=$PROBE_PASS"

if [ "$RC" -eq 0 ] &&
   [ "$FOUND_DIAG" -eq 0 ] &&
   [ "$PROTECTED_HASHES_UNCHANGED" = "YES" ] &&
   [ "$CONTRACT_COUNT" -eq 1 ] &&
   [ "$MODE_COUNT" -eq 1 ] &&
   [ "$SELECTOR_DIRECT" -eq 1 ] &&
   [ "$SELECTOR_VALID" -eq 1 ] &&
   [ "$SOURCE_COUNT" -eq 1 ] &&
   [ "$SOURCE_DIRECT" -eq 1 ] &&
   [ "$COUNT_VALID" -eq 1 ] &&
   [ "$MAIN_NONZERO" -eq 1 ] &&
   [ "$SNAPSHOT_COMPLETE" -eq 1 ] &&
   [ "$WRITE_ZERO" -ge 2 ] &&
   [ "$PROBE_PASS" -eq 1 ]; then
    log "RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_SNOW_PASS"
    log "RESULT: PASS"
    exit 0
fi

fail "Snow read-only prefix snapshot did not satisfy the control gate"
