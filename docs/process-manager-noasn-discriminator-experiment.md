# Process Manager no-ASN discriminator experiment

## Objective

Distinguish the two remaining translated-PPC Process Manager abort candidates with one guarded, process-local behavior test:

1. the earlier LaunchServices `getProcessDispatchTable()` abort if CoreApplicationServices process-dispatch setup fails; or
2. the later HIServices `__RegisterApplication` abort when application registration still has no usable ASN/PSN.

The preceding registration-protocol audit completed successfully on Snow Leopard and Lion. It now provides enough static evidence to test the documented no-ASN control safely without patching any framework or daemon.

## Evidence established by the protocol audit

### Exact environment variable and value semantics

The Snow Leopard PPC `__RegisterApplication` code computes the first `getenv()` operand as cstring address `0x542d0`. The mapped cstring at that address is:

```text
LSDONOTABORTIFNOASN
```

The function initializes its local abort-control byte to 1. If the variable is present, it passes the string value through `atoi()` and stores that result in the abort-control byte. Later, when the cached PSN low half is still zero, the fatal no-ASN branch executes only when that byte is nonzero.

Therefore the exact process-local override for this discriminator is:

```text
LSDONOTABORTIFNOASN=0
```

The Lion i386 HIServices implementation maps its corresponding `getenv()` operand to the same uppercase literal. The mixed-case `LSDoNotAbortIfNoASN` string also exists in the framework, but it is not the operand used by this `__RegisterApplication` abort-control sequence.

### The 32-bit registration client wire form is aligned

The Snow Leopard PPC `_LSDoRegisterApplication` client sends registration message ID `0x4652` with send size `0x44` and receive size `0x48`.

Lion's i386 `_LSDoRegisterApplication` uses the same message ID and the same `0x44` send / `0x48` receive sizes.

The x86_64 variants use wider request/reply layouts, so the active daemon architecture remains an interesting implementation detail, but the current evidence does not justify a protocol adapter merely from request size: the translated PPC client's 32-bit wire form matches Lion's native i386 client wire form.

### An earlier LaunchServices abort remains possible

Snow Leopard PPC LaunchServices `getProcessDispatchTable()` still has a separate fatal path: it calls `SetupCoreApplicationServicesCommunicationPort()` if the dispatch table is missing and calls `abort()` if the table is still unavailable.

The no-ASN override does not affect that earlier LaunchServices abort.

That makes the override a useful discriminator:

- if Lion still self-aborts before `GetProcessForPID` returns, the failure is upstream of the HIServices no-ASN gate;
- if `GetProcessForPID` returns, the prior crash was at or after the no-ASN gate and the returned status/PSN becomes the next evidence.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-noasn-discriminator.c
scripts/build-ppc-process-manager-noasn-discriminator-on-snowleopard.sh
scripts/prepare-ppc-process-manager-noasn-bundle.sh
scripts/run-snowleopard-ppc-process-manager-noasn-control.sh
scripts/run-lion-ppc-process-manager-noasn-discriminator.sh
docs/process-manager-noasn-discriminator-experiment.md
```

No Apple proprietary binary is committed.

The discriminator is intentionally smaller than the earlier GetProcessForPID-first GUI probe. It:

- verifies that `LSDONOTABORTIFNOASN=0` is actually present in the PPC process;
- calls only `GetProcessForPID(getpid(), &psn)`;
- records the OSStatus and returned PSN;
- exits immediately;
- does not call `TransformProcessType`, `SetFrontProcess`, window APIs, or an event loop.

The override is supplied only through the test bundle's `LSEnvironment`. Do not use `launchctl setenv`, shell-global launchd environment changes, or a system-wide configuration change.

## Safety constraints

For this experiment:

- perform exactly one Lion PPC launch after the Snow Leopard control;
- do not call `GetCurrentProcess` or `GetProcessPID`;
- do not call foreground conversion, activation, window, or event-loop APIs after the discriminator call;
- do not patch HIServices, LaunchServices, CoreServices, CoreGraphics, or coreservicesd;
- do not restart or replace coreservicesd, WindowServer, pbs, or launchd jobs;
- do not set the no-ASN variable globally or with `launchctl`;
- do not broaden or install the private LaunchServices PPC-admission patch;
- do not modify the LaunchServices database;
- do not change the Rosetta cache, Rosetta shims, or `/usr/oah/dyld`;
- do not transplant Snow Leopard frameworks or daemons;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, or live code injection.

The only behavior change is the test app's own `LSEnvironment.LSDONOTABORTIFNOASN=0`.

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

No kernel rebuild is part of this experiment.

## Phase B — build the PPC discriminator on Snow Leopard

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-process-manager-noasn-discriminator-on-snowleopard.sh \
  ./ppc-process-manager-noasn-private-dyld
```

Expected outputs:

```text
ppc-process-manager-noasn-private-dyld
ppc-process-manager-noasn-private-dyld.info.txt
ppc-process-manager-noasn-private-dyld.sha256
```

Require a 32-bit PPC executable, `LC_LOAD_DYLINKER=/usr/oah/dyld`, and the Carbon dependency.

## Phase C — prepare the Snow Leopard app bundle

```sh
./scripts/prepare-ppc-process-manager-noasn-bundle.sh \
  ./ppc-process-manager-noasn-private-dyld \
  ./ppc-process-manager-noasn-private-dyld.sha256 \
  ./RosettaProcessManagerNoASN.app
```

The bundle preparation must verify all three target environment entries:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
LSDONOTABORTIFNOASN=0
```

Preserve `RosettaProcessManagerNoASN.app.manifest.txt`.

## Phase D — Snow Leopard positive control

Run from the logged-in Aqua user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-noasn-control.sh \
  ./RosettaProcessManagerNoASN.app \
  ./RosettaProcessManagerNoASN.app.manifest.txt \
  ./ppc-process-manager-noasn-snowleopard-control.log \
  ./ppc-process-manager-noasn-snowleopard-milestone.log
```

Require:

```text
PM_NOASN_ENV:LSDONOTABORTIFNOASN=0
PM_NOASN_STATUS:GetProcessForPID=0
PM_NOASN_MILESTONE:M06_NOERR_NONZERO_PSN
RESULT: PASS
```

If the control fails, stop. Do not run the Lion discriminator.

## Phase E — transfer exact artifacts to Lion and recreate the bundle

Transfer privately:

```text
ppc-process-manager-noasn-private-dyld
ppc-process-manager-noasn-private-dyld.info.txt
ppc-process-manager-noasn-private-dyld.sha256
ppc-process-manager-noasn-snowleopard-control.log
ppc-process-manager-noasn-snowleopard-milestone.log
snowleopard-RosettaProcessManagerNoASN.app.manifest.txt
```

On Lion, recreate the bundle using the same preparation script and compare the executable and Info.plist hashes with the Snow Leopard manifest.

Do not upload the private LaunchServices binary.

## Phase F — verify the existing Lion prerequisites

Reuse the existing validated private LaunchServices admission copy. Require its patch checker to report:

```text
RESULT: ALREADY_PATCHED
```

Verify the installed system LaunchServices hash remains:

```text
ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5
```

Reuse the validated syscall-295 kernel. Set `ROSETTA_EXPECTED_KERNEL_SHA256` from the existing XNU build artifact and rerun the existing commpage and syscall-295 native preflights. Both must pass.

## Phase G — run the single Lion discriminator

From the runtime checkout:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-noasn-discriminator.sh
```

The runner:

1. re-verifies the kernel, translator, private dyld/cache, private LaunchServices, and app identities;
2. proves the private i386 LaunchServices admission copy is loaded by the native `open` preflight;
3. verifies the bundle contains `LSDONOTABORTIFNOASN=0`;
4. launches the PPC app exactly once with `open -n`;
5. records the PPC app's own environment, call boundary, OSStatus, and PSN milestones;
6. lists any new crash/core diagnostic;
7. re-verifies protected hashes.

Do not rerun the Lion test before the result is reviewed.

## Phase H — stop and return evidence

Return:

```text
ppc-process-manager-noasn-private-dyld.info.txt
ppc-process-manager-noasn-private-dyld.sha256
ppc-process-manager-noasn-snowleopard-control.log
ppc-process-manager-noasn-snowleopard-milestone.log
snowleopard-RosettaProcessManagerNoASN.app.manifest.txt
RosettaProcessManagerNoASN.app.manifest.txt
syscall295-probe-process-manager-noasn-preflight.log
lion-ppc-process-manager-noasn-discriminator.log
lion-ppc-process-manager-noasn-load-preflight.log
lion-ppc-process-manager-noasn-open.raw.log
lion-ppc-process-manager-noasn-milestone.log
```

Also return every new crash report/core listed by the runner.

If the open raw log is empty, report that fact; an empty file does not need to be uploaded.

## Result interpretation

### `NOASN_OVERRIDE_NONZERO_PSN`

The exact no-ASN override allowed `GetProcessForPID` to return `noErr` with a nonzero PSN.

Stop there. Do not immediately test foreground conversion or a window. The next step will determine whether that PSN is actually registered/usable without relying on undefined Process Manager state.

### `NOASN_OVERRIDE_ZERO_PSN`

The abort was suppressed but `GetProcessForPID` returned `noErr` with a zero PSN.

This proves the later no-ASN gate was involved but exposes invalid/incomplete registration state. The next target is the application registration result, not more Carbon APIs.

### `NOASN_OVERRIDE_RETURNED_ERROR`

The abort was suppressed and `GetProcessForPID` returned an OSStatus.

Preserve the exact `PM_NOASN_STATUS` line. The returned status becomes the next localization target.

### `ABORT_BEFORE_GETPROCESSFORPID_RETURN`

The exact override was visible in the PPC process, but the app still self-aborted before `GetProcessForPID` returned.

That strongly favors the earlier LaunchServices process-dispatch/setup abort or another abort upstream of the HIServices no-ASN branch. The next step will focus on that channel; do not broaden the override.

### `OVERRIDE_ENVIRONMENT_FAILURE`

The PPC process did not see `LSDONOTABORTIFNOASN=0`. This is a harness failure, not a Process Manager result.

### `LAUNCHSERVICES_GATE_REGRESSION` / `PRE_MAIN_OR_LAUNCH_FAILURE`

The already validated admission path regressed. Do not infer anything about the no-ASN gate.

## Current interpretation to preserve

The protocol audit did not reveal another XNU ABI failure.

The exact abort-control environment variable is now known, and Snow Leopard PPC and Lion i386 registration clients use the same message ID and 32-bit request/reply sizes. The remaining uncertainty is whether Lion dies before reaching the no-ASN gate or dies at that gate because registration did not yield a usable ASN/PSN.

This experiment changes only that one process-local abort-control value and stops immediately after the first Process Manager call.

## Non-goals

This experiment does not:

- make a system-wide environment change;
- patch HIServices or LaunchServices;
- alter coreservicesd or launchd;
- prove a protocol adapter is needed;
- perform foreground conversion;
- create a window;
- modify Rosetta or XNU.

It is a single discriminator for the two remaining user-space abort locations.
