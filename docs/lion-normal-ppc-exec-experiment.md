# Lion normal PowerPC exec experiment

## Objective

Test the **normal kernel PowerPC execution path** on Lion 10.7.5 after the guarded direct-translator control has succeeded.

The preceding experiment established all of the runtime prerequisites independently:

- the syscall-295 compatibility kernel boots;
- the native i386 translated-commpage probe passes;
- the native syscall-295 routing probe returns `EBADF` with no `SIGSYS`;
- the guarded direct `/usr/libexec/oah/translate` test reaches the PPC smoke-test message and exits 0 while using the private Snow Leopard dyld and process-local shared-cache validation bypass.

The remaining untested layer is the kernel's normal PowerPC activation path: recognizing the PPC executable, redirecting through `kern.exec.archhandler.powerpc`, preserving the PowerPC subject path for Rosetta, and arriving at the same guest runtime without invoking `translate` manually.

This experiment tests only that layer.

## Validated starting state

The current validated Lion control uses:

- Mac OS X 10.7.5 build `11G63`;
- syscall-295 experiment kernel SHA-256:
  `fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3`;
- architecture handler:
  `/usr/libexec/oah/translate`;
- experimental PPC executable SHA-256:
  `b34e7c4b1ffe9750ae866c4a1e2d732e5dd90aa44c3f79d15359d58076987b0a`;
- private Snow Leopard dyld SHA-256:
  `963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb`;
- Rosetta cache SHA-256:
  `2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911`;
- Rosetta cache-map SHA-256:
  `66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9`.

The PPC executable's `LC_LOAD_DYLINKER` must still name `/usr/oah/dyld`.

## Prepared runner

The runtime repository provides:

```text
scripts/run-lion-normal-ppc-exec-experiment.sh
```

The runner does **not** invoke `/usr/libexec/oah/translate` directly. It executes the PPC Mach-O itself and therefore exercises the normal kernel architecture-handler path.

It verifies the current kernel hash, architecture handler, translator identity, PPC executable identity, private dyld, Rosetta cache/map, and native Lion dyld integrity before execution. It also captures any new crash report or core file and verifies system/private dyld plus kernel integrity after the test.

The only process-local environment changes are:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

These are the same guest-cache conditions under which the direct-translator control passed.

## Safety constraints

For this experiment:

- do not replace Lion's `/usr/lib/dyld`;
- do not copy Snow Leopard libraries into Lion's `/usr/lib`;
- do not rebuild any dyld shared cache;
- do not change `DYLD_SHARED_REGION`;
- do not modify the private Snow Leopard dyld;
- do not rebuild or reinstall the kernel;
- do not use GDB, dtruss, or DTrace on the live Rosetta process;
- do not run the ordinary unmodified `ppc-smoketest`;
- do not run any GUI PowerPC application;
- stop after this one normal-exec control regardless of outcome.

Keep the previously validated alternate boot/rollback path available, although this experiment makes no kernel or system-file modification.

## Phase A — update the runtime tooling only

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm this file and the guarded runner are present:

```text
docs/lion-normal-ppc-exec-experiment.md
scripts/run-lion-normal-ppc-exec-experiment.sh
```

Do not stage or replace any private artifact in this phase.

## Phase B — re-establish the validated kernel identity

Set the source-tree paths used in the completed syscall-295 experiment:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
```

Load the exact candidate hash recorded before installation:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
echo "$ROSETTA_EXPECTED_KERNEL_SHA256"
```

For the current validated control it should be:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

Confirm the running kernel and handler again:

```sh
/usr/bin/shasum -a 256 /mach_kernel
/usr/sbin/sysctl kern.exec.archhandler.powerpc
```

The `/mach_kernel` hash must equal `ROSETTA_EXPECTED_KERNEL_SHA256`, and the handler must be:

```text
kern.exec.archhandler.powerpc: /usr/libexec/oah/translate
```

Stop if either differs.

## Phase C — repeat the two safe native gates

Before launching another PPC process, repeat the native commpage regression probe:

```sh
cd /path/to/lion-rosetta-runtime
./scripts/run-lion-commpage-probe.sh ./lion-commpage-probe
```

Require:

```text
RESULT: PASS - Lion native ABI and Rosetta translated commpage are present
```

Then repeat the syscall-295 routing probe from the completed XNU experiment:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-normal-exec-preflight.log"
```

Require both:

```text
RESULT: PASS - syscall 295 reached the compatibility front-end and returned EBADF
RESULT: PASS
```

If either native gate fails, stop. Do not execute a PPC binary.

## Phase D — run the guarded normal PPC exec experiment

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Do not use `scripts/run-ppc-smoketest.sh` for this controlled step. Run the dedicated guarded experiment through Bash:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-normal-ppc-exec-experiment.sh
```

The runner executes this validated PPC subject normally through the kernel:

```text
payload/ppc-smoketest-private-dyld
```

It does not manually launch `translate`.

The runner writes:

```text
payload/lion-normal-ppc-exec-experiment.log
payload/lion-normal-ppc-exec.raw.log
```

## Phase E — stop and preserve evidence

Stop after the runner returns, whether it passes or fails.

Preserve:

```text
payload/lion-normal-ppc-exec-experiment.log
payload/lion-normal-ppc-exec.raw.log
$XNU_SRC/syscall295-probe-normal-exec-preflight.log
```

Also preserve every new crash report or core file listed by the runner.

Do not perform another PPC launch before reviewing these outputs.

## Result interpretation

### PASS

A pass requires:

- the normal PPC execution returns status 0; and
- output contains `Rosetta PPC smoke test: pid=...`.

The expected successful library trace may include the PPC subject, Rosetta `Interposers.dylib`, PPC `libSystem.B.dylib`, and `libmathCommon.A.dylib`, matching the already successful direct-translator control.

A PASS establishes that the normal Lion PowerPC activation path, the subject-path correction, translated commpage, syscall-295 compatibility entry, private PPC dyld, and validated Rosetta cache arrangement work together for the minimal command-line PPC subject.

Stop after recording the pass. Broader PowerPC compatibility is a separate next phase.

### Translator usage or missing subject

If `translate` prints its usage text or otherwise behaves as though no PPC subject was supplied, preserve the exact raw output. That result points back to the PowerPC activation/subject-path layer despite the successful direct translator control.

Do not modify the runtime or kernel before reviewing it.

### New crash or loader error

Preserve the report, raw log, and every new diagnostic named by the runner. The error becomes the next measured compatibility boundary.

Do not preemptively add libraries or change the cache.

## What to return for review

Return:

```text
lion-normal-ppc-exec-experiment.log
lion-normal-ppc-exec.raw.log
syscall295-probe-normal-exec-preflight.log
```

Also return every new crash report or core file explicitly listed by the runner.

## Non-goals

This experiment does not:

- test Lion's native `/usr/lib/dyld` as a PPC guest loader;
- remove the process-local cache-validation bypass;
- define the final production dyld-redirection mechanism;
- test arbitrary PPC applications;
- test Carbon or Cocoa GUI applications;
- establish complete Rosetta compatibility.

It answers one question only: does a normal PPC `execve` now reach and successfully execute the validated PPC smoke subject on the fully prepared Lion kernel/runtime stack?
