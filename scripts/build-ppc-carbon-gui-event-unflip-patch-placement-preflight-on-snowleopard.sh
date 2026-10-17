#!/bin/bash
set -e

if [ "$#" -ge 1 ]; then
    PROBE_OUT="$1"
else
    PROBE_OUT="./ppc-carbon-gui-event-unflip-patch-placement-preflight-private-dyld"
fi
if [ "$#" -ge 2 ]; then
    MARKER_OUT="$2"
else
    MARKER_OUT="./ppc-carbon-gui-event-unflip-placement-marker.dylib"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE_SRC="$ROOT/tests/ppc-carbon-gui-event-unflip-patch-placement-preflight.c"
MARKER_SRC="$ROOT/tests/ppc-carbon-gui-event-unflip-placement-marker.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

[ -f "$PROBE_SRC" ] || { echo "error: missing source: $PROBE_SRC" >&2; exit 66; }
[ -f "$MARKER_SRC" ] || { echo "error: missing source: $MARKER_SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker helper: $PATCH_DYLINKER" >&2; exit 66; }

resolve_compiler() {
    for candidate in "${CC:-}" /usr/bin/gcc-4.2 /usr/bin/gcc /usr/bin/cc; do
        [ -n "$candidate" ] || continue
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

is_ppc32() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

CC_SELECTED="$(resolve_compiler)" || {
    echo "error: no compiler found" >&2
    exit 69
}

echo "compiler=$CC_SELECTED"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 \
    -dynamiclib "$MARKER_SRC" \
    -o "$MARKER_OUT"

/bin/chmod 755 "$MARKER_OUT"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 \
    "$PROBE_SRC" \
    -framework ApplicationServices \
    -o "$PROBE_OUT"

/bin/chmod +x "$PROBE_OUT"

/usr/bin/python "$PATCH_DYLINKER" "$PROBE_OUT" /usr/oah/dyld

is_ppc32 "$PROBE_OUT" || {
    echo "error: probe is not 32-bit PowerPC" >&2
    exit 70
}
is_ppc32 "$MARKER_OUT" || {
    echo "error: marker dylib is not 32-bit PowerPC" >&2
    exit 70
}

OT="$(/usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

PROBE_SHA="$(sha256 "$PROBE_OUT")"
MARKER_SHA="$(sha256 "$MARKER_OUT")"

echo "$PROBE_SHA  $PROBE_OUT" > "$PROBE_OUT.sha256"
echo "$MARKER_SHA  $MARKER_OUT" > "$MARKER_OUT.sha256"

{
    echo "== event-unflip patch placement probe =="
    echo "source=$PROBE_SRC"
    echo "compiler=$CC_SELECTED"
    /usr/bin/file "$PROBE_OUT"
    /usr/bin/otool -hv "$PROBE_OUT"
    /usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true
    echo "sha256=$PROBE_SHA"
} > "$PROBE_OUT.info.txt"

{
    echo "== event-unflip placement marker =="
    echo "source=$MARKER_SRC"
    echo "compiler=$CC_SELECTED"
    /usr/bin/file "$MARKER_OUT"
    /usr/bin/otool -hv "$MARKER_OUT"
    /usr/bin/nm -g "$MARKER_OUT" | /usr/bin/grep 'rosetta_event_unflip_placement_marker' || true
    echo "sha256=$MARKER_SHA"
} > "$MARKER_OUT.info.txt"

echo "Created:"
echo "  $PROBE_OUT"
echo "  $PROBE_OUT.info.txt"
echo "  $PROBE_OUT.sha256"
echo "  $MARKER_OUT"
echo "  $MARKER_OUT.info.txt"
echo "  $MARKER_OUT.sha256"
