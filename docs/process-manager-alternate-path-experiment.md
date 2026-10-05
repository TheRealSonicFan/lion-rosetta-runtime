# PPC Process Manager alternate-path experiment

## Objective

Determine whether Lion Rosetta's Carbon failure is specific to the legacy `GetCurrentProcess` initialization path, or whether the broader Process Manager/HIServices registration state is unusable for translated PPC applications.

The preceding private LaunchServices experiment established two independent facts:

1. the Lion LaunchServices PPC policy gate can be cleared with the private, process-local compatibility copy; the PPC application is then actually launched by LaunchServices;
2. after launch, the application still reaches `main()`, writes its `BEFORE_GetCurrentProcess` marker, and deliberately self-SIGABRTs inside `GetCurrentProcess`.

The new crash report repeats the already decoded Rosetta host pattern: PID in the first `kill` argument, signal 6 (SIGABRT), posix flag 1, successful host syscall return. Therefore the private LaunchServices patch did its job; the remaining boundary is guest Process Manager/HIServices behavior.

This experiment avoids `GetCurrentProcess` entirely. It tests two other documented Process Manager routes for obtaining/validating a `ProcessSerialNumber`:

- the pseudo-PSN `{ 0, kCurrentProcess }` with `GetProcessPID`;
- `GetProcessForPID(getpid(), &psn)`, followed by `GetProcessPID` round-trip validation.

If a usable PSN is obtained, the probe continues through `TransformProcessType`, `SetFrontProcess`, window creation, and a two-second Carbon event loop.

The experiment therefore answers whether a narrow `GetCurrentProcess` compatibility shim is plausible, or whether the Process Manager backend itself still lacks translated-PPC state.

## Repository files

The runtime repository provides:

```text
tests/ppc-process-manager-alternate.c
scripts/build-ppc-process-manager-alternate-on-snowleopard.sh
scripts/prepare-ppc-process-manager-alternate-bundle.sh
scripts/run-snowleopard-ppc-process-manager-alternate-control.sh
scripts/run-lion-ppc-process-manager-alternate-experiment.sh
docs/process-manager-alternate-path-experiment.md
```

No Apple proprietary binary is committed.

## Safety constraints

For this experiment:

- do not call `GetCurrentProcess` from the new probe;
- do not modify the installed LaunchServices framework;
- do not rebuild or edit the LaunchServices database;
- do not install Snow Leopard receipts;
- do not modify HIServices/ApplicationServices binaries or Rosetta shims;
- do not modify XNU;
- do not change `/usr/oah/dyld` or rebuild the Rosetta cache;
- keep the existing private LaunchServices compatibility copy unchanged;
- do not use live GDB, DTrace, or dtruss;
- do not test another real-world PPC application;
- stop after the single guarded Lion run.

## Milestone log

The probe writes unbuffered evidence to:

```text
/tmp/rosetta-processmanager-alternate-milestone.log
```

Important milestones are:

```text
M00_MAIN_ENTER
M01_BEFORE_GetProcessPID_PSEUDO
M02_AFTER_GetProcessPID_PSEUDO
M03_BEFORE_GetProcessForPID
M04_AFTER_GetProcessForPID
M05_BEFORE_GetProcessPID_ACTIVE
M06_AFTER_GetProcessPID_ACTIVE
M07_BEFORE_TransformProcessType
M08_AFTER_TransformProcessType
M09_BEFORE_SetFrontProcess
M10_AFTER_SetFrontProcess
M11_BEFORE_CreateNewWindow
M12_AFTER_CreateNewWindow
M13_BEFORE_ShowWindow
M14_AFTER_ShowWindow
M15_BEFORE_InstallEventLoopTimer
M16_AFTER_InstallEventLoopTimer
M17_BEFORE_RunApplicationEventLoop
M21_TIMER_CALLBACK_ENTER
M22_TIMER_CALLBACK_EXIT
M18_AFTER_RunApplicationEventLoop
M19_SUCCESS
```

The log also records Process Manager return codes, pseudo/resolved PSNs, and PID round-trip results.

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

## Phase B — build the alternate Process Manager probe on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-process-manager-alternate-on-snowleopard.sh \
  ./ppc-process-manager-alternate-private-dyld
```

Expected outputs:

```text
ppc-process-manager-alternate-private-dyld
ppc-process-manager-alternate-private-dyld.info.txt
ppc-process-manager-alternate-private-dyld.sha256
```

The info file must show:

- non-fat 32-bit PowerPC;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- Carbon framework dependency.

Do not rebuild or modify the executable after its checksum sidecar is generated.

## Phase C — prepare the Snow Leopard application bundle

Create a dedicated bundle:

```sh
./scripts/prepare-ppc-process-manager-alternate-bundle.sh \
  ./ppc-process-manager-alternate-private-dyld \
  ./ppc-process-manager-alternate-private-dyld.sha256 \
  ./RosettaProcessManagerAlternate.app
```

Expected:

```text
RosettaProcessManagerAlternate.app
RosettaProcessManagerAlternate.app.manifest.txt
```

The manifest must retain the executable SHA-256 and the two validated `LSEnvironment` entries.

## Phase D — Snow Leopard positive control

Run from the logged-in Aqua console user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-alternate-control.sh \
  ./RosettaProcessManagerAlternate.app \
  ./RosettaProcessManagerAlternate.app.manifest.txt \
  ./ppc-process-manager-alternate-snowleopard-control.log \
  ./ppc-process-manager-alternate-snowleopard-milestone.log
```

Require:

```text
PM_ALT_MILESTONE:M19_SUCCESS
RESULT: PASS
```

The window titled **Rosetta PPC Process Manager Alternate** should appear for approximately two seconds.

The milestone log should also show successful PID/PSN evidence. Preserve it exactly.

If the Snow Leopard control fails, stop and do not transfer the test to Lion.

## Phase E — transfer exact artifacts to Lion and recreate the bundle

Transfer privately to the Lion runtime checkout:

```text
payload/ppc-process-manager-alternate-private-dyld
payload/ppc-process-manager-alternate-private-dyld.info.txt
payload/ppc-process-manager-alternate-private-dyld.sha256
payload/ppc-process-manager-alternate-snowleopard-control.log
payload/ppc-process-manager-alternate-snowleopard-milestone.log
payload/snowleopard-RosettaProcessManagerAlternate.app.manifest.txt
```

On Lion, recreate the bundle definition around the exact executable:

```sh
cd /path/to/lion-rosetta-runtime

./scripts/prepare-ppc-process-manager-alternate-bundle.sh \
  ./payload/ppc-process-manager-alternate-private-dyld \
  ./payload/ppc-process-manager-alternate-private-dyld.sha256 \
  ./payload/RosettaProcessManagerAlternate.app
```

Compare the executable and Info.plist hashes between the Snow Leopard and Lion manifests. They must match exactly.

## Phase F — verify the existing private LaunchServices compatibility copy

Do not recreate or broaden the private LaunchServices patch.

Verify the existing payload:

```sh
cat ./payload/private-launchservices-ppc-compat/manifest.txt

/usr/bin/python ./scripts/patch-lion-launchservices-ppc-compat.py \
  --check \
  ./payload/private-launchservices-ppc-compat/LaunchServices.framework/Versions/A/LaunchServices
```

Require:

```text
RESULT: ALREADY_PATCHED
```

Also verify the installed system LaunchServices SHA-256 remains:

```text
ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5
```

## Phase G — repeat the validated native safety gates

Use the same syscall-295 kernel:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

Expected kernel SHA-256:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Run the existing commpage probe and require PASS.

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-process-manager-alternate-preflight.log"
```

Require both existing syscall-295 PASS lines.

## Phase H — run the guarded Lion Process Manager alternate-path test

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-alternate-experiment.sh
```

The runner:

1. verifies all validated kernel, Rosetta, dyld/cache, app, and private-LaunchServices identities;
2. proves again that i386 `open` loads the private patched LaunchServices;
3. launches the new PPC app exactly once through that process-private LaunchServices path;
4. copies the milestone log;
5. records the furthest Process Manager milestone;
6. captures every new crash/core diagnostic;
7. rechecks all protected hashes.

Expected logs:

```text
payload/lion-ppc-process-manager-alternate-experiment.log
payload/lion-ppc-process-manager-alternate-load-preflight.log
payload/lion-ppc-process-manager-alternate-open.raw.log
payload/lion-ppc-process-manager-alternate-milestone.log   # if main() is reached
```

## Phase I — stop and preserve evidence

Stop after the single Lion run.

Return:

```text
ppc-process-manager-alternate-private-dyld.info.txt
ppc-process-manager-alternate-private-dyld.sha256
ppc-process-manager-alternate-snowleopard-control.log
ppc-process-manager-alternate-snowleopard-milestone.log
snowleopard-RosettaProcessManagerAlternate.app.manifest.txt
RosettaProcessManagerAlternate.app.manifest.txt
syscall295-probe-process-manager-alternate-preflight.log
lion-ppc-process-manager-alternate-experiment.log
lion-ppc-process-manager-alternate-load-preflight.log
lion-ppc-process-manager-alternate-open.raw.log
lion-ppc-process-manager-alternate-milestone.log   # if created
```

Also return every new crash report/core listed by the runner.

Do not upload the private LaunchServices framework binary.

## Result interpretation

### PASS

If `M19_SUCCESS` is reached, the alternate Process Manager route produces a usable PSN and completes Carbon GUI execution.

That would strongly support a narrow compatibility implementation for `GetCurrentProcess`, potentially using the working PID-to-PSN path, rather than a broader Process Manager transplant.

### GETPROCESSPID_PSEUDO_BOUNDARY

The pseudo-PSN route itself aborts before returning. Preserve the crash/core; do not infer that `GetProcessForPID` is also broken because it was never reached.

### GETPROCESSFORPID_BOUNDARY

The pseudo-PSN call returned, but `GetProcessForPID(getpid())` aborts. This points to a broader Process Manager registration/backend problem rather than only `GetCurrentProcess`.

### GETPROCESSPID_ACTIVE_BOUNDARY

A PSN was returned by `GetProcessForPID`, but translating that PSN back to the PID aborts.

### TRANSFORMPROCESSTYPE_BOUNDARY / SETFRONTPROCESS_BOUNDARY

PSN acquisition works, but the first foreground-application conversion or activation operation is the next Process Manager boundary.

### CREATENEWWINDOW_BOUNDARY or later

Process Manager identity/foreground operations work; the next Carbon GUI subsystem becomes the new boundary.

### LOCALIZED_OR_RETURNED_FAILURE

The function returned an error instead of aborting, or the result falls between explicit milestone classes. Preserve the complete milestone log because its `PM_ALT_STATUS` and `PM_ALT_PSN` records become authoritative.

## Why this is the next step

The private LaunchServices experiment has already proven that the PPC app can be accepted, spawned by LaunchServices, identified by its bundle identifier, and presented to the user as a GUI process. Repeating LaunchServices work would not address the remaining crash.

The next unresolved question is whether translated PPC can obtain a Process Manager identity by any route other than `GetCurrentProcess`.

## Non-goals

This experiment does not:

- patch `GetCurrentProcess`;
- modify HIServices/ApplicationServices;
- install a new Rosetta shim;
- modify system LaunchServices;
- change XNU;
- define the production GUI-launch design.

It is a functional localization experiment for the Process Manager boundary.


## Observed Lion result: pseudo-PSN GetProcessPID aborts before return

The experiment completed its Snow Leopard positive control successfully. The exact PPC control reached every milestone through `M19_SUCCESS`: pseudo-PSN `GetProcessPID`, `GetProcessForPID`, PID round-trip validation, foreground transformation, window creation, and the event loop all succeeded.

On Lion, the validated private LaunchServices compatibility path again admitted and spawned the PPC application, but the subject reached only:

```text
PM_ALT_MILESTONE:M00_MAIN_ENTER
PM_ALT_PID:SELF=5106
PM_ALT_PSN:PSEUDO=0x00000000:0x00000002
PM_ALT_MILESTONE:M01_BEFORE_GetProcessPID_PSEUDO
```

No `M02_AFTER_GetProcessPID_PSEUDO` marker was written. The corresponding crash report is `EXC_CRASH (SIGABRT)`.

The crashed Rosetta host state again matches the previously decoded guest self-abort wrapper:

- EIP `0xb815ac07`;
- EAX `0`, indicating the host `kill` call returned successfully;
- EDI `0x13f2` = PID 5106;
- ESI `6` = SIGABRT;
- EDX `1` = the posix flag.

Therefore the pseudo-PSN `GetProcessPID({0,kCurrentProcess},...)` route reaches the same deliberate guest abort family as `GetCurrentProcess`.

This result does **not** establish that `GetProcessForPID` is broken: the subject never reached that call. The next controlled experiment starts with `GetProcessForPID(getpid(), &psn)`, omits both `GetCurrentProcess` and `GetProcessPID`, and uses any returned PSN directly for the later Carbon operations.

Follow `docs/process-manager-getprocessforpid-first-experiment.md`.

Do not modify HIServices, Rosetta, system LaunchServices, or XNU.
