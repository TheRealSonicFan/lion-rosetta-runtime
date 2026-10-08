# Process Manager post-identity SetFrontProcess experiment

## Objective

Test the next Process Manager foreground/activation boundary after the translated PPC process has already proved identity in both directions and successfully converted itself to a foreground application.

The completed TransformProcessType experiment now proves on Lion, under the unchanged v5 CoreServices SessionInit adapter and v1 Security AuditInfo adapter:

```text
GetProcessForPID(getpid(), &psn)                         -> noErr + nonzero PSN
GetProcessPID(&psn, &pid)                                -> noErr + pid == getpid()
TransformProcessType(&psn, kProcessTransformToForegroundApplication)
                                                           -> noErr
```

The narrow next call is therefore:

```text
SetFrontProcess(&psn)
```

The new subject re-proves all prior identity and foreground-conversion prerequisites, calls `SetFrontProcess` exactly once using the same PSN, records the OSStatus, and exits immediately.

It does not call `GetCurrentProcess`, `GetFrontProcess`, create or show a window, install an event-loop timer, or enter an event loop.

## Evidence entering this stage

The accepted Lion TransformProcessType run used:

```text
TransformProcessType subject SHA-256:
f70fb4c1a8d4d98b5986807b0d969d6d60e30455c656df9397cdefa18324aa3f

CoreServices adapter:
dual-bootstrap-servercheckin-sessioninit-v5
2b2aa88d8dda14323066c92ec0f98181e6e71cce4686a8f43dacc4dbb8e55057

Security adapter:
security-session-auditinfo-api-v1
9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51
```

Lion re-proved the single adapted SessionInit transaction, returned successfully from both identity APIs, then returned:

```text
TransformProcessType = 0
RESULT: POSTIDENTITY_TRANSFORMPROCESSTYPE_PASS
```

No new crash/core diagnostic was produced and protected hashes remained unchanged.

The Snow Leopard direct-execution control also returned status 0 from `TransformProcessType` after the same identity progression, establishing that this direct-execution/Aqua-console harness is valid for foreground conversion.

The Lion process continued to emit the already-known non-fatal WindowServer/default-connection diagnostics during registration before the identity calls, but those diagnostics did not prevent `TransformProcessType` from succeeding. This experiment does not patch or suppress them. Instead it tests whether the next documented foreground-selection API succeeds in the same environment.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-setfrontprocess.c
scripts/build-ppc-process-manager-postidentity-setfrontprocess-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-postidentity-setfrontprocess-control.sh
scripts/run-lion-ppc-process-manager-postidentity-setfrontprocess.sh
docs/process-manager-postidentity-setfrontprocess-experiment.md
```

The accepted v5 CoreServices and v1 Security interposers remain unchanged.

## Safety constraints

- keep `LSDONOTABORTIFNOASN` unset;
- reuse the exact accepted v5 CoreServices and v1 Security adapters unchanged;
- do not add MapSharedSegment, Disconnect, distributed-notification, WindowServer, CGS, or other compatibility behavior;
- do not call `GetCurrentProcess` or `GetFrontProcess`;
- call `SetFrontProcess` exactly once;
- do not create/show a window or run an event loop;
- direct-execute through `/usr/oah/dyld`;
- run from the logged-in Aqua console user's Terminal with WindowServer already running;
- do not patch HIServices, LaunchServices, CarbonCore, Security, coreservicesd, WindowServer, Rosetta, dyld, the shared cache, or XNU;
- do not proceed to Lion unless the Snow Leopard build and complete direct-execution control pass;
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
  /bin/bash ./scripts/build-ppc-process-manager-postidentity-setfrontprocess-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-postidentity-setfrontprocess-private-dyld
ppc-process-manager-postidentity-setfrontprocess-private-dyld.info.txt
ppc-process-manager-postidentity-setfrontprocess-private-dyld.sha256
```

Require:

- 32-bit PPC/ppc7400;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- direct Carbon linkage;
- imports `GetProcessForPID`, `GetProcessPID`, `TransformProcessType`, and `SetFrontProcess`;
- no imports of `GetCurrentProcess` or `GetFrontProcess`;
- the SetFrontProcess milestone/result strings;
- all three output files.

If Phase B fails, stop and return the complete build output. Do not continue to Phase C or Lion.

## Phase C — Snow Leopard direct-execution control

Run from the logged-in Aqua console user's Terminal while WindowServer is running:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-postidentity-setfrontprocess-control.sh \
  ./ppc-process-manager-postidentity-setfrontprocess-private-dyld \
  ./ppc-process-manager-postidentity-setfrontprocess-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-postidentity-setfrontprocess-snowleopard-control.log
```

Both compatibility layers run in passthrough mode.

Require all prior setup, identity, and TransformProcessType markers, exactly one SessionInit exact call, and:

```text
PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess
PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess
PM_POSTIDENTITY_STATUS:SetFrontProcess=0
PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS
PM_POSTIDENTITY_MILESTONE:M13_SUCCESS
RESULT: PASS
```

This is a hard gate.

If Snow Leopard does not return `SetFrontProcess=0` in this direct-execution context, stop and return the complete control log. Do not run Lion and do not weaken the gate.

## Phase D — transfer exact accepted artifacts

Transfer:

```text
ppc-process-manager-postidentity-setfrontprocess-private-dyld
ppc-process-manager-postidentity-setfrontprocess-private-dyld.info.txt
ppc-process-manager-postidentity-setfrontprocess-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256

ppc-process-manager-postidentity-setfrontprocess-snowleopard-control.log
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
syscall295-probe-process-manager-postidentity-setfrontprocess.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion SetFrontProcess run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-postidentity-setfrontprocess.sh
```

The runner enables only:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

and requires `LSDONOTABORTIFNOASN` to remain unset.

Before accepting the new activation result it re-requires:

- exact validated runtime/kernel/cache identities;
- bootstrap adapter PASS;
- ServerCheckin adapter PASS;
- Security AuditInfo adapter PASS;
- exactly one v5 SessionInit exact call and successful adapted reply;
- nonzero dispatch table/server port;
- successful `GetProcessForPID` with nonzero PSN;
- successful `GetProcessPID` exact PID round-trip;
- successful `TransformProcessType(...foreground...)`.

### Expected success

```text
PM_POSTIDENTITY_MILESTONE:M11_BEFORE_SetFrontProcess
PM_POSTIDENTITY_MILESTONE:M12_AFTER_SetFrontProcess
PM_POSTIDENTITY_STATUS:SetFrontProcess=0
PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS
PM_POSTIDENTITY_MILESTONE:M13_SUCCESS
RESULT: POSTIDENTITY_SETFRONTPROCESS_PASS
```

### New boundary

If the before marker appears but the after marker does not, preserve every new crash/core diagnostic and stop.

If `SetFrontProcess` returns a nonzero OSStatus, preserve the exact status and all WindowServer/CGS diagnostics. Do not add a WindowServer workaround or proceed to window creation.

If a second exact SessionInit appears, the runner stops separately through the existing v5 safety gate. Do not broaden v5 before reviewing that evidence.

Run Phase F only once before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-postidentity-setfrontprocess.log
lion-ppc-process-manager-postidentity-setfrontprocess.raw.log
syscall295-probe-process-manager-postidentity-setfrontprocess.log
ppc-process-manager-postidentity-setfrontprocess-snowleopard-control.log
ppc-process-manager-postidentity-setfrontprocess-private-dyld.info.txt
ppc-process-manager-postidentity-setfrontprocess-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new crash/core diagnostic named by the Lion runner.

## Result interpretation

### `POSTIDENTITY_SETFRONTPROCESS_PASS`

The current compatibility stack restores Process Manager identity, foreground conversion, and front-process selection in the direct-execution Aqua session. The next controlled stage can introduce the first actual window operation, still before an event loop.

### `POSTIDENTITY_SETFRONTPROCESS_RETURNED_ERROR`

Identity and foreground conversion remain good, but front-process selection exposes a new activation/WindowServer boundary. Review the exact status and diagnostics before changing compatibility behavior.

### termination before return

Review crash/core evidence before any broader test.

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
SetFrontProcess(returned PSN) -> next live proof
```

No additional XNU change is indicated.
