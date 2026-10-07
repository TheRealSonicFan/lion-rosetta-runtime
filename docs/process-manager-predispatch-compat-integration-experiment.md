# Process Manager pre-dispatch compatibility integration experiment

## Objective

Retest the original pre-dispatch primitive sequence now that the two proven CoreServices transport mismatches are corrected process-locally.

The completed dual CoreServices integration experiment has changed the state of the investigation materially:

- the Lion-format UUID-expanded coreservicesd bootstrap lookup succeeds inside unmodified Snow Leopard PPC CarbonCore;
- the exact legacy Snow Leopard PPC `ServerCheckin` request is recognized and adapted to Lion's native simple `0x18` request;
- Lion returns the expected `0x34` complex ServerCheckin reply with a nonzero session port;
- CarbonCore then returns a nonzero `LaunchApplicationServices` service port;
- CarbonCore exposes a nonzero server-checkin port and process options remain zero;
- the stage exits normally with `RESULT: CORESERVICES_COMPAT_SYSTEMSERVICE_PASS`.

This also proves that CarbonCore's existing Snow Leopard PPC `FindService("LaunchApplicationServices", 0x00010000,...)` transaction works against Lion without another adapter.

The next unresolved prerequisite is therefore the second half of the original pre-dispatch probe:

> Does the restored Snow Leopard PPC Security `SessionGetInfo(callerSecuritySession,...)` path work on Lion once CoreServices system-service acquisition is no longer blocking it?

This experiment answers only that question.

## Why this stage reuses the original pre-dispatch subject

The existing subject already executes the correct prerequisite order:

1. `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)`;
2. require a nonzero service port;
3. `SessionGetInfo(callerSecuritySession, ...)`;
4. require `noErr` and a nonzero security-session ID;
5. exit.

The first operation previously returned zero on Lion, so `SessionGetInfo` was never reached.

The dual CoreServices integration pass now proves that the first operation can succeed when only the two confirmed bootstrap/ServerCheckin request-shape differences are adapted. Therefore the same pre-dispatch subject is the narrowest useful next discriminator.

No Process Manager API and no LaunchServices `_LSDoInitializeProcessesServices` call is added.

## Security context to preserve

The earlier static transport audit found a material Security implementation split:

- Snow Leopard PPC `SessionGetInfo` reaches `SecurityServer::ClientSession::getSessionInfo` through the legacy Security client;
- Lion native i386 `SessionGetInfo` uses `CommonCriteria::AuditInfo::get` instead.

A translated PPC process on Lion executes the restored Snow Leopard PPC Security image from the validated Rosetta cache, not Lion's native i386 Security implementation.

That difference remains unresolved dynamically.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-predispatch-preflight.c
tests/ppc-process-manager-coreservices-compat-interposer.c
scripts/build-ppc-process-manager-predispatch-preflight-on-snowleopard.sh
scripts/build-ppc-process-manager-coreservices-compat-interposer-on-snowleopard.sh
scripts/build-ppc-process-manager-predispatch-compat-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-predispatch-compat-integration-control.sh
scripts/run-lion-ppc-process-manager-predispatch-compat-integration.sh
docs/process-manager-predispatch-compat-integration-experiment.md
```

The compatibility build ID remains:

```text
dual-bootstrap-servercheckin-v3
```

No Apple binary is modified or committed.

## Safety constraints

For this experiment:

- build all PPC artifacts only on Snow Leopard;
- run one Snow Leopard pass-through positive control before Lion;
- transfer the exact hashed PPC executable and interposer to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- perform exactly one Lion PPC pre-dispatch launch;
- use the v3 CoreServices interposer only through process-local `DYLD_INSERT_LIBRARIES`;
- adapt at most one exact coreservicesd bootstrap lookup and one exact legacy ServerCheckin transaction;
- pass all non-target `bootstrap_look_up2` and `mach_msg` calls to their original implementations;
- do not patch or interpose `SessionGetInfo`;
- do not alter Security session state;
- do not call `_LSDoInitializeProcessesServices`;
- do not call `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, or another Process Manager API;
- do not launch the Process Manager GUI application;
- do not use `SCDontUseServer`;
- do not install the interposer system-wide;
- do not patch CarbonCore, Security, LaunchServices, HIServices, launchd, or coreservicesd;
- do not restart, signal, suspend, or replace securityd, coreservicesd, pbs, WindowServer, or launchd jobs;
- do not modify the Rosetta cache, private dyld, system dyld, LaunchServices database, or XNU;
- do not use GDB, DTrace, dtruss, or any additional live injection.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the prepared files listed above.

On Lion also update XNU:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the PPC subject and v3 interposer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-predispatch-compat-integration-on-snowleopard.sh \
  ./ppc-process-manager-predispatch-compat-private-dyld \
  ./ppc-process-manager-coreservices-compat-interposer.dylib
```

Expected outputs:

```text
ppc-process-manager-predispatch-compat-private-dyld
ppc-process-manager-predispatch-compat-private-dyld.info.txt
ppc-process-manager-predispatch-compat-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
```

Require:

- both artifacts are 32-bit PPC;
- the executable uses `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- the executable links the CoreServices umbrella and Security;
- the interposer contains exactly two PPC `__DATA,__interpose` tuples;
- the interposer build ID is `dual-bootstrap-servercheckin-v3`;
- the interposer references `bootstrap_look_up2`, `mach_msg`, and `mig_get_reply_port`;
- the interposer does not import `dlsym`.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control with pass-through compatibility layer

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-predispatch-compat-integration-control.sh \
  ./ppc-process-manager-predispatch-compat-private-dyld \
  ./ppc-process-manager-predispatch-compat-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-predispatch-compat-snowleopard-control.log
```

Require all of:

```text
PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=1 mode=passthrough
PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=0 ... servicePort=nonzero
PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=1 mode=passthrough
PM_CORESERVICES_COMPAT_SERVERCHECKIN_PASSTHROUGH:bits=0x80001513 send=0x00000028 recv=0x0000003c
PM_PREDISPATCH_PORT:LaunchApplicationServices=nonzero
PM_PREDISPATCH_STATUS:SessionGetInfo=0
PM_PREDISPATCH_SESSION:ID=nonzero ...
PM_PREDISPATCH_RESULT:PREDISPATCH_PRIMITIVES_PASS
RESULT: PASS
```

This control proves that the same two-tuple interposer leaves Snow Leopard's native CoreServices and Security behavior unchanged.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-predispatch-compat-private-dyld
ppc-process-manager-predispatch-compat-private-dyld.info.txt
ppc-process-manager-predispatch-compat-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-predispatch-compat-snowleopard-control.log
```

Place the executable/interposer and SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild either artifact on Lion.

## Phase E — repeat Lion native safety gates

Set the validated kernel identity:

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
  "$XNU_SRC/syscall295-probe-process-manager-predispatch-compat-integration.log"
```

Require the established EBADF/no-SIGSYS PASS.

Do not continue if either native safety gate fails.

## Phase F — run one Lion pre-dispatch subject with the proven CoreServices adapter

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-predispatch-compat-integration.sh
```

The runner requires:

1. the validated Lion/kernel/translator/Rosetta identities;
2. the exact PPC executable and interposer hashes;
3. the v3 two-tuple interposer identity;
4. one successful adapted coreservicesd bootstrap lookup;
5. one successful adapted ServerCheckin reply;
6. a nonzero `LaunchApplicationServices` port from unmodified CarbonCore;
7. the exact `SessionGetInfo` result.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
lion-ppc-process-manager-predispatch-compat-integration.log
lion-ppc-process-manager-predispatch-compat-integration.raw.log
syscall295-probe-process-manager-predispatch-compat-integration.log
ppc-process-manager-predispatch-compat-snowleopard-control.log
ppc-process-manager-predispatch-compat-private-dyld.info.txt
ppc-process-manager-predispatch-compat-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
```

Also return every new crash report or core listed by the Lion runner.

## Result interpretation

### `PREDISPATCH_COMPAT_PRIMITIVES_PASS`

The proven CoreServices adaptations restore system-service acquisition and the untouched Snow Leopard PPC `SessionGetInfo` path also succeeds on Lion with a nonzero session ID.

This rules out Security session lookup as the next failure.

Stop there.

The next stage would test the untouched LaunchServices `_LSDoInitializeProcessesServices` request/result boundary while keeping the same process-local CoreServices adapter, still before any Process Manager identity API.

### `SESSIONGETINFO_ABORT_OR_CRASH`

CoreServices acquisition is confirmed working, but the restored Snow Leopard PPC `SessionGetInfo` path does not return.

This validates the Security compatibility boundary suggested by the earlier static audit.

The next stage would be a narrow SecurityServer/session protocol audit. Do not patch Process Manager or LaunchServices.

### `SESSIONGETINFO_ERROR`

`SessionGetInfo` returned an explicit OSStatus.

Preserve the exact numeric status. It becomes the next localization target.

### `SESSIONGETINFO_ZERO_SESSION`

`SessionGetInfo` returned `noErr` but no usable session ID.

Treat that as invalid security-session state. Do not force a session or patch LaunchServices to accept it.

### `PREDISPATCH_COMPAT_SYSTEMSERVICE_*` or CoreServices adapter failure

The previously proven CoreServices recovery did not reproduce in the pre-dispatch subject.

Preserve the complete raw log and stop before interpreting Security.

### pre-main/unclassified failure

Preserve all diagnostics and stop.

## Current interpretation to preserve

The completed dual CoreServices integration result closes the CarbonCore service-client boundary:

```text
bootstrap UUID adaptation -> PASS
ServerCheckin request adaptation -> PASS
CarbonCore check-in state -> nonzero
FindService("LaunchApplicationServices") -> nonzero
RESULT: CORESERVICES_COMPAT_SYSTEMSERVICE_PASS
```

No additional `FindService` adapter is indicated.

The next unresolved primitive is the restored Snow Leopard PPC Security `SessionGetInfo` path.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- modify the successful v3 CoreServices adaptation;
- patch or replace Security;
- call LaunchServices process-services initialization;
- call Process Manager;
- launch a GUI application;
- establish a permanent compatibility layer;
- modify Rosetta or XNU.

It is one controlled pre-dispatch discriminator that advances from the now-closed CarbonCore boundary to the previously unreachable Security-session boundary.


## Observed result — CoreServices passes; SessionGetInfo returns status 1

Phase F reached the intended Security boundary cleanly.

The proven v3 CoreServices compatibility layer reproduced its prior Lion success:

- bootstrap lookup adaptation returned a nonzero coreservicesd port;
- ServerCheckin adaptation returned a nonzero session port;
- unmodified PPC CarbonCore returned a nonzero `LaunchApplicationServices` port.

The untouched Snow Leopard PPC Security call then returned normally:

```text
PM_PREDISPATCH_MILESTONE:M03_BEFORE_SessionGetInfo
PM_PREDISPATCH_STATUS:SessionGetInfo=1
PM_PREDISPATCH_SESSION:ID=0x00000000 ATTRS=0x00000000
PM_PREDISPATCH_MILESTONE:M04_AFTER_SessionGetInfo
PM_PREDISPATCH_RESULT:SESSIONGETINFO_ERROR
```

There was no crash/core diagnostic. The executable, interposer, Rosetta cache, private/system dyld, and kernel hashes remained unchanged, and the native syscall-295 safety probe remained a clean EBADF/no-SIGSYS PASS.

The exact Snow Leopard control returned `SessionGetInfo=0`, a nonzero session ID, nonzero attributes, and `RESULT: PASS`.

Status `1` is especially useful. Historical Snow Leopard-era Security code routes `SessionGetInfo` through `SecurityServer::ClientSession::getSessionInfo`, and its error bridge maps an otherwise unhandled Mach transport exception to the bare `CSSM_ERRCODE_INTERNAL_ERROR` value `1`. Historical later SecurityServer protocol source preserves the same routine slot only as `skip; // was getSessionInfo -- now kept by the kernel`, while the newer native Security client uses `CommonCriteria::AuditInfo` rather than securityd for this query.

This localizes the next defect to the legacy Snow Leopard Security first-use/session transport versus Lion's newer kernel-backed session mechanism. The removed legacy `getSessionInfo` RPC is the leading candidate, but the first call also performs SecurityServer lookup/verification/setup, so the exact failing substep is not yet closed.

The live run did **not** expose the underlying Mach/MIG return code, so do not label it `MIG_BAD_ID` yet.

The authoritative next stage is the read-only shipped-binary audit in:

```text
docs/process-manager-security-session-protocol-audit.md
```

Do not rerun Phase F, do not patch Security, and do not proceed to LaunchServices process-services initialization until that audit is reviewed.
