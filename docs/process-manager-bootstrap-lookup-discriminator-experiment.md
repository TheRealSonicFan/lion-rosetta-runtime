# Process Manager coreservicesd bootstrap-lookup discriminator

## Objective

Resolve the remaining live boundary below CarbonCore client-session establishment after the guarded system-service stage discriminator returned:

```text
RESULT: CHECKIN_SESSION_UNAVAILABLE
```

The completed stage experiment established that the translated Snow Leopard PPC CarbonCore reaches and returns from:

```text
scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, ...)
```

but leaves both the requested service port and CarbonCore's existing server-checkin port at zero.

The next question is now narrower:

1. does the translated PPC process fail at the exact `bootstrap_look_up2` used to find `com.apple.CoreServices.coreservicesd`; or
2. does that bootstrap lookup succeed, making the subsequent legacy PPC `ServerCheckin` transaction the immediate failing boundary?

This experiment tests only the first item.

## Evidence from the completed stage discriminator

The exact PPC executable passed on Snow Leopard and failed deterministically on Lion.

On Snow Leopard:

- `LaunchApplicationServices` service port was nonzero;
- `scGetServerCheckinPort()` returned the same nonzero port;
- `scGetProcessOptions()` returned `0x00000000`;
- the control reported `RESULT: PASS`.

On Lion:

- `scCreateSystemServiceVersion` returned normally with service port zero;
- `scGetServerCheckinPort()` returned zero;
- `scGetProcessOptions()` returned `0x00000002`;
- no crash/core diagnostic was generated;
- protected hashes remained unchanged;
- the runner reported `RESULT: CHECKIN_SESSION_UNAVAILABLE`.

The Snow Leopard PPC `scGetProcessOptions` implementation sets option bit `0x2` when its internal CoreServices status is 1 or 3. That bit therefore corroborates an unusable/non-remote client state, but it does not by itself distinguish those two status values. The zero server-checkin port is the decisive evidence that no usable client session was established.

## Exact CarbonCore bootstrap call recovered statically

The completed RPC protocol audit shows that Snow Leopard PPC `SCClientSession::checkinWithServer` performs:

1. an `SCDontUseServer` environment check;
2. `getCheckinName()`;
3. `bootstrap_look_up2`;
4. only on success, `__scclient_ServerCheckin`.

The PPC call passes:

- the process `bootstrap_port`;
- service name from `getCheckinName()`;
- an output Mach port pointer;
- target PID `0`;
- 64-bit flags value `0x0000000000000008`.

The PPC `getCheckinName()` first checks the environment variable:

```text
CORESERVICESD_SERVICE_NAME
```

and otherwise defaults to:

```text
com.apple.CoreServices.coreservicesd
```

The new probe therefore requires both `CORESERVICESD_SERVICE_NAME` and `SCDontUseServer` to be unset and issues exactly one lookup using the default name and the same target/flags values.

The 64-bit width of the flags argument is intentional and required for the 32-bit PPC ABI: the recovered PPC call occupies the paired argument registers corresponding to a 64-bit final argument.

## Why this is the safest next live test

The probe does not call CarbonCore, Security, LaunchServices, Process Manager, `ServerCheckin`, or `FindService`.

It asks launchd's bootstrap namespace for the exact service endpoint CarbonCore asks for, records the return code and port, deallocates the returned send right if successful, and exits.

A successful lookup is not a CoreServices session registration. It only proves that the translated PPC task can reach the same bootstrap service name with the same `bootstrap_look_up2` contract.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-bootstrap-lookup-discriminator.c
scripts/build-ppc-process-manager-bootstrap-lookup-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-bootstrap-lookup-control.sh
scripts/run-lion-ppc-process-manager-bootstrap-lookup.sh
docs/process-manager-bootstrap-lookup-discriminator-experiment.md
```

No Apple proprietary binary is committed.

The PPC executable is built on Snow Leopard and patched to use:

```text
/usr/oah/dyld
```

It links only the normal system libraries required by the executable. It does not link CoreServices or Security.

## Safety constraints

For this experiment:

- perform one Snow Leopard positive control before Lion;
- perform exactly one Lion PPC bootstrap-lookup launch;
- do not rerun the previous system-service stage discriminator;
- do not call `scCreateSystemServiceVersion`;
- do not call `ServerCheckin`;
- do not call `FindService`;
- do not call `SessionGetInfo`;
- do not call LaunchServices process-services initialization;
- do not call Process Manager;
- do not set or change `CORESERVICESD_SERVICE_NAME`, `SCDontUseServer`, or other compatibility variables;
- do not restart, suspend, signal, or replace coreservicesd, launchd, securityd, pbs, or WindowServer;
- do not patch CarbonCore, LaunchServices, Security, HIServices, libSystem, or coreservicesd;
- do not modify Rosetta, the shared cache, private dyld, system dyld, or XNU;
- do not use GDB, DTrace, dtruss, DYLD interposition, or live injection.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the five files listed above.

On Lion also update XNU:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this experiment.

## Phase B — build the PPC lookup probe on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-bootstrap-lookup-on-snowleopard.sh \
  ./ppc-process-manager-bootstrap-lookup-private-dyld
```

Expected outputs:

```text
ppc-process-manager-bootstrap-lookup-private-dyld
ppc-process-manager-bootstrap-lookup-private-dyld.info.txt
ppc-process-manager-bootstrap-lookup-private-dyld.sha256
```

Require:

- 32-bit PowerPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up2` and `bootstrap_port`.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Before running, verify that neither variable is set in the shell:

```text
CORESERVICESD_SERVICE_NAME
SCDontUseServer
```

The control runner also enforces this.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-bootstrap-lookup-control.sh \
  ./ppc-process-manager-bootstrap-lookup-private-dyld \
  ./ppc-process-manager-bootstrap-lookup-private-dyld.sha256 \
  ./ppc-process-manager-bootstrap-lookup-snowleopard-control.log
```

Require:

```text
PM_BOOTSTRAP_LOOKUP_ENV:CORESERVICESD_SERVICE_NAME=UNSET
PM_BOOTSTRAP_LOOKUP_ENV:SCDontUseServer=UNSET
PM_BOOTSTRAP_LOOKUP_RETURN:kr=0 ...
PM_BOOTSTRAP_LOOKUP_RESULT:LOOKUP_PASS
PM_BOOTSTRAP_LOOKUP_MILESTONE:M03_SUCCESS
RESULT: PASS
```

Also require both the reported `bootstrap_port` and returned service port to be nonzero.

If the Snow Leopard control fails, stop. Do not run Lion.

## Phase D — transfer the exact control artifact to Lion

Transfer privately:

```text
ppc-process-manager-bootstrap-lookup-private-dyld
ppc-process-manager-bootstrap-lookup-private-dyld.info.txt
ppc-process-manager-bootstrap-lookup-private-dyld.sha256
ppc-process-manager-bootstrap-lookup-snowleopard-control.log
```

Place the executable and SHA sidecar in the Lion runtime `payload/` directory or pass their paths explicitly.

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

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-bootstrap-lookup.log"
```

Require the existing syscall-295 PASS result.

Do not continue if either native safety gate fails.

## Phase F — run the single Lion PPC bootstrap lookup

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-bootstrap-lookup.sh
```

The runner verifies:

- Lion 10.7.5;
- `CORESERVICESD_SERVICE_NAME` and `SCDontUseServer` are unset;
- validated kernel identity;
- PowerPC architecture handler;
- translator identity;
- exact PPC executable identity;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- private/system dyld identities;
- validated Rosetta cache/map identities;
- PPC libSystem membership in the Rosetta cache map.

It also records the current coreservicesd/pbs launchd state.

The executable is then launched exactly once with:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

Do not rerun it before the result is reviewed.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-bootstrap-lookup-private-dyld.info.txt
ppc-process-manager-bootstrap-lookup-private-dyld.sha256
ppc-process-manager-bootstrap-lookup-snowleopard-control.log
syscall295-probe-process-manager-bootstrap-lookup.log
lion-ppc-process-manager-bootstrap-lookup.log
lion-ppc-process-manager-bootstrap-lookup.raw.log
```

Also return every new crash report or core listed by the Lion runner.

## Result interpretation

### `BOOTSTRAP_LOOKUP_PASS`

The translated PPC task has a nonzero bootstrap port and can resolve:

```text
com.apple.CoreServices.coreservicesd
```

with the same `bootstrap_look_up2` target PID and flags used by Snow Leopard PPC CarbonCore.

This rules out the bootstrap lookup as the immediate cause of `CHECKIN_SESSION_UNAVAILABLE`.

The next boundary becomes only the legacy PPC `__scclient_ServerCheckin` transaction and its returned outputs/status. Stop before testing it.

### `BOOTSTRAP_LOOKUP_ERROR`

The translated PPC task has a bootstrap port, but the exact lookup returns a Mach/bootstrap error.

Preserve the numeric `kern_return_t` and returned port. That becomes the next localization target.

Do not proceed to `ServerCheckin`.

### `BOOTSTRAP_LOOKUP_ZERO_PORT`

The lookup returns success but no service port.

Treat this as an invalid bootstrap result and preserve the raw log. Do not synthesize or force a port.

### `BOOTSTRAP_PORT_NULL`

The translated PPC process itself has no usable `bootstrap_port` global.

This is earlier than service-name lookup and becomes the immediate boundary. Do not call `ServerCheckin`.

### `ENVIRONMENT_NOT_CLEAN`

One of the variables that changes CarbonCore's normal server/check-in behavior was already present.

Do not unset it inside the experiment. Correct the shell/session provenance first and repeat only after review.

### abort/crash classifications

Any abort/crash before the lookup returns is unexpected. Preserve diagnostics and stop.

## Current interpretation to preserve

The completed stage discriminator rules out `FindService` as the immediate observed failure: CarbonCore never established a usable client/check-in session.

The completed RPC audit shows that `FindService` wire constants align. A later re-read corrected the earlier ServerCheckin interpretation: Lion rejects Snow Leopard PPC's complex ServerCheckin request and expects its native simple form.

The next live discriminator is therefore exactly one bootstrap lookup. It must not issue `ServerCheckin` in the same run.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- initialize CarbonCore's system-service client;
- register a CoreServices client session;
- call `ServerCheckin`;
- call `FindService`;
- acquire `LaunchApplicationServices`;
- call Security;
- call LaunchServices process-services initialization;
- call Process Manager;
- patch or restart any service;
- modify Rosetta or XNU.

It is a one-shot discriminator of the bootstrap half of the already localized `bootstrap_look_up2 -> ServerCheckin` boundary.


## Observed result — Lion rejects the legacy PPC bootstrap lookup with MIG_BAD_ARGUMENTS

The completed discriminator resolves the next live boundary.

The exact PPC subject has SHA-256:

```text
6c1e9728fd3f30889217bb5bd5e55778cbcdc0a652e8739143d5512e068e2dbc
```

On Snow Leopard 10.6.8, the control reports a nonzero `bootstrap_port`, clean environment, `kr=0`, a nonzero returned service port, and `RESULT: PASS`.

On Lion 10.7.5, the exact same subject reports:

```text
bootstrap_port=nonzero
CORESERVICESD_SERVICE_NAME=UNSET
SCDontUseServer=UNSET
service=com.apple.CoreServices.coreservicesd
target_pid=0
flags=0x8
kr=-304 / 0xfffffed0
servicePort=0
RESULT: BOOTSTRAP_LOOKUP_ERROR
```

No crash/core was generated, and all protected hashes remained unchanged.

Darwin Mach/MIG defines `-304` as `MIG_BAD_ARGUMENTS`. This is not an ordinary unknown-service result.

Public Apple launchd sources for the exact baselines expose a concrete schema change beneath the stable `bootstrap_look_up2` API:

- Snow Leopard 10.6.8 / launchd-329.3.3 `vproc_mig_look_up2` carries target PID followed directly by 64-bit flags.
- Lion 10.7.5 / launchd-392.39 inserts an `instanceid : uuid_t` field between target PID and flags; Lion's `bootstrap_look_up2` internally routes through `bootstrap_look_up3` to supply that field.

The live `MIG_BAD_ARGUMENTS` result is directly consistent with Lion's generated MIG server rejecting the older Snow Leopard PPC request layout.

Before any protocol adapter is attempted, the shipped binaries must confirm the source-level schema evolution and exact request/reply sizes.

The authoritative next stage is therefore the read-only:

```text
docs/process-manager-bootstrap-protocol-audit.md
scripts/audit-process-manager-bootstrap-protocol.py
```

Do not rerun the bootstrap probe, call `ServerCheckin`, or patch libSystem/launchd before that binary audit is reviewed.
