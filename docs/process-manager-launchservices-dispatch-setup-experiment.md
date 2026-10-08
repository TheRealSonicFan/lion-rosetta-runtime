# Process Manager LaunchServices process-dispatch setup experiment

## Objective

Exercise the real Snow Leopard PPC LaunchServices process-dispatch setup path after the independently proven prerequisites and InitializeProcessesServices wire transaction have all passed on Lion.

This stage does **not** call a Process Manager identity API. Instead, a dedicated PPC probe resolves two already-audited non-exported functions inside the loaded Snow Leopard PPC LaunchServices image and invokes only:

```text
getProcessDispatchTable()
getProcessesServerPort()
```

The first call is the exact internal boundary that previously called `SetupCoreApplicationServicesCommunicationPort()` and aborted if the process dispatch table remained unavailable. In a fresh process, it should trigger the real setup path exactly once. If it returns a nonzero dispatch-table pointer, the old pre-identity abort boundary is closed. The second call is made only after that successful return; because the CFMachPort state is then already initialized, it should simply expose the established process-services Mach port without triggering the recheck-in branch.

## Evidence entering this stage

The immediately preceding wire experiment passed completely on both systems.

On Lion, after the proven CoreServices and Security adapters supplied a valid `LaunchApplicationServices` port and security session, the unmodified Snow Leopard PPC InitializeProcessesServices request was accepted unchanged:

```text
request ID   = 0x4650
send size    = 0x2c
receive size = 0x50
session      = 0x000186a3 (twice)
version      = 0x00a1be40
mach_msg     = KERN_SUCCESS
reply ID     = 0x46b4
reply size   = 0x48
complex      = YES
descriptors  = 2
process port = nonzero
outVersion   = 0x00a1be40
outError     = 0
outCount     = 0
```

The Snow Leopard positive control returned the same successful reply shape and scalar values.

Therefore the remaining earlier LaunchServices abort boundary is no longer the service/session prerequisites or the `0x4650` transport itself. The next unresolved work is the shipped LaunchServices post-reply path that creates the process CFMachPort, installs reconnect state, and publishes the local process dispatch table.

## Binary-proven local function offsets

The prior Snow Leopard PPC LaunchServices disassembly established:

```text
SetupCoreApplicationServicesCommunicationPort = n_value 0x00018070
getProcessDispatchTable                       = n_value 0x00018654
getProcessesServerPort                        = n_value 0x000186a8
```

The probe does not assume a fixed load address. At runtime it:

1. locates the loaded PPC `LaunchServices.framework/Versions/A/LaunchServices` image through dyld;
2. verifies a 32-bit PPC Mach-O header;
3. reads the loaded `__TEXT` segment's preferred `vmaddr` and size;
4. verifies each audited `n_value` lies within that `__TEXT` range;
5. resolves the actual function address as `loaded_header + (n_value - __TEXT.vmaddr)`.

Snow Leopard must pass this exact resolution and call sequence before Lion is attempted.

## Why this is the narrowest next discriminator

The shipped Snow Leopard PPC `getProcessDispatchTable()` implementation is only 21 instructions. It:

1. checks whether process-services state is absent;
2. calls `SetupCoreApplicationServicesCommunicationPort()` if needed;
3. reads the process dispatch table;
4. calls `abort()` if the table is still null;
5. otherwise returns the table pointer.

The real setup success branch, already audited, performs:

```text
scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, ...)
GetOurLSSessionID / SessionGetInfo
_LSDoInitializeProcessesServices
CFMachPortCreateWithPort(returned process port, ...)
scAddReconnectProc(...)
publish current pid / process dispatch table
```

The two compatibility layers now cover the only proven cross-version defects below that path, and the `_LSDoInitializeProcessesServices` wire request itself has passed unchanged.

Calling `getProcessDispatchTable()` directly therefore answers one precise question: does the real LaunchServices setup now complete and publish usable process-dispatch state?

## Prepared files

```text
tests/ppc-process-manager-launchservices-dispatch-setup-probe.c
scripts/build-ppc-process-manager-launchservices-dispatch-setup-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-launchservices-dispatch-setup-control.sh
scripts/run-lion-ppc-process-manager-launchservices-dispatch-setup.sh
docs/process-manager-launchservices-dispatch-setup-experiment.md
```

This stage reuses the two proven compatibility artifacts unchanged:

```text
ppc-process-manager-coreservices-compat-interposer.dylib
  build ID: dual-bootstrap-servercheckin-v3

ppc-process-manager-security-session-auditinfo-api.dylib
  build ID: security-session-auditinfo-api-v1
```

## Safety constraints

- build the PPC probe only on Snow Leopard 10.6.8;
- require the exact Snow Leopard direct-local-function control before Lion;
- use only the two already-proven process-local compatibility dylibs;
- do not modify either interposer;
- do not load the obsolete SecurityServer bootstrap/session compatibility experiment;
- do not patch LaunchServices, CarbonCore, Security, CoreServices, coreservicesd, libSystem, Rosetta, dyld, the shared cache, or XNU;
- do not use `SCDontUseServer`;
- do not set `LSDONOTABORTIFNOASN`;
- do not interpose `abort`;
- do not suppress or recover from a LaunchServices abort;
- do not call `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, foreground APIs, registration APIs, or an event loop;
- call `getProcessesServerPort()` only after `getProcessDispatchTable()` has returned a nonzero table, preventing the fresh-state recheck-in branch;
- do not restart daemons;
- do not use a debugger, DTrace, dtruss, or system-wide injection;
- perform exactly one Lion Phase F run before review.

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

No kernel rebuild or reboot is part of this stage.

## Phase B — build the PPC dispatch-setup probe on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-launchservices-dispatch-setup-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-launchservices-dispatch-setup-private-dyld
ppc-process-manager-launchservices-dispatch-setup-private-dyld.info.txt
ppc-process-manager-launchservices-dispatch-setup-private-dyld.sha256
```

Require:

- 32-bit PPC executable;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- CoreServices and Security linkage;
- no Process Manager identity/foreground imports;
- the three audited local-function offsets recorded in the build report.

If the build fails, stop and return the complete build output. Do not change the offsets to make the build or control pass.

## Phase C — Snow Leopard positive control

Use the exact proven CoreServices and Security dylibs and run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-launchservices-dispatch-setup-control.sh \
  ./ppc-process-manager-launchservices-dispatch-setup-private-dyld \
  ./ppc-process-manager-launchservices-dispatch-setup-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-launchservices-dispatch-setup-snowleopard-control.log
```

Both compatibility modes are pass-through on Snow Leopard.

Require:

```text
PM_LS_DISPATCH_IMAGE:... cputype=18 ...
PM_LS_DISPATCH_LAYOUT:... dispatchNValue=0x00018654 ... serverNValue=0x000186a8 ...
CoreServices passthrough lookup/ServerCheckin -> observed
Security SessionGetInfo passthrough -> observed
PM_LS_DISPATCH_MILESTONE:M01_BEFORE_getProcessDispatchTable
PM_LS_DISPATCH_MILESTONE:M02_AFTER_getProcessDispatchTable
PM_LS_DISPATCH_TABLE:pointer=nonzero nonzero=YES
PM_LS_DISPATCH_MILESTONE:M03_BEFORE_getProcessesServerPort
PM_LS_DISPATCH_MILESTONE:M04_AFTER_getProcessesServerPort
PM_LS_DISPATCH_SERVER_PORT:port=nonzero nonzero=YES
PM_LS_DISPATCH_RESULT:DISPATCH_SETUP_PASS
RESULT: PASS
```

If Phase C aborts, crashes, returns a null table, or returns a zero server port, stop. Do not run Lion. That would mean the local-function offset/resolution harness is not yet validated.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-launchservices-dispatch-setup-private-dyld
ppc-process-manager-launchservices-dispatch-setup-private-dyld.info.txt
ppc-process-manager-launchservices-dispatch-setup-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-launchservices-dispatch-setup-snowleopard-control.log
```

Place the executable/dylibs/SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing PASS.

Then run the syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-launchservices-dispatch-setup.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — one Lion real LaunchServices dispatch-setup run

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-launchservices-dispatch-setup.sh
```

The runner enables exactly:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

Expected success:

```text
PM_LS_DISPATCH_IMAGE:... cputype=18 ...
PM_LS_DISPATCH_LAYOUT:... dispatchNValue=0x00018654 ... serverNValue=0x000186a8 ...
CoreServices bootstrap adapter -> PASS
CoreServices ServerCheckin adapter -> PASS
Security AuditInfo SessionGetInfo adapter -> PASS
PM_LS_DISPATCH_MILESTONE:M02_AFTER_getProcessDispatchTable
PM_LS_DISPATCH_TABLE:pointer=nonzero nonzero=YES
PM_LS_DISPATCH_MILESTONE:M04_AFTER_getProcessesServerPort
PM_LS_DISPATCH_SERVER_PORT:port=nonzero nonzero=YES
PM_LS_DISPATCH_RESULT:DISPATCH_SETUP_PASS
RESULT: LAUNCHSERVICES_DISPATCH_SETUP_PASS
```

If `M01_BEFORE_getProcessDispatchTable` appears but `M02_AFTER_getProcessDispatchTable` does not, the runner classifies:

```text
RESULT: LAUNCHSERVICES_DISPATCH_SETUP_ABORT_BEFORE_RETURN
```

Preserve the crash/core and do not interpose `abort`.

Do not rerun Phase F before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-launchservices-dispatch-setup.log
lion-ppc-process-manager-launchservices-dispatch-setup.raw.log
syscall295-probe-process-manager-launchservices-dispatch-setup.log
ppc-process-manager-launchservices-dispatch-setup-snowleopard-control.log
ppc-process-manager-launchservices-dispatch-setup-private-dyld.info.txt
ppc-process-manager-launchservices-dispatch-setup-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new diagnostic named by the Lion runner.

## Result interpretation

### `LAUNCHSERVICES_DISPATCH_SETUP_PASS`

The earlier LaunchServices process-dispatch abort boundary is closed without calling Process Manager. The shipped PPC setup successfully:

- acquires the CoreServices endpoint through the existing adapter;
- derives the security session through the AuditInfo adapter;
- completes the unmodified InitializeProcessesServices wire transaction;
- creates and publishes usable process-services CFMachPort state;
- publishes a nonzero local process dispatch table.

The next controlled stage should then return to exactly one Process Manager identity request, preferably the already-audited `GetProcessForPID(getpid(), ...)` discriminator, with the two proven compatibility adapters active and **without** the old `LSDONOTABORTIFNOASN` override unless a later registration failure specifically justifies reintroducing that discriminator.

### abort before `getProcessDispatchTable` return

The wire transaction is known-good, so preserve the crash and correlate it with the post-reply LaunchServices setup branch. Do not infer that the table itself is null until the failure position is established.

### nonzero table but zero server port

The local dispatch-table publication succeeded but the CFMachPort-backed server endpoint is unusable. Preserve the exact log and stop.

### offset/image validation failure

Treat this as a harness/provenance problem, not a runtime compatibility defect.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo API adaptation -> PASS
combined pre-dispatch prerequisites -> PASS
InitializeProcessesServices 0x4650 wire transaction -> PASS
real LaunchServices process-dispatch setup -> next proof
```

No additional XNU change is indicated.
