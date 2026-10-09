# Process Manager SetFrontProcess compatibility integration experiment

## Objective

Integrate the now-proven SetFrontProcess request/reply ID translation into the normal combined CoreServices compatibility dylib and verify the exact public Process Manager sequence still succeeds end to end on Snow Leopard and Lion.

The prerequisite protocol proof is complete. On Lion the exact live SetFrontProcess request matched:

```text
bits                                     0x1513
legacy request ID                        0x729e
option                                   0x3
send / receive                           0x30 / 0x2c
PSN high                                 0
PSN low                                  nonzero
argument 2                               0
argument 3                               0
registration compatibility calls         1
```

The copied-buffer proof then established:

```text
private request ID                       0x729e -> 0x72a1
request bytes changed                    1
source request bytes changed             0
native Mach result                       0
native reply ID                          0x7305
native reply size                        0x24
native reply result                      0
private reply ID                         0x7305 -> 0x7302
reply bytes changed                      1
legacy-facing result                     0
public SetFrontProcess                   0
RESULT                                   CPS_SETFRONT_COMPAT_POLICY_PROOF_PASS
```

Snow remained strict passthrough and returned normal legacy 0x729e/0x7302 success.

This stage does not discover a new protocol. It promotes that exact already-proven policy to the integration build and verifies that the complete restored path remains stable without any protocol-proof-only compile mode.

## Integration implementation

Current runtime main extends:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
```

with compile-time mode:

```text
PM_CPS_SETFRONT_COMPAT_INTEGRATION
```

and the already-proven runtime mode:

```text
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1
```

Integration build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-v1
```

The dylib still contains exactly two PPC interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

The integration build reuses the exact SetFrontProcess handler already proven by the protocol experiment. No predicate, payload, result, or reply policy is broadened.

## Exact compatibility stack

Snow:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=passthrough
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=passthrough
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=passthrough
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=passthrough
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=passthrough
ROSETTA_CPS_SETFRONT_COMPAT_MODE=passthrough
```

Lion:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1
```

## Subject

Reuse the exact accepted subject from the protocol proof:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
build_id=cps-registration-setfront-trace-v1
required basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

Do not rebuild it unless its provenance changes.

The subject performs:

```text
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, foreground)
SetFrontProcess(returned PSN)
exit
```

It does not call GetFrontProcess or GetCurrentProcess, create a window, or enter an event loop.

## Exact SetFrontProcess integration predicate

The integration build accepts only the first SetFrontProcess request after exactly one successful CPS registration compatibility transaction, with:

```text
bits                                     0x1513
request ID                               0x729e
option                                   0x3
send                                     0x30
receive                                  0x2c
remote port                              nonzero
header reply port                        receive port, nonzero
timeout                                  0
notify                                   MACH_PORT_NULL
NDR                                      exact local NDR
PSN high                                 0
PSN low                                  nonzero
argument 2                               0
argument 3                               0
SetFront compatible call count           1
registration compatible call count       1
```

On Lion the handler:

1. copies the exact legacy request to a private buffer;
2. changes only request ID 0x729e to 0x72a1;
3. requires exactly one changed source-region byte and zero source-buffer mutations;
4. sends the private copy with unchanged 0x30/0x2c geometry;
5. requires native 0x7305/0x24/result 0 with the proven cross-endian NDR;
6. changes only private reply ID 0x7305 to 0x7302;
7. requires exactly one reply byte changed and result still 0;
8. copies the exact 0x24 legacy-facing reply back.

If any exact predicate or native-success check fails, the integration must not synthesize success.

## Safety constraints

- build only the new integration dylib on Snow Leopard 10.6.8;
- reuse the exact accepted SetFrontProcess subject from the protocol proof;
- reuse the accepted Security and CGS session-bootstrap interposers unchanged;
- require Snow passthrough before Lion;
- keep LSDONOTABORTIFNOASN unset;
- keep the accepted server-version and CPS-registration policies unchanged;
- call public SetFrontProcess exactly once;
- do not call private CPSSetFrontProcess separately;
- do not call GetFrontProcess or GetCurrentProcess;
- do not create a window or enter an event loop;
- do not broaden the 0x729e predicate;
- do not adapt any nonzero native SetFrontProcess result to success;
- do not alter the PSN or other request payload fields;
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

## Phase B — build the integration dylib on Snow Leopard

Reuse the exact accepted subject and build only the combined integration dylib:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.sha256
```

Require:

```text
build_id=dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-v1
architecture=ppc7400
__interpose size=0x10
imports bootstrap_look_up2, mach_msg, mig_get_reply_port
server-version compatibility markers present
CPS registration compatibility markers present
SetFront compatibility call/request/native-reply/adapted-reply/ADAPTER_PASS/PASSTHROUGH markers present
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Keep beside the new integration dylib:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-setfront-compat-integration-control.sh
```

Require final `RESULT: PASS` and:

```text
CPS registration compatibility          passthrough
GetProcessForPID                        PASS
GetProcessPID                           exact PID round-trip PASS
TransformProcessType                    PASS
PM_CPS_SETFRONT_COMPAT_CALL             index=1 mode=passthrough exact=YES
PM_CPS_SETFRONT_COMPAT_RESULT           PASSTHROUGH
legacy SetFront request/reply            0x729e -> 0x7302
legacy result                           0
SetFrontProcess                         0
M13_SUCCESS                             reached
SetFront ADAPTER_PASS                   absent
```

Phase C is a hard gate.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.sha256
ppc-process-manager-setfront-compat-integration-snowleopard-control.log
```

Reuse the exact accepted subject, Security interposer, CGS session-bootstrap interposer, and SHA sidecars unchanged.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Run the established native commpage probe and preserve the syscall-295 result as:

```text
syscall295-probe-process-manager-setfront-compat-integration.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion integration run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-setfront-compat-integration.sh
```

The desired result is:

```text
session-port compatibility               PASS
server-version compatibility             PASS
NewConnection                            PASS
CPS registration compatibility           PASS
_RegisterApplication -304                absent
GetProcessForPID                         PASS
GetProcessPID                            exact PID round-trip PASS
TransformProcessType                     PASS

PM_CPS_SETFRONT_COMPAT_CALL              index=1 mode=lion-setfront-v1 exact=YES
private request                          0x729e -> 0x72a1
request changed bytes                    1
source changed bytes                     0
native Mach result                       0
native reply                             0x7305 / 0x24 / result 0
private reply                            0x7305 -> 0x7302
reply changed bytes                      1
SetFront adapter                         PASS
legacy-facing reply                      0x7302 / result 0
SetFrontProcess                          0
M13_SUCCESS                              reached
new diagnostic                           none
protected hashes                         unchanged

RESULT: CPS_SETFRONT_COMPAT_INTEGRATION_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.sha256
ppc-process-manager-setfront-compat-integration-snowleopard-control.log
syscall295-probe-process-manager-setfront-compat-integration.log
lion-ppc-process-manager-setfront-compat-integration.log
lion-ppc-process-manager-setfront-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### CPS_SETFRONT_COMPAT_INTEGRATION_PASS

The exact SetFrontProcess ID-only policy is accepted as part of the normal combined compatibility build. This closes the current foreground-activation transport boundary for the validated Process Manager sequence.

Do not immediately broaden the adapter. Review the integration result first; a subsequent experiment may advance to the next observable Process Manager state, such as GetFrontProcess verification, while keeping all current predicates unchanged.

### Native reply rejected

The integration build reached Lion-native SetFrontProcess but did not receive the exact proven success reply. Preserve the native reply and stop.

### Predicate rejected

The live request no longer matches the exact proven geometry. Do not broaden it.

### Public SetFrontProcess failure after adapter PASS

Treat this as an integration defect even if the native request succeeded. Preserve the legacy-facing reply and public status.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
default CoreGraphics connection             -> established
CPS registration 0x7372 -> 0x73c1           -> accepted
GetProcessPID                               -> PASS
TransformProcessType                        -> PASS
SetFront protocol proof 0x729e -> 0x72a1    -> PASS
next step                                   -> integration build validation
```

No additional XNU change is indicated.
