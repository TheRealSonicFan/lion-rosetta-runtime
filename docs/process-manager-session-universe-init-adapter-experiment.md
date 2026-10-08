# Process Manager SCSessionUniverse InitConnection compatibility adapter experiment

## Objective

Test one narrowly-scoped user-space compatibility repair for the exact CarbonCore `SCSessionUniverseInitConnection_rpc` request mismatch now proven between Snow Leopard PPC and Lion.

The experiment keeps all previously proven components unchanged except for a new version of the process-local CoreServices interposer. The new interposer retains the proven bootstrap and ServerCheckin adaptations and adds one exact `mach_msg` request rewrite for `SCSessionUniverseInitConnection_rpc`.

The subject remains the already-proven post-dispatch PPC probe and still calls exactly one:

```text
GetProcessForPID(getpid(), &psn)
```

It stops immediately after that identity result. No foreground conversion, window creation, event loop, or second Process Manager identity API is added.

## Proven wire mismatch

The completed protocol audit proves that both releases use the same InitConnection request ID:

```text
request ID = 0x00002712
reply ID   = 0x00002776
receive    = 0x00000034
```

Snow Leopard PPC sends:

```text
send size = 0x2c

0x00..0x17  Mach message header
0x18..0x1f  NDR record
0x20        PID
0x24        UID
0x28        architecture/layout discriminator
```

Snow Leopard's generated dispatcher requires `msgh_size == 0x2c`.

Lion native CarbonCore sends:

```text
send size = 0x28

0x00..0x17  Mach message header
0x18..0x1f  NDR record
0x20        UID
0x24        architecture/layout discriminator
```

Lion's generated dispatcher requires `msgh_size == 0x28`. A size mismatch takes the generated MIG bad-arguments path and writes:

```text
0xfffffed0 = -304 = MIG_BAD_ARGUMENTS
```

The reply contract does not require translation for this experiment. Both client families expect reply ID `0x2776` and accept the same `0x2c` success / `0x24` error shapes.

The Lion native server also receives an audit token and derives caller identity server-side, so the removed legacy PID field is not copied elsewhere into the Lion request.

This closes the wire-causality question behind the preserved translated-PPC `0xd0feffff` / `-304` value and the subsequent null-universe SIGBUS.

## Compatibility design under test

Current runtime `main` adds:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-coreservices-sessioninit-compat-interposer-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-session-universe-init-adapter-control.sh
scripts/run-lion-ppc-process-manager-session-universe-init-adapter.sh
```

The new interposer build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v4
```

It still has exactly two `__DATA,__interpose` tuples:

```text
bootstrap_look_up2
mach_msg
```

For the InitConnection path it first captures the nonzero per-session CoreServices port returned by the already-proven ServerCheckin transaction. It then considers a message an InitConnection candidate only when both are true:

```text
remote port == captured CoreServices session port
message ID  == 0x00002712
```

The exact legacy request additionally requires:

```text
option      = 0x00000003
send size   = 0x0000002c
receive     = 0x00000034
bits        = 0x00001513
header size = 0x0000002c
timeout     = none
notify      = null
```

In the Lion adaptation mode it performs only:

```text
legacy PID    @ 0x20 -> dropped
legacy UID    @ 0x24 -> Lion UID    @ 0x20
legacy layout @ 0x28 -> Lion layout @ 0x24
msgh_size     0x2c   -> 0x28
mach_msg send 0x2c   -> 0x28
```

The NDR record, ports, request ID, options, receive size, and reply buffer are left unchanged. The reply is not rewritten.

The new mode is:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
```

The older proven `dual-bootstrap-servercheckin-v3` source remains unchanged and available for historical reproduction.

## Safety constraints

- do not set `LSDONOTABORTIFNOASN`;
- do not patch CarbonCore, LaunchServices, HIServices, CoreFoundation, coreservicesd, dyld, Rosetta, or the shared cache;
- do not restart or signal coreservicesd;
- do not send any standalone hand-built InitConnection request;
- do not adapt MapSharedSegment or Disconnect in this stage;
- do not broaden the Security adapter;
- do not change XNU;
- do not use live GDB, DTrace, or dtruss;
- do not proceed to Lion if the Snow Leopard build or passthrough control fails.

## Repository-side verification before execution

The prepared changes were re-fetched from current `main` and checked before this runbook was made authoritative:

- the new build, Snow control, and Lion runner pass `bash -n` syntax validation;
- the v4 C source has balanced C delimiters, exactly one `__DATA,__interpose` section with exactly two tuples, and no `dlsym`;
- the original v3 CoreServices source remains unchanged with build ID `dual-bootstrap-servercheckin-v3`;
- the v4 source uses a distinct build ID `dual-bootstrap-servercheckin-sessioninit-v4`;
- the v4 source recognizes only request ID `0x2712` on the captured session port and does not add a MapSharedSegment adapter.

The actual PowerPC C compile/link cannot be reproduced off Snow Leopard. Phase B is therefore the mandatory compiler/toolchain validation gate; do not proceed if it fails.

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

No kernel rebuild or reboot is part of this experiment.

## Phase B — build only the new v4 CoreServices interposer on Snow Leopard

Reuse the exact already-proven post-dispatch executable and Security adapter:

```text
ppc-process-manager-postdispatch-getprocessforpid-private-dyld
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Build the new v4 CoreServices interposer:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-compat-interposer-on-snowleopard.sh
```

Expected new outputs:

```text
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256
```

Require:

- 32-bit PPC;
- build ID `dual-bootstrap-servercheckin-sessioninit-v4`;
- exactly two PPC interpose tuples / `__DATA,__interpose` size `0x10`;
- imports/references for `bootstrap_look_up2`, `mach_msg`, and `mig_get_reply_port`;
- no `dlsym`;
- ServerCheckin PASS marker;
- SessionInit PASS marker;
- all three output files created.

The builder clears stale outputs before starting and deletes partial outputs if any validation gate fails.

If the already-proven post-dispatch executable is no longer available, rebuild it with its existing builder and require its existing Snow control before using it here. Do not manufacture missing SHA/info sidecars manually.

If Phase B fails, stop and return the complete build output. Do not proceed to Phase C or Lion.

## Phase C — Snow Leopard passthrough control

Run from the logged-in user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-session-universe-init-adapter-control.sh \
  ./ppc-process-manager-postdispatch-getprocessforpid-private-dyld \
  ./ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-session-universe-init-adapter-snowleopard-control.log
```

Both compatibility layers are in passthrough mode.

Require, in addition to all prior post-dispatch control markers:

```text
PM_CORESERVICES_COMPAT_BUILD_ID:dual-bootstrap-servercheckin-sessioninit-v4
PM_CORESERVICES_COMPAT_SESSION_PORT:source=passthrough port=nonzero
PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=1 mode=passthrough ...
PM_CORESERVICES_COMPAT_SESSIONINIT_PASSTHROUGH_RETURN:kr=0 hex=0x00000000
PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID
PM_POSTDISPATCH_STATUS:GetProcessForPID=0
PM_POSTDISPATCH_PSN:... low=nonzero
PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS
RESULT: PASS
```

This is a hard gate. It proves that the new v4 interposer observes the exact Snow InitConnection transaction but remains transparent on Snow Leopard.

If Phase C fails for any reason, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer the exact accepted artifacts:

```text
ppc-process-manager-postdispatch-getprocessforpid-private-dyld
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256

ppc-process-manager-session-universe-init-adapter-snowleopard-control.log
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

Then run the syscall-295 probe and preserve its output as:

```text
syscall295-probe-process-manager-session-universe-init-adapter.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion adapter run

From the logged-in Lion user's Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-session-universe-init-adapter.sh
```

The runner enables exactly:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

and explicitly requires `LSDONOTABORTIFNOASN` to be unset.

Before accepting an identity result, the runner requires:

```text
CoreServices bootstrap adapter -> PASS
CoreServices ServerCheckin adapter -> PASS
PM_CORESERVICES_COMPAT_SESSION_PORT:source=adapter port=nonzero
Security AuditInfo SessionGetInfo adapter -> PASS
dispatch table -> nonzero
process-services port -> nonzero

PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:
  index=1
  mode=lion-dual-sessioninit-adapter

PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REQUEST:
  id=0x00002712
  legacySend=0x0000002c
  adaptedSend=0x00000028
  recv=0x00000034

PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_MACH_MSG:
  kr=0
  hex=0x00000000

PM_CORESERVICES_COMPAT_SESSIONINIT_ADAPTER_REPLY:
  size=0x0000002c
  id=0x00002776
  retcodeRaw=0x00000000

PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS
```

### Best-case result

If the exact InitConnection repair also allows the original identity call to complete:

```text
PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID
PM_POSTDISPATCH_STATUS:GetProcessForPID=0
PM_POSTDISPATCH_PSN:... low=nonzero
PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS
RESULT: SESSIONINIT_ADAPTER_GETPROCESSFORPID_PASS
```

### Adapter passes, later boundary fails

If `PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS` appears but `GetProcessForPID` still does not complete, preserve the new crash/core diagnostic. The runner distinguishes SIGABRT from other termination. Do not assume MapSharedSegment is next without reviewing that evidence.

### InitConnection still rejected

If the exact adapter request is sent but the Lion reply is not the proven successful `0x2c / 0x2776 / RetCode=0` shape, stop. Do not broaden the rewrite.

Run Phase F only once before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-session-universe-init-adapter.log
lion-ppc-process-manager-session-universe-init-adapter.raw.log
syscall295-probe-process-manager-session-universe-init-adapter.log
ppc-process-manager-session-universe-init-adapter-snowleopard-control.log
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new crash/core diagnostic named by the Lion runner.

## Result interpretation

### `SESSIONINIT_ADAPTER_GETPROCESSFORPID_PASS`

The CarbonCore InitConnection compatibility boundary is closed and the first real shell-launched Process Manager identity call is restored without the no-ASN override.

Do not immediately broaden the compatibility layer. The next stage should be chosen from the first API/state boundary reached after the returned PSN is reviewed.

### `SESSIONINIT_ADAPTER_PASS_THEN_...`

The InitConnection mismatch is closed, but another later boundary remains. Use the new returned/crash evidence to identify that boundary before writing another adapter.

### InitConnection adapter failure

Treat this as an adapter/request-shape defect. Do not proceed to any downstream Process Manager experiment.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo adaptation -> PASS
LaunchServices process-dispatch setup -> PASS
GetProcessForPID -> enters registration/check-in
legacy InitConnection 0x2712 / 0x2c -> proven rejected by Lion 0x28 dispatcher with MIG_BAD_ARGUMENTS
request-only InitConnection compatibility adapter -> next live proof
```

No additional XNU change is indicated.
