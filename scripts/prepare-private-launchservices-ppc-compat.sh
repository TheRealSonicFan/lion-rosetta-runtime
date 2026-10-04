#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_ROOT="${1:-$ROOT/payload/private-launchservices-ppc-compat}"
SYSTEM_FRAMEWORK="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework"
PRIVATE_FRAMEWORK="$OUT_ROOT/LaunchServices.framework"
SYSTEM_BINARY="$SYSTEM_FRAMEWORK/Versions/A/LaunchServices"
PRIVATE_BINARY="$PRIVATE_FRAMEWORK/Versions/A/LaunchServices"
PATCHER="$SCRIPT_DIR/patch-lion-launchservices-ppc-compat.py"
MANIFEST="$OUT_ROOT/manifest.txt"
PATCH_LOG="$OUT_ROOT/patch.log"

EXPECTED_SYSTEM_SHA="ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5"

die() {
    echo "error: $*" >&2
    exit 1
}

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
[ "$PRODUCT_VERSION" = "10.7.5" ] || die "requires Lion 10.7.5"
[ -d "$SYSTEM_FRAMEWORK" ] || die "missing system LaunchServices.framework"
[ -f "$SYSTEM_BINARY" ] || die "missing system LaunchServices binary"
[ -f "$PATCHER" ] || die "missing patcher: $PATCHER"

SYSTEM_SHA="$(sha256 "$SYSTEM_BINARY")"
[ "$SYSTEM_SHA" = "$EXPECTED_SYSTEM_SHA" ] || die "system LaunchServices hash mismatch: $SYSTEM_SHA"

if [ -e "$OUT_ROOT" ]; then
    die "output already exists: $OUT_ROOT (remove the private payload directory explicitly before recreating it)"
fi

/bin/mkdir -p "$OUT_ROOT" || die "could not create output root"

# Copy the framework privately. The installed framework is never modified.
/usr/bin/ditto --rsrc --extattr "$SYSTEM_FRAMEWORK" "$PRIVATE_FRAMEWORK" ||     die "could not copy LaunchServices.framework"

[ -f "$PRIVATE_BINARY" ] || die "private framework binary missing after copy"
COPIED_SHA="$(sha256 "$PRIVATE_BINARY")"
[ "$COPIED_SHA" = "$EXPECTED_SYSTEM_SHA" ] || die "private copied binary hash mismatch"

TMP_PATCHED="$OUT_ROOT/LaunchServices.patched.tmp"

/usr/bin/python "$PATCHER" --check "$PRIVATE_BINARY" > "$PATCH_LOG" 2>&1 || {
    /bin/cat "$PATCH_LOG" >&2
    die "private LaunchServices binary is not patchable"
}

/usr/bin/python "$PATCHER" "$PRIVATE_BINARY" "$TMP_PATCHED" >> "$PATCH_LOG" 2>&1 || {
    /bin/cat "$PATCH_LOG" >&2
    die "private LaunchServices patch failed"
}

/bin/mv "$TMP_PATCHED" "$PRIVATE_BINARY" || die "could not install patched private binary"
/bin/chmod 755 "$PRIVATE_BINARY" || die "could not set private binary executable mode"

PATCHED_SHA="$(sha256 "$PRIVATE_BINARY")"
[ "$PATCHED_SHA" != "$EXPECTED_SYSTEM_SHA" ] || die "patch did not change private binary"

SYSTEM_SHA_AFTER="$(sha256 "$SYSTEM_BINARY")"
[ "$SYSTEM_SHA_AFTER" = "$EXPECTED_SYSTEM_SHA" ] || die "system LaunchServices changed unexpectedly"

{
    echo "== Private Lion LaunchServices PPC compatibility payload =="
    echo "product_version=$PRODUCT_VERSION"
    echo "system_framework=$SYSTEM_FRAMEWORK"
    echo "private_framework=$PRIVATE_FRAMEWORK"
    echo "system_launchservices_sha256=$SYSTEM_SHA"
    echo "private_launchservices_sha256=$PATCHED_SHA"
    echo "system_launchservices_sha256_after=$SYSTEM_SHA_AFTER"
    echo
    echo "== private binary identity =="
    /usr/bin/file "$PRIVATE_BINARY"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -info "$PRIVATE_BINARY" || true
    fi
    echo
    echo "== private patch verification =="
    /usr/bin/python "$PATCHER" --check "$PRIVATE_BINARY"
    echo
    echo "== patch log =="
    /bin/cat "$PATCH_LOG"
} > "$MANIFEST"

echo "Created private LaunchServices compatibility payload:"
echo "  $PRIVATE_FRAMEWORK"
echo "  $MANIFEST"
echo "  $PATCH_LOG"
echo "System LaunchServices was not modified."
