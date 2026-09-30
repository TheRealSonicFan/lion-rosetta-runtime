#!/bin/bash
set -e

[ "$#" -eq 1 ] || { echo "usage: $0 rosetta-10.6.8-runtime.tar.gz" >&2; exit 64; }
PAYLOAD="$1"
[ -f "$PAYLOAD" ] || { echo "error: payload not found: $PAYLOAD" >&2; exit 66; }

TMP="$(/usr/bin/mktemp -d /tmp/lion-rosetta-inspect.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
/usr/bin/tar -xzf "$PAYLOAD" -C "$TMP"

[ -f "$TMP/usr/libexec/oah/translate" ] || { echo "error: translate missing" >&2; exit 67; }
[ -f "$TMP/ROSETTA_PAYLOAD_MANIFEST.txt" ] || { echo "warning: manifest missing" >&2; }

echo "Payload SHA-256:"
/usr/bin/shasum -a 256 "$PAYLOAD"
echo
if [ -f "$TMP/ROSETTA_PAYLOAD_MANIFEST.txt" ]; then
    /bin/cat "$TMP/ROSETTA_PAYLOAD_MANIFEST.txt"
fi

echo
echo "OAH executables:"
/usr/bin/find "$TMP/usr/libexec/oah" -type f -perm +111 -print | while read f; do
    echo "-- ${f#$TMP}"
    /usr/bin/file "$f" || true
    /usr/bin/otool -L "$f" 2>/dev/null || true
 done
