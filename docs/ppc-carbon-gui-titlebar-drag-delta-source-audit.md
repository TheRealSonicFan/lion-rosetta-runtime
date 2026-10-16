# PPC Carbon GUI titlebar drag delta-source static audit

## Status

**COMPLETED STATIC PASS / CGSMOVEWINDOW ENTRY TRACE NEXT.**

Both returned reports pass with the exact pinned Snow PPC and Lion native
reference identities. The differential closes three candidate boundaries.

First, the move wire contract is release-stable: Snow PPC and Lion native
__CGSMoveWindow both use request/reply 0x7218/0x727c with the same 0x2c/0x2c
geometry. Second, public CGSMoveWindow on both releases accepts a two-float
target point and derives integer deltas before the Mach request. Third, the
classic DragWindow input remains a two-short QuickDraw Point, while both
tracking implementations explicitly bridge floating-point mouse-location data
back through HIPointToQDPoint before Point-based tracker logic.

The 0x42de live alias remains a useful discriminator, but this static pass does
not identify a single instruction that corrupts the value. The unresolved
live boundary is now the target CGPoint arriving from HIToolbox's bounds-update
path at CoreGraphics CGSMoveWindow. Follow
docs/ppc-carbon-gui-cgs-move-window-entry-live-trace.md next. No move payload
rewrite or private HIToolbox patch is authorized.

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

~~~text
Snow drag-delta static audit                      PASS / exact provenance
Lion native-reference drag-delta audit            PASS / exact provenance
0x7218/0x727c move wire contract                  release-stable
CGSMoveWindow target-point contract               two-float point both releases
DragWindow initial QD Point                       structurally aligned
TrackWindow mouse point conversion                HIPointToQDPoint explicit
0x42de alias instruction                          not yet isolated
v9 GetSharedWindow bridge                         retained / target-proven
Lion public titlebar input                        restored
Lion drag geometry                                corrupt / off-screen
move-payload rewrite                              NOT AUTHORIZED
private HIToolbox patch                           NOT AUTHORIZED
next action                                       docs/ppc-carbon-gui-cgs-move-window-entry-live-trace.md
XNU                                               unchanged
~~~
