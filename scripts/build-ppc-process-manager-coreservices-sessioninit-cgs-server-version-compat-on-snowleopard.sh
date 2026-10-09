#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
EXPECTED_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-v1"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
/usr/bin/grep -Fq "$EXPECTED_BUILD_ID" "$SRC" || {
    echo "error: stale CoreServices source; pull current runtime main" >&2
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

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib \
    -DPM_CGS_CONNECTION_TRACE=1 \
    -DPM_CGS_SERVER_VERSION_COMPAT_INTEGRATION=1 \
    "$SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
    -o "$OUT"
/bin/chmod 755 "$OUT"

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
    echo "error: compatibility interposer is not a 32-bit PPC Mach-O dylib" >&2
    exit 70
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: compatibility interposer section missing" >&2
    exit 71
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: compatibility interposer must retain exactly two PPC interpose tuples" >&2
    exit 71
}

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: compatibility build marker missing" >&2
    exit 72
}

for marker in \
    'PM_CGS_CONNECTION_TRACE_REQUEST:' \
    'PM_CGS_CONNECTION_TRACE_REPLY_WORDS:' \
    'PM_CGS_SERVER_VERSION_COMPAT_CALL:' \
    'PM_CGS_SERVER_VERSION_COMPAT_ADAPTER:' \
    'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_SERVER_VERSION_COMPAT_RESULT:PASSTHROUGH' \
    'SERVER_VERSION' \
    'NEW_CONNECTION'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required compatibility marker missing: $marker" >&2
        exit 72
    }
done

for sym in _bootstrap_look_up2 _mach_msg _mig_get_reply_port; do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: compatibility interposer does not import $sym" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"
SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"

{
    echo "== PPC CoreServices SessionInit + CGS server-version compatibility interposer =="
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "source_sha256=$SOURCE_SHA"
    echo "build_id=$EXPECTED_BUILD_ID"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== required imports =="
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -E '(_bootstrap_look_up2|_mach_msg|_mig_get_reply_port)' || true
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
