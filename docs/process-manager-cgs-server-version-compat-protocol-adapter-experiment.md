# Process Manager CGS server-version compatibility policy proof

## Objective

Prove the narrowest server-version compatibility policy in a standalone translated-PPC executable before changing the integrated CoreGraphics registration path.

The completed passive trace has now confirmed the exact failure mechanism dynamically.

Snow Leopard positive control:

```text
SERVER_VERSION request                      -> 0x7148
SERVER_VERSION reply                        -> 0x71ac
reply shape                                 -> complex, size 0x40
decoded server version                      -> 545 / 0
raw version word at 0x30                    -> 0x21020000
NewConnection 0x7469                        -> reached
registration                               -> PASS
```

Lion translated PPC after the proven session-port adapter:

```text
SERVER_VERSION request                      -> 0x7148
SERVER_VERSION reply                        -> 0x71ac
reply shape                                 -> complex, size 0x40
decoded server version                      -> 600 / 0
raw version word at 0x30                    -> 0x58020000
NewConnection 0x7469                        -> not reached
process exit                                -> status 1
new diagnostic                              -> none
protected hashes                            -> unchanged
```

The remaining server-version reply words are structurally identical between the Snow and Lion controls apart from expected Mach port names and the version value. Both replies use little-endian NDR relative to the PPC client, so the observed raw words decode as:

```text
0x21020000 -> byte-swapped 0x00000221 -> 545
0x58020000 -> byte-swapped 0x00000258 -> 600
```

This exactly matches the static Snow PPC control flow already established in `_connectAndCheck`: it compares the server major/minor pair against the local Snow PPC CoreGraphics pair, can return `0x3f0` on a disallowed mismatch, and `_CGSServerPort` converts `0x3f0` into `exit(1)`.

The compatibility question is therefore no longer whether the Lion WindowServer accepts the legacy request. It does. The question is whether a process-local compatibility layer can normalize only the returned server-version pair while leaving the reply shape, descriptor right, NDR representation, auxiliary fields, and every unrelated transaction unchanged.

## Prepared standalone proof

Current runtime `main` provides:

```text
tests/ppc-process-manager-cgs-server-version-compat-protocol-adapter.c
scripts/build-ppc-process-manager-cgs-server-version-compat-protocol-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-cgs-server-version-compat-protocol-control.sh
scripts/run-lion-ppc-process-manager-cgs-server-version-compat-protocol.sh
```

Build ID:

```text
cgs-server-version-compat-protocol-v1
```

The executable has two modes.

### `snow-control`

It performs only:

```text
task bootstrap special port 4
bootstrap_look_up("com.apple.windowserver.session")
server-version request 0x7148
decode complex reply 0x71ac
validate descriptor send right
validate decoded server version = 545 / 0
deallocate received rights
exit
```

No compatibility rewrite is applied on Snow Leopard.

### `lion-policy-proof`

It performs only:

```text
task bootstrap special port 4
Lion active-root lookup 0x194, flags 8
GetSessionPort 0x7151 -> 0x71b5
validate session send right
server-version request 0x7148
decode original complex reply 0x71ac
require original server version = 600 / 0
validate returned descriptor send right
copy reply bytes into local standalone buffer
normalize only version major/minor to 545 / 0 using reply NDR byte order
reparse copied buffer with the legacy PPC reply parser
require adapted version = 545 / 0
require zero changed bytes outside the version-word region
deallocate received rights
exit
```

The adapted byte buffer is never returned to CoreGraphics and is never sent back to WindowServer. This stage proves only the exact byte-level compatibility policy.

## Exact policy under test

The standalone normalizer is intentionally narrow.

It is eligible only after the reply has already passed all of these checks:

```text
request ID                         0x7148
reply ID                           0x71ac
Mach result                        KERN_SUCCESS
reply                              complex
reply size                         0x40
descriptor count                   1
descriptor disposition/type        0x11 / 0x00
descriptor port                    nonzero send right
original decoded version           600 / 0
local Snow PPC target version      545 / 0
```

The proof rewrites only the two decoded version words at reply offsets `0x30` and `0x34`, encoded according to the reply NDR representation. For the observed Lion reply the minor word is already zero, so only the major-version byte content should materially change.

The proof must also establish:

```text
descriptor port unchanged
descriptor disposition/type unchanged
auxiliary output unchanged
flags output unchanged
all bytes outside 0x30..0x37 unchanged
adapted decoded version = 545 / 0
```

No production interposer is installed by this experiment.

## Safety constraints

For this stage:

- build the standalone PPC executable only on Snow Leopard 10.6.8;
- require the Snow control before Lion;
- transfer the exact hashed executable to Lion;
- repeat the established native commpage and syscall-295 gates;
- run the Lion standalone proof exactly once before review;
- keep `DYLD_INSERT_LIBRARIES` unset;
- do not load the CoreServices, Security, or CGS compatibility interposers;
- do not call Process Manager registration, CPS, SetFrontProcess, or create a window;
- do not call `_CGSServerPort`, `_CGSNewConnection`, or `__CGSNewConnectionPort`;
- do not change CoreGraphics defaults or enable a broad unmatched-version preference;
- do not modify any live reply that CoreGraphics itself will consume;
- do not adapt `0x7469` or `0x729e`;
- do not fabricate a connection record or Mach right;
- do not patch CoreGraphics, WindowServer, Rosetta, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer or launchd jobs;
- do not use a debugger, DTrace, dtruss, or live injection.

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

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-cgs-server-version-compat-protocol-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld.info.txt
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld.sha256
```

Require:

- build ID `cgs-server-version-compat-protocol-v1`;
- 32-bit PPC executable;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- imports for `bootstrap_look_up`, `bootstrap_port`, `mig_get_reply_port`, `mach_msg`, `task_get_special_port`, `mach_port_type`, `mach_port_deallocate`, and `getpid`;
- policy/adaptation markers in the executable.

If Phase B fails, stop and return the complete build output.

## Phase C — Snow Leopard positive control

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cgs-server-version-compat-protocol-control.sh
```

Require:

```text
PM_CGS_SERVER_VERSION_LAYOUT:PASS
PM_CGS_SERVER_VERSION_SNOW_LOOKUP_RETURN:kr=0
PM_CGS_SERVER_VERSION_MACH_RETURN:kr=0
PM_CGS_SERVER_VERSION_REPLY:... id=0x000071ac ... major=545 minor=0
PM_CGS_SERVER_VERSION_RIGHT:label=snow-version-descriptor ... send=YES
PM_CGS_SERVER_VERSION_SNOW_POLICY:... match=YES
PM_CGS_SERVER_VERSION_RESULT:SNOW_CONTROL_PASS
RESULT: PASS
```

Phase C is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts

Transfer privately:

```text
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld.info.txt
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld.sha256
ppc-process-manager-cgs-server-version-compat-protocol-snowleopard-control.log
```

Place the executable and SHA sidecar under runtime `payload/`, or pass explicit paths.

Do not rebuild on Lion.

## Phase E — repeat native safety gates

Use the validated syscall-295 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing PASS.

Then run the established syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-cgs-server-version-compat-protocol.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion standalone policy proof

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cgs-server-version-compat-protocol.sh
```

The runner performs no interposition. It executes only the standalone `lion-policy-proof` mode.

Require the final result:

```text
RESULT: CGS_SERVER_VERSION_COMPAT_POLICY_PROOF_PASS
```

Do not rerun Phase F before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld.info.txt
ppc-process-manager-cgs-server-version-compat-protocol-private-dyld.sha256
ppc-process-manager-cgs-server-version-compat-protocol-snowleopard-control.log
syscall295-probe-process-manager-cgs-server-version-compat-protocol.log
lion-ppc-process-manager-cgs-server-version-compat-protocol.log
lion-ppc-process-manager-cgs-server-version-compat-protocol.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CGS_SERVER_VERSION_COMPAT_POLICY_PROOF_PASS`

The Lion WindowServer accepted the exact legacy `0x7148` request, returned the proven `600/0` version pair, and the standalone NDR-aware normalizer changed only the version region to the Snow PPC client pair `545/0` while preserving the descriptor and all auxiliary outputs.

That closes the last prerequisite before an integrated compatibility test.

The next stage would then extend the already-existing CoreServices `mach_msg` compatibility interposer—without adding another interpose tuple—to normalize only the exact successful Lion `0x71ac` reply that matches all of the standalone proof's shape and value predicates. Snow remains passthrough. The integration would reuse the proven session-bootstrap and Security adapters and perform one registration-only Process Manager run to ask whether `__CGSNewConnectionPort 0x7469` is finally reached.

Do not build that integrated reply normalizer until this standalone result is reviewed.

### Snow control failure

Stop. The probe must first reproduce the known Snow `545/0` server-version result and right semantics.

### Lion original version differs from `600/0`

Stop and preserve the exact response. Do not broaden the policy.

### Reply shape, descriptor, NDR, or right mismatch

Stop. Do not normalize the reply.

### Adaptation changes any byte outside the version region

Stop. Treat this as a probe defect or an invalid policy.

### Crash or new diagnostic

Preserve the diagnostic and stop.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port acquisition bridge             -> PASS
Snow server-version reply                   -> 545 / 0
Lion server-version reply                   -> 600 / 0
server-version wire envelope                -> identical 0x7148 / 0x71ac
Snow version-match path                     -> continues to 0x7469
Lion mismatch path                          -> clean status-1 exit before 0x7469
failure mechanism                           -> confirmed server-version skew
next step                                   -> standalone byte-level 600/0 -> 545/0 policy proof
```

No additional XNU change is indicated.
