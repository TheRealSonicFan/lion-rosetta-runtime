#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c"
EXPECTED_COMPAT_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v4"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
TMP_DYLIB="$(/usr/bin/mktemp /tmp/ppc-coreservices-sessioninit-compat.XXXXXX.dylib)"
TMP_LOG="$(/usr/bin/mktemp /tmp/ppc-coreservices-sessioninit-compat.XXXXXX.log)"
BUILD_COMPLETE=0
cleanup() {
    rc=$?
    trap - EXIT
    /bin/rm -f "$TMP_DYLIB" "$TMP_LOG"
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$OUT" "$INFO" "$SHA"
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

/bin/rm -f "$OUT" "$INFO" "$SHA"

[ -f "$SRC" ] || { echo "error: missing interposer source: $SRC" >&2; exit 66; }
/usr/bin/grep -Fq "#define COMPAT_BUILD_ID \"$EXPECTED_COMPAT_BUILD_ID\"" "$SRC" || {
    echo "error: stale CoreServices compatibility interposer source; pull current runtime main" >&2
    exit 66
}

resolve_compiler() {
    candidate="$1"
    [ -n "$candidate" ] || return 1
    if [ -x "$candidate" ]; then echo "$candidate"; return 0; fi
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
    if "$compiler" -arch ppc -mmacosx-version-min=10.5 -dynamiclib         "$SRC"         -install_name "@loader_path/$(/usr/bin/basename "$OUT")"         -o "$TMP_DYLIB" >"$TMP_LOG" 2>&1; then
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
    for c in         /Developer-3.2.6/usr/bin/gcc-4.2         /Developer-3.2.6/usr/bin/gcc-4.0         /Developer/usr/bin/gcc-4.2         /Developer/usr/bin/gcc-4.0         /usr/bin/gcc-4.2 /usr/bin/gcc-4.0 /usr/bin/gcc /usr/bin/cc; do
        echo "Probing compiler: $c" >&2
        if probe_compiler "$c"; then break; fi
    done
fi

[ -n "$CC_SELECTED" ] || {
    echo "error: no installed compiler/toolchain could build the PPC CoreServices compatibility interposer" >&2
    exit 69
}

echo "Using PowerPC-capable compiler: $CC_SELECTED"
"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib     "$SRC"     -install_name "@loader_path/$(/usr/bin/basename "$OUT")"     -o "$OUT"
/bin/chmod 755 "$OUT"

is_ppc32_macho "$OUT" || {
    echo "error: interposer is not a 32-bit PowerPC Mach-O image" >&2
    exit 70
}

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"
SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"

{
    echo "== PPC Process Manager CoreServices + SessionInit compatibility interposer build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "interposer_source_sha256=$SOURCE_SHA"
    echo "compat_build_id=$EXPECTED_COMPAT_BUILD_ID"
    echo
    echo "== file =="
    /usr/bin/file "$OUT"
    echo
    echo "== lipo =="
    if [ -x /usr/bin/lipo ]; then /usr/bin/lipo -info "$OUT" || true; fi
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== interpose section =="
    /usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true
    echo
    echo "== required imports/symbols =="
    /usr/bin/nm -m "$OUT" | /usr/bin/grep -E 'bootstrap_look_up2|mach_msg|mig_get_reply_port|rosetta_bootstrap_look_up2|rosetta_mach_msg' || true
    echo
    echo "== required markers =="
    /usr/bin/strings "$OUT" | /usr/bin/grep -E 'PM_CORESERVICES_COMPAT_BUILD_ID|PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT|PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: interposer does not contain a __DATA,__interpose section" >&2
    exit 71
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: interposer __DATA,__interpose section is not exactly two PPC tuples" >&2
    exit 71
}

for sym in _bootstrap_look_up2 _mach_msg _mig_get_reply_port _rosetta_bootstrap_look_up2 _rosetta_mach_msg; do
    /usr/bin/nm -m "$OUT" | /usr/bin/grep -Fq "$sym" || {
        echo "error: interposer does not reference $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -m "$OUT" | /usr/bin/grep -Fq '_dlsym'; then
    echo "error: interposer unexpectedly imports _dlsym" >&2
    exit 72
fi

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_COMPAT_BUILD_ID" || {
    echo "error: CoreServices compatibility build marker is missing" >&2
    exit 72
}

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SERVERCHECKIN_ADAPTER_RESULT:PASS' || {
    echo "error: ServerCheckin adapter success marker is missing" >&2
    exit 72
}

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS' || {
    echo "error: SessionInit adapter success marker is missing" >&2
    exit 72
}

/usr/bin/shasum -a 256 "$OUT" > "$SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
