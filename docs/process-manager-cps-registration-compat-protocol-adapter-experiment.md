# Process Manager CPS registration compatibility protocol policy proof

## Objective

Prove the exact byte-level compatibility policy required to translate the restored Snow Leopard PPC CPS application-registration transaction into the Lion native transaction, without yet returning an adapted registration request to WindowServer.

The completed passive transport trace directly joins the surviving registration diagnostic to the legacy wire call.

Snow Leopard control:

```text
request                               0x7372
send size                             0x84
receive size                          0x2c
Mach result                           0
reply                                 0x73d6
reply size                            0x24
reply scalar                          0
GetProcessForPID                      PASS
default connection                    nonzero
```

Lion translated PPC:

```text
request                               0x7372
send size                             0x84
receive size                          0x2c
Mach result                           0
reply                                 0x73d6
reply size                            0x24
raw result word                       0xd0feffff
reply NDR                             little-endian relative to PPC
decoded result                        -304
_RegisterApplication diagnostic       err=-304
GetProcessForPID                      PASS
default connection                    nonzero
```

The `-304` is therefore not inferred from the later diagnostic: it is the NDR-decoded scalar returned directly in the successful `0x73d6` reply.

The preceding static differential already established the Lion replacement contract:

```text
legacy request/reply                  0x7372 / 0x73d6
Lion request/reply                    0x73c1 / 0x7425
legacy send size                      aligned-string + 0x40
Lion send size                        aligned-string + 0x4c
receive size                          0x2c in both
success reply size                    0x24 in both
Lion appended tail                    byte 0, u32 0, u32 0x10
```

For the observed registration name, the MIG string length is `0x43`, so the exact observed sizes are:

```text
legacy                                0x84
Lion                                  0x90
delta                                 0x0c
```

## Why this stage is copied-buffer only

The server has already shown that the legacy request reaches the registration endpoint but returns `-304`, and the native Lion client contract is statically known. The remaining pre-integration question is whether the compatibility transformation can be defined narrowly enough to avoid touching unrelated request bytes or reply fields.

This stage therefore does **not** send `0x73c1` to WindowServer.

It constructs the exact observed legacy request shape in a standalone PPC executable, copies it into a private output buffer, and proves the transformation policy:

```text
request ID                            0x7372 -> 0x73c1
mach_msg send size                    0x84 -> 0x90
request bits                          unchanged 0x1513
receive size                          unchanged 0x2c
all common request bytes              unchanged except request ID
legacy source buffer                  unchanged
12-byte appended tail                 00 00 00 00 / 00000000 / 00000010
```

The generated MIG clients do not depend on the header `msgh_size` word for this call; the live traces show that field contains unrelated stack content while the explicit `mach_msg` send-size argument is authoritative. The policy proof therefore preserves that header word and changes only the explicit send size that a future interposer would pass to the original `mach_msg`.

For a successful Lion reply the local proof then proves:

```text
reply ID                              0x7425 -> 0x73d6
reply size                            remains 0x24
NDR                                   unchanged
result scalar                         remains 0
all reply bytes                       unchanged except reply ID
legacy parser result                  0
```

A future integration adapter, if justified by this proof, must use a private request/reply buffer rather than expanding the caller's legacy request in place.

## Prepared standalone proof

Current runtime `main` provides:

```text
tests/ppc-process-manager-cps-registration-compat-protocol-adapter.c
scripts/build-ppc-process-manager-cps-registration-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-cps-registration-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-cps-registration-compat-protocol.sh
```

Build ID:

```text
cps-registration-compat-protocol-v1
```

The executable has two modes.

### `snow-control`

It validates:

- the exact observed legacy request geometry;
- request bits `0x1513`;
- request ID `0x7372`;
- observed send/receive sizes `0x84/0x2c`;
- observed string length `0x43`;
- the captured Lion raw error word `0xd0feffff` under the observed swapped NDR model;
- decoded result `-304`.

It performs no Mach IPC and no compatibility rewrite.

### `lion-policy-proof`

It copies the representative legacy request, applies only the proposed request-ID plus 12-byte-tail transformation, and requires:

```text
legacy ID                             0x7372
adapted ID                            0x73c1
legacy send                           0x84
adapted send                          0x90
receive size                          0x2c
changed common bytes                  exactly 1
source-buffer changed bytes           0
tail byte                             0
tail u32[0]                           0
tail u32[1]                           0x10
```

The single changed common byte is the low byte difference between the two 32-bit request IDs in PPC byte order. The source request remains untouched.

It then constructs a successful Lion-format reply in a separate local buffer and proves the exact legacy-facing reply-ID conversion:

```text
Lion reply ID                         0x7425
legacy-facing reply ID                0x73d6
reply size                            0x24
changed reply bytes                   exactly 2
decoded result                        0
NDR swapped relative to PPC           YES
```

No request or reply buffer from this executable is sent to WindowServer.

## Safety constraints

For this stage:

- build only on Snow Leopard 10.6.8;
- require the Snow control before Lion;
- transfer the exact hashed executable to Lion;
- repeat the established native commpage and syscall-295 gates;
- run the Lion copied-buffer proof exactly once before review;
- keep `DYLD_INSERT_LIBRARIES` and `LSDONOTABORTIFNOASN` unset;
- do not load any compatibility interposer;
- do not call WindowServer, CoreGraphics registration, CPS, Process Manager, SetFrontProcess, or any private CGS registration API;
- do not send `0x7372`, `0x73c1`, `0x729e`, or any other CGS/CPS Mach request;
- do not fabricate a PSN, connection record, Mach right, or server-side registration state;
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

## Phase B validator correction

The first attempted Phase B exposed a build-script validation defect, not a compiler or Mach-O defect. The script successfully compiled the executable and patched `LC_LOAD_DYLINKER` to `/usr/oah/dyld`, but then treated failure of both `lipo -verify_arch` invocation forms as conclusive evidence that the output was not PPC. On that same output, Snow Leopard `file` reported:

```text
Mach-O executable ppc
```

Current `main` corrects the validator. Both the Snow builder and the Lion policy-proof runner now use the same architecture predicate already proven in the earlier server-version builder:

1. try both supported `lipo -verify_arch ppc` argument orders;
2. if neither verifies the file, inspect `/usr/bin/file`;
3. accept only a tokenized `ppc` or `powerpc` Mach-O description;
4. explicitly reject `ppc64` / `powerpc64`.

The previously failed Phase B output should not be promoted to later phases because the script exited before producing its normal `.info.txt` and SHA sidecar. Pull current `main`, discard or overwrite that partial output, and rerun Phase B. No source-level policy change is involved.

## Phase B — build on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-cps-registration-compat-protocol-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-cps-registration-compat-protocol-private-dyld
ppc-process-manager-cps-registration-compat-protocol-private-dyld.info.txt
ppc-process-manager-cps-registration-compat-protocol-private-dyld.sha256
```

Require:

```text
build_id=cps-registration-compat-protocol-v1
architecture=ppc7400
LC_LOAD_DYLINKER=/usr/oah/dyld
```

If Phase B fails, stop.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cps-registration-compat-protocol-control.sh
```

Require:

```text
PM_CPS_REGISTRATION_COMPAT_SNOW_LAYOUT:bits=0x00001513 id=0x00007372 send=0x00000084 recv=0x0000002c stringLength=0x00000043
PM_CPS_REGISTRATION_COMPAT_CAPTURED_ERROR_MODEL:raw=0xd0feffff decoded=-304 ndrSwapped=YES
PM_CPS_REGISTRATION_COMPAT_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

Phase C is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts

Transfer:

```text
ppc-process-manager-cps-registration-compat-protocol-private-dyld
ppc-process-manager-cps-registration-compat-protocol-private-dyld.info.txt
ppc-process-manager-cps-registration-compat-protocol-private-dyld.sha256
ppc-process-manager-cps-registration-compat-protocol-snowleopard-control.log
```

Place the executable and SHA sidecar under runtime `payload/`, or pass explicit paths.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity and run the established native commpage probe.

Then preserve the syscall-295 probe as:

```text
syscall295-probe-process-manager-cps-registration-compat-protocol.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion copied-buffer policy proof

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cps-registration-compat-protocol.sh
```

Require:

```text
PM_CPS_REGISTRATION_COMPAT_REQUEST_POLICY:legacyId=0x00007372 lionId=0x000073c1 legacySend=0x00000084 lionSend=0x00000090 recv=0x0000002c changedCommonBytes=1 sourceChangedBytes=0 tailByte=0x00 tailU32_0=0x00000000 tailU32_1=0x00000010
PM_CPS_REGISTRATION_COMPAT_REPLY_POLICY:lionId=0x00007425 legacyId=0x000073d6 size=0x00000024 changedBytes=2 result=0 ndrSwapped=YES
PM_CPS_REGISTRATION_COMPAT_RESULT:LION_POLICY_PROOF_PASS
RESULT: CPS_REGISTRATION_COMPAT_POLICY_PROOF_PASS
```

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cps-registration-compat-protocol-private-dyld.info.txt
ppc-process-manager-cps-registration-compat-protocol-private-dyld.sha256
ppc-process-manager-cps-registration-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-cps-registration-compat-protocol.log
lion-ppc-process-manager-cps-registration-compat-protocol.log
lion-ppc-process-manager-cps-registration-compat-protocol.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CPS_REGISTRATION_COMPAT_POLICY_PROOF_PASS`

The exact request/reply conversion policy is locally proven without Mach IPC. The next stage may integrate it into the existing two-tuple CoreServices `mach_msg` interposer using a private buffer:

1. accept only the exact legacy `0x7372` request envelope already traced;
2. copy the request;
3. change request ID to `0x73c1`;
4. append the exact 12-byte Lion tail;
5. call the original `mach_msg` with adapted send size `legacy + 0x0c`;
6. require successful Lion reply `0x7425` / `0x24`;
7. copy the reply back with only the reply ID converted to `0x73d6`;
8. let the untouched Snow PPC generated client parse the result.

Snow must remain passthrough.

Do not build that integrated adapter until this standalone result is reviewed.

### Any source/common-byte preservation failure

Stop. The transformation is too broad or the proof is defective.

### Tail mismatch

Stop. Do not infer alternate Lion defaults.

### Reply conversion or NDR failure

Stop. Do not integrate.

### Crash or new diagnostic

Preserve it and stop.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
__CGSNewConnectionPort 0x7469/0x74cd        -> PASS
CoreGraphics default connection             -> NONZERO
Snow CPS registration request               -> 0x7372 / send 0x84
Lion reply to legacy request                -> 0x73d6 / result -304
Lion native CPS registration                -> 0x73c1 / 0x7425
Lion native request size                    -> legacy + 0x0c
dynamic failure mechanism                   -> directly confirmed
next step                                   -> standalone copied-buffer registration policy proof
later SetFrontProcess 0x729e/0x72a1          -> still out of scope
```

No additional XNU change is indicated.
