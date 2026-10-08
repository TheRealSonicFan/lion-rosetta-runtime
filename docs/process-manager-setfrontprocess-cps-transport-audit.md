# Process Manager SetFrontProcess CPS/CGS transport audit

## Objective

Resolve the exact CoreGraphics/CPS boundary beneath the translated-PPC `SetFrontProcess` failure before any new behavioral experiment or compatibility layer is attempted.

The completed first call-path audit established a clean client-side localization:

- the validated Rosetta shared cache and map are identical on Snow Leopard and Lion;
- HIServices and CoreGraphics are present in that cache on both systems;
- Snow Leopard PPC `SetFrontProcessWithOptions` validates the PSN/options and then calls `_CPSSetFrontProcess`;
- Lion i386 `SetFrontProcessWithOptions` has the same essential structure and also delegates to `_CPSSetFrontProcess`;
- with the actual test inputs (non-null PSN and options `0`), Lion's `-50` result is therefore generated at or below the CPS/CoreGraphics layer, not by the initial public-API argument checks.

The existing v1 audit did **not** capture the exact CoreGraphics `_CPSSetFrontProcess`, `__CPSSetFrontProcessWithOptions`, and `__CGSSetFrontProcess` function windows for the relevant Snow PPC and Lion i386 comparison. The generic symbol-window collection capped before those late CoreGraphics symbols, and `EXACT_TARGETS["CoreGraphics"]` was empty. That is an evidence-collection limitation, not an audit failure.

This focused audit fixes that omission without launching PowerPC code.

## Why this is the correct next boundary

The accepted dynamic differential remains:

```text
Snow Leopard:
  GetProcessForPID      = 0
  GetProcessPID         = 0
  TransformProcessType  = 0
  SetFrontProcess       = 0

Lion:
  GetProcessForPID      = 0
  GetProcessPID         = 0
  TransformProcessType  = 0
  SetFrontProcess       = -50
```

The Lion call returned normally. It did not crash, self-abort, trigger another exact SessionInit transaction, or modify protected state.

The first audit now shows that the HIServices wrapper reaches `_CPSSetFrontProcess`. The remaining unknown is whether the difference is:

1. a pre-transport CPS connection/registration condition;
2. a Snow-PPC-to-Lion CGS wire/protocol mismatch;
3. a WindowServer/backend response to an otherwise compatible request; or
4. a native-Lion error-mapping semantic difference below HIServices.

The restored Rosetta cache is especially important here: the translated guest is using Snow Leopard PPC CoreGraphics code while the host-side WindowServer is Lion. The focused comparison therefore needs the exact Snow PPC CoreGraphics client path and Lion's native client path that reflects the Lion WindowServer contract.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-setfrontprocess-cps.py
docs/process-manager-setfrontprocess-cps-transport-audit.md
```

The analyzer is Python-2-compatible and read-only.

For HIServices it targets exactly:

```text
_SetFrontProcess
_SetFrontProcessWithOptions
__SetFrontProcessWithOptions
_TransformProcessType
```

For CoreGraphics it targets exactly:

```text
_CPSSetFrontProcess
__CPSSetFrontProcessWithOptions
__CGSSetFrontProcess
__CGSDefaultConnection
__CPSRegisterWithServer
__CGSCheckInApplication
_CGSMainConnectionID
__CPSGetCurrentProcess
__CPSGetFrontProcess
_CPSPostShowReq
```

For each available architecture it records:

- full-file and thin-slice SHA-256;
- linked-library dependencies;
- focused CPS/CGS strings and symbols;
- the complete disassembly window for every exact target found;
- references/callers to each exact target.

Validation requires the relevant Snow Leopard PPC and Lion i386 core targets to be present. Missing optional architecture slices are recorded but are not treated as failures outside those required control slices.

## Questions this audit must answer

### 1. What raw condition can CPS return before transport?

Determine whether Snow PPC `__CPSSetFrontProcessWithOptions` returns a fixed CPS status when the default/current CoreGraphics connection is absent, and whether that status is one that HIServices maps to `-50`.

### 2. What exact request does Snow PPC send?

Decode the Snow PPC `__CGSSetFrontProcess` transport:

- remote port source;
- Mach message ID;
- header bits;
- send/receive sizes;
- request field order and widths;
- expected reply ID/shape;
- returned server status extraction.

### 3. What does Lion native CoreGraphics send?

Compare the Lion i386/x86_64 client path with Snow PPC/i386.

If message ID, size, field order, or reply contract changed, that becomes a concrete protocol-evolution candidate.

### 4. Is default-connection/CPS registration the differentiator?

Correlate:

```text
__CGSDefaultConnection
__CPSRegisterWithServer
__CGSCheckInApplication
_CPSSetFrontProcess
```

with the known Lion registration-time diagnostic that `_CGSDefaultConnection()` was NULL.

Do not assume causality unless the exact CoreGraphics control flow supports it.

## Safety constraints

For this stage:

- do not launch the PPC SetFrontProcess subject again;
- do not call `SetFrontProcess` or `GetFrontProcess`;
- do not set `LSDONOTABORTIFNOASN`;
- do not create a window or run an event loop;
- do not restart or signal WindowServer, coreservicesd, pbs, loginwindow, Dock, or launchd jobs;
- do not patch HIServices, CoreGraphics, LaunchServices, CarbonCore, Security, Rosetta shims, dyld, or the shared cache;
- do not add a CPS/CGS/WindowServer interposer;
- do not broaden the v5 CoreServices adapter;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, or live code injection.

This stage is static/read-only evidence collection only.

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

## Phase B — Snow Leopard focused CPS/CGS audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-setfrontprocess-cps.py \
  ./process-manager-setfrontprocess-cps-snowleopard.txt
```

Require:

```text
Created: ./process-manager-setfrontprocess-cps-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return that report unchanged.

## Phase C — Lion focused CPS/CGS audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-setfrontprocess-cps.py \
  ./payload/process-manager-setfrontprocess-cps-lion.txt
```

Require:

```text
Created: ./payload/process-manager-setfrontprocess-cps-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop. Do not compensate by rerunning the PPC subject.

## Phase D — return evidence

Return only:

```text
process-manager-setfrontprocess-cps-snowleopard.txt
process-manager-setfrontprocess-cps-lion.txt
```

Keep the completed v1 reports available:

```text
process-manager-setfrontprocess-callpath-snowleopard.txt
process-manager-setfrontprocess-callpath-lion.txt
```

and keep the prior dynamic SetFrontProcess logs available for correlation.

No Apple framework or daemon binary should be uploaded at this stage.

## Decision gate

### A. Snow PPC and Lion native CGS wire differ

Localize the exact message-ID/layout/reply difference first. Only then may a request/reply adapter be designed, and it must be limited to that one proven transaction.

### B. CPS returns a connection-state error before any transport

The next stage should be a narrowly scoped diagnostic of CoreGraphics/CPS registration state, not a Mach-message adapter.

### C. Wire is compatible but Lion backend returns an error

Audit the exact WindowServer/server-side state or policy that produces that returned code before changing behavior.

### D. Static path remains ambiguous

Only then prepare a process-local passthrough diagnostic that logs the raw `_CPSSetFrontProcess` return and default-connection state without altering either result.

Do not proceed to `GetFrontProcess`, window creation, or an event loop until one of these cases is established.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security compatibility        -> PASS
SessionUniverse InitConnection v5            -> PASS
GetProcessForPID                             -> PASS
GetProcessPID                                -> PASS
TransformProcessType                         -> PASS
SetFrontProcess
  Snow Leopard                               -> PASS
  Lion                                       -> -50
HIServices client wrapper                    -> localized to _CPSSetFrontProcess
CoreGraphics CPS/CGS transport               -> next read-only proof
```

No additional XNU change is indicated.


## Observed completed result — two distinct CPS/CGS boundaries are now proven

The focused audit completed with `RESULT: PASS` on Snow Leopard and Lion and resolves the previously missing CoreGraphics windows.

The immediate Snow PPC CPS path is:

```text
CPSSetFrontProcess
  -> __CPSSetFrontProcessWithOptions
       -> read current CoreGraphics connection record
       -> if null: return raw CPS 0x000003eb (1003)
       -> otherwise: __CGSSetFrontProcess
```

The connection-record load in the standalone Snow PPC image is derived from the `__CPSSetFrontProcessWithOptions` PIC sequence and statically targets `0x007007c8`; that value is provenance for the unoptimized thin slice, not a guaranteed shared-cache runtime offset. Lion native CoreGraphics contains the same semantic pre-transport guard and also returns `0x3eb` when its current connection record is absent.

Snow PPC HIServices maps the positive CPS status `0x3eb` to public `paramErr (-50)`. This exactly fits the previously observed Lion public result, but a dynamic raw-CPS/state correlation is required before declaring the null connection causal.

The audit also proves a second, later protocol difference:

```text
Snow PPC __CGSSetFrontProcess:
  request 0x729e
  reply   0x7302
  send    0x30
  receive 0x2c

Lion i386 __CGSSetFrontProcess:
  request 0x72a1
  reply   0x7305
  send    0x30
  receive 0x2c
```

Therefore a CGS request-ID adapter may eventually be needed, but only after proving the current translated process actually reaches that transport.

The authoritative next stage is:

```text
docs/process-manager-setfrontprocess-cps-connection-discriminator-experiment.md
```

That experiment resolves the loaded PPC CPS symbols, decodes the shared-cache-adjusted `addis`/`lwz` PIC sequence in `_CPSSetFrontProcessWithOptions` to recover the actual runtime connection-slot address, calls exactly one private `CPSSetFrontProcess`, and records its raw status. It does not call public `SetFrontProcess`, `GetFrontProcess`, or any window/event-loop API.

No additional XNU change is indicated.
