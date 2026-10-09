# Process Manager CGS session-port protocol adapter experiment

## Objective

Prove, without modifying CoreGraphics or running Process Manager registration, that a translated PPC process on Lion can reproduce the exact native Lion WindowServer session-port acquisition sequence established by the completed version-2 CGS server-port audit.

The version-2 audit closes the static question that blocked an adapter design.

Snow Leopard PPC obtains its session WindowServer port through the task bootstrap namespace:

```text
_CGSServerPort
  -> _lookupServerPort(0, 0)
     -> task_get_special_port(..., 4, ...)
     -> bootstrap_look_up("com.apple.windowserver.session")
     -> fallback _CGSLookupServerRootPort(0)
```

The Snow PPC root fallback first looks up:

```text
com.apple.windowserver.active
```

and only permits the on-demand:

```text
com.apple.windowserver
```

fallback for root/permitted callers. The previously observed:

```text
On-demand launch of the Window Server is allowed for root user only.
```

is therefore the exact branch reached after the legacy session lookup and then the legacy active-root lookup both fail for the non-root translated subject.

Lion native CoreGraphics no longer obtains the session port by looking up `com.apple.windowserver.session`. Its native path is:

```text
_CGSLookupSessionPort
  -> _getSessionPort(1)
     -> _CGSLookupServerRootPort(1)
        -> bootstrap_look_up2("com.apple.windowserver.active",
                              target_pid=0,
                              flags=8)
     -> __CGSGetSessionPort(rootPort, &sessionPort)
        request 0x7151
        reply   0x71b5
        send    0x18
        receive 0x30
```

The successful `__CGSGetSessionPort` reply is a complex `0x28` reply with one port descriptor. Lion validates descriptor disposition `0x11` before returning the port. Both Snow PPC and Lion native subsequently validate the selected server port through `__CGSSessionDeathWatchPort`, request/reply `0x714c/0x71b0`.

This makes the smallest candidate bridge a per-session port acquisition bridge, not a rewrite of `__CGSNewConnectionPort` and not a blind renaming of the legacy bootstrap service.

## Why the next step is a standalone protocol proof

A process-local `bootstrap_look_up("com.apple.windowserver.session")` adapter is now architecturally justified, but it should not be inserted into the real Process Manager path until two properties are proven dynamically from PPC code on Lion:

1. the Lion-format privileged lookup of `com.apple.windowserver.active` returns the native root WindowServer send right;
2. the native `GetSessionPort` MIG transaction returns a valid send right that also passes the unchanged DeathWatch transaction.

The prepared probe performs exactly those operations and then exits. It does not call `_CGSDefaultConnection`, `_CGSNewConnection`, Process Manager, CPS registration, SetFrontProcess, or window creation.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-cgs-session-port-protocol-adapter.c
scripts/build-ppc-process-manager-cgs-session-port-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-cgs-session-port-protocol-control.sh
scripts/run-lion-ppc-process-manager-cgs-session-port-protocol.sh
docs/process-manager-cgs-session-port-protocol-adapter-experiment.md
```

The PPC executable has two modes.

## Corrected Phase-C tooling gate

The first returned Snow Leopard control built correctly but stopped immediately at:

```text
PM_CGS_SESSION_PORT_BUILD_ID:cgs-session-port-protocol-v1
PM_CGS_SESSION_PORT_MILESTONE:M00_MAIN_ENTER
PM_CGS_SESSION_PORT_LAYOUT:FAIL_LOOKUP
control_status=41
RESULT: FAIL
```

No bootstrap lookup, Mach request, or WindowServer RPC was reached. The failure was in the probe's own layout self-check.

Version 1 wrote the 64-bit launchd `flags` field with a native `uint64_t` copy, which is correct for the PPC-generated request, but then validated that same field by reading its two 32-bit halves in little-endian word order. On big-endian PPC, `flags=8` is represented with the high 32-bit word first, so the checker compared the correct in-memory 64-bit value against the wrong 32-bit half ordering and rejected the request before execution.

Version 2 fixes only that tooling defect:

- the request construction is unchanged;
- the 64-bit flags self-check now reads the field back as one native `uint64_t`;
- a failed lookup-layout check now logs the decoded header, size, ID, and 64-bit flags before stopping;
- the build ID is now `cgs-session-port-protocol-v2` so stale version-1 artifacts cannot pass the runners.

The version-1 executable, SHA sidecar, info file, and failed control log are provenance only. Do **not** transfer or run that executable on Lion. Pull current `main`, rebuild on Snow Leopard, and repeat Phase C with the version-2 artifact.

### Second Phase-C tooling correction after the version-2 control

The rebuilt version-2 Snow Leopard control passed the lookup-layout self-check and then reached the real legacy WindowServer path successfully:

```text
PM_CGS_SESSION_PORT_BUILD_ID:cgs-session-port-protocol-v2
PM_CGS_SESSION_PORT_LAYOUT:PASS
PM_CGS_SESSION_PORT_BOOTSTRAP_SPECIAL_PORT:kr=0 ... port=0x0000070b global=0x0000070b
PM_CGS_SESSION_PORT_SNOW_LOOKUP_RETURN:kr=0 ... sessionPort=0x00001e03
PM_CGS_SESSION_PORT_RIGHT:... send=YES
PM_CGS_SESSION_PORT_DEATHWATCH_MACH_RETURN:kr=0
PM_CGS_SESSION_PORT_DEATHWATCH_REPLY:bits=0x80001200 size=0x00000028 id=0x000071b0
PM_CGS_SESSION_PORT_DEATHWATCH_COMPLEX_REPLY:descriptor_count=1 port=0x00001f03 descriptorWord=0x00001100 disposition=0x00
control_status=22
RESULT: FAIL
```

This failure is also in the probe, but at a later point. The legacy session lookup and the DeathWatch transaction both succeeded. The reply is the expected complex `0x28` / `0x71b0` shape with one nonzero port descriptor. Version 2 incorrectly derived the descriptor disposition by treating the four bytes beginning at offset `0x24` as an integer and shifting that integer by 16 bits. On big-endian PPC the observed word `0x00001100` has byte `0x11` at the ABI-defined port-descriptor disposition offset `0x26`; integer shifting therefore decoded the correct descriptor as disposition zero.

Version 3 fixes that second endian-sensitive parser defect:

- the port descriptor disposition is read directly from message byte offset `0x26`;
- the descriptor type is read directly from byte offset `0x27` and must be `0x00`;
- the full 32-bit descriptor word remains logged only as diagnostic context and is no longer used to infer byte fields;
- the build ID is now `cgs-session-port-protocol-v3`;
- both Snow and Lion runners require v3, and their success gates require `disposition=0x11 type=0x00` on the relevant complex replies.

The byte offsets match the already-proven descriptor parsing used elsewhere in this repository for ServerCheckin and LaunchServices replies. The version-2 artifact and failed log are therefore provenance, not evidence of a protocol incompatibility. Do **not** transfer the v2 executable to Lion. Pull current `main`, rebuild on Snow Leopard, and repeat Phase C with the v3 artifact. The remaining Snow control requirement is to prove that the returned DeathWatch port is itself a live send right and that the control reaches `SNOW_CONTROL_PASS`.

### `snow-control`

It performs:

```text
task_get_special_port(..., 4, ...)
bootstrap_look_up("com.apple.windowserver.session")
mach_port_type -> send right
__CGSSessionDeathWatchPort-equivalent request 0x714c
reply 0x71b0 -> one nonzero send-right descriptor
```

This is the positive control for the exact legacy Snow semantics and for the probe's DeathWatch parser.

### `lion-native-session`

It performs:

```text
task_get_special_port(..., 4, ...)
Lion launchd lookup request 0x194
  service = com.apple.windowserver.active
  send = 0xbc
  receive = 0x6c
  target PID = 0
  instance UUID = zero
  flags = 8
  expected reply = 0x1f8
  expected server EUID = 0

GetSessionPort request 0x7151
  send = 0x18
  receive = 0x30
  expected reply = 0x71b5
  expected complex size = 0x28
  descriptor count = 1
  descriptor disposition = 0x11

DeathWatch request 0x714c
  send = 0x18
  receive = 0x30
  expected reply = 0x71b0
  expected complex size = 0x28
  descriptor count = 1
  descriptor disposition = 0x11
```

Every received service/session/death-watch port is checked with `mach_port_type` for a send right and deallocated before exit.

## Safety constraints

For this experiment:

- build the PPC subject only on Snow Leopard 10.6.8;
- require the Snow Leopard positive control before Lion;
- transfer the exact hashed executable to Lion;
- repeat the established native commpage and syscall-295 safety gates on Lion;
- run the Lion PPC probe exactly once before review;
- keep `DYLD_INSERT_LIBRARIES` unset;
- do not load the CoreServices, Security, or any CGS interposer;
- do not call `_CGSDefaultConnection`, `_CGSServerPort`, `_CGSNewConnection`, or `__CGSNewConnectionPort`;
- do not call Process Manager, LaunchServices process registration, CPS SetFrontProcess, or create a window;
- do not restart, signal, suspend, or replace WindowServer, launchd, loginwindow, Dock, or coreservicesd;
- do not patch CoreGraphics, launchd, libSystem, Rosetta, private dyld, the Rosetta cache, or XNU;
- do not use GDB, DTrace, dtruss, or live injection;
- do not rerun the Lion phase until the first result has been reviewed.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU documentation checkout:

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
  /bin/bash ./scripts/build-ppc-process-manager-cgs-session-port-protocol-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-cgs-session-port-protocol-private-dyld
ppc-process-manager-cgs-session-port-protocol-private-dyld.info.txt
ppc-process-manager-cgs-session-port-protocol-private-dyld.sha256
```

Require:

- a 32-bit PPC executable;
- build marker `PM_CGS_SESSION_PORT_BUILD_ID:cgs-session-port-protocol-v3`;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up`, `bootstrap_port`, `mig_get_reply_port`, `mach_msg`, `task_get_special_port`, `mach_port_type`, and `mach_port_deallocate`.

If the build fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cgs-session-port-protocol-control.sh
```

Require the ordered evidence:

```text
PM_CGS_SESSION_PORT_LAYOUT:PASS
PM_CGS_SESSION_PORT_SNOW_LOOKUP_RETURN:kr=0 ... sessionPort=nonzero
PM_CGS_SESSION_PORT_RIGHT:... send=YES
PM_CGS_SESSION_PORT_DEATHWATCH_MACH_RETURN:kr=0 ...
PM_CGS_SESSION_PORT_DEATHWATCH_REPLY:... id=0x000071b0
PM_CGS_SESSION_PORT_DEATHWATCH_COMPLEX_REPLY:descriptor_count=1 ... disposition=0x11
PM_CGS_SESSION_PORT_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

Phase C is a hard gate. If it fails, stop and do not run Lion. For the corrected pass, confirm the log contains `PM_CGS_SESSION_PORT_BUILD_ID:cgs-session-port-protocol-v3`; version-1 and version-2 logs are not eligible to advance.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
ppc-process-manager-cgs-session-port-protocol-private-dyld
ppc-process-manager-cgs-session-port-protocol-private-dyld.info.txt
ppc-process-manager-cgs-session-port-protocol-private-dyld.sha256
ppc-process-manager-cgs-session-port-protocol-snowleopard-control.log
```

Place the executable and SHA sidecar under runtime `payload/`, or pass explicit paths.

Before transfer, confirm the info file contains `build_id=cgs-session-port-protocol-v3` and the control log contains both the v3 build marker and `RESULT: PASS`. Do not transfer either failed version-1 or version-2 artifact.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing `RESULT: PASS`.

Then run the established syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-cgs-session-port-protocol.log
```

Require the established EBADF/no-SIGSYS result.

Do not continue if either native safety gate fails.

## Phase F — one Lion native-session protocol run

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cgs-session-port-protocol.sh
```

The runner requires a live WindowServer, the validated Lion CoreGraphics hash, the validated Rosetta cache/map, private dyld, translator, kernel identity, and exact executable SHA-256.

The probe performs only the native-like root lookup, `GetSessionPort`, DeathWatch validation, and port deallocation.

Do not rerun Phase F before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-cgs-session-port-protocol-private-dyld.info.txt
ppc-process-manager-cgs-session-port-protocol-private-dyld.sha256
ppc-process-manager-cgs-session-port-protocol-snowleopard-control.log
syscall295-probe-process-manager-cgs-session-port-protocol.log
lion-ppc-process-manager-cgs-session-port-protocol.log
lion-ppc-process-manager-cgs-session-port-protocol.raw.log
```

Also return any new crash report or core listed by the Lion runner.

## Result interpretation

### `CGS_SESSION_PORT_PROTOCOL_ADAPTER_PASS`

Lion accepted the exact native root-service lookup, returned a root-owned WindowServer service port, accepted the native `GetSessionPort 0x7151` transaction, returned a one-descriptor send right, and accepted the unchanged `DeathWatch 0x714c` transaction.

This proves the output-right semantics required by the Snow caller and closes the remaining protocol-design prerequisite.

The next controlled stage would then be a separate process-local interposer that targets only:

```text
bootstrap_look_up(..., "com.apple.windowserver.session", ...)
```

and, only on Lion and only for that exact service, returns the session port obtained through the just-proven native sequence. All other `bootstrap_look_up` calls would pass through untouched. That adapter would first receive a Snow Leopard passthrough control and then be combined with the already-proven CoreServices and Security compatibility layers for one guarded Process Manager registration run.

Do not build or run that integration until this standalone protocol result is reviewed.

### root lookup failure

Stop. Preserve the Lion-format launchd request/reply evidence. Do not fall back to the legacy `com.apple.windowserver.active` lookup.

### `GetSessionPort` transport, reply-ID, descriptor, or right failure

Stop. The native session-port MIG contract is the active boundary. Do not add a bootstrap interposer.

### DeathWatch failure

Stop. A returned session port is not yet equivalent to the port contract expected by the legacy client.

### crash or diagnostic

Preserve the artifact and stop.

## Current boundary

```text
syscall 295 compatibility                         -> PASS
CoreServices / Security compatibility             -> PASS
SessionUniverse InitConnection v5                 -> PASS
GetProcessForPID / GetProcessPID                  -> PASS
TransformProcessType                              -> PASS
Snow PPC default CoreGraphics connection          -> established
Lion translated-PPC default connection            -> NULL
Snow PPC session acquisition                      -> bootstrap_look_up("com.apple.windowserver.session")
Snow PPC root fallback                            -> legacy active/root bootstrap lookups
Lion native session acquisition                   -> active root port + GetSessionPort 0x7151
Lion native returned-port disposition             -> 0x11 send right
DeathWatch request/reply                          -> 0x714c / 0x71b0 on both
__CGSNewConnectionPort                            -> still not the active mismatch
next step                                         -> standalone PPC native-session protocol proof
```

No additional XNU change is indicated.


## Observed completed result — standalone protocol proof passed

The corrected version-3 experiment has now passed completely on both systems.

Snow Leopard 10.6.8 control:

```text
build_id                                      = cgs-session-port-protocol-v3
legacy com.apple.windowserver.session lookup = KERN_SUCCESS
returned session right                       = send right
DeathWatch 0x714c -> 0x71b0                  = PASS
descriptor disposition/type                  = 0x11 / 0x00
RESULT                                        = PASS
```

Lion 10.7.5 translated PPC:

```text
active WindowServer lookup 0x194             = PASS
target PID / UUID / flags                    = 0 / zero / 8
root reply server EUID                       = 0
root port                                    = send right
GetSessionPort 0x7151 -> 0x71b5              = PASS
session descriptor disposition/type          = 0x11 / 0x00
session port                                 = send right
DeathWatch 0x714c -> 0x71b0                  = PASS
death-watch returned port                    = send right
new crash/core diagnostic                    = none
protected hashes unchanged                   = YES
RESULT: CGS_SESSION_PORT_PROTOCOL_ADAPTER_PASS
```

The standalone prerequisite is therefore closed. The exact native Lion session-port acquisition sequence is callable from translated PPC and returns the ownership/type semantics required by the Snow PPC caller.

The authoritative next stage is now:

```text
docs/process-manager-cgs-session-bootstrap-compat-integration-experiment.md
```

That stage installs a one-tuple process-local adapter for only `bootstrap_look_up("com.apple.windowserver.session")`. On Snow Leopard it is passthrough. On Lion it substitutes the proven active-root plus `GetSessionPort` sequence, then performs exactly one Process Manager registration request and reads the already-audited CoreGraphics connection-record slot. The subject stops before `GetProcessPID`, `TransformProcessType`, public/private SetFrontProcess, window creation, or an event loop.

Do not adapt `0x729e -> 0x72a1` yet. The next question is only whether the repaired session lookup is sufficient for the unchanged Snow PPC `_CGSNewConnection` path to publish a valid default connection.

No additional XNU change is indicated.
