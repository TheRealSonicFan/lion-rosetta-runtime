# Process Manager CarbonCore system-service internals audit

## Objective

Localize why the translated PPC pre-dispatch probe receives a null service port from:

`scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)`

on Lion, while the exact same PPC executable succeeds on Snow Leopard.

The completed live pre-dispatch experiment established that the failure occurs before `SessionGetInfo` is reached, so the Security-session divergence found in the previous static audit is not the immediate failing boundary.

This stage is read-only. It does not launch another PPC process.

## Evidence established by the pre-dispatch experiment

The exact PPC executable, with the same SHA-256 and `LC_LOAD_DYLINKER=/usr/oah/dyld`, behaves differently across the two systems.

On Snow Leopard 10.6.8:

- `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)` returns a nonzero Mach port;
- `SessionGetInfo(callerSecuritySession,...)` returns `noErr`;
- a nonzero security-session ID is returned;
- the control reports `RESULT: PASS`.

On Lion 10.7.5:

- the executable reaches `main()`;
- CarbonCore, Security, LaunchServices, and the other expected Rosetta-cache images load;
- the marker before `scCreateSystemServiceVersion` is reached;
- `scCreateSystemServiceVersion` returns normally;
- the returned `LaunchApplicationServices` port is exactly zero;
- `SessionGetInfo` is never called;
- no crash/core diagnostic is generated;
- the runner reports `RESULT: SYSTEMSERVICE_ZERO_PORT`;
- kernel, private dyld, system dyld, Rosetta cache, and executable identities remain unchanged.

The native syscall-295 safety probe still passes.

Therefore the immediate failure is CarbonCore/CoreServices system-service acquisition, not Process Manager, not the later LaunchServices InitializeProcessesServices transaction, and not the Security `SessionGetInfo` call.

## Static boundary to resolve next

The previous transport audit showed that `scCreateSystemServiceVersion` on Snow Leopard PPC and Lion native CarbonCore both enter an internal:

`SCSession::findOrCreateService(...)`

path.

At the exported API level, a null return can result when the CarbonCore session state is unusable or when `findOrCreateService` fails to produce a service object.

The earlier report did not disassemble that internal client/session family in detail.

The new audit therefore expands CarbonCore coverage around:

- `scCreateSystemServiceVersion`;
- `SCSession::findOrCreateService`;
- `SCSession` internals;
- `SCClientSession`;
- `SCServerSession`;
- internal status helpers;
- reconnect/server-loss helpers;
- bootstrap/Mach-port imports used by those paths;
- diagnostics for coreservicesd check-in, service lookup, bootstrap registration, reconnect, and version negotiation.

The important comparison is:

- Snow Leopard PPC CarbonCore: this is the guest implementation actually executed under Rosetta on Lion;
- Snow Leopard native slices: control/reference behavior;
- Lion i386/x86_64 CarbonCore: native Lion client/server semantics.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-systemservice-client-internals.py
docs/process-manager-systemservice-client-internals-audit.md
```

The analyzer is Python-2-compatible and read-only.

It records:

- OS/build and PowerPC architecture handler;
- active coreservicesd/pbs launchd state;
- coreservicesd binary identity and architecture list;
- the coreservicesd LaunchDaemon/Mach-service metadata;
- CarbonCore full-file and architecture-slice hashes;
- architecture-specific symbol/import inventories;
- full static windows matching the system-service client/session family;
- mapped diagnostics and service-name cstrings;
- an explicit `RESULT: PASS` validation gate.

## Safety constraints

For this audit:

- do not launch the PPC pre-dispatch probe again;
- do not launch a Process Manager application;
- do not call `scCreateSystemServiceVersion` from custom code;
- do not call `SessionGetInfo`;
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
scripts/audit-process-manager-systemservice-client-internals.py
docs/process-manager-systemservice-client-internals-audit.md
```

No kernel rebuild or reboot is part of this stage.

## Phase B — Snow Leopard internals audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-systemservice-client-internals.py \
  ./process-manager-systemservice-client-internals-snowleopard.txt
```

Require:

```text
Created: ./process-manager-systemservice-client-internals-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return the report unchanged.

## Phase C — Lion internals audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-systemservice-client-internals.py \
  ./payload/process-manager-systemservice-client-internals-lion.txt
```

Require:

```text
Created: ./payload/process-manager-systemservice-client-internals-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop. Do not compensate by rerunning the PPC preflight.

## Phase D — stop and return evidence

Return:

```text
process-manager-systemservice-client-internals-snowleopard.txt
process-manager-systemservice-client-internals-lion.txt
```

Keep the completed pre-dispatch logs available.

No Apple framework binary should be uploaded.

## Decision gate

### A. Legacy PPC client check-in/service protocol differs from Lion

If the Snow Leopard PPC `SCClientSession` / `SCSession::findOrCreateService` path uses a materially different bootstrap/check-in request, service version contract, or returned service-object layout from Lion's native path, localize that exact difference.

The next experiment would then be limited to the specific CoreServices service-acquisition transaction.

### B. CarbonCore session status becomes unusable before service lookup

If the static control flow shows that the null port can be returned before `findOrCreateService` because the CarbonCore session state is outside its usable states, the next diagnostic should target that state initialization only.

Do not bypass the state gate.

### C. Static client/service paths are materially equivalent

If Snow Leopard PPC and Lion native service-acquisition paths remain structurally equivalent through check-in and service creation, static analysis has reached its useful limit.

Only then prepare a minimal one-shot diagnostic that distinguishes:

1. coreservicesd bootstrap/check-in failure;
2. successful daemon connection but service lookup/version failure;
3. service-object creation with an unusable returned port.

That diagnostic must still stop before Process Manager and `SessionGetInfo`.

## Current interpretation to preserve

The latest live result is a successful localization, not a regression.

The PPC process executes correctly far enough to load its Rosetta-cache frameworks and call CarbonCore. The CarbonCore API returns normally, but returns no `LaunchApplicationServices` service port.

The Security-session hypothesis remains relevant only after CoreServices service acquisition succeeds. It was not reached in the Lion pre-dispatch run.

The syscall-295/XNU boundary remains closed and healthy. No additional XNU change is indicated.

## Non-goals

This audit does not:

- acquire a service port;
- bypass CarbonCore state checks;
- call Security session APIs;
- call LaunchServices process-services APIs;
- call Process Manager;
- patch a framework or daemon;
- modify Rosetta or XNU.

It is a read-only differential audit of the exact CarbonCore client/session machinery now proven to be the immediate failing layer.
