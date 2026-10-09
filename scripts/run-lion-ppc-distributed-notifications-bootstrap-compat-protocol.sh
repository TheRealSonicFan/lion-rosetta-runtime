#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="${1:-$ROOT/payload/ppc-distributed-notifications-bootstrap-probe-private-dyld}"
PROBE_SHA_FILE="${2:-$PROBE.sha256}"
INTERPOSER="${3:-$ROOT/payload/ppc-distributed-notifications-bootstrap-compat-protocol.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
REPORT="${5:-$ROOT/payload/lion-ppc-distributed-notifications-bootstrap-compat-protocol.log}"
REPORT_DIR="$(/usr/bin/dirname "$REPORT")"
RAW_LOG="$REPORT_DIR/lion-ppc-distributed-notifications-bootstrap-compat-protocol.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
LIBSYSTEM="/usr/lib/libSystem.B.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_PROBE_BUILD_ID="distributed-notifications-bootstrap-probe-v1"
EXPECTED_INTERPOSER_BUILD_ID="distributed-notifications-bootstrap-compat-protocol-v1"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

mkdir -p "$REPORT_DIR" || exit 73
: > "$REPORT" || exit 73
: > "$RAW_LOG" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() { code="$1"; shift; log "ERROR: $*"; exit "$code"; }
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

log "== Lion PPC distributed-notifications bootstrap compatibility protocol proof =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
log "host=$(/bin/hostname)"
PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"

CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || die 65 "run from the logged-in Aqua console user's Terminal session"

for v in LSDONOTABORTIFNOASN ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE          ROSETTA_CORESERVICES_COMPAT_MODE ROSETTA_SECURITY_SESSION_API_COMPAT_MODE          ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE          ROSETTA_CPS_REGISTRATION_COMPAT_MODE ROSETTA_CPS_SETFRONT_COMPAT_MODE          DYLD_INSERT_LIBRARIES; do
    eval "present=${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"
for p in /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD"          "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$LIBSYSTEM"          "$PROBE" "$PROBE_SHA_FILE" "$INTERPOSER" "$INTERPOSER_SHA_FILE"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

EXPECTED_PROBE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$PROBE_SHA_FILE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"
KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"
LIBSYSTEM_BEFORE="$(sha256 "$LIBSYSTEM")"
PROBE_BEFORE="$(sha256 "$PROBE")"
INTERPOSER_BEFORE="$(sha256 "$INTERPOSER")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256_before=$CACHE_MAP_BEFORE"
log "libsystem_sha256_before=$LIBSYSTEM_BEFORE"
log "expected_probe_sha256=$EXPECTED_PROBE_SHA"
log "actual_probe_sha256=$PROBE_BEFORE"
log "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA"
log "actual_interposer_sha256=$INTERPOSER_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_BEFORE" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$PROBE_BEFORE" = "$EXPECTED_PROBE_SHA" ] || die 68 "probe hash mismatch"
[ "$INTERPOSER_BEFORE" = "$EXPECTED_INTERPOSER_SHA" ] || die 68 "interposer hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"
has_ppc32_arch "$PROBE" || die 67 "probe is not 32-bit PPC"
has_ppc32_arch "$INTERPOSER" || die 67 "interposer is not 32-bit PPC"

/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || die 68 "probe build marker missing"
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || die 68 "interposer build marker missing"

log ""
log "== SINGLE PPC DISTRIBUTED-NOTIFICATIONS LOOKUP PROOF =="
log "+ ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE=lion-lookup-v1 DYLD_INSERT_LIBRARIES=$INTERPOSER DYLD_SHARED_CACHE_DONT_VALIDATE=1 $PROBE"
set +e
ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE=lion-lookup-v1 DYLD_INSERT_LIBRARIES="$INTERPOSER" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PROBE" >"$RAW_LOG" 2>&1
RC=$?
set -e
/bin/cat "$RAW_LOG" >> "$REPORT"
log "probe_exit_status=$RC"

KERNEL_AFTER="$(sha256 /mach_kernel)"
TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"
PRIVATE_AFTER="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_AFTER="$(sha256 "$SYSTEM_DYLD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_AFTER="$(sha256 "$ROSETTA_CACHE_MAP")"
LIBSYSTEM_AFTER="$(sha256 "$LIBSYSTEM")"
PROBE_AFTER="$(sha256 "$PROBE")"
INTERPOSER_AFTER="$(sha256 "$INTERPOSER")"

UNCHANGED=YES
[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || UNCHANGED=NO
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || UNCHANGED=NO
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || UNCHANGED=NO
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || UNCHANGED=NO
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || UNCHANGED=NO
[ "$CACHE_MAP_AFTER" = "$CACHE_MAP_BEFORE" ] || UNCHANGED=NO
[ "$LIBSYSTEM_AFTER" = "$LIBSYSTEM_BEFORE" ] || UNCHANGED=NO
[ "$PROBE_AFTER" = "$PROBE_BEFORE" ] || UNCHANGED=NO
[ "$INTERPOSER_AFTER" = "$INTERPOSER_BEFORE" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"

if [ "$RC" -eq 0 ] &&
   [ "$UNCHANGED" = "YES" ] &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_CALL:index=1 mode=lion-lookup-v1' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_REQUEST:' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'id=0x00000194 send=0x000000bc recv=0x0000006c pid=0 uuid=ZERO flags=0x0000000000000008' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_MACH_MSG:kr=0 hex=0x00000000' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:LOOKUP_PASS' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_PASS kr=0 hex=0x00000000 servicePort=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" &&
   /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_LOOKUP:kr=0 hex=0x00000000 servicePort=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'hasSend=YES' "$RAW_LOG" &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_RESULT:PASS' "$RAW_LOG"; then
    log "RESULT: DISTRIBUTED_NOTIFICATIONS_COMPAT_POLICY_PROOF_PASS"
    exit 0
fi

if /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_FAILED' "$RAW_LOG"; then
    log "RESULT: DISTRIBUTED_NOTIFICATIONS_COMPAT_ADAPTER_FAILED"
    exit 0
fi

log "RESULT: DISTRIBUTED_NOTIFICATIONS_COMPAT_POLICY_PROOF_FAILED rc=$RC"
exit 0
