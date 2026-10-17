#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
OUT="${1:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld}"
EXPECTED_CONTRACT="carbon-gui-event-unflip-dladdr-route-execution-v2"

[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker helper: $PATCH_DYLINKER" >&2; exit 66; }

sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
resolve_compiler() {
    for candidate in "${CC:-}" /Developer-3.2.6/usr/bin/gcc-4.2 /Developer-3.2.6/usr/bin/gcc-4.0 /Developer/usr/bin/gcc-4.2 /Developer/usr/bin/gcc-4.0 /usr/bin/gcc-4.2 /usr/bin/gcc-4.0 /usr/bin/gcc /usr/bin/cc; do
        [ -n "$candidate" ] || continue
        [ -x "$candidate" ] && { echo "$candidate"; return 0; }
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
    desc="${desc#*: }"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc([0-9]+)?|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

CC_SELECTED="$(resolve_compiler)" || { echo "error: no PowerPC-capable compiler found" >&2; exit 69; }
SOURCE_SHA="$(sha256 "$SRC")"

echo "compiler=$CC_SELECTED"
echo "source_sha256=$SOURCE_SHA"
"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 "$SRC" -framework ApplicationServices -o "$OUT"
/bin/chmod 755 "$OUT"
/usr/bin/python "$PATCH_DYLINKER" "$OUT" /usr/oah/dyld

is_ppc32 "$OUT" || { echo "error: probe is not 32-bit PowerPC" >&2; exit 70; }
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$EXPECTED_CONTRACT" || { echo "error: probe contract marker missing" >&2; exit 71; }
OT="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || { echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2; exit 71; }

OUT_SHA="$(sha256 "$OUT")"
echo "$OUT_SHA  $OUT" > "$OUT.sha256"
{
    echo "== event-unflip dladdr route execution probe build =="
    echo "source=$SRC"
    echo "source_sha256=$SOURCE_SHA"
    echo "source_provenance_policy=MODERN_STAGING_SYSTEM_SHA256"
    echo "legacy_git_blob_check=NOT_REQUIRED"
    echo "contract=$EXPECTED_CONTRACT"
    echo "compiler=$CC_SELECTED"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    /usr/bin/otool -hv "$OUT"
    /usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true
    /usr/bin/otool -L "$OUT"
    echo "sha256=$OUT_SHA"
} > "$OUT.info.txt"

echo "Created:"
echo "  $OUT"
echo "  $OUT.info.txt"
echo "  $OUT.sha256"
