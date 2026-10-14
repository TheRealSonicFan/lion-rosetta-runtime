# PPC Carbon GUI CoreUI bitmap-info compatibility integration

## Status

NEXT CONTROLLED LIVE COMPATIBILITY STEP after the completed passive CoreUI image-constructor trace.

## Reviewed result that authorizes this step

The passive trace artifact matches the pinned source/build contract:

```text
interposer_source_git_blob=2b8ff38429e3d7d494f96ed67bc42d23f213965c
compat_build_id=coreui-image-constructor-passive-trace-v1
artifact_sha256=da0dc7d2dc7c04d87e7a7f13175ebca0dbc0240605eb62736429d0fcb9ea320c
```

Snow Leopard passes with exactly six old-PPC CoreUI image constructions:

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

Manual Snow titlebar result:

```text
visual appearance  NORMAL
```

Lion also passes the entire accepted stack and reaches the exact 400x222 titled window, while the same cached Snow-PPC CoreUI constructor still emits exactly six calls with Snow bitmap semantics:

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

Manual Lion result remains:

```text
visual appearance  PARTIAL / transparent titlebar and distorted traffic lights
titlebar drag      DOES NOT MOVE WINDOW
```

Together with the completed static image-format audit, this closes the remaining ambiguity:

- all six Snow bodies are byte-0-alpha under the raw-body discriminator;
- all six Lion bodies are byte-3-alpha;
- Snow's live PPC path uses bitmap-info `0x00000002`;
- the same live PPC path on Lion still uses `0x00000002`;
- Lion native CoreUI's equivalent constructor uses `0x00002002`;
- neither live run enters the old PPC `CWMatchBitmap` branch.

The image-format mismatch is therefore live-proven for the exact historical subject. A narrowly guarded bitmap-info conversion is now authorized. Pixel bytes, ArtFile records, metrics, titlebar mappings, providers, and image geometry remain unchanged.

The non-draggable Lion titlebar is recorded as a second functional discriminator. This step does not assume the image-format correction will fix dragging; the Lion manual gate must report visual fidelity and drag behavior separately.

## Objective

Change only one argument at the exact old-PPC CoreUI image-construction boundary on Lion:

```text
CGImageCreate bitmapInfo: 0x00000002 -> 0x00002002
```

under the exact live-proven predicate:

```text
caller image             CoreUI.framework
caller return offset     0x000299e0
width                    16
height                   16
bits/component           8
bits/pixel               32
bytes/row                64
incoming bitmapInfo      0x00000002
mode                     lion-bitmapinfo-0x2002-v1
```

No other argument or return value is modified.

Snow uses the same artifact in passthrough mode and requires its exact live-proven 14x16 constructor predicate:

```text
caller image             CoreUI.framework
caller return offset     0x000299e0
width                    14
height                   16
bits/component           8
bits/pixel               32
bytes/row                56
incoming bitmapInfo      0x00000002
mode                     snow-passthrough-v1
```

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-image-bitmapinfo-compat-interposer.c
Git blob 9d44128acbe49de49621104c9ffc2b0c0cd74589

scripts/build-ppc-coreui-image-bitmapinfo-compat-on-snowleopard.sh
Git blob 72616e786d8bac3655cb1789612e247fcd1a12ac

scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh
Git blob 5357b88c443d2bef39389589291ba2b66b8157ad

scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh
Git blob 99e5c775a71e24f5b248380256a743b7809ab706
```

Build ID:

```text
coreui-image-bitmapinfo-compat-v1
```

The adapter interposes only `CGImageCreate`.

## Safety constraints

- Do not modify any ArtFile file or record.
- Do not copy or byte-swap pixel buffers.
- Do not alter width, height, stride, color space, provider, decode array, interpolation flag, or rendering intent.
- Do not alter the thirteen serialized titlebar metrics.
- Do not alter the exact-six titlebar key mapping.
- Do not interpose `CWMatchBitmap`, `LoadFromArtFile`, renderer routines, or event/hit-test APIs.
- Do not force ArtFile200 or a scale factor.
- Do not change any accepted CGS, ShapeWindow, backing-sync, CPS, notification, or HIToolbox compatibility.
- Do not modify CoreUI, CoreGraphics, WindowServer, the Rosetta cache, or XNU.
- Stop after Snow if visual appearance or dragging regresses.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-image-bitmapinfo-compat-interposer.c)" = \
  "9d44128acbe49de49621104c9ffc2b0c0cd74589" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-image-bitmapinfo-compat-on-snowleopard.sh)" = \
  "72616e786d8bac3655cb1789612e247fcd1a12ac" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh)" = \
  "5357b88c443d2bef39389589291ba2b66b8157ad" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh)" = \
  "99e5c775a71e24f5b248380256a743b7809ab706" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-image-bitmapinfo-compat-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh || exit 1
```

No XNU build action is required.

## Phase B — build the compatibility dylib on Snow

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-image-bitmapinfo-compat-on-snowleopard.sh \
  ./payload/pm-coreui-image-bitmapinfo-compat.dylib || exit 1
```

Require:

```text
interposer_source_git_blob=9d44128acbe49de49621104c9ffc2b0c0cd74589
compat_build_id=coreui-image-bitmapinfo-compat-v1
```

The output must be 32-bit PPC and contain exactly one `__DATA,__interpose` tuple for `CGImageCreate`.

## Phase C — one Snow passthrough control

Place/reuse the accepted subject, backing-sync compatibility artifact, exact-six titlebar artifact, observer, and their SHA sidecars in Snow's `payload/` directory, together with the newly built bitmap-info compatibility artifact and its `.info.txt` / `.sha256`.

Run:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
```

Require:

```text
titlebar_passthrough_count=6
image_bitmapinfo_exact_passthrough_call_count=6
image_bitmapinfo_passthrough_result_count=6
image_bitmapinfo_predicate_reject_count=0
image_bitmapinfo_adapted_count=0
image_bitmapinfo_adapter_pass_count=0
image_bitmapinfo_adapter_null_count=0
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

Manual Snow gates:

```text
Snow titlebar visually normal: YES
Snow titlebar draggable: YES/NO
```

The visual gate must be YES. Record the drag result as the positive-control comparison for Lion. Do not proceed if Snow behavior regresses from the known-good state.

## Phase D — transfer only the new compatibility artifact

Transfer exactly:

```text
pm-coreui-image-bitmapinfo-compat.dylib
pm-coreui-image-bitmapinfo-compat.dylib.info.txt
pm-coreui-image-bitmapinfo-compat.dylib.sha256
```

to Lion's runtime `payload/`.

Do not replace the accepted six-key titlebar artifact or any existing CGS/HIToolbox compatibility artifact.

## Phase E — one Lion bitmap-info compatibility integration

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh || exit 1
```

Require the established full-stack gates plus:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
image_bitmapinfo_exact_call_count=6
image_bitmapinfo_adapted_count=6
image_bitmapinfo_adapter_pass_count=6
image_bitmapinfo_predicate_reject_count=0
image_bitmapinfo_passthrough_result_count=0
image_bitmapinfo_adapter_null_count=0
windowserver_observer_pass_count=1
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_PASS
RESULT: PASS
```

Manual Lion gates:

```text
Lion titlebar visually normal: YES/NO/PARTIAL
Lion titlebar draggable: YES/NO
```

If practical, wait until the observer has already captured the initial 400x222 frame before attempting the drag. The automated gate requires only that the original geometry was observed; it does not require the window to remain at the original position after manual interaction.

## Decision gate

### Visual titlebar becomes normal

The image-format incompatibility was causal for visual fidelity. Keep the bitmap-info adapter.

If dragging is also restored, the current Carbon titlebar defect is closed for the exact historical subject.

If dragging remains NO, preserve the bitmap-info adapter and move next to a **separate read-only titlebar hit-test/window-move audit**. Do not broaden the image adapter or modify titlebar metrics merely to address dragging.

### Visual titlebar improves but remains PARTIAL

Preserve the exact result and compare the remaining defect against the three release-specific titlebar metric rectangles. Do not alter pixels. The next step should trace the downstream renderer/hit-test consumers of those metrics, with drag behavior recorded as a co-discriminator.

### Visual titlebar is unchanged

Remove the bitmap-info adapter from the candidate fix path. Despite the proven format mismatch, it is not sufficient to explain the visible defect in this subject. Return to downstream metric/render-state use before any persistent compatibility decision.

### Any automated gate fails or predicate reject occurs

Stop. Preserve the raw log and do not broaden the predicate.

## Return evidence

Return:

```text
pm-coreui-image-bitmapinfo-compat.dylib.info.txt
pm-coreui-image-bitmapinfo-compat.dylib.sha256
ppc-carbon-gui-coreui-image-bitmapinfo-compat-snow.log
ppc-carbon-gui-coreui-image-bitmapinfo-compat-snow-observer.log
lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.log
lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.raw.log
lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat-observer.log
```

Also state:

```text
Snow titlebar visually normal: YES/NO
Snow titlebar draggable: YES/NO
Lion titlebar visually normal: YES/NO/PARTIAL
Lion titlebar draggable: YES/NO
```

Do not return the dylib binary unless specifically requested.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
exact-six titlebar translations                  6 / guard rejects 0
Snow live old-PPC bitmapInfo                     0x00000002 for 6/6
Lion live old-PPC bitmapInfo                     0x00000002 for 6/6
Snow live CWMatchBitmap                          0
Lion live CWMatchBitmap                          0
Lion native equivalent bitmapInfo                0x00002002
Snow raw-body alpha position                     BYTE0
Lion raw-body alpha position                     BYTE3
image-format mismatch                            LIVE-PROVEN
Lion titlebar appearance                         PARTIAL / unchanged
Lion titlebar drag                               NO
next step                                        one exact bitmapInfo 0x2 -> 0x2002 integration
pixel/resource rewrite                           NOT AUTHORIZED
metric rewrite                                   NOT AUTHORIZED
new titlebar mappings                            NOT AUTHORIZED
XNU                                              no source change indicated
```
