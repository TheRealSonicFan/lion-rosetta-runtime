# Process Manager pre-dispatch full compatibility integration experiment

## Objective

Re-run the original pre-dispatch primitive sequence with the two independently proven compatibility layers active at the same time:

1. `dual-bootstrap-servercheckin-v3` for CarbonCore's coreservicesd bootstrap lookup and ServerCheckin request shape;
2. `security-session-auditinfo-api-v1` for `SessionGetInfo(callerSecuritySession,...)` using typed Lion AuditInfo semantics.

This is a coexistence/integration proof only. It still stops before LaunchServices `_LSDoInitializeProcessesServices` and before every Process Manager identity API.

## Why this is the next stage

The investigation now has independent Lion passes for each prerequisite:

- CoreServices: adapted coreservicesd lookup -> adapted ServerCheckin -> unmodified CarbonCore `FindService("LaunchApplicationServices")` -> nonzero service port;
- Security: one-tuple `SessionGetInfo` adapter -> `getaudit_addr` -> typed `ai_asid` / `ai_flags` -> public `SessionGetInfo=0` with matching returned values.

The completed Security adapter proof showed the translated PPC layout explicitly:

```text
sizeof(auditinfo_addr_t)=0x30
ai_asid offset=0x24
ai_flags offset=0x28
ai_flags size=0x08
raw word 0x28=0x00000000
raw word 0x2c=0x00002030
typed flagsLow=0x00002030
```

Therefore the old SecurityServer `getSessionInfo=0x428` RPC is no longer part of the required `callerSecuritySession` path.

The only remaining question before advancing into LaunchServices process-services initialization is whether the already-proven CoreServices and Security adapters coexist correctly in the real pre-dispatch subject.

## Prepared files

```text
tests/ppc-process-manager-predispatch-preflight.c
tests/ppc-process-manager-coreservices-compat-interposer.c
tests/ppc-process-manager-security-session-auditinfo-api-interposer.c
scripts/build-ppc-process-manager-predispatch-compat-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-predispatch-full-compat-integration-control.sh
scripts/run-lion-ppc-process-manager-predispatch-full-compat-integration.sh
docs/process-manager-predispatch-full-compat-integration-experiment.md
```

Compatibility identities:

```text
CoreServices: dual-bootstrap-servercheckin-v3
Security:     security-session-auditinfo-api-v1
```

No merged interposer is introduced in this stage. The two already-proven dylibs are loaded together. They interpose disjoint APIs.

## Safety constraints

- build PPC artifacts only on Snow Leopard 10.6.8;
- require a combined Snow Leopard passthrough control before Lion;
- use only process-local `DYLD_INSERT_LIBRARIES`;
- CoreServices mode on Lion: `lion-dual-adapter`;
- Security mode on Lion: `lion-auditinfo-v1`;
- adapt only the exact proven CoreServices bootstrap/ServerCheckin transactions;
- adapt only `SessionGetInfo(callerSecuritySession,...)`;
- do not load the SecurityServer bootstrap compatibility interposer;
- do not revive or synthesize the retired SecurityServer `getSessionInfo` RPC;
- do not call `SessionCreate`, `setaudit_addr`, or `auditon`;
- do not call `_LSDoInitializeProcessesServices`;
- do not call `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, or another Process Manager identity API;
- do not use `SCDontUseServer`;
- do not patch CarbonCore, Security, LaunchServices, libSystem, Rosetta, dyld, the cache, launchd, coreservicesd, securityd, or XNU;
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

No XNU rebuild or reboot is part of this stage.

## Phase B — prepare the pre-dispatch and CoreServices artifacts on Snow Leopard

Build the pre-dispatch subject and the v3 CoreServices interposer:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-predispatch-compat-integration-on-snowleopard.sh \
  ./ppc-process-manager-predispatch-full-compat-private-dyld \
  ./ppc-process-manager-coreservices-compat-interposer.dylib
```

This produces:

```text
ppc-process-manager-predispatch-full-compat-private-dyld
ppc-process-manager-predispatch-full-compat-private-dyld.info.txt
ppc-process-manager-predispatch-full-compat-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
```

For the Security adapter, reuse the exact artifact that passed the immediately preceding experiment:

```text
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Do not silently substitute an older Security dylib. Require build ID:

```text
security-session-auditinfo-api-v1
```

If that exact artifact is unavailable, return to `docs/process-manager-security-session-auditinfo-api-adapter-experiment.md`, rebuild it on Snow Leopard, and require its Snow passthrough control before continuing.

## Phase C — combined Snow Leopard passthrough control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-predispatch-full-compat-integration-control.sh \
  ./ppc-process-manager-predispatch-full-compat-private-dyld \
  ./ppc-process-manager-predispatch-full-compat-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-predispatch-full-compat-snowleopard-control.log
```

The runner loads both dylibs together with both modes set to `passthrough`.

Require:

```text
PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=1 mode=passthrough
PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=1 mode=passthrough
PM_PREDISPATCH_PORT:LaunchApplicationServices=nonzero
PM_SECURITY_SESSION_API_COMPAT_CALL:index=1 mode=passthrough requested=0xffffffff targetCaller=YES
PM_SECURITY_SESSION_API_COMPAT_PASSTHROUGH_RETURN:status=0 ...
PM_PREDISPATCH_STATUS:SessionGetInfo=0
PM_PREDISPATCH_SESSION:ID=nonzero ...
PM_PREDISPATCH_RESULT:PREDISPATCH_PRIMITIVES_PASS
RESULT: PASS
```

This proves that both process-local layers can coexist without altering Snow Leopard behavior.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-predispatch-full-compat-private-dyld
ppc-process-manager-predispatch-full-compat-private-dyld.info.txt
ppc-process-manager-predispatch-full-compat-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-predispatch-full-compat-snowleopard-control.log
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

Run the established native commpage probe and require its existing PASS.

Then run the syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-predispatch-full-compat-integration.log
```

Require EBADF and no SIGSYS.

## Phase F — one Lion pre-dispatch run with both adapters

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-predispatch-full-compat-integration.sh
```

The runner loads:

```text
CoreServices adapter -> lion-dual-adapter
Security API adapter -> lion-auditinfo-v1
```

Require the ordered boundary:

```text
CoreServices bootstrap adapter -> PASS
ServerCheckin adapter -> PASS
LaunchApplicationServices port -> nonzero
Security SessionGetInfo API adapter -> typed AuditInfo read PASS
SessionGetInfo -> 0
security session ID -> nonzero
PREDISPATCH_PRIMITIVES_PASS
RESULT: PREDISPATCH_FULL_COMPAT_PRIMITIVES_PASS
```

Do not rerun before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-predispatch-full-compat-integration.log
lion-ppc-process-manager-predispatch-full-compat-integration.raw.log
syscall295-probe-process-manager-predispatch-full-compat-integration.log
ppc-process-manager-predispatch-full-compat-snowleopard-control.log
ppc-process-manager-predispatch-full-compat-private-dyld.info.txt
ppc-process-manager-predispatch-full-compat-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return any diagnostic named by the Lion runner.

## Result interpretation

### `PREDISPATCH_FULL_COMPAT_PRIMITIVES_PASS`

Both proven user-space compatibility layers coexist in the real prerequisite sequence. CoreServices service acquisition and Lion-semantic security-session discovery are then closed together.

The next controlled stage is the first `_LSDoInitializeProcessesServices` boundary test, using the same two compatibility layers and still stopping before Process Manager identity calls.

Do not merge or broaden the compatibility interposers yet; first determine whether the existing Snow Leopard PPC LaunchServices request succeeds unchanged against Lion.

### CoreServices failure

Preserve the raw log. Do not reinterpret the Security adapter.

### Security adapter failure

Preserve typed AuditInfo diagnostics. Do not fall back to SecurityServer RPC emulation.

### crash/diagnostic

Preserve it and stop.

## Current boundary

```text
XNU syscall 295 compatibility -> PASS
CoreServices bootstrap UUID adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
CarbonCore FindService("LaunchApplicationServices") -> PASS
legacy SecurityServer getSessionInfo 0x428 -> MIG_BAD_ID
translated PPC typed AuditInfo read -> PASS
SessionGetInfo(callerSecuritySession) AuditInfo API adapter -> PASS
combined pre-dispatch coexistence -> next proof
```

No additional XNU change is indicated.
