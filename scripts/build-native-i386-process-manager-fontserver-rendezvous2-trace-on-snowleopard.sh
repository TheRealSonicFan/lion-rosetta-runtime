#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

PROBE_SRC="$ROOT/tests/native-i386-process-manager-fontserver-rendezvous2-title-probe.c"
TRACE_SRC="$ROOT/tests/native-i386-process-manager-fontserver-rendezvous2-trace-interposer.c"

PROBE="${1:-./native-i386-process-manager-fontserver-rendezvous2-title-probe}"
TRACE="${2:-./native-i386-process-manager-fontserver-rendezvous2-trace.dylib}"

PROBE_INFO="$PROBE.info.txt"
PROBE_SHA="$PROBE.sha256"
TRACE_INFO="$TRACE.info.txt"
TRACE_SHA="$TRACE.sha256"

[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
[ -f "$PROBE_SRC" ] || {
    echo "error: missing probe source: $PROBE_SRC" >&2
    exit 66
}
[ -f "$TRACE_SRC" ] || {
    echo "error: missing trace source: $TRACE_SRC" >&2
    exit 66
}

/bin/rm -f "$PROBE" "$PROBE_INFO" "$PROBE_SHA" \
           "$TRACE" "$TRACE_INFO" "$TRACE_SHA"

"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6 \
    "$PROBE_SRC" \
    -framework Carbon -framework CoreFoundation \
    -o "$PROBE"

/bin/chmod 755 "$PROBE"

"$CC_SELECTED" -arch i386 -mmacosx-version-min=10.6 -dynamiclib \
    "$TRACE_SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$TRACE")" \
    -o "$TRACE"

/bin/chmod 755 "$TRACE"

is_thin_i386() {
    file="$1"
    /usr/bin/lipo -info "$file" 2>/dev/null |
        /usr/bin/grep -Fq 'is architecture: i386'
}

is_thin_i386 "$PROBE" || {
    echo "error: probe is not thin i386" >&2
    exit 70
}
is_thin_i386 "$TRACE" || {
    echo "error: trace dylib is not thin i386" >&2
    exit 70
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$TRACE" |
    /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: trace interpose section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: trace must contain exactly two i386 interpose tuples" >&2
    exit 72
}

for sym in _bootstrap_look_up _mach_msg; do
    /usr/bin/nm -u "$TRACE" |
        /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: trace does not import $sym" >&2
        exit 72
    }
done

for marker in \
    'PM_NATIVE_FONTSERVER_RENDEZVOUS2_TRACE_BUILD_ID:native-i386-fontserver-rendezvous2-trace-v1' \
    'PM_NATIVE_FONTSERVER_RENDEZVOUS2_REQUEST:' \
    'PM_NATIVE_FONTSERVER_RENDEZVOUS2_REPLY:' \
    'PM_NATIVE_FONTSERVER_RENDEZVOUS2_FIELDS:' \
    'PM_NATIVE_FONTSERVER_RENDEZVOUS2_RESULT:CAPTURED_COMPLEX_V5'; do
    /usr/bin/strings "$TRACE" | /usr/bin/grep -Fq "$marker" || {
        echo "error: trace marker missing: $marker" >&2
        exit 72
    }
done

/usr/bin/strings "$PROBE" |
    /usr/bin/grep -Fq 'PM_NATIVE_FONTSERVER_RENDEZVOUS2_PROBE_BEFORE_SETWINDOWTITLE' || {
    echo "error: probe marker missing" >&2
    exit 72
}

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null &&
    /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] ||
    RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== Native i386 FontServer Rendezvous2 title probe =="
    echo "build_id=native-i386-fontserver-rendezvous2-title-probe-v1"
    echo "compiler=$CC_SELECTED"
    echo "source=$PROBE_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    /usr/bin/file "$PROBE"
    /usr/bin/lipo -info "$PROBE"
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$PROBE"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$PROBE"
} > "$PROBE_INFO"

/usr/bin/shasum -a 256 "$PROBE" > "$PROBE_SHA"

{
    echo "== Native i386 FontServer Rendezvous2 one-shot trace interposer =="
    echo "build_id=native-i386-fontserver-rendezvous2-trace-v1"
    echo "compiler=$CC_SELECTED"
    echo "source=$TRACE_SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    /usr/bin/file "$TRACE"
    /usr/bin/lipo -info "$TRACE"
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$TRACE"
    echo
    echo "== undefined symbols =="
    /usr/bin/nm -u "$TRACE"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$TRACE"
} > "$TRACE_INFO"

/usr/bin/shasum -a 256 "$TRACE" > "$TRACE_SHA"

echo "Created:"
echo "  $PROBE"
echo "  $PROBE_INFO"
echo "  $PROBE_SHA"
echo "  $TRACE"
echo "  $TRACE_INFO"
echo "  $TRACE_SHA"
