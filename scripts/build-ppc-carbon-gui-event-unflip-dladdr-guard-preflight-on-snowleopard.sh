#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INTERPOSER_SRC="$ROOT/tests/ppc-carbon-gui-event-unflip-dladdr-guard-interposer.c"
PROBE_SRC="$ROOT/tests/ppc-carbon-gui-event-unflip-dladdr-guard-probe.c"
PATCH_DYLINKER="$SCRIPT_DIR/patch-ppc-load-dylinker.py"

INTERPOSER_OUT="${1:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib}"
PROBE_OUT="${2:-$ROOT/ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld}"

EXPECTED_BUILD_ID="event-unflip-dladdr-guard-v1"
EXPECTED_PROBE_CONTRACT="carbon-gui-event-unflip-dladdr-guard-preflight-v1"

for p in "$INTERPOSER_SRC" "$PROBE_SRC" "$PATCH_DYLINKER"; do
    [ -f "$p" ] || { echo "error: missing input: $p" >&2; exit 66; }
done

sha256() {
    /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

resolve_compiler() {
    for candidate in "${CC:-}"         /Developer-3.2.6/usr/bin/gcc-4.2         /Developer-3.2.6/usr/bin/gcc-4.0         /Developer/usr/bin/gcc-4.2         /Developer/usr/bin/gcc-4.0         /usr/bin/gcc-4.2         /usr/bin/gcc-4.0         /usr/bin/gcc         /usr/bin/cc; do
        [ -n "$candidate" ] || continue
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

is_ppc32() {
    file="$1"
    if [ -x /usr/bin/lipo ]; then
        /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0
        /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0
    fi
    desc="$(/usr/bin/file "$file" 2>/dev/null || true)"
    desc="${desc#*: }"
    echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc([0-9]+)?|powerpc)([^[:alnum:]_]|$)' || return 1
    echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1
    return 0
}

CC_SELECTED="$(resolve_compiler)" || {
    echo "error: no PowerPC-capable compiler found" >&2
    exit 69
}

INTERPOSER_SOURCE_SHA="$(sha256 "$INTERPOSER_SRC")"
PROBE_SOURCE_SHA="$(sha256 "$PROBE_SRC")"

echo "compiler=$CC_SELECTED"
echo "interposer_source_sha256=$INTERPOSER_SOURCE_SHA"
echo "probe_source_sha256=$PROBE_SOURCE_SHA"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib     "$INTERPOSER_SRC"     -install_name "@loader_path/$(/usr/bin/basename "$INTERPOSER_OUT")"     -o "$INTERPOSER_OUT"

"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5     "$PROBE_SRC"     -framework ApplicationServices     -o "$PROBE_OUT"

/bin/chmod 755 "$INTERPOSER_OUT" "$PROBE_OUT"
/usr/bin/python "$PATCH_DYLINKER" "$PROBE_OUT" /usr/oah/dyld

is_ppc32 "$INTERPOSER_OUT" || {
    echo "error: interposer is not 32-bit PowerPC" >&2
    exit 70
}
is_ppc32 "$PROBE_OUT" || {
    echo "error: probe is not 32-bit PowerPC" >&2
    exit 70
}

/usr/bin/strings "$INTERPOSER_OUT" | /usr/bin/grep -Fq     "PM_EVENT_UNFLIP_DLADDR_GUARD_BUILD_ID:$EXPECTED_BUILD_ID" || {
    echo "error: interposer build marker missing" >&2
    exit 71
}
/usr/bin/strings "$PROBE_OUT" | /usr/bin/grep -Fq "$EXPECTED_PROBE_CONTRACT" || {
    echo "error: probe contract marker missing" >&2
    exit 71
}

INTERPOSE_SECTION="$(/usr/bin/otool -l "$INTERPOSER_OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"
echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || {
    echo "error: interposer has no __DATA,__interpose section" >&2
    exit 71
}
echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000008' || {
    echo "error: __DATA,__interpose is not exactly one PPC tuple" >&2
    exit 71
}

/usr/bin/nm -g "$INTERPOSER_OUT" | /usr/bin/grep -q 'rosetta_event_unflip_dladdr_guard_target_return' || {
    echo "error: target-return helper is not exported" >&2
    exit 72
}
/usr/bin/nm -g "$INTERPOSER_OUT" | /usr/bin/grep -q 'rosetta_event_unflip_dladdr_guard_classify' || {
    echo "error: classifier helper is not exported" >&2
    exit 72
}
/usr/bin/nm -g "$INTERPOSER_OUT" | /usr/bin/grep -q 'rosetta_event_unflip_dladdr_guard_call_original' || {
    echo "error: original-replacee helper is not exported" >&2
    exit 72
}
/usr/bin/nm -g "$INTERPOSER_OUT" | /usr/bin/grep -q 'rosetta_event_unflip_dladdr_guard_get_counts' || {
    echo "error: counter helper is not exported" >&2
    exit 72
}

OT="$(/usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true)"
echo "$OT" | /usr/bin/grep -Fq 'name /usr/oah/dyld ' || {
    echo "error: probe LC_LOAD_DYLINKER is not /usr/oah/dyld" >&2
    exit 73
}

INTERPOSER_SHA="$(sha256 "$INTERPOSER_OUT")"
PROBE_SHA="$(sha256 "$PROBE_OUT")"
echo "$INTERPOSER_SHA  $INTERPOSER_OUT" > "$INTERPOSER_OUT.sha256"
echo "$PROBE_SHA  $PROBE_OUT" > "$PROBE_OUT.sha256"

{
    echo "== event-unflip dladdr guard interposer build =="
    echo "source=$INTERPOSER_SRC"
    echo "source_sha256=$INTERPOSER_SOURCE_SHA"
    echo "source_provenance_policy=MODERN_STAGING_SYSTEM_SHA256"
    echo "legacy_git_blob_check=NOT_REQUIRED"
    echo "build_id=$EXPECTED_BUILD_ID"
    echo "compiler=$CC_SELECTED"
    /usr/bin/file "$INTERPOSER_OUT"
    /usr/bin/lipo -info "$INTERPOSER_OUT" 2>/dev/null || true
    /usr/bin/otool -L "$INTERPOSER_OUT"
    echo
    echo "== interpose section =="
    echo "$INTERPOSE_SECTION"
    echo
    echo "== exported proof helpers =="
    /usr/bin/nm -g "$INTERPOSER_OUT" | /usr/bin/grep 'rosetta_event_unflip_dladdr_guard_' || true
    echo
    echo "sha256=$INTERPOSER_SHA"
} > "$INTERPOSER_OUT.info.txt"

{
    echo "== event-unflip dladdr guard probe build =="
    echo "source=$PROBE_SRC"
    echo "source_sha256=$PROBE_SOURCE_SHA"
    echo "source_provenance_policy=MODERN_STAGING_SYSTEM_SHA256"
    echo "legacy_git_blob_check=NOT_REQUIRED"
    echo "contract=$EXPECTED_PROBE_CONTRACT"
    echo "compiler=$CC_SELECTED"
    /usr/bin/file "$PROBE_OUT"
    /usr/bin/lipo -info "$PROBE_OUT" 2>/dev/null || true
    /usr/bin/otool -hv "$PROBE_OUT"
    /usr/bin/otool -l "$PROBE_OUT" | /usr/bin/grep -A3 LC_LOAD_DYLINKER || true
    /usr/bin/otool -L "$PROBE_OUT"
    echo
    echo "sha256=$PROBE_SHA"
} > "$PROBE_OUT.info.txt"

echo "Created:"
echo "  $INTERPOSER_OUT"
echo "  $INTERPOSER_OUT.info.txt"
echo "  $INTERPOSER_OUT.sha256"
echo "  $PROBE_OUT"
echo "  $PROBE_OUT.info.txt"
echo "  $PROBE_OUT.sha256"
