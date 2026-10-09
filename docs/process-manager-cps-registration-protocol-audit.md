# Process Manager CPS application-registration protocol audit

## Objective

Localize the next active user-space boundary after the successful CoreGraphics default-connection repair.

The completed server-version compatibility integration established all of the following on Lion translated PPC:

```text
session-port adapter                         PASS
server-version 600/0 -> 545/0 normalizer     PASS
__CGSNewConnectionPort request               0x7469
__CGSNewConnectionPort reply                 0x74cd
Mach result                                  success
GetProcessForPID                             0
CoreGraphics connection-record slot          nonzero
integration result                           CGS_SERVER_VERSION_COMPAT_CONNECTION_ESTABLISHED
```

However, the same successful run immediately emitted:

```text
_RegisterApplication(), FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304
```

Therefore the default CoreGraphics connection is now established, but Process Manager registration is not yet fully accepted by the Lion WindowServer/CPS side.

The next step is **not** SetFrontProcess and is **not** an adaptation of the already-known `0x729e -> 0x72a1` foreground request. The next boundary is the CPS application-registration transaction performed after default-connection creation.

## Existing static clue

Earlier focused CoreGraphics reports already show a material client evolution:

Snow Leopard PPC `__CPSRegisterWithServer` calls:

```text
__CGSCheckInApplication
```

Lion native `__CPSRegisterWithServer` calls:

```text
__CGSCreateApplication
```

The old reports were built for SetFrontProcess discrimination and did not exact-target both sides of this registration differential as a protocol study. In particular, Lion's `__CGSCreateApplication` body was not emitted as an exact target.

That is now the decisive missing evidence.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-cps-registration-protocol.py
```

Analyzer version:

```text
1
```

It is Python-2-compatible and read-only.

It inspects CoreGraphics slices for these exact targets:

```text
__CPSRegisterWithServer
__CGSCheckInApplication
__CGSCreateApplication
```

For every target found it records:

- the complete function window up to the next text symbol;
- direct calls and branches;
- immediate-bearing instructions;
- references/callers;
- focused symbols/imports including `mach_msg`, MIG reply-port helpers, NDR, session and registration helpers;
- focused strings and addressed cstrings;
- full-file and thin-slice provenance.

Validation requires:

Snow Leopard 10.6.8 PPC:

```text
__CPSRegisterWithServer
__CGSCheckInApplication
```

Lion 10.7.5 i386:

```text
__CPSRegisterWithServer
__CGSCreateApplication
```

Other slices are corroborating evidence only.

## Questions this audit must answer

### 1. What exact Snow PPC registration transaction follows connection creation?

Decode `__CGSCheckInApplication` completely:

- request ID;
- expected reply ID;
- request header bits;
- send/receive sizes;
- field order and widths;
- descriptor use, if any;
- NDR fields;
- return-code extraction;
- retry-relevant server status.

Earlier broad evidence suggests the Snow helper belongs to the `0x7372 -> 0x73d6` family, but this audit must establish the exact PPC contract from the complete helper body before that tuple is treated as authoritative.

### 2. What exact Lion native registration transaction replaced it?

Decode `__CGSCreateApplication` with the same rigor:

- request/reply IDs;
- send/receive sizes;
- payload fields;
- descriptor semantics;
- NDR handling;
- return-code extraction.

### 3. Did the registration ABI evolve or only the wrapper name?

Compare the exact Snow PPC and Lion native contracts. Determine whether the observed Lion `err=-304` is structurally consistent with the restored Snow PPC client sending a legacy request to a Lion server that validates a different request shape.

Do not assume that `-304` alone proves a size mismatch; the exact generated/client contracts must be compared first.

### 4. Does `__CPSRegisterWithServer` itself change argument preparation?

Compare the wrapper-side argument construction, including PSN/application identity, session information, path/name strings, flags, and retry behavior.

## Safety constraints

For this stage:

- do not launch a PPC test application;
- do not rerun the successful server-version integration;
- do not call `GetProcessPID`, `TransformProcessType`, `CPSSetFrontProcess`, or public `SetFrontProcess`;
- do not adapt `__CGSCheckInApplication`, `__CGSCreateApplication`, `0x729e`, or any other CGS request;
- do not broaden the server-version normalizer;
- do not alter CoreGraphics defaults;
- do not fabricate CPS registration state, PSNs, Mach rights, or connection records;
- do not patch CoreGraphics, WindowServer, Rosetta, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection.

This is a static/read-only differential only.

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

No kernel rebuild or reboot is part of this stage.

## Phase B — Snow Leopard audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cps-registration-protocol.py \
  ./process-manager-cps-registration-protocol-snowleopard.txt
```

Require:

```text
analyzer_version=1
product_version=10.6.8
__CPSRegisterWithServer count=1
__CGSCheckInApplication count=1
RESULT: PASS
```

If Phase B fails, stop and return the Snow report. Do not run Lion.

## Phase C — Lion audit

Only after Phase B passes, on Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cps-registration-protocol.py \
  ./payload/process-manager-cps-registration-protocol-lion.txt
```

Require:

```text
analyzer_version=1
product_version=10.7.5
__CPSRegisterWithServer count=1
__CGSCreateApplication count=1
RESULT: PASS
```

Do not rerun any translated-PPC subject after the audit.

## Phase D — return evidence and stop

Return only:

```text
process-manager-cps-registration-protocol-snowleopard.txt
process-manager-cps-registration-protocol-lion.txt
```

Stop after returning those reports.

## Decision gate

### Snow legacy and Lion native registration contracts differ

This is the leading expected case. Localize the exact request/reply and field-layout delta first. The next stage would be a standalone protocol proof or a passive exact registration trace; no integrated adapter should be written until the mismatch is dynamically or structurally proven.

### Contracts are wire-compatible

Then the `err=-304` must come from argument/state semantics rather than the generated envelope. Audit the exact wrapper inputs and server-status path before changing behavior.

### Lion retains the legacy helper too

Determine which helper native Lion `__CPSRegisterWithServer` actually calls and why. Presence of a legacy symbol alone is not proof that Lion accepts the Snow request on this path.

### Required target missing

Treat this as an analyzer/modeling issue and stop. Do not compensate with a dynamic experiment.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
__CGSNewConnectionPort 0x7469/0x74cd        -> PASS
CoreGraphics default connection             -> NONZERO
GetProcessForPID                            -> PASS
CPS/WindowServer registration               -> err=-304
known later SetFrontProcess mismatch         -> still out of scope
next step                                   -> read-only CPS registration protocol differential
```

No additional XNU change is indicated.
