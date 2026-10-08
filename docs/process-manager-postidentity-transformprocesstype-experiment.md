# Process Manager post-identity TransformProcessType experiment

## Objective

Test the first foreground-conversion boundary after the translated PPC process has already proved a usable Process Manager identity in both directions.

The completed post-identity round-trip experiment now proves on Lion that, with the accepted v5 CoreServices SessionInit adapter and v1 Security AuditInfo adapter:

```text
GetProcessForPID(getpid(), &psn) -> noErr + nonzero PSN
GetProcessPID(&psn, &pid)        -> noErr + pid == getpid()
```

The narrow next call is therefore:

```text
TransformProcessType(&psn, kProcessTransformToForegroundApplication)
```

The new subject re-proves all prior identity prerequisites, calls `TransformProcessType` exactly once with the returned PSN, records the OSStatus, and exits immediately.

It does not call `GetCurrentProcess`, `SetFrontProcess`, `GetFrontProcess`, create a window, show a window, or enter an event loop.

## Evidence entering this stage

The accepted Lion post-identity run used:

```text
post-identity subject SHA-256:
473e3dae6ee9e73ecb7f63bf2f7357bdf9fb63c9d7c555dd8e2bc0d2dcb1388b

CoreServices adapter:
dual-bootstrap-servercheckin-sessioninit-v5
2b2aa88d8dda14323066c92ec0f98181e6e71cce4686a8f43dacc4dbb8e55057

Security adapter:
security-session-auditinfo-api-v1
9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51
```

Lion completed the exact v5 SessionInit repair, returned from `GetProcessForPID` with status 0 and PSN `0x00000000:0x000bc0bc`, then returned from `GetProcessPID` with status 0 and exact PID round-trip `21863 -> 21863`. There was no second exact SessionInit call, no new crash/core diagnostic, and protected hashes were unchanged. The runner ended:

```text
RESULT: POSTIDENTITY_GETPROCESSPID_ROUNDTRIP_PASS
```

The Snow Leopard direct-execution control likewise returned status 0 from both identity calls and round-tripped its PID exactly with one observed SessionInit transaction.

The Lion identity path still emitted non-fatal WindowServer/default-connection diagnostics during registration. Those diagnostics did not prevent either Process Manager identity API from succeeding. They become relevant only because this stage is the first call that changes process foreground type.

For that reason, this experiment keeps the same direct-execution model first and makes the Snow Leopard `TransformProcessType` result a hard gate. If direct execution cannot perform this conversion on Snow Leopard, do not run Lion; the next step would be to redesign the foreground test around an application-bundle/Aqua launch context rather than infer a Lion compatibility defect.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-transformprocesstype.c
scripts/build-ppc-process-manager-postidentity-transformprocesstype-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-postidentity-transformprocesstype-control.sh
scripts/run-lion-ppc-process-manager-postidentity-transformprocesstype.sh
docs/process-manager-postidentity-transformprocesstype-experiment.md
```

The accepted v5 CoreServices and v1 Security interposers remain unchanged.

## Safety constraints

- keep `LSDONOTABORTIFNOASN` unset;
- reuse the exact accepted v5 CoreServices and v1 Security adapters unchanged;
- do not add MapSharedSegment, Disconnect, distributed-notification, WindowServer, or other compatibility behavior;
- do not call `GetCurrentProcess`;
- do not call `SetFrontProcess` or `GetFrontProcess`;
- do not create/show a window or run an event loop;
- direct-execute through `/usr/oah/dyld`;
- run from the logged-in Aqua console user's Terminal with WindowServer already running;
- do not patch HIServices, LaunchServices, CarbonCore, Security, coreservicesd, WindowServer, Rosetta, dyld, the shared cache, or XNU;
- do not proceed to Lion unless both the Snow Leopard build and the complete passthrough control pass;
- run Lion exactly once before review.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No XNU rebuild or reboot is part of this stage.

## Phase B — build on Snow Leopard

Reuse the exact accepted compatibility dylibs from the previous stage.

Build the new subject:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-postidentity-transformprocesstype-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-postidentity-transformprocesstype-private-dyld
ppc-process-manager-postidentity-transformprocesstype-private-dyld.info.txt
ppc-process-manager-postidentity-transformprocesstype-private-dyld.sha256
```

Require:

- 32-bit PPC/ppc7400;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- direct Carbon linkage;
- imports `GetProcessForPID`, `GetProcessPID`, and `TransformProcessType`;
- no imports of `GetCurrentProcess`, `GetFrontProcess`, or `SetFrontProcess`;
- the new TransformProcessType milestone/result strings;
- all three output files.

If the build fails, stop and return the complete build output. Do not continue to Phase C or Lion.

## Phase C — Snow Leopard direct-execution control

Run from the logged-in Aqua console user's Terminal while WindowServer is running:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-postidentity-transformprocesstype-control.sh \
  ./ppc-process-manager-postidentity-transformprocesstype-private-dyld \
  ./ppc-process-manager-postidentity-transformprocesstype-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-postidentity-transformprocesstype-snowleopard-control.log
```

Both compatibility layers run in passthrough mode.

Require all prior setup and identity markers, exactly one SessionInit exact call, and:

```text
PM_POSTIDENTITY_STATUS:GetProcessForPID=0
PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS
PM_POSTIDENTITY_STATUS:GetProcessPID=0
PM_POSTIDENTITY_ROUNDTRIP:self=<pid> returned=<same-pid> match=YES
PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS
PM_POSTIDENTITY_MILESTONE:M09_BEFORE_TransformProcessType
PM_POSTIDENTITY_MILESTONE:M10_AFTER_TransformProcessType
PM_POSTIDENTITY_STATUS:TransformProcessType=0
PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS
PM_POSTIDENTITY_MILESTONE:M11_SUCCESS
RESULT: PASS
```

This is a hard gate.

If Snow Leopard does not return `TransformProcessType=0` in this direct-execution context, stop and return the complete control log. Do not transfer the new subject to Lion and do not weaken the gate; the foreground harness would need to move to an Aqua application-bundle context first.

## Phase D — transfer exact accepted artifacts

Transfer:

```text
ppc-process-manager-postidentity-transformprocesstype-private-dyld
ppc-process-manager-postidentity-transformprocesstype-private-dyld.info.txt
ppc-process-manager-postidentity-transformprocesstype-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256

ppc-process-manager-postidentity-transformprocesstype-snowleopard-control.log
```

Place executable/dylibs/SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require PASS.

Then run the syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-postidentity-transformprocesstype.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion TransformProcessType run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-postidentity-transformprocesstype.sh
```

The runner enables only:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

and requires `LSDONOTABORTIFNOASN` to remain unset.

Before accepting the foreground result it re-requires:

- exact validated runtime/kernel/cache identities;
- bootstrap adapter PASS;
- ServerCheckin adapter PASS;
- Security AuditInfo adapter PASS;
- exactly one v5 SessionInit exact call and successful adapted reply;
- nonzero dispatch table/server port;
- successful `GetProcessForPID` with nonzero PSN;
- successful `GetProcessPID` exact PID round-trip.

### Expected success

```text
PM_POSTIDENTITY_MILESTONE:M09_BEFORE_TransformProcessType
PM_POSTIDENTITY_MILESTONE:M10_AFTER_TransformProcessType
PM_POSTIDENTITY_STATUS:TransformProcessType=0
PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS
PM_POSTIDENTITY_MILESTONE:M11_SUCCESS
RESULT: POSTIDENTITY_TRANSFORMPROCESSTYPE_PASS
```

### New boundary

If the before marker appears but the after marker does not, preserve every new crash/core diagnostic and stop.

If `TransformProcessType` returns a nonzero OSStatus, preserve the exact status and all WindowServer/default-connection diagnostics. Do not reinterpret that returned failure as another SessionInit defect.

If a second exact SessionInit appears, the runner stops separately through the existing v5 safety gate. Do not broaden v5 before reviewing why foreground conversion requested another session-universe initialization.

Run Phase F only once before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-postidentity-transformprocesstype.log
lion-ppc-process-manager-postidentity-transformprocesstype.raw.log
syscall295-probe-process-manager-postidentity-transformprocesstype.log
ppc-process-manager-postidentity-transformprocesstype-snowleopard-control.log
ppc-process-manager-postidentity-transformprocesstype-private-dyld.info.txt
ppc-process-manager-postidentity-transformprocesstype-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new crash/core diagnostic named by the Lion runner.

## Result interpretation

### `POSTIDENTITY_TRANSFORMPROCESSTYPE_PASS`

The Process Manager identity and foreground-conversion boundaries are both restored under the same narrow user-space compatibility stack. The next controlled stage should test `SetFrontProcess` using the same PSN, still without creating a window or running an event loop.

### `POSTIDENTITY_TRANSFORMPROCESSTYPE_RETURNED_ERROR`

Identity remains good, but foreground conversion has exposed a new returned OSStatus boundary. Review the exact status and the accompanying WindowServer/CGS diagnostics before choosing another experiment.

### termination before return

Review the new crash/core evidence before changing behavior.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo adaptation -> PASS
LaunchServices process-dispatch setup -> PASS
SCSessionUniverse InitConnection request adaptation -> PASS
GetProcessForPID(getpid()) -> PASS
GetProcessPID(returned PSN) -> PASS with exact PID round-trip
TransformProcessType(returned PSN, foreground) -> next live proof
```

No additional XNU change is indicated.
