#!/bin/bash
set -e

[ "$#" -ge 1 ] || { echo "usage: $0 /path/to/ppc-executable [args ...]" >&2; exit 64; }
EXE="$1"
shift
[ -x "$EXE" ] || { echo "error: executable not found or not executable: $EXE" >&2; exit 66; }

is_ppc32_macho() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
    fi

    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

DESC="$(/usr/bin/file "$EXE")"
echo "$DESC"
if [ -x /usr/bin/lipo ]; then
    /usr/bin/lipo -info "$EXE" || true
fi

is_ppc32_macho "$EXE" || {
    echo "error: input is not a 32-bit PowerPC Mach-O executable" >&2
    exit 67
}

echo "Architecture handler:"
/usr/sbin/sysctl kern.exec.archhandler.powerpc || true

echo "Executing test..."
set +e
"$EXE" "$@"
RC=$?
set -e
echo "exit status: $RC"
exit $RC
