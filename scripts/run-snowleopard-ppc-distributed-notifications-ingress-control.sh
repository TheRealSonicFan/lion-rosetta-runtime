#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROBE="${1:-$ROOT/ppc-distributed-notifications-ingress-probe-private-dyld}"
INTERPOSER="${2:-$ROOT/ppc-distributed-notifications-ingress-interposer.dylib}"
REPORT="${3:-$ROOT/distributed-notifications-ppc-ingress-snowleopard-control.txt}"
RAW="$REPORT.raw.log"

EXPECTED_PROBE_BUILD_ID="distributed-notifications-ppc-ingress-probe-v1"
EXPECTED_INTERPOSER_BUILD_ID="distributed-notifications-ppc-ingress-interposer-v1"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: Snow Leopard 10.6.8 required" >&2
    exit 65
}

for file in "$PROBE" "$PROBE.sha256" "$INTERPOSER" "$INTERPOSER.sha256"; do
    [ -f "$file" ] || {
        echo "error: missing $file" >&2
        exit 66
    }
done

EXPECTED_PROBE_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$PROBE.sha256")"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk 'NR==1 {print $1}' "$INTERPOSER.sha256")"
ACTUAL_PROBE_SHA="$(/usr/bin/shasum -a 256 "$PROBE" | /usr/bin/awk '{print $1}')"
ACTUAL_INTERPOSER_SHA="$(/usr/bin/shasum -a 256 "$INTERPOSER" | /usr/bin/awk '{print $1}')"

[ "$EXPECTED_PROBE_SHA" = "$ACTUAL_PROBE_SHA" ] || {
    echo "error: probe hash mismatch" >&2
    exit 68
}
[ "$EXPECTED_INTERPOSER_SHA" = "$ACTUAL_INTERPOSER_SHA" ] || {
    echo "error: interposer hash mismatch" >&2
    exit 68
}

/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || {
    echo "error: probe build marker missing" >&2
    exit 71
}
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || {
    echo "error: interposer build marker missing" >&2
    exit 71
}

TMPDIR_PROOF="$(/usr/bin/mktemp -d /tmp/distnotify-ppc-ingress-snow.XXXXXX)"
BEFORE="$TMPDIR_PROOF/before.sha256"
AFTER="$TMPDIR_PROOF/after.sha256"

cleanup() {
    /bin/rm -rf "$TMPDIR_PROOF"
}
trap cleanup EXIT HUP INT TERM

HASH_PATHS="/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation /usr/sbin/distnoted /sbin/launchd /usr/oah/dyld /usr/lib/libSystem.B.dylib $PROBE $INTERPOSER"

: > "$BEFORE"
for path in $HASH_PATHS; do
    [ -f "$path" ] && /usr/bin/shasum -a 256 "$path" >> "$BEFORE"
done

for v in     ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE     ROSETTA_DISTRIBUTED_NOTIFICATIONS_BROKER_PATH     DYLD_INSERT_LIBRARIES
do
    unset "$v" 2>/dev/null || true
done

/bin/rm -f "$REPORT" "$RAW"

set +e
ROSETTA_DISTRIBUTED_NOTIFICATIONS_INGRESS_MODE=passthrough DYLD_INSERT_LIBRARIES="$INTERPOSER" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PROBE" > "$RAW" 2>&1
RC=$?
set -e

: > "$AFTER"
for path in $HASH_PATHS; do
    [ -f "$path" ] && /usr/bin/shasum -a 256 "$path" >> "$AFTER"
done

UNCHANGED=YES
/usr/bin/cmp -s "$BEFORE" "$AFTER" || UNCHANGED=NO

{
    echo "== Snow Leopard PPC distributed-notifications ingress control =="
    echo "proof_version=1"
    echo "product_version=$(/usr/bin/sw_vers -productVersion)"
    echo "build_version=$(/usr/bin/sw_vers -buildVersion)"
    echo "probe_arch=ppc"
    echo "mode=passthrough"
    echo "probe_sha256=$ACTUAL_PROBE_SHA"
    echo "interposer_sha256=$ACTUAL_INTERPOSER_SHA"
    echo
    echo "== Raw output =="
    /bin/cat "$RAW"
    echo
    echo "== Protected hashes before =="
    /bin/cat "$BEFORE"
    echo
    echo "== Protected hashes after =="
    /bin/cat "$AFTER"
    echo "protected_hashes_unchanged=$UNCHANGED"
    echo "probe_exit_status=$RC"
} > "$REPORT"

PASS=1
[ "$RC" -eq 0 ] || PASS=0
[ "$UNCHANGED" = YES ] || PASS=0

for marker in     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:index=1 mode=passthrough name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:PASSTHROUGH kr=0 hex=0x00000000"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_REGISTER:behavior=4"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_POST:options=0x1"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_CALLBACK_SUMMARY:count=1 valid=YES"     "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:PASS"
do
    if ! /usr/bin/grep -Fq "$marker" "$RAW"; then
        echo "missing_required_marker=$marker" >> "$REPORT"
        PASS=0
    fi
done

if /usr/bin/grep -Fq "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:" "$RAW"; then
    echo "unexpected_bridge_start=YES" >> "$REPORT"
    PASS=0
fi

if [ "$PASS" -eq 1 ]; then
    echo "RESULT: PASS" >> "$REPORT"
    echo "Created: $REPORT"
    echo "RESULT: PASS"
    exit 0
fi

echo "RESULT: FAIL" >> "$REPORT"
echo "Created: $REPORT"
echo "RESULT: FAIL"
exit 1
