#!/bin/bash
set -e

OUT="${1:-./ppc-smoketest}"
TMP="$(/usr/bin/mktemp /tmp/ppc-smoketest.XXXXXX.c)"
trap 'rm -f "$TMP"' EXIT HUP INT TERM
cat > "$TMP" <<'SRC'
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
int main(void) {
    printf("Rosetta PPC smoke test: pid=%ld\n", (long)getpid());
    return 0;
}
SRC

CC=""
for c in /usr/bin/gcc-4.2 /usr/bin/gcc /usr/bin/cc; do
    if [ -x "$c" ]; then CC="$c"; break; fi
done
[ -n "$CC" ] || { echo "error: no C compiler found" >&2; exit 69; }

"$CC" -arch ppc -mmacosx-version-min=10.4 "$TMP" -o "$OUT"
/bin/chmod +x "$OUT"
/usr/bin/file "$OUT"
echo "Created: $OUT"
