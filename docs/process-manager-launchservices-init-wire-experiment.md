# Process Manager LaunchServices InitializeProcessesServices wire experiment

## Objective

Test the first still-unexercised LaunchServices process-services boundary after the combined pre-dispatch compatibility layer has passed.

The immediately preceding integration proved, in one translated PPC process on Lion, that:

- the v3 CoreServices bootstrap adaptation succeeds;
- the v3 ServerCheckin adaptation succeeds;
- unmodified CarbonCore returns a nonzero `LaunchApplicationServices` service port;
- the AuditInfo-backed `SessionGetInfo(callerSecuritySession,...)` adapter succeeds;
- the returned security session ID is nonzero;
- both compatibility dylibs coexist cleanly.

This experiment now sends exactly one binary-proven Snow Leopard PPC `InitializeProcessesServices` MIG request to that already-obtained service port and stops after decoding the reply. It does not call Process Manager and does not install a process dispatch table.

## Why this is the narrowest next discriminator

The earlier shipped-binary audit established that Snow Leopard PPC and Lion native LaunchServices use the same 32-bit InitializeProcessesServices message family:

```text
request ID  = 0x4650
send size   = 0x2c
receive size= 0x50
reply ID    = 0x46b4
```

The Snow Leopard PPC caller passes:

```text
service port
current LSSessionID
current LSSessionID
process-services version 0x00a1be40
five output locations
```

The generated PPC MIG client serializes only the first four values in the request: the three scalar input words are the current session ID twice and `0x00a1be40`.

The expected successful reply is the generated client's complex `0x48` form with two descriptors. Its scalar fields are NDR-encoded; the probe applies the same integer-representation conversion that the shipped PPC MIG stub performs before interpreting those values.

The probe deliberately sends the request itself rather than calling the private, non-exported `_LSDoInitializeProcessesServices` symbol. That isolates the client/server wire boundary without depending on private-symbol lookup or proceeding into CFMachPort/dispatch-table installation.

## Prepared files

```text
tests/ppc-process-manager-launchservices-init-wire-probe.c
scripts/build-ppc-process-manager-launchservices-init-wire-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-launchservices-init-wire-control.sh
scripts/run-lion-ppc-process-manager-launchservices-init-wire.sh
docs/process-manager-launchservices-init-wire-experiment.md
```

This stage reuses the two already-proven compatibility artifacts:

```text
ppc-process-manager-coreservices-compat-interposer.dylib
  build ID: dual-bootstrap-servercheckin-v3

ppc-process-manager-security-session-auditinfo-api.dylib
  build ID: security-session-auditinfo-api-v1
```

## Safety constraints

- build the PPC wire probe only on Snow Leopard 10.6.8;
- require a Snow Leopard positive control before Lion;
- use the two existing process-local compatibility dylibs only;
- do not load the separate SecurityServer bootstrap adapter;
- do not modify either proven compatibility interposer;
- do not patch LaunchServices, CarbonCore, Security, coreservicesd, libSystem, Rosetta, dyld, the shared cache, or XNU;
- do not use `SCDontUseServer`;
- do not call `SessionCreate`, `setaudit_addr`, or `auditon`;
- send exactly one InitializeProcessesServices request in the Lion run;
- do not call `getProcessDispatchTable`, `getProcessesServerPort`, `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, or another Process Manager API;
- do not install a dispatch table or create the returned CFMachPort;
- deallocate only ports/OOL memory returned to the probe itself;
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

## Phase B — build the wire probe on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-launchservices-init-wire-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-launchservices-init-wire-private-dyld
ppc-process-manager-launchservices-init-wire-private-dyld.info.txt
ppc-process-manager-launchservices-init-wire-private-dyld.sha256
```

Require:

- 32-bit PPC output;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- CoreServices and Security linkage;
- imports for `scCreateSystemServiceVersion`, `SessionGetInfo`, `mach_msg`, `mig_get_reply_port`, and `vm_deallocate`;
- compile-time confirmation that the PPC Mach header is `0x18` bytes and NDR record is `0x08` bytes.

If the build fails, stop and return the complete build output. Do not modify the wire constants to make it compile.

## Phase C — Snow Leopard positive control

Use the exact proven CoreServices and Security dylibs, then run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-launchservices-init-wire-control.sh \
  ./ppc-process-manager-launchservices-init-wire-private-dyld \
  ./ppc-process-manager-launchservices-init-wire-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-launchservices-init-wire-snowleopard-control.log
```

Both compatibility modes are pass-through on Snow Leopard.

Require:

```text
LaunchApplicationServices port -> nonzero
SessionGetInfo -> status 0
PM_LS_INIT_REQUEST:bits=0x00001513 id=0x00004650 send=0x0000002c recv=0x00000050 ...
PM_LS_INIT_MACH_MSG:kr=0 ...
PM_LS_INIT_REPLY_HEADER:... size=0x00000048 id=0x000046b4 complex=YES
PM_LS_INIT_REPLY_DESCRIPTORS:count=2 ...
PM_LS_INIT_REPLY_VALUES:... outError=0 ...
PM_LS_INIT_RESULT:PROCESS_SERVICES_WIRE_PASS
RESULT: PASS
```

The Snow log is also the reference for returned version/count/descriptor values. Do not hard-code additional value assumptions before reviewing that control.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-launchservices-init-wire-private-dyld
ppc-process-manager-launchservices-init-wire-private-dyld.info.txt
ppc-process-manager-launchservices-init-wire-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-launchservices-init-wire-snowleopard-control.log
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
syscall295-probe-process-manager-launchservices-init-wire.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — one Lion InitializeProcessesServices wire run

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-launchservices-init-wire.sh
```

The runner enables:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

Require the already-proven prerequisite sequence, then inspect the one `0x4650` transaction.

Expected successful result:

```text
PM_LS_INIT_REQUEST:bits=0x00001513 id=0x00004650 send=0x0000002c recv=0x00000050 ...
PM_LS_INIT_MACH_MSG:kr=0 hex=0x00000000
PM_LS_INIT_REPLY_HEADER:... size=0x00000048 id=0x000046b4 complex=YES
PM_LS_INIT_REPLY_DESCRIPTORS:count=2 ...
PM_LS_INIT_REPLY_VALUES:... outError=0 ...
PM_LS_INIT_RESULT:PROCESS_SERVICES_WIRE_PASS
RESULT: LAUNCHSERVICES_INIT_WIRE_PASS
```

If the server returns a simple MIG reply, preserve the logged signed/hex error. Do not adapt it in the same run.

Do not rerun Phase F before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-launchservices-init-wire.log
lion-ppc-process-manager-launchservices-init-wire.raw.log
syscall295-probe-process-manager-launchservices-init-wire.log
ppc-process-manager-launchservices-init-wire-snowleopard-control.log
ppc-process-manager-launchservices-init-wire-private-dyld.info.txt
ppc-process-manager-launchservices-init-wire-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new diagnostic named by the Lion runner.

## Result interpretation

### `LAUNCHSERVICES_INIT_WIRE_PASS`

The Snow Leopard PPC InitializeProcessesServices request is accepted unchanged by Lion coreservicesd after the already-proven CoreServices and Security compatibility prerequisites are restored.

The next boundary is no longer the wire request. The following controlled stage should exercise the real LaunchServices setup path through its post-reply work: CFMachPort creation, returned OOL dispatch-table handling, and process-dispatch-table installation, while still stopping before a Process Manager identity call if possible.

### simple MIG error or transport error

The exact request/reply becomes the next protocol boundary. Preserve the Snow control and Lion raw logs before designing any adaptation.

### complex reply with nonzero `outError`

Transport and MIG shape are compatible, but Lion coreservicesd rejected the initialization semantically. Preserve `outVersion`, `outError`, `outCount`, descriptor values, and session ID.

### descriptor/reply-shape mismatch

Do not infer a server policy error. Compare the Snow and Lion reply layouts first.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
LaunchApplicationServices service acquisition -> PASS
SessionGetInfo AuditInfo API adaptation -> PASS
combined pre-dispatch coexistence -> PASS
InitializeProcessesServices 0x4650 wire transaction -> next proof
```

No additional XNU change is indicated.


## Observed completed result

The Snow Leopard positive control and the Lion Phase F run both passed completely.

Lion sent the exact Snow Leopard PPC request after the two proven prerequisite adapters succeeded:

```text
LaunchApplicationServices port = 0x00008f03
security session ID            = 0x000186a3
security attributes            = 0x00002030
request bits                   = 0x00001513
request ID                     = 0x00004650
send size                      = 0x0000002c
receive size                   = 0x00000050
session1/session2              = 0x000186a3
requested version              = 0x00a1be40
```

Lion coreservicesd returned:

```text
mach_msg                       = KERN_SUCCESS
reply bits                     = 0x80001200
reply size                     = 0x00000048
reply ID                       = 0x000046b4
complex                        = YES
descriptor count               = 2
process port                   = 0x00008f03
port disposition               = 0x11
port type                      = 0x00
OOL address/size               = 0 / 0
OOL type                       = 0x01
remote NDR int rep             = 0x01
PPC local NDR int rep          = 0x00
outVersion                     = 0x00a1be40
outError                       = 0
outCount                       = 0
```

The Snow Leopard control produced the same successful reply shape and scalar values (with system-specific port/session names). This proves the Snow Leopard PPC InitializeProcessesServices wire contract is accepted unchanged by Lion once the already-proven CoreServices and Security prerequisites are restored.

No diagnostic was produced, protected identities remained unchanged, and the syscall-295 gate remained a clean EBADF/no-SIGSYS PASS.

The authoritative next stage is:

```text
docs/process-manager-launchservices-dispatch-setup-experiment.md
```

That stage invokes the already-audited Snow Leopard PPC LaunchServices `getProcessDispatchTable()` local function directly in a fresh process, allowing the real post-reply setup path to run while still stopping before every Process Manager identity API.

No additional XNU change is indicated.
