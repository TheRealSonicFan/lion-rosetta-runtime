#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-$ROOT/payload/rosetta-10.6.8-runtime.tar.gz}"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
case "$PRODUCT_VERSION" in
    10.6.8) ;;
    *) echo "error: collector requires Mac OS X 10.6.8 (found: $PRODUCT_VERSION)" >&2; exit 65 ;;
esac

[ -d /usr/libexec/oah ] || { echo "error: /usr/libexec/oah is missing; Rosetta may not be installed" >&2; exit 66; }
[ -f /usr/libexec/oah/translate ] || { echo "error: /usr/libexec/oah/translate is missing" >&2; exit 66; }

TMP="$(/usr/bin/mktemp -d /tmp/lion-rosetta-collect.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
STAGE="$TMP/root"
/bin/mkdir -p "$STAGE/usr/libexec" "$STAGE/private/var/db/dyld" "$STAGE/private/var/db/receipts" "$STAGE/Library/Preferences" "$STAGE/System/Library"

copy_path() {
    src="$1"
    if [ -e "$src" ] || [ -L "$src" ]; then
        parent="$STAGE$(dirname "$src")"
        /bin/mkdir -p "$parent"
        /usr/bin/ditto --rsrc --extattr "$src" "$STAGE$src"
        return 0
    fi
    return 1
}

sha256_file() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

file_size() {
    value="$(/usr/bin/stat -f %z "$1" 2>/dev/null || true)"
    case "$value" in
        ''|*[!0-9]*) value="$(/bin/ls -ln "$1" | /usr/bin/awk '{print $5}')" ;;
    esac
    echo "$value"
}

verify_staged_file() {
    src="$1"
    dst="$STAGE$src"
    [ -f "$src" ] || return 0
    [ -f "$dst" ] || { echo "error: staged copy missing: $src" >&2; exit 68; }
    src_sum="$(sha256_file "$src")"
    dst_sum="$(sha256_file "$dst")"
    if [ "$src_sum" != "$dst_sum" ]; then
        echo "error: source changed while collecting or staged copy differs: $src" >&2
        echo "       source=$src_sum" >&2
        echo "       staged=$dst_sum" >&2
        exit 68
    fi
}

# Preserve the complete OAH directory so companion binaries/Shims are not guessed one by one.
copy_path /usr/libexec/oah

# Metadata and ancillary Rosetta-era state found on Snow Leopard installations.
copy_path /private/var/db/RosettaVersion.plist || true
copy_path /Library/Preferences/com.apple.ReportMessages.domains || true

# translate contains an absolute reference to /System/Library/OAH/nbb/.  Preserve the
# complete /System/Library/OAH tree if the source system has it. On the audited 10K549
# source used for this project the path was absent, so it is optional rather than required.
copy_path /System/Library/OAH || true

# Capture the 10.6 Rosetta shared cache. Lion no longer carries PPC slices for
# many system frameworks, so this cache is needed for the first compatibility test.
for f in /private/var/db/dyld/dyld_shared_cache_rosetta /private/var/db/dyld/dyld_shared_cache_rosetta.map; do
    copy_path "$f" || true
done

# Verify critical files after copying. The Rosetta cache can be rebuilt by Snow Leopard;
# refuse an archive if a file changed while it was being collected.
for f in \
    /usr/libexec/oah/translate \
    /private/var/db/dyld/dyld_shared_cache_rosetta \
    /private/var/db/dyld/dyld_shared_cache_rosetta.map \
    /Library/Preferences/com.apple.ReportMessages.domains; do
    verify_staged_file "$f"
done

# Receipts are diagnostic/provenance data only.
for f in /private/var/db/receipts/*Rosetta* /private/var/db/receipts/*rosetta*; do
    if [ -f "$f" ]; then
        copy_path "$f" || true
    fi
done

# Record package-owned paths as reported by the source installation. This lets us
# compare a payload against the real package receipts without redistributing files.
PKG_LIST="$STAGE/ROSETTA_PACKAGE_FILES.txt"
: > "$PKG_LIST"
if [ -x /usr/sbin/pkgutil ]; then
    for pkg in com.apple.pkg.Rosetta com.apple.pkg.update.rosetta.10.6.8.combo; do
        if /usr/sbin/pkgutil --pkg-info "$pkg" >/dev/null 2>&1; then
            echo "[$pkg]" >> "$PKG_LIST"
            /usr/sbin/pkgutil --files "$pkg" 2>/dev/null | /usr/bin/sort >> "$PKG_LIST" || true
            echo >> "$PKG_LIST"
        fi
    done
fi

MANIFEST="$STAGE/ROSETTA_PAYLOAD_MANIFEST.txt"
{
    echo "source_product_version=$PRODUCT_VERSION"
    echo "source_build=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
    echo "collected_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ -f /private/var/db/dyld/dyld_shared_cache_rosetta ]; then
        echo "source_rosetta_cache_mtime_epoch=$(/usr/bin/stat -f %m /private/var/db/dyld/dyld_shared_cache_rosetta 2>/dev/null || true)"
        echo "source_rosetta_cache_size=$(file_size /private/var/db/dyld/dyld_shared_cache_rosetta)"
    fi
    echo
    echo "files:"
    /usr/bin/find "$STAGE" -type f ! -name ROSETTA_PAYLOAD_MANIFEST.txt -print | while read f; do
        rel="${f#$STAGE}"
        sum="$(sha256_file "$f")"
        size="$(file_size "$f")"
        echo "$sum  $size  $rel"
    done | /usr/bin/sort
} > "$MANIFEST"

OUT_DIR="$(dirname "$OUT")"
OUT_BASE="$(basename "$OUT")"
/bin/mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
OUT="$OUT_DIR/$OUT_BASE"
(
    cd "$STAGE"
    /usr/bin/tar -czf "$OUT" .
)
/usr/bin/shasum -a 256 "$OUT" > "$OUT.sha256"

echo "Created: $OUT"
echo "Checksum: $OUT.sha256"
echo "Do not commit this payload to a public repository."
