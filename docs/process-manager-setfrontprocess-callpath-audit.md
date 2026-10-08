# Process Manager SetFrontProcess call-path audit

## Objective

Localize the first returned-error boundary after translated PPC Process Manager identity and foreground conversion have already succeeded.

The completed SetFrontProcess experiment establishes a clean Snow Leopard/Lion differential under the same direct-execution Aqua-console harness:

```text
Snow Leopard 10.6.8:
  GetProcessForPID     = 0
  GetProcessPID        = 0, exact PID round-trip
  TransformProcessType = 0
  SetFrontProcess      = 0
  RESULT               = PASS

Lion 10.7.5:
  GetProcessForPID     = 0
  GetProcessPID        = 0, exact PID round-trip
  TransformProcessType = 0
  SetFrontProcess      = -50
  RESULT               = POSTIDENTITY_SETFRONTPROCESS_RETURNED_ERROR
```

The Lion call returned normally; it did not abort or crash. No second exact SessionInit request was observed, no new crash/core diagnostic was produced, protected hashes were unchanged, and syscall 295 remained healthy.

Therefore the next step is not another behavioral probe and not a compatibility patch. It is a read-only differential audit of the exact `SetFrontProcess`/foreground-selection call path.

## Why this audit is needed

The failure occurs strictly after three independently successful boundaries:

1. PID -> PSN lookup;
2. PSN -> PID round-trip;
3. foreground process-type conversion.

Lion still emits the already-known registration-time diagnostics:

```text
kCGErrorRangeCheck: On-demand launch of the Window Server is allowed for root user only.
_RegisterApplication(), FAILED TO establish the default connection to the WindowServer,
_CGSDefaultConnection() is NULL.
```

Those diagnostics predate the successful identity and `TransformProcessType` results, so their relevance to `SetFrontProcess=-50` is not yet proven. The audit must establish whether `SetFrontProcess` directly requires a CGS/CPS/default connection, performs an additional PSN/ASN validation, delegates through another foreground API, or follows a materially different Snow Leopard/Lion backend path.

Do not infer a WindowServer workaround from the numeric status alone.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-setfrontprocess.py
docs/process-manager-setfrontprocess-callpath-audit.md
```

The analyzer is Python-2-compatible and read-only. It records:

- OS/build and PowerPC architecture-handler state;
- Rosetta shared-cache/map identity and relevant map membership;
- current WindowServer, coreservicesd, pbs, loginwindow, and Dock state;
- full-file and architecture-slice identities for:
  - HIServices;
  - CoreGraphics;
  - LaunchServices;
  - Rosetta ApplicationServices shim;
  - Rosetta Interposers;
  - WindowServer when present at the expected path;
- dependencies;
- filtered strings and symbols matching:
  - `SetFrontProcess`;
  - `SetFrontProcessWithOptions`;
  - `GetFrontProcess`;
  - `TransformProcessType`;
  - CPS/CGS/default-connection/front-process helpers;
  - application ASN/Process Manager helpers;
- targeted disassembly windows for matching functions;
- direct reference/caller lines for the HIServices foreground APIs.

Temporary thin slices are created only under the system temporary directory and removed on exit.

## Safety constraints

For this audit:

- do not launch the PPC subject again;
- do not call another Process Manager API;
- do not set `LSDONOTABORTIFNOASN`;
- do not run `SetFrontProcess` again;
- do not call `GetFrontProcess`;
- do not create a window or run an event loop;
- do not restart or signal WindowServer, coreservicesd, pbs, loginwindow, Dock, or launchd jobs;
- do not patch HIServices, CoreGraphics, LaunchServices, CarbonCore, Security, Rosetta shims, dyld, or the shared cache;
- do not add a WindowServer/CGS/CPS interposer;
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

## Phase B — Snow Leopard call-path audit

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-setfrontprocess.py \
  ./process-manager-setfrontprocess-callpath-snowleopard.txt
```

Require:

```text
Created: ./process-manager-setfrontprocess-callpath-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If the report ends in `RESULT: FAIL`, stop and return it unchanged.

## Phase C — Lion call-path audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-setfrontprocess.py \
  ./payload/process-manager-setfrontprocess-callpath-lion.txt
```

Require:

```text
Created: ./payload/process-manager-setfrontprocess-callpath-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If it fails, stop. Do not rerun the PPC SetFrontProcess subject.

## Phase D — return evidence

Return only:

```text
process-manager-setfrontprocess-callpath-snowleopard.txt
process-manager-setfrontprocess-callpath-lion.txt
```

Keep the just-completed dynamic evidence available, especially:

```text
lion-ppc-process-manager-postidentity-setfrontprocess.log
lion-ppc-process-manager-postidentity-setfrontprocess.raw.log
ppc-process-manager-postidentity-setfrontprocess-snowleopard-control.log
```

No Apple framework binary should be uploaded at this stage. If the reports do not contain enough information to resolve a call path, request only the exact slice/binary needed for offline follow-up.

## Questions this audit must answer

### 1. Where does Snow PPC SetFrontProcess succeed?

Determine the exact Snow Leopard PPC HIServices call chain after `SetFrontProcess`/ `SetFrontProcessWithOptions`, including any CPS/CGS/default-connection call and any PSN/ASN conversion.

### 2. What does Lion native SetFrontProcess validate or call differently?

Compare Lion i386 with Snow PPC and Snow i386. Localize any changed parameter validation, application/ASN lookup, connection acquisition, or foreground-selection transport.

### 3. Is the returned -50 generated before transport or by a backend?

If the client has an explicit local `-50` return path, identify the exact predicate that reaches it. If the status is returned from CPS/CGS/WindowServer or another backend, identify that call boundary instead.

### 4. Are the old WindowServer diagnostics causally relevant?

The default-connection diagnostics alone are not sufficient proof because identity and `TransformProcessType` already succeed afterward. Determine whether `SetFrontProcess` actually consumes that same connection state.

## Decision gate

Do not implement compatibility behavior until the audit resolves the source of the returned status.

Possible outcomes:

- **local HIServices validation difference:** prepare the smallest discriminator around that validation;
- **CPS/CGS/default-connection dependency:** audit the exact connection/foreground transport before any interposer;
- **LaunchServices ASN/application-state dependency:** narrow the audit to that lookup/state boundary;
- **wire/protocol mismatch:** prove exact request/reply structure before writing an adapter;
- **static path effectively identical:** only then design a controlled, behavior-preserving runtime diagnostic around the exact call.

Do not jump directly to `GetFrontProcess`, window creation, or an event loop from the current failure.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo adaptation -> PASS
LaunchServices process-dispatch setup -> PASS
SCSessionUniverse InitConnection request adaptation -> PASS
GetProcessForPID(getpid()) -> PASS
GetProcessPID(returned PSN) -> PASS
TransformProcessType(returned PSN, foreground) -> PASS
SetFrontProcess(returned PSN):
  Snow Leopard -> PASS
  Lion         -> returned -50
next step      -> read-only SetFrontProcess call-path differential audit
```

No additional XNU change is indicated.


## Observed completed result — HIServices localizes the failure to CPS/CoreGraphics

The first call-path audit completed with `RESULT: PASS` on both systems.

The reports establish four important facts.

First, both systems use the same validated Rosetta cache and map, and both HIServices and CoreGraphics are members of that cache. The translated Lion process therefore continues to execute the restored Snow Leopard PPC guest-side framework code while talking to Lion host services.

Second, Snow Leopard PPC `SetFrontProcessWithOptions` validates a non-null PSN pointer and options no greater than 1, performs lazy registration if needed, and then calls `_CPSSetFrontProcess`. The Snow PPC wrapper explicitly recognizes/preserves several CPS return codes, including `0xffce` (-50), before returning an OSStatus.

Third, Lion native i386 `SetFrontProcessWithOptions` has the same decisive structure: after its own local pointer/options checks and lazy registration state checks, it calls `_CPSSetFrontProcess` and maps/preserves that returned CPS status. With the experiment's actual non-null PSN and options `0`, the observed Lion `SetFrontProcess=-50` is therefore generated at or below the CPS/CoreGraphics boundary rather than by the initial public-API argument validation.

Fourth, the v1 analyzer did not emit the exact CoreGraphics `_CPSSetFrontProcess`, `__CPSSetFrontProcessWithOptions`, or `__CGSSetFrontProcess` disassembly windows needed for the relevant Snow PPC versus Lion native comparison. Those symbols are present, but the generic symbol-window cap was reached before them because the v1 `CoreGraphics` exact-target list was empty.

The authoritative next stage is therefore:

```text
docs/process-manager-setfrontprocess-cps-transport-audit.md
scripts/audit-process-manager-setfrontprocess-cps.py
```

That audit is still read-only. It exact-targets the CPS/default-connection/CGS transport functions so the next review can decide whether Lion's `-50` reflects a missing CPS connection, a Snow-PPC-to-Lion CGS wire mismatch, or a backend-returned error.

Do not rerun the PPC subject or add a CPS/CGS/WindowServer workaround until that focused evidence is reviewed.

No additional XNU change is indicated.
