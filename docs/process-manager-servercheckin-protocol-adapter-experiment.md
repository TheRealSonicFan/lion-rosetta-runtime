# Process Manager ServerCheckin protocol adapter experiment

## Objective

Test the next user-space CoreServices compatibility boundary after the bootstrap integration experiment proved that Lion-format bootstrap lookup alone is not sufficient.

The completed integration run established this sequence on Lion:

```text
adapted bootstrap lookup -> nonzero coreservicesd port
CarbonCore service acquisition -> zero service port
CarbonCore server-checkin port -> zero
RESULT: BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE
```

The next question is now exact:

> Does Lion accept the native Lion `ServerCheckin` request shape when it is sent from the translated PPC process after the already-proven Lion-format bootstrap lookup?

This experiment answers only that question.

## Corrected ServerCheckin protocol interpretation

The earlier static RPC audit correctly recovered the Snow Leopard PPC and Lion native client stubs, but its interpretation of Lion's server wrapper was wrong.

### Snow Leopard PPC client

The restored PPC `__scclient_ServerCheckin` sends:

- request ID `0x2710`;
- complex message bits `0x80001513`;
- send size `0x28`;
- receive size `0x3c`;
- one port descriptor carrying the client task port;
- expected reply ID `0x2774`.

### Lion native i386 client

Lion's native i386 `__scclient_ServerCheckin` sends:

- request ID `0x2710`;
- simple message bits `0x00001513`;
- send size `0x18`;
- receive size `0x3c`;
- no request port descriptor;
- expected reply ID `0x2774`.

### Lion i386 server wrapper

Lion's i386 `__XServerCheckin` rejects a request whose complex bit is set and accepts only the simple `0x18` request before reaching `__scserver_ServerCheckin`.

Therefore the restored Snow Leopard PPC CarbonCore's legacy complex `0x28` request is not compatible with Lion's live ServerCheckin MIG wrapper.

This is consistent with the completed integration result: the adapted bootstrap lookup succeeds, but CarbonCore still never obtains a server-checkin port.

## Why the next experiment is standalone

Do not add a second interposition layer to CarbonCore yet.

First prove the exact Lion ServerCheckin request independently.

The prepared PPC subject:

1. performs a normal Snow Leopard bootstrap lookup and legacy complex ServerCheckin in control mode;
2. performs the already-proven Lion-format bootstrap lookup in Lion mode;
3. then sends exactly one Lion native-format simple ServerCheckin request;
4. records the Mach result and raw reply shape;
5. deallocates any returned session port and coreservicesd service port;
6. exits before `FindService`, CarbonCore service acquisition, Security, LaunchServices process services, or Process Manager.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-servercheckin-protocol-adapter.c
scripts/build-ppc-process-manager-servercheckin-protocol-adapter-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-servercheckin-protocol-adapter-control.sh
scripts/run-lion-ppc-process-manager-servercheckin-protocol-adapter.sh
docs/process-manager-servercheckin-protocol-adapter-experiment.md
```

No Apple binary is modified or committed.

## Safety constraints

For this experiment:

- build the PPC subject only on Snow Leopard;
- run one Snow Leopard positive control before Lion;
- transfer the exact hashed subject to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- run exactly one Lion PPC subject;
- send exactly one adapted bootstrap request and exactly one Lion-format ServerCheckin request;
- do not call `FindService`;
- do not call `scCreateSystemServiceVersion`;
- do not initialize CarbonCore's system-service client;
- do not call Security, LaunchServices process services, or Process Manager;
- do not use `DYLD_INSERT_LIBRARIES` in this stage;
- do not patch libSystem, launchd, CarbonCore, CoreServices, or coreservicesd;
- do not restart, signal, suspend, or replace launchd, coreservicesd, pbs, securityd, or WindowServer;
- do not modify the Rosetta cache, private dyld, system dyld, or XNU;
- do not use GDB, DTrace, dtruss, or live injection.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm the five prepared files listed above.

On Lion also update XNU:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — build the PPC subject on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-servercheckin-protocol-adapter-on-snowleopard.sh \
  ./ppc-process-manager-servercheckin-protocol-adapter-private-dyld
```

Expected outputs:

```text
ppc-process-manager-servercheckin-protocol-adapter-private-dyld
ppc-process-manager-servercheckin-protocol-adapter-private-dyld.info.txt
ppc-process-manager-servercheckin-protocol-adapter-private-dyld.sha256
```

Require:

- 32-bit PowerPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up2`, `bootstrap_port`, `mig_get_reply_port`, and `mach_msg`;
- protocol markers present in the built subject.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-servercheckin-protocol-adapter-control.sh \
  ./ppc-process-manager-servercheckin-protocol-adapter-private-dyld \
  ./ppc-process-manager-servercheckin-protocol-adapter-private-dyld.sha256 \
  ./ppc-process-manager-servercheckin-protocol-adapter-snowleopard-control.log
```

Require:

```text
PM_SERVERCHECKIN_LAYOUT:PASS
legacy_send=0x00000028
lion_send=0x00000018
PM_SERVERCHECKIN_SNOW_BOOTSTRAP:kr=0 ...
PM_SERVERCHECKIN_REQUEST:mode=snow-legacy ...
PM_SERVERCHECKIN_MACH_MSG:kr=0 ...
PM_SERVERCHECKIN_COMPLEX_REPLY:... sessionPort=nonzero ...
PM_SERVERCHECKIN_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

The Snow Leopard control sends the exact legacy complex request recovered from the PPC client stub and requires a nonzero returned session port.

If it fails, stop. Do not run Lion.

## Phase D — transfer the exact subject to Lion

Transfer privately:

```text
ppc-process-manager-servercheckin-protocol-adapter-private-dyld
ppc-process-manager-servercheckin-protocol-adapter-private-dyld.info.txt
ppc-process-manager-servercheckin-protocol-adapter-private-dyld.sha256
ppc-process-manager-servercheckin-protocol-adapter-snowleopard-control.log
```

Place the executable and SHA sidecar in the runtime `payload/` directory or pass explicit paths.

Do not rebuild it on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel:

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

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-servercheckin-protocol-adapter.log"
```

Require the established syscall-295 PASS result.

Do not continue if either native safety gate fails.

## Phase F — run the single Lion PPC ServerCheckin adapter subject

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-servercheckin-protocol-adapter.sh
```

The Lion subject:

1. performs the already-proven UUID-expanded `look_up2` request for `com.apple.CoreServices.coreservicesd`;
2. requires a nonzero returned coreservicesd port;
3. sends one simple ServerCheckin request:
   - bits `0x00001513`;
   - request ID `0x2710`;
   - send size `0x18`;
   - receive size `0x3c`;
4. validates reply ID `0x2774`;
5. on success requires the expected complex `0x34` reply with one moved-send port descriptor;
6. records the returned session port and options;
7. deallocates returned ports and exits.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-servercheckin-protocol-adapter-private-dyld.info.txt
ppc-process-manager-servercheckin-protocol-adapter-private-dyld.sha256
ppc-process-manager-servercheckin-protocol-adapter-snowleopard-control.log
syscall295-probe-process-manager-servercheckin-protocol-adapter.log
lion-ppc-process-manager-servercheckin-protocol-adapter.log
lion-ppc-process-manager-servercheckin-protocol-adapter.raw.log
```

Also return every new crash report or core listed by the Lion runner.

## Result interpretation

### `SERVERCHECKIN_PROTOCOL_ADAPTER_PASS`

Lion accepted the native Lion simple request and returned a nonzero CoreServices client-session port.

This directly validates the second protocol mismatch:

```text
Snow Leopard PPC ServerCheckin: complex 0x28 request
Lion ServerCheckin:             simple 0x18 request
```

Stop there.

The next stage would separately design a process-local integration mechanism that adapts only CarbonCore's actual `ServerCheckin` Mach transaction while preserving the already-working bootstrap adapter.

### `SERVERCHECKIN_MIG_BAD_ARGUMENTS`

Lion still rejects the native-format request with `MIG_BAD_ARGUMENTS`.

Do not broaden the request. Preserve the raw reply and re-audit the exact client/server layout.

### `SERVERCHECKIN_MIG_TYPE_ERROR`

The transport returned a reply whose shape does not match the audited contract.

Preserve the complete raw log and stop.

### `SERVERCHECKIN_SERVER_ERROR`

The request reached the server but returned another explicit status.

The exact numeric status becomes the next localization target.

### `LION_BOOTSTRAP_FAILURE`

The already-proven bootstrap adapter did not reproduce in this subject.

Stop before interpreting ServerCheckin.

### abort/crash or unclassified failure

Preserve all diagnostics and stop.

## Current interpretation to preserve

The completed bootstrap integration experiment proves the first adapter is working inside CarbonCore's real call path: the interposer returns a valid nonzero coreservicesd service port on Lion.

The subsequent zero server-checkin port is not a bootstrap failure.

Re-reading the shipped Lion i386 `__XServerCheckin` wrapper corrects an earlier static interpretation: Lion rejects complex ServerCheckin requests instead of retaining compatibility for Snow Leopard PPC's descriptor-bearing `0x28` request.

The next experiment therefore tests the exact native Lion simple `0x18` ServerCheckin request independently before any second integration interposer is attempted.

No additional XNU change is indicated.

## Non-goals

This experiment does not:

- install a permanent compatibility layer;
- modify the existing bootstrap integration interposer;
- interpose `mach_msg`;
- initialize CarbonCore service acquisition;
- call `FindService`;
- call Security;
- call LaunchServices process services;
- call Process Manager;
- patch launchd or coreservicesd;
- modify Rosetta or XNU.

It is one isolated protocol proof for the ServerCheckin boundary.


## Observed result — Lion native-format ServerCheckin succeeds from translated PPC

All phases of this experiment completed successfully.

The Snow Leopard control validated the recovered legacy request and returned a nonzero session port:

```text
request mode=snow-legacy
bits=0x80001513
send=0x28
recv=0x3c
reply id=0x2774
session port=nonzero
RESULT: PASS
```

The Lion subject then completed the already-proven UUID-expanded bootstrap lookup and obtained a nonzero coreservicesd port. It sent exactly one native Lion simple ServerCheckin request:

```text
bits=0x00001513
id=0x2710
send=0x18
recv=0x3c
```

Lion returned:

```text
mach_msg kr=0
reply bits=0x80001200
reply size=0x34
reply id=0x2774
descriptor count=1
disposition=0x11
session port=nonzero
options=0x03000000
RESULT: SERVERCHECKIN_PROTOCOL_ADAPTER_PASS
```

No crash/core diagnostic was produced. The private dyld, Lion system dyld, kernel, Rosetta cache, and probe hashes remained unchanged, and the native syscall-295 probe remained a clean EBADF/no-SIGSYS PASS.

This independently proves the second user-space protocol mismatch: Lion accepts its native simple `0x18` ServerCheckin from the translated PPC task, while the restored Snow Leopard PPC CarbonCore emits the incompatible complex `0x28` form.

The bootstrap and ServerCheckin request-shape defects are therefore both independently closed at the standalone protocol level.

The authoritative next stage is:

```text
docs/process-manager-coreservices-compat-integration-experiment.md
```

That experiment combines only the two proven adaptations in one private process-local interposer and returns control to unmodified PPC CarbonCore. It then observes whether CarbonCore establishes its check-in session and whether its existing `FindService("LaunchApplicationServices")` transaction succeeds.

Do not rerun this standalone ServerCheckin experiment before the dual-integration result is reviewed.
