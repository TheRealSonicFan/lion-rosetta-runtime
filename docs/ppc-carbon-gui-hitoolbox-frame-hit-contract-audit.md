# PPC Carbon GUI HIToolbox window-frame / hit-test contract audit

## Status

NEXT CONTROLLED STATIC STEP after the bitmap-info compatibility integration improved the Lion traffic-light rendering but left the titlebar frame/background absent and the titlebar non-draggable.

## Reviewed result that advances this step

The returned compatibility artifact matches the pinned source/build identity:

```text
interposer_source_git_blob=9d44128acbe49de49621104c9ffc2b0c0cd74589
compat_build_id=coreui-image-bitmapinfo-compat-v1
artifact_sha256=87a7c0cf397db0b93a0ad83af3b3fea71d9c8dd77c224ad5fc5d9729b9e7b9b5
```

The Snow passthrough control passes exactly:

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

Manual Snow gates are both positive:

```text
Snow titlebar visually normal: YES
Snow titlebar draggable: YES
```

The Snow observer independently records the window moving away from its initial `(120,98)` position during the run, consistent with the manual drag result.

The Lion integration also passes exactly:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
image_bitmapinfo_exact_call_count=6
image_bitmapinfo_predicate_reject_count=0
image_bitmapinfo_passthrough_result_count=0
image_bitmapinfo_adapted_count=6
image_bitmapinfo_adapter_pass_count=6
image_bitmapinfo_adapter_null_count=0
windowserver_observer_pass_count=1
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_PASS
RESULT: PASS
```

The exact `0x2 -> 0x2002` conversion is therefore live-proven for all six target CoreUI image constructions. Manual review shows a **real but incomplete** visual improvement:

```text
traffic-light controls  materially sharper / no longer blurry
titlebar background     still transparent / absent
top frame boundary      still absent
titlebar drag           NO
```

The bitmap-info adapter is retained. Its positive effect is specific to image-channel interpretation and does not explain the remaining frame or hit-test behavior.

The new combined visual/functional evidence points above CoreUI image construction and back into the Snow-era PPC HIToolbox window-definition path. Historical Snow/Lion static evidence already identifies the exact frame/hit family:

```text
ThemeWindowDef::DrawFrame()
ThemeWindowDef::HitSelf(Point)
ThemeWindowDef::CopyShapeInternal(...)
ThemeWindowDef::CopyShape(...)
ThemeWindowDef::InitializeWindowData()
ThemeWindowDef::DrawWidgetFromPartCode(...)
HIThemeDrawWindowFrame / internal
HIThemeGetWindowRegionHit
HIThemeGetWindowShape / internal
LayoutEngine::HitLayout(...)
LayoutEngine::ApplyLayoutBackground(...)
LayoutEngine::DrawLayout(...)
```

It also exposes one release-contract change that must be interpreted carefully: Snow PPC contains a separate `_HIThemeDrawDocumentWindowWithCoreUI` helper, while Lion native HIToolbox does not. The historical Lion PPC process still executes the accepted Snow PPC HIToolbox code from the unchanged Rosetta shared cache, so Lion native HIToolbox is a **reference for the release-local contract**, not the code actually executing in the PPC process.

This stage therefore returns to a read-only Snow/Lion HIToolbox differential before any hit-test, frame, or metric adapter is considered.

## Objective

Determine whether the remaining two symptoms share one release-specific HIToolbox window-definition contract:

1. why the old PPC path does not produce the normal titlebar/frame background on Lion; and
2. why a point in the visible titlebar does not lead to the normal draggable-window hit behavior on Lion.

The analyzer captures the exact Snow PPC and Lion native frame/hit implementations and their immediate layout helpers. It does not launch or modify the historical PPC subject.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py
Git blob 942fd692eb07bf288e2b5b236939051fc27c3ec1
```

Analyzer contract:

```text
analyzer_version=1
audit_contract=carbon-gui-hitoolbox-frame-hit-contract-v1
```

The analyzer pins:

```text
Snow 10.6.8 / 10K549 HIToolbox ppc7400
fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f

Lion 10.7.5 / 11G63 HIToolbox i386
b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6

dyld_shared_cache_rosetta
2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911

dyld_shared_cache_rosetta.map
66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9
```

It emits full function bodies and call/branch lines for the exact critical functions, including:

```text
HIThemeGetWindowRegionHit
HIThemeGetWindowShape
HIThemeDrawMovableWindow
HIThemeDrawDocumentWindow
HIThemeDrawDocumentWindowWithCoreUI        Snow expected
HIThemeDrawWindowFrameInternal
HIThemeDrawWindowFrame
LayoutEngine::HitLayout
LayoutEngine::ApplyLayoutBackground
LayoutEngine::DrawLayout
ThemeWindowDef::ClearStructure
ThemeWindowDef::InitializeWindowData
ThemeWindowDef::SetupTrackingRectForWidgetGroup
ThemeWindowDef::CopyShapeInternal
ThemeWindowDef::CopyShape
ThemeWindowDef::HitSelf
ThemeWindowDef::DrawFrame
```

It also inventories optional surrounding APIs such as `GetThemeWindowRegion`, `GetWindowRegion`, `FindWindow`, `DragWindow`, `ThemeWindowDef::StateChanged`, and `DrawWidgetFromPartCode`, and records the `HLTBUnrolledWindows` / “drawing with unrolled primitives” contract markers.

## Safety constraints

- Do not launch the PPC Carbon subject.
- Do not rerun the bitmap-info integration.
- Keep the accepted bitmap-info adapter unchanged.
- Do not interpose or modify `FindWindow`, `DragWindow`, `HIThemeGetWindowRegionHit`, `HIThemeGetWindowShape`, or any `ThemeWindowDef` method yet.
- Do not alter the titlebar metrics.
- Do not alter the exact-six CoreUI key mappings.
- Do not alter pixel bytes, ArtFile records, or the Snow `Extras.rsrc` compatibility resource.
- Do not broaden the existing AddTrackingArea or other CGS compatibility.
- Do not change WindowServer, CoreUI, HIToolbox, Rosetta caches, LaunchServices, Cocoa, or XNU.
- No kernel rebuild or reboot is required.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py)" = \
  "942fd692eb07bf288e2b5b236939051fc27c3ec1" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-hitoolbox-frame-hit-contract-v1"$' \
  ./scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py","rb").read(),"audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py","exec")' || exit 1
```

Do not proceed if Phase A fails.

## Phase B — Snow PPC frame/hit contract

On Snow Leopard 10.6.8 / 10K549:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py \
  ./ppc-carbon-gui-hitoolbox-frame-hit-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
hitoolbox_slice_exact=YES
runtime_ppc_hitoolbox_contract=local_snow_ppc_reference
document_window_with_coreui_present=YES
frame_hit_contract_exact=YES
RESULT: PASS
```

Do not launch the PPC subject after producing the report.

## Phase C — Lion native reference contract

On Lion 10.7.5 / 11G63:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-hitoolbox-frame-hit-contract.py \
  ./ppc-carbon-gui-hitoolbox-frame-hit-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
required_arch=i386
hitoolbox_slice_exact=YES
runtime_ppc_hitoolbox_contract=accepted_identical_snow_ppc_cache
native_lion_hitoolbox_role=reference_for_release_contract_only
document_window_with_coreui_present=NO
frame_hit_contract_exact=YES
RESULT: PASS
```

Do not launch the PPC subject afterward.

## Review gate

Review the two reports as one differential.

### Frame and hit paths share one changed layout/shape contract

If `ThemeWindowDef::DrawFrame` and `ThemeWindowDef::HitSelf` converge on the same release-specific `HIThemeGetWindowShape`, `HIThemeGetWindowRegionHit`, layout table, or window-state field, isolate that exact value/return boundary next. Prefer a passive live trace of one exported boundary over modifying either renderer or event handling.

### Frame path differs but hit path is structurally independent

Keep the two defects separate. The visual next step should follow `HIThemeDrawWindowFrameInternal` / document-window drawing; the drag next step should follow `HitSelf` / `HIThemeGetWindowRegionHit`. Do not use a rendering fix to alter hit behavior.

### Hit path exposes a release-specific part-code translation

Do not force dragging immediately. First prepare a passive Snow/Lion trace that proves the actual titlebar click part code on the historical subject and confirms the exact old/new semantic mapping.

### No meaningful frame/hit code-contract differential

Do not patch these functions. The next discriminator should be live input/output capture at the exported frame/region boundaries, preserving the bitmap-info adapter and all current compatibility rules.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-hitoolbox-frame-hit-snow.txt
ppc-carbon-gui-hitoolbox-frame-hit-lion.txt
```

No binary or live log is required.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
CoreUI exact-six key adapter                     LIVE-PROVEN PASS
CoreUI bitmapInfo 0x2 -> 0x2002                 LIVE-PROVEN / RETAIN
traffic-light image fidelity                     materially improved / sharp
Lion titlebar background                        absent / transparent
Lion top frame boundary                         absent
Snow titlebar drag                              YES
Lion titlebar drag                              NO
Snow observer movement                          observed
Lion initial exact frame                        400x222 at (120,98), onscreen
next step                                       static HIToolbox frame/hit differential
metric rewrite                                  NOT AUTHORIZED
hit-test/part-code rewrite                      NOT AUTHORIZED
frame renderer interposition                    NOT AUTHORIZED
new CGS rule                                    NOT AUTHORIZED
XNU                                             no source change indicated
```
