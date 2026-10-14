# PPC Carbon GUI CGSShapeWindow protocol differential audit

## Status

**COMPLETE — PASS.** The Snow/Lion WindowServer observation differential is complete and valid. The exact same native observer binary SHA-256 0416a9b3bd9466708f6e540616be94fcc2ba65c5a89a68844602eee7bb220634 observed the same titled Carbon window on both systems, but the geometry differs decisively:

~~~text
Snow Leopard 10.6.8 / 10K549
  x=120 y=98 width=400 height=222
  layer=0 alpha=1.000
  onscreen=YES after initial creation
  manual observation=VISIBLE

Lion 10.7.5 / 11G63
  x=120 y=98 width=1 height=1
  layer=0 alpha=1.000
  onscreen=YES after initial creation
  manual observation=NOT VISIBLE
~~~

The Lion window therefore does materialize in WindowServer, has the expected owner/title, reaches onscreen state, remains fully opaque, and is positioned at the expected origin. The first visual discriminator is the collapsed 1x1 geometry, not process registration, notification registration, ordering, alpha, title, or simple WindowServer presence.

The Lion raw trace contains one earlier legacy request immediately associated with the longstanding CoreGraphics diagnostic:

~~~text
request id=0x724d
reply id=0x72b1
send=0x50
recv=0x2c
window=0x195
reply result=-304 / MIG_BAD_ARGUMENTS
diagnostic=MIG: server type check failure: CGSShapeWindow
~~~

The request payload also contains the values 0x62, 0x78, 0x208, and 0x140, which correspond to decimal 98, 120, 520, and 320 — the observed Snow frame edges for the expected x=120 y=98 width=400 height=222 window. That strongly raises the old CGSShapeWindow rejection from a merely correlated diagnostic to the first geometry-specific compatibility boundary. It is still not enough evidence to invent an ID or payload rewrite.

## Why this is an audit, not an adapter

The earlier post-NewWindow static audit proved that later generated shape setters changed between Snow and Lion, but the live 0x724d / 0x72b1 transaction is a different earlier helper. Snow's PPC _CGSShapeWindow path references an internal __CGSWindowShape; Lion's i386 _CGSShapeWindow path instead references __CGSCopyWindowShape before its later set-shape helpers.

The next step is therefore to recover the exact Snow PPC and Lion i386 contracts for that first inner shape operation and its surrounding _CGSShapeWindow call graph. Only after that differential is reviewed may a live compatibility experiment be authorized.

## Authoritative analyzer

Current runtime main:

~~~text
scripts/audit-ppc-carbon-gui-cgsshapewindow-protocol.py
Git blob 31c2ac08a50addf7bcf9e1a740040b92879836bd
analyzer_version=1
~~~

The analyzer is read-only. It thins the local CoreGraphics binary to the required architecture, inventories the shape-family symbols, emits the full symbol windows and direct call/branch edges, records nearby Mach/MIG transport lines and candidate message IDs, and reports whether the outer _CGSShapeWindow path reaches the release-specific inner helper.

Expected release-specific inner helpers:

~~~text
Snow Leopard PPC7400: __CGSWindowShape
Lion i386:            __CGSCopyWindowShape
~~~

The historical live anchors are recorded as:

~~~text
legacy_live_request_id=0x0000724d
legacy_live_reply_id=0x000072b1
~~~

## Safety constraints

- Snow Leopard: exactly 10.6.8 / 10K549.
- Lion: exactly 10.7.5 / 11G63.
- Run the analyzer once on Snow and once on Lion.
- Do not launch the PPC Carbon subject.
- Do not rebuild the PPC subject, compatibility interposers, notification broker, observer, kernel, or Rosetta.
- Do not issue any CGS, CPS, WindowServer, display, bootstrap, or Mach request.
- Do not patch CGSGetDisplayBounds, CGSShapeWindow, _CGSLockWindow, display IDs, window geometry, CoreGraphics, WindowServer, Rosetta, dyld, caches, or XNU.
- Do not restart WindowServer, Dock, Finder, distnoted, launchd, or the machine.
- Keep all currently accepted runtime compatibility artifacts unchanged.

## Phase A — pull and pin current main

On both systems:

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-cgsshapewindow-protocol.py)" = \
  "31c2ac08a50addf7bcf9e1a740040b92879836bd" || exit 1
~~~

The XNU companion checkout may also be pulled to current main, but no XNU build or reboot is part of this phase.

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8 / 10K549:

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgsshapewindow-protocol.py \
  ./ppc-carbon-gui-cgsshapewindow-protocol-snowleopard.txt || exit 1
~~~

Require:

~~~text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
required_inner_shape_helper=__CGSWindowShape
outer_calls_required_inner=YES
RESULT: PASS
~~~

Do not run the PPC subject afterward.

## Phase C — Lion static audit

On Lion 10.7.5 / 11G63:

~~~sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgsshapewindow-protocol.py \
  ./ppc-carbon-gui-cgsshapewindow-protocol-lion.txt || exit 1
~~~

Require:

~~~text
product_version=10.7.5
build_version=11G63
required_arch=i386
required_inner_shape_helper=__CGSCopyWindowShape
outer_calls_required_inner=YES
RESULT: PASS
~~~

Do not run the PPC subject afterward.

## Phase D — return exactly two reports

Return:

~~~text
ppc-carbon-gui-cgsshapewindow-protocol-snowleopard.txt
ppc-carbon-gui-cgsshapewindow-protocol-lion.txt
~~~

No binary, crash report, core, or live trace is requested in this phase.

## What to compare

Review the two reports for:

- the exact _CGSShapeWindow outer call graph;
- Snow __CGSWindowShape versus Lion __CGSCopyWindowShape;
- request/reply message IDs;
- Mach message bits and options;
- send/receive sizes;
- NDR/scalar/region-data layout;
- reply validation and result decoding;
- whether Lion's replacement helper is an ID-only migration, a layout migration, or a semantic API change;
- the later __CGSSetWindowShape* / __CGSShapeWindow* helpers only as downstream context.

The live 0x724d / 0x72b1 failure must be explained by this first inner operation before any later shape setter is adapted.

## Decision gate

### Narrow transport differential

If Snow __CGSWindowShape and Lion __CGSCopyWindowShape are proven semantic counterparts with a narrow message-ID and/or fixed-layout change, prepare one exact compatibility experiment for only this first shape operation. Preserve all other accepted compatibility behavior, and keep the later shape setters held until the first adapted call returns successfully.

### Wire-compatible or state-dependent behavior

If the two helpers are wire-compatible, do not rewrite the message ID. Review the exact region/display arguments and the earlier CGSGetDisplayBounds (display 0) state instead.

### Semantic replacement without safe one-to-one mapping

If Lion replaced the Snow helper with a materially different API contract, stop. Do not emulate it from assumptions; prepare a narrower native control or passive trace to establish the missing semantics.

### Missing or ambiguous static attribution

Stop and refine the analyzer. Do not broaden the live interposer.

## Current boundary

~~~text
Snow manual Carbon window                     VISIBLE
Snow WindowServer geometry                    400x222 at (120,98), alpha 1, layer 0
Lion manual Carbon window                     NOT VISIBLE
Lion WindowServer geometry                    1x1 at (120,98), alpha 1, layer 0
Lion WindowServer target window               PRESENT + ONSCREEN
historical CPS registration                   PASS
historical exact-21 notifications             PASS
accepted CGS/titlebar stack                   PASS
live legacy 0x724d / 0x72b1                   -304 + CGSShapeWindow type-check failure
next step                                     static CGSShapeWindow inner-helper differential
new live CGS/display compatibility             NO
LaunchServices / Finder / Cocoa               HELD
XNU                                           no source change indicated
~~~


## Reviewed static result

Both analyzer-v1 reports pass with the required release and architecture slices. Snow's outer _CGSShapeWindow reaches __CGSWindowShape; Lion's outer _CGSShapeWindow reaches __CGSCopyWindowShape. The decisive generated-MIG result is farther down the set-shape path:

~~~text
Snow PPC  __CGSSetWindowShapeInline   0x724d / 0x72b1   bits 0x1513
Lion i386 __CGSSetWindowShapeInline   0x724e / 0x72b2   bits 0x1513
~~~

Both inline clients impose count <= 0x1000, use send size 0x2c + 4*count, receive size 0x2c, Mach option 0x3, and accept a 0x24 reply with equivalent NDR/result handling. The live historical request has count 9, so the observed send size 0x50 is exactly this inline contract.

Lion simultaneously assigns the old Snow inline IDs 0x724d / 0x72b1 to its different non-inline __CGSSetWindowShape client, whose request uses complex bits 0x80001513 and a fixed 0x3c send size. The live PPC request is therefore colliding with the wrong Lion server contract. That explains the -304 / MIG_BAD_ARGUMENTS and CGSShapeWindow type-check diagnostic without requiring a payload or display-ID hypothesis.

Current main advances to:

~~~text
docs/ppc-carbon-gui-cgsshapewindow-inline-compat-integration.md
~~~

That phase performs a Snow passthrough control and exactly one Lion ID-only conversion of the pinned count-9 historical request: 0x724d -> 0x724e and native reply 0x72b2 -> 0x72b1. The body, sizes, ports, NDR, region data, result, display state, and every later shape request remain unchanged.
