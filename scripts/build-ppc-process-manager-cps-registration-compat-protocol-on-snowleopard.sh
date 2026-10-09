#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-cps-registration-compat-protocol-private-dyld}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-cps-registration-compat-protocol-adapter.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
EXPECTED_BUILD_ID="cps-registration-compat-protocol-v1"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper: $PATCH_DYLINKER" >&2; exit 66; }
/usr/bin/grep -Fq "$EXPECTED_BUILD_ID" "$SRC" || {
    echo "error: stale source; pull current runtime main" >&2
    exit 66
}

/bin/rm -f "$OUT" "$INFO" "$SHA"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 "$SRC" -o "$OUT"
/bin/chmod 755 "$OUT"

/usr/bin/python "$PATCH_DYLINKER" "$OUT" /usr/oah/dyld

if /usr/bin/lipo -verify_arch ppc "$OUT" >/dev/null 2>&1; then
    :
elif /usr/bin/lipo "$OUT" -verify_arch ppc >/dev/null 2>&1; then
    :
else
    echo "error: output is not 32-bit PPC" >&2
    exit 70
fi

OT="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

for marker in     "PM_CPS_REGISTRATION_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID"     'PM_CPS_REGISTRATION_COMPAT_SNOW_LAYOUT:'     'PM_CPS_REGISTRATION_COMPAT_CAPTURED_ERROR_MODEL:'     'PM_CPS_REGISTRATION_COMPAT_REQUEST_POLICY:'     'PM_CPS_REGISTRATION_COMPAT_REPLY_POLICY:'     'PM_CPS_REGISTRATION_COMPAT_RESULT:LION_POLICY_PROOF_PASS'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required marker missing: $marker" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"
SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"

{
    echo "== PPC CPS registration compatibility protocol proof build =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "source_sha256=$SOURCE_SHA"
    echo "build_id=$EXPECTED_BUILD_ID"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== build marker =="
    /usr/bin/strings "$OUT" | /usr/bin/grep -F "PM_CPS_REGISTRATION_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

/usr/bin/shasum -a 256 "$OUT" > "$SHA"

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
