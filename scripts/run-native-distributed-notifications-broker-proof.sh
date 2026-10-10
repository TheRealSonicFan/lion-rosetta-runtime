#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROOF="${1:-$ROOT/native-distributed-notifications-broker-proof}"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD_VERSION="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"

case "$PRODUCT_VERSION" in
    10.6.8)
        DEFAULT_REPORT="$ROOT/distributed-notifications-native-broker-proof-snowleopard.txt"
        ;;
    10.7.5)
        DEFAULT_REPORT="$ROOT/distributed-notifications-native-broker-proof-lion.txt"
        ;;
    *)
        echo "error: run only on Snow Leopard 10.6.8 or Lion 10.7.5" >&2
        exit 65
        ;;
esac

REPORT="${2:-$DEFAULT_REPORT}"
TMPDIR_PROOF="$(/usr/bin/mktemp -d /tmp/distnotify-broker-proof.XXXXXX)"
RAW="$TMPDIR_PROOF/raw.log"
BEFORE="$TMPDIR_PROOF/before.sha256"
AFTER="$TMPDIR_PROOF/after.sha256"

cleanup() {
    /bin/rm -rf "$TMPDIR_PROOF"
}
trap cleanup EXIT HUP INT TERM

[ -x "$PROOF" ] || {
    echo "error: missing executable proof: $PROOF" >&2
    exit 66
}

if /usr/bin/lipo -verify_arch i386 "$PROOF" >/dev/null 2>&1; then
    :
elif /usr/bin/lipo "$PROOF" -verify_arch i386 >/dev/null 2>&1; then
    :
else
    echo "error: proof is not i386: $PROOF" >&2
    exit 70
fi

/usr/bin/strings "$PROOF" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_BUILD_ID:distributed-notifications-native-broker-proof-v1" || {
    echo "error: proof build marker missing" >&2
    exit 71
}

HASH_PATHS="/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation /usr/sbin/distnoted /sbin/launchd"
if [ -f /usr/lib/system/libxpc.dylib ]; then
    HASH_PATHS="$HASH_PATHS /usr/lib/system/libxpc.dylib"
fi

: > "$BEFORE"
for path in $HASH_PATHS; do
    if [ -f "$path" ]; then
        /usr/bin/shasum -a 256 "$path" >> "$BEFORE"
    fi
done

unset DYLD_INSERT_LIBRARIES
unset DYLD_LIBRARY_PATH
unset DYLD_FRAMEWORK_PATH

set +e
"$PROOF" > "$RAW" 2>&1
STATUS=$?
set -e

: > "$AFTER"
for path in $HASH_PATHS; do
    if [ -f "$path" ]; then
        /usr/bin/shasum -a 256 "$path" >> "$AFTER"
    fi
done

HASH_STATUS=PASS
if ! /usr/bin/cmp -s "$BEFORE" "$AFTER"; then
    HASH_STATUS=FAIL
fi

{
    echo "== Distributed notifications native broker proof =="
    echo "proof_version=1"
    echo "product_version=$PRODUCT_VERSION"
    echo "build_version=$BUILD_VERSION"
    echo "proof_arch=i386"
    echo "translation_boundary=synthetic Snow-v2 dictionary -> native public CFNotificationCenter API"
    echo "raw_private_xpc_synthesis=NO"
    echo "ppc_subject_launched=NO"
    echo "create_new_window_called=NO"
    echo "proof_sha256=$(/usr/bin/shasum -a 256 "$PROOF" | /usr/bin/awk '{print $1}')"
    echo
    echo "== Proof output =="
    /bin/cat "$RAW"
    echo
    echo "== Protected hashes before =="
    /bin/cat "$BEFORE"
    echo
    echo "== Protected hashes after =="
    /bin/cat "$AFTER"
    echo "protected_hashes_unchanged=$HASH_STATUS"
    echo "proof_exit_status=$STATUS"
} > "$REPORT"

PASS=1
[ "$STATUS" -eq 0 ] || PASS=0
[ "$HASH_STATUS" = PASS ] || PASS=0

for marker in \
    "enum_contract=PASS" \
    "negative_controls=PASS" \
    "negative_api_call_count=0" \
    "register_translation=PASS" \
    "poster_result=PASS" \
    "post_translation=PASS" \
    "callback_translation=PASS" \
    "callback_count=1" \
    "callback_valid=YES" \
    "unregister_translation=PASS" \
    "RESULT: DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_PASS"
do
    if ! /usr/bin/grep -Fq "$marker" "$RAW"; then
        echo "missing_required_marker=$marker" >> "$REPORT"
        PASS=0
    fi
done

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
