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
   - requires request ID `0x2710`, complex bits `0x80001513`, send size `0x28`, receive size `0x3c`, descriptor count 1, the current task port descriptor, disposition `0x13`, and the same reply port passed to `mach_msg`;
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
- build ID is `dual-bootstrap-servercheckin-v1`;
- ServerCheckin adapter markers are present.

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
PM_CORESERVICES_COMPAT_SERVERCHECKIN_EXACT_CALL:index=1 mode=passthrough
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
