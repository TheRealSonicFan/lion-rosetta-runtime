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
dual-bootstrap-servercheckin-sessioninit-v5
```

It still has exactly two `__DATA,__interpose` tuples:

```text
bootstrap_look_up2
mach_msg
```

The InitConnection transaction does **not** use the port descriptor returned inside the ServerCheckin reply. Earlier dynamic controls already proved that CarbonCore's private `scGetServerCheckinPort()` returns the original nonzero coreservicesd service/check-in port obtained by `bootstrap_look_up2`; the separate descriptor carried by the ServerCheckin reply is a different port.

The v5 interposer therefore records both values but routes InitConnection only on the already-proven coreservicesd server/check-in port. It considers a message an InitConnection candidate only when both are true:

```text
remote port == coreservicesd server/check-in port from bootstrap lookup
message ID  == 0x00002712
```

The exact legacy request additionally requires:

```text
option      = 0x00000003
send size   = 0x0000002c
receive     = 0x00000034
bits        = 0x00001513
reply port  = mach_msg receive port
timeout     = none
notify      = null
```

It deliberately does **not** require the pre-send `msgh_size` word to equal `0x2c`. The generated Snow PPC client passes `0x2c` as the `mach_msg` send-size argument but does not initialize `msgh_size` before the call; the receive path later overwrites that header field with the reply size. The `mach_msg` send-size argument is therefore the authoritative legacy-size discriminator.

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

The corrected v5 changes were re-fetched from current `main` after all edits and checked as a unit:

- the C source has balanced braces/parentheses/brackets, exactly one `__DATA,__interpose` declaration with exactly two tuples, and no `dlsym`;
- the active InitConnection candidate matches request ID `0x2712` against `gCoreServicesServerPort`, not the separately recorded ServerCheckin reply descriptor;
- the invalid pre-send `msgh_size == 0x2c` matcher is absent;
- the v5 route and ServerCheckin-reply diagnostics are present in the source and are required by the build/control runners;
- the build, Snow control, and Lion runner all require build ID `dual-bootstrap-servercheckin-sessioninit-v5`, contain no active v4 build-ID reference, and their shell control structures are balanced;
- the old ambiguous `PM_CORESERVICES_COMPAT_SESSION_PORT` marker is absent from the active v5 source/runners;
- no MapSharedSegment adapter was added.

The actual PowerPC C compile/link and real shell execution cannot be reproduced off Snow Leopard. Phase B and then Phase C remain the mandatory compiler/runtime validation gates; do not proceed if either fails.

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

## Phase B — build only the new v5 CoreServices interposer on Snow Leopard

Reuse the exact already-proven post-dispatch executable and Security adapter:

```text
ppc-process-manager-postdispatch-getprocessforpid-private-dyld
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.info.txt
ppc-process-manager-postdispatch-getprocessforpid-private-dyld.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Build the new v5 CoreServices interposer:

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
- build ID `dual-bootstrap-servercheckin-sessioninit-v5`;
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
PM_CORESERVICES_COMPAT_BUILD_ID:dual-bootstrap-servercheckin-sessioninit-v5
PM_CORESERVICES_COMPAT_SERVERCHECKIN_REPLY_PORT:source=passthrough port=nonzero
PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:index=1 mode=passthrough ...
PM_CORESERVICES_COMPAT_SESSIONINIT_ROUTE:remotePort=... serverCheckinPort=... serverCheckinReplyPort=...
PM_CORESERVICES_COMPAT_SESSIONINIT_PASSTHROUGH_RETURN:kr=0 hex=0x00000000
PM_POSTDISPATCH_MILESTONE:M06_AFTER_GetProcessForPID
PM_POSTDISPATCH_STATUS:GetProcessForPID=0
PM_POSTDISPATCH_PSN:... low=nonzero
PM_POSTDISPATCH_RESULT:GETPROCESSFORPID_PASS
RESULT: PASS
```

This is a hard gate. It proves that the new v5 interposer observes the exact Snow InitConnection transaction but remains transparent on Snow Leopard.

If Phase C fails for any reason, stop. Do not run Lion.

## Observed first Phase C failure and correction

The first v4 Snow Leopard control failed only at the new SessionInit-observation gate. The underlying PPC subject completed normally: the v4 interposer loaded, the bootstrap lookup returned a nonzero coreservicesd port, ServerCheckin passthrough completed and exposed a nonzero reply descriptor, Security passthrough completed, and `GetProcessForPID` returned status 0 with a nonzero PSN. The runner nevertheless ended `RESULT: FAIL` because no `PM_CORESERVICES_COMPAT_SESSIONINIT_*` marker appeared.

That failure exposed two harness assumptions, not a Snow Leopard compatibility failure.

First, v4 incorrectly treated the port descriptor returned inside the ServerCheckin reply as CarbonCore's later "server check-in port." Existing dynamic evidence proves they are distinct: on Snow Leopard the bootstrap/service/check-in port is `0x00002003`, while the ServerCheckin reply descriptor is `0x00002103`; on the prior Lion integration they were likewise `0x00009103` and `0x00009203`. CarbonCore's private `scGetServerCheckinPort()` returned the former value in both systems. InitConnection therefore targets the original coreservicesd server/check-in port, not the ServerCheckin reply descriptor.

Second, v4 required the pre-send message-header `msgh_size` field to equal `0x2c`. The generated Snow PPC InitConnection client does not initialize that field before calling `mach_msg`; it passes `0x2c` as the function's send-size argument. Requiring the header word would have rejected the exact legacy call even after correcting the port routing.

Current v5 corrects both issues while remaining narrow:

- build ID is `dual-bootstrap-servercheckin-sessioninit-v5`;
- ServerCheckin's reply descriptor is recorded only as diagnostic state;
- InitConnection matching uses the coreservicesd server/check-in port already captured by the proven bootstrap adapter;
- exact matching uses the `mach_msg` send-size argument and no longer constrains the uninitialized pre-send `msgh_size`;
- the adapter still targets only request ID `0x2712`, rewrites only `[PID,UID,layout] -> [UID,layout]`, and leaves MapSharedSegment/Disconnect untouched;
- a new `PM_CORESERVICES_COMPAT_SESSIONINIT_ROUTE` marker records the actual remote port, the server/check-in port, and the distinct ServerCheckin reply descriptor.

Because the v4 artifact is now stale, pull current runtime `main`, repeat **Phase B** to rebuild the v5 interposer, and then repeat **Phase C only**. Do not transfer the old v4 dylib or proceed to Lion until the rebuilt v5 Snow control ends in `RESULT: PASS`.

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
PM_CORESERVICES_COMPAT_SERVERCHECKIN_REPLY_PORT:source=adapter port=nonzero
Security AuditInfo SessionGetInfo adapter -> PASS
dispatch table -> nonzero
process-services port -> nonzero

PM_CORESERVICES_COMPAT_SESSIONINIT_EXACT_CALL:
  index=1
  mode=lion-dual-sessioninit-adapter

PM_CORESERVICES_COMPAT_SESSIONINIT_ROUTE:
  remotePort == serverCheckinPort
  serverCheckinReplyPort recorded separately

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


## Observed completed result — SessionInit repair restores GetProcessForPID

The corrected v5 experiment passed completely on both systems.

Snow Leopard passthrough control:

```text
remotePort              = 0x00002003
serverCheckinPort       = 0x00002003
serverCheckinReplyPort  = 0x00002103
SessionInit mach_msg    = KERN_SUCCESS
GetProcessForPID        = 0
returned PSN            = 0x00000000:0x000b00b0
RESULT                  = PASS
```

This confirms that v5 observes the exact legacy InitConnection transaction while remaining transparent on Snow Leopard.

Lion adaptation:

```text
bootstrap service/check-in port = 0x00009103
ServerCheckin reply descriptor  = 0x00009203
Security SessionGetInfo         = PASS
SessionInit legacy request      = 0x2712 / 0x2c [PID,UID,layout]
SessionInit adapted request     = 0x2712 / 0x28 [UID,layout]
mach_msg return                 = 0
reply                            = 0x2776 / 0x2c / RetCode=0
PM_CORESERVICES_COMPAT_SESSIONINIT_RESULT:PASS
GetProcessForPID                = 0
returned PSN                    = 0x00000000:0x000ba0ba
new crash/core diagnostic       = none
protected hashes unchanged      = YES
RESULT: SESSIONINIT_ADAPTER_GETPROCESSFORPID_PASS
```

The repaired route therefore closes the CarbonCore SessionUniverse InitConnection mismatch and the original first real shell-launched `GetProcessForPID` identity failure without setting `LSDONOTABORTIFNOASN`.

The same run emitted two non-target distributed-notification bootstrap passthrough failures with `MIG_BAD_ARGUMENTS` and WindowServer/default-connection diagnostics, but neither prevented identity registration or the successful Process Manager return. They are not broadened into compatibility work at this stage.

The authoritative next experiment is:

```text
docs/process-manager-postidentity-getprocesspid-experiment.md
```

That stage reuses the accepted v5 CoreServices and v1 Security adapters unchanged and tests exactly one additional documented identity operation: `GetProcessPID` on the PSN just returned by `GetProcessForPID`, requiring an exact PID round-trip. It still stops before `GetCurrentProcess`, foreground conversion, activation, window creation, or event-loop work.

No additional XNU change is indicated.
