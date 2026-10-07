#!/bin/bash
set -e

OUT_EXE="${1:-./ppc-process-manager-security-session-bootstrap-compat-private-dyld}"
OUT_INTERPOSER="${2:-./ppc-process-manager-security-session-bootstrap-compat.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE_SRC="$ROOT/tests/ppc-process-manager-security-session-rpc-probe.c"
INTERPOSER_SRC="$ROOT/tests/ppc-process-manager-security-session-bootstrap-compat-interposer.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

EXE_INFO="$OUT_EXE.info.txt"
EXE_SHA="$OUT_EXE.sha256"
INTERPOSER_INFO="$OUT_INTERPOSER.info.txt"
INTERPOSER_SHA="$OUT_INTERPOSER.sha256"

TMP_SRC="$(/usr/bin/mktemp /tmp/ppc-security-bootstrap-compat-build.XXXXXX.c)"
TMP_BIN="$(/usr/bin/mktemp /tmp/ppc-security-bootstrap-compat-build.XXXXXX)"
TMP_LOG="$(/usr/bin/mktemp /tmp/ppc-security-bootstrap-compat-build.XXXXXX.log)"
trap 'rm -f "$TMP_SRC" "$TMP_BIN" "$TMP_LOG"' EXIT HUP INT TERM

[ -f "$PROBE_SRC" ] || { echo "error: missing source: $PROBE_SRC" >&2; exit 66; }
[ -f "$INTERPOSER_SRC" ] || { echo "error: missing source: $INTERPOSER_SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper: $PATCH_DYLINKER" >&2; exit 66; }

cat > "$TMP_SRC" <<'SRC'
#include <Security/AuthSession.h>
int main(void) {
    SecuritySessionId sid = noSecuritySession;
    SessionAttributeBits attrs = 0;
    return SessionGetInfo(callerSecuritySession, &sid, &attrs) == noErr ? 0 : 1;
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

    /bin/rm -f "$TMP_BIN"
    if "$compiler" -arch ppc -mmacosx-version-min=10.5         "$TMP_SRC" -framework Security -o "$TMP_BIN" >"$TMP_LOG" 2>&1; then
        if [ -f "$TMP_BIN" ] && is_ppc32_macho "$TMP_BIN"; then
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
    echo "error: no installed compiler/toolchain could build a 32-bit PPC Security compatibility probe" >&2
    exit 69
}

echo "Using PowerPC-capable compiler: $CC_SELECTED"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$PROBE_SRC" -framework Security -o "$OUT_EXE"
/bin/chmod +x "$OUT_EXE"
/usr/bin/python "$PATCH_DYLINKER" "$OUT_EXE" /usr/oah/dyld

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     -dynamiclib "$INTERPOSER_SRC" -o "$OUT_INTERPOSER"

is_ppc32_macho "$OUT_EXE" || {
    echo "error: probe is not a 32-bit PowerPC Mach-O executable" >&2
    exit 70
}
is_ppc32_macho "$OUT_INTERPOSER" || {
    echo "error: compatibility interposer is not a 32-bit PowerPC Mach-O dylib" >&2
    exit 70
}

OT="$(/usr/bin/otool -l "$OUT_EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/otool -L "$OUT_EXE" | /usr/bin/grep -Fq     '/System/Library/Frameworks/Security.framework/Versions/A/Security' || {
    echo "error: probe does not link Security" >&2
    exit 72
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT_INTERPOSER" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: compatibility interposer __interpose section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: compatibility interposer does not contain exactly two PPC interpose tuples" >&2
    exit 72
}

/usr/bin/strings "$OUT_INTERPOSER" | /usr/bin/grep -Fq     'PM_SECURITY_COMPAT_BUILD_ID:security-session-bootstrap-compat-v1' || {
    echo "error: compatibility interposer build marker missing" >&2
    exit 72
}

for sym in _bootstrap_look_up _mach_msg _mig_get_reply_port; do
    /usr/bin/nm -u "$OUT_INTERPOSER" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: compatibility interposer does not import $sym" >&2
        exit 72
    }
done
if /usr/bin/nm -u "$OUT_INTERPOSER" | /usr/bin/grep -Eq '(^|[[:space:]])_dlsym$'; then
    echo "error: compatibility interposer unexpectedly imports dlsym" >&2
    exit 72
fi

{
    echo "== PPC Security session bootstrap compatibility probe =="
    echo "compiler=$CC_SELECTED"
    echo "source=$PROBE_SRC"
    echo
    /usr/bin/file "$OUT_EXE"
    if [ -x /usr/bin/lipo ]; then /usr/bin/lipo -info "$OUT_EXE" || true; fi
    echo
    echo "== LC_LOAD_DYLINKER =="
    /usr/bin/otool -l "$OUT_EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT_EXE"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT_EXE"
} > "$EXE_INFO"

{
    echo "== PPC Security session bootstrap compatibility interposer =="
    echo "compiler=$CC_SELECTED"
    echo "source=$INTERPOSER_SRC"
    echo "build_id=security-session-bootstrap-compat-v1"
    echo
    /usr/bin/file "$OUT_INTERPOSER"
    if [ -x /usr/bin/lipo ]; then /usr/bin/lipo -info "$OUT_INTERPOSER" || true; fi
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== undefined symbols =="
    /usr/bin/nm -u "$OUT_INTERPOSER"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT_INTERPOSER"
} > "$INTERPOSER_INFO"

/usr/bin/shasum -a 256 "$OUT_EXE" > "$EXE_SHA"
/usr/bin/shasum -a 256 "$OUT_INTERPOSER" > "$INTERPOSER_SHA"

echo "Created:"
echo "  $OUT_EXE"
echo "  $EXE_INFO"
echo "  $EXE_SHA"
echo "  $OUT_INTERPOSER"
echo "  $INTERPOSER_INFO"
echo "  $INTERPOSER_SHA"
