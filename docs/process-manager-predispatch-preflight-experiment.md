# Process Manager pre-dispatch primitive experiment

## Objective

Dynamically test the two exact user-space prerequisites that occur before LaunchServices sends the Process Manager InitializeProcessesServices request, without calling Process Manager itself.

The completed system-service transport audit found one material implementation change that static comparison cannot resolve:

- Snow Leopard PPC `SessionGetInfo` calls the legacy SecurityServer `ClientSession::getSessionInfo` path;
- Lion i386 `SessionGetInfo` instead reads session state through `CommonCriteria::AuditInfo`.

Because the translated Lion PPC process uses the restored Snow Leopard PPC Security image from the validated Rosetta shared cache, it will execute the legacy Snow Leopard Security client path against Lion's native host security/session environment. That is now a concrete cross-version compatibility risk.

At the same time, the CarbonCore `scCreateSystemServiceVersion` entry point remains semantically similar at the top level but reaches an internal `SCSession::findOrCreateService` implementation that the previous audit did not fully exercise dynamically.

The safest next step is therefore a single PPC command-line preflight that stops before LaunchServices Process Manager initialization.

## Why the probe order matters

`SetupCoreApplicationServicesCommunicationPort()` first obtains the CoreServices system-service endpoint and only then resolves the current security session before sending `_LSDoInitializeProcessesServices`.

The probe follows that same order:

1. call `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)`;
2. require a nonzero returned Mach port;
3. call `SessionGetInfo(callerSecuritySession, ...)`;
4. require `noErr` and a nonzero security-session ID;
5. exit immediately.

It does not call `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, `_LSDoInitializeProcessesServices`, foreground/window APIs, or an event loop.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-predispatch-preflight.c
scripts/build-ppc-process-manager-predispatch-preflight-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-predispatch-preflight-control.sh
scripts/run-lion-ppc-process-manager-predispatch-preflight.sh
docs/process-manager-predispatch-preflight-experiment.md
```

No Apple proprietary binary is committed.

The PPC executable is built on Snow Leopard and patched to use the already validated private guest dyld:

```text
/usr/oah/dyld
```

The Lion run uses the validated Snow Leopard Rosetta shared cache with the already established per-process cache-validation bypass.

The private LaunchServices PPC-admission patch is not required for this experiment because the probe is a command-line PPC executable and does not launch through Lion LaunchServices.

## Safety constraints

For this experiment:

- perform one Snow Leopard positive control before Lion;
- perform exactly one Lion PPC pre-dispatch launch;
- do not launch any Process Manager GUI test application;
- do not call any Process Manager identity API;
- do not call `_LSDoInitializeProcessesServices` directly;
- do not use `SCDontUseServer`;
- do not perform a custom bootstrap lookup;
- do not change security-session state;
- do not restart, replace, suspend, or signal securityd, coreservicesd, pbs, WindowServer, or launchd jobs;
- do not patch CarbonCore, Security, LaunchServices, HIServices, or coreservicesd;
- do not install or broaden the private LaunchServices PPC-admission patch;
- do not modify the LaunchServices database;
- do not change the Rosetta cache, Rosetta shims, private dyld, or system dyld;
- do not transplant Snow Leopard frameworks or daemons;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, DYLD interposition, or live code injection.

The returned CoreServices send right is deallocated before a normal successful exit. No service or framework is modified.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this experiment.

## Phase B — build the PPC preflight on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-predispatch-preflight-on-snowleopard.sh \
  ./ppc-process-manager-predispatch-private-dyld
```

Expected outputs:

```text
ppc-process-manager-predispatch-private-dyld
ppc-process-manager-predispatch-private-dyld.info.txt
ppc-process-manager-predispatch-private-dyld.sha256
```

Require:

- 32-bit PPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- CoreServices umbrella dependency;
- Security dependency.

On Snow Leopard, do not link the CarbonCore subframework binary directly. The system linker requires clients to link the `CoreServices.framework` umbrella; CarbonCore's exported implementation is reached through that umbrella/re-export relationship.

## Phase B harness correction

The first attempted Phase B build failed before producing a PPC executable. The compiler itself was present and was invoked successfully; the failure came from the build harness passing the CarbonCore subframework binary directly to the linker. Snow Leopard's linker rejects that form and requires clients to link the CoreServices umbrella framework instead.

The corrected builder now links with the CoreServices umbrella plus Security, while retaining the explicit `scCreateSystemServiceVersion` declaration in the probe source. The build validator and both Snow Leopard/Lion runners now require the CoreServices umbrella dependency rather than a direct CarbonCore load command. The Lion runtime provenance check still verifies that CarbonCore and Security are present in the validated Rosetta shared-cache map, because those are the actual implementation images used by the translated PPC process.

This was a build-harness defect only. No PPC pre-dispatch behavior was exercised by the failed attempt, so none of the experiment's runtime conclusions or decision gates change.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-predispatch-preflight-control.sh \
  ./ppc-process-manager-predispatch-private-dyld \
  ./ppc-process-manager-predispatch-private-dyld.sha256 \
  ./ppc-process-manager-predispatch-snowleopard-control.log
```

Require:

```text
PM_PREDISPATCH_MILESTONE:M02_AFTER_scCreateSystemServiceVersion
PM_PREDISPATCH_STATUS:SessionGetInfo=0
PM_PREDISPATCH_MILESTONE:M04_AFTER_SessionGetInfo
PM_PREDISPATCH_RESULT:PREDISPATCH_PRIMITIVES_PASS
RESULT: PASS
```

Also verify that the reported `LaunchApplicationServices` port is nonzero.

If the Snow Leopard control fails, stop and return the log. Do not run Lion.

## Phase D — transfer the exact control artifact to Lion

Transfer privately:

```text
ppc-process-manager-predispatch-private-dyld
ppc-process-manager-predispatch-private-dyld.info.txt
ppc-process-manager-predispatch-private-dyld.sha256
ppc-process-manager-predispatch-snowleopard-control.log
```

Place the executable and SHA sidecar in the Lion runtime payload directory or pass their paths explicitly to the runner.

Do not rebuild the PPC executable on Lion.

## Phase E — repeat the native Lion safety gates

Use the same validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

The currently validated kernel SHA-256 is:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Run the existing commpage probe and require `RESULT: PASS`.

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-predispatch-preflight.log"
```

Require the existing syscall-295 PASS result.

Do not continue if either native safety gate fails.

## Phase F — run the single Lion PPC pre-dispatch preflight

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-predispatch-preflight.sh
```

The runner verifies:

- Lion 10.7.5;
- the validated kernel hash;
- the PowerPC architecture handler;
- translator identity;
- exact PPC executable identity;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- private dyld identity;
- Rosetta cache/map identity;
- CarbonCore and Security membership in the Rosetta cache map.

It then launches the PPC executable once with:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

and records every pre-dispatch milestone plus any new crash/core diagnostic.

Do not rerun the Lion probe before the result is reviewed.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-predispatch-private-dyld.info.txt
ppc-process-manager-predispatch-private-dyld.sha256
ppc-process-manager-predispatch-snowleopard-control.log
syscall295-probe-process-manager-predispatch-preflight.log
lion-ppc-process-manager-predispatch-preflight.log
lion-ppc-process-manager-predispatch-preflight.raw.log
```

Also return every new crash report or core listed by the Lion runner.

If the raw log is empty, report that fact; an empty file does not need to be uploaded.

## Result interpretation

### `SYSTEMSERVICE_ABORT_OR_CRASH`

The PPC process entered `scCreateSystemServiceVersion` but did not return.

The next investigation target is CarbonCore `SCSession::findOrCreateService` and its old-client/native-Lion coreservicesd transport. Do not move to Security or Process Manager.

### `SYSTEMSERVICE_ZERO_PORT`

`scCreateSystemServiceVersion` returned but did not provide a usable `LaunchApplicationServices` service port.

The next target is still CarbonCore service creation/version negotiation. Preserve the exact raw log and do not force a port or use `SCDontUseServer`.

### `SESSIONGETINFO_ABORT_OR_CRASH`

CoreServices service acquisition succeeded, but the legacy Snow Leopard PPC `SessionGetInfo` path did not return on Lion.

This directly validates the Security session compatibility boundary suggested by the static audit. The next step would be a narrow SecurityServer/session protocol audit, not a Process Manager patch.

### `SESSIONGETINFO_ERROR`

`SessionGetInfo` returned an OSStatus on Lion. Preserve the exact status. That status becomes the next localization target.

### `SESSIONGETINFO_ZERO_SESSION`

`SessionGetInfo` returned `noErr` but no usable session ID. Treat that as invalid session state. Do not patch LaunchServices to accept it.

### `PREDISPATCH_PRIMITIVES_PASS`

Both exact prerequisites succeeded under translated PPC on Lion.

That would rule out both CarbonCore system-service acquisition and `SessionGetInfo` as the immediate failure. The next dynamic boundary would then be the LaunchServices `_LSDoInitializeProcessesServices` request/result itself, still before any Process Manager identity API.

### `PRE_MAIN_OR_UNCLASSIFIED_FAILURE`

The probe failed before the expected primitive milestones or produced an unexpected result. Preserve all diagnostics and stop.

## Static result that motivates this experiment

The completed audit established:

- identical validated Rosetta cache/map identities on Snow Leopard and Lion;
- CarbonCore and Security are both members of that Rosetta cache;
- the same `com.apple.CoreServices.coreservicesd` launchd Mach-service name exists on both systems;
- Snow Leopard PPC and Lion native CarbonCore both export `scCreateSystemServiceVersion` and route it through `SCSession::findOrCreateService`;
- Snow Leopard PPC `SessionGetInfo` uses `SecurityServer::ClientSession::getSessionInfo`;
- Lion i386 `SessionGetInfo` instead uses `CommonCriteria::AuditInfo::get`.

The Security change is material because a translated PPC process on Lion executes the restored Snow Leopard PPC Security client rather than Lion's native i386 implementation.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- call Process Manager;
- test foreground/window behavior;
- bypass an abort;
- substitute Lion's native Security implementation into the PPC process;
- force a CoreServices port;
- invoke the direct-function `SCDontUseServer` path;
- patch a framework or daemon;
- modify Rosetta or XNU.

It is a single behavioral discriminator for the two prerequisites immediately below the already localized LaunchServices process-dispatch boundary.


## Observed result — CoreServices service acquisition returns a null port on Lion

The completed Snow Leopard/Lion pre-dispatch experiment resolves the next decision gate.

The exact PPC executable passes on Snow Leopard: `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)` returns a nonzero port, `SessionGetInfo` returns `noErr`, and the control reaches `PREDISPATCH_PRIMITIVES_PASS`.

On Lion, the same hashed PPC executable reaches `main()` and the marker before `scCreateSystemServiceVersion`. The CarbonCore call returns normally, but the returned `LaunchApplicationServices` port is exactly zero. The probe therefore exits with:

```text
RESULT: SYSTEMSERVICE_ZERO_PORT
```

`SessionGetInfo` is never reached. No new crash/core is generated, the syscall-295 native preflight still passes, and all protected kernel/runtime hashes remain unchanged.

This moves the immediate failure boundary below LaunchServices Process Manager initialization and before Security session lookup.

The leading target is now CarbonCore's internal service-client path, particularly `SCSession::findOrCreateService`, session-status initialization, and the `SCClientSession` check-in/service negotiation with coreservicesd.

Do not repeat the PPC preflight yet.

The authoritative next stage is the read-only differential audit in:

```text
docs/process-manager-systemservice-client-internals-audit.md
scripts/audit-process-manager-systemservice-client-internals.py
```

That audit expands static coverage around the internal CarbonCore client/session machinery before any bootstrap lookup, state bypass, or live instrumentation is attempted.
