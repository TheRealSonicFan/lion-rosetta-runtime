# Process Manager GetFrontProcess validation experiment

## Objective

Verify the first observable foreground-selection state after the now-integrated SetFrontProcess compatibility repair.

The preceding integration has closed the SetFrontProcess transport boundary for the validated Process Manager sequence:

```text
CPS application registration              PASS
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType(...foreground...)     PASS
SetFrontProcess                           PASS
SetFront compatibility adapter            PASS
public SetFrontProcess result              0
new diagnostic                            none
protected hashes                          unchanged
RESULT                                    CPS_SETFRONT_COMPAT_INTEGRATION_PASS
```

This stage does not add another compatibility adapter. It keeps every accepted predicate unchanged, calls public `GetFrontProcess` exactly once after successful `SetFrontProcess`, and compares the returned PSN directly with the PSN already proven for the current process.

## Subject

Current runtime `main` adds:

```text
tests/ppc-process-manager-postidentity-getfrontprocess.c
scripts/build-ppc-process-manager-setfront-getfrontprocess-on-snowleopard.sh
```

The subject build ID is:

```text
cps-setfront-getfrontprocess-v1
```

The executable basename remains exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

That basename is required because the accepted CPS application-registration adapter remains narrowly predicate-gated to the exact previously traced registration string. This experiment does not broaden that predicate.

The subject sequence is:

```text
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, foreground)
SetFrontProcess(returned PSN)
GetFrontProcess(&frontPSN)
compare frontPSN with returned PSN
exit
```

It does not call `GetCurrentProcess`, private `CPSSetFrontProcess`, create a window, or enter an event loop.

## Compatibility stack

Reuse the exact accepted SetFront integration dylib unchanged:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
build_id=dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-v1
```

Also reuse unchanged:

```text
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

Do not rebuild or modify those dylibs for this stage.

Snow uses passthrough for every compatibility mode. Lion uses the exact accepted modes:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1
```

## Success condition

Before `GetFrontProcess`, the full accepted path must still pass:

```text
CPS registration adapter                  PASS on Lion
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType                      PASS
SetFront adapter                          PASS on Lion
SetFrontProcess                           0
no second registration call
no second SetFront compatibility call
```

Then require:

```text
GetFrontProcess                           0
returned front PSN                        exact match with expected PSN
PM_POSTIDENTITY_RESULT:GETFRONTPROCESS_MATCH_PASS
PM_POSTIDENTITY_MILESTONE:M16_SUCCESS
```

No new GetFrontProcess protocol compatibility is assumed or implemented.

## Safety constraints

- build only the new PPC subject on Snow Leopard 10.6.8;
- reuse the accepted SetFront integration dylib and other interposers unchanged;
- require Snow control before Lion;
- keep `LSDONOTABORTIFNOASN` unset;
- call `GetFrontProcess` exactly once;
- do not call `GetCurrentProcess`;
- do not call private `CPSSetFrontProcess` separately;
- do not create a window or enter an event loop;
- do not broaden the CPS registration or SetFrontProcess predicates;
- do not add a GetFrontProcess `mach_msg` rewrite or synthesize a front PSN;
- do not patch CoreGraphics, HIServices, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection;
- run Lion exactly once before review.

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

## Phase B — build the GetFrontProcess subject on Snow Leopard

Reuse the accepted compatibility dylibs unchanged and build only the subject:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-setfront-getfrontprocess-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Require:

```text
build_id=cps-setfront-getfrontprocess-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
architecture=ppc7400
LC_LOAD_DYLINKER=/usr/oah/dyld
imports GetProcessForPID, GetProcessPID, TransformProcessType, SetFrontProcess, GetFrontProcess
does not import GetCurrentProcess
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Keep the accepted compatibility dylibs and their SHA sidecars beside the new subject.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-getfrontprocess-control.sh
```

Require final `RESULT: PASS` and:

```text
registration compatibility               passthrough
SetFront compatibility                   passthrough
GetProcessForPID                         PASS
GetProcessPID                            exact PID round-trip PASS
TransformProcessType                     PASS
SetFrontProcess                          0
GetFrontProcess                          0
front PSN                                match=YES
PM_POSTIDENTITY_RESULT:GETFRONTPROCESS_MATCH_PASS
PM_POSTIDENTITY_MILESTONE:M16_SUCCESS
```

Phase C is a hard gate.

## Phase D — transfer the exact new subject to Lion

Transfer:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-getfrontprocess-snowleopard-control.log
```

Reuse unchanged on Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Do not rebuild any compatibility dylib on Lion.

## Phase E — repeat Lion native safety gates

Run the established native commpage probe and preserve the syscall-295 result as:

```text
syscall295-probe-process-manager-getfrontprocess-validation.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion GetFrontProcess validation

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-getfrontprocess-validation.sh
```

The desired result is:

```text
registration adapter                    PASS
GetProcessForPID                        PASS
GetProcessPID                           exact PID round-trip PASS
TransformProcessType                    PASS
SetFront adapter                        PASS
SetFrontProcess                         0
M13_SETFRONTPROCESS_SUCCESS             reached
GetFrontProcess                         0
front PSN                               exact match
GETFRONTPROCESS_MATCH_PASS              reached
M16_SUCCESS                             reached
new diagnostic                          none
protected hashes                        unchanged

RESULT: GETFRONTPROCESS_VALIDATION_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-getfrontprocess-snowleopard-control.log
syscall295-probe-process-manager-getfrontprocess-validation.log
lion-ppc-process-manager-getfrontprocess-validation.log
lion-ppc-process-manager-getfrontprocess-validation.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `GETFRONTPROCESS_VALIDATION_PASS`

The integrated foreground-selection repair is externally observable through the public Process Manager query: the current process is the front process and its PSN matches exactly. This closes the immediate foreground-state verification gate.

Do not automatically broaden the existing adapters. Review the result first. A later experiment may then revisit `GetCurrentProcess` under the now-restored registration/foreground stack.

### `GETFRONTPROCESS_RETURNED_ERROR`

SetFrontProcess remains accepted, but the public foreground query exposes a new boundary. Preserve the exact OSStatus and stop; do not add an adapter before auditing the call path.

### `GETFRONTPROCESS_PSN_MISMATCH`

The query succeeds but names a different foreground process. Preserve both PSNs and stop; do not synthesize a match.

### `GETFRONTPROCESS_NO_RETURN`

Preserve the crash/core/termination evidence and stop before another run.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
default CoreGraphics connection             -> established
CPS registration                            -> accepted
GetProcessPID                               -> PASS
TransformProcessType                        -> PASS
SetFrontProcess integration                 -> PASS
next step                                   -> verify public GetFrontProcess state
GetCurrentProcess                           -> held until this gate is reviewed
```

No additional XNU change is indicated.


## Observed completed result — GetFrontProcess state matches exactly

The returned Snow control and Lion validation fully passed this stage.

Snow:

```text
SetFrontProcess                         0
GetFrontProcess                         0
front PSN                               exact match
M16_SUCCESS                             reached
RESULT                                  PASS
```

Lion:

```text
registration adapter                    PASS
SetFront adapter                        PASS
SetFrontProcess                         0
GetFrontProcess                         0
expected PSN                            0x00000000 / 0x00144144
returned front PSN                      0x00000000 / 0x00144144
front PSN match                         YES
new diagnostic                          none
protected hashes                        unchanged
RESULT                                  GETFRONTPROCESS_VALIDATION_PASS
```

This proves the integrated foreground-selection repair is visible through the public Process Manager query and that the selected front process is exactly the current translated PPC process identified earlier by `GetProcessForPID`.

The authoritative next stage is:

```text
docs/process-manager-getcurrentprocess-validation-experiment.md
```

That stage keeps every accepted compatibility dylib unchanged and rebuilds only the exact-basename subject so the historic `GetCurrentProcess` boundary can be retested after registration, SetFrontProcess, and GetFrontProcess have all succeeded. No abort suppression, PSN synthesis, or GetCurrentProcess-specific adapter is introduced.
