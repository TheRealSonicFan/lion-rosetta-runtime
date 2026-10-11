# Process Manager CreateNewWindow CGS NewWindow protocol audit

## Objective

Localize the first remaining CreateNewWindow boundary after the exact Dock bootstrap compatibility path succeeds in the restored Lion stack.

The completed Dock-aware integration establishes:

```text
Snow full CreateNewWindow control                         PASS
Lion session/bootstrap compatibility                     PASS
Lion CGS server-version / connection compatibility       PASS
Lion CPS registration / SetFrontProcess compatibility    PASS
four reviewed distributed-notification registrations     PASS
exact Snow HIToolbox Extras.rsrc fallback                PASS
com.apple.dock.server Lion-format lookup                 PASS, valid send right
CreateNewWindow                                          returns -304
immediate diagnostic                                     MIG: server type check failure: CGSNewWindowWithOpaqueShape
```

The Dock lookup is therefore no longer the active boundary. The next question is whether Snow Leopard PPC CoreGraphics and Lion native CoreGraphics use different MIG request/reply contracts for the window-creation helper reached by `CGSNewWindowWithOpaqueShape`.

This stage is deliberately static and read-only. It establishes the client ABI before any new live `mach_msg` trace or compatibility adapter is designed.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-cgs-newwindow-protocol.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and inspects the system CoreGraphics binary without launching a PowerPC process. It examines these symbol families in every available i386, x86_64, and ppc7400 slice:

```text
CGSNewWindowWithOpaqueShape
CGSCreateWindowInline
CGSNewWindow
```

For every matching text symbol it records:

- complete function disassembly through the next text symbol;
- direct calls and branches;
- immediate-bearing instructions;
- references to the symbol/address;
- focused symbols/imports around NewWindow/CreateWindow, `mach_msg`, MIG reply-port helpers, NDR, region/shape/tag handling, and WindowServer;
- focused strings and addressed cstrings;
- full-file and thin-slice SHA-256 provenance.

Validation requires the `CGSNewWindowWithOpaqueShape` and `CGSCreateWindowInline` families in the Snow Leopard ppc7400 slice and the Lion i386 slice. Underscore spelling is intentionally not hard-coded.

## Questions this audit must answer

### 1. What exact Snow PPC transaction creates the window?

From the complete Snow PPC wrapper/helper bodies, identify:

- the helper call chain from `CGSNewWindowWithOpaqueShape` into the generated/private transport helper;
- request and expected reply IDs;
- request header bits and Mach options;
- send and receive sizes;
- descriptor count/types and port dispositions, if any;
- NDR placement;
- scalar field order and widths;
- region/shape/tag or variable payload representation;
- return-code extraction and any local validation.

### 2. What exact Lion native transaction replaced it?

Decode the same properties from Lion i386 CoreGraphics. Determine whether the routine ID family, fixed layout, variable payload, descriptor use, or reply shape changed.

### 3. Does the observed Lion `-304` fit a generated-MIG ABI mismatch?

The live error text alone does not authorize a rewrite. Compare the static contracts first. A difference in request ID, size, descriptor shape, field placement, or variable-data encoding would justify a later passive transport trace. Wire-compatible clients would instead move the investigation to argument/state semantics.

## Safety constraints

For this stage:

- do not run the PPC CreateNewWindow subject;
- do not rerun the Dock integration;
- do not modify or rebuild the accepted compatibility dylibs or native notification broker;
- do not add a NewWindow request adapter;
- do not broaden the existing `mach_msg` trace to unknown traffic yet;
- do not fabricate a window, Mach right, region, tag, or reply;
- do not patch CoreGraphics, WindowServer, HIToolbox, Rosetta, dyld, launchd, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection.

No XNU rebuild or reboot is part of this stage.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU documentation checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-newwindow-protocol.py \
  ./process-manager-cgs-newwindow-protocol-snowleopard.txt
```

Require:

```text
analyzer_version=1
product_version=10.6.8
CGSNewWindowWithOpaqueShape count >= 1 in ppc7400
CGSCreateWindowInline count >= 1 in ppc7400
RESULT: PASS
```

If Phase B fails, stop and return the Snow report. Do not run Lion.

## Phase C — Lion static audit

Only after Phase B passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-newwindow-protocol.py \
  ./payload/process-manager-cgs-newwindow-protocol-lion.txt
```

Require:

```text
analyzer_version=1
product_version=10.7.5
CGSNewWindowWithOpaqueShape count >= 1 in i386
CGSCreateWindowInline count >= 1 in i386
RESULT: PASS
```

Do not run translated PPC after the audit.

## Phase D — return evidence and stop

Return only:

```text
process-manager-cgs-newwindow-protocol-snowleopard.txt
process-manager-cgs-newwindow-protocol-lion.txt
```

Stop after returning those reports.

## Decision gate

### Snow and Lion NewWindow contracts differ

Localize the exact request/reply delta from the reports. The next stage will be a passive, exact transport trace of the unchanged Snow PPC request on Snow and then Lion. Do not write the adapter in the same stage.

### Contracts are wire-compatible

Treat the `CGSNewWindowWithOpaqueShape` type-check failure as an argument/state-semantics problem. Audit the wrapper inputs and server-side expectation before changing transport behavior.

### Required helper family is missing

Treat this as an analyzer/modeling issue. Preserve the report and stop; do not substitute a broad live Mach trace.

## Current boundary

```text
PPC execution / Rosetta                                      -> PASS
syscall 295                                                  -> PASS
CoreServices / Security / CGS pre-window compatibility       -> PASS
four reviewed distributed-notification registrations         -> PASS
exact Snow HIToolbox Extras.rsrc fallback                    -> PASS
integrated com.apple.dock.server adaptation                  -> PASS, valid send right
CreateNewWindow                                              -> returns -304
CGSNewWindowWithOpaqueShape                                  -> MIG server type-check failure
next step                                                    -> static Snow-PPC vs Lion-i386 NewWindow protocol differential
```

No additional XNU change is indicated.

## Observed completed result — inline NewWindow routine IDs evolved

Both returned analyzer-v1 reports pass, and the required Snow PPC and Lion i386 helper families are present.

The generated inline transport differs narrowly and materially:

```text
Snow PPC __CGSCreateWindowInline
  request / reply        0x7394 / 0x73f8
  bits                   0x1513
  mach_msg option        0x3
  receive size           0x40
  send size              0x38 + 4*countA + 4*countB
  accepted reply sizes   0x38 / 0x24

Lion i386 __CGSCreateWindowInline
  request / reply        0x739a / 0x73fe
  bits                   0x1513
  mach_msg option        0x3
  receive size           0x40
  send size              0x38 + 4*countA + 4*countB
  accepted reply sizes   0x38 / 0x24
```

The visible generated request construction and NDR-aware reply handling remain structurally aligned; the decisive static delta is the routine-ID pair. Both higher-level wrappers select the inline helper for region counts at or below `0x3fff` and otherwise fall back to `__CGSCreateWindow`.

The authoritative next procedure is now:

```text
docs/process-manager-createwindow-cgs-newwindow-transport-trace-experiment.md
```

That stage adds only a passive exact trace for the statically proven inline IDs to the accepted combined CoreServices interposer, requires a full Snow CreateNewWindow control, then performs exactly one Lion trace with the accepted Dock, notification, and Extras compatibility paths unchanged. It does not rewrite the NewWindow request yet.

