#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-noasn-private-dyld}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-noasn-discriminator.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
TMP_PROBE_SRC="$(/usr/bin/mktemp /tmp/ppc-pm-noasn-probe.XXXXXX.c)"
TMP_PROBE_BIN="$(/usr/bin/mktemp /tmp/ppc-pm-noasn-probe.XXXXXX)"
TMP_LOG="$(/usr/bin/mktemp /tmp/ppc-pm-noasn-probe.XXXXXX.log)"
trap 'rm -f "$TMP_PROBE_SRC" "$TMP_PROBE_BIN" "$TMP_LOG"' EXIT HUP INT TERM

[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper: $PATCH_DYLINKER" >&2; exit 66; }

cat > "$TMP_PROBE_SRC" <<'SRC'
#include <Carbon/Carbon.h>
#include <unistd.h>
int main(void) {
    ProcessSerialNumber psn = { 0, 0 };
    return (GetProcessForPID(getpid(), &psn) == noErr) ? 0 : 1;
}
SRC

resolve_compiler() {
    candidate="$1"
    [ -n "$candidate" ] || return 1
    if [ -x "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    command -v "$candidate" 2>/dev/null || return 1
}

is_ppc32_macho() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

probe_compiler() {
    candidate="$1"
    compiler="$(resolve_compiler "$candidate" || true)"
    [ -n "$compiler" ] || return 1

    /bin/rm -f "$TMP_PROBE_BIN"
    if "$compiler" -arch ppc -mmacosx-version-min=10.5         "$TMP_PROBE_SRC" -framework Carbon         -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1; then
        if [ -f "$TMP_PROBE_BIN" ] && is_ppc32_macho "$TMP_PROBE_BIN"; then
            CC_SELECTED="$compiler"
            return 0
        fi
    fi

    echo "Rejected compiler: $compiler" >&2
    /bin/cat "$TMP_LOG" >&2 || true
    return 1
}

CC_SELECTED=""
if [ -n "${CC:-}" ]; then
    echo "Probing requested compiler: $CC" >&2
    probe_compiler "$CC" || true
fi

if [ -z "$CC_SELECTED" ]; then
    for c in         /Developer-3.2.6/usr/bin/gcc-4.2         /Developer-3.2.6/usr/bin/gcc-4.0         /Developer/usr/bin/gcc-4.2         /Developer/usr/bin/gcc-4.0         /usr/bin/gcc-4.2         /usr/bin/gcc-4.0         /usr/bin/gcc         /usr/bin/cc; do
        echo "Probing compiler: $c" >&2
        if probe_compiler "$c"; then
            break
        fi
    done
fi

[ -n "$CC_SELECTED" ] || {
    echo "error: no installed compiler/toolchain could build the 32-bit PPC Process Manager no-ASN discriminator" >&2
    exit 69
}

echo "Using PowerPC-capable compiler: $CC_SELECTED"
"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$SRC" -framework Carbon -o "$OUT"
/bin/chmod +x "$OUT"

echo "Patching alternate PPC LC_LOAD_DYLINKER: /usr/oah/dyld"
/usr/bin/python "$PATCH_DYLINKER" "$OUT" /usr/oah/dyld

is_ppc32_macho "$OUT" || {
    echo "error: output is not a 32-bit PowerPC Mach-O executable" >&2
    exit 70
}

{
    echo "== PPC Process Manager no-ASN discriminator build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo
    echo "== file =="
    /usr/bin/file "$OUT"
    echo
    echo "== lipo =="
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -info "$OUT" || true
    fi
    echo
    echo "== LC_LOAD_DYLINKER =="
    /usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

OT="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: output LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/otool -L "$OUT" | /usr/bin/grep -Fq '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || {
    echo "error: output does not link Carbon" >&2
    exit 72
}

/usr/bin/shasum -a 256 "$OUT" > "$SHA"

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
