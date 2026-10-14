# PPC Carbon GUI live CoreUI image-constructor trace

## Status

COMPLETED LIVE-PROVEN PASS. Snow and Lion each make exactly six cached Snow-PPC CoreUI `CGImageCreate` calls with bitmap-info `0x00000002`; neither run enters `CWMatchBitmap`. The next controlled step is `docs/ppc-carbon-gui-coreui-image-bitmapinfo-compat-integration.md`.

## Reviewed result that advances this step

Both static reports pass.

Snow Leopard 10.6.8 / 10K549 proves the shared serialized metric layout and the Snow PPC image-construction contract:

```text
coreui_instruction_contract=PASS
metric_layout_grouping_shared=YES
image_constructor_bitmapinfo_values=0x00000004|0x00000002
image_constructor_byte_order_mask=DEFAULT
image_constructor_matchbitmap_branch=PRESENT
preferred_alpha_byte0_count=6
preferred_alpha_byte3_count=0
preferred_alpha_ambiguous_count=0
render_state_image_contract_exact=YES
RESULT: PASS
```

All six Snow exact titlebar-control bodies are strongly consistent with byte 0 as alpha.

Lion 10.7.5 / 11G63 proves the same logical metric layout under native Lion CoreUI, but a different raw image contract:

```text
coreui_instruction_contract=PASS
metric_layout_grouping_shared=YES
image_constructor_bitmapinfo_values=0x00002002
image_constructor_byte_order_mask=32_LITTLE
image_constructor_matchbitmap_branch=ABSENT
preferred_alpha_byte0_count=0
preferred_alpha_byte3_count=6
preferred_alpha_ambiguous_count=0
render_state_image_contract_exact=YES
RESULT: PASS
```

All six Lion exact titlebar-control bodies are strongly consistent with byte 3 as alpha.

This is now the strongest remaining titlebar-fidelity hypothesis. The historical PPC process on Lion executes the cached Snow-era PPC CoreUI loader, but consumes Lion ArtFile10 bodies whose raw channel ordering matches Lion native CoreUI's explicit `0x2002` 32-bit-little-endian image constructor. A field or pixel rewrite is still **not** authorized because the actual PPC image-construction branch used by the historical subject has not yet been observed live.

## Objective

Run one passive Snow control and one passive Lion trace that records, without modifying any argument or return value:

1. the exact `CGImageCreate` calls made by the Snow-era PPC CoreUI ArtFile loader for the exact titlebar image geometry;
2. the `bitmapInfo` value actually passed to CoreGraphics;
3. whether the old PPC CoreUI `CWMatchBitmap` branch executes;
4. the exact CoreUI call-site offsets for both calls.

The trace interposes only `CGImageCreate` and `CWMatchBitmap`. It does not touch ArtFile lookup, record bytes, pixel bytes, metrics, providers, image objects, or drawing state.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-image-constructor-trace-interposer.c
Git blob 2b8ff38429e3d7d494f96ed67bc42d23f213965c

scripts/build-ppc-coreui-image-constructor-trace-on-snowleopard.sh
Git blob 74bdc3016e4b22c8a099af43540697bbbea7defb

scripts/run-snowleopard-ppc-carbon-gui-coreui-image-constructor-trace-control.sh
Git blob d67c16de996dfa6db0a4f2094a8ba723e369074d

scripts/run-lion-ppc-carbon-gui-coreui-image-constructor-trace.sh
Git blob c8bffe35bfc6f5d83f0e36902ce60354f83a4ee7
```

Build ID:

```text
coreui-image-constructor-passive-trace-v1
```

Trace modes:

```text
Snow  snow-passive-image-v1
Lion  lion-passive-image-v1
```

The tracer logs only the exact target image geometries and records the caller image/offset for each call. The runners accept only the two Snow-PPC CoreUI call sites established by the static audit:

```text
CGImageCreate return-site offset   0x000299e0
CWMatchBitmap return-site offset   0x000298f4
```

and logs target image geometry only:

```text
Snow  14x16, 8 bits/component, 32 bits/pixel, 56 bytes/row
Lion  16x16, 8 bits/component, 32 bits/pixel, 64 bytes/row
```

The accepted six-key titlebar interposer remains separate and unchanged:

```text
pm-titlebar-bsearch-six-key-compat.dylib
SHA-256 6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72
build ID coreui-titlebar-bsearch-exact-six-v2
```

Snow runs it in `passthrough`; Lion runs it in `lion-exact-six-v1`.

## Safety constraints

- Do not change any titlebar key translation.
- Do not reuse the all-ArtFile tracer in this step.
- Do not rewrite any ArtFile header, metric, body, channel, or pixel byte.
- Do not force `bitmapInfo`, byte order, alpha position, or `CWMatchBitmap`.
- Do not replace `CGImageCreate` return objects.
- Do not substitute Snow resources or `titlebarcontrols.xml`.
- Do not force ArtFile200 or a scale factor.
- Do not change any accepted CGS/backing compatibility.
- Do not test another PPC application.
- Do not modify CoreUI, CoreGraphics, the Rosetta cache, WindowServer, or XNU.
- Stop after Snow if the titlebar ceases to look normal or any established gate regresses.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-image-constructor-trace-interposer.c)" = \
  "2b8ff38429e3d7d494f96ed67bc42d23f213965c" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-image-constructor-trace-on-snowleopard.sh)" = \
  "74bdc3016e4b22c8a099af43540697bbbea7defb" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-constructor-trace-control.sh)" = \
  "d67c16de996dfa6db0a4f2094a8ba723e369074d" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-coreui-image-constructor-trace.sh)" = \
  "c8bffe35bfc6f5d83f0e36902ce60354f83a4ee7" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-image-constructor-trace-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-constructor-trace-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-coreui-image-constructor-trace.sh || exit 1
```

No XNU build action is required.

## Phase B — build only the passive trace dylib on Snow

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-image-constructor-trace-on-snowleopard.sh \
  ./payload/pm-coreui-image-constructor-trace.dylib || exit 1
```

Require:

```text
interposer_source_git_blob=2b8ff38429e3d7d494f96ed67bc42d23f213965c
compat_build_id=coreui-image-constructor-passive-trace-v1
```

The output must be 32-bit PPC and contain exactly two `__DATA,__interpose` tuples, for `CGImageCreate` and `CWMatchBitmap`.

## Phase C — one Snow passive control

Place/reuse these accepted files in Snow's working directory:

```text
ppc-carbon-gui-smoketest-private-dyld
ppc-carbon-gui-smoketest-private-dyld.sha256
pm-carbon-gui-backing-sync-compat.dylib
pm-carbon-gui-backing-sync-compat.dylib.sha256
pm-titlebar-bsearch-six-key-compat.dylib
pm-titlebar-bsearch-six-key-compat.dylib.sha256
pm-coreui-image-constructor-trace.dylib
pm-coreui-image-constructor-trace.dylib.sha256
cgwindowlist-pid-observer
cgwindowlist-pid-observer.sha256
```

Then:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-constructor-trace-control.sh || exit 1
```

Require:

```text
titlebar_passthrough_count=6
image_constructor_coreui_exact_call_count >= 6
image_constructor_unexpected_bitmapinfo_count=0
image_constructor_all_coreui_candidate_count == image_constructor_coreui_exact_call_count
cwmatch_all_coreui_count == cwmatch_exact_coreui_count
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_CONSTRUCTOR_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Record:

```text
image_constructor_bitmapinfo_0x2_count
image_constructor_bitmapinfo_0x4_count
cwmatch_exact_coreui_count
```

Manual gate:

```text
Snow titlebar visually normal: YES
```

Do not proceed to Lion if that answer is NO.

## Phase D — transfer only the new passive trace artifact

Transfer exactly:

```text
pm-coreui-image-constructor-trace.dylib
pm-coreui-image-constructor-trace.dylib.info.txt
pm-coreui-image-constructor-trace.dylib.sha256
```

into Lion's runtime `payload/` directory.

Do not replace the accepted six-key titlebar artifact.

## Phase E — one Lion passive image-constructor trace

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

./scripts/run-lion-ppc-carbon-gui-coreui-image-constructor-trace.sh || exit 1
```

Require the established full-stack gates plus:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
image_constructor_coreui_exact_call_count >= 6
image_constructor_all_coreui_candidate_count == image_constructor_coreui_exact_call_count
cwmatch_all_coreui_count == cwmatch_exact_coreui_count
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_CONSTRUCTOR_TRACE_PASS
RESULT: PASS
```

Record without pre-judging the result:

```text
image_constructor_bitmapinfo_0x2_count
image_constructor_bitmapinfo_0x4_count
image_constructor_bitmapinfo_0x2002_count
image_constructor_other_bitmapinfo_count
cwmatch_exact_coreui_count
```

Manual gate:

```text
Lion titlebar visually normal: YES/NO/PARTIAL
```

## Decision gate

### Lion old-PPC calls remain 0x2/0x4 while Lion bodies are BYTE3

This directly confirms the current byte-order/alpha-layout incompatibility: the cached Snow PPC loader is constructing Lion's BYTE3-alpha ArtFile bodies with Snow's default-byte-order image semantics.

Do not patch ArtFile resources. The next implementation step should be a narrowly guarded `CGImageCreate` compatibility adapter for only this exact old-PPC CoreUI call site and exact 16x16/8/32/64 titlebar body contract, with a Snow passthrough control first. The adapter should change only the bitmap-info interpretation required to make Lion's body format match Lion native CoreUI; it must not mutate the pixel buffer.

### Lion old-PPC calls use 0x2002

Close the byte-order hypothesis as the immediate cause. Return to the three release-specific metric rectangles and trace their downstream use in the titlebar renderer before changing metrics.

### CWMatchBitmap behavior differs between Snow and Lion

Do not infer a bitmap-info fix yet. First determine whether ColorSync is normalizing or transforming the body on one release and not the other.

### Call-site guard or established stack fails

Stop. Preserve the raw log and do not broaden the tracer or add a rendering adapter.

## Observed result — live PPC constructor confirms the format mismatch

The returned passive trace artifact matches the pinned source/build identity and both live controls pass.

Snow:

```text
titlebar_passthrough_count=6
image_constructor_coreui_exact_call_count=6
image_constructor_bitmapinfo_0x2_count=6
image_constructor_bitmapinfo_0x4_count=0
image_constructor_unexpected_bitmapinfo_count=0
cwmatch_exact_coreui_count=0
cwmatch_all_coreui_count=0
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_CONSTRUCTOR_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
image_constructor_coreui_exact_call_count=6
image_constructor_bitmapinfo_0x2_count=6
image_constructor_bitmapinfo_0x4_count=0
image_constructor_bitmapinfo_0x2002_count=0
image_constructor_other_bitmapinfo_count=0
cwmatch_exact_coreui_count=0
cwmatch_all_coreui_count=0
windowserver_observer_pass_count=1
windowserver_observer_geometry_400x222_count=64
windowserver_observer_onscreen_400x222_count=45
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_CONSTRUCTOR_TRACE_PASS
RESULT: PASS
```

Manual review remains Snow normal versus Lion partial/unchanged, and Lion's titlebar is additionally reported non-draggable.

This satisfies the first decision gate exactly: the cached Snow-PPC loader constructs Lion's byte-3-alpha bodies with Snow's live `0x2` default-byte-order semantics, while Lion native CoreUI's equivalent static path uses `0x2002`. `CWMatchBitmap` does not execute on either live path, so ColorSync does not explain the release delta.

Follow `docs/ppc-carbon-gui-coreui-image-bitmapinfo-compat-integration.md` next. That step changes only `CGImageCreate bitmapInfo 0x2 -> 0x2002` at the exact live-proven Lion PPC CoreUI call site and 16x16/8/32/64 geometry, after a Snow passthrough control. It also records titlebar dragging separately so a remaining move/hit-test defect is not conflated with image-format fidelity.

## Return evidence

Return:

```text
pm-coreui-image-constructor-trace.dylib.info.txt
pm-coreui-image-constructor-trace.dylib.sha256
ppc-carbon-gui-coreui-image-constructor-trace-snow.log
ppc-carbon-gui-coreui-image-constructor-trace-snow-observer.log
lion-ppc-carbon-gui-coreui-image-constructor-trace.log
lion-ppc-carbon-gui-coreui-image-constructor-trace.raw.log
lion-ppc-carbon-gui-coreui-image-constructor-trace-observer.log
```

Also state:

```text
Snow titlebar visually normal: YES/NO
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not return the dylib binary unless specifically requested.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
validated ArtFile live set                       exact six only
old PPC record structure                         PASS on Snow and Lion
metric layout grouping                           shared
Snow raw exact-six alpha diagnostic              BYTE0 for 6/6
Lion raw exact-six alpha diagnostic              BYTE3 for 6/6
Snow PPC static bitmapInfo                       0x2 or 0x4 / default byte order
Lion native static bitmapInfo                    0x2002 / 32-bit little endian
live old-PPC bitmapInfo on Snow                  0x00000002 for 6/6
live old-PPC bitmapInfo on Lion                  0x00000002 for 6/6
live old-PPC CWMatchBitmap                       0 on both
image-format mismatch                            LIVE-PROVEN
Lion titlebar                                    PARTIAL / non-draggable
next step                                        docs/ppc-carbon-gui-coreui-image-bitmapinfo-compat-integration.md
metric/header/pixel rewrite                      NOT AUTHORIZED
new titlebar mappings                            NOT AUTHORIZED
ArtFile200 forcing                               NOT AUTHORIZED
XNU                                              no source change indicated
```
