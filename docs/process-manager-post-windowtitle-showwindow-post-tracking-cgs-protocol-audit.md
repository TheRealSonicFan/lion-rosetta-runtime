# Process Manager ShowWindow post-tracking CGS protocol audit

## Objective

The exact `CGSAddTrackingAreaInline` compatibility rule succeeded on Lion, but `ShowWindow` still does not return. This stage is a static, read-only Snow-Leopard-versus-Lion CoreGraphics audit of the two remaining post-`S00` legacy CGS requests that still return `-304 / MIG_BAD_ARGUMENTS`.

The completed Lion integration proves the tracking-area conversion itself is no longer the failing transaction:

```text
legacy request                 0x7388
native Lion request            0x738e
request body                   unchanged
native reply                   0x73f2 / 0x24 / result 0
legacy-facing reply            0x73ec / 0x24 / result 0
adapter result                 PASS
```

After that successful conversion, the post-`S00` sequence is:

```text
0x72e7 -> 0x734b   send 0x34 / recv 0x2c   result -304
0x7388 -> 0x73ec   exact adapter            result 0
0x7268 -> 0x72cc   send 0x24 / recv 0x2c   result 0
0x72f2 -> 0x7356   send 0x24 / recv 0x2c   result -304
```

The repeated CoreGraphics diagnostics around this sequence remain:

```text
CGSColorProfileCreateWithColorProfileID: Cannot initialize color profile client
_CGSWindowColorProfile: Invalid color profile id = 0x1
Failed to create window context color transform
CGWindowContextCreate: failed to create context delegate.
```

The first diagnostic cluster appears before the first `0x72e7` request, so the transport IDs must be attributed statically before inferring whether either `-304` is causal, consequential, or unrelated to the color-profile/window-context failure.

A separate earlier `0x724d -> 0x72b1` request still returns `-304` on Lion and is followed by a `CGSShapeWindow` server type-check diagnostic, but that occurs before `CreateNewWindow` returns successfully. It is preserved as an unresolved earlier mismatch and is not adapted in this stage.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and reads only the system CoreGraphics binary. It selects the Snow Leopard `ppc7400` slice or Lion `i386` slice, records provenance, searches the exact observed legacy request/reply anchors, inventories generated-MIG candidates in a narrow ID neighborhood, and emits complete symbol windows for those candidates.

Observed anchors:

```text
first post-S00 failure     request 0x72e7   reply 0x734b
second post-S00 failure    request 0x72f2   reply 0x7356
```

The narrow candidate ranges are deliberately limited to nearby request/reply IDs so the report can expose a same-named Lion-native helper even when its routine number shifted by a small amount.

## Questions this audit must answer

For each observed legacy pair, determine:

- the enclosing Snow PPC generated-MIG/helper symbol;
- the same helper or closest exact semantic counterpart on Lion i386;
- Snow and Lion request/reply IDs;
- request header bits;
- Mach options;
- send and receive sizes;
- NDR placement;
- scalar field order and widths;
- descriptor or variable-data use, if any;
- accepted reply size and result decoding;
- whether Lion changed only the routine number, changed wire geometry, or has no wire-compatible counterpart.

Do not authorize an adapter merely because a neighboring ID differs by a small constant. The complete generated-MIG contract must agree.

## Safety constraints

- Do not launch the PPC ShowWindow subject.
- Do not rerun the tracking-area integration.
- Do not rebuild or load a compatibility dylib.
- Do not modify the exact-six notification broker.
- Do not adapt `0x72e7`, `0x72f2`, `0x724d`, color-profile, window-context, RawCamera, CoreUI, or rendering behavior in this stage.
- Do not add `SelectWindow`, visibility queries, timers, or an event loop.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- Do not restart or signal WindowServer or related jobs.
- Keep the new Lion crash report/plist/core from the preceding integration locally.
- No XNU rebuild or reboot.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

Confirm runtime contains:

```text
scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py
docs/process-manager-post-windowtitle-showwindow-post-tracking-cgs-protocol-audit.md
```

Before either audit, syntax-check the analyzer with the platform Python:

```sh
/usr/bin/python -c 'compile(open("./scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py", "rb").read(), "./scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py", "exec")'
```

The command must produce no output and exit 0.

## Phase B — Snow Leopard 10.6.8 static audit

Run:

```sh
/usr/bin/python ./scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py \
  ./process-manager-showwindow-post-tracking-cgs-protocol-snowleopard.txt
```

Require:

```text
analyzer_version=1
product_version=10.6.8
required_arch=ppc7400
first_post_s00_failure_request_id=0x000072e7
first_post_s00_failure_reply_id=0x0000734b
second_post_s00_failure_request_id=0x000072f2
second_post_s00_failure_reply_id=0x00007356
candidate_symbol_count >= 1
RESULT: PASS
```

The Snow validation additionally requires the exact legacy request and reply anchors to be present in the PPC slice. Stop and return only the Snow report if this audit fails.

## Phase C — Lion 10.7.5 static audit

Only after the Snow report passes, run:

```sh
/usr/bin/python ./scripts/audit-process-manager-showwindow-post-tracking-cgs-protocol.py \
  ./process-manager-showwindow-post-tracking-cgs-protocol-lion.txt
```

Require:

```text
analyzer_version=1
product_version=10.7.5
required_arch=i386
first_post_s00_failure_request_id=0x000072e7
first_post_s00_failure_reply_id=0x0000734b
second_post_s00_failure_request_id=0x000072f2
second_post_s00_failure_reply_id=0x00007356
candidate_symbol_count >= 1
RESULT: PASS
```

Do not launch translated PPC afterward.

## Phase D — return evidence and stop

Return exactly:

```text
process-manager-showwindow-post-tracking-cgs-protocol-snowleopard.txt
process-manager-showwindow-post-tracking-cgs-protocol-lion.txt
```

Keep the new Lion crash report, crash plist, and `/cores/core.64160` locally. They are not required for this static phase.

## Decision gate

### Narrow generated-MIG differential

If one observed legacy pair maps to the same helper on Snow and Lion and the reports prove a narrow, exact protocol differential, prepare only the first causally relevant compatibility experiment. Do not combine the two requests in one live adapter unless the static evidence establishes that they are inseparable parts of one generated protocol boundary.

### Wire-compatible contract

If a failing request is already wire-compatible with Lion's native helper, do not rewrite its ID. Treat its `-304` as argument/state semantics and review the wrapper inputs plus the preserved crash/core before changing transport behavior.

### Diagnostic order points earlier than the RPC

If the static mapping shows the `0x72e7` or `0x72f2` failures are downstream of an already-failed color-profile/window-context setup, do not patch them as symptoms. The next stage should instead audit the exact earlier color-profile initialization contract/state boundary.

### Missing or ambiguous mapping

Stop and refine the static model. Do not broaden the passive trace or add a speculative adapter.

## Current boundary

```text
syscall 295                                      -> PASS
Snow tracking-area compatibility control         -> PASS
Lion CGSAddTrackingArea exact adapter             -> PASS
tracking native result                            -> 0
ShowWindow Lion                                   -> S00 reached, S01 absent
post-S00 0x72e7 / 0x734b                         -> result -304
post-S00 0x7268 / 0x72cc                         -> result 0
post-S00 0x72f2 / 0x7356                         -> result -304
color-profile/window-context diagnostics          -> still present
Lion process                                      -> exit 139 + new crash/core
next step                                         -> static post-tracking CGS protocol attribution
live additional CGS adaptation                    -> not authorized
XNU                                               -> no change indicated
```
