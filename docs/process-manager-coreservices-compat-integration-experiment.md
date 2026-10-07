# Process Manager dual CoreServices compatibility integration experiment

## Objective

Integrate the two independently proven user-space compatibility adaptations into the real Snow Leopard PPC CarbonCore path, without changing any system binary.

The completed standalone experiments now prove both protocol differences separately:

1. Lion bootstrap lookup requires the UUID-expanded `0xbc` request instead of Snow Leopard PPC's legacy `0xac` request.
2. Lion `ServerCheckin` accepts the native simple `0x18` request, while Snow Leopard PPC CarbonCore emits a complex `0x28` request with one task-port descriptor.

The latest standalone ServerCheckin proof passed on both systems. On Lion, the translated PPC subject:

- completed the already-proven Lion-format bootstrap lookup;
- obtained a nonzero coreservicesd port;
- sent one native Lion simple ServerCheckin request;
- received the expected complex `0x34` reply;
- received descriptor count 1, disposition `0x11`, a nonzero session port, and options `0x03000000`;
- exited normally with `SERVERCHECKIN_PROTOCOL_ADAPTER_PASS`;
- produced no crash/core and changed no protected hash.

The next question is now integration:

> If CarbonCore's exact bootstrap lookup and exact legacy ServerCheckin transaction are both adapted process-locally, does unmodified PPC CarbonCore establish its client session and proceed through the already-aligned `FindService("LaunchApplicationServices")` path?

This experiment answers only that question.

## Integration design

A new private PPC `__DATA,__interpose` dylib contains two tuples:

1. `bootstrap_look_up2` replacement:
   - adapts only `com.apple.CoreServices.coreservicesd`;
   - requires target PID 0 and flags `0x8`;
   - sends the already-proven Lion UUID-expanded lookup request;
   - records the returned coreservicesd port.

2. `mach_msg` replacement:
   - passes every non-target Mach message directly to the pre-interposed original `mach_msg`;
   - recognizes only the legacy Snow Leopard PPC ServerCheckin sent to the exact coreservicesd port returned by the first adapter;
   - requires request ID `0x2710`, complex bits `0x80001513`, the `mach_msg` send argument `0x28`, receive size `0x3c`, descriptor count 1, a nonzero port descriptor with disposition `0x13`/type `0x00`, the exact coreservicesd server port returned by the bootstrap adapter, and the same reply port passed to `mach_msg`; the pre-call `msgh_size` field is diagnostic only because Snow Leopard PPC CarbonCore's generated MIG stub does not initialize it before calling `mach_msg`;
   - for that one exact transaction, clears the complex bit, changes the request size to Lion's native `0x18`, and invokes the original `mach_msg` with send size `0x18`;
   - leaves Lion's reply in the original caller buffer so the unmodified Snow Leopard PPC MIG stub parses it normally.

The bootstrap adapter calls the original `mach_msg` directly and does not recurse through the ServerCheckin filter.

The experiment permits only one adapted bootstrap lookup and one adapted ServerCheckin.

## Why this is the correct next boundary

The previous bootstrap integration run already proved that a valid coreservicesd port can be returned into CarbonCore's real call path, yet CarbonCore still ended with:

```text
server-checkin port = 0
LaunchApplicationServices port = 0
process options = 0x00000002
RESULT: BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE
```

The standalone ServerCheckin proof then showed that Lion accepts its native simple request from the translated PPC task and returns a valid session port.

Therefore a second standalone protocol guess is no longer useful. The next useful observation must come from CarbonCore itself after both proven request-shape corrections are present.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-compat-interposer.c
scripts/build-ppc-process-manager-coreservices-compat-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-coreservices-compat-integration-control.sh
scripts/run-lion-ppc-process-manager-coreservices-compat-integration.sh
docs/process-manager-coreservices-compat-integration-experiment.md
```

The existing stage subject is reused through its established builder. It calls only:

```text
scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, ...)
scGetServerCheckinPort()
scGetProcessOptions()
```

It still stops before Security, LaunchServices process-services initialization, or Process Manager.

## Safety constraints

For this experiment:

- build the PPC stage/interposer only on Snow Leopard;
- run one Snow Leopard pass-through positive control before Lion;
- transfer the exact hashed artifacts to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- run exactly one Lion PPC integration subject;
- load the compatibility dylib only through process-local `DYLD_INSERT_LIBRARIES`;
- adapt exactly one coreservicesd bootstrap lookup;
- adapt exactly one matching legacy ServerCheckin Mach transaction;
- pass all other `bootstrap_look_up2` and `mach_msg` calls to their original implementations;
- do not install the interposer system-wide;
- do not call `ServerCheckin` or `FindService` directly from custom test code;
- do not call `SessionGetInfo`;
- do not call LaunchServices process-services initialization;
- do not call Process Manager;
- do not patch libSystem, launchd, CarbonCore, CoreServices, coreservicesd, Security, LaunchServices, or HIServices;
- do not restart, signal, suspend, or replace launchd, coreservicesd, pbs, securityd, or WindowServer;
- do not modify the Rosetta cache, private dyld, system dyld, LaunchServices database, or XNU;
- do not use GDB, DTrace, dtruss, or live injection beyond this one private dyld interposer.

## Phase A — update both repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the five prepared files listed above.

On Lion also update:

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
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-compat-integration-on-snowleopard.sh \
  ./ppc-process-manager-coreservices-compat-integration-stage-private-dyld \
  ./ppc-process-manager-coreservices-compat-interposer.dylib
```

Expected outputs:

```text
ppc-process-manager-coreservices-compat-integration-stage-private-dyld
ppc-process-manager-coreservices-compat-integration-stage-private-dyld.info.txt
ppc-process-manager-coreservices-compat-integration-stage-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
```

Require:

- both artifacts are 32-bit PowerPC;
- stage `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- stage links the CoreServices umbrella;
- interposer contains `__DATA,__interpose`;
- interposer references both `bootstrap_look_up2` and `mach_msg`;
- build ID is `dual-bootstrap-servercheckin-v3`;
- the `__DATA,__interpose` section is exactly two PPC tuples (`0x10` bytes);
- ServerCheckin candidate/exact-match adapter markers are present.

If the build fails, stop and return the complete build output. Do not edit the source locally.

## Phase C — Snow Leopard pass-through positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-coreservices-compat-integration-control.sh \
  ./ppc-process-manager-coreservices-compat-integration-stage-private-dyld \
  ./ppc-process-manager-coreservices-compat-integration-stage-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-compat-interposer.dylib \
  ./ppc-process-manager-coreservices-compat-interposer.dylib.sha256 \
  ./ppc-process-manager-coreservices-compat-integration-snowleopard-control.log
```

Require all of:

```text
PM_CORESERVICES_COMPAT_BOOTSTRAP_EXACT_CALL:index=1 mode=passthrough
PM_CORESERVICES_COMPAT_BOOTSTRAP_PASSTHROUGH_RETURN:kr=0 ... servicePort=nonzero
PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE:bits=0x80001513 headerSizeObserved=<diagnostic> id=0x00002710 option=0x00000003 send=0x00000028 recv=0x0000003c ... descriptorCount=1 descriptorPort=nonzero disposition=0x13 type=0x00 ...
PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=1 mode=passthrough ... descriptorPort=nonzero
PM_CORESERVICES_COMPAT_SERVERCHECKIN_PASSTHROUGH:bits=0x80001513 send=0x00000028 recv=0x0000003c
PM_SYSTEMSERVICE_STAGE_SERVICE:port=nonzero
PM_SYSTEMSERVICE_STAGE_CHECKIN:port=nonzero
PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS
RESULT: PASS
```

This proves that both interpose tuples load and that the `mach_msg` filter recognizes the real CarbonCore legacy ServerCheckin while leaving Snow Leopard behavior unchanged.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-coreservices-compat-integration-stage-private-dyld
ppc-process-manager-coreservices-compat-integration-stage-private-dyld.info.txt
ppc-process-manager-coreservices-compat-integration-stage-private-dyld.sha256
ppc-process-manager-coreservices-compat-interposer.dylib
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-coreservices-compat-integration-snowleopard-control.log
```

Place the executable/interposer and SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild either artifact on Lion.

## Phase E — repeat Lion native safety gates

Set the validated kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

The validated kernel SHA-256 remains:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Run the established native commpage safety probe and require its existing `RESULT: PASS`.

Then run:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-coreservices-compat-integration.log"
```

Require the established EBADF/no-SIGSYS PASS.

Do not continue if either native safety gate fails.

## Phase F — run one Lion dual-adapted CoreServices integration subject

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-coreservices-compat-integration.sh
```

The runner requires:

1. the validated kernel/runtime identities;
2. the exact stage and interposer hashes;
3. the expected build ID;
4. one adapted bootstrap lookup returning a privileged nonzero coreservicesd port;
5. one exact legacy ServerCheckin match from CarbonCore;
6. one successful native-Lion-format ServerCheckin reply with a nonzero session port;
7. CarbonCore's final service/check-in state.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
lion-ppc-process-manager-coreservices-compat-integration.log
lion-ppc-process-manager-coreservices-compat-integration.raw.log
syscall295-probe-process-manager-coreservices-compat-integration.log
ppc-process-manager-coreservices-compat-integration-snowleopard-control.log
ppc-process-manager-coreservices-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-compat-interposer.dylib.sha256
ppc-process-manager-coreservices-compat-integration-stage-private-dyld.info.txt
ppc-process-manager-coreservices-compat-integration-stage-private-dyld.sha256
```

Also return every new crash report or core listed by the Lion runner.

## Result interpretation

### `CORESERVICES_COMPAT_SYSTEMSERVICE_PASS`

Both protocol adaptations worked in CarbonCore's real path, CarbonCore established a nonzero check-in/session state, and `scCreateSystemServiceVersion("LaunchApplicationServices")` returned a nonzero service port.

That would also prove the existing Snow Leopard PPC `FindService` transaction is accepted by Lion without another adapter.

Stop there. The next stage would move back to the pre-dispatch sequence and test the next untouched prerequisite, `SessionGetInfo`, with the dual CoreServices adapter present.

### `CORESERVICES_COMPAT_FIND_SERVICE_FAILURE`

The adapted ServerCheckin succeeded and CarbonCore has a nonzero check-in port, but `LaunchApplicationServices` remains zero.

This isolates the next boundary to the existing `FindService` transaction despite the earlier static alignment.

Stop and preserve the complete raw log.

### `CORESERVICES_COMPAT_SESSION_STILL_UNAVAILABLE`

The process-local ServerCheckin adapter itself reported a valid session-port reply, but CarbonCore still exposes no check-in session.

That would indicate a client-side reply parsing/state-installation issue rather than a server transaction failure.

Stop before adding another patch.

### ServerCheckin transport/reply failure

If the exact CarbonCore request is recognized but Lion does not return the already-proven reply, preserve the raw log and diagnostics. Do not broaden the `mach_msg` filter.

### ServerCheckin not triggered

If bootstrap succeeds but the exact legacy ServerCheckin marker never appears, the standalone protocol proof cannot yet be integrated at the expected CarbonCore call site. Preserve the log and stop.

### bootstrap failure, multiple-call guard, abort/crash, or unclassified failure

Preserve all evidence and stop.

## Current interpretation to preserve

The standalone Lion ServerCheckin protocol adapter is a clean PASS.

The request/reply IDs remain `0x2710/0x2774`; the decisive request-shape difference is:

```text
Snow Leopard PPC: complex 0x28 request + one task-port descriptor
Lion native:      simple  0x18 request + no request descriptor
```

Lion returned a valid session port and the same raw options value observed in the Snow Leopard control.

The bootstrap and ServerCheckin protocol defects are therefore both independently proven.

The active question is now whether those two exact adaptations are sufficient for unmodified PPC CarbonCore to complete its own `FindService("LaunchApplicationServices")` path.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- create a permanent Rosetta compatibility installation;
- install or patch a system framework;
- broadly translate arbitrary Mach messages;
- alter `FindService`;
- call Security;
- call LaunchServices process services;
- call Process Manager;
- patch launchd or coreservicesd;
- modify the Rosetta cache or XNU.

It is one process-local integration discriminator for the two now-proven CoreServices transport mismatches.


## Phase C harness correction — v2 ServerCheckin matcher

The first Phase C attempt did **not** expose a Snow Leopard CoreServices failure.

The control log proves that:

- the stage and interposer hashes matched their sidecars;
- both artifacts were 32-bit PPC and the stage used `/usr/oah/dyld`;
- the interposer contained the expected two-tuple `__DATA,__interpose` section;
- dyld applied both private tuples to CarbonCore;
- the bootstrap tuple triggered and passed through successfully with a nonzero coreservicesd port;
- unmodified Snow Leopard CarbonCore completed `scCreateSystemServiceVersion`, exposed a nonzero server-checkin port, kept process options at zero, and ended in `STAGE_CONTROL_PASS`;
- the runner nevertheless emitted `RESULT: FAIL` solely because the expected private ServerCheckin exact-match marker never appeared.

The v1 matcher contained one unnecessary assumption: it required the port descriptor inside the legacy `ServerCheckin` request to be numerically identical to the value returned by calling `mach_task_self()` inside the private interposer. The recovered CarbonCore stub establishes only that the descriptor value is supplied by CarbonCore's process-global client state; the previous audits did not prove that its translated-process numeric name must equal a fresh `mach_task_self()` lookup performed from the interposer.

That equality check was therefore too brittle for an integration discriminator.

Version 2 keeps the transaction narrowly scoped but removes that unsupported numeric equality. It still requires all of the protocol identity fields that matter:

```text
remote port = exact coreservicesd port returned by the adapted bootstrap lookup
request id = 0x2710
bits = 0x80001513
header/send size = 0x28
receive size = 0x3c
mach_msg option = 0x3
descriptor count = 1
descriptor port = nonzero
descriptor disposition = 0x13
descriptor type = 0x00
reply port in header = mach_msg receive port
timeout = MACH_MSG_TIMEOUT_NONE
notify = MACH_PORT_NULL
```

Version 2 also emits a `PM_CORESERVICES_COMPAT_SERVERCHECKIN_CANDIDATE` record before the full predicate is evaluated. If another mismatch remains, the next Snow Leopard control will preserve the actual header, `mach_msg` arguments, descriptor port, disposition, type, timeout, and notify values instead of failing with an opaque missing-marker result.

The corrected build ID is:

```text
dual-bootstrap-servercheckin-v3
```

### Required restart point after the failed v1 control

Pull current runtime `main`, then repeat **Phase B and Phase C only**.

Do not transfer the v1 artifacts to Lion and do not run Phase F until the rebuilt v2 Snow Leopard control ends in `RESULT: PASS`.

The failed v1 control changes no runtime conclusion: Snow Leopard's native CarbonCore path itself completed successfully; only the private integration matcher was over-constrained.


## Second Phase C harness correction — v3 ignores pre-call `msgh_size`

The rebuilt v2 control again completed Snow Leopard's real CarbonCore path successfully but the runner still ended in `RESULT: FAIL`.

This time the new candidate record localized the exact mismatch:

```text
bits=0x80001513
headerSizeObserved=0x00000040
id=0x00002710
option=0x00000003
send=0x00000028
recv=0x0000003c
serverPort=nonzero
headerReplyPort=receivePort
descriptorCount=1
descriptorPort=nonzero
disposition=0x13
type=0x00
timeout=0
notify=0
```

The surrounding control still returned a nonzero coreservicesd service/check-in port, process options zero, and `STAGE_CONTROL_PASS`.

The recovered Snow Leopard PPC `__scclient_ServerCheckin` disassembly explains the discrepancy. The generated stub writes the message bits, remote port, reply port, message ID, descriptor count, descriptor port, disposition, and type, then calls:

```text
mach_msg(message, 0x3, 0x28, 0x3c, reply_port, 0, 0)
```

It does **not** initialize the `mach_msg_header_t.msgh_size` word at offset `+0x04` before that call. The `0x00000040` seen by the v2 candidate logger is therefore a pre-call stack value, not the authoritative wire send size.

The earlier standalone ServerCheckin probe was synthetic and explicitly initialized `msgh_size`, which is why using that field as part of the real CarbonCore matcher was too strict.

Version 3 corrects the integration filter accordingly:

- the `mach_msg` **send-size argument** must still be exactly `0x28`;
- all other ServerCheckin identity checks remain unchanged;
- the incoming `msgh_size` value is logged as `headerSizeObserved` but is not used as a match predicate;
- when adapting the request for Lion, the interposer still explicitly sets `msgh_size=0x18` before sending, because the native Lion request shape requires a fully formed simple `0x18` header.

The corrected build ID is:

```text
dual-bootstrap-servercheckin-v3
```

### Required restart point after the failed v2 control

Pull current runtime `main`, then repeat **Phase B and Phase C only**.

Do not transfer the v2 artifacts to Lion and do not run Phase F until the rebuilt v3 Snow Leopard control ends in `RESULT: PASS`.

As with the v1 failure, this changes no CoreServices runtime conclusion: the Snow Leopard control path itself passed; only the private matcher was over-constrained.


## Observed result — dual CoreServices integration passes on Lion

All phases of the corrected v3 experiment completed successfully.

The Snow Leopard pass-through control ended in `RESULT: PASS`.

On Lion, the process-local v3 interposer:

- adapted exactly one coreservicesd bootstrap lookup and received a nonzero privileged service port;
- recognized CarbonCore's exact legacy complex ServerCheckin transaction;
- converted it to Lion's native simple `0x18` request;
- received the expected complex `0x34` reply with a nonzero session port and options `0x03000000`;
- returned control to unmodified PPC CarbonCore.

CarbonCore then completed its own service acquisition:

```text
PM_SYSTEMSERVICE_STAGE_SERVICE:port=nonzero
PM_SYSTEMSERVICE_STAGE_CHECKIN:port=nonzero
PM_SYSTEMSERVICE_STAGE_OPTIONS:0x00000000
PM_SYSTEMSERVICE_STAGE_RESULT:STAGE_CONTROL_PASS
RESULT: CORESERVICES_COMPAT_SYSTEMSERVICE_PASS
```

No crash/core diagnostic was produced. The private dyld, Lion system dyld, kernel, Rosetta cache, stage executable, and interposer hashes remained unchanged, and the native syscall-295 probe remained a clean EBADF/no-SIGSYS PASS.

This result closes the CarbonCore system-service boundary.

Because `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000,...)` returned a nonzero port after check-in, CarbonCore's existing Snow Leopard PPC `FindService` transaction is also accepted by Lion without another adapter.

The authoritative next stage is:

```text
docs/process-manager-predispatch-compat-integration-experiment.md
```

That stage reuses the original pre-dispatch subject under the now-proven v3 CoreServices compatibility layer. It stops after `SessionGetInfo(callerSecuritySession,...)` and does not call LaunchServices process-services initialization or any Process Manager API.

Do not rerun this dual CoreServices integration stage before the pre-dispatch compatibility result is reviewed.
