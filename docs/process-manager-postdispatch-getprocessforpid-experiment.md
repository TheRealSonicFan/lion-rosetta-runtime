# Process Manager post-dispatch GetProcessForPID experiment

## Objective

Exercise exactly one real Process Manager identity request after the LaunchServices process-dispatch setup has already been completed successfully in the same PPC process.

The previous experiment now proves that Snow Leopard PPC LaunchServices can, on Lion with the two existing compatibility layers:

- acquire the CoreServices endpoint;
- obtain the current security session;
- complete the unchanged `InitializeProcessesServices` transaction;
- create/publish a nonzero process-dispatch table;
- expose a nonzero process-services server port.

The next unresolved boundary is therefore no longer LaunchServices setup itself. It is the first HIServices/Process Manager registration and identity call that consumes that initialized state.

This experiment uses:

```text
GetProcessForPID(getpid(), &psn)
```

exactly once, after a same-process positive check of `getProcessDispatchTable()` and `getProcessesServerPort()`.

It does not set `LSDONOTABORTIFNOASN`, does not call another Process Manager identity API, and does not continue into foreground/window/event-loop work.

## Why this is the narrowest next discriminator

Earlier in the investigation, `GetCurrentProcess`, pseudo-PSN `GetProcessPID`, and `GetProcessForPID` all self-aborted on Lion. Static analysis later identified two distinct possible fatal paths:

1. the earlier LaunchServices `getProcessDispatchTable()` abort if process-services setup did not publish a dispatch table;
2. the later HIServices `__RegisterApplication` no-ASN abort if application registration still had no usable ASN/PSN.

The first path is now dynamically closed. The corrected dispatch-setup experiment returned a nonzero table and process-services port on Lion without any no-ASN override.

That makes a no-override `GetProcessForPID` call the clean next test:

- if it now returns a nonzero PSN, Process Manager identity is restored by the existing CoreServices + Security compatibility layers;
- if it still aborts after the same-process dispatch-table proof, the remaining failure is downstream of LaunchServices process-dispatch setup, making the HIServices registration/no-ASN path the leading boundary;
- if it returns an error instead of aborting, preserve the exact OSStatus and PSN for the next decision.

## Evidence entering this stage

The completed Lion dispatch-setup run reported:

```text
LaunchServices image header / __TEXT.vmaddr = 0x97329000
getProcessDispatchTable address              = 0x97341654
getProcessesServerPort address               = 0x973416a8
all audited PPC prologues                    = 0x7c0802a6
CoreServices bootstrap adapter               = PASS
CoreServices ServerCheckin adapter            = PASS
Security SessionGetInfo AuditInfo adapter     = PASS
dispatch table                                = 0xa0bbf59c
process-services port                         = 0x00008f03
RESULT                                         = LAUNCHSERVICES_DISPATCH_SETUP_PASS
```

The Snow Leopard control returned the same nonzero dispatch-table pointer with a system-specific process-services port.

No new diagnostic was produced; protected hashes remained unchanged; syscall 295 still returned EBADF without SIGSYS.

## Prepared files

```text
tests/ppc-process-manager-postdispatch-getprocessforpid.c
scripts/build-ppc-process-manager-postdispatch-getprocessforpid-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-postdispatch-getprocessforpid-control.sh
scripts/run-lion-ppc-process-manager-postdispatch-getprocessforpid.sh
docs/process-manager-postdispatch-getprocessforpid-experiment.md
```

The stage reuses unchanged:

```text
ppc-process-manager-coreservices-compat-interposer.dylib
  build ID: dual-bootstrap-servercheckin-v3

ppc-process-manager-security-session-auditinfo-api.dylib
  build ID: security-session-auditinfo-api-v1
```

## Probe sequence

The PPC subject performs only this sequence:

1. require `LSDONOTABORTIFNOASN` to be absent;
2. locate the loaded Snow Leopard PPC LaunchServices image;
3. validate the corrected shared-cache `__TEXT` address model;
4. validate the three audited `mflr r0` entry prologues;
5. call `getProcessDispatchTable()` and require a nonzero pointer;
6. call `getProcessesServerPort()` and require a nonzero port;
7. call `GetProcessForPID(getpid(), &psn)` exactly once;
8. log the returned OSStatus and PSN;
9. exit immediately.

It does not call:

```text
GetCurrentProcess
GetProcessPID
TransformProcessType
SetFrontProcess
GetFrontProcess
window APIs
event-loop APIs
```

## Safety constraints

- build the PPC subject only on Snow Leopard 10.6.8;
- require the complete Snow Leopard control before Lion;
- run the Lion subject exactly once before review;
- keep `LSDONOTABORTIFNOASN` unset on both systems;
- do not use the old private LaunchServices PPC-admission patch;
- do not launch an app bundle through `open`;
- direct-execute only the private-dyld PPC subject;
- use only the proven v3 CoreServices and v1 Security interposers;
- do not modify either compatibility layer;
- do not patch HIServices, LaunchServices, CarbonCore, Security, coreservicesd, WindowServer, Rosetta, dyld, the shared cache, or XNU;
- do not alter the LaunchServices database;
- do not use `SCDontUseServer`;
- do not interpose or suppress `abort`;
- do not restart daemons;
- do not use GDB, DTrace, dtruss, or system-wide injection.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No XNU rebuild or reboot is part of this stage.

## Phase B — build on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-postdispatch-getprocessforpid-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-postdispatch-getprocessforpid-private-dyld
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256
```

Require:

- 32-bit PPC/ppc7400;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- Carbon, CoreServices, and Security linkage;
- `GetProcessForPID` imported;
- no imports of `GetCurrentProcess`, `GetProcessPID`, `GetFrontProcess`, `SetFrontProcess`, or `TransformProcessType`;
- the three audited LaunchServices `__TEXT` offsets and PPC prologue word recorded in the info sidecar.

If build fails, stop and return the complete output.

## Phase C — Snow Leopard positive control

Run from the logged-in user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-postdispatch-getprocessforpid-control.sh \
  ./ppc-process-manager-postdispatch-getprocessforpid-private-dyld \
  ./ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-postdispatch-getprocessforpid-snowleopard-control.log
```

Both compatibility modes are pass-through.

Require:

```text
PM_POSTDISPATCH_ENV:LSDONOTABORTIFNOASN=(unset)
PM_POSTDISPATCH_LAYOUT:... headerMatchesTextVMAddr=YES ...
PM_POSTDISPATCH_PROLOGUE:expected=0x7c0802a6 setup=0x7c0802a6 dispatch=0x7c0802a6 server=0x7c0802a6
CoreServices passthrough bootstrap/ServerCheckin -> observed
Security SessionGetInfo passthrough -> observed
PM_POSTDISPATCH_TABLE:pointer=nonzero nonzero=YES
PM_POSTDISPATCH_SERVER_PORT:port=nonzero nonzero=YES
PM_POSTDISPATCH_MILESTONE:M05_BEFORE_GetProcessForPID
PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID
PM_POSTDISPATCH_STATUS:GetProcessForPID=0
PM_POSTDISPATCH_PSN:... low=nonzero
PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS
PM_POSTDISPATCH_MILESTONE:M07_SUCCESS
RESULT: PASS
```

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-postdispatch-getprocessforpid-private-dyld
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-postdispatch-getprocessforpid-snowleopard-control.log
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
syscall295-probe-process-manager-postdispatch-getprocessforpid.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — one Lion post-dispatch identity run

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-postdispatch-getprocessforpid.sh
```

The runner enables only:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

and requires `LSDONOTABORTIFNOASN` to remain unset.

### Expected success

```text
PM_POSTDISPATCH_LAYOUT:... headerMatchesTextVMAddr=YES ... dispatchTextOffset=0x00018654 ... serverTextOffset=0x000186a8 ...
PM_POSTDISPATCH_PROLOGUE:expected=0x7c0802a6 setup=0x7c0802a6 dispatch=0x7c0802a6 server=0x7c0802a6
CoreServices bootstrap adapter -> PASS
CoreServices ServerCheckin adapter -> PASS
Security AuditInfo SessionGetInfo adapter -> PASS
PM_POSTDISPATCH_TABLE:pointer=nonzero nonzero=YES
PM_POSTDISPATCH_SERVER_PORT:port=nonzero nonzero=YES
PM_POSTDISPATCH_MILESTONE:M05_BEFORE_GetProcessForPID
PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID
PM_POSTDISPATCH_STATUS:GetProcessForPID=0
PM_POSTDISPATCH_PSN:... low=nonzero
PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS
RESULT: POSTDISPATCH_GETPROCESSFORPID_PASS
```

### Abort-before-return discriminator

If:

```text
M05_BEFORE_GetProcessForPID
```

appears but `M06_AFTER_GetProcessForPID` does not, the runner reports:

```text
RESULT: POSTDISPATCH_GETPROCESSFORPID_ABORT_BEFORE_RETURN
```

Preserve every crash/core diagnostic and stop. Do not rerun with `LSDONOTABORTIFNOASN=0` until that result is reviewed.

### Returned error

If the call returns but status is nonzero:

```text
RESULT: POSTDISPATCH_GETPROCESSFORPID_RETURNED_ERROR
```

Preserve the exact OSStatus and PSN.

### Zero PSN

If status is zero but the PSN remains unusable:

```text
RESULT: POSTDISPATCH_GETPROCESSFORPID_ZERO_PSN
```

Preserve the exact PSN.

Do not rerun Phase F before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-postdispatch-getprocessforpid.log
lion-ppc-process-manager-postdispatch-getprocessforpid.raw.log
syscall295-probe-process-manager-postdispatch-getprocessforpid.log
ppc-process-manager-postdispatch-getprocessforpid-snowleopard-control.log
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new crash/core diagnostic named by the Lion runner.

## Result interpretation

### `POSTDISPATCH_GETPROCESSFORPID_PASS`

The original shell-launched Process Manager identity failure is closed without a no-ASN override. The existing user-space compatibility work is sufficient for LaunchServices process-dispatch setup and at least one real HIServices Process Manager identity route.

The next stage should then test a minimally broader Carbon application sequence, beginning with the returned PSN and foreground conversion, rather than invent another compatibility layer.

### `POSTDISPATCH_GETPROCESSFORPID_ABORT_BEFORE_RETURN`

Because the same process already proved a nonzero dispatch table and process-services port, the former LaunchServices process-dispatch abort cannot explain this run. The remaining abort is downstream, with HIServices `__RegisterApplication` / ASN acquisition now the leading boundary.

The next discriminator would be a controlled repeat with the already-audited process-local `LSDONOTABORTIFNOASN=0` override, but only after reviewing the crash and confirming that the same dispatch setup markers preceded it.

### `POSTDISPATCH_GETPROCESSFORPID_RETURNED_ERROR`

Registration advanced far enough to return an OSStatus. Use that returned status, not the historical abort, as the next boundary.

### `POSTDISPATCH_GETPROCESSFORPID_ZERO_PSN`

The call returned noErr without a usable identity. Preserve the exact PSN and do not proceed to foreground APIs.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo API adaptation -> PASS
InitializeProcessesServices wire transaction -> PASS
real LaunchServices process-dispatch setup -> PASS
GetProcessForPID after proven dispatch setup -> next proof
```

No additional XNU change is indicated.
