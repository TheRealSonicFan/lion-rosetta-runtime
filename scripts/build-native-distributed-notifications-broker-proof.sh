#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="$ROOT/tests/native-distributed-notifications-broker-proof.c"
OUT="${1:-./native-distributed-notifications-broker-proof}"
EXPECTED_BUILD_ID="distributed-notifications-native-broker-proof-v1"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
case "$PRODUCT_VERSION" in
    10.6.8)
        MIN_VERSION=10.6
        ;;
    10.7.5)
        MIN_VERSION=10.7
        ;;
    *)
        echo "error: build only on Snow Leopard 10.6.8 or Lion 10.7.5" >&2
        exit 65
        ;;
esac

if [ -n "${CC:-}" ]; then
    CC_SELECTED="$CC"
elif [ -x /usr/bin/clang ]; then
    CC_SELECTED=/usr/bin/clang
elif [ -x /Developer/usr/bin/clang ]; then
    CC_SELECTED=/Developer/usr/bin/clang
elif [ -x /usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/usr/bin/gcc-4.2
elif [ -x /Developer/usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/Developer/usr/bin/gcc-4.2
else
    echo "error: no supported compiler found" >&2
    exit 69
fi

[ -x "$CC_SELECTED" ] || {
    echo "error: compiler is not executable: $CC_SELECTED" >&2
    exit 69
}
[ -f "$SRC" ] || {
    echo "error: missing source: $SRC" >&2
    exit 66
}

/bin/rm -f "$OUT"

"$CC_SELECTED" -arch i386 -std=gnu99 -Wall -Wextra \
    -mmacosx-version-min="$MIN_VERSION" \
    "$SRC" \
    -framework CoreFoundation \
    -o "$OUT"

/bin/chmod 755 "$OUT"

if /usr/bin/lipo -verify_arch i386 "$OUT" >/dev/null 2>&1; then
    :
elif /usr/bin/lipo "$OUT" -verify_arch i386 >/dev/null 2>&1; then
    :
else
    echo "error: proof binary is not i386" >&2
    /usr/bin/file "$OUT" >&2 || true
    exit 70
fi

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_BROKER_PROOF_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: proof build marker missing" >&2
    exit 71
}

for symbol in \
    _CFNotificationCenterGetDistributedCenter \
    _CFNotificationCenterAddObserver \
    _CFNotificationCenterPostNotificationWithOptions \
    _CFNotificationCenterRemoveObserver
do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Fq "$symbol" || {
        echo "error: required CoreFoundation import missing: $symbol" >&2
        exit 72
    }
done

echo "Built: $OUT"
echo "product_version=$PRODUCT_VERSION"
echo "compiler=$CC_SELECTED"
/usr/bin/file "$OUT"
/usr/bin/otool -L "$OUT"
/usr/bin/shasum -a 256 "$OUT"
