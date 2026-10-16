# PPC Carbon GUI drag event/display contract audit

## Status

**MOVE ENTRY INTERPOSE UNOBSERVABLE / EVENT-DISPLAY STATIC AUDIT NEXT.**

The passive CGSMoveWindow experiment did not expose the intended cross-image
entry boundary. The tracer artifact itself is valid: it is the expected
32-bit PPC build, contains one 8-byte __DATA,__interpose tuple, binds
_CGSMoveWindow, carries build ID cgs-move-window-entry-passive-v1, and has
SHA-256 51e546581ee2028756e6caafe91f96fd9d5329c58b3740336987fd16127936e5.
Both Snow and Lion loaded that exact artifact and emitted its build marker.
Neither run emitted a single PM_CGS_MOVE_WINDOW_ENTRY or
PM_CGS_MOVE_WINDOW_RESULT record.

That absence is decisive because Snow still issued 66 successful
0x7218/0x727c move transactions and completed the public titlebar-drag
positive control. Lion likewise issued 14 move transactions and reproduced
the off-screen jump. The external CGSMoveWindow binding is therefore bypassed
by the executing shared-cache call path; no target-point value may be inferred
from this experiment.

The live comparison nevertheless exposes a stronger discriminator immediately
upstream of the bad Lion movement:

- Snow logged zero CGSGetDisplayBounds(display 0) diagnostics.
- Lion logged eight CGSGetDisplayBounds(display 0) diagnostics.
- Lion's first public titlebar mouse-down is sane at h=302, v=109 and
  FindWindow=inDrag (4).
- Immediately before the first bad move, Lion logs
  CGSGetDisplayBounds(display 0), then the movementGroup query for window 849,
  then a successful 0x7218 move with deltas (-302,-98).
- The observer subsequently records the origin changing from (120,98) to
  (-182,17177), then (-182,17281), and later (-182,-113).
- Snow shows the same movementGroup -> 0x7218 ordering without the display-0
  diagnostic and with ordinary small move deltas.

This is not authorization to normalize display 0. The translated process runs
the Snow-era PPC CoreGraphics/HIToolbox contract from the Rosetta cache; Lion
native code is only the release-reference contract. The next step must identify
where the event/display identity and point fields enter the Snow PPC drag path
and whether their layout or interpretation changed across releases.

## Objective

Resolve the static path from the returned event stream to the display identity
and mouse coordinates used during titlebar dragging.

The audit asks:

1. Which event-record field supplies the display identity consumed by
   CGSGetUnflippedEventLocation and CGSGetDisplayBounds?
2. Do Snow PPC and Lion native use the same event-record offsets for display
   identity and mouse x/y?
3. What exactly happens to the output rectangle and return status when
   CGSGetDisplayBounds receives display 0?
4. Which TrackMouseLocation / TWindowTracker / TDragTracker path consumes
   that converted point before the movementGroup and 0x7218 request?
5. Does the evidence select an event-record projection boundary, a
   display-identity boundary, or neither?

The audit explicitly does not treat 0x721f/0x7283 as CGSGetDisplayBounds.
The earlier protocol audit resolves that ID pair to CGSGetSystemWindow on the
Lion native reference.

## Prepared analyzer

Current runtime main provides:

~~~text
scripts/audit-ppc-carbon-gui-drag-event-display-contract.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-drag-event-display-contract-v1
~~~

Current analyzer Git blob:

~~~text
30b3b38527b01e870273816816770826ccec219b
~~~

It reads and disassembles only the release-local CoreGraphics and HIToolbox
images plus Rosetta cache/map provenance. It emits complete symbol-bounded
windows and caller references for the display-bounds, event-location,
next-event/event-record translation, TrackMouseLocation, tracker, point bridge,
and DragWindow families.

Pinned architecture slices are:

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

## Safety constraints

- Do not launch the PPC subject for this step.
- Do not drag the test window for this step.
- Do not rebuild v9 or the failed CGSMoveWindow entry tracer.
- Do not add another dyld interposer.
- Do not rewrite, clamp, byte-swap, or normalize 0x7218 move payloads.
- Do not normalize display ID 0.
- Do not rewrite next-event stream payloads.
- Do not patch private HIToolbox tracker methods.
- Do not add the deferred out-of-line next-event adapter.
- Keep the accepted GetSharedWindow bridge and exact-21 notification policy
  unchanged.
- Do not change CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.
- Verify the current repository on a modern TLS-capable staging system,
  transfer it to Snow/Lion offline, and use SHA-256 for legacy-target
  provenance. No Git network or Git-object command is required on either
  legacy system.

## Snow static report

On Snow Leopard 10.6.8 / 10K549, from the transferred current runtime tree:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-drag-event-display-contract.py \
  ./ppc-carbon-gui-drag-event-display-contract-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-drag-event-display-contract-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
drag_event_display_contract_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63, from the separately transferred current runtime tree:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-drag-event-display-contract.py \
  ./ppc-carbon-gui-drag-event-display-contract-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-drag-event-display-contract-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
drag_event_display_contract_audit_exact=YES
RESULT: PASS
~~~

If either report says RESULT: FAIL, return it unchanged. Do not compensate by
running another live drag test.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-drag-event-display-contract-snow.txt
ppc-carbon-gui-drag-event-display-contract-lion.txt
~~~

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Snow public titlebar drag                         PASS / normal movement
Lion public mouse-down                            YES / inDrag (4)
CGSMoveWindow entry tracer                        loaded but 0 calls on Snow/Lion
external CGSMoveWindow interpose boundary         UNSOUND / bypassed
Snow 0x7218 move count in returned run            66
Lion 0x7218 move count in returned run            14
Snow CGSGetDisplayBounds(display 0)               0
Lion CGSGetDisplayBounds(display 0)               8
first Lion mouse-down                             (302,109)
first Lion bad move delta                         (-302,-98)
Lion observed bad origin                          (-182,17177)
move-payload rewrite                              NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
event-payload rewrite                             NOT AUTHORIZED
private HIToolbox patch                           NOT AUTHORIZED
next action                                       static event/display contract audit
XNU                                               unchanged
~~~
