# Process Manager CGS session-bootstrap compatibility integration experiment

## Objective

Integrate the now-proven Lion WindowServer session-port acquisition sequence into the exact Snow Leopard PPC bootstrap lookup that currently leaves the translated process without a default CoreGraphics connection, then stop immediately after Process Manager registration and read the already-audited CoreGraphics connection-record slot.

This stage does **not** call `TransformProcessType`, public `SetFrontProcess`, private `CPSSetFrontProcess`, create a window, or enter an event loop.

The completed standalone protocol proof established all prerequisites:

- Snow Leopard PPC `bootstrap_look_up("com.apple.windowserver.session")` returns a live send right;
- Lion PPC can perform the native active-root lookup using request `0x194`, target PID 0, zero UUID, flags 8;
- Lion returns a root-owned WindowServer port;
- `GetSessionPort 0x7151 -> 0x71b5` succeeds from translated PPC;
- the returned session port is a live send right with descriptor disposition/type `0x11/0x00`;
- unchanged DeathWatch `0x714c -> 0x71b0` succeeds on that session port;
- no new crash/core diagnostic was produced and protected hashes remained unchanged.

The standalone Lion runner ended with:

```text
RESULT: CGS_SESSION_PORT_PROTOCOL_ADAPTER_PASS
```

That closes the protocol-design prerequisite and justifies the smallest process-local compatibility bridge.

## Compatibility bridge under test

Current runtime `main` provides:

```text
tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c
scripts/build-ppc-process-manager-cgs-session-bootstrap-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-cgs-session-bootstrap-integration-control.sh
scripts/run-lion-ppc-process-manager-cgs-session-bootstrap-integration.sh
```

It also adds a compile-time integration mode to the already-audited CPS connection-state subject:

```text
tests/ppc-process-manager-cps-connection-discriminator.c
```

The new subject mode retains the same read-only loaded-CoreGraphics connection-slot resolution, performs exactly one real `GetProcessForPID(getpid(), &psn)`, reads the slot after registration, and exits. Later identity/foreground/CPS calls are compiled out of this integration binary.

The new interposer has exactly one `__DATA,__interpose` tuple:

```text
bootstrap_look_up -> process-local replacement
```

Only the exact service name:

```text
com.apple.windowserver.session
```

is adapted.

All other `bootstrap_look_up` calls pass through unchanged.

### Snow Leopard mode

```text
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=passthrough
```

The exact legacy session lookup is passed directly to the original Snow Leopard `bootstrap_look_up`.

### Lion mode

```text
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
```

For the exact legacy session service only, the interposer uses the caller-supplied bootstrap namespace port and performs the already-proven sequence:

```text
Lion-format active WindowServer lookup
  request        0x194
  service        com.apple.windowserver.active
  target PID     0
  instance UUID  zero
  flags          8
  reply          0x1f8
  require        complex 0x28, one port, server EUID 0

GetSessionPort
  request        0x7151
  reply          0x71b5
  send/receive   0x18 / 0x30
  require        complex 0x28, one port descriptor
  disposition    0x11
  type           0x00
  require        live send right
```

The root service right is deallocated after `GetSessionPort`. The returned session send right is handed to the original Snow PPC CoreGraphics caller with normal output ownership. The interposer does not fabricate a port, patch CoreGraphics, call a private CGS connection constructor, or alter `__CGSNewConnectionPort`.

## Why this stage stops after registration

The previously completed CPS discriminator proved:

```text
Snow:
  connection slot before identity = 0
  GetProcessForPID                = 0
  connection slot after identity  = nonzero

Lion before this adapter:
  connection slot before identity = 0
  GetProcessForPID                = 0
  connection slot after identity  = 0
  raw CPSSetFrontProcess          = 0x3eb before transport
```

A later Snow-PPC/Lion `SetFrontProcess` request-ID mismatch is already known:

```text
Snow PPC request  0x729e
Lion native       0x72a1
```

That mismatch remains deliberately out of scope. The present experiment asks only whether repairing the session bootstrap lookup allows the existing Snow PPC `_CGSDefaultConnection -> _CGSNewConnection` path to create the connection record during registration. The subject exits before any foreground or CPS transport can obscure that answer.

## Safety constraints

For this experiment:

- build the new PPC subject and CGS interposer only on Snow Leopard 10.6.8;
- require the Snow passthrough integration control before Lion;
- use the already accepted CoreServices SessionInit v5 and Security AuditInfo v1 interposers unchanged;
- transfer exact hashed artifacts to Lion; do not rebuild there;
- repeat the established native commpage and syscall-295 gates before the Lion run;
- run from the logged-in Aqua console user's Terminal;
- keep `LSDONOTABORTIFNOASN` unset;
- run the Lion integration exactly once before review;
- do not call `GetProcessPID`, `TransformProcessType`, `SetFrontProcess`, `CPSSetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- do not create a window or run an event loop;
- do not adapt CGS request `0x729e`;
- do not patch CoreGraphics, WindowServer, launchd, libSystem, Rosetta, private dyld, the Rosetta cache, or XNU;
- do not restart, signal, suspend, or replace WindowServer, coreservicesd, pbs, loginwindow, Dock, or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection.

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

## Phase B — build the new subject and CGS interposer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-cgs-session-bootstrap-integration-on-snowleopard.sh
```

Require these six new artifacts:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256

ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Require:

- subject build ID `cgs-session-bootstrap-integration-v1`;
- CGS interposer build ID `cgs-session-bootstrap-compat-v1`;
- both artifacts are 32-bit PPC;
- subject `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- subject imports `GetProcessForPID` and `dlsym`;
- subject does **not** import `GetProcessPID`, `TransformProcessType`, `SetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- the interposer contains exactly one PPC interpose tuple;
- the interposer imports ordinary `bootstrap_look_up`, not `bootstrap_look_up2`;
- the exact legacy and Lion WindowServer service strings are present.

If Phase B fails, stop and return the complete build output. Do not manually construct missing sidecars.

## Phase C — Snow Leopard passthrough integration control

Use the already accepted v5 CoreServices and v1 Security interposers in the same directory, then run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cgs-session-bootstrap-integration-control.sh
```

Require final:

```text
RESULT: PASS
```

and require evidence that:

```text
CoreServices bootstrap/server-checkin/SessionInit  -> passthrough
Security SessionGetInfo                           -> passthrough
CGS exact session lookup                          -> mode=passthrough
bootstrap_look_up("com.apple.windowserver.session") -> kr=0, nonzero port
GetProcessForPID                                  -> 0
CoreGraphics connection slot after identity       -> nonzero
integration result                                -> CONNECTION_NONZERO
```

Also require that no Lion active-root request was emitted and that the subject did not proceed to `GetProcessPID`, foreground conversion, or CPS.

Phase C is a hard gate. If it fails, stop and do not run Lion.

## Phase D — transfer exact accepted artifacts to Lion

Transfer privately:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256

ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256

ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256

ppc-process-manager-cgs-session-bootstrap-integration-snowleopard-control.log
```

Place executable/dylibs and SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild any artifact on Lion.

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
syscall295-probe-process-manager-cgs-session-bootstrap-integration.log
```

Require the established EBADF/no-SIGSYS PASS.

Do not continue if either native safety gate fails.

## Phase F — exactly one Lion registration integration run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cgs-session-bootstrap-integration.sh
```

The runner enables exactly:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
```

It keeps `LSDONOTABORTIFNOASN` unset.

The subject performs one `GetProcessForPID`, reads the decoded CoreGraphics connection slot, and exits. It cannot call the later Process Manager/foreground/CPS APIs because those imports are absent from this build.

### Expected leading result

The desired result is:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_CALL:index=1 mode=lion-session-port-v1 ... name=com.apple.windowserver.session
PM_CGS_SESSION_BOOTSTRAP_COMPAT_ROOT_RESULT:PASS
PM_CGS_SESSION_BOOTSTRAP_COMPAT_GETSESSION_RESULT:PASS
PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS
PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS
PM_CPS_CONNECTION_STATE:phase=postidentity ... nonzero=YES
PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_RESULT:CONNECTION_NONZERO
PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_MILESTONE:M07_SUCCESS
RESULT: CGS_SESSION_BOOTSTRAP_CONNECTION_ESTABLISHED
```

Run Phase F only once before review.

## Phase G — stop and return evidence

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-integration-snowleopard-control.log
syscall295-probe-process-manager-cgs-session-bootstrap-integration.log
lion-ppc-process-manager-cgs-session-bootstrap-integration.log
lion-ppc-process-manager-cgs-session-bootstrap-integration.raw.log
```

Also return any new crash/core diagnostic named by the Lion runner.

The already accepted CoreServices/Security info and SHA files need not be returned again unless their identities differ from the artifacts previously validated.

## Result interpretation

### `CGS_SESSION_BOOTSTRAP_CONNECTION_ESTABLISHED`

The exact legacy session bootstrap call is the missing compatibility operation that prevented Snow PPC CoreGraphics from creating its default connection on Lion. The process-local adapter successfully returned the Lion per-session WindowServer send right, and the unchanged Snow PPC connection-creation path then populated the audited connection record.

Do not immediately patch `0x729e`. The next controlled stage should reintroduce only the already-proven identity round-trip/foreground conversion and one raw `CPSSetFrontProcess` call with this session-bootstrap adapter active. That run will determine whether the latent Snow `0x729e` versus Lion `0x72a1` transport mismatch is now the active boundary.

### `CGS_SESSION_BOOTSTRAP_ADAPTER_PASS_CONNECTION_STILL_NULL`

The session-port bridge itself worked, but default-connection construction still failed. Stop. The next audit must localize the failure between the returned session port and connection-record publication, with `__CGSNewConnectionPort` response semantics as the leading downstream boundary. Do not touch `0x729e`.

### root lookup / GetSessionPort adapter failure

Stop. Preserve the exact request/reply evidence. This would contradict the standalone protocol proof in the integrated process context and must be explained before any broader adapter is attempted.

### target not reached

Stop. The registration path did not invoke the exact expected legacy service lookup under this subject. Re-audit call-path assumptions before changing behavior.

### crash or diagnostic

Preserve the artifact and stop.

## Current boundary

```text
syscall 295 compatibility                         -> PASS
CoreServices / Security compatibility             -> PASS
SessionUniverse InitConnection v5                 -> PASS
GetProcessForPID / GetProcessPID                  -> PASS
TransformProcessType                              -> PASS
Lion standalone active-root lookup                -> PASS
Lion standalone GetSessionPort 0x7151             -> PASS
Lion standalone session-port send-right check     -> PASS
Lion standalone DeathWatch 0x714c                 -> PASS
standalone result                                 -> CGS_SESSION_PORT_PROTOCOL_ADAPTER_PASS

Snow registration default connection              -> established
Lion registration default connection before fix   -> NULL
exact compatibility candidate                     -> bootstrap_look_up("com.apple.windowserver.session")
candidate implementation                          -> active root lookup + GetSessionPort
next step                                         -> one registration-only integration run
latent later boundary                             -> SetFrontProcess 0x729e vs 0x72a1
```

No additional XNU change is indicated.


## Observed Lion result — session bridge passed, process exited before GetProcessForPID returned

The first Lion registration integration did **not** fail at the session-bootstrap adapter. The returned log proves:

```text
SessionInit v5 adapter                         -> PASS
CGS exact legacy session lookup               -> reached
Lion active-root lookup 0x194                 -> PASS
root WindowServer send right                  -> valid
GetSessionPort 0x7151 -> 0x71b5               -> PASS
returned session send right                   -> valid
CGS session-bootstrap adapter                 -> ADAPTER_PASS
M06_AFTER_GetProcessForPID                    -> absent
process exit status                           -> 1
new crash/core diagnostic                     -> none
protected hashes                              -> unchanged
```

The runner's original terminal label `GETPROCESSFORPID_ABORT_OR_CRASH` was too broad. A status-1 process exit with no new diagnostic is not evidence of a signal or crash. Current `main` now classifies that exact pattern as `GETPROCESSFORPID_CLEAN_EARLY_EXIT_AFTER_SESSION_ADAPTER`.

This result advances the boundary downstream of the compatibility lookup itself. It does **not** yet prove that the legacy client accepted the returned session port through DeathWatch, nor that `__CGSNewConnectionPort 0x7469` was reached.

The authoritative next step is now:

```text
docs/process-manager-cgs-connection-transport-trace-experiment.md
```

That stage is behavior-preserving. It builds a trace-only variant of the existing CoreServices v5 `mach_msg` interposer, validates it on Snow Leopard, and then records only the integrated `0x714c -> 0x71b0` DeathWatch and `0x7469 -> 0x74cd` connection-creation transactions during one Lion run. No request is adapted and no connection record is written.

Do not rerun this integration with the ordinary v5 interposer, do not adapt `0x7469` or `0x729e`, and do not change XNU until the passive trace is reviewed.
