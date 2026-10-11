#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-hitoolbox-extras-resource-compat-interposer.c"
OUT="${1:-./ppc-hitoolbox-extras-resource-compat.dylib}"
EXPECTED_BUILD_ID="hitoolbox-extras-resource-compat-v1"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: build PPC HIToolbox Extras compatibility dylib on Snow Leopard 10.6.8" >&2
    exit 65
}
[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
[ -f "$SRC" ] || {
    echo "error: missing source: $SRC" >&2
    exit 66
}

/bin/rm -f "$OUT" "$OUT.sha256" "$OUT.info.txt"

"$CC_SELECTED" -arch ppc -std=gnu99 -Wall -Wextra \
    -mmacosx-version-min=10.5 -dynamiclib \
    "$SRC" \
    -framework CoreFoundation \
    -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
    -o "$OUT"

/bin/chmod 755 "$OUT"

INFO="$(/usr/bin/lipo -info "$OUT" 2>/dev/null || true)"
case "$INFO" in
    *" is architecture: ppc"*|*" is architecture: ppc7400"*|*" is architecture: ppc7450"*|*" is architecture: ppc970"*) ;;
    *)
        echo "error: compatibility dylib is not thin 32-bit PPC" >&2
        /usr/bin/file "$OUT" >&2 || true
        /usr/bin/lipo -info "$OUT" >&2 || true
        exit 70
        ;;
esac

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_HITOOLBOX_EXTRAS_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: compatibility build marker missing" >&2
    exit 71
}

for marker in PM_HITOOLBOX_EXTRAS_COMPAT_TARGET: PM_HITOOLBOX_EXTRAS_COMPAT_RESULT:
do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: compatibility marker missing: $marker" >&2
        exit 71
    }
done

UNDEFINED="$(/usr/bin/nm -u "$OUT")"
for sym in _CFBundleCopyResourceURLForLocalization _CFBundleGetIdentifier _CFURLCreateFromFileSystemRepresentation
do
    echo "$UNDEFINED" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: compatibility dylib missing import $sym" >&2
        exit 72
    }
done

if echo "$UNDEFINED" | /usr/bin/grep -Eq '(^|[[:space:]])_dlsym$'; then
    echo "error: compatibility dylib unexpectedly imports dlsym" >&2
    exit 72
fi

INTERPOSE_SIZE="$(/usr/bin/size -m "$OUT" 2>/dev/null | /usr/bin/awk '
    /Section __interpose/ { found=1; next }
    found && /size/ {
        gsub(/[^0-9]/, "", $2)
        print $2
        exit
    }')"
if [ -n "$INTERPOSE_SIZE" ] && [ "$INTERPOSE_SIZE" != "8" ]; then
    echo "error: expected one PPC __interpose tuple (8 bytes), got $INTERPOSE_SIZE" >&2
    exit 72
fi

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC HIToolbox Extras resource compatibility =="
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "compiler=$CC_SELECTED"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "source=$SRC"
    /usr/bin/shasum -a 256 "$SRC"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo "interpose_size=${INTERPOSE_SIZE:-UNAVAILABLE}"
    echo
    echo "== Undefined imports =="
    echo "$UNDEFINED"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$OUT.info.txt"

/usr/bin/shasum -a 256 "$OUT" > "$OUT.sha256"

echo "Created:"
echo "  $OUT"
echo "  $OUT.info.txt"
echo "  $OUT.sha256"
