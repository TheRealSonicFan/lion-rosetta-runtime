# Process Manager Security session bootstrap compatibility integration experiment

## Objective

Integrate only the independently proven Lion-format SecurityServer bootstrap lookup into the Security-only `SessionGetInfo` discriminator, then let the untouched Snow Leopard PPC Security client continue far enough to expose the next real first-use/session boundary.

The previous two experiments now establish:

1. Without adaptation, Lion's translated PPC `SessionGetInfo` fails at `bootstrap_look_up("com.apple.SecurityServer")` with `-304` / `MIG_BAD_ARGUMENTS`, before any Security ucsp request is sent.
2. A standalone PPC Lion-format lookup for `com.apple.SecurityServer` using request ID `0x194`, send size `0xbc`, zero instance UUID, target PID 0, and flags 0 succeeds and returns a nonzero SecurityServer port.

The bootstrap defect is therefore proven independently. The next question is what untouched Snow Leopard PPC Security does after that single lookup is repaired.

## Scope

The prepared compatibility dylib has exactly two process-local interpose tuples:

- `bootstrap_look_up`;
- `mach_msg`.

For the exact service `com.apple.SecurityServer`:

- Snow Leopard control mode passes the ordinary `bootstrap_look_up` through unchanged.
- Lion mode replaces only that lookup with the already-proven `0xbc` request shape, using target PID 0, zero instance UUID, and flags 0.

All Security ucsp `mach_msg` requests are forwarded unchanged. The second tuple records their request/reply metadata so the first subsequent incompatibility can be identified.

The adapter does not rewrite `verifyPrivileged2`, setup, setupThread, setupNew, or `getSessionInfo`.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-security-session-rpc-probe.c
tests/ppc-process-manager-security-session-bootstrap-compat-interposer.c
scripts/build-ppc-process-manager-security-session-bootstrap-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-security-session-bootstrap-compat-control.sh
scripts/run-lion-ppc-process-manager-security-session-bootstrap-compat.sh
docs/process-manager-security-session-bootstrap-compat-integration-experiment.md
```

The compatibility build ID is:

```text
security-session-bootstrap-compat-v1
```

The mode variable exists only inside the launched test process:

```text
ROSETTA_SECURITY_SESSION_COMPAT_MODE
```

Allowed values are:

```text
passthrough
lion-bootstrap-v1
```

## Safety constraints

For this experiment:

- build both PPC artifacts only on Snow Leopard 10.6.8;
- run exactly one Snow Leopard positive control before Lion;
- transfer the exact hashed artifacts;
- repeat the established Lion native commpage and syscall-295 gates;
- run exactly one Lion Security-session integration attempt before review;
- leave `SECURITYSERVER` unset;
- do not use the CoreServices compatibility interposer in this Security-only experiment;
- do not patch Security, securityd, libSystem, launchd, Rosetta, dyld, the Rosetta cache, or XNU;
- do not modify any Security ucsp request or reply;
- do not restart, signal, suspend, or replace securityd;
- do not call `SessionCreate`;
- do not use GDB, DTrace, dtruss, or system-wide injection;
- stop after the first Lion report and do not rerun until reviewed.

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

## Phase B — build on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-security-session-bootstrap-compat-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-security-session-bootstrap-compat-private-dyld
ppc-process-manager-security-session-bootstrap-compat-private-dyld.info.txt
ppc-process-manager-security-session-bootstrap-compat-private-dyld.sha256
ppc-process-manager-security-session-bootstrap-compat.dylib
ppc-process-manager-security-session-bootstrap-compat.dylib.info.txt
ppc-process-manager-security-session-bootstrap-compat.dylib.sha256
```

Require:

- both artifacts are 32-bit PPC;
- the probe uses `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- the probe links Security;
- the compatibility dylib contains exactly two PPC interpose tuples;
- the build marker is `security-session-bootstrap-compat-v1`;
- it imports `bootstrap_look_up`, `mach_msg`, and `mig_get_reply_port`;
- it does not import `dlsym`.

If the build fails, stop and return the full build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-security-session-bootstrap-compat-control.sh
```

Require:

```text
PM_SECURITY_COMPAT_BOOTSTRAP_EXACT_CALL:... mode=passthrough ...
PM_SECURITY_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=0 ... servicePort=nonzero
PM_SECURITY_COMPAT_RPC_REQUEST:... name=verifyPrivileged2 id=0x00000441 ...
PM_SECURITY_COMPAT_RPC_REQUEST:... name=setup id=0x000003e8 ...
PM_SECURITY_COMPAT_RPC_REQUEST:... name=getSessionInfo id=0x00000428 ...
PM_SECURITY_SESSION_STATUS:SessionGetInfo=0
PM_SECURITY_SESSION_RESULT:PASS
RESULT: PASS
```

The control validates that the new interposer is observationally transparent on the working Snow Leopard path.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-security-session-bootstrap-compat-private-dyld
ppc-process-manager-security-session-bootstrap-compat-private-dyld.info.txt
ppc-process-manager-security-session-bootstrap-compat-private-dyld.sha256
ppc-process-manager-security-session-bootstrap-compat.dylib
ppc-process-manager-security-session-bootstrap-compat.dylib.info.txt
ppc-process-manager-security-session-bootstrap-compat.dylib.sha256
ppc-process-manager-security-session-bootstrap-compat-snowleopard-control.log
```

Place the executable, dylib, and sidecars under runtime `payload/`, or pass explicit paths to the Lion runner.

Do not rebuild them on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require `RESULT: PASS`.

Then run the syscall-295 probe, preserving it as:

```text
syscall295-probe-process-manager-security-session-bootstrap-compat.log
```

Require the existing EBADF/no-SIGSYS PASS.

Do not continue if either native gate fails.

## Phase F — one Lion Security-session run with only bootstrap compatibility enabled

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-security-session-bootstrap-compat.sh
```

The runner enables only:

```text
ROSETTA_SECURITY_SESSION_COMPAT_MODE=lion-bootstrap-v1
```

inside the test process.

Require the report to prove:

```text
PM_SECURITY_COMPAT_BOOTSTRAP_ADAPTER_RESULT:PASS servicePort=nonzero
```

After that point, the decisive evidence is the ordered `PM_SECURITY_COMPAT_RPC_*` sequence and the final `SessionGetInfo` status.

The runner will classify a completed capture as one of:

```text
RESULT: SECURITY_SESSION_AFTER_BOOTSTRAP_PASS
RESULT: SECURITY_SESSION_AFTER_BOOTSTRAP_STATUS1_TRACE_CAPTURED
```

Either is an analyzable experiment completion. Do not rerun before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-security-session-bootstrap-compat-snowleopard-control.log
lion-ppc-process-manager-security-session-bootstrap-compat.log
lion-ppc-process-manager-security-session-bootstrap-compat.raw.log
syscall295-probe-process-manager-security-session-bootstrap-compat.log
ppc-process-manager-security-session-bootstrap-compat-private-dyld.info.txt
ppc-process-manager-security-session-bootstrap-compat-private-dyld.sha256
ppc-process-manager-security-session-bootstrap-compat.dylib.info.txt
ppc-process-manager-security-session-bootstrap-compat.dylib.sha256
```

Also return every new crash report or core listed by the Lion runner, if any.

Do not upload the executable, dylib, Apple Security binary, securityd, private dyld, or Rosetta cache unless later analysis identifies one exact binary artifact as necessary.

## Result interpretation

### `SECURITY_SESSION_AFTER_BOOTSTRAP_PASS`

The standalone SecurityServer bootstrap defect was sufficient to explain the current Security-session failure. Untouched Snow Leopard PPC Security completed all subsequent first-use/session work on Lion.

If this occurs, the next stage is integration with the already-proven CoreServices compatibility layer before resuming LaunchServices process-services initialization. Do not design a Security ucsp adapter.

### `verifyPrivileged2 (0x441)` is the first failing RPC

The next compatibility defect is SecurityServer client verification. Preserve the exact reply and do not continue to setup/getSessionInfo adaptation.

### `setup (0x3e8)`, `setupNew (0x3e9)`, or `setupThread (0x3ea)` is the first failing RPC

That exact first-use setup transaction becomes the next boundary. Preserve its raw reply.

### `getSessionInfo (0x428)` is reached and returns a simple MIG error

The earlier retired-session-RPC hypothesis becomes live only at this point. If the `0x24` simple reply contains `word0x20=-303`, then `MIG_BAD_ID` is directly proven for the shipped Lion server path.

Only after that observation should a session-information compatibility design be considered.

### crash/abort after bootstrap success

Preserve diagnostics and stop. Do not assume the last logged RPC caused the crash without correlating the report/core.

## Current boundary

The independently proven sequence is:

```text
PPC execution / Rosetta -> PASS
syscall 295 -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
CarbonCore FindService -> PASS
Security SessionGetInfo entry -> reached
legacy SecurityServer bootstrap request on Lion -> MIG_BAD_ARGUMENTS
Lion-format SecurityServer bootstrap request -> PASS
post-bootstrap untouched Security first-use/session path -> unresolved
```

No additional XNU change is indicated.


## Observed result — legacy getSessionInfo is rejected with MIG_BAD_ID

The completed Snow Leopard control remained fully transparent: SecurityServer lookup, `verifyPrivileged2`, setup, and `getSessionInfo (0x428)` all completed, and `SessionGetInfo` returned status 0 with nonzero session data.

On Lion, the proven SecurityServer bootstrap adaptation succeeded and returned a nonzero service port. The untouched Snow Leopard PPC Security client then proceeded further:

- `verifyPrivileged2 (0x441)` returned Mach success with the expected complex reply;
- `setup (0x3e8)` returned Mach success with RetCode 0;
- `getSessionInfo (0x428)` was finally sent;
- Mach transport itself returned success;
- the reply was a non-complex `0x24` MIG error reply with reply ID `0x48c`;
- the tracer observed raw offset-`0x20` word `0xd1feffff`;
- `SessionGetInfo` then returned status 1.

The shipped Snow Leopard PPC generated stub explicitly checks the reply NDR integer representation and performs a byte swap on the `0x20` error word when the server's representation differs. Applying that exact generated-client behavior to `0xd1feffff` yields `0xfffffed1`, which is signed `-303` / `MIG_BAD_ID`.

Therefore the retired legacy `getSessionInfo=0x428` routine is now directly proven as the next live incompatibility after bootstrap adaptation. The failure is not `verifyPrivileged2`, setup, Mach transport, or another XNU routing defect.

Lion's native `SessionGetInfo(callerSecuritySession,...)` does not send this RPC. Its shipped implementation calls `CommonCriteria::AuditInfo::get()`, which calls `getaudit_addr(..., 0x30)`, and then returns the words at structure offsets `0x24` and `0x28` as the public session ID and attribute bits.

The authoritative next stage is:

```text
docs/process-manager-security-session-auditinfo-oracle-experiment.md
```

That experiment first proves the `SessionGetInfo <-> getaudit_addr` field mapping on Snow Leopard and native Lion i386, then calls only `getaudit_addr` from translated PPC on Lion. It does not interpose `SessionGetInfo`, revive the old securityd RPC, or modify any system component.

Do not design the final SessionGetInfo compatibility shim until the translated-PPC AuditInfo oracle result is reviewed.
