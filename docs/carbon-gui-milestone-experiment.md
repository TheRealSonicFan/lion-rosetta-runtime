# Carbon GUI milestone experiment

## Objective

Localize the first Lion PPC Carbon GUI failure to a precise guest-side phase without changing the kernel, Rosetta runtime, dyld cache, private dyld, or framework set.

The preserved-core postmortem has now established that the Lion SIGABRT is not another missing host syscall ABI:

- Rosetta's host wrapper executes a Unix syscall through `int $0x80`;
- the direct caller supplies syscall number `0x25` (decimal 37);
- Lion and Snow Leopard define syscall 37 as `kill(pid, signum, posix)`;
- the arguments at the crash are PID 1311, signal 6 (SIGABRT), and posix flag 1;
- the syscall returned success (`EAX=0`, carry clear).

Therefore the translated PPC process deliberately requested `kill(self, SIGABRT, 1)`. The unresolved question is **which guest initialization/API path decided to abort**.

The existing Carbon smoke test prints its first program marker only after the window has already been created and shown, so the previous raw log cannot distinguish a pre-`main()` abort from a failure inside one of the early Process Manager/Carbon calls.

This experiment answers that question by building the same small Carbon GUI flow with unbuffered milestone writes before and after each call.

## Prepared files

The runtime repository provides:

```text
tests/ppc-carbon-gui-milestone.c
scripts/build-ppc-carbon-gui-milestone-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-milestone-control.sh
scripts/run-lion-ppc-carbon-gui-milestone-experiment.sh
docs/carbon-gui-milestone-experiment.md
```

No proprietary Apple binary is committed.

## Milestones

The probe writes fixed markers directly to stderr with `write(2)`. It does not depend on stdio buffering for localization.

Important ordered markers include:

```text
M00_MAIN_ENTER
M01_BEFORE_GetCurrentProcess
M02_AFTER_GetCurrentProcess
M03_BEFORE_TransformProcessType
M04_AFTER_TransformProcessType
M05_BEFORE_SetFrontProcess
M06_AFTER_SetFrontProcess
M07_BEFORE_CreateNewWindow
M08_AFTER_CreateNewWindow
M09_BEFORE_CFStringCreateWithCString
M10_AFTER_CFStringCreateWithCString
M11_BEFORE_SetWindowTitleWithCFString
M12_AFTER_SetWindowTitleWithCFString
M13_BEFORE_ShowWindow
M14_AFTER_ShowWindow
M15_BEFORE_SelectWindow
M16_AFTER_SelectWindow
M17_BEFORE_IsWindowVisible
M18_AFTER_IsWindowVisible
M19_BEFORE_NewEventLoopTimerUPP
M20_AFTER_NewEventLoopTimerUPP
M21_BEFORE_InstallEventLoopTimer
M22_AFTER_InstallEventLoopTimer
M25_BEFORE_RunApplicationEventLoop
M23_TIMER_CALLBACK_ENTER
M24_TIMER_CALLBACK_EXIT
M26_AFTER_RunApplicationEventLoop
M27_SUCCESS
```

The numbering around the timer callback is intentionally non-linear in execution order: M25 marks entry into the event loop, then M23/M24 identify the timer callback, followed by M26 after the loop returns.

## Safety constraints

For this experiment:

- do not modify or reinstall XNU;
- do not replace Lion's `/usr/lib/dyld`;
- do not copy any Snow Leopard framework/library into Lion;
- do not rebuild the Rosetta shared cache;
- do not change `DYLD_SHARED_REGION`;
- keep `DYLD_SHARED_CACHE_DONT_VALIDATE=1` for the Lion run;
- do not use live GDB, DTrace, or dtruss;
- do not rerun the original uninstrumented Carbon probe;
- do not test Cocoa or a real-world PPC GUI application;
- run both GUI controls from the logged-in Aqua console user's Terminal session;
- stop after the single Lion milestone run.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU checkout used for the already validated native syscall-295 probe:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild is part of this experiment.

## Phase B — build the milestone PPC subject on Snow Leopard

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-carbon-gui-milestone-on-snowleopard.sh \
  ./ppc-carbon-gui-milestone-private-dyld
```

Expected outputs:

```text
ppc-carbon-gui-milestone-private-dyld
ppc-carbon-gui-milestone-private-dyld.info.txt
ppc-carbon-gui-milestone-private-dyld.sha256
```

The info file must show:

- 32-bit PowerPC Mach-O;
- `LC_LOAD_DYLINKER` = `/usr/oah/dyld`;
- Carbon framework dependency.

Do not modify or rebuild the executable after its checksum sidecar is created.

## Phase C — Snow Leopard positive control

Run from the logged-in Snow Leopard Aqua console user's Terminal:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-milestone-control.sh \
  ./ppc-carbon-gui-milestone-private-dyld \
  ./ppc-carbon-gui-milestone-private-dyld.sha256 \
  ./ppc-carbon-gui-milestone-snowleopard-control.log
```

The same small window should appear for approximately two seconds.

Require:

```text
CARBON_MILESTONE:M00_MAIN_ENTER
...
CARBON_MILESTONE:M27_SUCCESS
RESULT: PASS
```

If the Snow Leopard control does not reach M27 and PASS, stop. Do not transfer this binary to Lion.

## Phase D — transfer exact artifacts to Lion

Transfer privately:

```text
payload/ppc-carbon-gui-milestone-private-dyld
payload/ppc-carbon-gui-milestone-private-dyld.info.txt
payload/ppc-carbon-gui-milestone-private-dyld.sha256
```

Also preserve the Snow Leopard control log.

On Lion verify the executable SHA-256 against the sidecar before proceeding.

## Phase E — re-establish the validated Lion state

Use the same kernel that passed syscall 295, normal PPC exec, CoreFoundation, and the previous Carbon preflight:

```sh
export XNU_SRC=/path/to/xnu-1699.32.7
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export ROSETTA_EXPECTED_KERNEL_SHA256="$(/usr/bin/awk '{print $1}' "$XNU_SRC/mach_kernel.rosetta-syscall295.sha256")"
```

For the current validated system:

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

Stop if the kernel hash, handler, console user, or WindowServer state differs from the prior validated setup.

## Phase F — repeat the two safe native gates

From the runtime checkout:

```sh
./scripts/run-lion-commpage-probe.sh ./lion-commpage-probe
```

Require its existing PASS.

Then:

```sh
cd "$XNU_SRC"
/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$XNU_SRC/syscall295-probe-carbon-milestone-preflight.log"
```

Require:

```text
RESULT: PASS - syscall 295 reached the compatibility front-end and returned EBADF
RESULT: PASS
```

Do not execute the PPC milestone subject if either gate fails.

## Phase G — run the guarded Lion milestone experiment

Return to the runtime checkout:

```sh
cd /path/to/lion-rosetta-runtime
```

Run:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-carbon-gui-milestone-experiment.sh \
  ./payload/ppc-carbon-gui-milestone-private-dyld \
  ./payload/ppc-carbon-gui-milestone-private-dyld.sha256
```

The runner keeps the same validated Lion runtime conditions:

```text
DYLD_SHARED_CACHE_DONT_VALIDATE=1
DYLD_PRINT_LIBRARIES=1
```

It writes:

```text
payload/lion-ppc-carbon-gui-milestone-experiment.log
payload/lion-ppc-carbon-gui-milestone.raw.log
```

The report also records:

```text
furthest_carbon_milestone=...
```

and captures every new crash/core file created during the run.

## Phase H — stop and preserve evidence

Stop after the single Lion milestone run, regardless of outcome.

Preserve:

```text
ppc-carbon-gui-milestone-private-dyld.info.txt
ppc-carbon-gui-milestone-private-dyld.sha256
ppc-carbon-gui-milestone-snowleopard-control.log
syscall295-probe-carbon-milestone-preflight.log
payload/lion-ppc-carbon-gui-milestone-experiment.log
payload/lion-ppc-carbon-gui-milestone.raw.log
```

Also preserve every new crash report/core listed by the runner.

Do not modify frameworks, Rosetta, or XNU after the run.

## Result interpretation

### PRE_MAIN_FAILURE

If no M00 marker appears, the abort occurs before `main()`, during image/framework initialization. The next analysis should focus on initialization order rather than any explicit Carbon call in the test program.

### Localized API boundary

If a `BEFORE_` marker appears without its corresponding `AFTER_` marker, that API call is the immediate observed boundary. Preserve the new non-debugged diagnostic before considering any runtime change.

Examples:

- M01 with no M02: `GetCurrentProcess`;
- M03 with no M04: `TransformProcessType`;
- M05 with no M06: `SetFrontProcess`;
- M07 with no M08: `CreateNewWindow`;
- M13 with no M14: `ShowWindow`.

### PASS

If M27 is reached with exit status 0, instrumentation changed the timing enough that the previous abort did not recur. Preserve that result; do not infer that the original problem has disappeared. A repeat/control decision will be made from the logs.

## What to return for review

Return:

```text
ppc-carbon-gui-milestone-private-dyld.info.txt
ppc-carbon-gui-milestone-private-dyld.sha256
ppc-carbon-gui-milestone-snowleopard-control.log
syscall295-probe-carbon-milestone-preflight.log
lion-ppc-carbon-gui-milestone-experiment.log
lion-ppc-carbon-gui-milestone.raw.log
```

Return every new crash report/core file explicitly listed by the runner.

Also state whether the milestone window was visually observed on Snow Leopard and Lion.

## Non-goals

This experiment does not repair the Carbon failure. It only identifies the first guest-side stage that precedes the deliberate self-SIGABRT.


## Observed Lion result: GetCurrentProcess boundary

The milestone experiment completed its Snow Leopard positive control successfully. The exact executable SHA-256 was:

```text
a1aea9b492df8185c237acd4414c9be08a562e956c83e4ab43a07387af31b3dd
```

On Snow Leopard, the probe reached every milestone through `M27_SUCCESS`, displayed the Carbon window, and exited 0.

On Lion, all kernel/runtime preflights and hashes remained at the validated values. The process reached:

```text
CARBON_MILESTONE:M00_MAIN_ENTER
CARBON_MILESTONE:M01_BEFORE_GetCurrentProcess
```

and then terminated with SIGABRT/status 134. `M02_AFTER_GetCurrentProcess` was never reached, and no window appeared.

The new crash report repeats the previously decoded guest self-SIGABRT pattern at Rosetta's host syscall wrapper. Therefore the immediate observed Carbon boundary is now `GetCurrentProcess`, not pre-main framework initialization.

This result does not justify another XNU change. The next controlled variable is launch context: package a near-identical milestone executable as a real application bundle and launch it through LaunchServices. Follow `docs/carbon-launchservices-experiment.md`.


## Current-path note after Process Manager restoration

The historical Lion localization in this document stopped at `GetCurrentProcess` before window creation. That boundary is now closed under the accepted registration/session/CoreGraphics/SetFront compatibility stack: `GetCurrentProcess` returns success and the exact expected PSN with `LSDONOTABORTIFNOASN` unset.

Do not rerun this older milestone subject as the current gate. The authoritative next procedure is `docs/process-manager-createwindow-validation-experiment.md`, which preserves the complete restored stack and advances only through `CreateNewWindow` plus immediate `DisposeWindow`, stopping before show/select/visibility and event-loop work.
