# Process Manager system-service transport audit

## Objective

Resolve the remaining static gap below LaunchServices process-dispatch setup before any live instrumentation is attempted.

The completed process-dispatch audit shows that the Snow Leopard PPC client and Lion native LaunchServices implementations retain the same overall process-services initialization structure. In particular, the PPC Snow Leopard `_LSDoInitializeProcessesServices` client uses message ID `0x4650`, a `0x2c` request, a `0x50` receive buffer, and expects reply ID `0x46b4`. Lion's i386 implementation uses the same values.

Both setup paths also:

- obtain the current security session;
- call `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, 0)`;
- call `_LSDoInitializeProcessesServices`;
- require a successful transport result and a zero returned process-services error;
- create a `CFMachPort` from the returned server port;
- install the process-dispatch table used by Process Manager identity calls.

The server-side InitializeProcessesServices family on both systems also performs session resolution and audit-token handling rather than exposing an obvious PPC-only rejection in the LaunchServices layer.

That means the next unresolved static boundary is below LaunchServices itself: the imported CarbonCore system-service transport and Security session functions used by the PPC client.

This stage remains read-only and does not launch the PPC application.

## Why this audit comes before dynamic instrumentation

The previous audit deliberately examined LaunchServices, not the implementations of its imported functions:

- `scCreateSystemServiceVersion`;
- `scAddReconnectProc`;
- `SessionGetInfo`.

The translated PPC client on Lion is expected to execute the restored Snow Leopard PPC CarbonCore/Security code supplied through the Rosetta environment, while Lion's native CoreServices daemon and native frameworks provide the host-side environment.

Before using GDB, DTrace, interposition, a no-server override, or another failing Process Manager call, we need to know whether those imported transport/session routines changed their service discovery, bootstrap/Mach-port protocol, reconnect behavior, or session assumptions between Snow Leopard and Lion.

## Prepared files

Current runtime `main` provides:

```text
scripts/audit-process-manager-systemservice-transport.py
docs/process-manager-systemservice-transport-audit.md
```

The analyzer is Python-2-compatible and read-only.

It records:

- OS/build and `kern.exec.archhandler.powerpc`;
- Rosetta shared-cache and map identity;
- Rosetta-cache membership for CarbonCore and Security;
- active `coreservicesd` / `com.apple.pbs` launchd state;
- `coreservicesd` binary identity and architecture list;
- the `com.apple.coreservicesd` LaunchDaemon metadata and Mach-service declaration;
- CarbonCore full-file and architecture-slice hashes;
- CarbonCore symbols/imports and disassembly windows matching:
  - `scCreateSystemServiceVersion`;
  - `scCreateSystemService`;
  - `scAddReconnectProc`;
  - related SystemService/reconnect routines;
- CarbonCore helper imports involving bootstrap, Mach messages/ports, and CFMachPort;
- mapped CarbonCore cstrings for CoreServices service names, bootstrap/service-port diagnostics, reconnect state, and related system-service text;
- Security full-file and architecture-slice hashes;
- Security symbols/imports and disassembly windows matching:
  - `SessionGetInfo`;
  - related SecuritySession/AuditSession routines;
- mapped session-related cstrings.

Snow Leopard validation requires the relevant PPC/ppc7400 CarbonCore and Security targets. Lion validation requires the corresponding i386 targets. x86_64 slices are collected as additional native context.

## Safety constraints

For this audit:

- do not launch the PPC test application;
- do not repeat the no-ASN discriminator;
- do not call `scCreateSystemServiceVersion` from custom code yet;
- do not use `SCDontUseServer`;
- do not perform a custom bootstrap/Mach-service lookup;
- do not patch CarbonCore, Security, LaunchServices, HIServices, or coreservicesd;
- do not restart, signal, suspend, or replace coreservicesd, WindowServer, pbs, or launchd jobs;
- do not alter the LaunchServices database;
- do not broaden or install the private LaunchServices PPC-admission patch;
- do not modify the Rosetta cache, Rosetta shims, or private dyld;
- do not transplant Snow Leopard frameworks or daemons;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, DYLD interposition, or live code injection in this stage.

Temporary architecture slices are created only under the system temporary directory and removed on exit.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-systemservice-transport.py
docs/process-manager-systemservice-transport-audit.md
```

No kernel rebuild or reboot is part of this stage.

## Phase B — Snow Leopard transport audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-systemservice-transport.py \
  ./process-manager-systemservice-transport-snowleopard.txt
```

Require:

```text
Created: ./process-manager-systemservice-transport-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged.

## Phase C — Lion transport audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-systemservice-transport.py \
  ./payload/process-manager-systemservice-transport-lion.txt
```

Require:

```text
Created: ./payload/process-manager-systemservice-transport-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop. Do not compensate by launching the PPC application or restarting CoreServices components.

## Phase D — stop and return evidence

Return:

```text
process-manager-systemservice-transport-snowleopard.txt
process-manager-systemservice-transport-lion.txt
```

Keep the completed process-dispatch reports available:

```text
process-manager-process-dispatch-snowleopard.txt
process-manager-process-dispatch-lion.txt
```

No proprietary framework binary should be uploaded at this stage.

## Decision gate

### A. CarbonCore system-service protocol changed materially

If `scCreateSystemServiceVersion` or its direct helpers use a materially different service name, bootstrap lookup, request/reply protocol, version negotiation, or port-handling contract between the Snow Leopard PPC client and Lion native implementation, localize that exact contract first.

The next experiment would then be a minimal process-local service-creation probe, not another Process Manager call.

### B. Security session semantics changed materially

If `SessionGetInfo` or its session/audit-token path differs in a way that can explain the translated client's session initialization failure, isolate that session boundary first.

Do not patch Process Manager or LaunchServices to hide an invalid security session.

### C. CarbonCore and Security transport paths are materially compatible

If the imported transport/session paths are also structurally compatible, static analysis has reached its useful limit.

The next step will then be a narrowly controlled PPC preflight that calls only the exact pre-Process-Manager primitives needed to distinguish:

1. valid `SessionGetInfo`;
2. successful `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, 0)`;
3. failure later inside LaunchServices process-services initialization.

That probe will not call `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, foreground/window APIs, or an event loop.

### D. Provenance is ambiguous

If CarbonCore or Security provenance cannot be established from the Rosetta cache/map, resolve that provenance before any live test.

## Current interpretation to preserve

The process-dispatch audit did not reveal an obvious LaunchServices wire-ABI mismatch for InitializeProcessesServices. The Snow Leopard PPC and Lion i386 client forms use the same `0x4650` message family and the same 32-bit request/receive sizes.

Both systems expose the same `com.apple.CoreServices.coreservicesd` launchd Mach-service declaration, and the service is active on both systems.

Lion's `coreservicesd` lacks a PPC slice, whereas Snow Leopard's binary contains one, but that fact alone does not establish a failure because the translated PPC client communicates with a native daemon over the process-services transport.

The remaining static uncertainty is the CarbonCore/Security layer that obtains the CoreServices system-service endpoint and current security session before LaunchServices sends its InitializeProcessesServices request.

No additional XNU change is indicated.

## Non-goals

This audit does not:

- launch Rosetta/PPC code;
- call Process Manager;
- perform a custom service lookup;
- use the direct-function `SCDontUseServer` path;
- patch any transport or dispatch table;
- change a service or launchd job;
- modify Rosetta or XNU.

It is a read-only differential audit of the system-service and security-session transport beneath LaunchServices process-dispatch initialization.
