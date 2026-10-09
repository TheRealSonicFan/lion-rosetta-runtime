#!/bin/bash
set -e

SUBJECT_OUT="${1:-./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld}"
INTERPOSER_OUT="${2:-./ppc-process-manager-cgs-session-bootstrap-compat.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBJECT_SRC="$ROOT/tests/ppc-process-manager-cps-connection-discriminator.c"
INTERPOSER_SRC="$ROOT/tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

SUBJECT_INFO="$SUBJECT_OUT.info.txt"
SUBJECT_SHA="$SUBJECT_OUT.sha256"
INTERPOSER_INFO="$INTERPOSER_OUT.info.txt"
INTERPOSER_SHA="$INTERPOSER_OUT.sha256"

EXPECTED_SUBJECT_BUILD_ID="cgs-session-bootstrap-integration-v1"
EXPECTED_INTERPOSER_BUILD_ID="cgs-session-bootstrap-compat-v1"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SUBJECT_SRC" ] || { echo "error: missing subject source: $SUBJECT_SRC" >&2; exit 66; }
[ -f "$INTERPOSER_SRC" ] || { echo "error: missing interposer source: $INTERPOSER_SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }

/bin/rm -f "$SUBJECT_OUT" "$SUBJECT_INFO" "$SUBJECT_SHA" \
            "$INTERPOSER_OUT" "$INTERPOSER_INFO" "$INTERPOSER_SHA"

BUILD_COMPLETE=0
cleanup_on_exit() {
    rc=$?
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$SUBJECT_OUT" "$SUBJECT_INFO" "$SUBJECT_SHA" \
                    "$INTERPOSER_OUT" "$INTERPOSER_INFO" "$INTERPOSER_SHA"
    fi
    return "$rc"
}
trap cleanup_on_exit EXIT

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 \
    -DPM_CGS_SESSION_BOOTSTRAP_INTEGRATION=1 \
    "$SUBJECT_SRC" -framework Carbon -o "$SUBJECT_OUT"
/bin/chmod +x "$SUBJECT_OUT"
/usr/bin/python "$PATCH_DYLINKER" "$SUBJECT_OUT" /usr/oah/dyld

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib \
    "$INTERPOSER_SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")" \
    -o "$INTERPOSER_OUT"
/bin/chmod 755 "$INTERPOSER_OUT"

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

is_ppc32_macho "$SUBJECT_OUT" || {
    echo "error: subject is not a 32-bit PPC Mach-O" >&2
    exit 70
}
is_ppc32_macho "$INTERPOSER_OUT" || {
    echo "error: interposer is not a 32-bit PPC Mach-O dylib" >&2
    exit 70
}

OT="$(/usr/bin/otool -l "$SUBJECT_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: subject LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/otool -L "$SUBJECT_OUT" | /usr/bin/grep -Fq \
    '/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon' || {
    echo "error: subject does not link Carbon" >&2
    exit 72
}

for sym in _GetProcessForPID _dlsym; do
    /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: subject does not import $sym" >&2
        exit 72
    }
done

if /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -Eq \
    '(_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess)($|[[:space:]])'; then
    echo "error: integration subject imports a forbidden later Process Manager API" >&2
    /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -E \
        '(_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess)' >&2 || true
    exit 72
fi

for marker in \
    "PM_CGS_SESSION_BOOTSTRAP_SUBJECT_BUILD_ID:$EXPECTED_SUBJECT_BUILD_ID" \
    'PM_POSTIDENTITY_MILESTONE:M05_BEFORE_GetProcessForPID' \
    'PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS' \
    'PM_CPS_CONNECTION_STATE:phase=%s slot=' \
    'PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_RESULT:CONNECTION_NULL' \
    'PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_RESULT:CONNECTION_NONZERO' \
    'PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_MILESTONE:M07_SUCCESS'; do
    /usr/bin/strings "$SUBJECT_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required integration-subject marker missing: $marker" >&2
        exit 72
    }
done

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER_OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: interposer section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: expected exactly one PPC interpose tuple" >&2
    exit 72
}

for sym in _bootstrap_look_up _mach_msg _mig_get_reply_port _mach_port_type _mach_port_deallocate; do
    /usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: interposer does not import $sym" >&2
        exit 72
    }
done

/usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq \
    '(^|[[:space:]])_bootstrap_look_up2$' && {
    echo "error: interposer unexpectedly imports bootstrap_look_up2" >&2
    exit 72
}

/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID" || {
    echo "error: interposer build marker missing" >&2
    exit 72
}
/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq \
    'com.apple.windowserver.session' || {
    echo "error: exact legacy session service name missing" >&2
    exit 72
}
/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq \
    'com.apple.windowserver.active' || {
    echo "error: Lion active WindowServer service name missing" >&2
    exit 72
}
/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq \
    'PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' || {
    echo "error: adapter PASS marker missing" >&2
    exit 72
}

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC CGS session-bootstrap integration subject =="
    echo "build_id=$EXPECTED_SUBJECT_BUILD_ID"
    echo "compiler=$CC_SELECTED"
    echo "source=$SUBJECT_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    /usr/bin/file "$SUBJECT_OUT"
    /usr/bin/lipo -info "$SUBJECT_OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    /usr/bin/otool -l "$SUBJECT_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$SUBJECT_OUT"
    echo
    echo "== relevant imports =="
    /usr/bin/nm -u "$SUBJECT_OUT" | /usr/bin/grep -E \
        '(_GetProcessForPID|_GetProcessPID|_TransformProcessType|_SetFrontProcess|_GetFrontProcess|_GetCurrentProcess|_dlsym)' || true
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$SUBJECT_OUT"
} > "$SUBJECT_INFO"

{
    echo "== PPC CGS session-bootstrap compatibility interposer =="
    echo "build_id=$EXPECTED_INTERPOSER_BUILD_ID"
    echo "compiler=$CC_SELECTED"
    echo "source=$INTERPOSER_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    /usr/bin/file "$INTERPOSER_OUT"
    /usr/bin/lipo -info "$INTERPOSER_OUT" 2>/dev/null || true
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$INTERPOSER_OUT"
    echo
    echo "== undefined symbols =="
    /usr/bin/nm -u "$INTERPOSER_OUT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$INTERPOSER_OUT"
} > "$INTERPOSER_INFO"

/usr/bin/shasum -a 256 "$SUBJECT_OUT" > "$SUBJECT_SHA"
/usr/bin/shasum -a 256 "$INTERPOSER_OUT" > "$INTERPOSER_SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $SUBJECT_OUT"
echo "  $SUBJECT_INFO"
echo "  $SUBJECT_SHA"
echo "  $INTERPOSER_OUT"
echo "  $INTERPOSER_INFO"
echo "  $INTERPOSER_SHA"
