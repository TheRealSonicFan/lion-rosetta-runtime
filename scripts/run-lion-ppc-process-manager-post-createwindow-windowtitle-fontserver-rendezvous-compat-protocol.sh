#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXE="${1:-$ROOT/payload/ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
REPORT="${3:-$ROOT/payload/lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
FONTREGISTRY="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ATS.framework/Versions/A/Resources/libFontRegistry.dylib"
ATSSERVER="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/ATS.framework/Versions/A/Resources/libATSServer.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_FONTREGISTRY_SHA="46a1b10401b2b03e49fd86f20134b6dc012ec61f898965d32cd72c5f31224189"
EXPECTED_ATSSERVER_SHA="5f1deeb31f644f922c0a7163d920c76b66ff814fb2dae107ac99642969e87f59"
EXPECTED_BUILD_ID="windowtitle-fontserver-rendezvous-compat-protocol-v1"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73
log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() { code="$1"; shift; log "ERROR: $*"; exit "$code"; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

is_ppc32_macho() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq "Mach-O" || return 1
    echo "$desc" | /usr/bin/grep -Eiq "(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)" || return 1
    echo "$desc" | /usr/bin/grep -Eiq "ppc64|powerpc64" && return 1
    return 0
}

log "== Lion PPC FontServer rendezvous compatibility policy proof =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"
PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"
[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset"
[ -z "${LSDONOTABORTIFNOASN+x}" ] || die 68 "LSDONOTABORTIFNOASN must be unset"
[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$FONTREGISTRY" "$ATSSERVER" "$EXE" "$SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_SHA="$(sha256 "$ROSETTA_CACHE_MAP")"
FONTREGISTRY_BEFORE="$(sha256 "$FONTREGISTRY")"
ATSSERVER_BEFORE="$(sha256 "$ATSSERVER")"
EXE_BEFORE="$(sha256 "$EXE")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "expected_mach_kernel_sha256=$EXPECTED_KERNEL_SHA"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256=$CACHE_MAP_SHA"
log "fontregistry_sha256_before=$FONTREGISTRY_BEFORE"
log "atsserver_sha256_before=$ATSSERVER_BEFORE"
log "expected_executable_sha256=$EXPECTED_EXE_SHA"
log "actual_executable_sha256=$EXE_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_SHA" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$FONTREGISTRY_BEFORE" = "$EXPECTED_FONTREGISTRY_SHA" ] || die 68 "FontRegistry baseline hash mismatch"
[ "$ATSSERVER_BEFORE" = "$EXPECTED_ATSSERVER_SHA" ] || die 68 "ATSServer baseline hash mismatch"
[ "$EXE_BEFORE" = "$EXPECTED_EXE_SHA" ] || die 68 "proof executable hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"
is_ppc32_macho "$EXE" || die 67 "proof executable is not a 32-bit PowerPC Mach-O executable"
OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq "name /usr/oah/dyld " || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"
/usr/bin/strings "$EXE" | /usr/bin/grep -Fq "PM_FONTSERVER_RENDEZVOUS_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || die 68 "build marker missing"

MARKER="$(/usr/bin/mktemp /tmp/lion-fontserver-rendezvous-policy-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
ulimit -c unlimited 2>/dev/null && log "core_dump_limit=unlimited"
log ""
log "== SINGLE PPC FONTSERVER RENDEZVOUS POLICY PROOF =="
log "+ DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 $EXE lion-policy-proof"
DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 "$EXE" lion-policy-proof > "$RAW_LOG" 2>&1
RC=$?
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "fontserver_rendezvous_policy_exec_status=$RC"

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
[ "$(sha256 "$FONTREGISTRY")" = "$FONTREGISTRY_BEFORE" ] || die 70 "FontRegistry changed"
[ "$(sha256 "$ATSSERVER")" = "$ATSSERVER_BEFORE" ] || die 70 "ATSServer changed"
[ "$(sha256 "$EXE")" = "$EXE_BEFORE" ] || die 70 "proof executable changed"
log "protected_hashes_unchanged=YES"

if [ "$RC" -eq 0 ] && [ "$FOUND" -eq 0 ] &&
   /usr/bin/grep -Fq "PM_FONTSERVER_RENDEZVOUS_COMPAT_REQUEST_POLICY:legacyId=0x000032c8 lionId=0x000032e7 send=0x00000018 legacyRecv=0x0000003c lionRecv=0x00000040 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0" "$RAW_LOG" &&
   /usr/bin/grep -Fq "PM_FONTSERVER_RENDEZVOUS_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x0000334b legacyId=0x0000332c nativeSize=0x00000038 legacySize=0x00000034 protocolVersion=5 descriptorCount=1 descriptorAddress=0x000b7000 descriptorSize=0x00001000 nativeExplicitSize=0x00001000 legacyExplicitSize=0x00001000 preservedPrefixChangedBytes=0 sourceChangedBytes=0 descriptorPreserved=YES ndrPreserved=YES explicitSizeRelocated=YES removedProtocolBytes=4" "$RAW_LOG" &&
   /usr/bin/grep -Fq "PM_FONTSERVER_RENDEZVOUS_COMPAT_ERROR_REPLY_POLICY:lionId=0x0000334b legacyId=0x0000332c size=0x00000024 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 rawResult=0xd0feffff decodedResult=-304 ndrSwapped=YES" "$RAW_LOG" &&
   /usr/bin/grep -Fq "PM_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:LION_POLICY_PROOF_PASS" "$RAW_LOG"; then
    log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_POLICY_PROOF_PASS"
    exit 0
fi

log "RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_POLICY_PROOF_UNCLASSIFIED_FAILURE rc=$RC diagnostics=$FOUND"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
