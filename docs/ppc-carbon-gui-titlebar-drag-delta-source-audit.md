# PPC Carbon GUI titlebar drag delta-source static audit

## Status

**GETSHAREDWINDOW TARGET PROVEN / DRAG DELTA SOURCE NEXT.**

The returned v9 experiment is a major boundary advance. Snow remains a clean
public-drag control. On Lion, the GetSharedWindow bridge passed all 847 exact
calls with zero rejects, the former `_CGSFindSharedWindow` client type-check
diagnostic disappeared, the prior out-of-line event type-check diagnostic did
not recur, and the public Carbon dispatcher finally received titlebar input.
The first titlebar mouse-down was classified as `inDrag (4)`, and
WindowServer observed real movement.

The movement itself is wrong. The Lion window begins at `(120,98)`. The
first legacy move request (`0x7218/0x727c`, send/receive `0x2c/0x2c`)
carries deltas `(-317,-98)`, immediately moving the origin toward the
top-left. The next move request carries vertical delta `17118 = 0x42de`.
That value is the high 16-bit halfword of IEEE-754 float `111.0`, which is
also the first mouse-down vertical coordinate. Later bad vertical deltas track
the same pattern. WindowServer therefore appears to be applying the values the
PPC client actually sends; the next question is where the old HIToolbox drag
tracker constructs those scalars.

This is an evidence lead, not authorization to rewrite a move request. The
next controlled step is static-only.

## Objective

Resolve the exact point/delta conversion path from the Snow-era PPC
`DragWindow` implementation that executes under Rosetta on Lion to
CoreGraphics `CGSMoveWindow`.

The audit asks:

1. How does `DragWindow` pass the initial QuickDraw `Point` into
   `TDragTracker`?
2. Where are later cursor points obtained and converted before
   `TDragTracker::OnMouseMoved`?
3. Which instructions derive the horizontal and vertical values ultimately
   sent by `CGSMoveWindow`?
4. Can the observed `0x42de` delta be traced to the high halfword of float
   `111.0` before CoreGraphics transport?
5. Is the `0x7218/0x727c` move transport release-stable, confirming that the
   request payload is already wrong at entry rather than misinterpreted by
   WindowServer?

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-titlebar-drag-delta-source.py
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-drag-delta-source-v1
```

The analyzer is read-only. It slices and disassembles HIToolbox and
CoreGraphics, emits the full drag/tracker and move-window focus functions,
direct caller/reference lines, point/float conversion instructions, and
`0x7218/0x727c` protocol-immediate contexts.

Pinned provenance includes:

```text
Snow 10.6.8 / 10K549
HIToolbox ppc7400:
fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f

CoreGraphics ppc7400:
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63
HIToolbox i386:
b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6

CoreGraphics i386:
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
```

The Snow PPC HIToolbox image is the executing historical contract on Lion.
Native Lion HIToolbox/CoreGraphics are reference contracts for the release
differential only.

## Safety constraints

- Do not launch the PPC subject for this step.
- Do not drag a test window for this step.
- Do not rebuild the v9 compatibility dylib.
- Do not rewrite, clamp, byte-swap, or normalize `0x7218` move payloads.
- Do not patch private HIToolbox tracker methods.
- Do not add an out-of-line event adapter.
- Do not broaden or alter the accepted GetSharedWindow projection.
- Keep the exact-21 notification policy unchanged.
- Do not change CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
- Verify the current repository tree on a modern TLS-capable staging system,
  transfer it to Snow/Lion offline, and use SHA-256 for legacy-target artifact
  provenance. No Git network or Git-object command is required on either
  legacy system.

## Snow static report

On Snow Leopard 10.6.8 / 10K549, from the transferred current runtime tree:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-drag-delta-source.py \
  ./ppc-carbon-gui-titlebar-drag-delta-source-snow.txt
```

Require:

```text
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
hitoolbox_slice_exact=YES
coregraphics_slice_exact=YES
titlebar_drag_delta_source_audit_exact=YES
RESULT: PASS
```

## Lion static reference report

On Lion 10.7.5 / 11G63, from the separately transferred current runtime tree:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-drag-delta-source.py \
  ./ppc-carbon-gui-titlebar-drag-delta-source-lion.txt
```

Require:

```text
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
hitoolbox_slice_exact=YES
coregraphics_slice_exact=YES
titlebar_drag_delta_source_audit_exact=YES
RESULT: PASS
```

## Return evidence

Return only:

```text
ppc-carbon-gui-titlebar-drag-delta-source-snow.txt
ppc-carbon-gui-titlebar-drag-delta-source-lion.txt
```

If either report says `RESULT: FAIL`, return it unchanged and do not perform
another live drag experiment.

## Current boundary

```text
Snow GetSharedWindow control                       PASS
Lion GetSharedWindow bridge                       PASS 847/847
Lion FindSharedWindow type-check                   0
Lion out-of-line next-event type-check             0
Lion public titlebar mouse-down                    YES / inDrag (4)
Lion WindowServer movement                         YES
initial Lion window origin                         (120,98)
first Lion move delta                              (-317,-98)
second Lion vertical move delta                    17118 / 0x42de
observer after bad move                            off-screen coordinates
0x7218 payload rewrite                             NOT AUTHORIZED
private HIToolbox patch                            NOT AUTHORIZED
notification policy                               exact-21 unchanged
XNU                                               unchanged
next action                                       static drag-delta source audit
```
