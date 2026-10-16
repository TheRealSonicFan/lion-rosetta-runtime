#!/bin/bash
set -e

if [ "$#" -ge 1 ]; then
    PPC_OUT="$1"
else
    PPC_OUT="./ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld"
fi
if [ "$#" -ge 2 ]; then
    I386_OUT="$2"
else
    I386_OUT="./lion-i386-display-shmem-prefix-snapshot"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-carbon-gui-display-shmem-prefix-snapshot.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

PPC_INFO="$PPC_OUT.info.txt"
PPC_SHA="$PPC_OUT.sha256"
I386_INFO="$I386_OUT.info.txt"
I386_SHA="$I386_OUT.sha256"

TMP_PROBE_SRC="$(/usr/bin/mktemp /tmp/display-shmem-prefix-build.XXXXXX.c)"
TMP_PROBE_BIN="$(/usr/bin/mktemp /tmp/display-shmem-prefix-build.XXXXXX)"
TMP_LOG="$(/usr/bin/mktemp /tmp/display-shmem-prefix-build.XXXXXX.log)"
trap 'rm -f "$TMP_PROBE_SRC" "$TMP_PROBE_BIN" "$TMP_LOG"' EXIT HUP INT TERM

[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper: $PATCH_DYLINKER" >&2; exit 66; }

cat > "$TMP_PROBE_SRC" <<'SRC'
#include <ApplicationServices/ApplicationServices.h>
int main(void) { return CGMainDisplayID() == 0 ? 0 : 0; }
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

is_arch() {
    arch="$1"
    file="$2"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch "$arch" "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch "$arch" >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    case "$arch" in
        ppc)
            echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
            echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
            ;;
        i386)
            echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])i386([^[:alnum:]_]|$)' || return 1
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

probe_compiler() {
    candidate="$1"
    compiler="$(resolve_compiler "$candidate" || true)"
    [ -n "$compiler" ] || return 1

    /bin/rm -f "$TMP_PROBE_BIN"
    if "$compiler" -arch ppc -mmacosx-version-min=10.4         "$TMP_PROBE_SRC" -framework ApplicationServices         -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1; then
        if [ -f "$TMP_PROBE_BIN" ] && is_arch ppc "$TMP_PROBE_BIN"; then
            /bin/rm -f "$TMP_PROBE_BIN"
            if "$compiler" -arch i386 -mmacosx-version-min=10.6                 "$TMP_PROBE_SRC" -framework ApplicationServices                 -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1; then
                if [ -f "$TMP_PROBE_BIN" ] && is_arch i386 "$TMP_PROBE_BIN"; then
                    CC_SELECTED="$compiler"
                    return 0
                fi
            fi
        fi
    fi

    echo "Rejected compiler: $compiler" >&2
    /bin/cat "$TMP_LOG" >&2 || true
    return 1
}

CC_SELECTED=""
if [ -n "$CC" ]; then
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
    echo "error: no installed compiler can build both 32-bit PPC and i386 probes" >&2
    exit 69
}

echo "Using compiler: $CC_SELECTED"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.4     "$SRC" -framework ApplicationServices -o "$PPC_OUT"
/bin/chmod +x "$PPC_OUT"

echo "Patching PPC LC_LOAD_DYLINKER: /usr/oah/dyld"
/usr/bin/python "$PATCH_DYLINKER" "$PPC_OUT" /usr/oah/dyld

"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6     "$SRC" -framework ApplicationServices -o "$I386_OUT"
/bin/chmod +x "$I386_OUT"

is_arch ppc "$PPC_OUT" || {
    echo "error: PPC output is not 32-bit PPC" >&2
    exit 70
}
is_arch i386 "$I386_OUT" || {
    echo "error: i386 output is not 32-bit i386" >&2
    exit 70
}

PPC_OT="$(/usr/bin/otool -l "$PPC_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$PPC_OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: PPC LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

for file in "$PPC_OUT" "$I386_OUT"; do
    /usr/bin/otool -L "$file" | /usr/bin/grep -Eq         'ApplicationServices|CoreGraphics' || {
        echo "error: CoreGraphics/ApplicationServices dependency absent: $file" >&2
        exit 72
    }
done

{
    echo "== PPC display-shmem prefix snapshot build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo
    /usr/bin/file "$PPC_OUT"
    /usr/bin/lipo -info "$PPC_OUT" 2>/dev/null || true
    echo
    /usr/bin/otool -l "$PPC_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    /usr/bin/otool -L "$PPC_OUT"
    echo
    /usr/bin/shasum -a 256 "$PPC_OUT"
} > "$PPC_INFO"

{
    echo "== Lion i386 display-shmem prefix snapshot build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo
    /usr/bin/file "$I386_OUT"
    /usr/bin/lipo -info "$I386_OUT" 2>/dev/null || true
    echo
    /usr/bin/otool -l "$I386_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    /usr/bin/otool -L "$I386_OUT"
    echo
    /usr/bin/shasum -a 256 "$I386_OUT"
} > "$I386_INFO"

/usr/bin/shasum -a 256 "$PPC_OUT" > "$PPC_SHA"
/usr/bin/shasum -a 256 "$I386_OUT" > "$I386_SHA"

echo "Created:"
echo "  $PPC_OUT"
echo "  $PPC_INFO"
echo "  $PPC_SHA"
echo "  $I386_OUT"
echo "  $I386_INFO"
echo "  $I386_SHA"
