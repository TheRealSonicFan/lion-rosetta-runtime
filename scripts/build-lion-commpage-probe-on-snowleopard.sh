#!/bin/bash
set -e

OUT="${1:-./lion-commpage-probe}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/../tools/lion-commpage-probe.c"
[ -f "$SRC" ] || { echo "error: source not found: $SRC" >&2; exit 66; }

resolve_compiler() {
    candidate="$1"
    [ -n "$candidate" ] || return 1
    if [ -x "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    command -v "$candidate" 2>/dev/null || return 1
}

probe_compiler() {
    candidate="$1"
    compiler="$(resolve_compiler "$candidate" || true)"
    [ -n "$compiler" ] || return 1

    tmpc="$(/usr/bin/mktemp /tmp/lion-commpage-probe.XXXXXX.c)"
    tmpbin="$(/usr/bin/mktemp /tmp/lion-commpage-probe.XXXXXX)"
    echo 'int main(void) { return 0; }' > "$tmpc"

    if "$compiler" -arch i386 -mmacosx-version-min=10.6 "$tmpc" -o "$tmpbin" >/dev/null 2>&1 && \
       /usr/bin/lipo -verify_arch i386 "$tmpbin" >/dev/null 2>&1; then
        /bin/rm -f "$tmpc" "$tmpbin"
        CC_SELECTED="$compiler"
        return 0
    fi

    /bin/rm -f "$tmpc" "$tmpbin"
    return 1
}

CC_SELECTED=""
if [ -n "${CC:-}" ]; then
    probe_compiler "$CC" || true
fi

if [ -z "$CC_SELECTED" ]; then
    for c in \
        /Developer-3.2.6/usr/bin/gcc-4.2 \
        /Developer/usr/bin/gcc-4.2 \
        /usr/bin/gcc-4.2 \
        /usr/bin/gcc \
        /usr/bin/cc; do
        probe_compiler "$c" && break
    done
fi

[ -n "$CC_SELECTED" ] || {
    echo "error: no compiler could build an i386 Mach-O" >&2
    exit 69
}

echo "Using i386 compiler: $CC_SELECTED"
"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6 -Wall -Wextra "$SRC" -o "$OUT"
/bin/chmod +x "$OUT"
/usr/bin/file "$OUT"
/usr/bin/lipo -info "$OUT" || true
/usr/bin/shasum -a 256 "$OUT" 2>/dev/null || true
echo "Created: $OUT"
