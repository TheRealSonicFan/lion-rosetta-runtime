# PPC Carbon GUI CGSGetNextEventRecord protocol audit

## Status

**COMPLETE — PROTOCOL DIFFERENTIAL RESOLVED.**

The returned analyzer-v2 Snow and Lion reports are internally valid, but they
also expose a flaw in the v2 attribution rule. On Snow, `_snarfEvents`
directly calls `__CGSGetPortStreamInline`, and the v2 legacy-ID search
correctly lands on that same helper. On Lion, `_snarfEvents` also directly
calls `__CGSGetPortStreamInline`, but the legacy-ID search instead lands on
`__CGSGetDisplayPalette`. The v2 Lion line
`native_event_transport_candidate_exact_geometry=YES` therefore describes
the Lion routine that now owns Snow's old IDs; it is not the native Lion
next-event helper.

The earlier accepted post-ShowWindow static reports in the investigation
contain complete `__CGSGetPortStreamInline` windows from the exact same
CoreGraphics binaries now returned by v2:

```text
Snow CoreGraphics SHA-256
2e2fa8b25aff0fd85565d67c585dd368e79eee5d12716eac2b1c3511a1aadd18

Lion CoreGraphics SHA-256
fff91efa5392c007ef4bde715666cc738b69f652f565abfce056ba07273aa192
```

Correlating those same-binary reports resolves the native contract:

```text
Snow PPC  __CGSGetPortStreamInline
  request / reply       0x7292 / 0x72f6
  bits                  0x1513
  mach option           0x3
  send / receive        0x18 / 0x4030

Lion i386 __CGSGetPortStreamInline
  request / reply       0x7295 / 0x72f9
  bits                  0x1513
  mach option           0x3
  send / receive        0x18 / 0x4030

Lion i386 __CGSGetDisplayPalette
  request / reply       0x7292 / 0x72f6
  send / receive        0x24 / 0x0c30
```

Both native event-stream helpers use the same header-only request geometry,
the same receive capacity, and equivalent variable stream/simple-error reply
validation. Lion moved the event-stream pair by exactly +3 and reused Snow's
old pair for the structurally different display-palette RPC. This explains the
live failure exactly: translated Snow CoreGraphics sends a valid event-stream
`0x7292` request of size `0x18`; Lion dispatches ID `0x7292` as
`__CGSGetDisplayPalette`, which requires a `0x24` request, and WindowServer
returns the observed -304 server type-check error.

The correct compatibility hypothesis is therefore **ID-only**:

```text
request ID       0x7292 -> 0x7295
native reply ID  0x72f9 -> 0x72f6
all other bytes  unchanged
send size        0x18 unchanged
receive size     0x4030 unchanged
ports/bits       unchanged
stream payload   unchanged
NDR/data length  unchanged
```

No request-layout synthesis, part-code translation, HIToolbox patch, or XNU
change is justified.

## Analyzer correction

Current runtime `main` carries analyzer v3:

```text
scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py
Git blob daa2cae1556a45e6ea7dd3c75e4f329d3bba6cfd
analyzer_version=3
audit_contract=carbon-gui-cgs-get-next-event-record-protocol-v3
```

V3 no longer chooses a Lion event transport merely because it contains the
Snow IDs. It resolves the exact `_snarfEvents -> __CGSGetPortStreamInline`
edge, validates the release-native ID pair and common `0x18/0x4030`
geometry, and separately inventories the Lion legacy-ID collision owner.

A v3 rerun is not required before the next experiment because the complete
native helper windows are already preserved in the Library from the same
CoreGraphics SHA-256 binaries. Rerun v3 only if either system binary provenance
changes or a future audit needs a self-contained regenerated report.

## Superseded v2 interpretation

Do not use this v2 Lion conclusion:

```text
native event transport = __CGSGetDisplayPalette
native send / receive  = 0x24 / 0x0c30
ID-only rewrite        = ruled out
```

That was an analyzer-attribution error. The v2 report itself proves the
contradiction because its emitted `_snarfEvents` body calls
`__CGSGetPortStreamInline`, while its selected "transport candidate" is
`__CGSGetDisplayPalette`.

## Safety boundary

The static audit is closed. Preserve:

- the exact historical Carbon GUI subject;
- all accepted CPS, notification, CGS, CoreUI and HIToolbox compatibility;
- the exact-five shared-art mapping and exact-two corner-format rule;
- the exact-six traffic-light rule;
- public `FindWindow` observation semantics;
- all system binaries, Rosetta caches, WindowServer and XNU.

Do not patch CoreGraphics or HIToolbox. Do not alter event-record bytes, stream
lengths, NDR, Mach ports, Mach bits, send/receive sizes, or any request other
than the exact legacy inline event-stream ID.

## Next controlled step

Follow:

```text
docs/ppc-carbon-gui-cgs-get-next-event-inline-compat-integration.md
```

That stage builds one new full-stack PPC compatibility artifact on Snow,
requires a Snow passthrough + drag positive control, then performs exactly one
Lion run with the exact request/reply ID conversion above while retaining the
v2 public dispatcher monitor. The decisive Lion gate is not merely "Mach call
succeeded": the old `CGSGetNextEventRecord (Inline)` type-check diagnostic
must disappear, at least one native `0x72f9` stream reply must be translated
back to `0x72f6`, and the public dispatcher must receive the manual titlebar
mouse-down. Window movement is recorded as the downstream discriminator.

## Current boundary

```text
window-frame rendering                           RESTORED
Snow titlebar input control                      PASS / inDrag / moves
Lion dispatcher mouse events                     NONE before adapter
live Snow event request/reply                    0x7292 / 0x72f6
Snow native inline helper                        0x7292 / 0x72f6, 0x18 / 0x4030
Lion native inline helper                        0x7295 / 0x72f9, 0x18 / 0x4030
Lion owner of old Snow IDs                       __CGSGetDisplayPalette
Lion old-ID owner geometry                       0x24 / 0x0c30
failure mechanism                                exact generated-MIG ID collision
next compatibility                               ID-only 0x7292->0x7295 / 0x72f9->0x72f6
part-code rewrite                                NOT AUTHORIZED
notification policy                              unchanged
XNU                                              no source change indicated
next step                                        exact next-event inline compatibility integration
```
