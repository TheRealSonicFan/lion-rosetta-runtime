# Process Manager post-identity GetProcessPID round-trip experiment

## Objective

Test the first Process Manager API boundary after the now-restored `GetProcessForPID(getpid(), &psn)` path, without moving into foreground conversion, WindowServer activation, window creation, or an event loop.

The completed SessionUniverse InitConnection adapter experiment proves that, under the current v5 CoreServices adapter plus the Security AuditInfo adapter, Lion now returns `noErr` and a nonzero PSN from the first real shell-launched `GetProcessForPID` call.

The narrow next question is whether that returned PSN is usable by the documented reverse identity lookup:

```text
GetProcessPID(&psn, &pid)
```

The new probe therefore performs exactly this progression:

```text
dispatch setup proof
-> GetProcessForPID(getpid(), &psn)
-> require noErr + nonzero PSN
-> GetProcessPID(&psn, &roundtrip_pid)
-> require noErr + roundtrip_pid == getpid()
-> stop
```

It does not call `GetCurrentProcess`, `TransformProcessType`, `SetFrontProcess`, any window API, or any event-loop API.

## Evidence entering this stage

The accepted Lion run used:

```text
CoreServices adapter:
  dual-bootstrap-servercheckin-sessioninit-v5
  SHA-256 2b2aa88d8dda14323066c92ec0f98181e6e71cce4686a8f43dacc4dbb8e55057

Security adapter:
  security-session-auditinfo-api-v1
  SHA-256 9aed61996fd5079299f7b8971a77efcfc25908636618e4754866ea8267306b51

post-dispatch subject:
  SHA-256 bfcb083723fb24fa4c1875bce1a3388ab2b010145b4bc2f54749f8918231ab37
```

On Lion, v5 observed the legacy request on the actual coreservicesd server/check-in port, rewrote only request `0x2712` from `0x2c [PID,UID,layout]` to `0x28 [UID,layout]`, received the compatible `0x2776 / 0x2c / RetCode=0` reply, and reported `PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS`.

The subject then returned from `GetProcessForPID` with status 0 and a nonzero PSN and the runner ended:

```text
RESULT: SESSIONINIT_ADAPTER_GETPROCESSFORPID_PASS
```

No new crash/core diagnostic was produced and all guarded hashes remained unchanged.

The run also emitted non-fatal WindowServer/default-connection diagnostics after registration. This experiment deliberately does not interpret or repair those diagnostics because it does not perform foreground conversion or GUI work. The only new discriminator is PSN-to-PID round-trip identity.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-getprocesspid.c
scripts/build-ppc-process-manager-postidentity-getprocesspid-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-postidentity-getprocesspid-control.sh
scripts/run-lion-ppc-process-manager-postidentity-getprocesspid.sh
docs/process-manager-postidentity-getprocesspid-experiment.md
```

The new subject retains the same validated LaunchServices local setup checks and then adds exactly one `GetProcessPID` call using the PSN returned by `GetProcessForPID`.

## Safety constraints

- keep `LSDONOTABORTIFNOASN` unset;
- reuse the accepted v5 CoreServices and v1 Security interposers unchanged;
- do not add a MapSharedSegment or Disconnect adapter;
- do not call `GetCurrentProcess`;
- do not call `TransformProcessType`, `SetFrontProcess`, `GetFrontProcess`, or GUI/event APIs;
- direct-execute the PPC subject through `/usr/oah/dyld`; do not launch an app bundle in this stage;
- do not patch HIServices, LaunchServices, CarbonCore, Security, coreservicesd, WindowServer, Rosetta, dyld, or the shared cache;
- do not modify XNU;
- do not proceed to Lion unless the Snow Leopard build and passthrough control both pass;
- run the Lion subject exactly once before review.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the documentation checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the new PPC subject on Snow Leopard

Reuse the exact accepted compatibility dylibs from the completed SessionInit experiment.

Build:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-postidentity-getprocesspid-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-postidentity-getprocesspid-private-dyld
ppc-process-manager-postidentity-getprocesspid-private-dyld.info.txt
ppc-process-manager-postidentity-getprocesspid-private-dyld.sha256
```

Require:

- 32-bit PPC/ppc7400;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- direct Carbon linkage;
- imports of exactly the two intended Process Manager identity APIs for this stage: `GetProcessForPID` and `GetProcessPID`;
- no `GetCurrentProcess`, `GetFrontProcess`, `SetFrontProcess`, or `TransformProcessType`;
- required post-identity milestone/result strings;
- all three outputs present.

If Phase B fails, stop and return the complete build output. Do not proceed to Phase C or Lion.

## Phase C — Snow Leopard passthrough control

Run from the logged-in user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-postidentity-getprocesspid-control.sh \
  ./ppc-process-manager-postidentity-getprocesspid-private-dyld \
  ./ppc-process-manager-postidentity-getprocesspid-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-postidentity-getprocesspid-snowleopard-control.log
```

Both compatibility layers run in passthrough mode.

Require all established setup/SessionInit markers, require exactly one observed SessionInit exact call (no `index=2`), and:

```text
PM_POSTIDENTITY_STATUS:GetProcessForPID=0
PM_POSTIDENTITY_PSN:... low=nonzero
PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS
PM_POSTIDENTITY_MILESTONE:M07_BEFORE_GetProcessPID
PM_POSTIDENTITY_MILESTONE:M08_AFTER_GetProcessPID
PM_POSTIDENTITY_STATUS:GetProcessPID=0
PM_POSTIDENTITY_ROUNDTRIP:self=<pid> returned=<same-pid> match=YES
PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS
PM_POSTIDENTITY_MILESTONE:M09_SUCCESS
RESULT: PASS
```

This is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts

Transfer to Lion:

```text
ppc-process-manager-postidentity-getprocesspid-private-dyld
ppc-process-manager-postidentity-getprocesspid-private-dyld.info.txt
ppc-process-manager-postidentity-getprocesspid-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256

ppc-process-manager-postidentity-getprocesspid-snowleopard-control.log
```

Place the executable/dylibs/SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the already validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require PASS.

Then run the syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-postidentity-getprocesspid.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion round-trip run

From the logged-in Lion user's Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-postidentity-getprocesspid.sh
```

The runner again enables only:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

and requires `LSDONOTABORTIFNOASN` to remain unset.

Before accepting the new round-trip result it re-requires:

- bootstrap adapter PASS;
- ServerCheckin adapter PASS;
- Security AuditInfo adapter PASS;
- v5 SessionInit exact-call/request/reply PASS;
- no second exact SessionInit call; the Snow control is a hard gate for that invariant;
- nonzero dispatch table and process-services port;
- `GetProcessForPID=0` and a nonzero returned PSN.

### Expected success

```text
PM_POSTIDENTITY_MILESTONE:M07_BEFORE_GetProcessPID
PM_POSTIDENTITY_MILESTONE:M08_AFTER_GetProcessPID
PM_POSTIDENTITY_STATUS:GetProcessPID=0
PM_POSTIDENTITY_ROUNDTRIP:self=<pid> returned=<same-pid> match=YES
PM_POSTIDENTITY_RESULT:GETPROCESSPID_ROUNDTRIP_PASS
PM_POSTIDENTITY_MILESTONE:M09_SUCCESS
RESULT: POSTIDENTITY_GETPROCESSPID_ROUNDTRIP_PASS
```

### New boundary

If `M07_BEFORE_GetProcessPID` appears but `M08_AFTER_GetProcessPID` does not, preserve every new crash/core diagnostic and stop.

If the API returns a nonzero OSStatus, preserve it and stop.

If it returns `noErr` but a different PID, preserve both PIDs and stop.

An unexpected second SessionInit is classified separately as `POSTIDENTITY_UNEXPECTED_SECOND_SESSIONINIT`; do not weaken the v5 one-call safety guard from a Lion-only observation. Do not compensate by enabling the no-ASN override or moving to foreground APIs.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-postidentity-getprocesspid.log
lion-ppc-process-manager-postidentity-getprocesspid.raw.log
syscall295-probe-process-manager-postidentity-getprocesspid.log
ppc-process-manager-postidentity-getprocesspid-snowleopard-control.log
ppc-process-manager-postidentity-getprocesspid-private-dyld.info.txt
ppc-process-manager-postidentity-getprocesspid-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new crash/core diagnostic named by the Lion runner.

## Result interpretation

### `POSTIDENTITY_GETPROCESSPID_ROUNDTRIP_PASS`

The returned PSN is demonstrably usable by a second documented Process Manager identity API and round-trips to the exact subject PID. At that point the identity/registration path is closed beyond a single API call. The next controlled stage may move to foreground conversion using the already-returned PSN, still before window creation.

### `POSTIDENTITY_GETPROCESSPID_...` failure

The SessionInit repair restores PID-to-PSN lookup but a later PSN-to-PID identity boundary remains. Review that exact returned/termination evidence before any foreground experiment.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo adaptation -> PASS
LaunchServices process-dispatch setup -> PASS
SCSessionUniverse InitConnection request adaptation -> PASS
GetProcessForPID(getpid()) -> PASS with nonzero PSN
GetProcessPID(returned PSN) -> next live proof
```

No additional XNU change is indicated.
