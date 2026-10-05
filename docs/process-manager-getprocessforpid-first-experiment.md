# GetProcessForPID-first Process Manager experiment

## Objective

Determine whether the Lion Rosetta Process Manager failure is specific to the legacy current-process lookup paths, or whether translated PPC cannot use the broader HIServices Process Manager registration backend.

The previous alternate-path experiment made the pseudo-PSN call:

```text
GetProcessPID({0, kCurrentProcess}, &pid)
```

as its first Process Manager operation. On Snow Leopard that call succeeds. On Lion it never returns; the translated guest self-SIGABRTs before `M02_AFTER_GetProcessPID_PSEUDO`.

The preserved Lion crash report again shows Rosetta's already-decoded host abort wrapper with:

- PID 5106 in the PID argument;
- signal 6 (SIGABRT);
- posix flag 1;
- host return EAX 0.

That is the same guest-requested abort mechanism previously seen inside `GetCurrentProcess`. It does **not** establish that `GetProcessForPID` is broken because that function was never reached.

This experiment therefore begins with:

```text
GetProcessForPID(getpid(), &psn)
```

and deliberately never calls `GetCurrentProcess` or `GetProcessPID`.

If a PSN is returned, the probe uses that PSN directly for `TransformProcessType`, `SetFrontProcess`, window creation, and a short Carbon event loop.

The Lion launch is again made through the already validated private LaunchServices compatibility copy so the known `-10665` admission gate does not mask the Process Manager result.

## Repository files

```text
tests/ppc-process-manager-getprocessforpid-first.c
scripts/build-ppc-process-manager-getprocessforpid-first-on-snowleopard.sh
scripts/prepare-ppc-process-manager-getprocessforpid-first-bundle.sh
scripts/run-snowleopard-ppc-process-manager-getprocessforpid-first-control.sh
scripts/run-lion-ppc-process-manager-getprocessforpid-first-experiment.sh
docs/process-manager-getprocessforpid-first-experiment.md
```

No Apple proprietary binary is committed.

## Safety constraints

For this experiment:

- do not call `GetCurrentProcess`;
- do not call `GetProcessPID` from the PPC subject;
- do not modify HIServices/ApplicationServices or Rosetta shims;
- do not modify the installed LaunchServices framework or database;
- do not broaden the private LaunchServices test patch;
- do not install Snow Leopard receipts;
- do not modify XNU;
- do not modify `/usr/oah/dyld` or the Rosetta shared cache;
- do not use live GDB, DTrace, or dtruss;
- do not test another PPC application;
- stop after the single guarded Lion launch.

The Lion runner also omits `open -W`. This removes the native launcher's unrelated wait-path `GetProcessPID` diagnostic from the experiment. It uses `open -n`, waits five seconds, and then evaluates the PPC subject's own milestone file.

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

## Phase B — build the GetProcessForPID-first PPC probe on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-process-manager-getprocessforpid-first-on-snowleopard.sh \
  ./ppc-process-manager-getprocessforpid-first-private-dyld
```

Expected outputs:

```text
ppc-process-manager-getprocessforpid-first-private-dyld
ppc-process-manager-getprocessforpid-first-private-dyld.info.txt
ppc-process-manager-getprocessforpid-first-private-dyld.sha256
```

Require:

- 32-bit PowerPC/ppc7400;
- `LC_LOAD_DYLINKER=/usr/oah/dyld`;
- Carbon dependency.

Do not rebuild the executable after its checksum sidecar is generated.

## Phase C — prepare the Snow Leopard app bundle

```sh
./scripts/prepare-ppc-process-manager-getprocessforpid-first-bundle.sh \
  ./ppc-process-manager-getprocessforpid-first-private-dyld \
  ./ppc-process-manager-getprocessforpid-first-private-dyld.sha256 \
  ./RosettaProcessManagerPIDFirst.app
```

Expected:

```text
RosettaProcessManagerPIDFirst.app
RosettaProcessManagerPIDFirst.app.manifest.txt
```

## Phase D — Snow Leopard positive control

Run from the logged-in Aqua user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-getprocessforpid-first-control.sh \
  ./RosettaProcessManagerPIDFirst.app \
  ./RosettaProcessManagerPIDFirst.app.manifest.txt \
  ./ppc-process-manager-getprocessforpid-first-snowleopard-control.log \
  ./ppc-process-manager-getprocessforpid-first-snowleopard-milestone.log
```

Require:

```text
PM_PIDFIRST_STATUS:GetProcessForPID=0
PM_PIDFIRST_MILESTONE:M15_SUCCESS
RESULT: PASS
```

The window titled **Rosetta PPC GetProcessForPID First** should appear for approximately two seconds.

If the Snow Leopard control fails, stop.

## Phase E — transfer exact artifacts to Lion and recreate the bundle

Transfer privately:

```text
payload/ppc-process-manager-getprocessforpid-first-private-dyld
payload/ppc-process-manager-getprocessforpid-first-private-dyld.info.txt
payload/ppc-process-manager-getprocessforpid-first-private-dyld.sha256
payload/ppc-process-manager-getprocessforpid-first-snowleopard-control.log
payload/ppc-process-manager-getprocessforpid-first-snowleopard-milestone.log
payload/snowleopard-RosettaProcessManagerPIDFirst.app.manifest.txt
```

On Lion:

```sh
cd /path/to/lion-rosetta-runtime

./scripts/prepare-ppc-process-manager-getprocessforpid-first-bundle.sh \
  ./payload/ppc-process-manager-getprocessforpid-first-private-dyld \
  ./payload/ppc-process-manager-getprocessforpid-first-private-dyld.sha256 \
  ./payload/RosettaProcessManagerPIDFirst.app
```

Compare the executable and Info.plist hashes between the Snow Leopard and Lion manifests. They must match exactly.

## Phase F — verify the existing private LaunchServices compatibility copy

Do not recreate or broaden it.

```sh
/usr/bin/python ./scripts/patch-lion-launchservices-ppc-compat.py \
  --check \
  ./payload/private-launchservices-ppc-compat/LaunchServices.framework/Versions/A/LaunchServices
```

Require:

```text
RESULT: ALREADY_PATCHED
```

Verify installed system LaunchServices remains:

```text
ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5
```

## Phase G — repeat native safety gates

Use the same validated syscall-295 kernel:

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
  "$XNU_SRC/syscall295-probe-process-manager-pidfirst-preflight.log"
```

Require both existing syscall-295 PASS lines.

## Phase H — run the guarded Lion GetProcessForPID-first test

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-getprocessforpid-first-experiment.sh
```

The runner:

1. re-verifies the kernel, translator, dyld/cache, private LaunchServices, and app identities;
2. proves the private i386 LaunchServices copy is loaded;
3. launches the PPC app once using `open -n`, not `open -W`;
4. waits five seconds for the probe's two-second event loop;
5. records the furthest PPC milestone and return-status evidence;
6. lists new crash/core diagnostics;
7. re-verifies all protected hashes.

Expected logs:

```text
payload/lion-ppc-process-manager-getprocessforpid-first-experiment.log
payload/lion-ppc-process-manager-getprocessforpid-first-load-preflight.log
payload/lion-ppc-process-manager-getprocessforpid-first-open.raw.log
payload/lion-ppc-process-manager-getprocessforpid-first-milestone.log   # if main is reached
```

## Phase I — stop and preserve evidence

Stop after the single Lion launch.

Return:

```text
ppc-process-manager-getprocessforpid-first-private-dyld.info.txt
ppc-process-manager-getprocessforpid-first-private-dyld.sha256
ppc-process-manager-getprocessforpid-first-snowleopard-control.log
ppc-process-manager-getprocessforpid-first-snowleopard-milestone.log
snowleopard-RosettaProcessManagerPIDFirst.app.manifest.txt
RosettaProcessManagerPIDFirst.app.manifest.txt
syscall295-probe-process-manager-pidfirst-preflight.log
lion-ppc-process-manager-getprocessforpid-first-experiment.log
lion-ppc-process-manager-getprocessforpid-first-load-preflight.log
lion-ppc-process-manager-getprocessforpid-first-open.raw.log
lion-ppc-process-manager-getprocessforpid-first-milestone.log   # if created
```

Also return every new crash report/core listed by the runner.

Do not upload the private LaunchServices framework binary.

## Result interpretation

### PASS

`GetProcessForPID(getpid())` returned a usable PSN and the app completed foreground conversion, window creation, and the Carbon event loop without invoking either `GetCurrentProcess` or `GetProcessPID`.

This would isolate the incompatibility to the current-process lookup family and justify designing a narrow Rosetta/HIServices compatibility shim around that path.

### GETPROCESSFORPID_BOUNDARY

The app reached `M01_BEFORE_GetProcessForPID` and then aborted before the function returned.

Combined with the prior `GetCurrentProcess` and pseudo-`GetProcessPID` failures, this would show that multiple Process Manager identity APIs share a missing translated-PPC registration/backend requirement. The next step would be a read-only Snow Leopard/Lion HIServices Process Manager implementation audit, not another API permutation.

### GETPROCESSFORPID_RETURNED_ERROR

The function returned rather than aborting but did not provide a usable PSN. Preserve the exact `PM_PIDFIRST_STATUS` value. The next step will be determined by that returned error.

### TRANSFORMPROCESSTYPE_BOUNDARY / SETFRONTPROCESS_BOUNDARY

PID-to-PSN lookup works. The new boundary is foreground-process conversion or activation.

### CREATENEWWINDOW_BOUNDARY or later

Process Manager identity and activation work. The next Carbon GUI subsystem becomes the boundary.

### PRE_MAIN_OR_LAUNCH_FAILURE

The already proven LaunchServices path unexpectedly regressed. Do not infer a Process Manager result.

## Non-goals

This experiment does not patch HIServices, Rosetta, LaunchServices, or XNU. It does not call `GetCurrentProcess` or `GetProcessPID`. It is a single functional test of the remaining documented PID-to-PSN route.
