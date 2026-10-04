# Carbon LaunchServices registration experiment

## Objective

Test whether the Lion Carbon failure at `GetCurrentProcess` is specific to launching the PPC executable directly from a shell, rather than through LaunchServices as a registered application bundle.

The milestone experiment localized the Lion failure precisely:

- `main()` is reached;
- `M01_BEFORE_GetCurrentProcess` is written;
- `M02_AFTER_GetCurrentProcess` is never reached;
- the process deliberately requests `kill(self, SIGABRT, 1)` through Rosetta and terminates.

The exact milestone binary succeeds on Snow Leopard. Therefore the next controlled variable is **application launch context**.

This experiment packages a near-identical milestone probe as a real `.app` bundle and launches it through LaunchServices with `open -n -W`. The bundle declares the already validated Rosetta dyld environment through the documented `LSEnvironment` Info.plist dictionary, so the PPC process still receives:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

The probe also writes its milestones to a fixed private file in `/tmp`, because LaunchServices GUI launches do not provide a reliable shell stdout/stderr channel on these historical systems.

This experiment does not repair or bypass `GetCurrentProcess`. It tests whether LaunchServices application registration is the missing precondition.

## Prepared repository files

The runtime repository provides:

```text
tests/ppc-carbon-launchservices-milestone.c
scripts/build-ppc-carbon-launchservices-milestone-on-snowleopard.sh
scripts/prepare-ppc-carbon-launchservices-bundle.sh
scripts/run-snowleopard-ppc-carbon-launchservices-control.sh
scripts/run-lion-ppc-carbon-launchservices-experiment.sh
docs/carbon-launchservices-experiment.md
```

No proprietary Apple binary is committed.

## Safety constraints

For this experiment:

- do not modify or reinstall XNU;
- do not replace Lion's native `/usr/lib/dyld`;
- do not copy Snow Leopard frameworks or libraries into Lion;
- do not rebuild the Rosetta shared cache;
- do not change `DYLD_SHARED_REGION`;
- do not remove the private `/usr/oah/dyld`;
- do not use live GDB, DTrace, or dtruss;
- do not rerun the prior shell-launched Carbon milestone binary;
- do not test a real-world PPC application;
- run the LaunchServices controls from the logged-in Aqua console user's Terminal session;
- stop after the single Lion LaunchServices run.

## Fixed milestone log

The bundle executable writes unbuffered milestones to:

```text
/tmp/rosetta-carbon-launchservices-milestone.log
```

The control runners remove any previous copy immediately before launch.

The log also records whether the two required `LSEnvironment` variables are visible in `main()`.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout used for the already validated syscall-295 probe:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild is part of this experiment.

## Phase B — build the LaunchServices milestone subject on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-carbon-launchservices-milestone-on-snowleopard.sh \
  ./ppc-carbon-launchservices-milestone-private-dyld
```

Expected outputs:

```text
ppc-carbon-launchservices-milestone-private-dyld
ppc-carbon-launchservices-milestone-private-dyld.info.txt
ppc-carbon-launchservices-milestone-private-dyld.sha256
```

The info file must show:

- a 32-bit PowerPC Mach-O executable;
- `LC_LOAD_DYLINKER` = `/usr/oah/dyld`;
- a Carbon framework dependency.

Do not modify or rebuild the executable after its checksum sidecar is created.

## Phase C — prepare the Snow Leopard app bundle

Create the bundle around the exact executable:

```sh
./scripts/prepare-ppc-carbon-launchservices-bundle.sh \
  ./ppc-carbon-launchservices-milestone-private-dyld \
  ./ppc-carbon-launchservices-milestone-private-dyld.sha256 \
  ./RosettaCarbonLaunchServices.app
```

This creates:

```text
RosettaCarbonLaunchServices.app
RosettaCarbonLaunchServices.app.manifest.txt
```

The manifest must show:

- the exact executable SHA-256;
- an Info.plist SHA-256;
- `CFBundleExecutable=RosettaCarbonLaunchServices`;
- `LSEnvironment.DYLD_SHARED_CACHE_DONT_VALIDATE=1`;
- `LSEnvironment.DYLD_PRINT_LIBRARIES=1`.

The bundled executable hash must remain identical to the standalone executable.

## Phase D — Snow Leopard LaunchServices positive control

Run from the logged-in Aqua console user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-launchservices-control.sh \
  ./RosettaCarbonLaunchServices.app \
  ./RosettaCarbonLaunchServices.app.manifest.txt \
  ./ppc-carbon-launchservices-snowleopard-control.log
```

The app is registered with LaunchServices and launched using `open -n -W`.

A small window titled **Rosetta PPC Carbon LaunchServices** should appear for approximately two seconds and close automatically.

Require the milestone log to include:

```text
CARBON_LS_ENV:DYLD_SHARED_CACHE_DONT_VALIDATE=1
CARBON_LS_MILESTONE:M00_MAIN_ENTER
...
CARBON_LS_MILESTONE:M27_SUCCESS
```

and the control log must end with:

```text
RESULT: PASS
```

If the Snow Leopard LaunchServices control fails, stop. Do not transfer the experiment to Lion.

## Phase E — transfer the exact validated artifacts to Lion

Transfer privately:

```text
ppc-carbon-launchservices-milestone-private-dyld
ppc-carbon-launchservices-milestone-private-dyld.info.txt
ppc-carbon-launchservices-milestone-private-dyld.sha256
ppc-carbon-launchservices-snowleopard-control.log
RosettaCarbonLaunchServices.app.manifest.txt
```

Place the executable and its two sidecars in the Lion runtime checkout's ignored `payload/` directory.

Preserve the Snow Leopard bundle manifest under a distinct name on Lion, for example:

```text
payload/snowleopard-RosettaCarbonLaunchServices.app.manifest.txt
```

## Phase F — recreate the exact bundle definition on Lion

From the Lion runtime checkout:

```sh
./scripts/prepare-ppc-carbon-launchservices-bundle.sh \
  ./payload/ppc-carbon-launchservices-milestone-private-dyld \
  ./payload/ppc-carbon-launchservices-milestone-private-dyld.sha256 \
  ./payload/RosettaCarbonLaunchServices.app
```

Compare the critical manifest hashes with the Snow Leopard manifest:

```sh
grep -E '^(executable_sha256|info_plist_sha256)=' \
  ./payload/snowleopard-RosettaCarbonLaunchServices.app.manifest.txt

grep -E '^(executable_sha256|info_plist_sha256)=' \
  ./payload/RosettaCarbonLaunchServices.app.manifest.txt
```

Both `executable_sha256` and `info_plist_sha256` must match across systems.

Stop if they differ.

## Phase G — re-establish the validated Lion kernel/runtime gates

Use the same kernel that passed syscall 295, normal PPC exec, and CoreFoundation:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

For the validated system:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Verify:

```sh
/usr/bin/shasum -a 256 /mach_kernel
/usr/sbin/sysctl kern.exec.archhandler.powerpc
/usr/bin/id -un
/usr/bin/stat -f '%Su' /dev/console
/bin/ps -ax | /usr/bin/grep '[W]indowServer'
```

Then repeat the two native gates:

```sh
cd /path/to/lion-rosetta-runtime
./scripts/run-lion-commpage-probe.sh ./lion-commpage-probe
```

Require its existing PASS.

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-carbon-launchservices-preflight.log"
```

Require both syscall-295 PASS lines.

Do not launch the app if any gate differs from the prior validated state.

## Phase H — run the guarded Lion LaunchServices experiment

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-carbon-launchservices-experiment.sh \
  ./payload/RosettaCarbonLaunchServices.app \
  ./payload/RosettaCarbonLaunchServices.app.manifest.txt
```

The runner:

1. verifies all established kernel/runtime identities;
2. verifies the bundle's PPC executable and `LSEnvironment`;
3. registers the bundle with LaunchServices;
4. launches it through `open -n -W`;
5. copies the fixed milestone file into `payload/`;
6. records the furthest LaunchServices milestone;
7. captures every new crash/core diagnostic;
8. rechecks kernel, dyld, cache, and bundled-executable hashes.

Expected output files:

```text
payload/lion-ppc-carbon-launchservices-experiment.log
payload/lion-ppc-carbon-launchservices-open.raw.log
payload/lion-ppc-carbon-launchservices-milestone.log
```

## Phase I — stop and preserve evidence

Stop immediately after the single Lion LaunchServices run.

Preserve:

```text
ppc-carbon-launchservices-milestone-private-dyld.info.txt
ppc-carbon-launchservices-milestone-private-dyld.sha256
ppc-carbon-launchservices-snowleopard-control.log
snowleopard-RosettaCarbonLaunchServices.app.manifest.txt
RosettaCarbonLaunchServices.app.manifest.txt
syscall295-probe-carbon-launchservices-preflight.log
lion-ppc-carbon-launchservices-experiment.log
lion-ppc-carbon-launchservices-open.raw.log
lion-ppc-carbon-launchservices-milestone.log
```

Also preserve every new crash report/core explicitly listed by the runner.

Do not change XNU, frameworks, Rosetta shims, or dyld/cache state after this run.

## Result interpretation

### PASS

If the LaunchServices milestone reaches `M27_SUCCESS`, LaunchServices application registration changes the result from the shell-launched `GetCurrentProcess` abort to successful Carbon GUI execution.

This would strongly localize the missing condition to GUI application registration/launch context rather than Carbon framework code itself.

Stop after the pass; a production launch-path design would be a separate phase.

### SAME_GETCURRENTPROCESS_BOUNDARY

If the furthest marker remains:

```text
M01_BEFORE_GetCurrentProcess
```

then normal LaunchServices app registration is not sufficient. The next analysis should focus on the Process Manager/LaunchServices registration state visible to translated PPC code and Rosetta's ApplicationServices compatibility path.

Do not copy frameworks or patch XNU based on that result alone.

### BOUNDARY_MOVED

If `M02_AFTER_GetCurrentProcess` is reached but a later marker fails, the LaunchServices launch context fixed the immediate Process Manager boundary and the new furthest marker becomes the next measured compatibility boundary.

### PRE_MAIN_OR_LAUNCH_FAILURE

If no `M00_MAIN_ENTER` appears, preserve the open log and new diagnostics. Verify the LaunchServices environment/bundle launch path before drawing a Carbon conclusion.

## What to return for review

Return all Phase I text artifacts and any new crash report/core listed by the runner.

Also state whether the **Rosetta PPC Carbon LaunchServices** window was visually observed on Snow Leopard and Lion.

## Non-goals

This experiment does not:

- fix `GetCurrentProcess`;
- copy a Process Manager or LaunchServices framework;
- modify Rosetta shims;
- patch XNU;
- remove the private dyld;
- remove the cache-validation bypass;
- launch a real-world PPC application.

It isolates whether LaunchServices application registration is the missing condition at the first Carbon Process Manager call.
