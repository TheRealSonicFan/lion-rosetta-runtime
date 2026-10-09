#!/bin/bash
set -e

PROBE="${1:-./ppc-distributed-notifications-bootstrap-probe-private-dyld}"
INTERPOSER="${2:-./ppc-distributed-notifications-bootstrap-compat-protocol.dylib}"
LOG="${3:-./ppc-distributed-notifications-bootstrap-compat-protocol-snowleopard-control.log}"

EXPECTED_PROBE_BUILD_ID="distributed-notifications-bootstrap-probe-v1"
EXPECTED_INTERPOSER_BUILD_ID="distributed-notifications-bootstrap-compat-protocol-v1"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: Snow Leopard 10.6.8 required" >&2
    exit 64
}
for file in "$PROBE" "$INTERPOSER" "$PROBE.sha256" "$INTERPOSER.sha256"; do
    [ -f "$file" ] || { echo "error: missing $file" >&2; exit 66; }
done

EXPECTED_PROBE_SHA="$(/usr/bin/awk '{print $1}' "$PROBE.sha256")"
ACTUAL_PROBE_SHA="$(/usr/bin/shasum -a 256 "$PROBE" | /usr/bin/awk '{print $1}')"
EXPECTED_INTERPOSER_SHA="$(/usr/bin/awk '{print $1}' "$INTERPOSER.sha256")"
ACTUAL_INTERPOSER_SHA="$(/usr/bin/shasum -a 256 "$INTERPOSER" | /usr/bin/awk '{print $1}')"
[ "$EXPECTED_PROBE_SHA" = "$ACTUAL_PROBE_SHA" ] || { echo "error: probe hash mismatch" >&2; exit 70; }
[ "$EXPECTED_INTERPOSER_SHA" = "$ACTUAL_INTERPOSER_SHA" ] || { echo "error: interposer hash mismatch" >&2; exit 70; }

/usr/bin/strings "$PROBE" | /usr/bin/grep -Fq "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || {
    echo "error: probe build ID mismatch" >&2
    exit 71
}
/usr/bin/strings "$INTERPOSER" | /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || {
    echo "error: interposer build ID mismatch" >&2
    exit 71
}

for envname in ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE DYLD_INSERT_LIBRARIES; do
    unset "$envname" 2>/dev/null || true
done

/bin/rm -f "$LOG"
echo "== Snow Leopard distributed-notifications bootstrap compatibility protocol control ==" | /usr/bin/tee -a "$LOG"
echo "product_version=$(/usr/bin/sw_vers -productVersion)" | /usr/bin/tee -a "$LOG"
echo "build_version=$(/usr/bin/sw_vers -buildVersion)" | /usr/bin/tee -a "$LOG"
echo "probe_sha256=$ACTUAL_PROBE_SHA" | /usr/bin/tee -a "$LOG"
echo "interposer_sha256=$ACTUAL_INTERPOSER_SHA" | /usr/bin/tee -a "$LOG"

set +e
ROSETTA_DISTRIBUTED_NOTIFICATIONS_COMPAT_MODE=passthrough DYLD_INSERT_LIBRARIES="$INTERPOSER" DYLD_SHARED_CACHE_DONT_VALIDATE=1 "$PROBE" >>"$LOG" 2>&1
RC=$?
set -e

echo "probe_exit_status=$RC" | /usr/bin/tee -a "$LOG"

if [ "$RC" -eq 0 ] &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_CALL:index=1 mode=passthrough' "$LOG" &&
   /usr/bin/grep -Fq 'name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008' "$LOG" &&
   /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:PASSTHROUGH kr=0 hex=0x00000000 servicePort=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Eq 'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_LOOKUP:kr=0 hex=0x00000000 servicePort=0x[0-9a-fA-F]*[1-9a-fA-F][0-9a-fA-F]*' "$LOG" &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_PORT_TYPE:kr=0 hex=0x00000000' "$LOG" &&
   /usr/bin/grep -Fq 'hasSend=YES' "$LOG" &&
   /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_RESULT:PASS' "$LOG" &&
   ! /usr/bin/grep -Fq 'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_PASS' "$LOG"; then
    echo "RESULT: PASS" | /usr/bin/tee -a "$LOG"
    exit 0
fi

echo "RESULT: FAIL" | /usr/bin/tee -a "$LOG"
exit 1
