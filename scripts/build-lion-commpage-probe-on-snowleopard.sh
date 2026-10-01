#!/bin/bash
set -e

OUT="${1:-./lion-commpage-probe}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/../tools/lion-commpage-probe.c"
[ -f "$SRC" ] || { echo "error: source not found: $SRC" >&2; exit 66; }

TMP_PROBE_SRC="$(/usr/bin/mktemp /tmp/lion-commpage-probe-src.XXXXXX)"
TMP_PROBE_BIN="$(/usr/bin/mktemp /tmp/lion-commpage-probe-bin.XXXXXX)"
TMP_LOG="$(/usr/bin/mktemp /tmp/lion-commpage-probe-log.XXXXXX)"
trap '/bin/rm -f "$TMP_PROBE_SRC" "$TMP_PROBE_BIN" "$TMP_LOG"' EXIT HUP INT TERM

cat > "$TMP_PROBE_SRC" <<'SRC'
int main(void) { return 0; }
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

is_i386_macho() {
    file="$1"
    [ -f "$file" ] || return 1

    # Prefer lipo when it can positively identify the i386 slice.
    if [ -x /usr/bin/lipo ]; then
        if /usr/bin/lipo -verify_arch i386 "$file" >/dev/null 2>&1; then
            return 0
        fi

        info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
        echo "$info" | /usr/bin/grep -Eiq '(^|[[:space:]:])i386([[:space:]]|$)' && return 0
    fi

    # file(1) wording differs somewhat across Snow Leopard and Lion.
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq 'Mach-O.*(^|[[:space:]])i386([[:space:]]|$)' && return 0

    return 1
}

probe_compiler() {
    candidate="$1"
    compiler="$(resolve_compiler "$candidate" || true)"
    [ -n "$compiler" ] || return 1

    /bin/rm -f "$TMP_PROBE_BIN"
    : > "$TMP_LOG"

    if "$compiler" -arch i386 -mmacosx-version-min=10.6 -x c "$TMP_PROBE_SRC" -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1; then
        if is_i386_macho "$TMP_PROBE_BIN"; then
            CC_SELECTED="$compiler"
            return 0
        fi
    fi

    echo "Rejected compiler: $compiler" >&2
    if [ -f "$TMP_PROBE_BIN" ]; then
        /usr/bin/file "$TMP_PROBE_BIN" >&2 || true
        if [ -x /usr/bin/lipo ]; then
            /usr/bin/lipo -info "$TMP_PROBE_BIN" >&2 || true
        fi
    fi
    /bin/cat "$TMP_LOG" >&2 || true
    return 1
}

CC_SELECTED=""

if [ -n "${CC:-}" ]; then
    echo "Probing requested compiler: $CC" >&2
    probe_compiler "$CC" || true
fi

if [ -z "$CC_SELECTED" ]; then
    for c in         /Developer-3.2.6/usr/bin/gcc-4.2         /Developer/usr/bin/gcc-4.2         /Developer/usr/bin/llvm-gcc-4.2         /usr/bin/gcc-4.2         /usr/bin/llvm-gcc-4.2         /usr/bin/gcc         /usr/bin/cc; do
        echo "Probing compiler: $c" >&2
        if probe_compiler "$c"; then
            break
        fi
    done
fi

if [ -z "$CC_SELECTED" ]; then
    echo "error: no installed compiler/toolchain could build and link an i386 Mach-O executable" >&2
    echo "The rejection diagnostics above show the exact compiler/linker failure." >&2
    echo "You may explicitly select a compiler, for example:" >&2
    echo "  CC=/Developer-3.2.6/usr/bin/gcc-4.2 $0 $OUT" >&2
    exit 69
fi

echo "Using i386-capable compiler: $CC_SELECTED"

# Remove any old output so a failed compile cannot be mistaken for a new probe.
/bin/rm -f "$OUT"

"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6 -Wall -Wextra     "$SRC" -o "$OUT"

/bin/chmod +x "$OUT"

/usr/bin/file "$OUT"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$OUT" || true
fi
/usr/bin/shasum -a 256 "$OUT" 2>/dev/null || true

is_i386_macho "$OUT" || {
    echo "error: output is not an i386 Mach-O executable" >&2
    exit 70
}

echo "Created: $OUT"
