#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-cps-registration-compat-protocol-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
REPORT="${3:-$ROOT/payload/lion-ppc-process-manager-cps-registration-compat-protocol.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-cps-registration-compat-protocol.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_COREGRAPHICS_SHA="fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192"
EXPECTED_BUILD_ID="cps-registration-compat-protocol-v1"
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

log "== Lion PPC CPS registration compatibility policy proof =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset"
[ -z "${LSDONOTABORTIFNOASN+x}" ] || die 68 "LSDONOTABORTIFNOASN must be unset"
log "DYLD_INSERT_LIBRARIES=UNSET_IN_PARENT"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD"          "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS"          "$EXE" "$SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
CG_BEFORE="$(sha256 "$COREGRAPHICS")"
EXE_BEFORE="$(sha256 "$EXE")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "coregraphics_sha256_before=$CG_BEFORE"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$CG_BEFORE" = "$EXPECTED_COREGRAPHICS_SHA" ] || die 68 "CoreGraphics baseline hash mismatch"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "probe executable hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

/usr/bin/lipo -verify_arch ppc "$EXE" >/dev/null 2>&1 || /usr/bin/lipo "$EXE" -verify_arch ppc >/dev/null 2>&1 || die 67 "probe is not 32-bit PPC"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/strings "$EXE" | /usr/bin/grep -Fq     "PM_CPS_REGISTRATION_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || die 68 "build marker missing"

MARKER="$(/usr/bin/mktemp /tmp/lion-cps-registration-policy-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC CPS REGISTRATION POLICY PROOF =="
log "+ DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 $EXE lion-policy-proof"
DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1     "$EXE" lion-policy-proof > "$RAW_LOG" 2>&1
RC=$?

/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "cps_registration_policy_exec_status=$RC"

/bin/sleep 3
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
[ "$(sha256 "$ROSETTA_CACHE")" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$(sha256 "$COREGRAPHICS")" = "$CG_BEFORE" ] || die 70 "CoreGraphics changed"
[ "$(sha256 "$EXE")" = "$EXE_BEFORE" ] || die 70 "probe executable changed"
log "protected_hashes_unchanged=YES"

if [ "$RC" -eq 0 ] && [ "$FOUND" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_REQUEST_POLICY:legacyId=0x00007372 lionId=0x000073c1 legacySend=0x00000084 lionSend=0x00000090 recv=0x0000002c changedCommonBytes=1 sourceChangedBytes=0 tailByte=0x00 tailU32_0=0x00000000 tailU32_1=0x00000010' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_REPLY_POLICY:lionId=0x00007425 legacyId=0x000073d6 size=0x00000024 changedBytes=2 result=0 ndrSwapped=YES' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CPS_REGISTRATION_COMPAT_RESULT:LION_POLICY_PROOF_PASS' "$RAW_LOG"; then
    log "RESULT: CPS_REGISTRATION_COMPAT_POLICY_PROOF_PASS"
    exit 0
fi

log "RESULT: CPS_REGISTRATION_COMPAT_POLICY_PROOF_UNCLASSIFIED_FAILURE rc=$RC diagnostics=$FOUND"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
