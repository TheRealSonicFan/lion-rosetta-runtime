# Process Manager CGS server-version compatibility integration experiment

## Objective

Integrate the now-proven narrow server-version normalization into the registration-only Process Manager path and determine whether restored Snow Leopard PPC CoreGraphics can proceed from the Lion session port through `__CGSNewConnectionPort` and publish a nonzero default connection.

The completed standalone policy proof established all prerequisites:

```text
Snow server-version request/reply             0x7148 -> 0x71ac
Snow decoded version                          545 / 0
Lion server-version request/reply             0x7148 -> 0x71ac
Lion decoded version                          600 / 0
Lion reply descriptor                         valid send right, disposition/type 0x11 / 0x00
Lion NDR representation                       swapped relative to PPC
copied-buffer normalization                   600 / 0 -> 545 / 0
changed bytes                                 1
bytes changed outside offsets 0x30..0x37      0
descriptor / auxiliary outputs                preserved
standalone result                             CGS_SERVER_VERSION_COMPAT_POLICY_PROOF_PASS
```

The prior integrated passive trace also established that the unmodified Lion `600/0` reply is followed by a clean status-1 exit before request `0x7469`. Snow PPC static control flow explains that exact stop: `_connectAndCheck` rejects the server-version mismatch with `0x3f0`, and `_CGSServerPort` converts that status to `exit(1)`.

This stage changes only that confirmed compatibility value and keeps the existing session-port, CoreServices, Security, and registration-only controls unchanged.

## Compatibility implementation under test

Current runtime `main` extends the existing CoreServices `mach_msg` interposer instead of adding another Mach interposer.

Build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-v1
```

The dylib still contains exactly two PPC interpose tuples:

```text
bootstrap_look_up2
mach_msg
```

The new compile-time integration variant retains the passive CGS trace for:

```text
SERVER_VERSION   0x7148 -> 0x71ac
DEATHWATCH       0x714c -> 0x71b0
NEW_CONNECTION   0x7469 -> 0x74cd
```

and adds one separate runtime mode:

```text
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE
```

### Snow mode

```text
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=passthrough
```

The `0x7148/0x71ac` transaction is observed but never modified. The control must decode `545/0`, proceed through `0x7469/0x74cd`, complete `GetProcessForPID`, and publish a nonzero connection.

### Lion mode

```text
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
```

The interposer calls the original `mach_msg` first and considers normalization only if every predicate below matches:

```text
request ID                           0x7148
request bits                         0x1513
send / receive                       0x24 / 0x48
mach_msg option                      0x3
remote / reply / receive ports       nonzero
timeout / notify                     zero
Mach result                          KERN_SUCCESS
reply                                complex
reply ID                             0x71ac
reply size                           0x40
descriptor count                     1
descriptor port                      nonzero
descriptor disposition / type        0x11 / 0x00
reply NDR                            swapped relative to PPC
decoded original major / minor       600 / 0
decoded auxiliary                    0x69333836
decoded flags                        0x00000001
exact compatible call count          1
```

Only then are the reply words at offsets `0x30` and `0x34` encoded as `545/0` using the reply's own NDR byte order. The adapter post-check requires:

```text
adapted decoded major / minor        545 / 0
changed bytes                        nonzero
changed bytes outside 0x30..0x37     zero
descriptor count / port              unchanged
descriptor disposition / type        unchanged
auxiliary / flags                    unchanged
```

If any post-check fails, the original `0x40` reply is restored before returning to CoreGraphics.

All nonmatching requests and replies remain unchanged.

## Why integration is now justified

The standalone proof did not return an adapted buffer to CoreGraphics. It demonstrated that the exact Lion reply can be normalized to the Snow client version with one byte changed and no collateral output changes.

The next unanswered question is therefore behavioral rather than structural: once restored Snow PPC `_connectAndCheck` sees its expected `545/0`, does it proceed to the already-known `__CGSNewConnectionPort 0x7469` transaction and publish the default CoreGraphics connection?

The existing registration-only subject is sufficient to answer that question and stops before the later foreground/CPS path.

## Safety constraints

For this stage:

- build only the new CoreServices compatibility variant on Snow Leopard 10.6.8;
- reuse the accepted registration-only subject, Security v1 interposer, and CGS session-bootstrap v1 interposer unchanged;
- require the Snow passthrough control before Lion;
- transfer the exact hashed new CoreServices dylib to Lion;
- repeat the established native commpage and syscall-295 safety gates;
- run the Lion registration integration exactly once before review;
- keep `LSDONOTABORTIFNOASN` unset;
- do not call `GetProcessPID`, `TransformProcessType`, `SetFrontProcess`, `CPSSetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`;
- do not create a window or enter an event loop;
- do not normalize any server-version reply except the exact predicate set above;
- do not alter request `0x7148`;
- do not adapt `0x7469` or `0x729e`;
- do not fabricate Mach rights or a connection record;
- do not change CoreGraphics defaults or enable a broad unmatched-version preference;
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

## Phase B — build the integrated CoreServices compatibility variant on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat-on-snowleopard.sh
```

Expected files:

```text
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib.sha256
```

Require:

- build ID `dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-v1`;
- 32-bit PPC dylib;
- exactly two PPC interpose tuples, section size `0x10`;
- imports `bootstrap_look_up2`, `mach_msg`, and `mig_get_reply_port`;
- passive trace markers for SERVER_VERSION and NEW_CONNECTION;
- server-version compatibility call, adapter, passthrough, and ADAPTER_PASS markers.

If Phase B fails, stop and return the complete build output.

## Phase C — Snow Leopard passthrough integration control

Keep these already accepted artifacts in the same directory:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

with their SHA sidecars.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cgs-server-version-compat-integration-control.sh
```

Require final:

```text
PM_CGS_SERVER_VERSION_COMPAT_CALL:index=1 mode=passthrough ... major=545 minor=0
PM_CGS_SERVER_VERSION_COMPAT_RESULT:PASSTHROUGH major=545 minor=0
NEW_CONNECTION 0x7469 -> 0x74cd              Mach success / ID match
PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS
PM_CPS_CONNECTION_STATE:phase=postidentity ... nonzero=YES
PM_CGS_SESSION_BOOTSTRAP_INTEGRATION_MILESTONE:M07_SUCCESS
RESULT: PASS
```

The Snow log must not contain `PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS`.

Phase C is a hard gate. If it fails, do not run Lion.

## Phase D — transfer exact artifacts to Lion

Transfer the new CoreServices compatibility artifact and sidecars plus the Snow control log:

```text
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib.sha256
ppc-process-manager-cgs-server-version-compat-integration-snowleopard-control.log
```

Reuse without rebuilding the accepted:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

and their SHA sidecars.

## Phase E — repeat Lion native safety gates

Use the validated syscall-295 kernel identity:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require its existing PASS.

Then run the established syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-cgs-server-version-compat-integration.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion registration integration run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cgs-server-version-compat-integration.sh
```

The runner enables exactly:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
```

The leading desired evidence is:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_RESULT:ADAPTER_PASS
SERVER_VERSION original reply                600 / 0
PM_CGS_SERVER_VERSION_COMPAT_RESULT:ADAPTER_PASS
NEW_CONNECTION request                      0x7469
NEW_CONNECTION reply                        0x74cd
PM_POSTIDENTITY_RESULT:GETPROCESSFORPID_PASS
postidentity connection                     nonzero
RESULT: CGS_SERVER_VERSION_COMPAT_CONNECTION_ESTABLISHED
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cgs-server-version-compat.dylib.sha256
ppc-process-manager-cgs-server-version-compat-integration-snowleopard-control.log
syscall295-probe-process-manager-cgs-server-version-compat-integration.log
lion-ppc-process-manager-cgs-server-version-compat-integration.log
lion-ppc-process-manager-cgs-server-version-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CGS_SERVER_VERSION_COMPAT_CONNECTION_ESTABLISHED`

The combined session-port bridge plus exact server-version normalization is sufficient for restored Snow PPC CoreGraphics to complete its default connection on Lion. The next stage should stop again before automatically adapting the known later `0x729e` SetFrontProcess mismatch; first review the exact `0x7469/0x74cd` Lion reply and connection state from this successful run for consistency with Snow.

### `CGS_SERVER_VERSION_COMPAT_ADAPTER_PASS_NO_NEWCONNECTION_CLEAN_RC1`

The exact version normalization was accepted by the interposer but Snow PPC still exited before `0x7469`. Stop and audit the immediate local post-version branch. Do not broaden normalization.

### `CGS_SERVER_VERSION_COMPAT_NEWCONNECTION_MACH_FAILURE`

The version gate is cleared and the exact active boundary moves to the `0x7469` transport. Preserve the numeric Mach result and compare the request against Snow.

### `CGS_SERVER_VERSION_COMPAT_NEWCONNECTION_REPLY_ID_MISMATCH`

Lion accepted the request transport but returned an unexpected reply ID. Audit the exact response protocol before adaptation.

### `CGS_SERVER_VERSION_COMPAT_NEWCONNECTION_REPLY_OBSERVED_CLEAN_EARLY_EXIT_RC1`

Lion returned the expected `0x74cd`, but the restored client still stopped. Compare the complete Snow/Lion raw reply words and immediate connection-record initialization before changing the NewConnection transaction.

### `CGS_SERVER_VERSION_COMPAT_GETPROCESSFORPID_RETURNED_CONNECTION_NOT_ESTABLISHED`

Registration returned but did not publish the expected default connection. Compare the NewConnection reply and connection-record state; do not proceed to CPS.

### Any predicate rejection

If the original Lion reply is no longer exactly the standalone-proven `600/0`, descriptor, NDR, auxiliary, and flags shape, no normalization occurs. Preserve the log and stop.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version wire envelope                -> identical
Snow server version                         -> 545 / 0
Lion server version                         -> 600 / 0
standalone copied-buffer normalizer          -> PASS
unmodified Lion registration                -> exits 1 before 0x7469
next step                                   -> one exact live reply normalization integration
later known CPS mismatch                    -> 0x729e vs 0x72a1, still out of scope
```

No additional XNU change is indicated.
