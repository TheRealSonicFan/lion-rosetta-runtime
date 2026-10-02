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

detect_ppc_arch() {
    file="$1"

    # The validated Snow Leopard 10.6.8 dyld uses the G4-specific ppc7400
    # subtype. The Lion Rosetta core independently shows a requested PowerPC
    # CPU subtype of 0x0a (10), which is CPU_SUBTYPE_POWERPC_7400.
    #
    # Older Apple lipo releases also differ in accepted -verify_arch ordering,
    # so try both forms before falling back to parsing lipo -info.
    for arch in ppc7400 ppc; do
        if /usr/bin/lipo "$file" -verify_arch "$arch" >/dev/null 2>&1 || \
           /usr/bin/lipo -verify_arch "$arch" "$file" >/dev/null 2>&1; then
            echo "$arch"
            return 0
        fi
    done

    info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
    if echo "$info" | /usr/bin/grep -Eiq '(^|[[:space:]:])ppc7400([[:space:]]|$)'; then
        echo "ppc7400"
        return 0
    fi
    if echo "$info" | /usr/bin/grep -Eiq '(^|[[:space:]:])ppc([[:space:]]|$)'; then
        echo "ppc"
        return 0
    fi
    return 1
}

PPC_ARCH="$(detect_ppc_arch "$SRC" || true)"
if [ -z "$PPC_ARCH" ]; then
    echo "error: Snow Leopard $SRC has no supported 32-bit PowerPC dyld slice" >&2
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
    echo "selected_ppc_arch=$PPC_ARCH"
    echo "ppc_verify=PASS"
    echo
    echo "== PPC Mach-O header =="
    /usr/bin/otool -hv -arch "$PPC_ARCH" "$SRC" 2>&1 || true
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

COPIED_PPC_ARCH="$(detect_ppc_arch "$OUT" || true)"
[ -n "$COPIED_PPC_ARCH" ] || {
    echo "error: copied dyld no longer verifies as 32-bit PowerPC-capable" >&2
    exit 68
}

/usr/bin/shasum -a 256 "$OUT" > "$SUM"

echo "Validated Snow Leopard PPC-capable dyld ($PPC_ARCH)."
echo "Private binary: $OUT"
echo "Audit report:   $INFO"
echo "Checksum:       $SUM"
echo "Do not commit the binary or checksum/report output to this public repository."
