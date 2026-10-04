# Private LaunchServices PPC compatibility experiment

## Objective

Test the localized Lion LaunchServices PPC policy hypothesis with a private, process-local copy of LaunchServices. The installed system framework, LaunchServices database, Rosetta runtime, dyld cache, and XNU kernel must remain unchanged.

The provenance audit now shows that Lion's launch-time unsupported-format result is computed by __LSBundleDataGetUnsupportedFormatFlag from bundle architecture state plus current-CPU policy; no dedicated unsupported-format setter was identified. Snow Leopard contains an Intel-host fallback that accepts the PPC architecture bit for Rosetta. Lion removed that fallback.

For this experiment only, a private copy of the Lion i386 LaunchServices slice changes the x86_64-host architecture mask from 0x14000000 to 0x16000000, adding the PPC architecture bit 0x02000000. This is a one-byte hypothesis test, not the intended production implementation.

The private copy is loaded only into an i386 /usr/bin/open process through DYLD_FRAMEWORK_PATH. A no-application preflight must prove that the private framework is actually loaded before any PPC application is launched.

## Repository files

```text
scripts/patch-lion-launchservices-ppc-compat.py
scripts/prepare-private-launchservices-ppc-compat.sh
scripts/run-lion-private-launchservices-ppc-experiment.sh
docs/private-launchservices-ppc-compat-experiment.md
```

No Apple binary is committed. The private framework copy remains under ignored payload/.

## Safety constraints

- Do not modify the installed /System/Library LaunchServices framework.
- Do not rebuild or edit the LaunchServices database.
- Do not run lsregister -f, lsregister -u, or database reset commands.
- Do not install Snow Leopard Rosetta receipts.
- Do not copy Snow Leopard CoreServices or LaunchServices binaries to Lion.
- Do not modify XNU, /usr/oah/dyld, or the Rosetta shared cache.
- Do not remove DYLD_SHARED_CACHE_DONT_VALIDATE from the validated PPC app.
- Do not use live GDB, DTrace, or dtruss.
- Do not test another PPC application.
- Stop after the single guarded compatibility launch.

## Phase A - update both repositories

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD

cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild is part of this experiment.

## Phase B - verify the exact system LaunchServices baseline

From the runtime checkout:

```sh
/usr/bin/shasum -a 256 \
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices

/usr/bin/python ./scripts/patch-lion-launchservices-ppc-compat.py \
  --check \
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Versions/A/LaunchServices
```

Required system LaunchServices SHA-256:

```text
ffdc7bd8fb0cb5f7ceabc9c88978e991e71fbfe7390a8345ce545397b1ab24b5
```

The patcher check must end with RESULT: PATCHABLE. Stop if the hash or signature differs.

## Phase C - create the private patched framework

```sh
/bin/bash ./scripts/prepare-private-launchservices-ppc-compat.sh
```

Expected private outputs:

```text
payload/private-launchservices-ppc-compat/LaunchServices.framework
payload/private-launchservices-ppc-compat/manifest.txt
payload/private-launchservices-ppc-compat/patch.log
```

The preparer verifies the system hash, copies the framework privately, applies the one-byte change only to the private i386 slice, verifies that exactly one byte changed from 0x14 to 0x16, verifies the patched signature, and then re-verifies the installed system LaunchServices hash.

Review manifest.txt and patch.log. The installed system LaunchServices hash must remain unchanged. Do not copy the private framework into /System/Library.

## Phase D - confirm the previously validated PPC app bundle is unchanged

Use the same bundle from the prior LaunchServices experiment:

```text
payload/RosettaCarbonLaunchServices.app
payload/RosettaCarbonLaunchServices.app.manifest.txt
```

Verify the bundled executable SHA-256 against the existing manifest. Do not rebuild or re-register the app.

## Phase E - repeat the validated native safety gates

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

Run the existing native commpage probe and require PASS. Then run:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-private-launchservices-preflight.log"
```

Require both syscall-295 PASS lines. Stop if either native gate fails.

## Phase F - run the guarded private-LaunchServices experiment

Return to the runtime checkout and run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-private-launchservices-ppc-experiment.sh
```

The runner first performs a no-application i386 open preflight with DYLD_FRAMEWORK_PATH and DYLD_PRINT_LIBRARIES. Its exit status may be nonzero because no target is supplied; the required condition is that the dyld trace explicitly names the private patched LaunchServices binary. If that proof is absent, no PPC launch is attempted.

Only after the private framework load is confirmed does the runner perform one i386 open -n -W launch of the already validated PPC app.

Expected logs:

```text
payload/lion-private-launchservices-ppc-experiment.log
payload/lion-private-launchservices-load-preflight.log
payload/lion-private-launchservices-open.raw.log
```

If the PPC app reaches main(), the runner also creates:

```text
payload/lion-private-launchservices-milestone.log
```

Any new crash/core diagnostics are listed in the experiment report.

## Phase G - stop and preserve evidence

Stop after the one guarded launch, regardless of outcome.

Return:

```text
payload/private-launchservices-ppc-compat/manifest.txt
payload/private-launchservices-ppc-compat/patch.log
syscall295-probe-private-launchservices-preflight.log
lion-private-launchservices-ppc-experiment.log
lion-private-launchservices-load-preflight.log
lion-private-launchservices-open.raw.log
lion-private-launchservices-milestone.log   # only if created
```

Also return every new crash report/core explicitly listed by the runner. Do not upload the private LaunchServices framework binary.

## Result interpretation

### PASS

If the app reaches M27_SUCCESS, the process-private policy change is sufficient to move the registered PPC application through complete Carbon GUI execution. That proves the LaunchServices PPC policy gate experimentally, but the one-byte mask broadening is not the final production design; a final patch should reproduce Snow Leopard's exact fallback semantics.

### SAME_LAUNCHSERVICES_GATE

If open still returns -10665 while the preflight proves the patched private i386 LaunchServices was loaded, the rejecting decision is occurring elsewhere, most likely another process or architecture slice such as coreservicesd. Do not broaden the patch; the next step would be x86_64/server-side localization.

### LAUNCH_GATE_CLEARED_GETCURRENTPROCESS_BOUNDARY_REMAINS

If the app starts and reaches only M00_MAIN_ENTER and M01_BEFORE_GetCurrentProcess, the LaunchServices gate has been cleared and the previously independent Carbon Process Manager GetCurrentProcess boundary remains.

### LAUNCH_GATE_CLEARED_BOUNDARY_MOVED

If the app starts and proceeds farther, the furthest milestone becomes the next measured Carbon boundary.

### NEW_LAUNCH_FAILURE

If -10665 disappears but no milestone is generated, preserve the open log and diagnostics. Do not infer success from the changed error alone.

## Non-goals

This experiment does not modify system LaunchServices, define final Finder integration, install receipts, change XNU, or fix the later GetCurrentProcess problem. It is a controlled proof of the LaunchServices PPC policy hypothesis.