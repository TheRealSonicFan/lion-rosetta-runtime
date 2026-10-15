# PPC Carbon GUI CGSGetNextEventRecord protocol audit

## Status

NEXT CONTROLLED STATIC STEP after the Lion titlebar-input run exposed the first
direct event-transport failure.

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

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-cgs-get-next-event-record-protocol.py
Git blob 66dad572fc9a8a42a338e00998af488c2587d6ea
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-cgs-get-next-event-record-protocol-v1
```

The analyzer is Python-2-compatible, thins only the required CoreGraphics
architecture to a temporary directory, inventories the
`CGSGetNextEventRecord` symbol family, emits full target-symbol
disassemblies, direct branch/call lines, MIG transport lines, relevant
protocol immediates, and contexts for the live Snow `0x7292 / 0x72f6`
anchors.

The analyzer source was syntax-checked before commit.

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
  "66dad572fc9a8a42a338e00998af488c2587d6ea" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
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
