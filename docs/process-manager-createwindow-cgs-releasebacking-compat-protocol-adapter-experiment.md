# Process Manager CreateNewWindow CGS release-backing compatibility protocol policy proof

## Objective

Prove the smallest byte-level compatibility policy implied by the completed passive `CGSSetWindowToReleaseBackingOnOrderOut` transport trace, without sending an adapted request to WindowServer.

The live trace now reproduces the same legacy generated-MIG envelope on Snow Leopard PPC and Lion translated PPC:

```text
request bits             0x1513
legacy request ID        0x724b
expected legacy reply    0x72af
mach_msg option          0x3
send / receive           0x28 / 0x2c
reply size               0x24
```

Snow returns Mach success with `0x72af / 0x24` and decoded result 0, then the public `CreateNewWindow` path continues to M24. Lion also returns Mach success and the expected legacy reply ID, but its `0x24` reply carries raw result `0xd0feffff`, which decodes under the returned cross-endian NDR to `-304`; CoreGraphics immediately reports a MIG server type-check failure for `CGSSetWindowToReleaseBackingOnOrderOut`.

The exact live request payload words were:

```text
Snow PPC   off18=0x00000000 off1c=0x00000000 off20=0x000000ff off24=0x00000001
Lion PPC   off18=0x00000000 off1c=0x00000000 off20=0x0000020a off24=0x00000001
```

The differing `off20` scalar is a per-run object value and is not used as evidence of an ABI mismatch. The static differential established the same two-scalar request layout on Snow PPC and Lion i386. This proof therefore preserves the complete captured Lion request body and changes only the generated routine ID.

The corresponding native Lion generated-MIG IDs are:

```text
Snow/legacy request / reply    0x724b / 0x72af
Lion native request / reply    0x724c / 0x72b0
```

Both clients use the same bits, Mach option, send/receive sizes, `0x24` reply geometry, and NDR-aware result decode.

## Why this stage is local-only

The passive trace proves the legacy transaction reaches the server and returns a structurally normal generated-MIG error reply rather than failing at Mach transport. It does not yet prove that changing the routine ID is sufficient in the live translated process.

The next safe discriminator is therefore a standalone copied-buffer proof with no Mach IPC. It must prove:

- request `0x724b -> 0x724c` changes exactly one byte;
- the complete `0x28` request body remains unchanged;
- the source request buffer remains unchanged;
- reply `0x72b0 -> 0x72af` changes exactly one byte;
- the complete `0x24` reply body remains unchanged;
- a native success result 0 remains 0;
- a modeled native error using the captured raw result `0xd0feffff` remains decoded `-304`.

No WindowServer request is sent by this stage.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-adapter.c
scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol.sh
```

Build ID:

```text
createwindow-cgs-releasebacking-compat-protocol-v1
```

The PPC executable performs no Mach IPC. Its Snow mode validates the observed Snow request/reply geometry. Its Lion policy mode copies the exact observed Lion legacy request model, rewrites only the request ID in the private copy, then separately models native success and error replies and rewrites only the reply ID.

## Safety constraints

- Build the proof executable only on Snow Leopard 10.6.8.
- Require the Snow local control before Lion.
- Transfer the exact hashed proof executable to Lion; do not rebuild it there.
- Repeat the established native syscall-295 safety gate on Lion.
- Keep `DYLD_INSERT_LIBRARIES` and `LSDONOTABORTIFNOASN` unset.
- Do not load any compatibility interposer for this proof.
- Do not call WindowServer, CoreGraphics window creation, Process Manager, CPS, or any private CGS API.
- Do not send `0x724b`, `0x724c`, or any other CGS Mach request.
- Do not integrate release-backing translation in this stage.
- Do not touch the accepted NewWindow compatibility policy.
- Do not trace or adapt opacity, display-bounds, ShapeWindow, or any later post-NewWindow helper.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, launchd, or XNU.
- Do not rebuild or reboot XNU.
- Run the Lion policy proof exactly once before review.

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

## Phase B — build the standalone proof on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld.sha256
```

Require a 32-bit PPC executable, `LC_LOAD_DYLINKER=/usr/oah/dyld`, the build ID above, and all `PM_CGS_RELEASEBACKING_COMPAT` markers.

## Phase C — Snow Leopard local control

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-control.sh
```

Require:

```text
PM_CGS_RELEASEBACKING_COMPAT_SNOW_LAYOUT:bits=0x00001513 legacyId=0x0000724b send=0x00000028 recv=0x0000002c reply=0x00000024 off20=0x000000ff off24=0x00000001
PM_CGS_RELEASEBACKING_COMPAT_SNOW_SUCCESS_REPLY:legacyId=0x000072af size=0x00000024 decodedResult=0 ndrSwapped=YES
PM_CGS_RELEASEBACKING_COMPAT_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

Stop if Phase C fails.

## Phase D — transfer the exact proof artifacts

Transfer to Lion:

```text
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld.sha256
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-snowleopard-control.log
```

Place the executable and SHA sidecar under `payload/`, or pass explicit paths. Do not rebuild on Lion.

## Phase E — repeat the Lion syscall-295 safety gate

Run the established native syscall-295 probe and save:

```text
syscall295-probe-process-manager-createwindow-cgs-releasebacking-compat-protocol.log
```

Require `result=-1`, `errno=9`, `saw_sigsys=0`, and `RESULT: PASS`.

## Phase F — exactly one Lion copied-buffer policy proof

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol.sh
```

Require:

```text
PM_CGS_RELEASEBACKING_COMPAT_REQUEST_POLICY:legacyId=0x0000724b lionId=0x0000724c send=0x00000028 recv=0x0000002c off20=0x0000020a off24=0x00000001 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0
PM_CGS_RELEASEBACKING_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x000072b0 legacyId=0x000072af size=0x00000024 changedBytes=1 bodyChangedBytes=0 decodedResult=0 ndrSwapped=YES
PM_CGS_RELEASEBACKING_COMPAT_ERROR_REPLY_POLICY:lionId=0x000072b0 legacyId=0x000072af size=0x00000024 changedBytes=1 bodyChangedBytes=0 rawResult=0xd0feffff decodedResult=-304 ndrSwapped=YES
PM_CGS_RELEASEBACKING_COMPAT_RESULT:LION_POLICY_PROOF_PASS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_POLICY_PROOF_PASS
```

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-private-dyld.sha256
ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-releasebacking-compat-protocol.log
lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol.log
lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-protocol.raw.log
```

Also return any new crash/core diagnostic named by the Lion runner. Stop after Phase G.

## Decision gate

### `CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_POLICY_PROOF_PASS`

The exact release-backing ID-only copied-buffer policy is locally proven. The following stage may integrate only this policy into the existing two-tuple CoreServices `mach_msg` interposer.

A later live adapter must remain tightly gated to the observed release-backing envelope and must use a private request/reply buffer. Snow remains passthrough. On Lion it may change only `0x724b -> 0x724c`, call the original `mach_msg` with unchanged bits/options/sizes/ports/timeout/notify and body, accept only native reply ID `0x72b0` with the exact `0x24` reply geometry, and change only the reply ID back to `0x72af`. Any nonzero native result must be propagated unchanged.

Do not create the live release-backing integration until this standalone result is reviewed.

### Any preservation failure

Stop. Do not integrate an ID conversion.

### Unexpected NDR/result decode

Stop and refine the reply model before live IPC.

### Crash or new diagnostic

Preserve it and stop.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
Dock bootstrap compatibility                    -> PASS
NewWindow ID-only live integration              -> native Lion success
Snow release-backing 0x724b -> 0x72af / 0x24   -> Mach PASS, result 0
Lion release-backing 0x724b -> 0x72af / 0x24   -> Mach PASS, decoded -304
Lion native release-backing IDs                 -> 0x724c / 0x72b0
next step                                       -> standalone ID-only copied-buffer policy proof
```

No additional XNU change is indicated.
