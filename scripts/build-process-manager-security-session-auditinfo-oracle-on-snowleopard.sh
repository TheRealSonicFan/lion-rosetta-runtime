#!/bin/bash
set -e

OUT_PPC="${1:-./ppc-process-manager-security-session-auditinfo-private-dyld}"
OUT_I386="${2:-./i386-process-manager-security-session-auditinfo-oracle}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/process-manager-security-session-auditinfo-oracle.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

PPC_INFO="$OUT_PPC.info.txt"
PPC_SHA="$OUT_PPC.sha256"
I386_INFO="$OUT_I386.info.txt"
I386_SHA="$OUT_I386.sha256"

TMP_PPC="$(/usr/bin/mktemp /tmp/security-auditinfo-ppc.XXXXXX)"
TMP_I386="$(/usr/bin/mktemp /tmp/security-auditinfo-i386.XXXXXX)"
TMP_LOG="$(/usr/bin/mktemp /tmp/security-auditinfo-build.XXXXXX.log)"
trap 'rm -f "$TMP_PPC" "$TMP_I386" "$TMP_LOG"' EXIT HUP INT TERM

[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper: $PATCH_DYLINKER" >&2; exit 66; }

resolve_compiler() {
    candidate="$1"
    [ -n "$candidate" ] || return 1
    if [ -x "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    command -v "$candidate" 2>/dev/null || return 1
}

is_arch() {
    arch="$1"
    file="$2"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch "$arch" "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch "$arch" >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq "$arch" || return 1
    return 0
}

probe_compiler() {
    candidate="$1"
    compiler="$(resolve_compiler "$candidate" || true)"
    [ -n "$compiler" ] || return 1

    /bin/rm -f "$TMP_PPC" "$TMP_I386"
    if "$compiler" -arch ppc -mmacosx-version-min=10.5         "$SRC" -framework Security -o "$TMP_PPC" >"$TMP_LOG" 2>&1 &&
       "$compiler" -arch i386 -mmacosx-version-min=10.5         "$SRC" -framework Security -o "$TMP_I386" >>"$TMP_LOG" 2>&1 &&
       is_arch ppc "$TMP_PPC" &&
       is_arch i386 "$TMP_I386"; then
        CC_SELECTED="$compiler"
        return 0
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
    echo "error: no installed compiler/toolchain could build both PPC and i386 Security AuditInfo probes" >&2
    exit 69
}

echo "Using compiler: $CC_SELECTED"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$SRC" -framework Security -o "$OUT_PPC"
"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.5     "$SRC" -framework Security -o "$OUT_I386"
/bin/chmod +x "$OUT_PPC" "$OUT_I386"

/usr/bin/python "$PATCH_DYLINKER" "$OUT_PPC" /usr/oah/dyld

is_arch ppc "$OUT_PPC" || { echo "error: PPC output is not PPC" >&2; exit 70; }
is_arch i386 "$OUT_I386" || { echo "error: i386 output is not i386" >&2; exit 70; }

OT="$(/usr/bin/otool -l "$OUT_PPC" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: PPC LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

for file in "$OUT_PPC" "$OUT_I386"; do
    /usr/bin/otool -L "$file" | /usr/bin/grep -Fq         '/System/Library/Frameworks/Security.framework/Versions/A/Security' || {
        echo "error: $file does not link Security" >&2
        exit 72
    }
    /usr/bin/nm -u "$file" | /usr/bin/grep -Eq '(^|[[:space:]])_getaudit_addr$' || {
        echo "error: $file does not import getaudit_addr" >&2
        exit 72
    }
    /usr/bin/nm -u "$file" | /usr/bin/grep -Eq '(^|[[:space:]])_SessionGetInfo$' || {
        echo "error: $file does not import SessionGetInfo" >&2
        exit 72
    }
done

{
    echo "== PPC Security AuditInfo oracle probe =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    /usr/bin/file "$OUT_PPC"
    /usr/bin/lipo -info "$OUT_PPC" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    /usr/bin/otool -l "$OUT_PPC" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    echo "== imports =="
    /usr/bin/nm -u "$OUT_PPC" | /usr/bin/grep -E '(_getaudit_addr|_SessionGetInfo)' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT_PPC"
} > "$PPC_INFO"

{
    echo "== i386 Security AuditInfo oracle =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    /usr/bin/file "$OUT_I386"
    /usr/bin/lipo -info "$OUT_I386" 2>/dev/null || true
    echo
    echo "== imports =="
    /usr/bin/nm -u "$OUT_I386" | /usr/bin/grep -E '(_getaudit_addr|_SessionGetInfo)' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT_I386"
} > "$I386_INFO"

/usr/bin/shasum -a 256 "$OUT_PPC" > "$PPC_SHA"
/usr/bin/shasum -a 256 "$OUT_I386" > "$I386_SHA"

echo "Created:"
echo "  $OUT_PPC"
echo "  $PPC_INFO"
echo "  $PPC_SHA"
echo "  $OUT_I386"
echo "  $I386_INFO"
echo "  $I386_SHA"
