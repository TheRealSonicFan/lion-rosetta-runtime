#!/bin/bash
set -e
OUT="${1:-./pm-coreui-windowframe-shared-art-slot0-compat.dylib}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$ROOT/tests/ppc-coreui-windowframe-shared-art-slot0-compat-interposer.c"
EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v2"
EXPECTED_SOURCE_SHA256="49e5468cee947d738713fbe5bbccca6ffd7f510af46a27fc6ae2f9e15ea1294d"
INFO="$OUT.info.txt"
SHA="$OUT.sha256"
TMP_DYLIB="$(/usr/bin/mktemp /tmp/pm-coreui-windowframe-shared-art-slot0.XXXXXX.dylib)"
TMP_LOG="$(/usr/bin/mktemp /tmp/pm-coreui-windowframe-shared-art-slot0.XXXXXX.log)"
trap 'rm -f "$TMP_DYLIB" "$TMP_LOG"' EXIT HUP INT TERM
[ -f "$SRC" ] || { echo "error: missing source: $SRC" >&2; exit 66; }
/usr/bin/grep -Fq "#define BUILD_ID \"$EXPECTED_BUILD_ID\"" "$SRC" || { echo "error: stale slot0 source" >&2; exit 66; }
SOURCE_SHA="$(/usr/bin/shasum -a 256 "$SRC" | /usr/bin/awk '{print $1}')"
[ "$SOURCE_SHA" = "$EXPECTED_SOURCE_SHA256" ] || { echo "error: slot0 source SHA-256 mismatch: $SOURCE_SHA" >&2; exit 66; }
resolve_compiler(){ candidate="$1"; [ -n "$candidate" ] || return 1; if [ -x "$candidate" ]; then echo "$candidate"; return 0; fi; command -v "$candidate" 2>/dev/null || return 1; }
is_ppc32_macho(){ file="$1"; if [ -x /usr/bin/lipo ]; then /usr/bin/lipo -verify_arch ppc "$file" >/dev/null 2>&1 && return 0; /usr/bin/lipo "$file" -verify_arch ppc >/dev/null 2>&1 && return 0; fi; desc="$(/usr/bin/file "$file" 2>/dev/null || true)"; echo "$desc" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(ppc|powerpc)([^[:alnum:]_]|$)' || return 1; echo "$desc" | /usr/bin/grep -Eiq 'ppc64|powerpc64' && return 1; return 0; }
probe_compiler(){ candidate="$1"; compiler="$(resolve_compiler "$candidate" || true)"; [ -n "$compiler" ] || return 1; /bin/rm -f "$TMP_DYLIB"; if "$compiler" -arch ppc -mmacosx-version-min=10.5 -dynamiclib "$SRC" -framework ApplicationServices -install_name "@loader_path/$(/usr/bin/basename "$OUT")" -o "$TMP_DYLIB" >"$TMP_LOG" 2>&1; then if [ -f "$TMP_DYLIB" ] && is_ppc32_macho "$TMP_DYLIB"; then CC_SELECTED="$compiler"; return 0; fi; fi; echo "Rejected compiler: $compiler" >&2; /bin/cat "$TMP_LOG" >&2 || true; return 1; }
CC_SELECTED=""; if [ -n "${CC:-}" ]; then probe_compiler "$CC" || true; fi
if [ -z "$CC_SELECTED" ]; then for c in /Developer-3.2.6/usr/bin/gcc-4.2 /Developer-3.2.6/usr/bin/gcc-4.0 /Developer/usr/bin/gcc-4.2 /Developer/usr/bin/gcc-4.0 /usr/bin/gcc-4.2 /usr/bin/gcc-4.0 /usr/bin/gcc /usr/bin/cc; do if probe_compiler "$c"; then break; fi; done; fi
[ -n "$CC_SELECTED" ] || { echo "error: no installed compiler/toolchain could build PPC slot0 compatibility dylib" >&2; exit 69; }
echo "Using PowerPC-capable compiler: $CC_SELECTED"
"$CC_SELECTED" -arch ppc -mmacosx-version-min=10.5 -dynamiclib "$SRC" -framework ApplicationServices -install_name "@loader_path/$(/usr/bin/basename "$OUT")" -o "$OUT"
/bin/chmod 755 "$OUT"; is_ppc32_macho "$OUT" || { echo "error: output is not 32-bit PPC Mach-O" >&2; exit 70; }
{
 echo "== PPC CoreUI window-frame shared-art slot0 compatibility build =="; echo "compiler=$CC_SELECTED"; echo "source=$SRC"; echo "interposer_source_sha256=$SOURCE_SHA"; echo "compat_build_id=$EXPECTED_BUILD_ID"; echo; echo "== file =="; /usr/bin/file "$OUT"; echo; echo "== lipo =="; /usr/bin/lipo -info "$OUT" || true; echo; echo "== linked libraries =="; /usr/bin/otool -L "$OUT"; echo; echo "== interpose section =="; /usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true; echo; echo "== symbols =="; /usr/bin/nm -m "$OUT" | /usr/bin/grep -E '_CG(DataProviderCreateWithData|ImageCreate|ImageSourceCreateWithDataProvider|ImageSourceCreateImageAtIndex)' || true; echo; echo "== markers =="; /usr/bin/strings "$OUT" | /usr/bin/grep -E 'PM_COREUI_(IMAGE_BITMAPINFO_COMPAT|SHARED_ART_SLOT0_COMPAT)' || true; echo; echo "== SHA-256 =="; /usr/bin/shasum -a 256 "$OUT";
} > "$INFO"
INTERPOSE_SECTION="$(/usr/bin/otool -l "$OUT" | /usr/bin/grep -A10 -B2 '__interpose' || true)"; echo "$INTERPOSE_SECTION" | /usr/bin/grep -q '__interpose' || { echo "error: missing __interpose" >&2; exit 71; }; echo "$INTERPOSE_SECTION" | /usr/bin/grep -Fq 'size 0x00000020' || { echo "error: interpose is not four PPC tuples" >&2; exit 71; }
for sym in _CGDataProviderCreateWithData _CGImageCreate _CGImageSourceCreateWithDataProvider _CGImageSourceCreateImageAtIndex; do /usr/bin/nm -m "$OUT" | /usr/bin/grep -Fq "$sym" || { echo "error: missing symbol: $sym" >&2; exit 72; }; done
for marker in "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_BUILD_ID:$EXPECTED_BUILD_ID" "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_CALL:" "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_ADAPTED:from=0x00000002 to=0x00002002" "PM_COREUI_IMAGE_BITMAPINFO_COMPAT_RESULT:ADAPTER_PASS" "PM_COREUI_SHARED_ART_SLOT0_COMPAT:"; do /usr/bin/strings "$OUT" | /usr/bin/grep -Fq "$marker" || { echo "error: missing marker: $marker" >&2; exit 72; }; done
/usr/bin/shasum -a 256 "$OUT" > "$SHA"
echo "Created:"; echo "  $OUT"; echo "  $INFO"; echo "  $SHA"
