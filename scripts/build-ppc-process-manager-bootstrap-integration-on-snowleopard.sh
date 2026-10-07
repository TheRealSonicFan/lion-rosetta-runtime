#!/bin/bash
set -e

STAGE_OUT="${1:-./ppc-process-manager-bootstrap-integration-stage-private-dyld}"
INTERPOSER_OUT="${2:-./ppc-process-manager-bootstrap-compat-interposer.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE_BUILDER="$SCRIPT_DIR/build-ppc-process-manager-systemservice-stage-on-snowleopard.sh"
INTERPOSER_SRC="$ROOT/tests/ppc-process-manager-bootstrap-compat-interposer.c"
INFO="$INTERPOSER_OUT.info.txt"
SHA="$INTERPOSER_OUT.sha256"
TMP_DYLIB="$(/usr/bin/mktemp /tmp/ppc-bootstrap-compat.XXXXXX.dylib)"
TMP_LOG="$(/usr/bin/mktemp /tmp/ppc-bootstrap-compat.XXXXXX.log)"
trap 'rm -f "$TMP_DYLIB" "$TMP_LOG"' EXIT HUP INT TERM

[ -x "$STAGE_BUILDER" ] || { echo "error: missing stage builder: $STAGE_BUILDER" >&2; exit 66; }
[ -f "$INTERPOSER_SRC" ] || { echo "error: missing interposer source: $INTERPOSER_SRC" >&2; exit 66; }

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
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
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

    /bin/rm -f "$TMP_DYLIB"
    if "$compiler" -arch ppc -mmacosx-version-min=10.5 -dynamiclib         "$INTERPOSER_SRC"         -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")"         -o "$TMP_DYLIB" >"$TMP_LOG" 2>&1; then
        if [ -f "$TMP_DYLIB" ] && is_ppc32_macho "$TMP_DYLIB"; then
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
    echo "error: no installed compiler/toolchain could build the PPC bootstrap compatibility interposer" >&2
    exit 69
}

echo "Using PowerPC-capable compiler: $CC_SELECTED"

echo "Building the existing CoreServices stage subject..."
CC="$CC_SELECTED" /bin/bash "$STAGE_BUILDER" "$STAGE_OUT"

echo "Building the PPC process-local bootstrap compatibility interposer..."
"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib     "$INTERPOSER_SRC"     -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")"     -o "$INTERPOSER_OUT"
/bin/chmod 755 "$INTERPOSER_OUT"

is_ppc32_macho "$INTERPOSER_OUT" || {
    echo "error: interposer is not a 32-bit PowerPC Mach-O image" >&2
    exit 70
}

{
    echo "== PPC Process Manager bootstrap compatibility interposer build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$INTERPOSER_SRC"
    echo
    echo "== file =="
    /usr/bin/file "$INTERPOSER_OUT"
    echo
    echo "== lipo =="
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -info "$INTERPOSER_OUT" || true
    fi
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$INTERPOSER_OUT"
    echo
    echo "== interpose section =="
    /usr/bin/otool -l "$INTERPOSER_OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true
    echo
    echo "== required imports/symbols =="
    /usr/bin/nm -m "$INTERPOSER_OUT" | /usr/bin/grep -E 'bootstrap_look_up2|mach_msg|mig_get_reply_port|rosetta_bootstrap_look_up2' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$INTERPOSER_OUT"
} > "$INFO"

/usr/bin/otool -l "$INTERPOSER_OUT" | /usr/bin/grep -q '__interpose' || {
    echo "error: interposer does not contain a __DATA,__interpose section" >&2
    exit 71
}

for sym in _bootstrap_look_up2 _mach_msg _mig_get_reply_port _rosetta_bootstrap_look_up2; do
    /usr/bin/nm -m "$INTERPOSER_OUT" | /usr/bin/grep -Fq "$sym" || {
        echo "error: interposer does not reference $sym" >&2
        exit 72
    }
done

/usr/bin/shasum -a 256 "$INTERPOSER_OUT" > "$SHA"

echo "Created:"
echo "  $STAGE_OUT"
echo "  $STAGE_OUT.info.txt"
echo "  $STAGE_OUT.sha256"
echo "  $INTERPOSER_OUT"
echo "  $INFO"
echo "  $SHA"
