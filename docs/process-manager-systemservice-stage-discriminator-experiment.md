# Process Manager CoreServices system-service stage discriminator

## Objective

Distinguish the two remaining live sub-boundaries behind Lion's zero `LaunchApplicationServices` port without calling Security, LaunchServices process-services initialization, or Process Manager.

The completed RPC protocol audit shows that the Snow Leopard PPC guest and Lion's native CarbonCore use compatible CoreServices service RPC contracts at the wire level.

The remaining question is behavioral:

1. does the translated PPC CarbonCore fail to establish a usable coreservicesd client/check-in session; or
2. does check-in succeed, after which the `FindService("LaunchApplicationServices", 0x00010000,...)` transaction fails?

This experiment answers only that question.

## Evidence from the completed RPC protocol audit

Both RPC protocol reports completed with `RESULT: PASS`.

### ServerCheckin

The Snow Leopard PPC client sends the legacy complex `ServerCheckin` form:

- request ID `0x2710`;
- send size `0x28`;
- receive size `0x3c`;
- expected reply ID `0x2774`;
- one port descriptor in the complex request.

Lion's native i386 client uses the newer simple `0x18` request with the same request ID, receive size, and reply ID.

That earlier interpretation is superseded by the later integration re-read: Lion's i386 `__XServerCheckin` rejects complex requests and accepts only the simple `0x18` form before calling `__scserver_ServerCheckin`. Snow Leopard PPC's descriptor-bearing `0x28` request is therefore a real ServerCheckin protocol mismatch.

### FindService

Snow Leopard PPC and Lion i386 agree on the `FindService` client contract:

- request ID `0x2723`;
- send size `0x12c`;
- receive size `0x30`;
- expected reply ID `0x2787`;
- service name copied into a `0x100`-byte request field;
- transport failure and returned service-status failure are both rejected by `SCClientSession::createService`.

No static wire mismatch is therefore established.

### Lion connection-state behavior

Lion's native `connectToCoreServicesD()` makes the remaining control distinction explicit. Successful client check-in installs an `SCClientSession` and moves to the remote-client state. Failed check-in instead creates a local fallback `SCSession` and moves to a different state; `scCreateSystemServiceVersion` rejects that state before `SCSession::findOrCreateService`.

The translated PPC process executes the restored Snow Leopard PPC CarbonCore rather than Lion's native i386 CarbonCore, so a live discriminator is still required.

## Why the discriminator uses existing CarbonCore helpers

The Snow Leopard PPC CarbonCore exports:

```text
scGetServerCheckinPort
scGetProcessOptions
```

The static audit shows that `scGetServerCheckinPort()` obtains the already initialized system session and returns its server-checkin port field.

The probe resolves both helpers dynamically from the already loaded CarbonCore image. It does not patch or interpose anything.

Critically, it calls them only **after** the original:

```text
scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, ...)
```

has returned.

This preserves the setup order that produced `SYSTEMSERVICE_ZERO_PORT`; the helpers are diagnostic reads of the resulting CarbonCore state, not replacements for the failing call.

The returned check-in port is CarbonCore-owned and is never deallocated by the probe. A successfully returned `LaunchApplicationServices` service port is deallocated before exit.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-systemservice-stage-discriminator.c
scripts/build-ppc-process-manager-systemservice-stage-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-systemservice-stage-control.sh
scripts/run-lion-ppc-process-manager-systemservice-stage.sh
docs/process-manager-systemservice-stage-discriminator-experiment.md
```

The PPC executable is built on Snow Leopard and patched to use:

```text
/usr/oah/dyld
```

It links only the CoreServices umbrella framework. It does not link Security and does not call `SessionGetInfo`.

## Safety constraints

For this experiment:

- run one Snow Leopard positive control before Lion;
- run exactly one Lion PPC stage-discriminator launch;
- do not launch the earlier pre-dispatch probe again;
- do not launch a Process Manager GUI application;
- do not call `SessionGetInfo`;
- do not call `_LSDoInitializeProcessesServices`;
- do not call Process Manager identity APIs;
- do not use `SCDontUseServer`;
- do not perform a custom bootstrap lookup;
- do not call `ServerCheckin` or `FindService` directly;
- do not patch CarbonCore, Security, LaunchServices, HIServices, or coreservicesd;
- do not restart, suspend, replace, or signal coreservicesd, securityd, pbs, WindowServer, or launchd jobs;
- do not modify the Rosetta cache, private dyld, system dyld, or XNU;
- do not use GDB, DTrace, dtruss, DYLD interposition, or live code injection.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the five files listed above.

On Lion also update the XNU checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this experiment.

## Phase B — build the PPC discriminator on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-systemservice-stage-on-snowleopard.sh \
  ./ppc-process-manager-systemservice-stage-private-dyld
```

Expected outputs:

```text
ppc-process-manager-systemservice-stage-private-dyld
ppc-process-manager-systemservice-stage-private-dyld.info.txt
ppc-process-manager-systemservice-stage-private-dyld.sha256
```

Require:

- 32-bit PowerPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- CoreServices umbrella dependency.

If the build fails, stop and return the complete build output. Do not try to link CarbonCore directly.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-systemservice-stage-control.sh \
  ./ppc-process-manager-systemservice-stage-private-dyld \
  ./ppc-process-manager-systemservice-stage-private-dyld.sha256 \
  ./ppc-process-manager-systemservice-stage-snowleopard-control.log
```

Require:

```text
PM_SYSTEMSERVICE_STAGE_HELPER:scGetServerCheckinPort=FOUND
PM_SYSTEMSERVICE_STAGE_HELPER:scGetProcessOptions=FOUND
PM_SYSTEMSERVICE_STAGE_MILESTONE:M06_AFTER_scGetProcessOptions
PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS
RESULT: PASS
```

Also require both reported ports to be nonzero:

```text
PM_SYSTEMSERVICE_STAGE_SERVICE:port=...
PM_SYSTEMSERVICE_STAGE_CHECKIN:port=...
```

If the Snow Leopard control fails, stop. The private helper cannot be used as a Lion discriminator until the control proves its behavior.

## Phase D — transfer the exact control artifact to Lion

Transfer privately:

```text
ppc-process-manager-systemservice-stage-private-dyld
ppc-process-manager-systemservice-stage-private-dyld.info.txt
ppc-process-manager-systemservice-stage-private-dyld.sha256
ppc-process-manager-systemservice-stage-snowleopard-control.log
```

Place the executable and SHA sidecar in the Lion runtime `payload/` directory, or pass their paths explicitly.

Do not rebuild the PPC executable on Lion.

## Phase E — repeat the native Lion safety gates

Use the same validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

The validated kernel SHA-256 remains:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Run the established native commpage safety probe and require its existing `RESULT: PASS`.

Then run:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-systemservice-stage.log"
```

Require the existing syscall-295 PASS result.

Do not continue if either native safety gate fails.

## Phase F — run the single Lion PPC stage discriminator

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-systemservice-stage.sh
```

The runner verifies:

- Lion 10.7.5;
- validated kernel identity;
- PowerPC architecture handler;
- translator identity;
- exact PPC executable identity;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- private and system dyld identities;
- validated Rosetta cache/map identities;
- CarbonCore membership in the Rosetta cache map.

It then runs the PPC executable exactly once with:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

The probe first repeats the known `scCreateSystemServiceVersion` call. Only after that call returns does it query CarbonCore's existing server-checkin port and process options.

Do not rerun it before the result is reviewed.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-systemservice-stage-private-dyld.info.txt
ppc-process-manager-systemservice-stage-private-dyld.sha256
ppc-process-manager-systemservice-stage-snowleopard-control.log
syscall295-probe-process-manager-systemservice-stage.log
lion-ppc-process-manager-systemservice-stage.log
lion-ppc-process-manager-systemservice-stage.raw.log
```

Also return every new crash report or core listed by the Lion runner.

If the raw log is empty, report that fact; an empty file does not need to be uploaded.

## Result interpretation

### `CHECKIN_SESSION_UNAVAILABLE`

The original service-acquisition call returned zero and the already initialized CarbonCore system session has no server-checkin port.

This localizes the immediate failure before `FindService`: the guest PPC CarbonCore did not establish a usable coreservicesd client session.

The next investigation target would be the live `bootstrap_look_up2 -> ServerCheckin` boundary only.

Do not patch `FindService`, LaunchServices, or Security.

### `SERVICE_LOOKUP_FAILURE_AFTER_CHECKIN`

The original service-acquisition call returned zero, but CarbonCore has a nonzero server-checkin port.

That proves client check-in/session establishment succeeded.

The immediate target then becomes the `FindService("LaunchApplicationServices", 0x00010000,...)` transaction or its returned service-status handling.

### `SYSTEMSERVICE_STAGE_PASS`

Both the requested service port and the server-checkin port are nonzero on Lion.

That would contradict the prior zero-port result and must be treated as a changed runtime condition. Stop and compare the exact binary/hash/environment before proceeding.

### `PRIVATE_HELPER_UNAVAILABLE`

The exact Snow Leopard PPC CarbonCore loaded on Lion did not expose one of the two controlled diagnostic helpers to `dlsym`.

Do not substitute a raw address call. Preserve the logs and stop.

### abort/crash classifications

Any abort/crash before or during the helper reads is unexpected. Preserve all diagnostics and stop.

## Current interpretation to preserve

Static comparison no longer supports a generic "old PPC RPC format versus new Lion RPC format" explanation.

The Snow Leopard PPC `ServerCheckin` request is older and complex, and later live/static evidence shows Lion rejects that form in favor of its simple `0x18` request. The `FindService` wire constants still match directly.

The remaining problem is therefore runtime state/transaction behavior, not another XNU ABI and not yet Security or Process Manager.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- perform a custom bootstrap lookup;
- issue `ServerCheckin` directly;
- issue `FindService` directly;
- force or synthesize a CoreServices service port;
- call Security;
- call LaunchServices process-services initialization;
- call Process Manager;
- patch any framework or daemon;
- modify Rosetta or XNU.

It is a single post-call state discriminator for the already proven `SYSTEMSERVICE_ZERO_PORT` boundary.


## Observed result — CarbonCore never establishes a usable client/check-in session on Lion

The completed Snow Leopard/Lion stage discriminator resolves the previous two-way ambiguity.

The exact PPC subject has SHA-256:

```text
aef485ca23cdc4b7a235add955835926cf6091c9fabcf6a1335b33ec0be61978
```

On Snow Leopard 10.6.8, the positive control returns a nonzero `LaunchApplicationServices` port, a nonzero CarbonCore server-checkin port, process options `0x00000000`, and `RESULT: PASS`.

On Lion 10.7.5, the same subject:

- returns normally from `scCreateSystemServiceVersion`;
- reports service port `0x00000000`;
- reports server-checkin port `0x00000000`;
- reports process options `0x00000002`;
- produces no crash/core diagnostic;
- preserves the validated kernel, private dyld, system dyld, Rosetta cache, and probe hashes;
- ends with `RESULT: CHECKIN_SESSION_UNAVAILABLE`.

The zero server-checkin port is decisive: the guest PPC CarbonCore did not establish a usable coreservicesd client session, so the immediate failure is before `FindService`.

The process-options value independently supports the same direction. Snow Leopard PPC `scGetProcessOptions` sets bit `0x2` when its internal CoreServices status is 1 or 3. The bit does not uniquely identify which of those states is active, so it must not be used as a stronger claim than the direct zero-port observation.

The next live boundary is now only:

```text
bootstrap_look_up2 -> __scclient_ServerCheckin
```

The authoritative next experiment is:

```text
docs/process-manager-bootstrap-lookup-discriminator-experiment.md
```

That experiment tests only the bootstrap half of the boundary using the exact service name, target PID, and 64-bit flags value recovered from the Snow Leopard PPC CarbonCore callsite. It does not call `ServerCheckin` in the same run.

Do not rerun this stage discriminator, proceed to `FindService`, call Security/Process Manager, patch CarbonCore, or modify XNU before the bootstrap result is reviewed.
