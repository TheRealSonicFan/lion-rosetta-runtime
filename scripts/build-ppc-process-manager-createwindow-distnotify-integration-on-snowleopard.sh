#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORE_SRC="$ROOT/tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c"
INGRESS_SRC="$ROOT/tests/ppc-distributed-notifications-ingress-interposer.c"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"

EXPECTED_BUILD_ID="dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-v1"
EXPECTED_INGRESS_BUILD_ID="distributed-notifications-ppc-ingress-interposer-v2"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ "$(/usr/bin/sw_vers -productVersion)" = "10.6.8" ] || {
    echo "error: build combined PPC integration dylib on Snow Leopard 10.6.8" >&2
    exit 65
}
[ -x "$CC_SELECTED" ] || {
    echo "error: compiler not executable: $CC_SELECTED" >&2
    exit 69
}
for file in "$CORE_SRC" "$INGRESS_SRC"; do
    [ -f "$file" ] || {
        echo "error: missing $file" >&2
        exit 66
    }
done

/usr/bin/grep -Fq "$EXPECTED_BUILD_ID" "$CORE_SRC" || {
    echo "error: stale CoreServices source; pull current runtime main" >&2
    exit 66
}
/usr/bin/grep -Fq "$EXPECTED_INGRESS_BUILD_ID" "$INGRESS_SRC" || {
    echo "error: stale distributed-notifications ingress source; pull current runtime main" >&2
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
    -DPM_CPS_REGISTRATION_TRACE=1 \
    -DPM_CPS_REGISTRATION_COMPAT_INTEGRATION=1 \
    -DPM_CPS_SETFRONT_TRACE=1 \
    -DPM_CPS_SETFRONT_COMPAT_INTEGRATION=1 \
    -DPM_DISTRIBUTED_NOTIFICATIONS_INGRESS_INTEGRATION=1 \
    -DPM_DISTRIBUTED_NOTIFICATIONS_INGRESS_EMBEDDED=1 \
    "$CORE_SRC" "$INGRESS_SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
    -o "$OUT"

/bin/chmod 755 "$OUT"

macho_archs() {
    file="$1"
    info="$(/usr/bin/lipo -info "$file" 2>/dev/null || true)"
    case "$info" in
        *" is architecture: "*)
            echo "$info" | /usr/bin/sed 's/^.* is architecture: //'
            ;;
        *" are: "*)
            echo "$info" | /usr/bin/sed 's/^.* are: //'
            ;;
        *)
            return 1
            ;;
    esac
}

is_ppc32_arch_name() {
    case "$1" in
        ppc|ppc601|ppc603|ppc603e|ppc603ev|ppc604|ppc604e|ppc750|ppc7400|ppc7450|ppc970)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ARCHS="$(macho_archs "$OUT")" || {
    echo "error: cannot determine combined interposer architecture" >&2
    exit 70
}
FOUND_PPC32=0
for arch in $ARCHS; do
    is_ppc32_arch_name "$arch" && FOUND_PPC32=1
done
[ "$FOUND_PPC32" -eq 1 ] || {
    echo "error: combined interposer is not 32-bit PPC" >&2
    /usr/bin/lipo -info "$OUT" >&2 || true
    exit 70
}

/usr/bin/file "$OUT" | /usr/bin/grep -Fq 'Mach-O' || {
    echo "error: combined interposer is not Mach-O" >&2
    exit 70
}
/usr/bin/file "$OUT" | /usr/bin/grep -Fq ' ppc' || {
    echo "error: combined interposer is not PPC" >&2
    exit 70
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq '__interpose' || {
    echo "error: combined interpose section missing" >&2
    exit 71
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000010' || {
    echo "error: combined interposer must contain exactly two PPC interpose tuples" >&2
    exit 71
}

/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_CORESERVICES_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: combined CoreServices build marker missing" >&2
    exit 72
}
/usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    "PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_INTERPOSER_BUILD_ID:$EXPECTED_INGRESS_BUILD_ID" || {
    echo "error: embedded distributed-notifications ingress marker missing" >&2
    exit 72
}

for marker in \
    'PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CPS_SETFRONT_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_LOOKUP_RESULT:LOCAL_SERVICE_PASS' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BRIDGE_READY:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:' \
    'PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_CALLBACK:'
do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: combined interposer marker missing: $marker" >&2
        exit 72
    }
done

if /usr/bin/strings "$OUT" | /usr/bin/grep -Fq \
    'PM_DISTRIBUTED_NOTIFICATIONS_COMPAT_RESULT:ADAPTER_PASS'; then
    echo "error: obsolete name-only distributed-notifications adapter is present" >&2
    exit 72
fi

UNDEFINED="$(/usr/bin/nm -u "$OUT")"
for sym in \
    _bootstrap_look_up2 \
    _mach_msg \
    _mig_get_reply_port \
    _posix_spawn \
    _pthread_create \
    __NSGetEnviron
do
    echo "$UNDEFINED" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: combined interposer missing import $sym" >&2
        exit 72
    }
done

SOCKETPAIR_IMPORT=""
SOCKETPAIR_IMPORT_COUNT=0
for sym in $(echo "$UNDEFINED" | /usr/bin/awk '{print $NF}'); do
    case "$sym" in
        _socketpair|'_socketpair$UNIX2003')
            SOCKETPAIR_IMPORT="$sym"
            SOCKETPAIR_IMPORT_COUNT=$((SOCKETPAIR_IMPORT_COUNT + 1))
            ;;
    esac
done
[ "$SOCKETPAIR_IMPORT_COUNT" -eq 1 ] || {
    echo "error: combined interposer must import exactly one supported socketpair symbol" >&2
    echo 'expected: _socketpair or _socketpair$UNIX2003' >&2
    echo "$UNDEFINED" | /usr/bin/grep -F 'socketpair' >&2 || true
    exit 72
}

if echo "$UNDEFINED" | /usr/bin/grep -Eq '(^|[[:space:]])_environ$'; then
    echo "error: combined interposer must not import _environ directly" >&2
    exit 72
fi

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"
CORE_SOURCE_SHA="$(/usr/bin/shasum -a 256 "$CORE_SRC" | /usr/bin/awk '{print $1}')"
INGRESS_SOURCE_SHA="$(/usr/bin/shasum -a 256 "$INGRESS_SRC" | /usr/bin/awk '{print $1}')"

{
    echo "== PPC Process Manager + distributed-notifications combined compatibility interposer =="
    echo "compiler=$CC_SELECTED"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    echo "core_source=$CORE_SRC"
    echo "core_source_sha256=$CORE_SOURCE_SHA"
    echo "ingress_source=$INGRESS_SRC"
    echo "ingress_source_sha256=$INGRESS_SOURCE_SHA"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "embedded_ingress_build_id=$EXPECTED_INGRESS_BUILD_ID"
    echo "socketpair_import=$SOCKETPAIR_IMPORT"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
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
