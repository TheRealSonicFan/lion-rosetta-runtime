# Process Manager CoreServices system-service RPC protocol audit

## Objective

Resolve the remaining static ambiguity inside CarbonCore service acquisition after the translated PPC pre-dispatch probe returned a null `LaunchApplicationServices` port on Lion.

The completed CarbonCore internals audit shows that Snow Leopard PPC and Lion i386 use the same broad client architecture:

1. establish or recover a CoreServices client session;
2. look up the coreservicesd check-in endpoint;
3. perform `ServerCheckin`;
4. use `SCSession::findOrCreateService`;
5. call the client `FindService` RPC when the requested service is not already cached;
6. return the service object's Mach port through `scCreateSystemServiceVersion`.

However, the previous analyzer did not select the actual MIG-style `ServerCheckin` and `FindService` stubs, the check-in-name helper, or Lion's `connectToCoreServicesD` state transition for complete side-by-side disassembly.

That missing wire/status comparison must be completed before another PPC behavior test.

This stage is read-only.

## Evidence established by the completed internals audit

Both requested reports completed with `RESULT: PASS`.

### Common structure

Snow Leopard PPC and Lion i386 both:

- gate server use through the `SCDontUseServer` check;
- obtain a check-in service name through `getCheckinName()`;
- call `bootstrap_look_up2`;
- call `__scclient_ServerCheckin`;
- construct an `SCClientSession` only after successful check-in;
- route `SCSession::findOrCreateService` through the session's virtual `createService` method when no matching cached service exists;
- implement `SCClientSession::createService` with the `__scsclient_FindService` RPC;
- return null if the client RPC fails or its returned service-status output is nonzero.

### Expected internal-layout evolution

The client-session object layout changed between the releases.

The Snow Leopard PPC check-in path allocates a `0xb4`-byte `SCClientSession` and stores its remote client/service port at offset `0xb0`.

Lion i386 allocates a `0x9c`-byte `SCClientSession` and stores the corresponding port at offset `0x98`.

Those offsets are internal to each framework version. They do not by themselves establish an IPC incompatibility.

### Lion connection-state wrapper

Lion i386 `scCreateSystemServiceVersion` obtains its client-session state through `getStatus()`, which can call `connectToCoreServicesD()`. If the resulting status is outside the two usable states, the exported API returns a null port before `SCSession::findOrCreateService`.

Snow Leopard PPC performs related status/initialization checks directly in the exported path instead of exposing the same selected `getStatus/connectToCoreServicesD` pair in the previous report.

Therefore the observed null port still has two concrete sub-boundaries:

1. CoreServices client check-in/session establishment fails before a usable `SCSession` is available; or
2. check-in succeeds, but the subsequent `FindService("LaunchApplicationServices", 0x00010000,...)` transaction fails or returns a nonzero service status.

The previous report did not expose enough of the RPC stubs to distinguish those statically.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-systemservice-rpc-protocol.py
docs/process-manager-systemservice-rpc-protocol-audit.md
```

The analyzer is Python-2-compatible and read-only.

It expands the CarbonCore static windows to include:

- `scCreateSystemServiceVersion`;
- Lion `getStatus` and `connectToCoreServicesD`;
- `getCheckinName`;
- `SCClientSession::checkinWithServer`;
- all selected `ServerCheckin` client/server/RPC symbols;
- `SCSession::findOrCreateService`;
- `SCClientSession::createService`;
- all selected `FindService` client/server/RPC symbols;
- `scGetServerCheckinPort`;
- `scGetProcessOptions`;
- relevant service-object constructors;
- bootstrap, Mach-message, Mach-port, mutex, syslog, and error helpers;
- mapped cstrings for coreservicesd check-in, service lookup, version diagnostics, and `SCDontUseServer`.

The purpose is to recover the exact request/reply message IDs, message sizes, output/status handling, check-in naming, and service-version semantics used by Snow Leopard PPC and Lion native CarbonCore.

## Safety constraints

For this audit:

- do not launch the PPC pre-dispatch probe;
- do not launch the Process Manager application;
- do not call `scCreateSystemServiceVersion`, `SessionGetInfo`, or Process Manager from custom code;
- do not use `SCDontUseServer`;
- do not perform a custom bootstrap/Mach-service lookup;
- do not patch CarbonCore, Security, LaunchServices, HIServices, or coreservicesd;
- do not restart or signal coreservicesd, securityd, pbs, WindowServer, or launchd jobs;
- do not modify Rosetta, private dyld, LaunchServices databases, or XNU;
- do not use GDB, DTrace, dtruss, DYLD interposition, or live code injection.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-systemservice-rpc-protocol.py
docs/process-manager-systemservice-rpc-protocol-audit.md
```

No kernel rebuild, reboot, or PPC execution is part of this stage.

## Phase B — Snow Leopard RPC protocol audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-systemservice-rpc-protocol.py \
  ./process-manager-systemservice-rpc-protocol-snowleopard.txt
```

Require:

```text
Created: ./process-manager-systemservice-rpc-protocol-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged.

## Phase C — Lion RPC protocol audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-systemservice-rpc-protocol.py \
  ./payload/process-manager-systemservice-rpc-protocol-lion.txt
```

Require:

```text
Created: ./payload/process-manager-systemservice-rpc-protocol-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop. Do not compensate by rerunning the PPC probe.

## Phase D — stop and return evidence

Return:

```text
process-manager-systemservice-rpc-protocol-snowleopard.txt
process-manager-systemservice-rpc-protocol-lion.txt
```

Keep the completed internals reports and pre-dispatch logs available.

No Apple framework or daemon binary should be uploaded.

## Decision gate

### A. ServerCheckin protocol differs materially

If Snow Leopard PPC and Lion native CarbonCore use materially different check-in names, message IDs/sizes, descriptors, output fields, or status semantics, localize that exact contract.

The next experiment would then target only CoreServices client check-in. Do not proceed to `FindService` or Process Manager.

### B. Check-in is compatible, but FindService differs

If `ServerCheckin` is aligned but `FindService` differs in message layout, service/version encoding, returned status, or port handling, focus next on the `LaunchApplicationServices` service-acquisition transaction.

Do not force a port or bypass service-status validation.

### C. Both RPC contracts are materially compatible

If check-in and service lookup are structurally compatible, static analysis has reached its useful limit.

The next stage will then be one minimal, one-shot diagnostic that distinguishes:

1. Lion connection status/check-in failure before `SCSession::findOrCreateService`;
2. successful check-in followed by `FindService` transport failure;
3. successful `FindService` transport with a nonzero returned service status;
4. service-object creation with an unusable/null returned port.

That diagnostic must still stop before `SessionGetInfo`, LaunchServices process-services initialization, and Process Manager.

## Current interpretation to preserve

The `SYSTEMSERVICE_ZERO_PORT` result remains the immediate behavioral boundary.

The current static audit shows the guest PPC client and Lion native client use the same broad check-in/service-acquisition architecture, but it does not yet establish that the underlying MIG request/reply contracts are byte-compatible.

The Security-session hypothesis remains downstream and was not reached by the failing Lion probe.

The syscall-295/XNU boundary remains closed. No additional XNU change is indicated.

## Non-goals

This audit does not:

- establish a live CoreServices connection;
- obtain a service port;
- change CarbonCore connection state;
- bypass a status check;
- call Security, LaunchServices process-services, or Process Manager;
- patch a framework or daemon;
- modify Rosetta or XNU.

It is the final read-only RPC-contract comparison before any lower-level live discriminator is considered.


## Observed result — initial interpretation later corrected

Both requested RPC protocol reports completed with `RESULT: PASS`.

The initial static comparison was incomplete: `FindService` aligns, but the later re-read below establishes a concrete `ServerCheckin` wire incompatibility.

Snow Leopard PPC `ServerCheckin` uses the older complex request form with request ID `0x2710`, send size `0x28`, receive size `0x3c`, and expected reply ID `0x2774`. Lion's native i386 client uses the newer simple `0x18` request. The later re-read documented below shows Lion's `__XServerCheckin` rejects the complex form rather than retaining compatibility for it.

The `FindService` client contract aligns directly: Snow Leopard PPC and Lion i386 both use request ID `0x2723`, send size `0x12c`, receive size `0x30`, and expected reply ID `0x2787`.

At the time of this audit the remaining ambiguity was treated as behavioral; that interpretation is superseded by the correction below, which identifies the `ServerCheckin` request-shape mismatch directly.

The authoritative next step is the guarded one-shot experiment in:

```text
docs/process-manager-systemservice-stage-discriminator-experiment.md
```

It repeats the already proven `scCreateSystemServiceVersion` call and, only after that call returns, reads the existing CarbonCore server-checkin port and process options through dynamically resolved exported helpers from the same guest PPC CarbonCore image.

Do not perform a raw-address call, direct `ServerCheckin`, direct `FindService`, custom bootstrap lookup, or framework patch before that result is reviewed.


## Correction — Lion ServerCheckin does not accept the Snow Leopard PPC complex request

The later live bootstrap-integration result required a re-read of the previously collected Lion i386 `__XServerCheckin` wrapper.

The earlier interpretation in this document that Lion retained compatibility handling for Snow Leopard PPC's descriptor-bearing ServerCheckin request was incorrect.

The shipped client/server binaries show:

### Snow Leopard PPC client

`__scclient_ServerCheckin` builds:

- Mach bits `0x80001513` (complex);
- request ID `0x2710`;
- send size `0x28`;
- receive size `0x3c`;
- descriptor count 1;
- one port descriptor;
- expected reply ID `0x2774`.

### Lion i386 client

Lion's native `__scclient_ServerCheckin` builds:

- Mach bits `0x00001513` (simple);
- request ID `0x2710`;
- send size `0x18`;
- receive size `0x3c`;
- no request descriptor;
- expected reply ID `0x2774`.

### Lion i386 server

Lion's `__XServerCheckin` checks that the request is **not complex** and that its size is exactly `0x18`. A complex request is routed to the `MIG_BAD_ARGUMENTS` reply path before `__scserver_ServerCheckin` is invoked.

Therefore the Snow Leopard PPC request is structurally incompatible with Lion's live ServerCheckin wrapper even though the request and reply IDs remain the same.

The completed bootstrap integration experiment independently supports this correction: after the bootstrap call is adapted successfully and returns a nonzero coreservicesd port, unmodified PPC CarbonCore still never obtains a server-checkin port.

The next controlled experiment is:

```text
docs/process-manager-servercheckin-protocol-adapter-experiment.md
```

It sends exactly one native Lion simple ServerCheckin request from a standalone translated PPC subject after the already-proven Lion-format bootstrap lookup.

Do not use the superseded claim that Lion accepts the legacy complex ServerCheckin form.
