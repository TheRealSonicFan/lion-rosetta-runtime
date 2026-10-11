#!/bin/bash
set -e

OUT="${1:-./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
EXPECTED_BUILD_ID="cgs-session-bootstrap-dockserver-compat-v2"
CC_SELECTED="${CC:-/Developer-3.2.6/usr/bin/gcc-4.2}"

[ -x "$CC_SELECTED" ] || { echo "error: compiler not executable: $CC_SELECTED" >&2; exit 69; }
[ -f "$SRC" ] || { echo "error: missing interposer source: $SRC" >&2; exit 66; }

/bin/rm -f "$OUT" "$INFO" "$SHA"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib \
    -DPM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT=1 \
    "$SRC" \
    -install_name "@loader_path/$(/usr/bin/basename "$OUT")" \
    -o "$OUT"
/bin/chmod 755 "$OUT"

macho_arch() {
    info="$(/usr/bin/lipo -info "$1" 2>/dev/null || true)"
    case "$info" in
        *" is architecture: "*) echo "$info" | /usr/bin/sed 's/^.* is architecture: //' ;;
        *) return 1 ;;
    esac
}

is_ppc32_arch_name() {
    case "$1" in
        ppc|ppc601|ppc603|ppc603e|ppc603ev|ppc604|ppc604e|ppc750|ppc7400|ppc7450|ppc970)
            return 0 ;;
        *) return 1 ;;
    esac
}

is_ppc32_macho() {
    file="$1"
    arch="$(macho_arch "$file")" || return 1
    is_ppc32_arch_name "$arch" || return 1
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    echo "$desc" | /usr/bin/grep -Fq 'Mach-O' || return 1
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

is_ppc32_macho "$OUT" || {
    echo "error: output is not a thin 32-bit PPC Mach-O dylib" >&2
    exit 70
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: interposer section missing" >&2
    exit 72
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: expected exactly one PPC interpose tuple" >&2
    exit 72
}

for sym in _bootstrap_look_up _mach_msg _mig_get_reply_port _mach_port_type _mach_port_deallocate; do
    /usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq "(^|[[:space:]])$sym$" || {
        echo "error: interposer does not import $sym" >&2
        exit 72
    }
done

/usr/bin/nm -u "$OUT" | /usr/bin/grep -Eq '(^|[[:space:]])_bootstrap_look_up2$' && {
    echo "error: interposer unexpectedly imports bootstrap_look_up2" >&2
    exit 72
}

for marker in \
    "PM_CGS_SESSION_BOOTSTRAP_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" \
    'com.apple.windowserver.session' \
    'com.apple.windowserver.active' \
    'com.apple.dock.server' \
    'PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS' \
    'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_REQUEST:' \
    'PM_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS'; do
    /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || {
        echo "error: required interposer marker missing: $marker" >&2
        exit 72
    }
done

RUNTIME_GIT_HEAD="$(cd "$ROOT" 2>/dev/null && /usr/bin/git rev-parse HEAD 2>/dev/null || true)"
[ -n "$RUNTIME_GIT_HEAD" ] || RUNTIME_GIT_HEAD="UNAVAILABLE_NON_GIT_CHECKOUT"

{
    echo "== PPC CGS session + Dock bootstrap compatibility interposer =="
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "compiler=$CC_SELECTED"
    echo "source=$SRC"
    echo "runtime_git_head=$RUNTIME_GIT_HEAD"
    /usr/bin/file "$OUT"
    /usr/bin/lipo -info "$OUT" 2>/dev/null || true
    echo
    echo "== __interpose =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== linked libraries =="
    /usr/bin/otool -L "$OUT"
    echo
    echo "== undefined symbols =="
    /usr/bin/nm -u "$OUT"
    echo
    echo "== SHA-256 =="
    /usr/bin/shasum -a 256 "$OUT"
} > "$INFO"

/usr/bin/shasum -a 256 "$OUT" > "$SHA"

echo "Created:"
echo "  $OUT"
echo "  $INFO"
echo "  $SHA"
