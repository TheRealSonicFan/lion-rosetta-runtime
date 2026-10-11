# Process Manager CreateNewWindow CGS NewWindow compatibility protocol policy proof

## Objective

Prove the smallest byte-level compatibility policy implied by the completed passive NewWindow transport trace, without yet sending an adapted request to WindowServer.

The live trace now closes the attribution that the previous static audit predicted. Snow Leopard PPC and Lion translated PPC send the same legacy inline transaction:

~~~text
request ID              0x7394
expected legacy reply   0x73f8
request bits            0x1513
mach_msg option         0x3
send size               0x68
receive size            0x40
~~~

The visible request words through offset 0x40 are identical in the Snow and Lion captures. Snow returns Mach success with a 0x73f8 / 0x38 reply and CreateNewWindow succeeds. Lion also returns Mach success and the expected legacy reply ID, but the reply is the 0x24 error form with raw result word 0xd0feffff; under the returned NDR this decodes to -304, exactly matching public CreateNewWindow=-304.

The static Lion i386 audit already established the corresponding native inline IDs:

~~~text
Snow PPC request/reply  0x7394 / 0x73f8
Lion native request     0x739a
Lion native reply       0x73fe
~~~

The request envelope, variable-size construction, receive size, success/error reply-size family, and NDR-aware parsing are otherwise aligned. This stage therefore tests only the copied-buffer ID policy 0x7394 -> 0x739a and 0x73fe -> 0x73f8.

## Why this stage is local-only

The passive trace proves that the legacy request already reaches the server and fails as a normal server reply, not as a Mach transport failure. It does not yet prove that changing the routine ID is sufficient in the live translated process.

The next safe discriminator is therefore a standalone copied-buffer proof with no Mach IPC. It must establish that the proposed conversion can be applied while preserving every other request/reply byte, including a nonzero native error result.

The proof deliberately does not assign semantics to request bytes beyond the prefix actually captured by the passive tracer. Bytes after offset 0x40 are filled with deterministic sentinels and must remain unchanged. This tests an ID-only copy policy without inventing payload meaning.

## Prepared implementation

Current runtime main provides:

~~~text
tests/ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-adapter.c
scripts/build-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol.sh
~~~

Build ID:

~~~text
createwindow-cgs-newwindow-compat-protocol-v1
~~~

The executable performs no Mach IPC. Its Lion policy mode copies a representative 0x68-byte legacy request, changes only the request ID, and proves the source request is unchanged. It separately models both accepted reply sizes and proves that only the reply ID changes; a modeled native error retains decoded result -304.

## Safety constraints

- Build the PPC proof only on Snow Leopard 10.6.8.
- Require the Snow local control before Lion.
- Transfer the exact hashed proof executable to Lion; do not rebuild it there.
- Repeat the established native syscall-295 safety gate on Lion.
- Keep DYLD_INSERT_LIBRARIES and LSDONOTABORTIFNOASN unset.
- Do not load any compatibility interposer for this proof.
- Do not call WindowServer, CoreGraphics window creation, Process Manager, CPS, or any private CGS API.
- Do not send 0x7394, 0x739a, or any other CGS Mach request.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, launchd, or XNU.
- Do not reboot or rebuild XNU.
- Run the Lion policy proof exactly once before review.

## Phase A — update repositories

On Snow Leopard and Lion:

~~~sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
~~~

On Lion also update the XNU documentation checkout:

~~~sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
~~~

## Phase B — build the standalone proof on Snow Leopard

~~~sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-on-snowleopard.sh
~~~

Expected outputs:

~~~text
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld.sha256
~~~

Require a 32-bit PPC executable, LC_LOAD_DYLINKER=/usr/oah/dyld, the build ID above, and all PM_CGS_NEWWINDOW_COMPAT markers.

## Phase C — Snow Leopard local control

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-control.sh
~~~

Require:

~~~text
PM_CGS_NEWWINDOW_COMPAT_SNOW_LAYOUT:bits=0x00001513 legacyId=0x00007394 send=0x00000068 recv=0x00000040 successReply=0x00000038 errorReply=0x00000024
PM_CGS_NEWWINDOW_COMPAT_CAPTURED_ERROR_MODEL:raw=0xd0feffff decoded=-304 ndrSwapped=YES
PM_CGS_NEWWINDOW_COMPAT_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
~~~

Stop if Phase C fails.

## Phase D — transfer exact proof artifacts

Transfer to Lion:

~~~text
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld.sha256
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-snowleopard-control.log
~~~

Place the executable and SHA sidecar under runtime payload/, or pass explicit paths. Do not rebuild on Lion.

## Phase E — repeat the Lion syscall-295 safety gate

Run the established native syscall-295 probe and save:

~~~text
syscall295-probe-process-manager-createwindow-cgs-newwindow-compat-protocol.log
~~~

Require result=-1, errno=9, saw_sigsys=0, and RESULT: PASS.

## Phase F — exactly one Lion copied-buffer policy proof

From the logged-in Aqua console user's Lion Terminal:

~~~sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol.sh
~~~

Require:

~~~text
PM_CGS_NEWWINDOW_COMPAT_REQUEST_POLICY:legacyId=0x00007394 lionId=0x0000739a send=0x00000068 recv=0x00000040 changedBytes=1 sourceChangedBytes=0
PM_CGS_NEWWINDOW_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x000073fe legacyId=0x000073f8 size=0x00000038 changedBytes=1 bodyChangedBytes=0 ndrSwapped=YES
PM_CGS_NEWWINDOW_COMPAT_ERROR_REPLY_POLICY:lionId=0x000073fe legacyId=0x000073f8 size=0x00000024 changedBytes=1 bodyChangedBytes=0 decodedResult=-304 ndrSwapped=YES
PM_CGS_NEWWINDOW_COMPAT_RESULT:LION_POLICY_PROOF_PASS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_POLICY_PROOF_PASS
~~~

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

~~~text
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld.info.txt
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-private-dyld.sha256
ppc-process-manager-createwindow-cgs-newwindow-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-newwindow-compat-protocol.log
lion-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol.log
lion-ppc-process-manager-createwindow-cgs-newwindow-compat-protocol.raw.log
~~~

Also return any new crash/core diagnostic named by the Lion runner. Stop after Phase G.

## Decision gate

### CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_POLICY_PROOF_PASS

The narrow ID-only copied-buffer policy is locally proven. The next stage may integrate that exact policy into the existing two-tuple CoreServices mach_msg interposer using a private request/reply buffer.

A later integrated adapter must remain tightly gated to the already traced legacy envelope. Snow remains passthrough. On Lion it may change only 0x7394 -> 0x739a in a private request copy, call the original mach_msg with the unchanged 0x68/0x40 envelope, accept only native reply ID 0x73fe with the statically accepted 0x38 success or 0x24 error size, and map only the reply ID back to 0x73f8. A nonzero native server result must be propagated unchanged; it must never be normalized to success.

Do not create that live integration until this standalone result is reviewed.

### Any preservation failure

Stop. Do not integrate an ID conversion.

### Unexpected NDR/error decode

Stop and refine the reply model before live IPC.

### Crash or new diagnostic

Preserve it and stop.

## Current boundary

~~~text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
Dock bootstrap compatibility                    -> PASS
Snow live NewWindow 0x7394 -> 0x73f8 / 0x38    -> PASS
Lion legacy 0x7394 -> 0x73f8 / 0x24            -> Mach PASS, decoded -304
Lion native inline IDs                          -> 0x739a / 0x73fe
next step                                       -> standalone ID-only copied-buffer policy proof
~~~

No additional XNU change is indicated.


## Observed completed result — copied-buffer ID policy proof passed

The returned Snow control, syscall-295 gate, and Lion policy proof fully pass this stage.

Artifact and control provenance:

~~~text
build ID                    createwindow-cgs-newwindow-compat-protocol-v1
architecture                ppc7400
LC_LOAD_DYLINKER            /usr/oah/dyld
proof executable SHA-256    70bcfc2a81bd39602c4002b5ffa77f2a7171cb2f3dfd4237940d44e18e9ef634
Snow control                PASS
syscall 295                 EBADF / no SIGSYS / PASS
~~~

The Lion copied-buffer proof established:

~~~text
legacy request ID           0x7394
Lion request ID             0x739a
send / receive              0x68 / 0x40
request changed bytes       1
source request changes      0

Lion success reply ID       0x73fe
legacy success reply ID     0x73f8
success reply size          0x38
reply changed bytes         1
reply body changes          0

Lion error reply ID         0x73fe
legacy error reply ID       0x73f8
error reply size            0x24
reply changed bytes         1
reply body changes          0
modeled decoded error       -304
new diagnostics             none
protected hashes            unchanged
RESULT                      CREATENEWWINDOW_CGS_NEWWINDOW_COMPAT_POLICY_PROOF_PASS
~~~

This closes the local policy prerequisite: for the validated transaction geometry, the proposed compatibility transformation changes only the generated MIG routine IDs and preserves the entire request/reply body, including a nonzero error result.

The authoritative next procedure is:

~~~text
docs/process-manager-createwindow-cgs-newwindow-compat-integration-experiment.md
~~~

That stage integrates the same ID-only policy into the existing combined CoreServices mach_msg interposer using a private buffer, keeps Snow strict passthrough, and performs one Lion CreateNewWindow run under the already accepted Dock, exact-four notification, and HIToolbox Extras compatibility stack. The live adapter must never normalize a nonzero native server result to success.
