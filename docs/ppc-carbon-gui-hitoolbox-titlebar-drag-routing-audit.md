# PPC Carbon GUI HIToolbox titlebar drag-routing audit

## Status

NEXT CONTROLLED STATIC STEP after the CoreUI window-frame rendering contract is
closed.

The exact-two slot-0 format correction is now visually successful on Lion:
the titlebar background and both top corners are restored while the accepted
traffic-light rendering remains sharp. The v2 log also satisfies the dedicated
format-adapter contract: all five shared-art substitutions return
`ADAPTER_PASS`, the three ImageIO source bindings are present, the three
byte-identical mapped images use `bitmapInfo=0x2`, and only legacy
`0x4e8f` / `0x4e91` use `0x2002`.

The generic Lion runner still exits 1 because the already-known notification
oracle is unchanged: the former ColorSync registration 7 is absent and the old
requests 8..21 appear as requests 7..20. This is not a rendering-adapter
failure and is not accepted as a new notification policy.

The remaining titlebar defect is now interaction-only: the fully rendered
titlebar is still not draggable.

## Why the next step is static

Earlier frame/hit analysis already proved that Snow PPC and native Lion map the
same hit-mask bits to the same classic window-part codes. That evidence does
not authorize a part-code rewrite.

The historical Lion PPC process executes the accepted Snow PPC HIToolbox image
from the unchanged Rosetta shared cache. Before adding any live event
interposer, identify the exact Snow PPC route among:

```text
ThemeWindowDef::HitSelf(Point)
GetThemeWindowRegionHit
HIThemeGetWindowRegionHit
FindWindow
DragWindow
TDragTracker
TWindowTracker::TrackWindow
standard/window event handlers
```

The result will determine the narrowest passive live trace that can distinguish
event delivery, hit classification, drag dispatch, and actual tracking.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-hitoolbox-titlebar-drag-routing.py
Git blob 8e456b3c04d6d9143c478cb19f15ff513ea811f0
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-hitoolbox-titlebar-drag-routing-v1
```

Pinned runtime identities:

```text
Snow 10.6.8 / 10K549 / HIToolbox ppc7400
fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f

dyld_shared_cache_rosetta
2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911

dyld_shared_cache_rosetta.map
66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9
```

The analyzer emits full bodies for the exact hit/drag focus symbols, all
`TDragTracker` / `TWindowTracker` text symbols, a focused interaction symbol
inventory, and direct callers resolved from both symbolic and numeric branch
targets.

## Safety constraints

- Snow static-only; do not launch the PPC subject.
- Do not rerun the Lion rendering test.
- Do not click or drag any test window for this step.
- Do not interpose or patch private HIToolbox C++ methods.
- Do not alter `FindWindow`, `DragWindow`, hit masks, classic part codes,
  event routing, or control actions.
- Retain the completed exact-five slot-0 mapping, exact-two corner
  `bitmapInfo=0x2002` rule, and exact-six traffic-light bitmap rule unchanged.
- Do not change the distributed-notification broker.
- Do not change CGS compatibility, CoreUI resources, Rosetta caches, or XNU.

## Phase A — update and pin

On Snow Leopard 10.6.8 / 10K549:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-hitoolbox-titlebar-drag-routing.py)" = \
  "8e456b3c04d6d9143c478cb19f15ff513ea811f0" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-hitoolbox-titlebar-drag-routing.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-hitoolbox-titlebar-drag-routing-v1"$' \
  ./scripts/audit-ppc-carbon-gui-hitoolbox-titlebar-drag-routing.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-hitoolbox-titlebar-drag-routing.py","rb").read(),"titlebar-drag-routing.py","exec")' || exit 1
```

## Phase B — static drag-routing report

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-hitoolbox-titlebar-drag-routing.py \
  ./ppc-carbon-gui-hitoolbox-titlebar-drag-routing-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
runtime_on_lion_contract=accepted_identical_snow_ppc_cache
hitoolbox_slice_exact=YES
DragWindow_uses_TWindowTracker=YES
HitSelf_calls_GetThemeWindowRegionHit=YES
GetThemeWindowRegionHit_calls_HIThemeGetWindowRegionHit=YES
part_code_rewrite_authorized=NO
private_HIToolbox_patch_authorized=NO
titlebar_drag_routing_audit_exact=YES
RESULT: PASS
```

## Review gate

### A standard/window-event handler directly reaches DragWindow

The next live test should trace only public event delivery plus `DragWindow`
entry/exit and window bounds, with one manual titlebar drag on Snow and one on
Lion. Do not interpose `HitSelf` or rewrite part codes.

### The event handler bypasses DragWindow and reaches TWindowTracker directly

Do not use a `DragWindow`-only trace. Prepare a passive event-delivery trace
plus the narrowest stable exported boundary immediately before tracking.

### HitSelf is called through a discoverable window-event route before tracking

The next live trace should correlate one mouse-down sequence with event
delivery and the existing exported hit-result boundary. Preserve the returned
part code exactly; no translation is authorized.

### Direct callers are unresolved or only indirect virtual dispatch is visible

Do not guess from symbol names. Use the emitted candidate inventory to prepare
one further static vtable/call-slot audit before any live interposition.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-hitoolbox-titlebar-drag-routing-snow.txt
```

## Current boundary

```text
Snow v2 slot0-format control                     PASS
Lion v2 slot0 substitutions                      5 / all ADAPTER_PASS
Lion corner formats                              0x4e8f,0x4e91 -> 0x2002
Lion titlebar/frame rendering                    RESTORED
Lion traffic-light rendering                     SHARP / retained
Lion titlebar dragging                           FAIL
known ColorSync notification deletion            persists / held separately
hit part-code rewrite                            NOT AUTHORIZED
interaction compatibility                        NONE YET
next step                                        Snow static titlebar drag-routing audit
XNU                                              no source change indicated
```
