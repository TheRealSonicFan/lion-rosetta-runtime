#!/bin/bash
set -e

OUT="${1:-./pm-coreui-image-bitmapinfo-compat.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-coreui-image-bitmapinfo-compat-interposer.c"
EXPECTED_BUILD_ID="coreui-image-bitmapinfo-compat-v1"
EXPECTED_SOURCE_SHA256="fa8768f73b8469c5795c4801e2412ccd7a6094979fb2d01818f51a9876b11852"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
TMP_DYLIB="$(/usr/bin/mktemp /tmp/pm-coreui-image-bitmapinfo.XXXXXX.dylib)"
TMP_LOG="$(/usr/bin/mktemp /tmp/pm-coreui-image-bitmapinfo.XXXXXX.log)"
trap 'rm -f "$TMP_DYLIB" "$TMP_LOG"' EXIT HUP INT TERM

[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
/usr/bin/grep -Fq "#define BUILD_ID \"$EXPECTED_BUILD_ID\"" "$SRC" || {
    echo "error: stale CoreUI bitmap-info compatibility source; pull current runtime main" >&2
    exit 66
}

SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"
[ "$SOURCE_SHA" = "$EXPECTED_SOURCE_SHA256" ] || {
    echo "error: CoreUI bitmap-info compatibility source SHA-256 mismatch: $SOURCE_SHA" >&2
    exit 66
}resolve_compiler() {
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
    if "$compiler" -arch ppc -mmacosx-version-min=10.5 -dynamiclib \
        "$SRC" -framework ApplicationServices \
        -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
        -o "$TMP_DYLIB" >"$TMP_LOG" 2>&1; then
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
    probe_compiler "$CC" || true
fi

if [ -z "$CC_SELECTED" ]; then
    for c in \
        /Developer-3.2.6/usr/bin/gcc-4.2 \
        /Developer-3.2.6/usr/bin/gcc-4.0 \
        /Developer/usr/bin/gcc-4.2 \
        /Developer/usr/bin/gcc-4.0 \
        /usr/bin/gcc-4.2 \
        /usr/bin/gcc-4.0 \
        /usr/bin/gcc \
        /usr/bin/cc; do
        if probe_compiler "$c"; then
            break
        fi
    done
fi

[ -n "$CC_SELECTED" ] || {
    echo "error: no installed compiler/toolchain could build the PPC CoreUI bitmap-info compatibility dylib" >&2
    exit 69
}

echo "Using PowerPC-capable compiler: $CC_SELECTED"
"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib \
    "$SRC" -framework ApplicationServices \
    -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
    -o "$OUT"
/bin/chmod 755 "$OUT"

is_ppc32_macho "$OUT" || {
    echo "error: output is not a 32-bit PowerPC Mach-O image" >&2
    exit 70
}


{
    echo "== PPC CoreUI bitmap-info compatibility build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "interposer_source_sha256=$SOURCE_SHA"
    echo "compat_build_id=$EXPECTED_BUILD_ID"
    echo
    echo "== file =="
    /usr/bin/file "$OUT"
    echo
    echo "== lipo =="
    /usr/bin/lipo -info "$OUT" || true
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== interpose section =="
    /usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true
    echo
    echo "== symbols =="
    /usr/bin/nm -m "$OUT" | /usr/bin/grep -E '_CGImageCreate|_rosetta_CGImageCreate' || true
    echo
    echo "== markers =="
    /usr/bin/strings "$OUT" | /usr/bin/grep -E 'PM_COREUI_IMAGE_BITMAPINFO_COMPAT_(BUILD_ID|CALL|ADAPTED|RESULT):' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: output has no __DATA,__interpose section" >&2
    exit 71
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: __DATA,__interpose is not exactly one PPC tuple" >&2
    exit 71
}
/usr/bin/nm -m "$OUT" | /usr/bin/grep -Fq '_CGImageCreate' || {
    echo "error: CGImageCreate reference missing" >&2
    exit 72
}
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: build marker missing" >&2
    exit 72
}
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:" || {
    echo "error: call marker missing" >&2
    exit 72
}
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002" || {
    echo "error: adapted marker missing" >&2
    exit 72
}
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS" || {
    echo "error: adapter pass marker missing" >&2
    exit 72
}

/usr/bin/shasum -a 256 "$OUT" > "$SHA"

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
