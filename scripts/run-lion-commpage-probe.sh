#!/bin/bash
set -e

[ "$#" -eq 1 ] || { echo "usage: $0 /path/to/lion-commpage-probe" >&2; exit 64; }
EXE="$1"
[ -x "$EXE" ] || { echo "error: missing or non-executable: $EXE" >&2; exit 66; }

VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
case "$VERSION" in
    10.7|10.7.*) ;;
    *) echo "error: this probe is for Mac OS X 10.7.x, found $VERSION" >&2; exit 65 ;;
esac

/usr/bin/file "$EXE"
/usr/bin/lipo -verify_arch i386 "$EXE" >/dev/null 2>&1 || {
    echo "error: probe has no i386 slice" >&2
    exit 67
}

"$EXE"
