#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROBE_SRC="$ROOT/tests/native-distributed-notifications-service-selection-probe.m"
INTERPOSER_SRC="$ROOT/tests/native-distributed-notifications-xpc-trace-interposer.c"

PROBE_OUT="${1:-./native-distributed-notifications-service-selection-probe}"
INTERPOSER_OUT="${2:-./native-distributed-notifications-xpc-trace.dylib}"

EXPECTED_PROBE_BUILD_ID="distributed-notifications-native-service-selection-probe-v1"
EXPECTED_TRACE_BUILD_ID="distributed-notifications-native-xpc-trace-v1"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
[ "$PRODUCT_VERSION" = "10.7.5" ] || {
    echo "error: build this experiment on Lion 10.7.5" >&2
    exit 65
}

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
    echo "error: no supported Lion compiler found" >&2
    exit 69
fi

[ -x "$CC_SELECTED" ] || {
    echo "error: compiler is not executable: $CC_SELECTED" >&2
    exit 69
}
[ -f "$PROBE_SRC" ] || { echo "error: missing $PROBE_SRC" >&2; exit 66; }
[ -f "$INTERPOSER_SRC" ] || { echo "error: missing $INTERPOSER_SRC" >&2; exit 66; }

/bin/rm -f "$PROBE_OUT" "$INTERPOSER_OUT"

"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.7 \
    "$PROBE_SRC" \
    -framework Foundation -framework CoreFoundation \
    -o "$PROBE_OUT"

"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.7 -dynamiclib \
    "$INTERPOSER_SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")" \
    -o "$INTERPOSER_OUT"

/bin/chmod 755 "$PROBE_OUT" "$INTERPOSER_OUT"

is_i386_macho() {
    file="$1"
    /usr/bin/lipo -verify_arch i386 "$file" >/dev/null 2>&1 && return 0
    /usr/bin/lipo "$file" -verify_arch i386 >/dev/null 2>&1 && return 0
    return 1
}

for file in "$PROBE_OUT" "$INTERPOSER_OUT"; do
    is_i386_macho "$file" || {
        echo "error: not an i386 Mach-O: $file" >&2
        /usr/bin/file "$file" >&2 || true
        exit 70
    }
done

/usr/bin/strings "$PROBE_OUT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID" || {
    echo "error: native probe build marker missing" >&2
    exit 71
}

/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_NATIVE_XPC_TRACE_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" || {
    echo "error: XPC trace build marker missing" >&2
    exit 71
}

/usr/bin/nm -u "$PROBE_OUT" | /usr/bin/grep -Fq "_CFNotificationCenterGetDistributedCenter" || {
    echo "error: probe does not import CFNotificationCenterGetDistributedCenter" >&2
    exit 72
}

/usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Fq "_xpc_connection_create" || {
    echo "error: trace interposer does not import xpc_connection_create" >&2
    exit 72
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER_OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq "__interpose" || {
    echo "error: trace interpose section missing" >&2
    exit 72
}

echo "Built: $PROBE_OUT"
echo "Built: $INTERPOSER_OUT"
echo "compiler=$CC_SELECTED"
/usr/bin/file "$PROBE_OUT"
/usr/bin/file "$INTERPOSER_OUT"
/usr/bin/shasum -a 256 "$PROBE_OUT"
/usr/bin/shasum -a 256 "$INTERPOSER_OUT"
