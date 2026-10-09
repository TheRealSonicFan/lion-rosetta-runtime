# Process Manager SetFrontProcess compatibility protocol adapter experiment

## Objective

Prove the smallest exact compatibility policy for the now-live SetFrontProcess boundary after default-connection creation, CPS application registration, identity round-trip, and foreground conversion have all passed.

The completed passive trace establishes the active Lion failure precisely:

```text
legacy request                           0x729e
bits                                     0x1513
mach_msg option                          0x3
send / receive                           0x30 / 0x2c
legacy request Mach result               0
reply ID                                 0x7302
reply size                               0x24
reply result                             -304
public SetFrontProcess                   -304
new diagnostic                           none
protected hashes                         unchanged
```

Snow Leopard with the same unchanged PPC client returns:

```text
0x729e -> 0x7302
reply result 0
SetFrontProcess 0
```

The earlier static audit also proves that Lion native CoreGraphics uses the same message sizes and payload shape but different MIG routine IDs:

```text
Snow PPC request/reply                   0x729e / 0x7302
Lion native request/reply                0x72a1 / 0x7305
send / receive                           0x30 / 0x2c on both
payload                                  NDR + four 32-bit arguments
success reply                            0x24 with NDR + 32-bit result
```

Therefore this stage tests only an ID translation on a private copied buffer. It does not alter the original request buffer before transport and changes no payload field.

## Prepared implementation

Current runtime main provides:

```text
tests/ppc-process-manager-postidentity-setfrontprocess.c
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c

scripts/build-ppc-process-manager-setfront-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-setfront-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-setfront-compat-protocol.sh
```

The subject remains:

```text
build_id=cps-registration-setfront-trace-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

The exact basename is retained because the accepted CPS application-registration adapter remains narrowly gated to that previously traced registration string.

The protocol interposer build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-protocol-v1
```

It retains exactly two PPC interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

and keeps all already accepted compatibility behavior unchanged.

## Exact SetFrontProcess policy

The adapter considers only the first SetFrontProcess transaction after exactly one successful CPS registration compatibility call in the process.

The legacy request must match all of:

```text
bits                                     0x1513
request ID                               0x729e
option                                   0x3
send                                     0x30
receive                                  0x2c
remote port                              nonzero
reply port                               receive port, nonzero
timeout                                  0
notify                                   MACH_PORT_NULL
NDR                                      local NDR
PSN high                                 0
PSN low                                  nonzero
argument 2                               0
argument 3                               0
```

Snow mode is strict passthrough.

Lion mode:

1. copies the exact 0x30-byte legacy request to a private buffer;
2. changes only request ID 0x729e to 0x72a1;
3. verifies exactly one source byte changed and the original request buffer is unchanged;
4. sends the private copy with the unchanged 0x30/0x2c envelope;
5. requires native reply 0x7305, size 0x24, result 0, and expected cross-endian NDR;
6. changes only private reply ID 0x7305 to 0x7302;
7. verifies exactly one reply byte changed and result remains 0;
8. copies the 0x24 legacy-facing reply back to the original buffer.

No PSN, NDR, option field, Mach right, connection state, or server result is fabricated.

## Safety constraints

- keep LSDONOTABORTIFNOASN unset;
- build on Snow Leopard only;
- require Snow passthrough before Lion;
- reuse the accepted Security and session-bootstrap interposers unchanged;
- preserve the existing server-version and CPS registration adapters exactly;
- call public SetFrontProcess exactly once;
- do not call private CPSSetFrontProcess separately;
- do not call GetFrontProcess or GetCurrentProcess;
- do not create a window or enter an event loop;
- do not broaden the SetFrontProcess predicate;
- do not change payload fields other than the copied request/reply IDs;
- do not patch CoreGraphics, HIServices, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
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

## Phase B — build on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-setfront-compat-protocol-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-protocol.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-protocol.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-protocol.dylib.sha256
```

Require:

```text
subject architecture                      ppc7400
subject LC_LOAD_DYLINKER                  /usr/oah/dyld
subject imports                           GetProcessForPID/GetProcessPID/TransformProcessType/SetFrontProcess
protocol interposer architecture          ppc7400
protocol build ID                         ...setfront-compat-protocol-v1
__interpose size                          0x10
required SetFront compatibility markers   present
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-setfront-compat-protocol-control.sh
```

Require final `RESULT: PASS` and:

```text
PM_CPS_SETFRONT_COMPAT_CALL:index=1 mode=passthrough exact=YES
PM_CPS_SETFRONT_COMPAT_RESULT:PASSTHROUGH
0x729e -> 0x7302 / result 0
SetFrontProcess=0
PM_POSTIDENTITY_RESULT:SETFRONTPROCESS_PASS
PM_POSTIDENTITY_MILESTONE:M13_SUCCESS
```

No SetFront adapter PASS marker may appear on Snow.

Phase C is a hard gate.

## Phase D — transfer exact artifacts

Transfer the newly built subject/interposer and sidecars plus:

```text
ppc-process-manager-setfront-compat-protocol-snowleopard-control.log
```

Reuse unchanged:

```text
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Run the established native commpage probe, then preserve the syscall-295 probe as:

```text
syscall295-probe-process-manager-setfront-compat-protocol.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion protocol proof

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-setfront-compat-protocol.sh
```

The desired result is:

```text
registration adapter                      PASS
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType                      PASS

SetFront exact predicate                  YES
private request                           0x729e -> 0x72a1
request changed bytes                     1
source request changed bytes              0
native Mach result                        0
native reply                              0x7305 / 0x24 / result 0
private reply                             0x7305 -> 0x7302
reply changed bytes                       1
SetFront adapter                          PASS
legacy-facing reply                       0x7302 / result 0
SetFrontProcess                           0
M13_SUCCESS                               reached
new diagnostic                            none
protected hashes                          unchanged

RESULT: CPS_SETFRONT_COMPAT_POLICY_PROOF_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-protocol.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat-protocol.dylib.sha256
ppc-process-manager-setfront-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-setfront-compat-protocol.log
lion-ppc-process-manager-setfront-compat-protocol.log
lion-ppc-process-manager-setfront-compat-protocol.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### CPS_SETFRONT_COMPAT_POLICY_PROOF_PASS

The exact request-ID/reply-ID translation is sufficient for the current SetFrontProcess call and preserves the already-restored registration/identity path. The next stage may integrate this proven policy into the normal compatibility stack without broadening its predicate.

### Native 0x72a1 reply nonzero or malformed

The request-ID difference is not sufficient. Preserve the native reply and stop; do not normalize the server result.

### Predicate rejected

The live request differs from the proven trace. Review the new request first.

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
legacy SetFrontProcess 0x729e on Lion       -> reply -304 dynamically proven
native Lion SetFrontProcess ID              -> 0x72a1 statically proven
next step                                   -> exact copied-buffer ID policy proof
```

No additional XNU change is indicated.


## Observed completed result — SetFrontProcess policy proof passed

The returned Snow control and Lion protocol proof fully passed this stage.

Snow:

```text
SetFront compatibility mode             passthrough
exact legacy predicate                  YES
legacy request/reply                    0x729e -> 0x7302
reply result                            0
SetFrontProcess                         0
RESULT                                  PASS
```

Lion:

```text
exact legacy predicate                  YES
registration compatibility calls         1
private request                         0x729e -> 0x72a1
request changed bytes                   1
source request changed bytes             0
native Mach result                      0
native reply                            0x7305 / 0x24 / result 0
private reply                           0x7305 -> 0x7302
reply changed bytes                     1
SetFront adapter                        PASS
legacy-facing result                    0
SetFrontProcess                         0
M13_SUCCESS                             reached
new diagnostic                          none
protected hashes                        unchanged
RESULT                                  CPS_SETFRONT_COMPAT_POLICY_PROOF_PASS
```

This proves the SetFrontProcess incompatibility is exactly resolved by the narrow request/reply ID translation for the validated live request; no payload rewrite or server-result normalization is required.

The authoritative next stage is:

```text
docs/process-manager-setfront-compat-integration-experiment.md
```

That stage promotes the same exact copied-buffer policy to the normal combined compatibility build under `PM_CPS_SETFRONT_COMPAT_INTEGRATION`, reuses the accepted subject unchanged, requires Snow passthrough, and performs exactly one Lion integration run. Do not broaden the predicate.


The subsequent normal combined SetFrontProcess compatibility integration has now passed completely. The exact ID-only policy remains unchanged in the integration build and public SetFrontProcess returns success. The current authoritative next procedure is `docs/process-manager-getfrontprocess-validation-experiment.md`; do not rerun this protocol proof unless SetFrontProcess message provenance changes.
