#!/bin/bash
set -e

OUT="${1:-./ppc-smoketest}"
TMP_SRC="$(/usr/bin/mktemp /tmp/ppc-smoketest.XXXXXX.c)"
TMP_PROBE_SRC="$(/usr/bin/mktemp /tmp/ppc-probe.XXXXXX.c)"
TMP_PROBE_BIN="$(/usr/bin/mktemp /tmp/ppc-probe.XXXXXX)"
TMP_LOG="$(/usr/bin/mktemp /tmp/ppc-probe.XXXXXX.log)"
trap 'rm -f "$TMP_SRC" "$TMP_PROBE_SRC" "$TMP_PROBE_BIN" "$TMP_LOG"' EXIT HUP INT TERM

cat > "$TMP_SRC" <<'SRC'
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
int main(void) {
    printf("Rosetta PPC smoke test: pid=%ld\n", (long)getpid());
    return 0;
}
SRC

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

is_ppc32_macho() {
    file="$1"

    # Prefer lipo's architecture check: it understands Mach-O architecture
    # names directly and avoids depending on file(1)'s wording ("ppc" vs
    # "PowerPC").
    if [ -x /usr/bin/lipo ]; then
        if /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Fallback for systems where lipo is unavailable.
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
    if "$compiler" -arch ppc -mmacosx-version-min=10.4 "$TMP_PROBE_SRC" -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1; then
        if [ -f "$TMP_PROBE_BIN" ] && is_ppc32_macho "$TMP_PROBE_BIN"; then
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
    for c in \
        /Developer/usr/bin/gcc-4.2 \
        /Developer/usr/bin/gcc-4.0 \
        /usr/bin/gcc-4.2 \
        /usr/bin/gcc-4.0 \
        /usr/bin/gcc \
        /usr/bin/cc; do
        echo "Probing compiler: $c" >&2
        if probe_compiler "$c"; then
            break
        fi
    done
fi

if [ -z "$CC_SELECTED" ]; then
    echo "error: no installed compiler/toolchain could build and link a 32-bit PowerPC Mach-O executable" >&2
    echo "Use a PowerPC-capable Xcode 3.x GCC toolchain and rerun with, for example:" >&2
    echo "  CC=/path/to/gcc-4.2 $0 $OUT" >&2
    exit 69
fi

echo "Using PowerPC-capable compiler: $CC_SELECTED"
if [ -n "${PPC_DYLINKER:-}" ]; then
    echo "Using alternate PPC LC_LOAD_DYLINKER: $PPC_DYLINKER"
    "$CC_SELECTED" -arch ppc -mmacosx-version-min=10.4 \
        -Wl,-dylinker,"$PPC_DYLINKER" "$TMP_SRC" -o "$OUT"
else
    "$CC_SELECTED" -arch ppc -mmacosx-version-min=10.4 "$TMP_SRC" -o "$OUT"
fi
/bin/chmod +x "$OUT"

/usr/bin/file "$OUT"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$OUT" || true
fi
/usr/bin/shasum -a 256 "$OUT" 2>/dev/null || true

is_ppc32_macho "$OUT" || {
    echo "error: output is not a 32-bit PowerPC Mach-O executable" >&2
    exit 70
}

echo "Created: $OUT"
