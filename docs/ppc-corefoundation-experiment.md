# PPC CoreFoundation compatibility experiment

## Objective

Expand the validated Lion Rosetta command-line path by one framework layer: **CoreFoundation**.

The preceding normal-exec experiment proved that a 32-bit PowerPC Mach-O can now be launched normally through Lion's kernel architecture handler and execute successfully under Rosetta when all of the already validated conditions are kept unchanged:

- syscall-295 compatibility kernel;
- translated commpage restoration;
- PowerPC subject-path correction;
- private Snow Leopard PPC dyld at `/usr/oah/dyld`;
- exact validated Rosetta shared cache;
- process-local `DYLD_SHARED_CACHE_DONT_VALIDATE=1`.

This experiment changes only the PPC subject. Instead of the minimal libc-only smoke test, it uses a small PowerPC executable linked against CoreFoundation and exercises real CoreFoundation object creation, string conversion, array creation, and release.

It does **not** test GUI frameworks or production dyld/cache integration.

## Repository files prepared for this experiment

The runtime repository now provides:

```text
tests/ppc-corefoundation-smoketest.c
scripts/build-ppc-corefoundation-smoketest-on-snowleopard.sh
scripts/run-snowleopard-ppc-corefoundation-control.sh
scripts/run-lion-ppc-corefoundation-experiment.sh
docs/ppc-corefoundation-experiment.md
```

No proprietary Apple binary is included in the repository.

## Safety constraints

Do not change these conditions during this experiment:

- do not replace Lion's native `/usr/lib/dyld`;
- do not copy Snow Leopard libraries into Lion's `/usr/lib`;
- do not rebuild any dyld shared cache;
- do not modify the syscall-295 kernel;
- do not remove the process-local cache-validation bypass yet;
- do not change `DYLD_SHARED_REGION`;
- do not use live GDB, dtruss, or DTrace;
- do not run a GUI PowerPC application;
- stop after the single CoreFoundation experiment and preserve the evidence.

The CoreFoundation test executable is disposable private test material only because its `LC_LOAD_DYLINKER` is rewritten to the private test path. The source and scripts remain public.

## Phase A — update both checkouts

On Snow Leopard and Lion, update the runtime checkout before using the new scripts:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout so the native syscall-routing probe tooling remains current:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

Do not modify the installed kernel.

## Phase B — build the exact PPC CoreFoundation subject on Snow Leopard

Perform the build on the validated Snow Leopard 10.6.8 source machine.

From the runtime checkout:

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-corefoundation-smoketest-on-snowleopard.sh \
  ./ppc-corefoundation-smoketest-private-dyld
```

The builder must produce:

```text
ppc-corefoundation-smoketest-private-dyld
ppc-corefoundation-smoketest-private-dyld.info.txt
ppc-corefoundation-smoketest-private-dyld.sha256
```

The info file must show:

- 32-bit PowerPC Mach-O;
- `LC_LOAD_DYLINKER` = `/usr/oah/dyld`;
- a dependency on `/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation`.

Do not rebuild the executable after its SHA-256 sidecar is generated.

## Phase C — Snow Leopard positive control

The exact validated Snow Leopard dyld must already be staged at:

```text
/usr/oah/dyld
```

Its required SHA-256 remains:

```text
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb
```

If it is not staged, use the same private donor artifact and staging procedure already validated in the earlier private-dyld experiment. Do not modify Snow Leopard's native `/usr/lib/dyld`.

Run the positive control:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-corefoundation-control.sh \
  ./ppc-corefoundation-smoketest-private-dyld \
  ./ppc-corefoundation-smoketest-private-dyld.sha256 \
  ./ppc-corefoundation-snowleopard-control.log
```

Require:

```text
RESULT: PASS
```

The test output must contain a line beginning:

```text
Rosetta PPC CoreFoundation smoke test:
```

If the Snow Leopard control fails, stop. Do not transfer the test to Lion.

## Phase D — transfer the exact validated test artifacts to Lion

Transfer these files privately to the Lion runtime checkout:

```text
payload/ppc-corefoundation-smoketest-private-dyld
payload/ppc-corefoundation-smoketest-private-dyld.info.txt
payload/ppc-corefoundation-smoketest-private-dyld.sha256
```

Also preserve the Snow Leopard control log for review.

On Lion, confirm the transferred executable hash matches its sidecar:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/shasum -a 256 ./payload/ppc-corefoundation-smoketest-private-dyld
cat ./payload/ppc-corefoundation-smoketest-private-dyld.sha256
```

Do not alter the executable after transfer.

## Phase E — re-establish the validated Lion kernel state

Use the same syscall-295 kernel that passed the direct and normal PPC smoke tests.

Set:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

For the currently validated control, the expected hash is:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Verify:

```sh
/usr/bin/shasum -a 256 /mach_kernel
/usr/sbin/sysctl kern.exec.archhandler.powerpc
```

The hash must match, and the handler must remain:

```text
/usr/libexec/oah/translate
```

Stop if either differs.

## Phase F — repeat the two safe native gates

From the Lion runtime checkout:

```sh
./scripts/run-lion-commpage-probe.sh ./lion-commpage-probe
```

Require the existing commpage PASS.

Then from the XNU source directory:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-corefoundation-preflight.log"
```

Require both syscall-probe PASS lines, including `EBADF` with no `SIGSYS`.

If either native gate fails, stop and do not execute the PPC CoreFoundation subject.

## Phase G — run the guarded Lion CoreFoundation experiment

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-corefoundation-experiment.sh \
  ./payload/ppc-corefoundation-smoketest-private-dyld \
  ./payload/ppc-corefoundation-smoketest-private-dyld.sha256
```

The runner performs a normal PPC exec through the kernel. It does not invoke `translate` directly.

It retains only the already validated process-local runtime conditions:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

It writes:

```text
payload/lion-ppc-corefoundation-experiment.log
payload/lion-ppc-corefoundation.raw.log
```

## Phase H — stop and preserve evidence

Stop after the runner returns, regardless of the outcome.

Preserve:

```text
ppc-corefoundation-smoketest-private-dyld.info.txt
ppc-corefoundation-smoketest-private-dyld.sha256
ppc-corefoundation-snowleopard-control.log
syscall295-probe-corefoundation-preflight.log
payload/lion-ppc-corefoundation-experiment.log
payload/lion-ppc-corefoundation.raw.log
```

Also preserve every new crash report or core file listed by the Lion runner.

Do not test another framework or GUI application until these results are reviewed.

## Result interpretation

### PASS

A complete pass requires status 0 and output beginning with:

```text
Rosetta PPC CoreFoundation smoke test:
```

A pass establishes that the validated Lion Rosetta stack can execute a normal PPC command-line subject that uses CoreFoundation, not just libc/libSystem.

It does **not** establish complete framework compatibility.

### Loader error

If dyld reports a missing image or architecture mismatch, preserve the exact path and output. Do not copy a library into Lion's system directories.

### Crash

Preserve the runner report, raw log, and every new crash/core file. Analyze the non-debugged diagnostic before changing the runtime or kernel.

## What to return for review

Return:

```text
ppc-corefoundation-smoketest-private-dyld.info.txt
ppc-corefoundation-smoketest-private-dyld.sha256
ppc-corefoundation-snowleopard-control.log
syscall295-probe-corefoundation-preflight.log
lion-ppc-corefoundation-experiment.log
lion-ppc-corefoundation.raw.log
```

Also return every new diagnostic named by the runner.

## Non-goals

This experiment does not:

- remove the private dyld path;
- remove `DYLD_SHARED_CACHE_DONT_VALIDATE`;
- test arbitrary existing PPC binaries;
- test ApplicationServices, Carbon, Cocoa, or GUI launch;
- define the final production installation.

It is the first controlled compatibility-expansion test after the minimal normal PPC exec path was proven.


## Observed result: PASS

The PPC CoreFoundation experiment has now passed completely on both the Snow Leopard 10.6.8 control system and Lion 10.7.5.

Validated experimental executable SHA-256:

```text
47c8ee924e7dcd940832457c25caf3a4c6c8e9fcf907929f58794ae1851da841
```

The Snow Leopard control loaded CoreFoundation plus its dependent PPC runtime libraries, printed the expected CoreFoundation marker, and exited 0.

On Lion, the exact same executable and private dyld were used. The guarded normal PPC run loaded:

```text
/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation
/usr/lib/libSystem.B.dylib
/usr/lib/libauto.dylib
/usr/lib/libicucore.A.dylib
/usr/lib/libobjc.A.dylib
/usr/lib/libz.1.dylib
/usr/lib/libstdc++.6.dylib
/usr/lib/system/libmathCommon.A.dylib
```

The probe created and converted a CoreFoundation string, created a CFArray, validated the results, printed the expected marker, and exited 0. No new crash/core diagnostic was produced. The private dyld, Lion native dyld, kernel, and Rosetta cache hashes remained unchanged.

This closes the command-line CoreFoundation layer for the controlled environment.

The next layer is the first controlled PPC GUI/window-event-loop test. Follow `docs/ppc-carbon-gui-experiment.md`.
