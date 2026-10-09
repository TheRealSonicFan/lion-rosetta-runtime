#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-postidentity-createwindow.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
EXPECTED_BUILD_ID="cps-createwindow-validation-v1"
EXPECTED_BASENAME="ppc-process-manager-cgs-session-bootstrap-integration-private-dyld"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }
[ "$(/usr/bin/basename "$OUT")" = "$EXPECTED_BASENAME" ] || {
    echo "error: output basename must remain $EXPECTED_BASENAME for the exact registration predicate" >&2
    exit 64
}
/usr/bin/grep -Fq "$EXPECTED_BUILD_ID" "$SRC" || {
    echo "error: stale CreateNewWindow subject source; pull current runtime main" >&2
    exit 66
}

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

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 \
    -DPM_CPS_CREATEWINDOW_VALIDATION=1 \
    "$SRC" -framework Carbon -o "$OUT"
/bin/chmod +x "$OUT"
/usr/bin/python "$PATCH_DYLINKER" "$OUT" /usr/oah/dyld

is_ppc32_macho() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Eiq 'Mach-O' || return 1
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

is_ppc32_macho "$OUT" || {
    echo "error: output is not a 32-bit PowerPC Mach-O executable" >&2
    /usr/bin/file "$OUT" >&2 || true
    /usr/bin/lipo -info "$OUT" >&2 2>/dev/null || true
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

for sym in _GetProcessForPID _GetProcessPID _TransformProcessType _SetFrontProcess _GetFrontProcess _GetCurrentProcess _CreateNewWindow _DisposeWindow; do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: output does not import $sym" >&2
        exit 72
    }
done

for marker in \
    "PM_CPS_CREATEWINDOW_BUILD_ID:$EXPECTED_BUILD_ID" \
    'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' \
    'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS' \
    'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS' \
    'PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M14_BEFORE_GetFrontProcess' \
    'PM_POSTIDENTITY_MILESTONE:M15_AFTER_GetFrontProcess' \
    'PM_POSTIDENTITY_STATUS:GetFrontProcess=' \
    'PM_POSTIDENTITY_FRONT_PSN:' \
    'PM_POSTIDENTITY_RESULT:GETFRONTPROCESS_MATCH_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M16_GETFRONTPROCESS_SUCCESS' \
    'PM_POSTIDENTITY_MILESTONE:M17_BEFORE_GetCurrentProcess' \
    'PM_POSTIDENTITY_MILESTONE:M18_AFTER_GetCurrentProcess' \
    'PM_POSTIDENTITY_STATUS:GetCurrentProcess=' \
    'PM_POSTIDENTITY_CURRENT_PSN:' \
    'PM_POSTIDENTITY_RESULT:GETCURRENTPROCESS_MATCH_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M19_GETCURRENTPROCESS_SUCCESS' \
    'PM_POSTIDENTITY_MILESTONE:M20_BEFORE_CreateNewWindow' \
    'PM_POSTIDENTITY_MILESTONE:M21_AFTER_CreateNewWindow' \
    'PM_POSTIDENTITY_STATUS:CreateNewWindow=' \
    'PM_POSTIDENTITY_WINDOW:' \
    'PM_POSTIDENTITY_RESULT:CREATENEWWINDOW_PASS' \
    'PM_POSTIDENTITY_MILESTONE:M22_BEFORE_DisposeWindow' \
    'PM_POSTIDENTITY_MILESTONE:M23_AFTER_DisposeWindow' \
    'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required subject marker missing: $marker" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"
SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"

{
    echo "== PPC restored-stack CreateNewWindow validation subject =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "source_sha256=$SOURCE_SHA"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "required_basename=$EXPECTED_BASENAME"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== Process Manager imports =="
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -E '(_GetProcessForPID|_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess|_CreateNewWindow|_DisposeWindow)' || true
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
