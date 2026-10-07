#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api-private-dyld}"
EXE_SHA_FILE="${2:-$EXE.sha256}"
INTERPOSER="${3:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-api.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
REPORT="${5:-$ROOT/payload/lion-ppc-process-manager-security-session-auditinfo-api.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-security-session-auditinfo-api.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
SECURITY="/System/Library/Frameworks/Security.framework/Versions/A/Security"
SECURITYD="/usr/sbin/securityd"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_BUILD_ID="security-session-auditinfo-api-v1"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() {
    code="$1"
    shift
    log "ERROR: $*"
    exit "$code"
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
abspath() {
    file="$1"
    dir="$(/usr/bin/dirname "$file")"
    base="$(/usr/bin/basename "$file")"
    (cd "$dir" 2>/dev/null && echo "$(pwd)/$base")
}

log "== Lion PPC SessionGetInfo AuditInfo API adapter =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${SECURITYSERVER+x}" ] || die 68 "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset before the runner"
[ -z "${ROSETTA_SECURITY_SESSION_API_COMPAT_MODE+x}" ] || die 68 "compat mode must be unset before the runner"
[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$SECURITY" "$SECURITYD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$EXE" "$EXE_SHA_FILE" "$INTERPOSER" "$INTERPOSER_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$EXE_SHA_FILE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"

KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
SECURITYD_BEFORE="$(sha256 "$SECURITYD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
EXE_BEFORE="$(sha256 "$EXE")"
INTERPOSER_BEFORE="$(sha256 "$INTERPOSER")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "security_sha256_before=$SECURITY_BEFORE"
log "securityd_sha256_before=$SECURITYD_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"
log "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA"
log "actual_interposer_sha256=$INTERPOSER_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "probe hash mismatch"
[ "$INTERPOSER_BEFORE" = "$EXPECTED_INTERPOSER_SHA" ] || die 68 "interposer hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

/usr/bin/grep -Fq "$SECURITY" "$ROSETTA_CACHE_MAP" || die 68 "Security is absent from Rosetta cache map"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || die 68 "interposer build marker missing"

INTERPOSER_ABS="$(abspath "$INTERPOSER")"
[ -n "$INTERPOSER_ABS" ] || die 68 "could not resolve interposer absolute path"
log "interposer_absolute_path=$INTERPOSER_ABS"

MARKER="$(/usr/bin/mktemp /tmp/lion-security-session-api-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC SESSIONGETINFO RUN WITH AUDITINFO API ADAPTER =="
log "+ ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 DYLD_INSERT_LIBRARIES=$INTERPOSER_ABS DYLD_SHARED_CACHE_DONT_VALIDATE=1 $EXE"

ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 DYLD_INSERT_LIBRARIES="$INTERPOSER_ABS" DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_INTERPOSING=1 DYLD_PRINT_LIBRARIES=1 "$EXE" > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "security_session_exec_status=$RC"

/bin/sleep 2
log ""
log "== New diagnostics since test start =="
FOUND=0
if [ -d "$HOME/Library/Logs/DiagnosticReports" ]; then
    NEW="$(/usr/bin/find "$HOME/Library/Logs/DiagnosticReports" -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW" ]; then log "$NEW"; FOUND=1; fi
fi
if [ -d /cores ]; then
    NEW="$(/usr/bin/find /cores -type f -newer "$MARKER" -print 2>/dev/null || true)"
    if [ -n "$NEW" ]; then log "$NEW"; FOUND=1; fi
fi
[ "$FOUND" -eq 1 ] || log "none detected"
/bin/rm -f "$MARKER"

log ""
log "== Post-test integrity =="
[ "$(sha256 /mach_kernel)" = "$KERNEL_BEFORE" ] || die 70 "kernel changed"
[ "$(sha256 "$TRANSLATOR")" = "$TRANSLATOR_BEFORE" ] || die 70 "translator changed"
[ "$(sha256 "$PRIVATE_DYLD")" = "$PRIVATE_BEFORE" ] || die 70 "private dyld changed"
[ "$(sha256 "$SYSTEM_DYLD")" = "$SYSTEM_BEFORE" ] || die 70 "system dyld changed"
[ "$(sha256 "$SECURITY")" = "$SECURITY_BEFORE" ] || die 70 "Security changed"
[ "$(sha256 "$SECURITYD")" = "$SECURITYD_BEFORE" ] || die 70 "securityd changed"
[ "$(sha256 "$ROSETTA_CACHE")" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$(sha256 "$EXE")" = "$EXE_BEFORE" ] || die 70 "probe changed"
[ "$(sha256 "$INTERPOSER")" = "$INTERPOSER_BEFORE" ] || die 70 "interposer changed"
log "protected_hashes_unchanged=YES"

ADAPTER_LINE="$(/usr/bin/grep 'PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS ' "$RAW_LOG" | /usr/bin/tail -1)"
PROBE_LINE="$(/usr/bin/grep 'PM_SECURITY_SESSION_VALUE:ID=' "$RAW_LOG" | /usr/bin/tail -1)"
ADAPTER_ID="$(echo "$ADAPTER_LINE" | /usr/bin/sed -n 's/.* id=\(0x[0-9a-fA-F]*\).*/\1/p')"
ADAPTER_ATTRS="$(echo "$ADAPTER_LINE" | /usr/bin/sed -n 's/.* attrs=\(0x[0-9a-fA-F]*\).*/\1/p')"
PROBE_ID="$(echo "$PROBE_LINE" | /usr/bin/sed -n 's/.*ID=\(0x[0-9a-fA-F]*\).*/\1/p')"
PROBE_ATTRS="$(echo "$PROBE_LINE" | /usr/bin/sed -n 's/.*ATTRS=\(0x[0-9a-fA-F]*\).*/\1/p')"

log "adapter_probe_id_match=$([ -n "$ADAPTER_ID" ] && [ "$ADAPTER_ID" = "$PROBE_ID" ] && echo YES || echo NO) adapter=$ADAPTER_ID probe=$PROBE_ID"
log "adapter_probe_attrs_match=$([ -n "$ADAPTER_ATTRS" ] && [ "$ADAPTER_ATTRS" = "$PROBE_ATTRS" ] && echo YES || echo NO) adapter=$ADAPTER_ATTRS probe=$PROBE_ATTRS"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq "dyld: loaded: $INTERPOSER_ABS" "$RAW_LOG" &&
   /usr/bin/grep -Fq "PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_CALL:' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'mode=lion-auditinfo-v1' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'targetCaller=YES' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_LAYOUT:size=0x30 asidOffset=0x24 flagsOffset=0x28 flagsSize=0x08' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_AUDIT:rc=0 errno=0 ' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_API_COMPAT_RESULT:ADAPTER_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_STATUS:SessionGetInfo=0' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_SESSION_RESULT:PASS' "$RAW_LOG" &&
   [ -n "$ADAPTER_ID" ] && [ "$ADAPTER_ID" = "$PROBE_ID" ] &&
   [ -n "$ADAPTER_ATTRS" ] && [ "$ADAPTER_ATTRS" = "$PROBE_ATTRS" ]; then
    log "RESULT: SECURITY_SESSION_AUDITINFO_API_ADAPTER_PASS"
    exit 0
fi

log "RESULT: SECURITY_SESSION_AUDITINFO_API_ADAPTER_FAIL"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
