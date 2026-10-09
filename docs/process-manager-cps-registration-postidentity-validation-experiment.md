# Process Manager CPS registration postidentity validation experiment

## Objective

Verify that the newly accepted Lion CPS application registration remains compatible with the next two already-proven Process Manager checkpoints:

```text
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, foreground)
```

This stage deliberately stops before any SetFrontProcess or raw CPS foreground request.

The preceding integration is now proven:

```text
legacy registration request             0x7372 / 0x84
native Lion registration request        0x73c1 / 0x90
native Lion reply                       0x7425 / 0x24 / result 0
legacy-facing reply                     0x73d6 / 0x24 / result 0
registration adapter                    PASS
_RegisterApplication err=-304           absent
GetProcessForPID                        PASS
RESULT                                  CPS_REGISTRATION_COMPAT_REGISTRATION_ACCEPTED
```

The active question is no longer application registration itself. Before returning to the known SetFrontProcess transport mismatch, the restored stack must re-prove that the registered PSN can round-trip through `GetProcessPID` and can be converted to foreground type without introducing a second registration transaction or a new compatibility failure.

## Subject

Current runtime `main` reuses:

```text
tests/ppc-process-manager-postidentity-transformprocesstype.c
```

with compile-time marker:

```text
PM_CPS_REGISTRATION_POSTIDENTITY_VALIDATION
```

and build ID:

```text
cps-registration-postidentity-v1
```

The builder intentionally writes the executable with the exact basename:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

That basename is required because the accepted CPS registration adapter remains narrowly predicate-gated to the exact previously traced MIG registration string. The adapter is not broadened for this experiment.

The subject imports exactly:

```text
GetProcessForPID
GetProcessPID
TransformProcessType
```

among the Process Manager calls relevant here, and does not import `SetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`.

The subject sequence is:

```text
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, kProcessTransformToForegroundApplication)
exit
```

## Compatibility stack

Reuse unchanged from the successful registration integration:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

Do not rebuild or modify those dylibs for this stage unless provenance has changed.

Lion runtime modes remain:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
```

Snow uses passthrough for every compatibility mode.

## Success gates

The registration path must still prove:

```text
server-version adapter                  PASS on Lion
NewConnection                           0x7469 -> 0x74cd
CPS registration exact predicate        YES
request conversion                      0x7372 -> 0x73c1
native reply                            0x7425 / result 0
legacy-facing reply                     0x73d6 / result 0
registration adapter                    PASS
_RegisterApplication err=-304           absent
```

Then the subject must prove:

```text
GetProcessForPID                        0
GetProcessPID                           0
PID round-trip                          exact
TransformProcessType                    0
final milestone                         M11_SUCCESS
```

A second `PM_CPS_REGISTRATION_COMPAT_CALL` is a stop condition. This stage expects exactly one application-registration transaction.

## Safety constraints

- keep `LSDONOTABORTIFNOASN` unset;
- keep the accepted CPS registration adapter unchanged;
- keep the accepted server-version and session-port adapters unchanged;
- do not call `SetFrontProcess`, `CPSSetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- do not adapt `0x729e`, `0x72a1`, or any foreground request;
- do not create a window or enter an event loop;
- do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the shared cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection;
- require Snow control before Lion;
- run the Lion phase exactly once before review.

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

## Phase B — build the extended subject on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-cps-registration-postidentity-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Require:

```text
build_id=cps-registration-postidentity-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
architecture=ppc7400
LC_LOAD_DYLINKER=/usr/oah/dyld
imports GetProcessForPID, GetProcessPID, TransformProcessType
does not import SetFrontProcess, GetFrontProcess, GetCurrentProcess
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Keep the accepted compatibility dylibs and sidecars beside the new subject, then run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cps-registration-postidentity-control.sh
```

Require final `RESULT: PASS` and all of:

```text
PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=passthrough exact=YES
PM_CPS_REGISTRATION_COMPAT_RESULT:PASSTHROUGH
CPS_CHECKIN_APPLICATION                  0x7372 -> 0x73d6 / result 0
GetProcessForPID                        0
GetProcessPID                           0
PID round-trip                          match=YES
TransformProcessType                    0
PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS
PM_POSTIDENTITY_MILESTONE:M11_SUCCESS
```

The Snow log must contain no registration failure diagnostic and no CPSSetFrontProcess milestone.

Phase C is a hard gate.

## Phase D — transfer exact artifacts to Lion

Transfer the newly built subject and sidecars:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-cps-registration-postidentity-snowleopard-control.log
```

Reuse unchanged:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Do not rebuild the compatibility dylibs on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity and run the established native commpage probe.

Then preserve the syscall-295 probe as:

```text
syscall295-probe-process-manager-cps-registration-postidentity.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion postidentity validation

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cps-registration-postidentity.sh
```

The leading desired result is:

```text
registration adapter                         PASS
_RegisterApplication err=-304                absent
GetProcessForPID                             PASS
GetProcessPID                               0
PID round-trip                              match=YES
TransformProcessType                        0
PM_POSTIDENTITY_RESULT:TRANSFORMPROCESSTYPE_PASS
PM_POSTIDENTITY_MILESTONE:M11_SUCCESS
no second registration call
RESULT: CPS_REGISTRATION_POSTIDENTITY_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-cps-registration-postidentity-snowleopard-control.log
syscall295-probe-process-manager-cps-registration-postidentity.log
lion-ppc-process-manager-cps-registration-postidentity.log
lion-ppc-process-manager-cps-registration-postidentity.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CPS_REGISTRATION_POSTIDENTITY_PASS`

The accepted registration repair survives both identity round-trip and foreground-type conversion. This reopens the already-known SetFrontProcess boundary. The next stage should return to the exact `0x729e -> 0x72a1` foreground transaction with the full now-restored registration stack active.

### GetProcessPID failure or no return

The registration repair has exposed or regressed an identity boundary. Preserve the exact status/diagnostic and stop.

### TransformProcessType failure or no return

Registration and identity remain accepted, but foreground conversion is the active boundary again. Preserve the returned OSStatus or crash evidence and stop.

### Second registration call

Do not broaden the single-call registration adapter. Review why foreground conversion re-entered registration.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
__CGSNewConnectionPort 0x7469/0x74cd        -> PASS
CoreGraphics default connection             -> established
CPS registration 0x7372 -> 0x73c1           -> accepted
GetProcessForPID                             -> PASS
next step                                   -> revalidate GetProcessPID + TransformProcessType
SetFrontProcess 0x729e/0x72a1                -> held until this gate passes
```

No additional XNU change is indicated.
