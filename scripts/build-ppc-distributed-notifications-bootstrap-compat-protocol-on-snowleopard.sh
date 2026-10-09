#!/bin/bash
set -e

PROBE_OUT="${1:-./ppc-distributed-notifications-bootstrap-probe-private-dyld}"
INTERPOSER_OUT="${2:-./ppc-distributed-notifications-bootstrap-compat-protocol.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE_SRC="$ROOT/tests/ppc-distributed-notifications-bootstrap-probe.c"
INTERPOSER_SRC="$ROOT/tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"
PROBE_INFO="$PROBE_OUT.info.txt"
PROBE_SHA="$PROBE_OUT.sha256"
INTERPOSER_INFO="$INTERPOSER_OUT.info.txt"
INTERPOSER_SHA="$INTERPOSER_OUT.sha256"
EXPECTED_PROBE_BUILD_ID="distributed-notifications-bootstrap-probe-v1"
EXPECTED_INTERPOSER_BUILD_ID="distributed-notifications-bootstrap-compat-protocol-v1"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$PROBE_SRC" ] || { echo "error: missing probe source: $PROBE_SRC" >&2; exit 66; }
[ -f "$INTERPOSER_SRC" ] || { echo "error: missing interposer source: $INTERPOSER_SRC" >&2; exit 66; }
[ -f "$PATCH_DYLINKER" ] || { echo "error: missing dylinker patch helper" >&2; exit 66; }
/usr/bin/grep -Fq "$EXPECTED_PROBE_BUILD_ID" "$PROBE_SRC" || {
    echo "error: stale probe source; pull current runtime main" >&2
    exit 66
}
/usr/bin/grep -Fq "$EXPECTED_INTERPOSER_BUILD_ID" "$INTERPOSER_SRC" || {
    echo "error: stale interposer source; pull current runtime main" >&2
    exit 66
}

/bin/rm -f "$PROBE_OUT" "$PROBE_INFO" "$PROBE_SHA"             "$INTERPOSER_OUT" "$INTERPOSER_INFO" "$INTERPOSER_SHA"

BUILD_COMPLETE=0
cleanup_on_exit() {
    rc=$?
    if [ "$BUILD_COMPLETE" -ne 1 ]; then
        /bin/rm -f "$PROBE_OUT" "$PROBE_INFO" "$PROBE_SHA"                     "$INTERPOSER_OUT" "$INTERPOSER_INFO" "$INTERPOSER_SHA"
    fi
    return "$rc"
}
trap cleanup_on_exit EXIT

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$PROBE_SRC" -o "$PROBE_OUT"
/bin/chmod +x "$PROBE_OUT"
/usr/bin/python "$PATCH_DYLINKER" "$PROBE_OUT" /usr/oah/dyld

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib     -DPM_DISTRIBUTED_NOTIFICATIONS_COMPAT_PROTOCOL=1     "$INTERPOSER_SRC"     -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")"     -o "$INTERPOSER_OUT"
/bin/chmod 755 "$INTERPOSER_OUT"

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

for file in "$PROBE_OUT" "$INTERPOSER_OUT"; do
    is_ppc32_macho "$file" || {
        echo "error: output is not a 32-bit PowerPC Mach-O: $file" >&2
        /usr/bin/file "$file" >&2 || true
        /usr/bin/lipo -info "$file" >&2 2>/dev/null || true
        exit 70
    }
done

OT="$(/usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 71
}

/usr/bin/nm -u "$PROBE_OUT" | /usr/bin/grep -Eq '(^|[[:space:]])_bootstrap_look_up2$' || {
    echo "error: probe does not import bootstrap_look_up2" >&2
    exit 72
}
for marker in     "PM_DISTRIBUTED_NOTIFICATIONS_PROBE_BUILD_ID:$EXPECTED_PROBE_BUILD_ID"     'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_LOOKUP:'     'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_PORT_TYPE:'     'PM_DISTRIBUTED_NOTIFICATIONS_PROBE_RESULT:PASS'; do
    /usr/bin/strings "$PROBE_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required probe marker missing: $marker" >&2
        exit 72
    }
done

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER_OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: interpose section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: interposer must contain exactly two PPC interpose tuples" >&2
    exit 72
}

for marker in     "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_INTERPOSER_BUILD_ID"     'com.apple.distributed_notifications.2'     'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_CALL:'     'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:PASSTHROUGH'     'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_PASS'     'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_REQUEST:'     'PM_CORESERVICES_COMPAT_BOOTSTRAP_ADAPTER_RESULT:LOOKUP_PASS'; do
    /usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required interposer marker missing: $marker" >&2
        exit 72
    }
done

for sym in _bootstrap_look_up2 _mach_msg _mig_get_reply_port; do
    /usr/bin/nm -u "$INTERPOSER_OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: interposer does not import $sym" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC distributed-notifications bootstrap probe =="
    echo "compiler=$CC_SELECTED"
    echo "source=$PROBE_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "build_id=$EXPECTED_PROBE_BUILD_ID"
    /usr/bin/file "$PROBE_OUT"
    /usr/bin/lipo -info "$PROBE_OUT" 2>/dev/null || true
    echo
    echo "== LC_LOAD_DYLINKER =="
    echo "$OT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$PROBE_OUT"
} > "$PROBE_INFO"

{
    echo "== PPC distributed-notifications bootstrap compatibility protocol interposer =="
    echo "compiler=$CC_SELECTED"
    echo "source=$INTERPOSER_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "build_id=$EXPECTED_INTERPOSER_BUILD_ID"
    /usr/bin/file "$INTERPOSER_OUT"
    /usr/bin/lipo -info "$INTERPOSER_OUT" 2>/dev/null || true
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$INTERPOSER_OUT"
} > "$INTERPOSER_INFO"

/usr/bin/shasum -a 256 "$PROBE_OUT" > "$PROBE_SHA"
/usr/bin/shasum -a 256 "$INTERPOSER_OUT" > "$INTERPOSER_SHA"
BUILD_COMPLETE=1

echo "Created:"
echo "  $PROBE_OUT"
echo "  $PROBE_INFO"
echo "  $PROBE_SHA"
echo "  $INTERPOSER_OUT"
echo "  $INTERPOSER_INFO"
echo "  $INTERPOSER_SHA"
