# PPC Carbon GUI CGSGetNextEventRecord protocol audit

## Status

**V1 COMPLETE — PASS / V2 STATIC REFINEMENT PREPARED.** Both returned v1
reports are valid and materially narrow the failure. Snow PPC and Lion i386
retain the same generated-MIG request/reply IDs, `0x7292 / 0x72f6`, and the
same `0x1513` request bits, but their native wire geometry is not equivalent:
Snow sends `0x18` and receives up to `0x4030`, while Lion's native client
sends `0x24` and receives up to `0x0c30`. An ID-only compatibility rewrite
is therefore ruled out.

The v1 analyzer did not complete the original field-level objective because the
public `CGSGetNextEventRecord*` functions contain no Mach transport; they call
down into `_snarfEvents`, while the request/reply anchors were emitted only as
global disassembly context. V2 now resolves `_snarfEvents`, identifies the
single containing generated-MIG symbol that carries both IDs and Mach
transport, emits that complete symbol window and caller references, and gates
the release-specific native send/receive geometry. The next step remains
static-only: rerun this audit on Snow and Lion with v2 before designing any
adapter.

The Snow v2 input control is healthy and authoritative:

```text
dispatcher handler install                       PASS
diagnostic quit timer 2 s -> 8 s                PASS
mouse-down public FindWindow result             inDrag (4)
independent WindowServer movement               YES
routing_state                                   SNOW_PUBLIC_HIT_IN_DRAG_MOVED
RESULT                                           PASS
```

The corresponding Lion run does not reach the public Carbon dispatcher
handler at all. The v2 monitor itself loads and installs successfully, and the
diagnostic timer is extended successfully, but no
`PM_HITOOLBOX_TITLEBAR_INPUT_EVENT` record appears.

Instead, the first event-retrieval transaction fails at a lower boundary:

```text
legacy request ID                               0x00007292
legacy reply ID                                 0x000072f6
request bits                                    0x00001513
send size                                       0x18
receive capacity                                0x4030
Mach transport return                           0
Lion simple reply size                          0x24
raw reply error word                            0xd0feffff
PPC/NDR-swapped error                           0xfffffed0 / -304
diagnostic                                      MIG: server type check failure:
                                                CGSGetNextEventRecord (Inline)
```

The same Snow request succeeds and returns a variable event-record reply
instead of the simple error reply. In the accepted Snow drag run, the exact
`0x7292 / 0x72f6` transaction returns large event data before the dispatcher
monitor reports `inDrag`, and subsequent calls return event-sized records as
the window is dragged.

This is materially narrower than the earlier interaction hypotheses. The
visible beach-ball symptom and missing dispatcher events are consistent with
Snow PPC CoreGraphics failing to retrieve the next WindowServer event on Lion.
The current evidence proves a generated-MIG protocol incompatibility at
`CGSGetNextEventRecord (Inline)`; it does **not** yet prove that the correct
fix is an ID-only rewrite.

## Objective

Compare the shipped client-side generated-MIG contracts for
`CGSGetNextEventRecord` in:

```text
Snow Leopard 10.6.8 / 10K549 / CoreGraphics ppc7400
Lion 10.7.5 / 11G63 / CoreGraphics i386
```

The audit must establish, from read-only shipped binaries:

- the exact target symbol family on each release;
- request/reply IDs selected by each client;
- request message construction and any request payload fields;
- send and receive sizes;
- expected reply sizes / variable-data handling;
- NDR and MIG reply validation;
- direct helper/caller structure around the generated transport.

Do not infer an adapter until those two native contracts are compared.


## Reviewed v1 result

Both v1 reports pass their integrity gates. The decisive differential is:

```text
Snow PPC  request/reply  0x7292 / 0x72f6  bits 0x1513  send 0x18  recv 0x4030
Lion i386 request/reply  0x7292 / 0x72f6  bits 0x1513  send 0x24  recv 0x0c30
```

The Snow request is therefore a Mach-header-only `0x18` request at this
boundary, while Lion's native request is 12 bytes larger. The v1 Lion anchor
context also shows stores into that extra request region before `mach_msg`,
but v1 does not safely identify those fields or their semantics. Likewise, the
receive-capacity change from `0x4030` to `0x0c30` must be correlated with
the native reply-validation and event-record extraction path before a
compatibility policy is specified.

The unchanged request/reply IDs make the earlier ID-migration branch of the
review gate inapplicable. This is a layout/contract migration until v2 proves
the exact field mapping.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py
Git blob 90412347f0cc187627a05912897b953b18541812
```

Contract:

```text
analyzer_version=2
audit_contract=carbon-gui-cgs-get-next-event-record-protocol-v2
```

The analyzer is Python-2-compatible, thins only the required CoreGraphics
architecture to a temporary directory, inventories the
`CGSGetNextEventRecord` symbol family, emits full target-symbol
disassemblies, direct branch/call lines, MIG transport lines, relevant
protocol immediates, and contexts for the live Snow `0x7292 / 0x72f6`
anchors. V2 additionally resolves the release-local `_snarfEvents` symbol,
groups disassembly by containing text symbol, requires exactly one
generated-MIG transport candidate containing both legacy IDs plus Mach
transport, emits that entire candidate and its caller references, and verifies
the native Snow `0x18/0x4030` versus Lion `0x24/0x0c30` geometry.
The request-bits immediate is reported but is not a hard static gate because
Snow may load the header bits through a release-local template rather than an
inline `0x1513` immediate in the transport symbol.

Phase A performs an explicit syntax compile on each host before the audit.

## Safety constraints

- Static-only on Snow and Lion.
- Do not launch the PPC Carbon GUI subject.
- Do not click or drag a window for this step.
- Do not interpose `mach_msg`, `CGSGetNextEventRecord`, HIToolbox, or
  WindowServer.
- Do not change the exact-five CoreUI mapping, exact-two corner
  `bitmapInfo=0x2002` rule, or exact-six traffic-light rule.
- Do not change classic part codes or hit masks.
- Do not change the exact-21 notification broker.
- Do not add or broaden any CGS compatibility rule.
- Do not modify CoreGraphics, HIToolbox, Rosetta caches, WindowServer, or XNU.

## Phase A — update and pin

On both Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py)" = \
  "90412347f0cc187627a05912897b953b18541812" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "2" \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-cgs-get-next-event-record-protocol-v2" \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py","rb").read(),"cgs-next-event.py","exec")' || exit 1
```

## Phase B — Snow static report

On Snow Leopard 10.6.8 / 10K549:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt || exit 1
```

Require:

```text
analyzer_version=2
audit_contract=carbon-gui-cgs-get-next-event-record-protocol-v2
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
live_legacy_request_id=0x00007292
live_legacy_reply_id=0x000072f6
live_send_size=0x18
live_recv_size=0x4030
target_symbol_count >= 1
snarf_events_symbol_count=1
legacy_transport_candidate_count=1
native_expected_request_id=0x00007292
native_expected_reply_id=0x000072f6
native_expected_request_bits=0x00001513
native_expected_send_size=0x18
native_expected_recv_size=0x4030
native_event_transport_candidate_exact_geometry=YES
legacy_request_anchor ... instruction_hits >= 1
legacy_reply_anchor ... instruction_hits >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

## Phase C — Lion static report

On Lion 10.7.5 / 11G63:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt || exit 1
```

Require:

```text
analyzer_version=2
audit_contract=carbon-gui-cgs-get-next-event-record-protocol-v2
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
live_lion_error_signed=-304
target_symbol_count >= 1
snarf_events_symbol_count=1
legacy_transport_candidate_count=1
native_expected_request_id=0x00007292
native_expected_reply_id=0x000072f6
native_expected_request_bits=0x00001513
native_expected_send_size=0x24
native_expected_recv_size=0xc30
native_event_transport_candidate_exact_geometry=YES
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

Lion is **not** required to contain the Snow `0x7292 / 0x72f6` immediate
anchors. Their absence may be the relevant protocol difference.

## Review gate

### Current v1 result: IDs match, request/reply geometry changes

Do not rewrite the IDs. V2 must map every changed request field, size,
descriptor/NDR rule, receive-buffer convention, and reply-validation branch in
the exact generated-MIG transport before a standalone adapter is designed.

### V2 resolves a narrow one-to-one layout migration

Only then prepare a standalone copied-request / copied-reply proof for the
minimal field-level conversion. Do not patch the integrated PPC stack first.

### V2 shows semantic replacement or ambiguous attribution

Stop and refine the static audit or prepare a narrower native control. Do not
emulate missing semantics from assumptions.

### Native Lion no longer has the same generated-MIG helper

Audit the native Lion event-retrieval caller chain and transport selected in its
place. Do not revive the Snow RPC speculatively.

### Snow and Lion client contracts appear identical

Do not rewrite IDs. The next boundary is WindowServer connection/event-port
state or another prerequisite to event retrieval.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt
ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt
```

## Current boundary

```text
window-frame rendering                           RESTORED
Snow v2 titlebar input control                   PASS
Snow public hit classification                   inDrag (4)
Snow observer movement                           YES
Lion dispatcher handler install                  PASS
Lion dispatcher mouse events                     NONE
Lion observer movement                           NO
Lion event retrieval                             CGSGetNextEventRecord type-check failure
legacy event request/reply                       0x7292 / 0x72f6
Lion legacy reply                                simple 0x24 / -304 after PPC swap
part-code rewrite                                NOT AUTHORIZED
notification policy                              unchanged
CGS event compatibility                          NONE YET
v1 native IDs/bits                               SAME: 0x7292 / 0x72f6 / 0x1513
v1 Snow native geometry                          send 0x18 / recv 0x4030
v1 Lion native geometry                          send 0x24 / recv 0x0c30
ID-only rewrite                                  RULED OUT
next step                                        rerun v2 static _snarfEvents/generated-MIG resolution audit
XNU                                              no source change indicated
```
 \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-cgs-get-next-event-record-protocol-v1"$' \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py","rb").read(),"cgs-next-event.py","exec")' || exit 1
```

## Phase B — Snow static report

On Snow Leopard 10.6.8 / 10K549:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt || exit 1
```

Require:

```text
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
live_legacy_request_id=0x00007292
live_legacy_reply_id=0x000072f6
live_send_size=0x18
live_recv_size=0x4030
target_symbol_count >= 1
legacy_request_anchor ... instruction_hits >= 1
legacy_reply_anchor ... instruction_hits >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

## Phase C — Lion static report

On Lion 10.7.5 / 11G63:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt || exit 1
```

Require:

```text
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
live_lion_error_signed=-304
target_symbol_count >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

Lion is **not** required to contain the Snow `0x7292 / 0x72f6` immediate
anchors. Their absence may be the relevant protocol difference.

## Review gate

### Native Lion uses a different request/reply ID with otherwise equivalent layout

Do not patch the integrated stack immediately. First prepare a standalone
copied-request / copied-reply compatibility proof that changes only the exact
generated-MIG IDs and validates the native Lion reply against the Snow PPC
decoder contract.

### Native Lion changes request or reply structure

Map every changed field, size, descriptor, and NDR rule before a standalone
adapter is designed. Do not treat this as an ID-only conversion.

### Native Lion no longer has the same generated-MIG helper

Audit the native Lion event-retrieval caller chain and transport selected in its
place. Do not revive the Snow RPC speculatively.

### Snow and Lion client contracts appear identical

Do not rewrite IDs. The next boundary is WindowServer connection/event-port
state or another prerequisite to event retrieval.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt
ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt
```

## Current boundary

```text
window-frame rendering                           RESTORED
Snow v2 titlebar input control                   PASS
Snow public hit classification                   inDrag (4)
Snow observer movement                           YES
Lion dispatcher handler install                  PASS
Lion dispatcher mouse events                     NONE
Lion observer movement                           NO
Lion event retrieval                             CGSGetNextEventRecord type-check failure
legacy event request/reply                       0x7292 / 0x72f6
Lion legacy reply                                simple 0x24 / -304 after PPC swap
part-code rewrite                                NOT AUTHORIZED
notification policy                              unchanged
CGS event compatibility                          NONE YET
next step                                        Snow/Lion static CGSGetNextEventRecord protocol audit
XNU                                              no source change indicated
```
 \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py","rb").read(),"cgs-next-event.py","exec")' || exit 1
```

## Phase B — Snow static report

On Snow Leopard 10.6.8 / 10K549:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt || exit 1
```

Require:

```text
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
live_legacy_request_id=0x00007292
live_legacy_reply_id=0x000072f6
live_send_size=0x18
live_recv_size=0x4030
target_symbol_count >= 1
legacy_request_anchor ... instruction_hits >= 1
legacy_reply_anchor ... instruction_hits >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

## Phase C — Lion static report

On Lion 10.7.5 / 11G63:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt || exit 1
```

Require:

```text
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
live_lion_error_signed=-304
target_symbol_count >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

Lion is **not** required to contain the Snow `0x7292 / 0x72f6` immediate
anchors. Their absence may be the relevant protocol difference.

## Review gate

### Native Lion uses a different request/reply ID with otherwise equivalent layout

Do not patch the integrated stack immediately. First prepare a standalone
copied-request / copied-reply compatibility proof that changes only the exact
generated-MIG IDs and validates the native Lion reply against the Snow PPC
decoder contract.

### Native Lion changes request or reply structure

Map every changed field, size, descriptor, and NDR rule before a standalone
adapter is designed. Do not treat this as an ID-only conversion.

### Native Lion no longer has the same generated-MIG helper

Audit the native Lion event-retrieval caller chain and transport selected in its
place. Do not revive the Snow RPC speculatively.

### Snow and Lion client contracts appear identical

Do not rewrite IDs. The next boundary is WindowServer connection/event-port
state or another prerequisite to event retrieval.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt
ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt
```

## Current boundary

```text
window-frame rendering                           RESTORED
Snow v2 titlebar input control                   PASS
Snow public hit classification                   inDrag (4)
Snow observer movement                           YES
Lion dispatcher handler install                  PASS
Lion dispatcher mouse events                     NONE
Lion observer movement                           NO
Lion event retrieval                             CGSGetNextEventRecord type-check failure
legacy event request/reply                       0x7292 / 0x72f6
Lion legacy reply                                simple 0x24 / -304 after PPC swap
part-code rewrite                                NOT AUTHORIZED
notification policy                              unchanged
CGS event compatibility                          NONE YET
next step                                        Snow/Lion static CGSGetNextEventRecord protocol audit
XNU                                              no source change indicated
```
 \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-cgs-get-next-event-record-protocol-v1"$' \
  ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py","rb").read(),"cgs-next-event.py","exec")' || exit 1
```

## Phase B — Snow static report

On Snow Leopard 10.6.8 / 10K549:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt || exit 1
```

Require:

```text
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
live_legacy_request_id=0x00007292
live_legacy_reply_id=0x000072f6
live_send_size=0x18
live_recv_size=0x4030
target_symbol_count >= 1
legacy_request_anchor ... instruction_hits >= 1
legacy_reply_anchor ... instruction_hits >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

## Phase C — Lion static report

On Lion 10.7.5 / 11G63:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py \
  ./ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt || exit 1
```

Require:

```text
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
live_lion_error_signed=-304
target_symbol_count >= 1
cgs_get_next_event_record_protocol_audit_exact=YES
RESULT: PASS
```

Lion is **not** required to contain the Snow `0x7292 / 0x72f6` immediate
anchors. Their absence may be the relevant protocol difference.

## Review gate

### Native Lion uses a different request/reply ID with otherwise equivalent layout

Do not patch the integrated stack immediately. First prepare a standalone
copied-request / copied-reply compatibility proof that changes only the exact
generated-MIG IDs and validates the native Lion reply against the Snow PPC
decoder contract.

### Native Lion changes request or reply structure

Map every changed field, size, descriptor, and NDR rule before a standalone
adapter is designed. Do not treat this as an ID-only conversion.

### Native Lion no longer has the same generated-MIG helper

Audit the native Lion event-retrieval caller chain and transport selected in its
place. Do not revive the Snow RPC speculatively.

### Snow and Lion client contracts appear identical

Do not rewrite IDs. The next boundary is WindowServer connection/event-port
state or another prerequisite to event retrieval.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-cgs-get-next-event-record-protocol-snow.txt
ppc-carbon-gui-cgs-get-next-event-record-protocol-lion.txt
```

## Current boundary

```text
window-frame rendering                           RESTORED
Snow v2 titlebar input control                   PASS
Snow public hit classification                   inDrag (4)
Snow observer movement                           YES
Lion dispatcher handler install                  PASS
Lion dispatcher mouse events                     NONE
Lion observer movement                           NO
Lion event retrieval                             CGSGetNextEventRecord type-check failure
legacy event request/reply                       0x7292 / 0x72f6
Lion legacy reply                                simple 0x24 / -304 after PPC swap
part-code rewrite                                NOT AUTHORIZED
notification policy                              unchanged
CGS event compatibility                          NONE YET
next step                                        Snow/Lion static CGSGetNextEventRecord protocol audit
XNU                                              no source change indicated
```
