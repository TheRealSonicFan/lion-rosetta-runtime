#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/native-cgwindowlist-pid-observer.c"
OUT="${1:-./cgwindowlist-pid-observer}"
EXPECTED_BUILD_ID="cgwindowlist-pid-observer-v1"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: build WindowServer observer on Snow Leopard 10.6.8" >&2
    exit 65
}

if [ -n "${CC:-}" ]; then
    CC_SELECTED="$CC"
elif [ -x /Developer-3.2.6/usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/Developer-3.2.6/usr/bin/gcc-4.2
elif [ -x /Developer/usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/Developer/usr/bin/gcc-4.2
elif [ -x /usr/bin/gcc-4.2 ]; then
    CC_SELECTED=/usr/bin/gcc-4.2
else
    echo "error: no supported Snow Leopard compiler found" >&2
    exit 69
fi

[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
[ -f "$SRC" ] || {
    echo "error: missing source: $SRC" >&2
    exit 66
}

/bin/rm -f "$OUT" "$OUT.info.txt" "$OUT.sha256"

"$CC_SELECTED" -arch i386 -std=gnu99 -Wall -Wextra \
    -mmacosx-version-min=10.6 \
    "$SRC" \
    -framework ApplicationServices \
    -o "$OUT"

/bin/chmod 755 "$OUT"

/usr/bin/lipo -verify_arch i386 "$OUT" >/dev/null 2>&1 ||
    /usr/bin/lipo "$OUT" -verify_arch i386 >/dev/null 2>&1 || {
        echo "error: WindowServer observer is not i386" >&2
        exit 70
    }

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "CGWINDOW_OBSERVER_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: observer build marker missing" >&2
    exit 71
}

for sym in \
    _CGWindowListCopyWindowInfo \
    _CGMainDisplayID \
    _CGDisplayBounds \
    _CGGetActiveDisplayList
do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Fq "$sym" || {
        echo "error: observer missing import $sym" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== Native CGWindowList PID observer =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "source=$SRC"
    /usr/bin/shasum -a 256 "$SRC"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== Dependencies =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$OUT.info.txt"

/usr/bin/shasum -a 256 "$OUT" > "$OUT.sha256"

echo "Created:"
echo "  $OUT"
echo "  $OUT.info.txt"
echo "  $OUT.sha256"
