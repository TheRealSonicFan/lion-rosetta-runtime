#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROBE="${1:-$ROOT/payload/ppc-distributed-notifications-ingress-probe-private-dyld}"
PROBE_SHA_FILE="${2:-$PROBE.sha256}"
INTERPOSER="${3:-$ROOT/payload/ppc-distributed-notifications-ingress-interposer.dylib}"
INTERPOSER_SHA_FILE="${4:-$INTERPOSER.sha256}"
BROKER="${5:-$ROOT/native-distributed-notifications-ppc-ingress-broker}"
BROKER_SHA_FILE="${6:-$BROKER.sha256}"
REPORT="${7:-$ROOT/distributed-notifications-ppc-ingress-lion.txt}"
RAW="$REPORT.raw.log"

TRANSLATOR="/usr/libexec/oah/translate"
PRIVATE_DYLD="/usr/oah/dyld"
SYSTEM_DYLD="/usr/lib/dyld"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_CACHE_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
LIBSYSTEM="/usr/lib/libSystem.B.dylib"
COREFOUNDATION="/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
DISTNOTED="/usr/sbin/distnoted"
LAUNCHD="/sbin/launchd"
LIBXPC="/usr/lib/system/libxpc.dylib"

EXPECTED_DYLD_SHA="963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb"
EXPECTED_TRANSLATOR_SHA="4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18"
EXPECTED_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
EXPECTED_CACHE_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
EXPECTED_KERNEL_SHA="${ROSETTA_EXPECTED_KERNEL_SHA256:-}"

EXPECTED_PROBE_BUILD_ID="distributed-notifications-ppc-ingress-probe-v1"
EXPECTED_INTERPOSER_BUILD_ID="distributed-notifications-ppc-ingress-interposer-v1"
EXPECTED_BROKER_BUILD_ID="distributed-notifications-ppc-ingress-broker-v1"

mkdir -p "$(/usr/bin/dirname "$REPORT")" || exit 73
: > "$REPORT" || exit 73
: > "$RAW" || exit 73

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() { code="$1"; shift; log "ERROR: $*"; exit "$code"; }
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }

has_arch() {
    arch="$1"
    file="$2"
    /usr/bin/lipo -verify_arch "$arch" "$file" >/dev/null 2>&1 && return 0
    /usr/bin/lipo "$file" -verify_arch "$arch" >/dev/null 2>&1 && return 0
    return 1
}

log "== Lion PPC distributed-notifications ingress bridge proof =="
log "date=$(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
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

for v in     LSDONOTABORTIFNOASN     ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE     ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH     ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE     ROSETTA_CORESERVICES_COMPAT_MODE     ROSETTA_SECURITY_SESSION_API_COMPAT_MODE     ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE     ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE     ROSETTA_CPS_REGISTRATION_COMPAT_MODE     ROSETTA_CPS_SETFRONT_COMPAT_MODE     DYLD_INSERT_LIBRARIES
do
    eval "present=${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

[ -n "$EXPECTED_KERNEL_SHA" ] || die 64 "set ROSETTA_EXPECTED_KERNEL_SHA256"

for path in     /mach_kernel "$TRANSLATOR" "$PRIVATE_DYLD" "$SYSTEM_DYLD"     "$ROSETTA_CACHE" "$ROSETTA_CACHE_MAP" "$LIBSYSTEM"     "$COREFOUNDATION" "$DISTNOTED" "$LAUNCHD" "$LIBXPC"     "$PROBE" "$PROBE_SHA_FILE"     "$INTERPOSER" "$INTERPOSER_SHA_FILE"     "$BROKER" "$BROKER_SHA_FILE"
do
    [ -e "$path" ] || die 66 "missing required path: $path"
done

has_arch ppc "$PROBE" || die 67 "probe is not 32-bit PPC"
has_arch ppc "$INTERPOSER" || die 67 "interposer is not 32-bit PPC"
has_arch i386 "$BROKER" || die 67 "broker is not i386"

EXPECTED_PROBE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$PROBE_SHA_FILE")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER_SHA_FILE")"
EXPECTED_BROKER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$BROKER_SHA_FILE")"

KERNEL_BEFORE="$(sha256 /mach_kernel)"
TRANSLATOR_BEFORE="$(sha256 "$TRANSLATOR")"
PRIVATE_BEFORE="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_BEFORE="$(sha256 "$SYSTEM_DYLD")"
CACHE_BEFORE="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_BEFORE="$(sha256 "$ROSETTA_CACHE_MAP")"
LIBSYSTEM_BEFORE="$(sha256 "$LIBSYSTEM")"
CF_BEFORE="$(sha256 "$COREFOUNDATION")"
DISTNOTED_BEFORE="$(sha256 "$DISTNOTED")"
LAUNCHD_BEFORE="$(sha256 "$LAUNCHD")"
LIBXPC_BEFORE="$(sha256 "$LIBXPC")"
PROBE_BEFORE="$(sha256 "$PROBE")"
INTERPOSER_BEFORE="$(sha256 "$INTERPOSER")"
BROKER_BEFORE="$(sha256 "$BROKER")"

log "mach_kernel_sha256_before=$KERNEL_BEFORE"
log "translator_sha256_before=$TRANSLATOR_BEFORE"
log "private_dyld_sha256_before=$PRIVATE_BEFORE"
log "system_dyld_sha256_before=$SYSTEM_BEFORE"
log "rosetta_cache_sha256_before=$CACHE_BEFORE"
log "rosetta_cache_map_sha256_before=$CACHE_MAP_BEFORE"
log "libsystem_sha256_before=$LIBSYSTEM_BEFORE"
log "corefoundation_sha256_before=$CF_BEFORE"
log "distnoted_sha256_before=$DISTNOTED_BEFORE"
log "launchd_sha256_before=$LAUNCHD_BEFORE"
log "libxpc_sha256_before=$LIBXPC_BEFORE"
log "expected_probe_sha256=$EXPECTED_PROBE_SHA"
log "actual_probe_sha256=$PROBE_BEFORE"
log "expected_interposer_sha256=$EXPECTED_INTERPOSER_SHA"
log "actual_interposer_sha256=$INTERPOSER_BEFORE"
log "expected_broker_sha256=$EXPECTED_BROKER_SHA"
log "actual_broker_sha256=$BROKER_BEFORE"

[ "$KERNEL_BEFORE" = "$EXPECTED_KERNEL_SHA" ] || die 68 "kernel hash mismatch"
[ "$TRANSLATOR_BEFORE" = "$EXPECTED_TRANSLATOR_SHA" ] || die 68 "translator hash mismatch"
[ "$PRIVATE_BEFORE" = "$EXPECTED_DYLD_SHA" ] || die 68 "private dyld hash mismatch"
[ "$CACHE_BEFORE" = "$EXPECTED_CACHE_SHA" ] || die 68 "Rosetta cache hash mismatch"
[ "$CACHE_MAP_BEFORE" = "$EXPECTED_CACHE_MAP_SHA" ] || die 68 "Rosetta cache map hash mismatch"
[ "$PROBE_BEFORE" = "$EXPECTED_PROBE_SHA" ] || die 68 "probe hash mismatch"
[ "$INTERPOSER_BEFORE" = "$EXPECTED_INTERPOSER_SHA" ] || die 68 "interposer hash mismatch"
[ "$BROKER_BEFORE" = "$EXPECTED_BROKER_SHA" ] || die 68 "broker hash mismatch"

HANDLER="$(/usr/sbin/sysctl -n kern.exec.archhandler.powerpc 2>/dev/null || true)"
log "powerpc_archhandler=$HANDLER"
[ "$HANDLER" = "$TRANSLATOR" ] || die 68 "PowerPC handler mismatch"

/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || die 68 "probe build marker missing"
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || die 68 "interposer build marker missing"
/usr/bin/strings "$BROKER" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_BUILD_ID:$EXPECTED_BROKER_BUILD_ID" || die 68 "broker build marker missing"

BROKER_DIR="$(cd "$(/usr/bin/dirname "$BROKER")" && pwd)" || die 66 "cannot resolve broker directory"
BROKER_ABS="$BROKER_DIR/$(/usr/bin/basename "$BROKER")"

log ""
log "== SINGLE PPC INGRESS / NATIVE BROKER PROOF =="
log "probe=$PROBE"
log "interposer=$INTERPOSER"
log "broker=$BROKER_ABS"

set +e
ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=lion-ppc-ingress-v1 ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH="$BROKER_ABS" DYLD_INSERT_LIBRARIES="$INTERPOSER" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PROBE" > "$RAW" 2>&1
RC=$?
set -e

/bin/cat "$RAW" >> "$REPORT"
log "probe_exit_status=$RC"

KERNEL_AFTER="$(sha256 /mach_kernel)"
TRANSLATOR_AFTER="$(sha256 "$TRANSLATOR")"
PRIVATE_AFTER="$(sha256 "$PRIVATE_DYLD")"
SYSTEM_AFTER="$(sha256 "$SYSTEM_DYLD")"
CACHE_AFTER="$(sha256 "$ROSETTA_CACHE")"
CACHE_MAP_AFTER="$(sha256 "$ROSETTA_CACHE_MAP")"
LIBSYSTEM_AFTER="$(sha256 "$LIBSYSTEM")"
CF_AFTER="$(sha256 "$COREFOUNDATION")"
DISTNOTED_AFTER="$(sha256 "$DISTNOTED")"
LAUNCHD_AFTER="$(sha256 "$LAUNCHD")"
LIBXPC_AFTER="$(sha256 "$LIBXPC")"
PROBE_AFTER="$(sha256 "$PROBE")"
INTERPOSER_AFTER="$(sha256 "$INTERPOSER")"
BROKER_AFTER="$(sha256 "$BROKER")"

UNCHANGED=YES
[ "$KERNEL_AFTER" = "$KERNEL_BEFORE" ] || UNCHANGED=NO
[ "$TRANSLATOR_AFTER" = "$TRANSLATOR_BEFORE" ] || UNCHANGED=NO
[ "$PRIVATE_AFTER" = "$PRIVATE_BEFORE" ] || UNCHANGED=NO
[ "$SYSTEM_AFTER" = "$SYSTEM_BEFORE" ] || UNCHANGED=NO
[ "$CACHE_AFTER" = "$CACHE_BEFORE" ] || UNCHANGED=NO
[ "$CACHE_MAP_AFTER" = "$CACHE_MAP_BEFORE" ] || UNCHANGED=NO
[ "$LIBSYSTEM_AFTER" = "$LIBSYSTEM_BEFORE" ] || UNCHANGED=NO
[ "$CF_AFTER" = "$CF_BEFORE" ] || UNCHANGED=NO
[ "$DISTNOTED_AFTER" = "$DISTNOTED_BEFORE" ] || UNCHANGED=NO
[ "$LAUNCHD_AFTER" = "$LAUNCHD_BEFORE" ] || UNCHANGED=NO
[ "$LIBXPC_AFTER" = "$LIBXPC_BEFORE" ] || UNCHANGED=NO
[ "$PROBE_AFTER" = "$PROBE_BEFORE" ] || UNCHANGED=NO
[ "$INTERPOSER_AFTER" = "$INTERPOSER_BEFORE" ] || UNCHANGED=NO
[ "$BROKER_AFTER" = "$BROKER_BEFORE" ] || UNCHANGED=NO
log "protected_hashes_unchanged=$UNCHANGED"

PASS=1
[ "$RC" -eq 0 ] || PASS=0
[ "$UNCHANGED" = YES ] || PASS=0

for marker in     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:index=1 mode=lion-ppc-ingress-v1 name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REGISTER:index=1 legacyBehavior=1 publicBehavior=4"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_POST:index=1 options=0x1 currentSession=YES sux=NO"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_CALLBACK:index=1 valid=YES"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=1"     "result=PASS"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_CALLBACK_SUMMARY:count=1 valid=YES"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_UNREGISTER:index=1"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_EXIT:register=1 post=1 callback=1 unregister=1 rejects=0"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:"     "exit=0"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=3 callbacks=1"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:PASS"
do
    if ! /usr/bin/grep -Fq "$marker" "$RAW"; then
        log "missing_required_marker=$marker"
        PASS=0
    fi
done

if ! /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=1 .* result=PASSCALLBACK_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=' "$RAW" 2>/dev/null || true)"
log "legacy_mach_request_count=$REQUEST_COUNT"
log "legacy_mach_callback_count=$CALLBACK_COUNT"

[ "$REQUEST_COUNT" = "3" ] || PASS=0
[ "$CALLBACK_COUNT" = "1" ] || PASS=0

if [ "$PASS" -eq 1 ]; then
    log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_PASS"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_FAIL"
log "RESULT: FAIL"
exit 1
 "$RAW"; then
    log "missing_required_marker=exact Mach callback PASS line"
    PASS=0
fi

if ! /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:pid=[0-9]+ exit=0CALLBACK_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=' "$RAW" 2>/dev/null || true)"
log "legacy_mach_request_count=$REQUEST_COUNT"
log "legacy_mach_callback_count=$CALLBACK_COUNT"

[ "$REQUEST_COUNT" = "3" ] || PASS=0
[ "$CALLBACK_COUNT" = "1" ] || PASS=0

if [ "$PASS" -eq 1 ]; then
    log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_PASS"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_FAIL"
log "RESULT: FAIL"
exit 1
 "$RAW"; then
    log "missing_required_marker=broker wait exit 0"
    PASS=0
fi

REQUEST_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' "$RAW" 2>/dev/null || true)"
CALLBACK_COUNT="$(/usr/bin/grep -c 'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=' "$RAW" 2>/dev/null || true)"
log "legacy_mach_request_count=$REQUEST_COUNT"
log "legacy_mach_callback_count=$CALLBACK_COUNT"

[ "$REQUEST_COUNT" = "3" ] || PASS=0
[ "$CALLBACK_COUNT" = "1" ] || PASS=0

if [ "$PASS" -eq 1 ]; then
    log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_PASS"
    log "RESULT: PASS"
    exit 0
fi

log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_FAIL"
log "RESULT: FAIL"
exit 1
