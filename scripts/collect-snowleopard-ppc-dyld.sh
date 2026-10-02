#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="/usr/lib/dyld"
OUT="${1:-$ROOT/payload/snowleopard-10.6.8-dyld}"
INFO="$OUT.info.txt"
SUM="$OUT.sha256"

PRODUCT_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
case "$PRODUCT_VERSION" in
    10.6.8) ;;
    *) echo "error: collector requires Mac OS X 10.6.8 (found: $PRODUCT_VERSION)" >&2; exit 65 ;;
esac

[ -f "$SRC" ] || { echo "error: missing $SRC" >&2; exit 66; }
[ -x /usr/bin/lipo ] || { echo "error: /usr/bin/lipo is required" >&2; exit 69; }

has_ppc_arch() {
    file="$1"

    # Older Apple lipo releases differ in accepted -verify_arch ordering.
    /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0

    info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
    echo "$info" | /usr/bin/grep -Eiq '(^|[[:space:]:])ppc([[:space:]]|$)'
}

if ! has_ppc_arch "$SRC"; then
    echo "error: Snow Leopard $SRC has no 32-bit ppc slice" >&2
    /usr/bin/file "$SRC" >&2 || true
    /usr/bin/lipo -info "$SRC" >&2 || true
    exit 67
fi

if [ "$OUT" = "$SRC" ]; then
    echo "error: refusing to overwrite $SRC" >&2
    exit 64
fi

/bin/mkdir -p "$(dirname "$OUT")"

{
    echo "source_product_version=$PRODUCT_VERSION"
    echo "source_build=$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
    echo "source_path=$SRC"
    echo
    echo "== file =="
    /usr/bin/file "$SRC" 2>&1 || true
    echo
    echo "== lipo =="
    /usr/bin/lipo -info "$SRC" 2>&1 || true
    if /usr/bin/lipo "$SRC" -verify_arch ppc >/dev/null 2>&1 ||        /usr/bin/lipo -verify_arch ppc "$SRC" >/dev/null 2>&1; then
        echo "ppc_verify=PASS"
    else
        echo "ppc_verify=FAIL"
    fi
    echo
    echo "== PPC Mach-O header =="
    /usr/bin/otool -hv -arch ppc "$SRC" 2>&1 || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$SRC" 2>&1 || true
} > "$INFO"

/usr/bin/ditto --rsrc --extattr "$SRC" "$OUT"

SRC_SUM="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"
OUT_SUM="$(/usr/bin/shasum -a 256 "$OUT" | /usr/bin/awk '{print $1}')"
if [ "$SRC_SUM" != "$OUT_SUM" ]; then
    echo "error: copied dyld hash differs from source" >&2
    echo "       source=$SRC_SUM" >&2
    echo "       copied=$OUT_SUM" >&2
    exit 68
fi

has_ppc_arch "$OUT" || {
    echo "error: copied dyld no longer verifies as 32-bit ppc-capable" >&2
    exit 68
}

/usr/bin/shasum -a 256 "$OUT" > "$SUM"

echo "Validated Snow Leopard PPC-capable dyld."
echo "Private binary: $OUT"
echo "Audit report:   $INFO"
echo "Checksum:       $SUM"
echo "Do not commit the binary or checksum/report output to this public repository."
