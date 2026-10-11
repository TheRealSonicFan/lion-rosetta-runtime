#!/bin/bash
set -e

OUT="${1:-./SnowLeopard-HIToolbox-Extras.rsrc}"
SOURCE="/System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Resources/Extras.rsrc"
EXPECTED_SHA="a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197"
EXPECTED_SIZE="5425538"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: stage Extras.rsrc on Snow Leopard 10.6.8" >&2
    exit 65
}
[ -f "$SOURCE" ] || {
    echo "error: missing Snow Leopard HIToolbox Extras.rsrc: $SOURCE" >&2
    exit 66
}

sha256() { /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'; }
filesize() { /usr/bin/stat -f '%z' "$1"; }

SOURCE_SHA="$(sha256 "$SOURCE")"
SOURCE_SIZE="$(filesize "$SOURCE")"
[ "$SOURCE_SHA" = "$EXPECTED_SHA" ] || {
    echo "error: Snow Leopard Extras.rsrc hash mismatch" >&2
    exit 68
}
[ "$SOURCE_SIZE" = "$EXPECTED_SIZE" ] || {
    echo "error: Snow Leopard Extras.rsrc size mismatch" >&2
    exit 68
}

/bin/cp -p "$SOURCE" "$OUT"
/bin/chmod 644 "$OUT"

COPIED_SHA="$(sha256 "$OUT")"
COPIED_SIZE="$(filesize "$OUT")"
[ "$COPIED_SHA" = "$EXPECTED_SHA" ] || {
    echo "error: staged Extras.rsrc hash mismatch" >&2
    exit 68
}
[ "$COPIED_SIZE" = "$EXPECTED_SIZE" ] || {
    echo "error: staged Extras.rsrc size mismatch" >&2
    exit 68
}

{
    echo "== Snow Leopard HIToolbox Extras.rsrc staging =="
    echo "product_version=$(/usr/bin/sw_vers -productVersion)"
    echo "build_version=$(/usr/bin/sw_vers -buildVersion)"
    echo "source=$SOURCE"
    echo "source_sha256=$SOURCE_SHA"
    echo "source_size=$SOURCE_SIZE"
    echo "output=$OUT"
    echo "output_sha256=$COPIED_SHA"
    echo "output_size=$COPIED_SIZE"
    echo "expected_sha256=$EXPECTED_SHA"
    echo "exact_match=YES"
    echo "note=locally copied Apple resource; do not commit to the repository"
} > "$OUT.info.txt"

/usr/bin/shasum -a 256 "$OUT" > "$OUT.sha256"

echo "Created local, untracked resource artifacts:"
echo "  $OUT"
echo "  $OUT.info.txt"
echo "  $OUT.sha256"
