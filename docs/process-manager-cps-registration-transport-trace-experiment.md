# Process Manager CPS application-registration transport trace experiment

## Objective

Dynamically bind the newly proven CPS application-registration protocol differential to the surviving Lion registration error without changing the request, reply, or registration state.

The completed read-only audit proves a release-level protocol replacement.

Snow Leopard CoreGraphics:

```text
i386 / x86_64 / ppc7400:
  __CPSRegisterWithServer          present
  __CGSCheckInApplication         present
  __CGSCreateApplication          absent
```

Lion CoreGraphics:

```text
i386 / x86_64:
  __CPSRegisterWithServer          present
  __CGSCheckInApplication          absent
  __CGSCreateApplication          present
```

The generated/client contracts are materially different.

Snow Leopard PPC `__CGSCheckInApplication`:

```text
request bits                       0x1513
request ID                         0x7372
send size                          align(mig_strncpy_length + 3) + 0x40
receive size                       0x2c
mach_msg option                    0x3
expected reply ID                  0x73d6
success reply size                 0x24
reply result                       NDR-aware scalar
```

Lion i386 `__CGSCreateApplication`:

```text
request bits                       0x1513
request ID                         0x73c1
send size                          align(mig_strncpy_length + 3) + 0x4c
receive size                       0x2c
mach_msg option                    0x3
expected reply ID                  0x7425
success reply size                 0x24
reply result                       NDR-aware scalar
```

The first six fixed scalar inputs and the variable string occupy the same leading request region, but the Lion request extends the message by `0x0c` bytes after the aligned string. The Lion i386 generated client writes one byte followed by two 32-bit values in that tail; its `__CPSRegisterWithServer` caller supplies those three tail arguments as `0`, `0`, and `0x10` on the observed native path.

This is a structural protocol evolution, not merely a renamed wrapper.

The prior successful connection integration also established that translated Snow PPC now reaches a nonzero default CoreGraphics connection on Lion, yet `_RegisterApplication` still reports:

```text
FAILED TO REGISTER PROCESS WITH CPS/CoreGraphics in WindowServer, err=-304
```

The active question is therefore exactly what Lion WindowServer returns to the unchanged Snow PPC `0x7372` request.

## Trace implementation

Current runtime `main` extends the already-proven CoreServices `mach_msg` trace path with a compile-time-only registration trace mode:

```text
PM_CPS_REGISTRATION_TRACE
```

New build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-trace-v1
```

The dylib still contains exactly two interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

It retains the accepted server-version normalizer and the existing passive CGS trace, and additionally recognizes:

```text
CPS_CHECKIN_APPLICATION   0x7372 -> 0x73d6
CPS_CREATE_APPLICATION    0x73c1 -> 0x7425
```

The trace:

- logs request metadata and raw request words;
- calls the original `mach_msg` unchanged;
- logs the raw Mach return;
- logs reply metadata and raw reply words;
- performs no CPS registration adaptation;
- performs no message-ID rewrite;
- performs no request-size rewrite;
- performs no reply rewrite;
- performs no CPS state fabrication.

The existing server-version compatibility path remains the only reply normalization enabled on Lion.

## Why a passive trace comes before an adapter

The static audit proves the client contracts differ, but the translated Lion run has not yet captured the raw `0x7372` transaction and reply at the point where `_RegisterApplication` reports `-304`.

This trace determines whether:

1. Lion returns the legacy expected reply ID with an error scalar;
2. Lion returns a MIG error envelope or unexpected reply ID;
3. transport itself fails;
4. the expected legacy request is not actually the source of the observed `-304`.

Only after that result is known should a standalone `0x73c1` protocol proof or any narrow integration adapter be designed.

## Safety constraints

For this stage:

- build only the new trace variant on Snow Leopard 10.6.8;
- reuse the accepted registration-only subject, Security v1 interposer, and CGS session-bootstrap v1 interposer unchanged;
- keep Snow server-version mode strictly passthrough;
- keep Lion server-version mode at the already-proven `lion-server-version-v1`;
- require the Snow trace control before Lion;
- transfer the exact hashed trace dylib to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- run the Lion trace exactly once before review;
- keep `LSDONOTABORTIFNOASN` unset;
- do not call `GetProcessPID`, `TransformProcessType`, `SetFrontProcess`, `CPSSetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- do not adapt `0x7372`, `0x73c1`, `0x729e`, or any other CPS/CGS registration request;
- do not fabricate a PSN, Mach right, connection record, or CPS registration state;
- do not patch CoreGraphics, WindowServer, Rosetta, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
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

## Phase B — build the registration-trace variant on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-cps-registration-trace-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib.sha256
```

Require:

```text
build_id=dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-trace-v1
architecture=ppc7400
__interpose size=0x10
imports bootstrap_look_up2, mach_msg, mig_get_reply_port
markers SERVER_VERSION, NEW_CONNECTION, CPS_CHECKIN_APPLICATION, CPS_CREATE_APPLICATION
```

If Phase B fails, stop.

## Phase C — Snow Leopard positive control

Keep the accepted artifacts and sidecars in the same directory:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cps-registration-transport-trace-control.sh
```

Require final `RESULT: PASS`.

The control must prove:

```text
server version                       passthrough 545/0
NewConnection                        0x7469 -> 0x74cd, Mach success
CPS registration request             0x7372
CPS registration reply               0x73d6
CPS registration Mach result         success
reply result scalar                  zero
GetProcessForPID                     PASS
postidentity connection              nonzero
CPS_CREATE_APPLICATION               not observed
```

Phase C is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib.sha256
ppc-process-manager-cps-registration-transport-trace-snowleopard-control.log
```

Reuse the accepted subject, Security interposer, CGS session-bootstrap interposer, and their SHA sidecars unchanged.

## Phase E — repeat Lion native safety gates

Use the already validated syscall-295 kernel identity and run the established native commpage probe.

Then preserve the syscall-295 probe as:

```text
syscall295-probe-process-manager-cps-registration-trace.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion passive registration trace

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cps-registration-transport-trace.sh
```

The runner enables only the already-accepted compatibility modes:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
```

The new CPS registration trace is compile-time passive behavior only.

The leading expected result is one of:

```text
RESULT: CPS_REGISTRATION_TRACE_LEGACY_REPLY_OBSERVED
RESULT: CPS_REGISTRATION_TRACE_LEGACY_UNEXPECTED_REPLY_OBSERVED
RESULT: CPS_REGISTRATION_TRACE_LEGACY_MACH_FAILURE
```

Do not rerun Phase F to chase a preferred classification.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-trace.dylib.sha256
ppc-process-manager-cps-registration-transport-trace-snowleopard-control.log
syscall295-probe-process-manager-cps-registration-trace.log
lion-ppc-process-manager-cps-registration-transport-trace.log
lion-ppc-process-manager-cps-registration-transport-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CPS_REGISTRATION_TRACE_LEGACY_REPLY_OBSERVED`

Lion transported the Snow `0x7372` request and returned the legacy expected reply ID `0x73d6`. Review the raw NDR/result word. If it decodes to `-304`, the static protocol evolution and dynamic registration failure are directly joined; the next stage should be a standalone `0x73c1` protocol proof before any integrated request translation.

### `CPS_REGISTRATION_TRACE_LEGACY_UNEXPECTED_REPLY_OBSERVED`

Lion returned a reply envelope outside the Snow client's expected `0x73d6` contract. Decode the exact MIG envelope before deciding whether a request-ID or payload adaptation is appropriate.

### `CPS_REGISTRATION_TRACE_LEGACY_MACH_FAILURE`

The active boundary is transport-level rather than a normal server-returned CPS error. Preserve the numeric Mach result and do not build a request adapter yet.

### `CPS_REGISTRATION_TRACE_LEGACY_REQUEST_NOT_OBSERVED`

The surviving `-304` did not arise from the exact Snow registration helper predicted by the static audit. Stop and localize the actual caller/message.

### `CPS_REGISTRATION_TRACE_UNEXPECTED_NATIVE_CREATE_APPLICATION_OBSERVED`

The translated PPC path reached Lion's native registration message unexpectedly. Stop and review the loaded-client provenance before further work.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
__CGSNewConnectionPort 0x7469/0x74cd        -> PASS
CoreGraphics default connection             -> NONZERO
Snow CPS registration                       -> 0x7372 / 0x73d6
Lion native CPS registration                -> 0x73c1 / 0x7425
Lion native request extension                -> +0x0c tail after aligned string
translated Lion registration diagnostic     -> err=-304
next step                                   -> passive exact 0x7372 transport trace
later SetFrontProcess 0x729e/0x72a1          -> still out of scope
```

No additional XNU change is indicated.


## Observed completed result — legacy reply directly returns -304

The returned Snow and Lion evidence passed this stage.

Snow control:

```text
0x7372 request send/receive               0x84 / 0x2c
Mach result                               0
reply                                     0x73d6 / 0x24
raw result                                0
GetProcessForPID                          PASS
default connection                        nonzero
RESULT                                    PASS
```

Lion translated PPC:

```text
0x7372 request send/receive               0x84 / 0x2c
Mach result                               0
reply                                     0x73d6 / 0x24
raw result word                           0xd0feffff
reply NDR                                 swapped relative to PPC
decoded result                            -304
_RegisterApplication diagnostic           err=-304
GetProcessForPID                          PASS
default connection                        nonzero
new diagnostic                            none
protected hashes                          unchanged
RESULT                                    CPS_REGISTRATION_TRACE_LEGACY_REPLY_OBSERVED
```

This directly joins the WindowServer reply scalar to the Process Manager diagnostic. The failure is a normal successful Mach transaction returning the legacy expected reply ID, not a transport error or reply-ID mismatch.

The authoritative next stage is the standalone copied-buffer policy proof:

```text
docs/process-manager-cps-registration-compat-protocol-adapter-experiment.md
```

It proves the exact `0x7372 -> 0x73c1`, send-size `+0x0c`, Lion-tail, and `0x7425 -> 0x73d6` conversion locally without sending a new registration request. Do not integrate the translator or proceed to SetFrontProcess until that proof is reviewed.


The subsequent standalone copied-buffer registration policy proof has now passed, so this passive trace stage is closed. The authoritative next procedure is `docs/process-manager-cps-registration-compat-integration-experiment.md`. Do not rerun the trace unless registration-message provenance changes.
