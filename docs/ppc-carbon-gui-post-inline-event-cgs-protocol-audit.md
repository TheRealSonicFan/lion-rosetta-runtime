# PPC Carbon GUI post-inline event CGS protocol audit

## Status

**AUDIT PASSED / GETWINDOWSHAPE ID COLLISION RESOLVED.**

Both returned reports pass their integrity and validation gates against the
accepted CoreGraphics binaries. The current reports plus the earlier complete
static reports from the same SHA-256 binaries resolve the four live anchors:

```text
family                              Snow PPC                     Lion i386
__CGSGetWindowShape                 724e/72b2  send24 recv3c     724f/72b3  send24 recv3c
legacy 724e/72b2 owner on Lion      --                           __CGSSetWindowShapeInline
__CGSGetSharedWindow                7258/72bc  recv38 success30  7259/72bd  recv3c success34
legacy 7258/72bc owner on Lion      --                           __CGSGetSharedWindowState
__CGSGetPortStreamOutofline         7293/72f7  send18 recv3c     7296/72fa  send18 recv3c
legacy 7293/72f7 owner on Lion      --                           __CGSCompleteDisplayConfiguration
__CGSGetSystemWindow                721f/7283                    721f/7283
```

This closes the immediate `CGSGetWindowBounds` question: both public
implementations call `__CGSGetWindowShape`, its wire geometry is unchanged,
and Lion moved its IDs by one while reusing Snow's old IDs for the set-shape
inline RPC. An exact ID-only GetWindowShape adapter is therefore authorized.

The SharedWindow family is deliberately **not** authorized for ID-only
adaptation because its receive capacity and complex success reply both grew on
Lion. The out-of-line event helper is an ID-only candidate, but it occurs
farther downstream and is deferred so that only one newly resolved boundary is
changed per live experiment. The unchanged `0x721f/0x7283` pair belongs to
`__CGSGetSystemWindow`; it does not justify a `CGSGetDisplayBounds`
adapter.

The authoritative next procedure is
`docs/ppc-carbon-gui-cgs-get-window-shape-compat-integration.md`.

## Question

Resolve the Snow Leopard PPC and Lion i386 native owners and exact
generated-MIG contracts for the post-inline-event failures before any new live
adapter is written:

1. Which native helper owns the Snow and Lion `0x724e / 0x72b2` family, and
   what request/reply geometry does `CGSGetWindowBounds` actually use on each
   release?
2. Which native helper owns `0x7258 / 0x72bc` on each release, and why does
   Lion return a shorter reply that the Snow PPC `_CGSFindSharedWindow`
   client rejects?
3. What are the Snow and Lion native IDs and message geometry for
   `__CGSGetPortStreamOutofline` /
   `CGSGetNextEventRecord (Outofline)`?
4. Does the `0x721f / 0x7283` family actually participate in
   `CGSGetDisplayBounds`, or is that diagnostic only a downstream
   consequence?

The answer must come from the release-local CoreGraphics binaries, not from
assuming that a legacy ID retains the same meaning on Lion.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-post-inline-event-cgs-protocol.py
```

Analyzer contract:

```text
analyzer_version=1
audit_contract=carbon-gui-post-inline-event-cgs-protocol-v1
```

The analyzer is Python-2-compatible and read-only. It selects the Snow
`ppc7400` or Lion `i386` CoreGraphics slice, records SHA-256 provenance,
emits focused symbols and diagnostic strings, preserves full disassembly
windows for the target helpers, enumerates generated-MIG protocol immediates,
shows the four live anchor families in disassembly context, and emits caller
references. It does not launch the PPC subject or issue any CGS, WindowServer,
event, bootstrap, or Mach request.

## Safety constraints

- Do not rerun the PPC Carbon GUI subject for this step.
- Do not add an adapter for `0x724e`, `0x7258`, `0x7293`, or `0x721f`
  before both static reports are compared.
- Do not broaden the already accepted inline next-event predicate.
- Do not rewrite event payload bytes, NDR data, message sizes, hit parts, or
  Carbon event semantics.
- Do not patch private HIToolbox.
- Do not alter the exact-21 notification policy or any accepted rendering,
  ShapeWindow, backing-sync, titlebar, or image rule.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
- Snow Leopard and Lion remain offline legacy execution targets. Verify and
  transfer the current repository tree on a modern TLS-capable staging system;
  do not require Git commands on either legacy system.

## Snow Leopard static audit

On Snow Leopard 10.6.8 / 10K549, from the transferred current runtime tree:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-post-inline-event-cgs-protocol.py \
  ./ppc-carbon-gui-post-inline-event-cgs-protocol-snow.txt
```

Require:

```text
mode=snow
product_version=10.6.8
build_version=10K549
post_inline_event_cgs_protocol_audit_exact=YES
RESULT: PASS
```

Do not launch the PPC subject before or after this audit.

## Lion static audit

On Lion 10.7.5 / 11G63, from the separately verified/transferred current
runtime tree:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-post-inline-event-cgs-protocol.py \
  ./ppc-carbon-gui-post-inline-event-cgs-protocol-lion.txt
```

Require:

```text
mode=lion
product_version=10.7.5
build_version=11G63
post_inline_event_cgs_protocol_audit_exact=YES
RESULT: PASS
```

## Return evidence

Return only:

```text
ppc-carbon-gui-post-inline-event-cgs-protocol-snow.txt
ppc-carbon-gui-post-inline-event-cgs-protocol-lion.txt
```

If either audit reports `RESULT: FAIL`, return that report unchanged rather
than attempting a live compatibility experiment.

## Current boundary

```text
Snow/Lion post-inline static audit                 PASS / PASS
inline next-event adapter                          proven
CGSGetWindowBounds lower helper                    __CGSGetWindowShape
Snow GetWindowShape                                0x724e / 0x72b2, 0x24 / 0x3c
Lion GetWindowShape                                0x724f / 0x72b3, 0x24 / 0x3c
Lion old-ID collision                              __CGSSetWindowShapeInline
next action                                        exact GetWindowShape ID-only integration
SharedWindow                                       changed reply geometry; deferred
out-of-line event helper                           clean ID-only candidate; deferred
0x721f / 0x7283                                    unchanged GetSystemWindow
private HIToolbox patch                            not authorized
XNU                                                unchanged
```
