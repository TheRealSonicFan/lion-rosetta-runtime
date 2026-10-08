# Process Manager CGS default-connection differential audit

## Objective

Localize the now-proven CoreGraphics default-connection failure that prevents translated Snow Leopard PPC applications from reaching the later `SetFrontProcess` CGS transport on Lion.

The completed CPS connection-state discriminator established a strict Snow Leopard/Lion differential under the same validated Process Manager path:

```text
Snow Leopard:
  preidentity connection slot      = 0
  GetProcessForPID                 = 0
  postidentity connection slot     = nonzero
  GetProcessPID round-trip         = PASS
  TransformProcessType             = 0
  CPSSetFrontProcess raw status    = 0
  RESULT                           = PASS

Lion:
  preidentity connection slot      = 0
  GetProcessForPID                 = 0
  _RegisterApplication diagnostic  = _CGSDefaultConnection() is NULL
  postidentity connection slot     = 0
  GetProcessPID round-trip         = PASS
  TransformProcessType             = 0
  CPSSetFrontProcess raw status    = 0x3eb / 1003
  RESULT                           = CPS_CONNECTION_NULL_PRETRANSPORT_CONFIRMED
```

No new crash/core diagnostic was produced, protected hashes were unchanged, and syscall 295 remained healthy.

This proves that the current public `SetFrontProcess=-50` failure is **not** yet caused by the already-known Snow-PPC `0x729e` versus Lion `0x72a1` SetFrontProcess request-ID difference. The translated process never reaches that transaction because its CoreGraphics default connection is still absent.

## Immediate causal boundary

The earlier HIServices audit already shows the registration order used by the untouched Snow PPC client and by Lion native HIServices:

1. `_RegisterApplication` / `__RegisterApplication` calls `_CGSDefaultConnection`;
2. only when that returns nonzero does registration proceed to `_CPSRegisterWithServer`;
3. the null path emits:
   `FAILED TO establish the default connection to the WindowServer, _CGSDefaultConnection() is NULL.`

The successful discriminator now makes that diagnostic causal rather than merely correlated.

On Snow Leopard, the same decoded CoreGraphics connection-record slot starts at zero and becomes nonzero during `GetProcessForPID` registration. On Lion it remains zero through registration, foreground conversion, and the raw CPS call.

The next unresolved boundary is therefore inside:

```text
_CGSDefaultConnection
  -> _CGSNewConnection
     -> server-port acquisition / __CGSNewConnectionPort
        -> connection establishment
```

before `_CPSRegisterWithServer`.

## Why this is a read-only audit first

The Lion log also records:

```text
kCGErrorRangeCheck: On-demand launch of the Window Server is allowed for root user only.
_RegisterApplication(), FAILED TO establish the default connection to the WindowServer,
_CGSDefaultConnection() is NULL.
```

Those messages strongly suggest a server-port or connection-creation problem, but they do not yet distinguish:

- an obsolete Snow Leopard bootstrap/service lookup;
- a Snow-PPC-to-Lion connection-establishment Mach message mismatch;
- a Lion session/authentication policy rejection;
- a native Lion migration to a different connection mechanism;
- or a later connection-record initialization difference.

Do not patch around the null pointer and do not force a fabricated CoreGraphics connection record. The exact connection creation contract must be established first.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-process-manager-cgs-default-connection.py
docs/process-manager-cgs-default-connection-audit.md
```

The analyzer is Python-2-compatible and read-only.

It records:

- OS/build and PowerPC architecture-handler state;
- Rosetta shared-cache/map provenance and HIServices/CoreGraphics membership;
- current read-only process/job state for WindowServer, loginwindow, Dock, coreservicesd, and pbs;
- full-file and architecture-slice identities for HIServices and CoreGraphics;
- linked-library dependencies;
- focused strings/symbols/imports for WindowServer, bootstrap/vproc/XPC, Mach messaging, registration, and default-connection paths;
- exact disassembly windows and references for the following functions when present.

### HIServices targets

```text
__RegisterApplication
_RegisterApplication
_RegisterCGSessionWhenFirstRootProcessLaunches
_TransformProcessType
_SetFrontProcessWithOptions
```

### CoreGraphics targets

```text
_CGSInitialize
__CGSConnectionInitialize
_CGSDefaultConnectionForThread
__CGSDefaultConnection
_CGSMainConnectionID
__CGSMainConnection
_CGSDefaultConnectionMachPort
_CGSNewConnection
__CGSNewConnectionPort
_CGSLookupServerPort
_CGWindowServerCFMachPort
__CPSInitialize
__CPSRegisterWithServer
__CGSCheckInApplication
_CGSGetDenyWindowServerConnections
_CGSSetDenyWindowServerConnections
```

Validation requires the core registration/connection targets in the Snow Leopard PPC slice and Lion i386 slice. Optional corroborating architecture targets are recorded when present.

## Questions this audit must answer

### 1. Exactly where can Snow PPC `_CGSDefaultConnection` return zero?

Trace the Snow PPC path from `_CGSDefaultConnection` into `_CGSNewConnection` and identify every return condition before the global/default connection record is installed.

### 2. How does Snow PPC acquire the WindowServer service port?

Determine the exact service name and mechanism used by:

```text
_CGSNewConnection
_CGSLookupServerPort
__CGSNewConnectionPort
```

including any use of:

```text
bootstrap_look_up*
vproc_mig_look_up2
xpc_*
mach_msg
task/bootstrap ports
```

The audit must establish whether the old PPC client is trying to resolve or on-demand-launch a service in a way Lion no longer accepts.

### 3. What does Lion native CoreGraphics do differently?

Compare Snow PPC with Snow i386/x86_64 and Lion i386/x86_64. Determine whether Lion changed:

- the service name;
- launchd/bootstrap lookup layout;
- per-session service selection;
- XPC involvement;
- connection-creation request ID;
- request/reply size or field order;
- audit/session data;
- or error handling.

### 4. If a connection-creation Mach request is reached, what is its exact wire contract?

Extract:

- remote-port source;
- request ID;
- send and receive sizes;
- header bits;
- descriptors;
- payload field order and widths;
- expected reply ID and shape;
- raw server return handling.

Do not infer a compatible adapter from message IDs alone.

### 5. Is `_CPSRegisterWithServer` active in the failing Lion PPC path?

The existing dynamic evidence indicates no, because `_CGSDefaultConnection` is null first. Confirm the static call ordering and keep CPS registration outside the active fix unless new evidence contradicts that ordering.

## Safety constraints

For this audit:

- do not launch the PPC discriminator or any PPC Process Manager subject;
- do not call `_CGSDefaultConnection`, `_CGSNewConnection`, or `_CPSRegisterWithServer`;
- do not call public `SetFrontProcess` or `GetFrontProcess`;
- do not create a window or run an event loop;
- do not set `LSDONOTABORTIFNOASN`;
- do not restart, signal, or relaunch WindowServer, launchd, loginwindow, Dock, coreservicesd, or pbs;
- do not add a CoreGraphics/CPS/CGS/WindowServer interposer;
- do not adapt `0x729e -> 0x72a1`;
- do not fabricate or write the CoreGraphics connection-record slot;
- do not broaden the v5 CoreServices or v1 Security adapters;
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

## Phase B — Snow Leopard default-connection audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-default-connection.py \
  ./process-manager-cgs-default-connection-snowleopard.txt
```

Require:

```text
Created: ./process-manager-cgs-default-connection-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

Phase B is a hard gate. If it ends in `RESULT: FAIL`, stop and return that report unchanged. Do not run Lion until the analyzer is corrected.

## Phase C — Lion default-connection audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-cgs-default-connection.py \
  ./payload/process-manager-cgs-default-connection-lion.txt
```

Require:

```text
Created: ./payload/process-manager-cgs-default-connection-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If it fails, stop. Do not compensate by running another PPC subject.

## Phase D — return evidence

Return only:

```text
process-manager-cgs-default-connection-snowleopard.txt
process-manager-cgs-default-connection-lion.txt
```

Keep the completed discriminator evidence available for correlation, especially:

```text
lion-ppc-process-manager-cps-connection-discriminator.log
lion-ppc-process-manager-cps-connection-discriminator.raw.log
ppc-process-manager-cps-connection-discriminator-snowleopard-control.log
```

No Apple framework or daemon binary should be uploaded at this stage.

## Decision gate

### A. Snow PPC uses an obsolete WindowServer service lookup

If Snow PPC fails before obtaining a usable Lion WindowServer port and Lion native uses a different service lookup/session mechanism, prove that exact lookup evolution before designing a process-local adapter.

Do not use a generic bootstrap rewrite: any adapter must discriminate only the exact CoreGraphics lookup tuple that the audit proves incompatible.

### B. Service lookup is compatible but connection-creation wire differs

If the same server port is obtainable but Snow PPC `__CGSNewConnectionPort` sends an obsolete request ID/layout, perform a generated/client-server protocol audit for that exact transaction before implementing adaptation.

### C. Wire is compatible but Lion rejects session/authentication state

Localize the exact backend status and required native Lion session/audit semantics. Do not bypass the check or synthesize a connection record.

### D. Lion native moved the connection path to XPC or another mechanism

Treat the native Lion path as the semantic oracle. Determine the smallest process-local bridge that reproduces native connection establishment for the translated PPC process without reviving an obsolete server contract.

### E. Static evidence is still ambiguous

Only then prepare one behavior-preserving dynamic discriminator around the exact server-port/connection-creation call boundary. It must observe raw return/state without changing either.

## Current boundary

```text
syscall 295 compatibility                         -> PASS
CoreServices / Security compatibility             -> PASS
SessionUniverse InitConnection v5                 -> PASS
GetProcessForPID / GetProcessPID                  -> PASS
TransformProcessType                              -> PASS
Snow PPC CoreGraphics connection slot:
  before GetProcessForPID                         -> zero
  after GetProcessForPID                          -> nonzero
Lion translated-PPC CoreGraphics connection slot:
  before GetProcessForPID                         -> zero
  after GetProcessForPID                          -> zero
Lion _RegisterApplication                         -> _CGSDefaultConnection() NULL
raw CPSSetFrontProcess on Lion                    -> 0x3eb before transport
legacy SetFrontProcess CGS request 0x729e          -> not reached
next step                                         -> _CGSDefaultConnection/_CGSNewConnection differential audit
```

No additional XNU change is indicated.
