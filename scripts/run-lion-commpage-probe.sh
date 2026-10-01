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

is_i386_macho() {
    file="$1"
    [ -f "$file" ] || return 1

    # Lion/Snow Leopard lipo accepts the input file before -verify_arch.
    # Try that form first, then the alternate ordering used by newer tools.
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo "$file" -verify_arch i386 >/dev/null 2>&1 && return 0
        /usr/bin/lipo -verify_arch i386 "$file" >/dev/null 2>&1 && return 0

        info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
        echo "$info" | /usr/bin/grep -Eiq '(^|[[:space:]:])i386([[:space:]]|$)' && return 0
    fi

    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq 'Mach-O.*[[:space:]]i386([[:space:]]|$)' && return 0

    return 1
}

/usr/bin/file "$EXE"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" || true
fi

is_i386_macho "$EXE" || {
    echo "error: probe has no i386 slice" >&2
    exit 67
}

"$EXE"
