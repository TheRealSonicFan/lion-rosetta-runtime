# Process Manager CPS registration compatibility integration experiment

## Objective

Integrate the now-proven CPS application-registration conversion into the existing two-tuple CoreServices compatibility interposer and determine whether restored Snow Leopard PPC registration is accepted by Lion WindowServer.

The prerequisite evidence is complete.

The passive trace proved that Snow Leopard PPC sends:

```text
request ID                         0x7372
send size                          0x84
receive size                       0x2c
reply ID                           0x73d6
success reply size                 0x24
Snow result                        0
Lion result to unchanged request   -304
```

The read-only differential proved that Lion native registration instead uses:

```text
request ID                         0x73c1
reply ID                           0x7425
send size                          legacy + 0x0c
receive size                       0x2c
success reply size                 0x24
appended tail                      byte 0, u32 0, u32 0x10
```

The standalone copied-buffer proof then passed with the exact observed registration geometry:

```text
legacy request                     0x7372 / 0x84
adapted request                    0x73c1 / 0x90
common bytes changed               exactly 1
source request changed             0
tail                               00 00 00 00 / 00000000 / 00000010
Lion reply                         0x7425 / 0x24 / result 0
legacy-facing reply                0x73d6 / 0x24 / result 0
reply bytes changed                exactly 2
standalone result                  CPS_REGISTRATION_COMPAT_POLICY_PROOF_PASS
```

This stage asks the remaining behavioral question: does the exact private-buffer request/reply translation remove the live `_RegisterApplication ... err=-304` failure while preserving the already-restored default CoreGraphics connection?

## Integration implementation

Current runtime `main` extends:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
```

with compile-time mode:

```text
PM_CPS_REGISTRATION_COMPAT_INTEGRATION
```

and runtime mode:

```text
ROSETTA_CPS_REGISTRATION_COMPAT_MODE
```

New build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-v1
```

The dylib still contains exactly two PPC interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

No third `mach_msg` interposer is introduced.

The existing CoreServices, SessionInit, server-version normalization, and passive CGS trace paths remain in the same dylib.

## Exact Snow behavior

Snow control sets:

```text
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=passthrough
```

The exact legacy `0x7372` transaction must be recognized but passed to the original `mach_msg` unchanged.

Require:

```text
legacy request                         0x7372 / 0x84
compat exact predicate                 YES
compat result                          PASSTHROUGH
reply                                  0x73d6 / result 0
CPS adapter                            NOT RUN
GetProcessForPID                       PASS
default connection                     nonzero
```

## Exact Lion request predicate

Lion sets:

```text
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
```

The adapter is eligible only for the first request that matches all of:

```text
request bits                           0x1513
request ID                             0x7372
mach_msg option                        0x3
explicit send size                     0x84
receive size                           0x2c
remote port                            nonzero
header reply port                      receive port, nonzero
timeout                                zero
notify                                 zero
request NDR                            exact local PPC NDR
MIG string length                      0x43
MIG string                             ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
compatible call count                  1
```

The caller's legacy request buffer is never expanded in place.

## Private-buffer request conversion

For an exact Lion-mode match, the interposer:

1. copies the full `0x84` legacy request into a private `0x100`-byte buffer;
2. changes only the private copy's request ID from `0x7372` to `0x73c1`;
3. appends the exact 12-byte Lion tail at offsets `0x84..0x8f`;
4. requires exactly one changed byte in the original `0x84` common region;
5. requires zero changed bytes in the caller's original request buffer;
6. calls the original `mach_msg` with explicit send size `0x90` and unchanged receive arguments.

The legacy header `msgh_size` word is copied unchanged because both the prior traces and standalone proof establish that this generated client uses the explicit `mach_msg` send-size argument as the authoritative request length.

The appended tail is exactly:

```text
0x84 byte                            0
0x85..0x87 padding                   0
0x88 u32                             0
0x8c u32                             0x10
```

All leading application identity, PSN/session, flags, path/name, and NDR bytes are preserved exactly from the live Snow request.

## Native reply acceptance and legacy-facing conversion

If the private Lion request returns Mach success, the adapter requires:

```text
reply bits                            0x1200
reply size                            0x24
reply ID                              0x7425
reply NDR                             swapped relative to PPC
decoded result                        0
```

Only then does it change the private reply ID from `0x7425` to `0x73d6`.

Post-checks require:

```text
legacy-facing reply ID                0x73d6
reply size                             0x24
decoded result                         0
changed reply bytes                    exactly 2
```

The converted `0x24` reply is then copied back to the original caller buffer, allowing the untouched Snow PPC generated `__CGSCheckInApplication` client to parse it normally.

If the native reply is not the exact successful shape, the interposer does not synthesize success. It copies the native reply back without ID conversion when possible and reports a rejection marker.

If request transformation post-checks fail, the original legacy request is sent unchanged.

## Safety constraints

For this stage:

- build only the new integration dylib on Snow Leopard 10.6.8;
- reuse the accepted registration-only subject, Security v1 interposer, and CGS session-bootstrap v1 interposer unchanged;
- require the Snow passthrough control before Lion;
- transfer the exact hashed integration dylib to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- run the Lion registration integration exactly once before review;
- keep `LSDONOTABORTIFNOASN` unset;
- do not call `GetProcessPID`, `TransformProcessType`, `SetFrontProcess`, `CPSSetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- do not adapt any registration request except the exact `0x7372` predicate above;
- do not adapt `0x729e` or `0x72a1`;
- do not fabricate a PSN, Mach right, connection record, or registration result;
- do not broaden the already-proven server-version normalizer;
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

## Phase B — build the integration dylib on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-cps-registration-compat-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.sha256
```

Require:

```text
build_id=dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-v1
architecture=ppc7400
__interpose size=0x10
imports bootstrap_look_up2, mach_msg, mig_get_reply_port
CPS compatibility call/request/native-reply/adapted-reply/ADAPTER_PASS markers present
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Keep the accepted subject/interposers and sidecars in the same directory:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cps-registration-compat-integration-control.sh
```

Require final:

```text
PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=passthrough exact=YES
PM_CPS_REGISTRATION_COMPAT_RESULT:PASSTHROUGH
CPS_CHECKIN_APPLICATION 0x7372 -> 0x73d6
reply result                            0
GetProcessForPID                        PASS
postidentity connection                 nonzero
RESULT: PASS
```

The Snow log must not contain `PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS`.

Phase C is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.sha256
ppc-process-manager-cps-registration-compat-integration-snowleopard-control.log
```

Reuse the accepted subject, Security interposer, CGS session-bootstrap interposer, and their SHA sidecars unchanged.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity and run the established native commpage probe.

Then preserve the syscall-295 probe as:

```text
syscall295-probe-process-manager-cps-registration-compat-integration.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion CPS registration integration

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cps-registration-compat-integration.sh
```

The runner enables exactly:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
```

The leading desired result is:

```text
PM_CPS_REGISTRATION_COMPAT_CALL:index=1 mode=lion-create-application-v1 exact=YES
PM_CPS_REGISTRATION_COMPAT_ADAPTED_REQUEST:... legacyId=0x7372 lionId=0x73c1 ... changedCommonBytes=1 sourceChangedBytes=0 ...
PM_CPS_REGISTRATION_COMPAT_NATIVE_MACH_RETURN:index=1 kr=0
PM_CPS_REGISTRATION_COMPAT_NATIVE_REPLY:index=1 ... id=0x7425 result=0 ...
PM_CPS_REGISTRATION_COMPAT_ADAPTED_REPLY:index=1 ... legacyId=0x73d6 ... changedBytes=2 result=0
PM_CPS_REGISTRATION_COMPAT_RESULT:ADAPTER_PASS
CPS_CHECKIN_APPLICATION legacy-facing reply 0x73d6 / result 0
_RegisterApplication err=-304                NOT PRESENT
GetProcessForPID                              PASS
postidentity connection                       nonzero
RESULT: CPS_REGISTRATION_COMPAT_REGISTRATION_ACCEPTED
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-compat.dylib.sha256
ppc-process-manager-cps-registration-compat-integration-snowleopard-control.log
syscall295-probe-process-manager-cps-registration-compat-integration.log
lion-ppc-process-manager-cps-registration-compat-integration.log
lion-ppc-process-manager-cps-registration-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CPS_REGISTRATION_COMPAT_REGISTRATION_ACCEPTED`

The exact native Lion application-registration request is accepted and the Snow PPC generated client sees a normal legacy success reply. This closes the CPS application-registration boundary.

Do not immediately adapt SetFrontProcess. First review this successful run and then advance the registration-only subject in a separate experiment to the previously proven `GetProcessPID` / `TransformProcessType` checkpoints. Only after those remain intact should the known later `0x729e -> 0x72a1` foreground mismatch become active again.

### `CPS_REGISTRATION_COMPAT_NATIVE_MACH_FAILURE`

The copied Lion request reached a transport failure. Preserve the numeric Mach result and stop.

### `CPS_REGISTRATION_COMPAT_NATIVE_REPLY_REJECTED`

Lion did not return the exact native success envelope/result. Preserve the native reply and do not synthesize legacy success.

### `CPS_REGISTRATION_COMPAT_ADAPTER_PASS_ERR_MINUS304_PERSISTS`

The request/reply conversion itself succeeded but Process Manager still reports `-304`. Stop and audit the immediate local registration state; do not broaden the adapter.

### `CPS_REGISTRATION_COMPAT_LEGACY_FACING_REPLY_NOT_ACCEPTED`

The adapter returned a legacy-facing reply, but the trace/client did not observe the expected success shape. Treat this as an integration defect.

### Any predicate rejection

The live request no longer matches the exact traced/proven subject geometry. No translation occurs; preserve the evidence and stop.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
__CGSNewConnectionPort 0x7469/0x74cd        -> PASS
CoreGraphics default connection             -> NONZERO
legacy CPS registration 0x7372              -> Lion returns -304
standalone 0x7372 -> 0x73c1 policy proof    -> PASS
next step                                   -> exact private-buffer live registration integration
later SetFrontProcess 0x729e/0x72a1          -> still out of scope
```

No additional XNU change is indicated.


## Observed completed result

The returned Snow control and Lion integration both passed. On Lion, the exact legacy registration request was copied to the native Lion form, the native reply returned result zero, the reply was converted back to the legacy ID, the registration adapter reported PASS, the previous registration error did not recur, GetProcessForPID remained successful, no new diagnostic was detected, protected hashes were unchanged, and the final result was CPS_REGISTRATION_COMPAT_REGISTRATION_ACCEPTED.

This closes the CPS application-registration boundary for the exact validated subject and compatibility stack. The authoritative next stage is docs/process-manager-cps-registration-postidentity-validation-experiment.md. That stage keeps the accepted registration adapter unchanged, rebuilds only the subject with the same exact executable basename, revalidates GetProcessPID and TransformProcessType, and stops before the foreground activation call.
