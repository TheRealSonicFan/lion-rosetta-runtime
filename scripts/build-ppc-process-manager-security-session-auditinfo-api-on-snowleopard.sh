#!/bin/bash
set -e

OUT_EXE="${1:-./ppc-process-manager-security-session-auditinfo-api-private-dyld}"
OUT_INTERPOSER="${2:-./ppc-process-manager-security-session-auditinfo-api.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE_SRC="$ROOT/tests/ppc-process-manager-security-session-rpc-probe.c"
INTERPOSER_SRC="$ROOT/tests/ppc-process-manager-security-session-auditinfo-api-interposer.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

EXE_INFO="$OUT_EXE.info.txt"
EXE_SHA="$OUT_EXE.sha256"
INTERPOSER_INFO="$OUT_INTERPOSER.info.txt"
INTERPOSER_SHA="$OUT_INTERPOSER.sha256"

CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$PROBE_SRC" ] || { echo "error: missing source: $PROBE_SRC" >&2; exit 66; }
[ -f "$INTERPOSER_SRC" ] || { echo "error: missing source: $INTERPOSER_SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$PROBE_SRC" -framework Security -o "$OUT_EXE"
/bin/chmod +x "$OUT_EXE"
/usr/bin/python "$PATCH_DYLINKER" "$OUT_EXE" /usr/oah/dyld

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     -dynamiclib "$INTERPOSER_SRC" -framework Security -o "$OUT_INTERPOSER"

/usr/bin/lipo -verify_arch ppc "$OUT_EXE"
/usr/bin/lipo -verify_arch ppc "$OUT_INTERPOSER"

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
    echo "error: interposer section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: expected exactly one PPC interpose tuple" >&2
    exit 72
}

/usr/bin/strings "$OUT_INTERPOSER" | /usr/bin/grep -Fq     'PM_SECURITY_SESSION_API_COMPAT_BUILD_ID:security-session-auditinfo-api-v1' || {
    echo "error: interposer build marker missing" >&2
    exit 72
}

for sym in _SessionGetInfo _getaudit_addr; do
    /usr/bin/nm -u "$OUT_INTERPOSER" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: interposer does not import $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -u "$OUT_INTERPOSER" | /usr/bin/grep -Eq '(^|[[:space:]])_dlsym$'; then
    echo "error: interposer unexpectedly imports dlsym" >&2
    exit 72
fi

{
    echo "== PPC Security SessionGetInfo AuditInfo adapter probe =="
    echo "compiler=$CC_SELECTED"
    echo "source=$PROBE_SRC"
    /usr/bin/file "$OUT_EXE"
    /usr/bin/lipo -info "$OUT_EXE" || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    /usr/bin/otool -l "$OUT_EXE" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT_EXE"
} > "$EXE_INFO"

{
    echo "== PPC Security SessionGetInfo AuditInfo adapter interposer =="
    echo "compiler=$CC_SELECTED"
    echo "source=$INTERPOSER_SRC"
    echo "build_id=security-session-auditinfo-api-v1"
    /usr/bin/file "$OUT_INTERPOSER"
    /usr/bin/lipo -info "$OUT_INTERPOSER" || true
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
