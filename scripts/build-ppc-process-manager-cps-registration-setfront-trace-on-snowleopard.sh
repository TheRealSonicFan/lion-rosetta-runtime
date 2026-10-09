#!/bin/bash
set -e

SUBJECT_OUT="${1:-./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
TRACE_OUT="${2:-./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-trace.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBJECT_SRC="$ROOT/tests/ppc-process-manager-postidentity-setfrontprocess.c"
TRACE_SRC="$ROOT/tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

SUBJECT_INFO="$SUBJECT_OUT.info.txt"
SUBJECT_SHA="$SUBJECT_OUT.sha256"
TRACE_INFO="$TRACE_OUT.info.txt"
TRACE_SHA="$TRACE_OUT.sha256"

EXPECTED_SUBJECT_BUILD_ID="cps-registration-setfront-trace-v1"
EXPECTED_TRACE_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-trace-v1"
EXPECTED_SUBJECT_BASENAME="ppc-process-manager-cgs-session-bootstrap-integration-private-dyld"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SUBJECT_SRC" ] || { echo "error: missing subject source: $SUBJECT_SRC" >&2; exit 66; }
[ -f "$TRACE_SRC" ] || { echo "error: missing trace source: $TRACE_SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper: $PATCH_DYLINKER" >&2; exit 66; }
[ "$(/usr/bin/basename "$SUBJECT_OUT")" = "$EXPECTED_SUBJECT_BASENAME" ] || {
    echo "error: subject basename must remain $EXPECTED_SUBJECT_BASENAME for the exact registration predicate" >&2
    exit 64
}
/usr/bin/grep -Fq "$EXPECTED_SUBJECT_BUILD_ID" "$SUBJECT_SRC" || {
    echo "error: stale SetFrontProcess subject source; pull current runtime main" >&2
    exit 66
}
/usr/bin/grep -Fq "$EXPECTED_TRACE_BUILD_ID" "$TRACE_SRC" || {
    echo "error: stale CoreServices trace source; pull current runtime main" >&2
    exit 66
}

/bin/rm -f "$SUBJECT_OUT" "$SUBJECT_INFO" "$SUBJECT_SHA"             "$TRACE_OUT" "$TRACE_INFO" "$TRACE_SHA"

BUILD_COMPLETE=0
cleanup_on_exit() {
    rc=$?
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$SUBJECT_OUT" "$SUBJECT_INFO" "$SUBJECT_SHA"                     "$TRACE_OUT" "$TRACE_INFO" "$TRACE_SHA"
    fi
    return "$rc"
}
trap cleanup_on_exit EXIT

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     -DPM_CPS_REGISTRATION_SETFRONT_TRACE_SUBJECT=1     "$SUBJECT_SRC" -framework Carbon -o "$SUBJECT_OUT"
/bin/chmod +x "$SUBJECT_OUT"
/usr/bin/python "$PATCH_DYLINKER" "$SUBJECT_OUT" /usr/oah/dyld

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib     -DPM_CGS_CONNECTION_TRACE=1     -DPM_CGS_SERVER_VERSION_COMPAT_INTEGRATION=1     -DPM_CPS_REGISTRATION_TRACE=1     -DPM_CPS_REGISTRATION_COMPAT_INTEGRATION=1     -DPM_CPS_SETFRONT_TRACE=1     "$TRACE_SRC"     -install_name "@loader_path/$(/usr/bin/basename "$TRACE_OUT")"     -o "$TRACE_OUT"
/bin/chmod 755 "$TRACE_OUT"

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

for file in "$SUBJECT_OUT" "$TRACE_OUT"; do
    is_ppc32_macho "$file" || {
        echo "error: output is not a 32-bit PowerPC Mach-O: $file" >&2
        /usr/bin/file "$file" >&2 || true
        /usr/bin/lipo -info "$file" >&2 2>/dev/null || true
        exit 70
    }
done

OT="$(/usr/bin/otool -l "$SUBJECT_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: subject LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/otool -L "$SUBJECT_OUT" | /usr/bin/grep -Fq     '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || {
    echo "error: subject does not link Carbon" >&2
    exit 72
}

for sym in _GetProcessForPID _GetProcessPID _TransformProcessType _SetFrontProcess; do
    /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: subject does not import $sym" >&2
        exit 72
    }
done
if /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -Eq '(_GetCurrentProcess|_GetFrontProcess)($|[[:space:]])'; then
    echo "error: subject unexpectedly imports a later query API" >&2
    exit 72
fi

for marker in     "PM_CPS_REGISTRATION_SETFRONT_TRACE_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID"     'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS'     'PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS'     'PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS'     'PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess'     'PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess'     'PM_POSTIDENTITY_STATUS:SetFrontProcess='     'PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS'; do
    /usr/bin/strings "$SUBJECT_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required subject marker missing: $marker" >&2
        exit 72
    }
done

INTERPOSE_SECTION="$(/usr/bin/otool -l "$TRACE_OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: trace interposer section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: trace interposer must retain exactly two PPC interpose tuples" >&2
    exit 72
}

/usr/bin/strings "$TRACE_OUT" | /usr/bin/grep -Fq     "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_TRACE_BUILD_ID" || {
    echo "error: trace build marker missing" >&2
    exit 72
}
for marker in     'PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS'     'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS'     'CPS_CHECKIN_APPLICATION'     'CPS_SET_FRONT_PROCESS_LEGACY'     'CPS_SET_FRONT_PROCESS_LION'     'PM_CGS_CONNECTION_TRACE_REQUEST:'     'PM_CGS_CONNECTION_TRACE_REPLY:'     'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:'; do
    /usr/bin/strings "$TRACE_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required trace marker missing: $marker" >&2
        exit 72
    }
done

for sym in _bootstrap_look_up2 _mach_msg _mig_get_reply_port; do
    /usr/bin/nm -u "$TRACE_OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: trace interposer does not import $sym" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC CPS-registration SetFrontProcess trace subject =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SUBJECT_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "build_id=$EXPECTED_SUBJECT_BUILD_ID"
    echo "required_basename=$EXPECTED_SUBJECT_BASENAME"
    /usr/bin/file "$SUBJECT_OUT"
    /usr/bin/lipo -info "$SUBJECT_OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== Process Manager imports =="
    /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -E         '(_GetProcessForPID|_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess)' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$SUBJECT_OUT"
} > "$SUBJECT_INFO"

{
    echo "== PPC CoreServices + CPS registration compatibility + SetFrontProcess passive trace =="
    echo "compiler=$CC_SELECTED"
    echo "source=$TRACE_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "build_id=$EXPECTED_TRACE_BUILD_ID"
    /usr/bin/file "$TRACE_OUT"
    /usr/bin/lipo -info "$TRACE_OUT" 2>/dev/null || true
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== required imports =="
    /usr/bin/nm -u "$TRACE_OUT" | /usr/bin/grep -E         '(_bootstrap_look_up2|_mach_msg|_mig_get_reply_port)' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$TRACE_OUT"
} > "$TRACE_INFO"

/usr/bin/shasum -a 256 "$SUBJECT_OUT" > "$SUBJECT_SHA"
/usr/bin/shasum -a 256 "$TRACE_OUT" > "$TRACE_SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $SUBJECT_OUT"
echo "  $SUBJECT_INFO"
echo "  $SUBJECT_SHA"
echo "  $TRACE_OUT"
echo "  $TRACE_INFO"
echo "  $TRACE_SHA"
