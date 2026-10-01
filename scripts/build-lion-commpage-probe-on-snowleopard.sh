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

select_sdk() {
    compiler="$1"

    if [ -n "${SDKROOT:-}" ] && [ -d "$SDKROOT" ]; then
        echo "$SDKROOT"
        return 0
    fi

    case "$compiler" in
        /Developer-3.2.6/*)
            [ -d /Developer-3.2.6/SDKs/MacOSX10.6.sdk ] && {
                echo /Developer-3.2.6/SDKs/MacOSX10.6.sdk
                return 0
            }
            ;;
        /Developer/*)
            [ -d /Developer/SDKs/MacOSX10.6.sdk ] && {
                echo /Developer/SDKs/MacOSX10.6.sdk
                return 0
            }
            [ -d /Developer/SDKs/MacOSX10.7.sdk ] && {
                echo /Developer/SDKs/MacOSX10.7.sdk
                return 0
            }
            ;;
    esac

    version="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
    case "$version" in
        10.6|10.6.*)
            [ -d /Developer-3.2.6/SDKs/MacOSX10.6.sdk ] && {
                echo /Developer-3.2.6/SDKs/MacOSX10.6.sdk
                return 0
            }
            [ -d /Developer/SDKs/MacOSX10.6.sdk ] && {
                echo /Developer/SDKs/MacOSX10.6.sdk
                return 0
            }
            ;;
        10.7|10.7.*)
            [ -d /Developer/SDKs/MacOSX10.7.sdk ] && {
                echo /Developer/SDKs/MacOSX10.7.sdk
                return 0
            }
            [ -d /Developer/SDKs/MacOSX10.6.sdk ] && {
                echo /Developer/SDKs/MacOSX10.6.sdk
                return 0
            }
            ;;
    esac

    # Building against the live system root is still valid when the
    # corresponding headers/libraries are installed.
    echo ""
    return 0
}

is_i386_macho() {
    file="$1"
    [ -f "$file" ] || return 1

    if [ -x /usr/bin/lipo ]; then
        if /usr/bin/lipo -verify_arch i386 "$file" >/dev/null 2>&1; then
            return 0
        fi

        info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
        echo "$info" | /usr/bin/grep -Eiq '(^|[[:space:]:])i386([[:space:]]|$)' && return 0
    fi

    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq 'Mach-O.*[[:space:]]i386([[:space:]]|$)' && return 0

    return 1
}

compile_probe_program() {
    compiler="$1"
    sdk="$2"

    /bin/rm -f "$TMP_PROBE_BIN"
    : > "$TMP_LOG"

    if [ -n "$sdk" ]; then
        "$compiler" -arch i386 -mmacosx-version-min=10.6 -isysroot "$sdk" -x c "$TMP_PROBE_SRC" -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1
    else
        "$compiler" -arch i386 -mmacosx-version-min=10.6 -x c "$TMP_PROBE_SRC" -o "$TMP_PROBE_BIN" >"$TMP_LOG" 2>&1
    fi
}

probe_compiler() {
    candidate="$1"
    compiler="$(resolve_compiler "$candidate" || true)"
    [ -n "$compiler" ] || return 1

    sdk="$(select_sdk "$compiler")"

    if compile_probe_program "$compiler" "$sdk"; then
        if is_i386_macho "$TMP_PROBE_BIN"; then
            CC_SELECTED="$compiler"
            SDK_SELECTED="$sdk"
            return 0
        fi
    fi

    echo "Rejected compiler: $compiler" >&2
    [ -n "$sdk" ] && echo "  SDK: $sdk" >&2

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
SDK_SELECTED=""

if [ -n "${CC:-}" ]; then
    echo "Probing requested compiler: $CC" >&2
    probe_compiler "$CC" || true
fi

if [ -z "$CC_SELECTED" ]; then
    for c in /Developer-3.2.6/usr/bin/gcc-4.2 /Developer/usr/bin/gcc-4.2 /Developer/usr/bin/llvm-gcc-4.2 /usr/bin/gcc-4.2 /usr/bin/llvm-gcc-4.2 /usr/bin/gcc /usr/bin/cc; do
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
if [ -n "$SDK_SELECTED" ]; then
    echo "Using SDK: $SDK_SELECTED"
else
    echo "Using live system headers/libraries (no explicit SDK)"
fi

/bin/rm -f "$OUT"

if [ -n "$SDK_SELECTED" ]; then
    "$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6 -isysroot "$SDK_SELECTED" -Wall -Wextra "$SRC" -o "$OUT"
else
    "$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6 -Wall -Wextra "$SRC" -o "$OUT"
fi

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
