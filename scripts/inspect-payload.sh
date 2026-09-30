#!/bin/bash
set -e

[ "$#" -eq 1 ] || { echo "usage: $0 rosetta-10.6.8-runtime.tar.gz" >&2; exit 64; }
PAYLOAD="$1"
[ -f "$PAYLOAD" ] || { echo "error: payload not found: $PAYLOAD" >&2; exit 66; }

TMP="$(/usr/bin/mktemp -d /tmp/lion-rosetta-inspect.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
/usr/bin/tar -xzf "$PAYLOAD" -C "$TMP"

[ -f "$TMP/usr/libexec/oah/translate" ] || { echo "error: translate missing" >&2; exit 67; }
MANIFEST="$TMP/ROSETTA_PAYLOAD_MANIFEST.txt"
[ -f "$MANIFEST" ] || { echo "error: payload manifest missing" >&2; exit 67; }

file_size() {
    value="$(/usr/bin/stat -f %z "$1" 2>/dev/null || true)"
    case "$value" in
        ''|*[!0-9]*) value="$(/bin/ls -ln "$1" | /usr/bin/awk '{print $5}')" ;;
    esac
    echo "$value"
}

VERIFY_LIST="$TMP/.manifest-files"
/usr/bin/sed -n '/^files:$/,$p' "$MANIFEST" | /usr/bin/tail -n +2 > "$VERIFY_LIST"
VERIFY_COUNT=0
while read expected_sum expected_size path; do
    [ -n "$expected_sum" ] || continue
    [ -n "$path" ] || { echo "error: malformed manifest entry" >&2; exit 68; }
    file="$TMP$path"
    [ -f "$file" ] || { echo "error: manifest file missing from payload: $path" >&2; exit 68; }
    actual_sum="$(/usr/bin/shasum -a 256 "$file" | /usr/bin/awk '{print $1}')"
    actual_size="$(file_size "$file")"
    [ "$actual_sum" = "$expected_sum" ] || { echo "error: SHA-256 mismatch: $path" >&2; exit 68; }
    [ "$actual_size" = "$expected_size" ] || { echo "error: size mismatch: $path" >&2; exit 68; }
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
done < "$VERIFY_LIST"

echo "Payload SHA-256:"
/usr/bin/shasum -a 256 "$PAYLOAD"
echo "Manifest verification: $VERIFY_COUNT files OK"
echo
/bin/cat "$MANIFEST"

echo
echo "OAH executables:"
/usr/bin/find "$TMP/usr/libexec/oah" -type f -perm +111 -print | while read f; do
    echo "-- ${f#$TMP}"
    /usr/bin/file "$f" || true
    /usr/bin/otool -L "$f" 2>/dev/null || true
done
