#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROBE="${1:-$ROOT/native-distributed-notifications-service-selection-probe}"
INTERPOSER="${2:-$ROOT/native-distributed-notifications-xpc-trace.dylib}"
REPORT="${3:-$ROOT/distributed-notifications-native-service-selection-lion.txt}"

COREFOUNDATION="/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation"
FOUNDATION="/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation"
DISTNOTED="/usr/sbin/distnoted"

EXPECTED_PROBE_BUILD_ID="distributed-notifications-native-service-selection-probe-v1"
EXPECTED_TRACE_BUILD_ID="distributed-notifications-native-xpc-trace-v1"

TMP_CF="$REPORT.cf.tmp"
TMP_FOUNDATION="$REPORT.foundation.tmp"

/bin/rm -f "$REPORT" "$TMP_CF" "$TMP_FOUNDATION"

log() { echo "$*" | /usr/bin/tee -a "$REPORT"; }
die() {
    code="$1"
    shift
    log "ERROR: $*"
    /bin/rm -f "$TMP_CF" "$TMP_FOUNDATION"
    exit "$code"
}
sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
distnoted_snapshot() {
    /bin/ps -axo pid=,uid=,command= | /usr/bin/awk '
        $3 == "/usr/sbin/distnoted" {
            line = $1 ":" $2 ":" $3
            for (i = 4; i <= NF; i++)
                line = line " " $i
            print line
        }' | /usr/bin/sort
}

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
CURRENT_USER="$(/usr/bin/id -un 2>/dev/null || true)"
CONSOLE_USER="$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)"

log "== Lion native distributed-notifications service-selection trace =="
log "product_version=$PRODUCT_VERSION"
log "build_version=$BUILD_VERSION"
log "current_user=$CURRENT_USER"
log "console_user=$CONSOLE_USER"

[ "$PRODUCT_VERSION" = "10.7.5" ] || die 65 "requires Lion 10.7.5"
[ "$CURRENT_USER" = "$CONSOLE_USER" ] || die 65 "run from the logged-in Aqua console user's Terminal session"

for v in DYLD_INSERT_LIBRARIES DYLD_FORCE_FLAT_NAMESPACE PM_DISTNOTIFY_PROBE_MODE; do
    eval "present=\${$v+x}"
    [ -z "$present" ] || die 68 "$v must be unset before the runner"
done

for p in "$PROBE" "$INTERPOSER" "$COREFOUNDATION" "$FOUNDATION" "$DISTNOTED"; do
    [ -e "$p" ] || die 66 "missing required path: $p"
done

/usr/bin/lipo -verify_arch i386 "$PROBE" >/dev/null 2>&1 || \
/usr/bin/lipo "$PROBE" -verify_arch i386 >/dev/null 2>&1 || \
    die 67 "probe is not i386"

/usr/bin/lipo -verify_arch i386 "$INTERPOSER" >/dev/null 2>&1 || \
/usr/bin/lipo "$INTERPOSER" -verify_arch i386 >/dev/null 2>&1 || \
    die 67 "interposer is not i386"

/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || \
    die 68 "probe build marker missing"

/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_TRACE_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" || \
    die 68 "trace build marker missing"

PROBE_SHA_BEFORE="$(sha256 "$PROBE")"
INTERPOSER_SHA_BEFORE="$(sha256 "$INTERPOSER")"
CF_SHA_BEFORE="$(sha256 "$COREFOUNDATION")"
FOUNDATION_SHA_BEFORE="$(sha256 "$FOUNDATION")"
DISTNOTED_SHA_BEFORE="$(sha256 "$DISTNOTED")"
DISTNOTED_PROCESSES_BEFORE="$(distnoted_snapshot)"

[ -n "$DISTNOTED_PROCESSES_BEFORE" ] || die 69 "no active distnoted process found; do not use this trace to launch it"
echo "$DISTNOTED_PROCESSES_BEFORE" | /usr/bin/grep -Fq " daemon" || die 69 "distnoted daemon is not already active"
echo "$DISTNOTED_PROCESSES_BEFORE" | /usr/bin/grep -Fq " agent" || die 69 "distnoted agent is not already active"

log "probe_sha256=$PROBE_SHA_BEFORE"
log "interposer_sha256=$INTERPOSER_SHA_BEFORE"
log "corefoundation_sha256_before=$CF_SHA_BEFORE"
log "foundation_sha256_before=$FOUNDATION_SHA_BEFORE"
log "distnoted_sha256_before=$DISTNOTED_SHA_BEFORE"
log "distnoted_processes_before=$DISTNOTED_PROCESSES_BEFORE"

log ""
log "== CFNotificationCenterGetDistributedCenter =="
/usr/bin/env \
    PM_DISTNOTIFY_PROBE_MODE=CF \
    DYLD_INSERT_LIBRARIES="$INTERPOSER" \
    "$PROBE" cf >"$TMP_CF" 2>&1
CF_RC=$?
/bin/cat "$TMP_CF" | /usr/bin/tee -a "$REPORT"
log "cf_exit_status=$CF_RC"
[ "$CF_RC" -eq 0 ] || die 80 "native CF probe failed"

log ""
log "== NSDistributedNotificationCenter defaultCenter =="
/usr/bin/env \
    PM_DISTNOTIFY_PROBE_MODE=FOUNDATION \
    DYLD_INSERT_LIBRARIES="$INTERPOSER" \
    "$PROBE" foundation >"$TMP_FOUNDATION" 2>&1
FOUNDATION_RC=$?
/bin/cat "$TMP_FOUNDATION" | /usr/bin/tee -a "$REPORT"
log "foundation_exit_status=$FOUNDATION_RC"
[ "$FOUNDATION_RC" -eq 0 ] || die 81 "native Foundation probe failed"

CF_NAMES="$(/usr/bin/grep '^PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_CREATE:mode=CF name=' "$TMP_CF" 2>/dev/null | \
    /usr/bin/sed 's/^.* name=//' | /usr/bin/sort -u)"
FOUNDATION_NAMES="$(/usr/bin/grep '^PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_CREATE:mode=FOUNDATION name=' "$TMP_FOUNDATION" 2>/dev/null | \
    /usr/bin/sed 's/^.* name=//' | /usr/bin/sort -u)"

CF_NAME_COUNT="$(echo "$CF_NAMES" | /usr/bin/sed '/^$/d' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
FOUNDATION_NAME_COUNT="$(echo "$FOUNDATION_NAMES" | /usr/bin/sed '/^$/d' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"

log ""
log "== Selection result =="
log "cf_distinct_service_count=$CF_NAME_COUNT"
log "foundation_distinct_service_count=$FOUNDATION_NAME_COUNT"
log "cf_services=$CF_NAMES"
log "foundation_services=$FOUNDATION_NAMES"

[ "$CF_NAME_COUNT" = "1" ] || die 82 "CF mode did not select exactly one distributed-notifications XPC service"
[ "$FOUNDATION_NAME_COUNT" = "1" ] || die 83 "Foundation mode did not select exactly one distributed-notifications XPC service"
[ "$CF_NAMES" = "$FOUNDATION_NAMES" ] || die 84 "CF and Foundation selected different services"

case "$CF_NAMES" in
    com.apple.distributed_notifications@Uv3|com.apple.distributed_notifications@1v3)
        ;;
    *)
        die 85 "unexpected Lion distributed-notifications service: $CF_NAMES"
        ;;
esac

PROBE_SHA_AFTER="$(sha256 "$PROBE")"
INTERPOSER_SHA_AFTER="$(sha256 "$INTERPOSER")"
CF_SHA_AFTER="$(sha256 "$COREFOUNDATION")"
FOUNDATION_SHA_AFTER="$(sha256 "$FOUNDATION")"
DISTNOTED_SHA_AFTER="$(sha256 "$DISTNOTED")"
DISTNOTED_PROCESSES_AFTER="$(distnoted_snapshot)"

log "selected_service=$CF_NAMES"
log "corefoundation_sha256_after=$CF_SHA_AFTER"
log "foundation_sha256_after=$FOUNDATION_SHA_AFTER"
log "distnoted_sha256_after=$DISTNOTED_SHA_AFTER"
log "distnoted_processes_after=$DISTNOTED_PROCESSES_AFTER"

[ "$PROBE_SHA_BEFORE" = "$PROBE_SHA_AFTER" ] || die 86 "probe changed during run"
[ "$INTERPOSER_SHA_BEFORE" = "$INTERPOSER_SHA_AFTER" ] || die 86 "interposer changed during run"
[ "$CF_SHA_BEFORE" = "$CF_SHA_AFTER" ] || die 86 "CoreFoundation changed during run"
[ "$FOUNDATION_SHA_BEFORE" = "$FOUNDATION_SHA_AFTER" ] || die 86 "Foundation changed during run"
[ "$DISTNOTED_SHA_BEFORE" = "$DISTNOTED_SHA_AFTER" ] || die 86 "distnoted changed during run"
[ "$DISTNOTED_PROCESSES_BEFORE" = "$DISTNOTED_PROCESSES_AFTER" ] || die 87 "distnoted process set changed during run"

/bin/rm -f "$TMP_CF" "$TMP_FOUNDATION"

log "RESULT: PASS"
log ""
log "No PowerPC application was launched by this experiment."
log "No notification was posted, registered, removed, or delivered intentionally."
log "The trace interposer forwarded xpc_connection_create unchanged and logged only distributed-notification service names."
log "No launchd or distnoted process was started, stopped, restarted, signaled, or modified."
log "No framework, executable, launchd plist, Rosetta component, cache, or kernel was modified."
