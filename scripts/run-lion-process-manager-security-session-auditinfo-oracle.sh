#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PPC="${1:-$ROOT/payload/ppc-process-manager-security-session-auditinfo-private-dyld}"
PPC_SHA_FILE="${2:-$PPC.sha256}"
I386="${3:-$ROOT/payload/i386-process-manager-security-session-auditinfo-oracle}"
I386_SHA_FILE="${4:-$I386.sha256}"
REPORT="${5:-$ROOT/payload/lion-process-manager-security-session-auditinfo-oracle.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-process-manager-security-session-auditinfo-oracle.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
SECURITY="/System/Library/Frameworks/Security.framework/Versions/A/Security"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
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

log "== Lion Security AuditInfo oracle =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${SECURITYSERVER+x}" ] || die 68 "SECURITYSERVER must be unset"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset"
[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$SECURITY" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$PPC" "$PPC_SHA_FILE" "$I386" "$I386_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_PPC_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$PPC_SHA_FILE")"
EXPECTED_I386_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$I386_SHA_FILE")"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
SECURITY_BEFORE="$(sha256 "$SECURITY")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
PPC_BEFORE="$(sha256 "$PPC")"
I386_BEFORE="$(sha256 "$I386")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "security_sha256_before=$SECURITY_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "expected_ppc_sha256=$EXPECTED_PPC_SHA"
log "actual_ppc_sha256=$PPC_BEFORE"
log "expected_i386_sha256=$EXPECTED_I386_SHA"
log "actual_i386_sha256=$I386_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$PPC_BEFORE" = "$EXPECTED_PPC_SHA" ] || die 68 "PPC probe hash mismatch"
[ "$I386_BEFORE" = "$EXPECTED_I386_SHA" ] || die 68 "i386 oracle hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

/usr/bin/grep -Fq "$SECURITY" "$ROSETTA_CACHE_MAP" || die 68 "Security is absent from Rosetta cache map"
OT="$(/usr/bin/otool -l "$PPC" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "PPC LC_LOAD_DYLINKER is not /usr/oah/dyld"

MARKER="$(/usr/bin/mktemp /tmp/lion-security-auditinfo-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== Native Lion i386 SessionGetInfo/AuditInfo oracle =="
echo "== I386 ==" >> "$RAW_LOG"
"$I386" session-audit >> "$RAW_LOG" 2>&1
I386_RC=$?
log "i386_status=$I386_RC"

log ""
log "== Translated PPC direct getaudit_addr probe =="
echo "== PPC ==" >> "$RAW_LOG"
DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PPC" audit-only >> "$RAW_LOG" 2>&1
PPC_RC=$?
log "ppc_status=$PPC_RC"

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"

I386_LINE="$(/usr/bin/grep 'PM_SECURITY_AUDITINFO_GET:arch=i386 ' "$RAW_LOG" | /usr/bin/tail -1)"
PPC_LINE="$(/usr/bin/grep 'PM_SECURITY_AUDITINFO_GET:arch=ppc ' "$RAW_LOG" | /usr/bin/tail -1)"
I386_ASID="$(echo "$I386_LINE" | /usr/bin/sed -n 's/.*word24=\(0x[0-9a-fA-F]*\).*/\1/p')"
I386_FLAGS="$(echo "$I386_LINE" | /usr/bin/sed -n 's/.*word28=\(0x[0-9a-fA-F]*\).*/\1/p')"
PPC_ASID="$(echo "$PPC_LINE" | /usr/bin/sed -n 's/.*word24=\(0x[0-9a-fA-F]*\).*/\1/p')"
PPC_FLAGS="$(echo "$PPC_LINE" | /usr/bin/sed -n 's/.*word28=\(0x[0-9a-fA-F]*\).*/\1/p')"
log "cross_arch_asid_match=$([ -n "$I386_ASID" ] && [ "$I386_ASID" = "$PPC_ASID" ] && echo YES || echo NO) i386=$I386_ASID ppc=$PPC_ASID"
log "cross_arch_flags_match=$([ -n "$I386_FLAGS" ] && [ "$I386_FLAGS" = "$PPC_FLAGS" ] && echo YES || echo NO) i386=$I386_FLAGS ppc=$PPC_FLAGS"

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
[ "$(sha256 "$ROSETTA_CACHE")" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$(sha256 "$PPC")" = "$PPC_BEFORE" ] || die 70 "PPC probe changed"
[ "$(sha256 "$I386")" = "$I386_BEFORE" ] || die 70 "i386 oracle changed"
log "protected_hashes_unchanged=YES"

if [ "$I386_RC" -eq 0 ] &&
   [ "$PPC_RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_SECURITY_AUDITINFO_RESULT:SESSION_AUDIT_MATCH' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_AUDITINFO_GET:arch=ppc rc=0 ' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_SECURITY_AUDITINFO_RESULT:AUDIT_ONLY_PASS' "$RAW_LOG"; then
    log "RESULT: SECURITY_AUDITINFO_ORACLE_PASS"
    exit 0
fi

log "RESULT: SECURITY_AUDITINFO_ORACLE_FAIL"
[ "$I386_RC" -ne 0 ] && exit "$I386_RC"
[ "$PPC_RC" -ne 0 ] && exit "$PPC_RC"
exit 1
