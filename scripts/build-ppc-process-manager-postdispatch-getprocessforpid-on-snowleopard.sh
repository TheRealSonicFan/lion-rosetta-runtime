#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-postdispatch-getprocessforpid-private-dyld}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-postdispatch-getprocessforpid.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }

/bin/rm -f "$OUT" "$INFO" "$SHA"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$SRC" -framework Carbon -o "$OUT"
/bin/chmod +x "$OUT"

/usr/bin/python "$PATCH_DYLINKER" "$OUT" /usr/oah/dyld

is_ppc32_macho() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

is_ppc32_macho "$OUT" || {
    echo "error: output is not a 32-bit PPC Mach-O" >&2
    exit 70
}

OT="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: output LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/otool -L "$OUT" | /usr/bin/grep -Fq     '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || {
    echo "error: output does not link Carbon" >&2
    exit 72
}

/usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq '(^|[[:space:]])_GetProcessForPID$' || {
    echo "error: output does not import GetProcessForPID" >&2
    exit 72
}

if /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq     '(_GetCurrentProcess|_GetProcessPID|_GetFrontProcess|_SetFrontProcess|_TransformProcessType)($|[[:space:]])'; then
    echo "error: probe unexpectedly imports another Process Manager/foreground API" >&2
    exit 72
fi

for marker in     'PM_POSTDISPATCH_MILESTONE:M05_BEFORE_GetProcessForPID'     'PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID'     'PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required probe marker missing: $marker" >&2
        exit 72
    }
done

{
    echo "== PPC post-dispatch GetProcessForPID probe =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    /usr/bin/otool -l "$OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== linkage note =="
    echo "Direct Carbon linkage is required."
    echo "CoreServices and Security are runtime/transitive participants and are validated by the Snow/Lion runners, not by direct LC_LOAD_DYLIB entries."
    echo
    echo "== Process Manager imports =="
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -E         '(_GetProcessForPID|_GetCurrentProcess|_GetProcessPID|_GetFrontProcess|_SetFrontProcess|_TransformProcessType)' || true
    echo
    echo "== fixed Snow Leopard PPC LaunchServices __TEXT-relative symbol offsets =="
    echo "SetupCoreApplicationServicesCommunicationPort=0x00018070"
    echo "getProcessDispatchTable=0x00018654"
    echo "getProcessesServerPort=0x000186a8"
    echo "expected_ppc_prologue_word=0x7c0802a6"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

/usr/bin/shasum -a 256 "$OUT" > "$SHA"

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
