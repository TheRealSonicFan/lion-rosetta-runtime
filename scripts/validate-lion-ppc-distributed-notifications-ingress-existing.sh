#!/bin/bash
set -u

REPORT="${1:-./distributed-notifications-ppc-ingress-lion.txt}"
RAW="${2:-$REPORT.raw.log}"
OUT="${3:-./distributed-notifications-ppc-ingress-lion-recovery-validation.txt}"

: > "$OUT" || exit 73

log() {
    echo "$*" | /usr/bin/tee -a "$OUT"
}

fail() {
    log "RESULT: FAIL"
    exit 1
}

log "== Lion PPC distributed-notifications ingress proof recovery validation =="
log "validation_mode=existing_artifacts_only"
log "live_proof_rerun=NO"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
log "product_version=$PRODUCT_VERSION"
[ "$PRODUCT_VERSION" = "10.7.5" ] || {
    log "validation_issue=requires Lion 10.7.5"
    fail
}

for file in "$REPORT" "$RAW"; do
    [ -f "$file" ] || {
        log "validation_issue=missing existing artifact: $file"
        fail
    }
done

PASS=1

/usr/bin/grep -Fq 'probe_exit_status=0' "$REPORT" || {
    log "missing_required_marker=probe_exit_status=0"
    PASS=0
}

/usr/bin/grep -Fq 'protected_hashes_unchanged=YES' "$REPORT" || {
    log "missing_required_marker=protected_hashes_unchanged=YES"
    PASS=0
}

for marker in \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:index=1 mode=lion-ppc-ingress-v1 name=com.apple.distributed_notifications.2 pid=0 flags=0x0000000000000008" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_READY:" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REGISTER:index=1 legacyBehavior=1 publicBehavior=4" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_POST:index=1 options=0x1 currentSession=YES sux=NO" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_CALLBACK:index=1 valid=YES" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=1" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_CALLBACK_SUMMARY:count=1 valid=YES" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_UNREGISTER:index=1" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_EXIT:register=1 post=1 callback=1 unregister=1 rejects=0" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_EXIT:lookups=1 requests=3 callbacks=1" \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_RESULT:PASS"
do
    if ! /usr/bin/grep -Fq "$marker" "$RAW"; then
        log "missing_required_marker=$marker"
        PASS=0
    fi
done

if ! /usr/bin/grep -Eq \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=1 .* result=PASS$' \
    "$RAW"; then
    log "missing_required_marker=exact Mach callback PASS line"
    PASS=0
fi

if ! /usr/bin/grep -Eq \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_WAIT:pid=[0-9]+ exit=0$' \
    "$RAW"; then
    log "missing_required_marker=broker wait exit 0"
    PASS=0
fi

REQUEST_COUNT="$(/usr/bin/grep -c \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' \
    "$RAW" 2>/dev/null || true)"
CALLBACK_COUNT="$(/usr/bin/grep -c \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:index=' \
    "$RAW" 2>/dev/null || true)"

log "legacy_mach_request_count=$REQUEST_COUNT"
log "legacy_mach_callback_count=$CALLBACK_COUNT"

[ "$REQUEST_COUNT" = "3" ] || PASS=0
[ "$CALLBACK_COUNT" = "1" ] || PASS=0

if [ "$PASS" -eq 1 ]; then
    log "RESULT: DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_PROOF_RECOVERY_PASS"
    log "RESULT: PASS"
    exit 0
fi

fail
