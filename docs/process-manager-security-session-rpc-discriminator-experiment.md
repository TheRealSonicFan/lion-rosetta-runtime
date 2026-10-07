# Process Manager Security session RPC discriminator experiment

## Objective

Identify the first failing legacy SecurityServer transaction behind Lion's translated-PPC `SessionGetInfo(callerSecuritySession,...)` status `1` before any Security compatibility adapter is designed.

The completed shipped-binary audit established two facts that supersede the earlier source-only arithmetic:

- Snow Leopard PPC `ucsp_client_getSessionInfo` sends request ID `0x428` (1064), not `0x429`; its send size is `0x24` and receive size is `0x74`.
- The same first public `SessionGetInfo` call performs legacy SecurityServer first-use activation before the `getSessionInfo` request. Visible client requests include `setup=0x3e8`, `setupNew=0x3e9`, `setupThread=0x3ea`, and `verifyPrivileged2=0x441`.

Lion's native i386 Security implementation uses `CommonCriteria::AuditInfo` instead. Lion securityd still exposes the legacy ucsp dispatcher and visible handlers for setup, setupThread, and verifyPrivileged2, while no visible `getSessionInfo` or `setupNew` server body was found.

Static evidence therefore cannot distinguish an earlier first-use failure from the retired session-information request. This experiment is the narrow live discriminator.

## What this experiment does

A new 32-bit PPC command-line subject calls only:

```text
SessionGetInfo(callerSecuritySession, ...)
```

A separate PPC `__DATA,__interpose` dylib passively records:

- the `com.apple.SecurityServer` `bootstrap_look_up` request/result;
- legacy Security ucsp `mach_msg` calls, including request ID, send/receive sizes, Mach return, reply ID/size, and the `0x20` reply word for simple MIG error replies.

The tracer never rewrites a service name, port, message header, message body, send size, receive size, or return value. Every call is forwarded to its original implementation through the replacee pointers in the interpose tuples.

This is intentionally separate from the proven CoreServices v3 adapter. No CarbonCore, LaunchServices process-services initialization, or Process Manager API is needed to exercise the Security boundary directly.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-security-session-rpc-probe.c
tests/ppc-process-manager-security-session-rpc-trace-interposer.c
scripts/build-ppc-process-manager-security-session-rpc-discriminator-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-security-session-rpc-discriminator-control.sh
scripts/run-lion-ppc-process-manager-security-session-rpc-discriminator.sh
docs/process-manager-security-session-rpc-discriminator-experiment.md
```

The tracer build ID is:

```text
security-session-rpc-trace-v1
```

## Safety constraints

For this experiment:

- build both PPC artifacts only on Snow Leopard 10.6.8;
- run exactly one Snow Leopard positive control before Lion;
- transfer the exact hashed artifacts to Lion;
- repeat the established Lion native commpage and syscall-295 safety gates before the PPC run;
- perform exactly one Lion PPC discriminator launch before review;
- use the tracer only through process-local `DYLD_INSERT_LIBRARIES`;
- leave `SECURITYSERVER` unset;
- do not use the CoreServices compatibility interposer in this experiment;
- do not call CarbonCore system-service acquisition;
- do not call LaunchServices process-services initialization;
- do not call Process Manager;
- do not call `SessionCreate` or modify Security session state;
- do not modify any SecurityServer Mach request or reply;
- do not restart, signal, suspend, or replace securityd;
- do not patch Security, securityd, libSystem, Rosetta, private dyld, the Rosetta cache, LaunchServices, or XNU;
- do not use GDB, DTrace, dtruss, or live code injection beyond the prepared pass-through interposer;
- do not rerun the Lion phase until the first report has been reviewed.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU repository:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the PPC subject and passive tracer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-security-session-rpc-discriminator-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-security-session-rpc-private-dyld
ppc-process-manager-security-session-rpc-private-dyld.info.txt
ppc-process-manager-security-session-rpc-private-dyld.sha256
ppc-process-manager-security-session-rpc-trace.dylib
ppc-process-manager-security-session-rpc-trace.dylib.info.txt
ppc-process-manager-security-session-rpc-trace.dylib.sha256
```

Require:

- the executable and tracer are 32-bit PPC;
- the executable uses `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- the executable links Security;
- the tracer contains exactly two PPC interpose tuples;
- the tracer build marker is `security-session-rpc-trace-v1`;
- the tracer imports `bootstrap_look_up` and `mach_msg`;
- the tracer does not import `dlsym`.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-security-session-rpc-discriminator-control.sh
```

Require the control to end in:

```text
PM_SECURITY_SESSION_TRACE_BOOTSTRAP_REPLY:... kr=0 ... servicePort=nonzero
PM_SECURITY_SESSION_TRACE_RPC_REQUEST:... name=getSessionInfo id=0x00000428 ...
PM_SECURITY_SESSION_STATUS:SessionGetInfo=0
PM_SECURITY_SESSION_VALUE:ID=nonzero ...
PM_SECURITY_SESSION_RESULT:PASS
RESULT: PASS
```

Preserve the complete control log. Its preceding trace records are also important because they show which first-use requests the exact shipped PPC client actually sends in a fresh process.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-security-session-rpc-private-dyld
ppc-process-manager-security-session-rpc-private-dyld.info.txt
ppc-process-manager-security-session-rpc-private-dyld.sha256
ppc-process-manager-security-session-rpc-trace.dylib
ppc-process-manager-security-session-rpc-trace.dylib.info.txt
ppc-process-manager-security-session-rpc-trace.dylib.sha256
ppc-process-manager-security-session-rpc-snowleopard-control.log
```

Place the executable, tracer, and sidecars under runtime `payload/`, or pass explicit paths to the Lion runner.

Do not rebuild either PPC artifact on Lion.

## Phase E — repeat Lion native safety gates

Use the already validated phase-2 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require `RESULT: PASS`.

Then run the established syscall-295 probe and preserve its log, using a discriminator-specific filename such as:

```text
syscall295-probe-process-manager-security-session-rpc-discriminator.log
```

Require the established EBADF/no-SIGSYS PASS.

Do not continue if either native safety gate fails.

## Phase F — one Lion Security-session discriminator run

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-security-session-rpc-discriminator.sh
```

The runner validates the kernel, translator, private dyld, Rosetta cache/map, Security cache membership, PPC artifacts, and protected hashes before and after the single launch.

Expected current high-level result is:

```text
PM_SECURITY_SESSION_STATUS:SessionGetInfo=1
RESULT: SECURITY_SESSION_STATUS1_RPC_TRACE_CAPTURED
```

Do not treat that status line alone as the result of the experiment. The decisive evidence is the ordered `PM_SECURITY_SESSION_TRACE_*` sequence immediately before it.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-security-session-rpc-snowleopard-control.log
lion-ppc-process-manager-security-session-rpc-discriminator.log
lion-ppc-process-manager-security-session-rpc-discriminator.raw.log
syscall295-probe-process-manager-security-session-rpc-discriminator.log
ppc-process-manager-security-session-rpc-private-dyld.info.txt
ppc-process-manager-security-session-rpc-private-dyld.sha256
ppc-process-manager-security-session-rpc-trace.dylib.info.txt
ppc-process-manager-security-session-rpc-trace.dylib.sha256
```

Also return every new crash report or core listed by the Lion runner, if any.

Do not upload the executable, tracer, Apple framework binaries, securityd, private dyld, or Rosetta cache unless a later review identifies one exact binary artifact as necessary.

## Result interpretation

Review the ordered Snow Leopard and Lion trace sequences request by request.

### Failure before a SecurityServer bootstrap port is obtained

The current boundary is SecurityServer lookup/launch registration, not the session RPC. Localize that lookup before any message adapter is considered.

### `verifyPrivileged2` (`0x441`) fails

The first-use privileged-server verification contract is the active boundary. Do not proceed to `getSessionInfo` adaptation.

### `setup` (`0x3e8`) or `setupNew` (`0x3e9`) fails

The Security client-session setup protocol is the active boundary. In particular, a live `setupNew=0x3e9` failure would explain why the static Lion audit's absence of a visible setupNew server body matters.

### `setupThread` (`0x3ea`) fails

The per-thread Security client setup contract is the active boundary.

### First-use succeeds and `getSessionInfo` (`0x428`) returns a simple MIG error

This closes the ambiguity. If the simple reply's `word0x20` is `-303` (`MIG_BAD_ID`), the retired legacy session-information RPC is directly proven as the immediate defect.

Only after that proof should a separate compatibility design reproduce Lion's correct session-information semantics for translated PPC code. Do not infer that the right fix is to revive the old securityd RPC; Lion's native Security implementation obtains this information through its later AuditInfo/kernel-backed path.

### `SessionGetInfo` unexpectedly succeeds on Lion

Stop. Preserve the exact trace and environment because it contradicts the previous pre-dispatch result; do not proceed to LaunchServices or Process Manager until the difference is explained.

## Current boundary

The active sequence remains:

```text
PPC execution / Rosetta -> PASS
syscall 295 -> PASS
LaunchServices PPC admission proof -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
CarbonCore FindService -> PASS
SessionGetInfo -> status 1 on Lion
Security first-use / session RPC substep -> unresolved
```

No additional XNU change is indicated.


## Observed result — failure is before every legacy Security RPC

The completed Snow Leopard control and Lion discriminator resolve the first-use ambiguity.

Snow Leopard 10.6.8:

- `bootstrap_look_up("com.apple.SecurityServer")` returns `kr=0` with a nonzero service port;
- `verifyPrivileged2 (0x441)` completes;
- `setup (0x3e8)` completes;
- `getSessionInfo (0x428)` completes;
- `SessionGetInfo` returns 0 with nonzero session ID/attributes;
- `RESULT: PASS`.

Lion 10.7.5:

- the tracer reaches the same `bootstrap_look_up("com.apple.SecurityServer")`;
- that lookup returns `kr=-304` / `MIG_BAD_ARGUMENTS`;
- the service port remains zero;
- no `verifyPrivileged2`, setup, setupThread, or `getSessionInfo` request is sent;
- `SessionGetInfo` then returns status 1 with zero session ID/attributes;
- no crash/core is generated and protected hashes remain unchanged.

This supersedes the earlier leading `getSessionInfo` hypothesis as the **immediate** live failure. The retired `getSessionInfo` RPC may still become a later boundary after first-use lookup is repaired, but it was not reached in this run.

The result also matches the already-proven launchd lookup protocol evolution from the earlier Process Manager bootstrap work: Snow Leopard PPC emits the legacy `0xac` `vproc_mig_look_up2` request, while Lion expects the UUID-expanded `0xbc` form. The previous standalone Lion-format lookup proof already established that the UUID-expanded shape is accepted by Lion for another service.

The authoritative next stage is therefore:

```text
docs/process-manager-securityserver-bootstrap-protocol-adapter-experiment.md
```

That experiment changes only the service name/flags case that remains unproven: it sends one Lion-format `0xbc` lookup for `com.apple.SecurityServer`, target PID 0, zero instance UUID, flags 0, and stops without calling Security.
