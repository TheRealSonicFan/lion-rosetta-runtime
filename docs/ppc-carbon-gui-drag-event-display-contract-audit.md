# PPC Carbon GUI drag event/display contract audit

## Status

**COMPLETED / EVENT XY LAYOUT ALIGNED / MAIN-DISPLAY LOOKUP NEXT.**

Both returned reports pass the exact provenance and validation gates. They
resolve the display-0 symptom more narrowly than the original audit question.

Snow PPC and Lion native `_CGSGetUnflippedEventLocation` both read the event
point from offsets `0x0c/0x10`. Their release-local cached vertical-extent
field differs (`0xc6` on Snow, `0xbe` on Lion), but that field is not a
display ID. When the Snow field is zero, the executing PPC path calls
`_CGSMainDisplayID` and passes its return value directly to
`_CGSGetDisplayBounds`; only after a successful bounds query does it cache the
vertical extent back into the event object.

The live `CGSGetDisplayBounds(display 0)` diagnostic therefore selects the
main-display lookup as the next boundary: at that exact Snow PPC fallback the
main-display result reaching the bounds call is zero. The x/y event storage is
not the current mismatch, and no event-field rewrite is authorized.

The authoritative next procedure is
`docs/ppc-carbon-gui-main-display-id-contract-audit.md`. It is static-only and
compares the Snow PPC `_CGSMainDisplayID` / `_lookupMainDisplay` /
display-initialization path against Lion's native reference before any live
display-ID substitution or compatibility rule is considered.

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
