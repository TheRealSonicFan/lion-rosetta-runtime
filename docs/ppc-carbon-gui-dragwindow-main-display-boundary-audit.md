# PPC Carbon GUI DragWindow/main-display boundary audit

## Status

**NEXT STEP — INSPECT THE DIRECT `_DragWindow -> _CGMainDisplayID` CONTRACT BEFORE CHOOSING AN ADAPTER OR IMAGE-LOCAL REPAIR.**

The complete import-closure audits pass on both pinned releases. They overturn the earlier candidate-limited impression that HIToolbox has no relevant CoreGraphics import: HIToolbox imports hundreds of CoreGraphics entry points, and the direct-call closure from the titlebar roots reaches many of them.

The most important new Snow result is concrete and close to the real drag entry point: `_DragWindow` itself directly calls the imported public `_CGMainDisplayID`. That call is interposable at the HIToolbox/CoreGraphics image boundary. However, the known failing zero-cache conversion remains a different sequence inside CoreGraphics: `_CGSGetUnflippedEventLocation` calls private `_CGSMainDisplayID` and then private `_CGSGetDisplayBounds` image-locally. Therefore the existence of the public `_DragWindow` call is not enough to authorize an interposer; the next static step must establish what that result controls, when it is consumed relative to tracker setup, and whether it can affect the later event-unflip fallback at all.

The broad closure is intentionally not treated as a causal call graph. Snow reaches 590 CoreGraphics-import call sites and Lion reaches 627, while both closures also retain many unresolved direct/indirect calls. A reachable import far from the titlebar root is only a candidate. This audit narrows the evidence to the actual `_DragWindow`, tracker, and public/private main-display/bounds bodies.

## Prepared analyzer

Use:

~~~text
scripts/audit-ppc-carbon-gui-dragwindow-main-display-boundary.py
analyzer_version=2
audit_contract=carbon-gui-dragwindow-main-display-boundary-v1
Git blob 10af49b4dabfe7b7b662a6e755fbd85c1882c6f9
~~~

The analyzer is static-only. Version 2 is a performance-only correction to the original implementation: version 1 rebuilt the complete HIToolbox call graph once for every selected import and rebuilt symbol indexes for every function, which can consume one CPU for tens of minutes on Snow Leopard without producing visible progress. Version 2 caches the symbol indexes and parsed calls, builds the graph once, uses a deque-based breadth-first search, and prints progress before the graph phase. If version 1 is still running, interrupt it and rerun from current main; its partial output is not evidence.

The analyzer verifies the pinned slices, then:

- dumps the exact release-local `_DragWindow` body and its parsed calls;
- records direct `_DragWindow` imports for `_CGMainDisplayID`, `_CGDisplayBounds`, cursor/window-bounds, and event retrieval APIs;
- computes shortest direct-call paths from `_DragWindow` to those selected CoreGraphics imports;
- dumps the focused `TWindowTracker::TrackWindow` and mouse-move bodies;
- dumps CoreGraphics `_CGMainDisplayID`, `_CGSMainDisplayID`, `_CGDisplayBounds`, `_CGSGetDisplayBounds`, `_CGSGetUnflippedEventLocation`, and `_CGEventGetUnflippedLocation`;
- records whether public main-display/bounds APIs directly enter the same private image-local functions used by the failing zero-cache fallback.

Pinned slices remain:

~~~text
Snow 10.6.8 / 10K549
CoreGraphics ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a
HIToolbox ppc7400
fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f

Lion 10.7.5 / 11G63
CoreGraphics i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
HIToolbox i386
b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6
~~~

## Phase A — Snow Leopard PPC

Run on Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-dragwindow-main-display-boundary.py \
  ./ppc-carbon-gui-dragwindow-main-display-boundary-snow.txt
~~~

Require:

~~~text
mode=snow
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
dragwindow_direct_import=_CGMainDisplayID present=YES
dragwindow_main_display_boundary_audit_exact=YES
RESULT: PASS
~~~

Do not build or load an interposer even if the direct public call is confirmed.

## Phase B — Lion native reference

Only after Snow passes, run the same analyzer on Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-dragwindow-main-display-boundary.py \
  ./ppc-carbon-gui-dragwindow-main-display-boundary-lion.txt
~~~

Require:

~~~text
mode=lion
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
dragwindow_main_display_boundary_audit_exact=YES
RESULT: PASS
~~~

The presence or absence of a Lion direct `_DragWindow -> _CGMainDisplayID` call is evidence, not a pass criterion.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-dragwindow-main-display-boundary-snow.txt
ppc-carbon-gui-dragwindow-main-display-boundary-lion.txt
~~~

## Decision gate after the audit

If the Snow `_DragWindow -> _CGMainDisplayID` result is consumed only for initial drag constraints/setup and the later zero-cache event conversion still reaches private `_CGSMainDisplayID` independently inside CoreGraphics, a public `_CGMainDisplayID` interposer is not a sufficient repair for the observed failure. The interposable-seam branch would then be closed for the actual fallback, and the next design review must compare a narrowly justified image-local CoreGraphics repair with a fully specified display-mapping lifecycle projection.

If the audit instead proves that the imported public call seeds or controls the exact state consumed by the zero-cache fallback, a call-scoped adapter may be reviewed, but it must still use the proven projection only under the display lock, restore the process-local pointer before unlock, and avoid exposing a partial record to bind/rebind or notification-driven lifecycle work.

No count>1 or persistent projection is authorized by this audit.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not build or load a new interposer.
- Do not patch CoreGraphics or HIToolbox.
- Do not modify process-local display pointers.
- Do not make the +0x1c proof projection persistent.
- Do not mutate server-owned display shared memory.
- Do not normalize or substitute display IDs.
- Do not rewrite event or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, or XNU.
