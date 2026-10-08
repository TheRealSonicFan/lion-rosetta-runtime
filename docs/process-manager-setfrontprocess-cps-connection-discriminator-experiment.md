# Process Manager CPS connection-state discriminator experiment

## Objective

Dynamically distinguish the now-static-localized `SetFrontProcess=-50` failure between:

1. the Snow Leopard PPC CoreGraphics **pre-transport no-connection guard**, and
2. the later Snow-PPC-to-Lion CGS `SetFrontProcess` wire mismatch already visible in the focused audit.

This experiment does not call public `SetFrontProcess`. It reads one binary-audited CoreGraphics connection-record slot without invoking a connection getter, then calls exactly one private `CPSSetFrontProcess(&psn)` and stops immediately after recording its raw CPS status.

## What the focused static audit proved

Both focused reports completed with `RESULT: PASS`.

### The immediate pre-transport guard is identical in Snow PPC and Lion native CoreGraphics

Snow Leopard PPC `__CPSSetFrontProcessWithOptions` has audited original-image offset:

```text
0x001fcfdc
```

Its first state test loads a CoreGraphics connection-record pointer from audited original-image offset:

```text
0x007007c8
```

and returns raw CPS status:

```text
0x000003eb  (1003)
```

if that pointer is zero, before calling `__CGSSetFrontProcess`.

The slot offset is derived directly from the PPC sequence in the original Snow Leopard PPC image:

```text
bcl ...                    -> LR/PC 0x001fcfe4
addis r2,r31,0x50          -> +0x00500000
lwz   r2,0x37e4(r2)        -> original-image offset 0x007007c8
cmpwi r2,0
beq   return_0x3eb
```

Lion i386 CoreGraphics has the same decisive guard: its native `__CPSSetFrontProcessWithOptions` returns `0x3eb` when its current connection record is absent.

Snow PPC HIServices then maps this positive CPS status into the public Process Manager `-50` result. In particular, the PPC `SetFrontProcessWithOptions` return mapping sends positive status `0x3eb` down the `> 0x3ea` branch that returns `paramErr (-50)`.

That control flow exactly matches the already-observed Lion registration diagnostic that `_CGSDefaultConnection()` was NULL, but a live raw-CPS/state correlation is still required before treating it as causal.

### A later CGS protocol mismatch is also statically real

If the no-connection guard is cleared, the restored Snow PPC CoreGraphics client and Lion native CoreGraphics do **not** use the same `__CGSSetFrontProcess` request ID.

Snow Leopard PPC:

```text
request ID     0x729e
expected reply 0x7302
send size      0x30
receive size   0x2c
Mach options   0x3
```

Lion i386:

```text
request ID     0x72a1
expected reply 0x7305
send size      0x30
receive size   0x2c
Mach options   0x3
```

Thus a CGS wire adapter may eventually be required, but it must **not** be implemented before proving whether the current Lion run ever gets past the connection guard.

## Prepared subject

Current runtime `main` provides:

```text
tests/ppc-process-manager-cps-connection-discriminator.c
scripts/build-ppc-process-manager-cps-connection-discriminator-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-cps-connection-discriminator-control.sh
scripts/run-lion-ppc-process-manager-cps-connection-discriminator.sh
```

The subject reuses the accepted v5 CoreServices and v1 Security compatibility stack and re-proves:

```text
LaunchServices dispatch table/server port
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
exact PID round-trip
TransformProcessType(...foreground...)
```

It then:

1. resolves the loaded PPC CoreGraphics image;
2. resolves the loaded Snow PPC `_CPSSetFrontProcessWithOptions` and `CPSSetFrontProcess` symbols dynamically and validates their audited same-`__TEXT` runtime delta (`0xf0`);
3. validates the `__CPSSetFrontProcessWithOptions` PPC prologue word `0x7c0802a6`;
4. decodes the loaded PPC PIC `addis`/`lwz` pair inside `_CPSSetFrontProcessWithOptions` to reconstruct the actual shared-cache runtime address of the connection-record slot, without invoking a connection getter;
5. logs that slot before identity, after identity, after foreground conversion, and after the private CPS call;
6. calls exactly one `CPSSetFrontProcess(&psn)`;
7. records the **raw CPS status**, before HIServices maps it to an OSStatus;
8. exits immediately.

The subject does **not** import or call public `SetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess`.

The static Snow CoreGraphics values remain provenance only. The live discriminator deliberately derives the cross-segment connection-slot address from the loaded PPC instructions because the Rosetta shared cache can relocate `__TEXT` and `__DATA` independently.

## Safety constraints

For this experiment:

- run only from the logged-in Aqua console user's Terminal;
- keep `LSDONOTABORTIFNOASN` unset;
- do not call public `SetFrontProcess`;
- do not call `GetFrontProcess`;
- do not create a window or run an event loop;
- do not invoke `_CGSDefaultConnection` merely to inspect it, because that getter can attempt initialization and would contaminate the discriminator;
- do not restart or signal WindowServer, coreservicesd, pbs, loginwindow, Dock, or launchd jobs;
- do not add a CPS/CGS/WindowServer interposer;
- do not adapt request `0x729e` yet;
- do not broaden the v5 CoreServices adapter;
- do not modify XNU.

The connection slot is read only. No framework or shared-cache memory is written.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout:

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
  /bin/bash ./scripts/build-ppc-process-manager-cps-connection-discriminator-on-snowleopard.sh
```

Require exactly these three new artifacts:

```text
ppc-process-manager-cps-connection-discriminator-private-dyld
ppc-process-manager-cps-connection-discriminator-private-dyld.info.txt
ppc-process-manager-cps-connection-discriminator-private-dyld.sha256
```

The builder requires:

- 32-bit PPC output;
- private `/usr/oah/dyld`;
- direct Carbon linkage;
- exact `GetProcessForPID`, `GetProcessPID`, `TransformProcessType`, and `dlsym` imports;
- **no** public `SetFrontProcess`, `GetFrontProcess`, or `GetCurrentProcess` import;
- the audited CoreGraphics static values:
  - `_CPSSetFrontProcessWithOptions` symbol value `0x001fcfdc`;
  - `CPSSetFrontProcess` symbol value `0x001fd0cc` and same-`__TEXT` delta `0xf0`;
  - standalone-image connection target `0x007007c8` as provenance;
  - loaded PPC PIC instruction pattern used to derive the actual runtime slot;
  - raw no-connection status `0x000003eb`.

Do not manually create sidecars if the builder fails.


### Phase B harness correction

An initial Phase B attempt can fail after the PPC executable has compiled, linked, and had its `LC_LOAD_DYLINKER` patched with:

```text
error: required discriminator marker missing: PM_CPS_CONNECTION_STATE:phase=posttransform
```

That message identifies a **builder validation defect**, not a missing runtime code path. The subject emits connection-state lines through one format string:

```text
PM_CPS_CONNECTION_STATE:phase=%s slot=...
```

and supplies `preidentity`, `postidentity`, `posttransform`, and `postcps` as separate string arguments. Therefore the fully rendered text `PM_CPS_CONNECTION_STATE:phase=posttransform` does not exist as one literal string in the Mach-O and cannot correctly be required by `strings`.

Current `main` fixes the build gate to require the emitted format template plus all four phase literals separately. No subject behavior, CoreGraphics offset, private CPS call, or experiment interpretation changed.

If the old failure was observed:

1. pull current runtime `main`;
2. rerun **Phase B only**;
3. require the builder to create all three artifacts normally;
4. continue to Phase C only after Phase B succeeds.

The builder's failure-cleanup trap removes partial executable/info/SHA outputs, so do not reuse or manually reconstruct artifacts from the failed attempt.


### Phase C address-model correction

The first Snow Leopard Phase C run with executable SHA-256
`367235a029bfc887d76c8826ad3ea79c76bedac56ab01ec2b0d2a0ad0244dabc`
failed before the identity/CPS discriminator itself ran:

```text
PM_POSTIDENTITY_SERVER_PORT:port=0x00002003 nonzero=YES
PM_CPS_DISCRIMINATOR_RESULT:AUDITED_OFFSET_OUTSIDE_IMAGE
control_status=38
RESULT: FAIL
```

This is a second harness/address-resolution defect, not a Snow Leopard Process Manager or CPS failure. The executable provenance was otherwise correct: PPC7400, private `/usr/oah/dyld`, the intended Process Manager imports only, and the audited CoreGraphics static values.

The defect was treating the standalone Snow PPC CoreGraphics `nm` values
`0x001fcfdc`, `0x001fd0cc`, and the statically computed connection target
`0x007007c8` as if they were all runtime offsets from the loaded shared-cache image header. That model is valid for the already-audited LaunchServices local `__TEXT` offsets but is not valid for this CoreGraphics cross-segment data reference in the optimized Rosetta shared cache.

The corrected discriminator now uses the loaded code itself as the authority:

1. resolve `_CPSSetFrontProcessWithOptions` and `CPSSetFrontProcess` with `dlsym`;
2. require their runtime separation to equal the audited same-`__TEXT` delta `0xf0`;
3. validate the PPC prologue;
4. decode the loaded `addis r2,r31,imm16` instruction at function offset `0x1c` and loaded `lwz r2,disp16(r2)` at offset `0x28`;
5. reconstruct the actual runtime connection-slot address from the loaded PIC sequence using the `bcl` LR base at function offset `0x08`;
6. require both the resolved CPS function and decoded slot to fall inside loaded CoreGraphics segments before reading the slot.

This preserves the original static audit as provenance while correctly allowing dyld shared-cache split-segment rebasing to alter the runtime `__TEXT -> __DATA` displacement.

Because the subject source changed, the old executable and sidecars are stale. Pull current runtime `main`, repeat **Phase B**, and then repeat **Phase C only**. Do not proceed to Lion until the rebuilt Snow control reaches the actual identity/foreground/CPS milestones and ends in `RESULT: PASS`.

## Phase C — Snow Leopard control

Use the already accepted v5 CoreServices and v1 Security interposers:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-cps-connection-discriminator-control.sh
```

This is a hard gate.

Require final:

```text
RESULT: PASS
```

and, in the log, require:

```text
PM_CPS_PROLOGUE:expected=0x7c0802a6 actual=0x7c0802a6
PM_CPS_CONNECTION_STATE:phase=posttransform ... nonzero=YES
PM_CPS_DISCRIMINATOR_MILESTONE:M11_BEFORE_CPSSetFrontProcess
PM_CPS_DISCRIMINATOR_MILESTONE:M12_AFTER_CPSSetFrontProcess
PM_CPS_DISCRIMINATOR_STATUS:CPSSetFrontProcess=0 hex=0x00000000
PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_ZERO
PM_CPS_DISCRIMINATOR_MILESTONE:M13_SUCCESS
```

The control also re-requires exactly one passthrough SessionInit transaction and all previously accepted identity/foreground-conversion milestones.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer exact accepted artifacts

Transfer:

```text
ppc-process-manager-cps-connection-discriminator-private-dyld
ppc-process-manager-cps-connection-discriminator-private-dyld.info.txt
ppc-process-manager-cps-connection-discriminator-private-dyld.sha256

ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256

ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256

ppc-process-manager-cps-connection-discriminator-snowleopard-control.log
```

Place the executable, dylibs, and SHA sidecars under runtime `payload/`, or pass explicit paths.

Do not rebuild on Lion.

## Phase E — repeat Lion native safety gates

Use the already validated syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Run the established native commpage probe and require PASS.

Then run the syscall-295 probe and preserve it as:

```text
syscall295-probe-process-manager-cps-connection-discriminator.log
```

Require EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion CPS discriminator run

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-cps-connection-discriminator.sh
```

The runner enables only:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
```

and keeps `LSDONOTABORTIFNOASN` unset.

Before accepting the discriminator result it re-requires the established provenance, adapter, SessionInit, identity, round-trip, and `TransformProcessType` gates.

### Expected discriminator result

The leading result is:

```text
PM_CPS_CONNECTION_STATE:phase=posttransform ... pointer=0x00000000 nonzero=NO
PM_CPS_DISCRIMINATOR_MILESTONE:M11_BEFORE_CPSSetFrontProcess
PM_CPS_DISCRIMINATOR_MILESTONE:M12_AFTER_CPSSetFrontProcess
PM_CPS_DISCRIMINATOR_STATUS:CPSSetFrontProcess=1003 hex=0x000003eb
PM_CPS_DISCRIMINATOR_RESULT:CPS_RAW_0X000003EB
PM_CPS_CONNECTION_STATE:phase=postcps ... pointer=0x00000000 nonzero=NO
RESULT: CPS_CONNECTION_NULL_PRETRANSPORT_CONFIRMED
```

The subject itself exits `32` for raw status `0x3eb`; the Lion runner converts the exact zero-slot + raw-`0x3eb` combination into a successful experiment result.

If that exact result is obtained, the current `SetFrontProcess=-50` boundary is proven to stop **before** the legacy PPC `__CGSSetFrontProcess` Mach request is reached.

### Other outcomes

If raw `CPSSetFrontProcess` returns zero, stop with:

```text
RESULT: CPS_RAW_ZERO_UNEXPECTED
```

That would mean the private CPS boundary succeeds despite the previous public `SetFrontProcess=-50`, so the public-wrapper state must be re-audited before any further action.

If raw `0x3eb` is returned while the audited connection slot is nonzero, stop with:

```text
RESULT: CPS_RAW_0X000003EB_WITHOUT_NULL_SLOT_PROOF
```

If another raw status is returned, stop with:

```text
RESULT: CPS_RAW_OTHER_STATUS
```

Preserve the exact raw status.

If the CPS call does not return, preserve any new crash/core diagnostic and stop.

Run Phase F only once before review.

## Phase G — return evidence

Return:

```text
lion-ppc-process-manager-cps-connection-discriminator.log
lion-ppc-process-manager-cps-connection-discriminator.raw.log
syscall295-probe-process-manager-cps-connection-discriminator.log
ppc-process-manager-cps-connection-discriminator-snowleopard-control.log
ppc-process-manager-cps-connection-discriminator-private-dyld.info.txt
ppc-process-manager-cps-connection-discriminator-private-dyld.sha256
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-compat-interposer.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib.info.txt
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
```

Also return every new crash/core diagnostic named by the Lion runner.

## Decision gate after Phase F

### `CPS_CONNECTION_NULL_PRETRANSPORT_CONFIRMED`

Do **not** adapt CGS request `0x729e` yet.

The next investigation must move one step earlier into the failed CoreGraphics/WindowServer connection-registration path that leaves the audited connection record null. The existing registration-time diagnostics then become causal evidence rather than mere correlation.

A later stage may still need to adapt Snow PPC `0x729e` to Lion `0x72a1`, because the focused audit has already proven that protocol difference. But that wire path is latent until a valid CPS connection exists.

### nonzero connection slot with a transport-derived error

Then the pre-transport hypothesis is closed and the already-proven `0x729e -> 0x72a1` protocol difference becomes the leading next boundary.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security compatibility        -> PASS
SessionUniverse InitConnection v5            -> PASS
GetProcessForPID                             -> PASS
GetProcessPID                                -> PASS
TransformProcessType                         -> PASS
public SetFrontProcess
  Snow Leopard                               -> 0
  Lion                                       -> -50
HIServices                                   -> delegates to CPS
Snow PPC CPS no-connection guard             -> raw 0x3eb -> public -50
Snow PPC CGS request                         -> 0x729e
Lion native CGS request                      -> 0x72a1
next live discriminator                      -> connection slot + raw CPS status
```

No additional XNU change is indicated.
