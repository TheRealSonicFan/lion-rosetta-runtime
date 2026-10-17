#!/bin/bash
set -u

OUT="${1:-./ppc-carbon-gui-event-unflip-near-stub-audit.txt}"
COREGRAPHICS="/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics"
ROSETTA_CACHE="/private/var/db/dyld/dyld_shared_cache_rosetta"
ROSETTA_MAP="/private/var/db/dyld/dyld_shared_cache_rosetta.map"
SNOW_PPC_SHA="83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a"
LION_I386_SHA="4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d"
ROSETTA_CACHE_SHA="2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911"
ROSETTA_MAP_SHA="66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9"
CONTRACT="carbon-gui-event-unflip-near-stub-audit-v1"

TMPDIR_AUDIT="$(/usr/bin/mktemp -d /tmp/rosetta-near-stub.XXXXXX)" || exit 1
trap '/bin/rm -rf "$TMPDIR_AUDIT"' EXIT HUP INT TERM

PRODUCT="$(/usr/bin/sw_vers -productVersion 2>/dev/null || true)"
BUILD="$(/usr/bin/sw_vers -buildVersion 2>/dev/null || true)"
MODE="unsupported"
ARCH=""
EXPECTED_SLICE_SHA=""
if [ "$PRODUCT" = "10.6.8" ] && [ "$BUILD" = "10K549" ]; then
    MODE="snow"
    ARCH="ppc7400"
    EXPECTED_SLICE_SHA="$SNOW_PPC_SHA"
elif [ "$PRODUCT" = "10.7.5" ] && [ "$BUILD" = "11G63" ]; then
    MODE="lion"
    ARCH="i386"
    EXPECTED_SLICE_SHA="$LION_I386_SHA"
fi

FAIL=0
SLICE="$TMPDIR_AUDIT/CoreGraphics.$ARCH"

{
    echo "== PPC Carbon GUI event-unflip near-stub audit =="
    echo "audit_contract=$CONTRACT"
    echo "product_version=$PRODUCT"
    echo "build_version=$BUILD"
    echo "mode=$MODE"
    echo "prior_patch_placement_result=NONE_OBSERVED"
    echo "coregraphics_text_write_attempts=0"
    echo "vm_protect_attempts=0"
    echo "vm_allocate_attempts=0"
    echo "helper_or_interposer_load_attempts=0"
    echo "original_gui_launch_count=0"
    echo "xnu_change_authorized=NO"
    echo

    if [ "$MODE" = "unsupported" ]; then
        echo "validation_issue=unsupported product/build"
        FAIL=1
    elif [ ! -f "$COREGRAPHICS" ]; then
        echo "validation_issue=CoreGraphics missing"
        FAIL=1
    else
        echo "== CoreGraphics slice provenance =="
        echo "required_arch=$ARCH"
        echo "expected_slice_sha256=$EXPECTED_SLICE_SHA"
        /bin/rm -f "$SLICE"
        if /usr/bin/lipo "$COREGRAPHICS" -thin "$ARCH" -output "$SLICE" >/dev/null 2>&1 || \
           /usr/bin/lipo -thin "$ARCH" "$COREGRAPHICS" -output "$SLICE" >/dev/null 2>&1; then
            ACTUAL_SLICE_SHA="$(/usr/bin/shasum -a 256 "$SLICE" | /usr/bin/awk '{print $1}')"
            echo "slice_sha256=$ACTUAL_SLICE_SHA"
            if [ "$ACTUAL_SLICE_SHA" = "$EXPECTED_SLICE_SHA" ]; then
                echo "slice_exact=YES"
            else
                echo "slice_exact=NO"
                echo "validation_issue=CoreGraphics slice SHA mismatch"
                FAIL=1
            fi
        else
            echo "slice_exact=NO"
            echo "validation_issue=required CoreGraphics slice unavailable"
            FAIL=1
        fi
    fi

    if [ "$MODE" = "lion" ]; then
        echo
        echo "== Rosetta shared-cache provenance =="
        if [ -f "$ROSETTA_CACHE" ]; then
            CACHE_SHA="$(/usr/bin/shasum -a 256 "$ROSETTA_CACHE" | /usr/bin/awk '{print $1}')"
        else
            CACHE_SHA="MISSING"
        fi
        if [ -f "$ROSETTA_MAP" ]; then
            MAP_SHA="$(/usr/bin/shasum -a 256 "$ROSETTA_MAP" | /usr/bin/awk '{print $1}')"
        else
            MAP_SHA="MISSING"
        fi
        echo "rosetta_cache_sha256=$CACHE_SHA"
        echo "rosetta_cache_map_sha256=$MAP_SHA"
        [ "$CACHE_SHA" = "$ROSETTA_CACHE_SHA" ] && echo "rosetta_cache_expected=YES" || { echo "rosetta_cache_expected=NO"; FAIL=1; }
        [ "$MAP_SHA" = "$ROSETTA_MAP_SHA" ] && echo "rosetta_cache_map_expected=YES" || { echo "rosetta_cache_map_expected=NO"; FAIL=1; }
        if [ -f "$ROSETTA_MAP" ] && /usr/bin/grep -q 'CoreGraphics.framework' "$ROSETTA_MAP"; then
            echo "coregraphics_present_in_rosetta_cache_map=YES"
        else
            echo "coregraphics_present_in_rosetta_cache_map=NO"
            FAIL=1
        fi
        echo "translated_ppc_stub_inventory_source=PINNED_SNOW_PPC_COREGRAPHICS"
    fi

    if [ -f "$SLICE" ]; then
        echo
        echo "== Symbol-stub indirect table =="
        /usr/bin/otool -Iv "$SLICE" 2>&1 || { echo "validation_issue=otool -Iv failed"; FAIL=1; }

        echo
        echo "== Calls and branches annotated as symbol-stub references =="
        /usr/bin/otool -tvV "$SLICE" 2>&1 | /usr/bin/grep 'symbol stub for:' || true

        echo
        echo "== Undefined/imported symbol inventory =="
        /usr/bin/nm -m "$SLICE" 2>&1 | /usr/bin/grep -E 'undefined|lazy' || true

        echo
        echo "== Stub-section metadata =="
        /usr/bin/otool -l "$SLICE" 2>&1 | /usr/bin/awk '
            /^Section$/ {insec=1; buf=$0 ORS; next}
            insec {buf=buf $0 ORS}
            insec && /sectname (__stubs|__symbol_stub1|__picsymbolstub1)/ {keep=1}
            insec && /reserved2/ {if (keep) printf "%s", buf; insec=0; keep=0; buf=""}
        '

        for SECT in __stubs __symbol_stub1 __picsymbolstub1; do
            echo
            echo "== Raw stub section: __TEXT,$SECT =="
            /usr/bin/otool -v -s __TEXT "$SECT" "$SLICE" 2>&1 || true
        done
    fi

    echo
    echo "== Route review constants =="
    if [ "$MODE" = "snow" ]; then
        echo "patch_callsite=0x0014c38c"
        echo "patch_return_address=0x0014c390"
        echo "original_bounds_target=0x001433b8"
        echo "original_call_word=0x4bff702d"
        echo "ppc_relative_branch_range=PLUS_MINUS_32_MIB"
        echo "route_question=inventory existing reachable symbol stubs and select only an LR-preserving imported target whose non-target calls can be forwarded unchanged"
    else
        echo "native_reference_bounds_callsite=0x0015796b"
        echo "native_reference_bounds_target=0x0007663b"
        echo "route_question=confirm accepted Lion environment while Snow PPC provides the translated-code stub inventory"
    fi

    echo
    echo "== Integrity =="
    echo "No PowerPC subject was launched."
    echo "No original Carbon GUI was launched."
    echo "No CoreGraphics text or data was modified."
    echo "No vm_protect or vm_allocate operation was attempted."
    echo "No helper or interposer was loaded."
    echo "No WindowServer, Rosetta cache, dyld, shared-cache file, or XNU state was modified."

    echo
    if [ "$FAIL" -eq 0 ]; then
        echo "RESULT: NEAR_STUB_AUDIT_CAPTURE_PASS"
        echo "RESULT: PASS"
    else
        echo "RESULT: FAIL"
    fi
} > "$OUT"

if [ "$FAIL" -eq 0 ]; then
    echo "Created: $OUT"
    echo "RESULT: PASS"
    exit 0
fi

echo "Created: $OUT"
echo "RESULT: FAIL"
exit 1
