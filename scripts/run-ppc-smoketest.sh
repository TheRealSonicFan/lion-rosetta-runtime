#!/bin/bash
set -e

[ "$#" -ge 1 ] || { echo "usage: $0 /path/to/ppc-executable [args ...]" >&2; exit 64; }
EXE="$1"
shift
[ -x "$EXE" ] || { echo "error: executable not found or not executable: $EXE" >&2; exit 66; }

DESC="$(/usr/bin/file "$EXE")"
echo "$DESC"
echo "$DESC" | /usr/bin/grep -qi 'PowerPC' || {
    echo "error: file(1) does not identify the input as PowerPC" >&2
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
