# Process Manager CreateNewWindow CGS opacity create-alpha compatibility protocol policy proof

## Objective

Prove the smallest byte-level compatibility policy implied by the completed opacity alpha-plane static audit and passive branch/transport trace, without sending an adapted opacity request to WindowServer.

The completed Snow and Lion runs both selected the **create-alpha** branch beneath `CGSSetWindowOpacity`.

Observed live legacy request contract:

```text
request bits             0x1513
legacy create request    0x724f
expected legacy reply    0x72b3
mach_msg option          0x3
send / receive           0x24 / 0x2c
request window ID        Snow 0x113 / Lion 0x239
```

Snow returned Mach success with `0x72b3 / 0x24 / result 0`, then `CreateNewWindow` returned 0 with a nonzero WindowRef and reached DisposeWindow/M24.

Lion reached the same legacy create request only after the already accepted NewWindow and release-backing adapters had both completed with native Lion success. The opacity `mach_msg` then returned:

```text
kr             268451844
hex            0x10004004
meaning        MACH_RCV_TOO_LARGE
```

The passive failure-buffer snapshot was:

```text
postBits       0x80001200
postSize       0x18
postId         0x72b3
off18          0x00000000
off1c          0x08000000
off20          0x00000239
```

Those post-call bytes are diagnostic only and are **not** treated as a valid MIG reply.

The completed static audit established the corresponding Lion-native create-alpha contract:

```text
Snow/legacy request / reply    0x724f / 0x72b3
Lion native request / reply    0x7250 / 0x72b4
bits                           0x1513
mach_msg option                0x3
send / receive                 0x24 / 0x2c
accepted reply size            0x24
NDR/result handling            equivalent
```

The same static audit also showed that Snow terminate `0x7250/0x72b4` numerically collides with Lion create. The passive trace removes that ambiguity for the failing path: both systems actually selected **create**, not terminate.

## Why this stage is local-only

The trace proves that the translated PPC caller is issuing Snow's create-alpha routine number `0x724f` on Lion and that this reaches a receive-too-large boundary. It does not yet prove that translating the routine number to Lion's native create-alpha ID is sufficient in the live process.

The next safe discriminator is therefore a standalone copied-buffer proof with no Mach IPC. It must prove:

- request `0x724f -> 0x7250` changes exactly one byte;
- the complete `0x24` request body remains unchanged;
- the source request buffer remains unchanged;
- the live Lion window scalar at offset `0x20` is preserved;
- reply `0x72b4 -> 0x72b3` changes exactly one byte;
- the complete `0x24` reply body remains unchanged;
- a modeled native success result 0 remains 0;
- a modeled nonzero native result remains unchanged after reply-ID conversion.

The proof uses raw `0xd0feffff` / decoded `-304` only as a nonzero result-preservation sentinel because that cross-endian generated-MIG error value has already been observed elsewhere in this restoration. It was **not** returned by the opacity trace and must not be described as an observed opacity server result.

No WindowServer request is sent by this stage.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-adapter.c
scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol.sh
```

Build ID:

```text
createwindow-cgs-opacity-alpha-plane-create-compat-protocol-v1
```

The PPC executable performs no Mach IPC. Snow mode validates the observed successful legacy create-alpha geometry. Lion policy mode copies the exact observed Lion legacy request model, changes only the request ID in the private copy, then separately models a native success reply and a representative nonzero native error reply and changes only the reply ID.

The captured Snow and Lion window IDs are per-run object values used only to model the already observed requests. A later live compatibility predicate, if authorized, must require a nonzero live window ID and must not hard-code `0x113` or `0x239`.

## Safety constraints

- Build the proof executable only on Snow Leopard 10.6.8.
- Require the Snow local control before Lion.
- Transfer the exact hashed proof executable to Lion; do not rebuild it there.
- Repeat the established native syscall-295 safety gate on Lion.
- Keep `DYLD_INSERT_LIBRARIES` and `LSDONOTABORTIFNOASN` unset.
- Do not load any compatibility interposer for this proof.
- Do not call WindowServer, CoreGraphics window creation, Process Manager, CPS, or any private CGS API.
- Do not send `0x724f`, `0x7250`, or any other CGS Mach request.
- Do not add `MACH_RCV_LARGE`, change the `0x2c` receive size, or reinterpret the failure-buffer snapshot as a reply.
- Do not integrate opacity translation in this stage.
- Do not touch the accepted NewWindow or release-backing compatibility policies.
- Do not adapt terminate-alpha, display-bounds, ShapeWindow, or any later helper.
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

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld.sha256
```

Require a 32-bit PPC executable, `LC_LOAD_DYLINKER=/usr/oah/dyld`, the build ID above, and all `PM_CGS_OPACITY_ALPHA_CREATE_COMPAT` markers.

Stop if Phase B fails.

## Phase C — Snow Leopard local control

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-control.sh
```

Require:

```text
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_SNOW_LAYOUT:bits=0x00001513 legacyId=0x0000724f send=0x00000024 recv=0x0000002c reply=0x00000024 off20=0x00000113
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_SNOW_SUCCESS_REPLY:legacyId=0x000072b3 size=0x00000024 decodedResult=0 ndrSwapped=YES
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

This is a local byte-model control only; it does not rerun CreateNewWindow or contact WindowServer.

Stop if Phase C fails.

## Phase D — transfer the exact proof artifacts

Transfer to Lion:

```text
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld.sha256
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-snowleopard-control.log
```

Place the executable and SHA sidecar under `payload/`, or pass explicit paths. Do not rebuild on Lion.

## Phase E — repeat the Lion syscall-295 safety gate

Run the established native syscall-295 probe and save:

```text
syscall295-probe-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion copied-buffer policy proof

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol.sh
```

Require:

```text
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_REQUEST_POLICY:legacyId=0x0000724f lionId=0x00007250 send=0x00000024 recv=0x0000002c off20=0x00000239 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x000072b4 legacyId=0x000072b3 size=0x00000024 changedBytes=1 bodyChangedBytes=0 decodedResult=0 ndrSwapped=YES
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_ERROR_REPLY_POLICY:lionId=0x000072b4 legacyId=0x000072b3 size=0x00000024 changedBytes=1 bodyChangedBytes=0 rawResult=0xd0feffff decodedResult=-304 ndrSwapped=YES
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:LION_POLICY_PROOF_PASS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_POLICY_PROOF_PASS
```

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-private-dyld.sha256
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol.log
lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol.log
lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Stop after Phase G.

## Decision gate

### `CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_POLICY_PROOF_PASS`

The exact create-alpha ID-only copied-buffer policy is locally proven. The following stage may integrate only this policy into the existing two-tuple CoreServices `mach_msg` interposer.

A later live adapter must remain tightly gated to the observed create-alpha envelope. Snow remains passthrough. On Lion it may change only `0x724f -> 0x7250`, call the original `mach_msg` with unchanged bits/options/sizes/ports/timeout/notify and complete request body, accept only native reply ID `0x72b4` with the exact `0x24` reply geometry and cross-endian NDR, and change only the reply ID back to `0x72b3`. Any nonzero native result must be propagated unchanged.

Do not create the live create-alpha integration until this standalone result is reviewed.

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
NewWindow ID-only live integration              -> native Lion success
release-backing ID-only live integration        -> native Lion success
Snow opacity branch                             -> CREATE
Snow create-alpha 0x724f -> 0x72b3 / 0x24      -> Mach PASS, result 0, M24
Lion opacity branch                             -> CREATE
Lion legacy create-alpha request                -> 0x724f, 0x24/0x2c
Lion legacy create-alpha Mach return            -> 0x10004004 MACH_RCV_TOO_LARGE
Lion native create-alpha IDs                    -> 0x7250 / 0x72b4
next step                                       -> standalone ID-only copied-buffer policy proof
```

No additional XNU change is indicated.


## Observed completed result — create-alpha copied-buffer policy proof passed

The returned Snow control, syscall-295 gate, and Lion copied-buffer proof all pass.

Artifact/control provenance:

```text
build ID                     createwindow-cgs-opacity-alpha-plane-create-compat-protocol-v1
architecture                 ppc7400
LC_LOAD_DYLINKER             /usr/oah/dyld
proof executable SHA-256     8e26b90c7d3a33a9d93406bf8a6303dce8b2fd750117d25bb476a0aa9c0dcb95
Snow control                 PASS
syscall 295                  EBADF / no SIGSYS / PASS
new diagnostics              none
protected hashes             unchanged
```

The Lion local proof established:

```text
legacy request ID            0x724f
Lion request ID              0x7250
send / receive               0x24 / 0x2c
captured window ID           0x239
request changed bytes        1
request body changes         0
source request changes       0

Lion success reply ID        0x72b4
legacy success reply ID      0x72b3
reply size                   0x24
reply changed bytes          1
reply body changes           0
decoded result               0

modeled nonzero raw result   0xd0feffff
modeled decoded result       -304
nonzero result               preserved
RESULT                       CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_POLICY_PROOF_PASS
```

The `-304` value remains only a result-preservation sentinel in this local proof; it was not observed as an opacity server response in the passive trace.

This closes the local policy prerequisite for the live create-alpha adapter. The authoritative next procedure is:

```text
docs/process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-integration-experiment.md
```

That stage integrates only `0x724f -> 0x7250` and `0x72b4 -> 0x72b3` into the existing combined two-tuple CoreServices `mach_msg` interposer, keeps Snow strict passthrough, preserves the accepted NewWindow/release-backing adapters unchanged, and performs exactly one Lion CreateNewWindow run. Do not alter receive size, terminate-alpha, display-bounds, ShapeWindow, or XNU.
