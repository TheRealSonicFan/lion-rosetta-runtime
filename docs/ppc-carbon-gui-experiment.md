# PPC Carbon GUI compatibility experiment

## Objective

Move from successful command-line CoreFoundation translation to the first controlled **PowerPC GUI** test on Lion 10.7.5.

The preceding experiments have already validated:

- normal kernel PowerPC activation;
- PowerPC subject-path preservation;
- the translated commpage;
- syscall 295 `shared_region_map_np`;
- the private Snow Leopard PPC dyld;
- the validated Rosetta shared cache with process-local cache validation bypass;
- a normal PPC command-line subject using CoreFoundation.

This experiment changes only the guest application layer. It builds a very small Carbon executable that:

1. transforms itself into a foreground application;
2. creates a standard Carbon document window;
3. assigns a title and shows the window;
4. confirms the window is visible according to Carbon;
5. runs the Carbon application event loop;
6. exits automatically after a two-second event-loop timer.

The test is intentionally self-terminating so no manual window interaction is required.

## Repository files prepared for this experiment

The runtime repository provides:

```text
tests/ppc-carbon-gui-smoketest.c
scripts/build-ppc-carbon-gui-smoketest-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-control.sh
scripts/run-lion-ppc-carbon-gui-experiment.sh
docs/ppc-carbon-gui-experiment.md
```

No proprietary Apple binary is committed.

## Safety constraints

Keep all previously validated runtime and kernel state unchanged:

- do not replace Lion's native `/usr/lib/dyld`;
- do not copy Snow Leopard libraries/frameworks into Lion system paths;
- do not rebuild a dyld shared cache;
- do not modify or reinstall XNU;
- do not remove `DYLD_SHARED_CACHE_DONT_VALIDATE`;
- do not change `DYLD_SHARED_REGION`;
- do not use live GDB, dtruss, or DTrace;
- do not launch an arbitrary PPC GUI application;
- do not use LaunchServices/`open` for this test;
- stop after this single Carbon GUI control and preserve the evidence.

Run both GUI controls from the logged-in Aqua console user's Terminal session. Do not run them via `sudo`, SSH, or a background login session.

## Phase A — update both repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout used for the native syscall-295 probe:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

Do not modify the installed kernel.

## Phase B — build the exact PPC Carbon GUI subject on Snow Leopard

Use the validated Snow Leopard 10.6.8 system and Xcode 3.2.6 GCC:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-carbon-gui-smoketest-on-snowleopard.sh \
  ./ppc-carbon-gui-smoketest-private-dyld
```

The builder must create:

```text
ppc-carbon-gui-smoketest-private-dyld
ppc-carbon-gui-smoketest-private-dyld.info.txt
ppc-carbon-gui-smoketest-private-dyld.sha256
```

The info file must establish:

- a non-fat 32-bit PowerPC executable;
- `LC_LOAD_DYLINKER` = `/usr/oah/dyld`;
- a dependency on `/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon`.

Do not rebuild or modify the executable after its SHA-256 sidecar is generated.

## Phase C — Snow Leopard GUI positive control

The exact validated Snow Leopard dyld must already exist privately at:

```text
/usr/oah/dyld
```

with SHA-256:

```text
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb
```

Run the control from the logged-in Snow Leopard Aqua user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./ppc-carbon-gui-snowleopard-control.log
```

A small window titled **Rosetta PPC Carbon GUI** should appear for approximately two seconds and then disappear automatically.

The control must contain both markers:

```text
Rosetta PPC Carbon GUI window shown:
Rosetta PPC Carbon GUI smoke test:
```

and end with:

```text
RESULT: PASS
```

The textual PASS is required even if the window was visually observed.

If the Snow Leopard control fails, stop. Do not transfer the Carbon test to Lion.

## Phase D — transfer the exact validated Carbon artifacts to Lion

Transfer privately into the Lion runtime checkout:

```text
payload/ppc-carbon-gui-smoketest-private-dyld
payload/ppc-carbon-gui-smoketest-private-dyld.info.txt
payload/ppc-carbon-gui-smoketest-private-dyld.sha256
```

Also preserve:

```text
ppc-carbon-gui-snowleopard-control.log
```

On Lion verify the transferred hash:

```sh
cd /path/to/lion-rosetta-runtime
/usr/bin/shasum -a 256 ./payload/ppc-carbon-gui-smoketest-private-dyld
cat ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256
```

The values must match exactly.

Do not alter the executable after transfer.

## Phase E — re-establish the validated Lion kernel state

Use the same kernel that passed the syscall-295, normal-exec, and CoreFoundation experiments:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

For the validated system the expected kernel SHA-256 is:

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

Requirements:

- `/mach_kernel` hash matches the expected value;
- PowerPC handler is `/usr/libexec/oah/translate`;
- current user equals the owner of `/dev/console`;
- WindowServer is running.

Stop if any requirement fails.

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
  "$XNU_SRC/syscall295-probe-carbon-gui-preflight.log"
```

Require:

```text
RESULT: PASS - syscall 295 reached the compatibility front-end and returned EBADF
RESULT: PASS
```

Do not continue if either native gate fails.

## Phase G — run the guarded Lion Carbon GUI experiment

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Run from the logged-in Aqua console user's Terminal:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-carbon-gui-experiment.sh \
  ./payload/ppc-carbon-gui-smoketest-private-dyld \
  ./payload/ppc-carbon-gui-smoketest-private-dyld.sha256
```

The runner executes the PowerPC binary normally through the kernel architecture handler. It does not launch `translate` manually and does not use LaunchServices.

The same small Carbon window should appear for approximately two seconds and close automatically.

The only dyld environment conditions retained are the already validated:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

The runner writes:

```text
payload/lion-ppc-carbon-gui-experiment.log
payload/lion-ppc-carbon-gui.raw.log
```

## Phase H — stop and preserve evidence

Stop after the Lion runner returns, regardless of outcome.

Preserve:

```text
ppc-carbon-gui-smoketest-private-dyld.info.txt
ppc-carbon-gui-smoketest-private-dyld.sha256
ppc-carbon-gui-snowleopard-control.log
syscall295-probe-carbon-gui-preflight.log
payload/lion-ppc-carbon-gui-experiment.log
payload/lion-ppc-carbon-gui.raw.log
```

Also preserve every new crash report or core file explicitly listed by the Lion runner.

Do not test Cocoa or a real-world PPC application before these results are reviewed.

## Result interpretation

### PASS

A complete pass requires:

- the executable exits 0;
- the raw log contains `Rosetta PPC Carbon GUI window shown:`;
- the raw log contains `Rosetta PPC Carbon GUI smoke test:`;
- the runner ends with `RESULT: PASS`.

The program itself verifies that Carbon reports the window visible and that the Carbon event loop runs until the scheduled timer fires.

A pass establishes that this Lion Rosetta stack can execute a normal 32-bit PPC Carbon GUI process far enough to create a window and run the Carbon event loop.

### Loader error

If dyld reports a missing image, framework, or architecture, preserve the exact path and output. Do not copy a Snow Leopard framework into Lion.

### Carbon API failure

If the probe reports a nonzero `OSStatus`, preserve the exact operation and status number. That becomes the next compatibility boundary.

### Crash

Preserve the runner report, raw log, and every new crash/core diagnostic. Analyze the non-debugged evidence before changing XNU or the runtime.

## What to return for review

Return:

```text
ppc-carbon-gui-smoketest-private-dyld.info.txt
ppc-carbon-gui-smoketest-private-dyld.sha256
ppc-carbon-gui-snowleopard-control.log
syscall295-probe-carbon-gui-preflight.log
lion-ppc-carbon-gui-experiment.log
lion-ppc-carbon-gui.raw.log
```

Also state whether you visually saw the **Rosetta PPC Carbon GUI** window appear on Snow Leopard and on Lion. The textual runner result remains authoritative, but the visual observation is useful supporting evidence.

Return any new crash report/core file explicitly listed by the runner.

## Non-goals

This experiment does not:

- test Cocoa/AppKit;
- launch through Finder or LaunchServices;
- test document opening;
- test OpenGL;
- test arbitrary real-world PPC applications;
- remove the private dyld path;
- remove the shared-cache validation bypass;
- define the final production installation.

It isolates the first GUI/window-event-loop layer after command-line CoreFoundation compatibility has been proven.


## Observed Lion result: SIGABRT before window marker

The Snow Leopard positive control passed with the exact experimental executable: the Carbon window became visible, the event loop timer fired, and the program exited 0.

The Lion run did not reproduce that result. The exact executable and all guarded kernel/runtime identities passed preflight, and dyld loaded the Carbon/ApplicationServices dependency graph, but neither Carbon program marker was printed and no window appeared. The process exited 134 and generated a crash report plus `/cores/core.1311`.

The non-debugged crash report records `EXC_CRASH (SIGABRT)` at Rosetta host EIP `0xb815ac07`. Its register state includes `EAX=0`, carry clear, `EDI=0x51f` (the process PID 1311), and `ESI=6` (SIGABRT). This pattern suggests deliberate self-signal delivery through Rosetta's syscall path, but the crash report alone is not enough to prove the syscall number or identify the guest-side abort source.

Do not copy frameworks, modify XNU, or rerun the Carbon subject yet. The authoritative next step is the read-only preserved-core procedure in `docs/carbon-gui-sigabrt-postmortem.md`, using `scripts/collect-lion-carbon-sigabrt-core.sh`.


### Preserved-core follow-up

The preserved `/cores/core.1311` has now been analyzed postmortem. Rosetta's direct caller supplies Unix syscall `0x25` (37), and the preserved arguments are `kill(1311, SIGABRT, 1)`. The syscall returns success before the process dies from SIGABRT.

This means the failure is guest-requested, not a second missing Lion syscall ABI.

The core does not resolve whether the guest abort occurs before `main()` or inside one of the early Carbon/Process Manager calls. The next experiment is therefore `docs/carbon-gui-milestone-experiment.md`.
