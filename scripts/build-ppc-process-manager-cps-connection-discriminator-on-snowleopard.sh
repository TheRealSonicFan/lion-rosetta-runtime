#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-cps-connection-discriminator-private-dyld}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-cps-connection-discriminator.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }

/bin/rm -f "$OUT" "$INFO" "$SHA"

BUILD_COMPLETE=0
cleanup_on_exit() {
    rc=$?
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$OUT" "$INFO" "$SHA"
    fi
    return "$rc"
}
trap cleanup_on_exit EXIT

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 "$SRC" -framework Carbon -o "$OUT"
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

/usr/bin/otool -L "$OUT" | /usr/bin/grep -Fq '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || {
    echo "error: output does not link Carbon" >&2
    exit 72
}

for sym in _GetProcessForPID _GetProcessPID _TransformProcessType _dlsym; do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: output does not import $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq '(_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess)($|[[:space:]])'; then
    echo "error: discriminator unexpectedly imports a public foreground verification API" >&2
    exit 72
fi

for marker in \
    'PM_POSTIDENTITY_MILESTONE:M05_BEFORE_GetProcessForPID' \
    'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' \
    'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS' \
    'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS' \
    'PM_CPS_IMAGE:' \
    'PM_CPS_PROLOGUE:' \
    'PM_CPS_CONNECTION_STATE:phase=%s slot=' \
    'preidentity' \
    'postidentity' \
    'posttransform' \
    'postcps' \
    'PM_CPS_DISCRIMINATOR_MILESTONE:M11_BEFORE_CPSSetFrontProcess' \
    'PM_CPS_DISCRIMINATOR_MILESTONE:M12_AFTER_CPSSetFrontProcess' \
    'PM_CPS_DISCRIMINATOR_STATUS:CPSSetFrontProcess=' \
    'PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_ZERO' \
    'PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_0X000003EB'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required discriminator artifact string missing: $marker" >&2
        exit 72
    }
done

{
    echo "== PPC CPS connection-state discriminator =="
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
    echo "== Process Manager / dlsym imports =="
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -E '(_GetProcessForPID|_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess|_dlsym)' || true
    echo
    echo "== audited Snow Leopard PPC LaunchServices offsets =="
    echo "SetupCoreApplicationServicesCommunicationPort=0x00018070"
    echo "getProcessDispatchTable=0x00018654"
    echo "getProcessesServerPort=0x000186a8"
    echo "expected_ppc_prologue_word=0x7c0802a6"
    echo
    echo "== audited Snow Leopard PPC CoreGraphics static values =="
    echo "__CPSSetFrontProcessWithOptions_static_n_value=0x001fcfdc"
    echo "CPSSetFrontProcess_static_n_value=0x001fd0cc"
    echo "CPS_symbol_static_delta=0x000000f0"
    echo "CPS_connection_record_static_target=0x007007c8"
    echo "CPS_connection_record_static_delta_from_with_options=0x005037ec"
    echo "CPS_runtime_slot_resolution=decode_loaded_PPC_PIC_addis_at_0x1c_plus_lwz_at_0x28_from_LR_base_0x08"
    echo "CPS_no_connection_raw_status=0x000003eb"
    echo "expected_CPS_with_options_prologue_word=0x7c0802a6"
    echo
    echo "== protocol observation from static audit =="
    echo "Snow PPC __CGSSetFrontProcess request_id=0x0000729e reply_id=0x00007302 send_size=0x30 receive_size=0x2c"
    echo "Lion i386 __CGSSetFrontProcess request_id=0x000072a1 reply_id=0x00007305 send_size=0x30 receive_size=0x2c"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

/usr/bin/shasum -a 256 "$OUT" > "$SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
