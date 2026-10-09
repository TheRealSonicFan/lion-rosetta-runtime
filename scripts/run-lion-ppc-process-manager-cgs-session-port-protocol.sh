#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXE="${1:-$ROOT/payload/ppc-process-manager-cgs-session-port-protocol-private-dyld}"
SHA_FILE="${2:-$EXE.sha256}"
REPORT="${3:-$ROOT/payload/lion-ppc-process-manager-cgs-session-port-protocol.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-process-manager-cgs-session-port-protocol.raw.log"

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
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() {
    code="$1"
    shift
    log "ERROR: $*"
    log "Preflight stopped; preserve the report before changing anything."
    exit "$code"
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
has_ppc32_arch() {
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

log "== Lion PPC CGS session-port native-protocol probe =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

[ -z "${DYLD_INSERT_LIBRARIES+x}" ] || die 68 "DYLD_INSERT_LIBRARIES must be unset"
log "DYLD_INSERT_LIBRARIES=UNSET_IN_PARENT"

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256 to the validated syscall-295 kernel hash"

for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD" "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$COREGRAPHICS" "$EXE" "$SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_EXE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$SHA_FILE")"
[ -n "$EXPECTED_EXE_SHA" ] || die 68 "could not read expected executable SHA-256"

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
log "lion_system_dyld_sha256_before=$SYSTEM_BEFORE"
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

has_ppc32_arch "$EXE" || die 67 "probe is not a 32-bit PowerPC Mach-O"

OT="$(/usr/bin/otool -l "$EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/tee -a "$REPORT"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || die 68 "LC_LOAD_DYLINKER is not /usr/oah/dyld"

/usr/bin/strings "$EXE" | /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_BUILD_ID:cgs-session-port-protocol-v3' || die 68 "build marker missing"
/usr/bin/grep -Fq "$COREGRAPHICS" "$ROSETTA_CACHE_MAP" || die 68 "CoreGraphics absent from Rosetta cache map"

log ""
log "== WindowServer state before test =="
/bin/ps -axww -o pid=,uid=,command= 2>&1 | /usr/bin/grep '[W]indowServer' | /usr/bin/tee -a "$REPORT" || die 68 "WindowServer is not running"

MARKER="$(/usr/bin/mktemp /tmp/lion-cgs-session-port-marker.XXXXXX)" || die 73 "could not create diagnostic marker"
if ulimit -c unlimited 2>/dev/null; then
    log "core_dump_limit=unlimited"
fi

log ""
log "== SINGLE PPC LION NATIVE-SESSION PORT PROTOCOL TEST =="
log "+ DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 $EXE lion-native-session"
DYLD_SHARED_CACHE_DONT_VALIDATE=1 DYLD_PRINT_LIBRARIES=1 "$EXE" lion-native-session > "$RAW_LOG" 2>&1
RC=$?
/bin/cat "$RAW_LOG" | /usr/bin/tee -a "$REPORT"
log "cgs_session_port_exec_status=$RC"

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
[ "$(sha256 "$SYSTEM_DYLD")" = "$SYSTEM_BEFORE" ] || die 70 "Lion native dyld changed"
[ "$(sha256 "$ROSETTA_CACHE")" = "$CACHE_BEFORE" ] || die 70 "Rosetta cache changed"
[ "$(sha256 "$COREGRAPHICS")" = "$CG_BEFORE" ] || die 70 "CoreGraphics changed"
[ "$(sha256 "$EXE")" = "$EXE_BEFORE" ] || die 70 "probe executable changed"
log "protected_hashes_unchanged=YES"

log ""
if /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_MILESTONE:L00_BEFORE_ROOT_LOOKUP' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_MILESTONE:L01_AFTER_ROOT_LOOKUP' "$RAW_LOG"; then
    log "RESULT: ROOT_LOOKUP_ABORT_OR_CRASH"; exit 1
fi
if /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_MILESTONE:L02_BEFORE_GETSESSIONPORT' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_MILESTONE:L03_AFTER_GETSESSIONPORT' "$RAW_LOG"; then
    log "RESULT: GETSESSIONPORT_ABORT_OR_CRASH"; exit 1
fi
if /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_MILESTONE:L04_BEFORE_DEATHWATCH' "$RAW_LOG" &&
   ! /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_MILESTONE:L05_AFTER_DEATHWATCH' "$RAW_LOG"; then
    log "RESULT: DEATHWATCH_ABORT_OR_CRASH"; exit 1
fi

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_LAYOUT:PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_ROOT_LOOKUP_RESULT:PASS' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'flags=0x0000000000000008' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'serverEuid=0' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_GETSESSIONPORT_MACH_RETURN:kr=0 ' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_GETSESSIONPORT_REPLY:' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_CGS_SESSION_PORT_GETSESSIONPORT_COMPLEX_REPLY:descriptor_count=1 .* disposition=0x11 type=0x00' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_DEATHWATCH_MACH_RETURN:kr=0 ' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_CGS_SESSION_PORT_DEATHWATCH_COMPLEX_REPLY:descriptor_count=1 .* disposition=0x11 type=0x00' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CGS_SESSION_PORT_RESULT:LION_NATIVE_SESSION_PROTOCOL_PASS' "$RAW_LOG"; then
    log "RESULT: CGS_SESSION_PORT_PROTOCOL_ADAPTER_PASS"
    exit 0
fi

log "RESULT: CGS_SESSION_PORT_PROTOCOL_UNCLASSIFIED_FAILURE"
[ "$RC" -ne 0 ] && exit "$RC"
exit 1
