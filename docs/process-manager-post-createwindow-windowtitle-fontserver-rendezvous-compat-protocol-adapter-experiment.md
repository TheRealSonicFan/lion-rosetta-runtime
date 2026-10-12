# Post-CreateNewWindow window-title FontServer rendezvous compatibility protocol policy proof

## Objective

Prove the exact copied-buffer conversion implied by the completed Snow legacy rendezvous trace and the successful native Lion Rendezvous2 capture, without sending an adapted FontServer message.

The dynamic evidence now establishes both sides of the boundary.

Snow Leopard translated-PPC contract:

```text
client                       _XTSendRendezvous
request ID                   0x32c8
request bits                 0x1513
send / receive               0x18 / 0x3c
reply ID                     0x332c
success reply                complex, size 0x34
descriptor count             1
captured descriptor size     0x1000
decoded explicit size        0x1000
```

Native Lion i386 contract, now confirmed live:

```text
client                       _XTSendRendezvous2
request ID                   0x32e7
request bits                 0x1513
send / receive               0x18 / 0x40
mach_msg option              0x3
reply ID                     0x334b
success reply                complex, size 0x38
descriptor count             1
captured descriptor size     0x1000
protocol version             5
decoded explicit size        0x1000
```

The native request is still header-only. The native success reply preserves the Snow-style complex descriptor and NDR block, but inserts a four-byte protocol-version scalar at offset `0x30` and moves the explicit payload-size scalar from Snow offset `0x30` to Lion offset `0x34`. The native caller requires protocol version `5` before accepting the payload.

The successful native capture returned:

```text
reply bits                   0x80001200
reply size                   0x38
reply ID                     0x334b
descriptor count             1
descriptor address           0x000b7000
descriptor size              0x00001000
descriptor flags             0x01000101
protocol version             5
explicit size                0x00001000
```

The captured OOL address is per-run state. It is used only to make the standalone model concrete and must never become a live adapter predicate.

The first corrected native capture therefore satisfies the previous dynamic-server gate. The next safe discriminator is a no-Mach-IPC PPC copied-buffer proof before any live translated-PPC FontServer conversion.

## Required compatibility policy to prove

### Request

The legacy translated-PPC request remains `0x18` bytes and bodyless. A future adapter would:

- copy the complete legacy request to a private buffer;
- change only request ID `0x32c8 -> 0x32e7`;
- preserve bits, ports, pre-wrapper header scratch words, timeout, notify, and the full `0x18` source bytes;
- call the native transaction with send size `0x18`;
- increase only the receive-size argument from legacy `0x3c` to native `0x40`.

The receive-size change is an explicit envelope change, not a request-buffer mutation.

### Complex success reply

For a native `0x334b / 0x38` success reply, a future adapter would construct the legacy-facing `0x332c / 0x34` reply in a private copy:

- change reply ID `0x334b -> 0x332c`;
- change reply size `0x38 -> 0x34`;
- preserve the complex bit, descriptor count, complete OOL descriptor, and NDR bytes;
- require decoded protocol version `5`;
- remove exactly the four-byte protocol-version scalar at native offset `0x30`;
- relocate the native explicit-size scalar bytes from `0x34` to legacy `0x30`;
- preserve the native source reply unchanged.

This is not an ID-only reply transformation.

### Simple error reply

The generated Lion stub also accepts a simple `0x24` error reply. The policy proof must model that form and prove:

- reply ID `0x334b -> 0x332c`;
- size remains `0x24`;
- NDR and the nonzero result word remain unchanged;
- only the reply ID changes.

The proof uses raw `0xd0feffff` / decoded `-304` only as a nonzero result-preservation sentinel already established elsewhere in this restoration. It was not observed as a native Rendezvous2 error and must not be described as one.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-adapter.c
scripts/build-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.sh
```

Build ID:

```text
windowtitle-fontserver-rendezvous-compat-protocol-v1
```

The executable performs no Mach IPC. Snow mode validates the already captured legacy geometry. Lion policy mode performs only in-memory request/reply copies and structural checks.

## Safety constraints

- Build the standalone PPC proof only on Snow Leopard 10.6.8.
- Require the Snow local control before Lion.
- Transfer the exact hashed proof executable to Lion; do not rebuild it there.
- Repeat the established syscall-295 safety gate on Lion.
- Keep `DYLD_INSERT_LIBRARIES` and `LSDONOTABORTIFNOASN` unset.
- Do not load any FontServer/bootstrap/CGS compatibility interposer for this proof.
- Do not call `SetWindowTitleWithCFString`, CoreText, ATS, FontRegistry, FontServer, or `mach_msg`.
- Do not send `0x32c8`, `0x32e7`, or any other FontServer request.
- Do not rerun the translated-PPC title subject.
- Do not patch FontRegistry, CoreText, ATS, `libATSServer.dylib`, `fontd`, launchd, Rosetta, dyld, caches, or XNU.
- No XNU rebuild or reboot.
- Run the Lion policy proof exactly once before review.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build the standalone PPC proof on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld.info.txt
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld.sha256
```

Require a 32-bit PPC executable, `LC_LOAD_DYLINKER=/usr/oah/dyld`, the build ID above, and all required `PM_FONTSERVER_RENDEZVOUS_COMPAT` markers.

Stop if Phase B fails.

## Phase C — Snow Leopard local control

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-control.sh
```

Require:

```text
PM_FONTSERVER_RENDEZVOUS_COMPAT_SNOW_LAYOUT:bits=0x00001513 legacyId=0x000032c8 send=0x00000018 recv=0x0000003c replyId=0x0000332c replySize=0x00000034 descriptorCount=1 descriptorAddress=0x00654000 descriptorSize=0x00001000 explicitSize=0x00001000 ndrSwapped=YES
PM_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

This is a local byte-model control only. It does not contact FontServer.

## Phase D — transfer exact proof artifacts

Transfer:

```text
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld.info.txt
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-snowleopard-control.log
```

Place the executable and SHA sidecar under `payload/`, or pass explicit paths. Do not rebuild on Lion.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.log
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
/bin/bash ./scripts/run-lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.sh
```

Require:

```text
PM_FONTSERVER_RENDEZVOUS_COMPAT_REQUEST_POLICY:legacyId=0x000032c8 lionId=0x000032e7 send=0x00000018 legacyRecv=0x0000003c lionRecv=0x00000040 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0
PM_FONTSERVER_RENDEZVOUS_COMPAT_SUCCESS_REPLY_POLICY:lionId=0x0000334b legacyId=0x0000332c nativeSize=0x00000038 legacySize=0x00000034 protocolVersion=5 descriptorCount=1 descriptorAddress=0x000b7000 descriptorSize=0x00001000 nativeExplicitSize=0x00001000 legacyExplicitSize=0x00001000 preservedPrefixChangedBytes=0 sourceChangedBytes=0 descriptorPreserved=YES ndrPreserved=YES explicitSizeRelocated=YES removedProtocolBytes=4
PM_FONTSERVER_RENDEZVOUS_COMPAT_ERROR_REPLY_POLICY:lionId=0x0000334b legacyId=0x0000332c size=0x00000024 changedBytes=1 bodyChangedBytes=0 sourceChangedBytes=0 rawResult=0xd0feffff decodedResult=-304 ndrSwapped=YES
PM_FONTSERVER_RENDEZVOUS_COMPAT_RESULT:LION_POLICY_PROOF_PASS
protected_hashes_unchanged=YES
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_POLICY_PROOF_PASS
```

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld.info.txt
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-private-dyld.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-protocol.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Stop after Phase G.

## Decision gate

### Policy proof passes

The exact local conversion policy is proven. The following stage may integrate only this rendezvous conversion into the existing FontServer bootstrap/RPC interposer:

- target only the exact first legacy `0x32c8` / `0x18` transaction on the already identified FontServer service port;
- use a private `0x40`-byte request/reply buffer;
- change only request ID `0x32c8 -> 0x32e7`;
- call native `mach_msg` with send `0x18` and receive `0x40`;
- accept only `0x334b`;
- convert a complex `0x38` version-5 success reply into legacy `0x332c / 0x34` by removing the version word and relocating explicit size;
- map a simple `0x24` error reply only by reply ID and preserve its nonzero result;
- stop before adapting `0x32d9`, `0x32db`, or any later font operation.

Do not create the live integration until this standalone result is reviewed.

### Any request-copy or source-preservation failure

Stop. Do not integrate the rendezvous conversion.

### Protocol version is not exactly 5 in the modeled native success

Stop. The conversion contract is not satisfied.

### Descriptor/NDR/explicit-size preservation fails

Stop. Do not integrate a complex-reply conversion.

### New diagnostic or protected hash change

Preserve the evidence and stop.

## Current boundary

```text
Snow legacy rendezvous                     -> 0x32c8, 0x18/0x3c
Snow legacy success reply                  -> 0x332c, complex 0x34
Lion translated legacy request             -> 0x32c8
Lion translated legacy reply               -> simple 0x332c/0x24, -667
Lion native Rendezvous2 request            -> 0x32e7, 0x18/0x40, dynamically confirmed
Lion native Rendezvous2 success reply      -> 0x334b, complex 0x38, dynamically confirmed
Lion native protocol version               -> 5
native descriptor / explicit size          -> 0x1000 / 0x1000
next step                                  -> standalone no-IPC rendezvous copied-buffer policy proof
```

No additional XNU change is indicated.


## Observed completed result — copied-buffer rendezvous policy proof passed

The returned Snow control, Lion syscall-295 gate, and Lion no-IPC proof all pass.

Artifact/control provenance:

```text
build ID                         windowtitle-fontserver-rendezvous-compat-protocol-v1
architecture                     ppc7400
LC_LOAD_DYLINKER                 /usr/oah/dyld
proof executable SHA-256         6fab10b71e1d0c7fcc1efd9fc964f87f811ca1fd183c64e83275366ff7dac942
Snow control                     PASS
syscall 295                      EBADF / no SIGSYS / PASS
new diagnostics                  none
protected hashes                 unchanged
```

The Lion policy proof established:

```text
legacy request ID                0x32c8
Lion request ID                  0x32e7
send                             0x18
legacy receive                   0x3c
Lion receive                     0x40
request changed bytes            1
request body changes             0
source request changes           0

Lion success reply ID            0x334b
legacy success reply ID          0x332c
Lion success size                0x38
legacy success size              0x34
protocol version                 5
descriptor count                 1
descriptor size                  0x1000
native explicit size             0x1000
legacy explicit size             0x1000
preserved-prefix changes         0
source reply changes             0
descriptor preserved             YES
NDR preserved                    YES
explicit size relocated          YES
removed protocol bytes           4

modeled simple error size        0x24
error reply ID conversion        0x334b -> 0x332c
error body changes               0
modeled decoded error            -304
nonzero result                   preserved
RESULT                           POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_POLICY_PROOF_PASS
```

This closes the local proof prerequisite. The captured OOL address remains per-run state and is not a future live-adapter predicate.

The authoritative next procedure is:

```text
docs/process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration-experiment.md
```

That stage integrates only the first `0x32c8` rendezvous conversion into the existing two-tuple FontServer bootstrap/RPC interposer, keeps Snow strict passthrough, keeps passive tracing enabled, and performs exactly one Lion title run. Later FontServer operations remain unadapted even if the successful rendezvous reaches them.
