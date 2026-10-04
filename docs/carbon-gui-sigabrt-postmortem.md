# Carbon GUI SIGABRT postmortem

## Objective

Analyze the preserved non-debugged Lion core from the first PPC Carbon GUI experiment before changing the kernel, Rosetta runtime, frameworks, dyld cache, or test program.

The Carbon GUI experiment is a controlled cross-system differential:

- the exact executable SHA-256 is `fe2ddc8e76e996c242facd60e56aa2203ffc762dec941fc6b1bbf0fe25613067`;
- Snow Leopard 10.6.8 runs that exact executable successfully, displays the Carbon window, runs the event loop, and exits 0;
- Lion 10.7.5 uses the same executable, private dyld, Rosetta cache identity, and already validated syscall-295 kernel;
- Lion loads the Carbon/ApplicationServices dependency graph but terminates before either Carbon program marker is printed;
- Lion exits 134 and writes a non-debugged core plus crash report.

The purpose of this step is to determine **who deliberately raised SIGABRT and from which translated/guest path**. It is not yet a framework-copy or XNU-patching step.

## Current evidence

The Lion crash report records:

- process ID 1311;
- `EXC_CRASH (SIGABRT)`;
- x86 crash EIP `0xb815ac07`, the same Rosetta host syscall-wrapper area previously seen in the syscall-295 investigation;
- `EAX=0`;
- EFLAGS `0x246`, with carry clear;
- `EDI=0x51f` (decimal 1311, the process PID);
- `ESI=6` (the Darwin signal number for SIGABRT);
- direct caller `0xb8179fb4`.

That register pattern is strongly consistent with a successful signal-delivery syscall targeting the process itself, but the crash report alone does not prove the syscall number or the guest-side caller. The preserved core is required to reconstruct the actual call site.

The library trace is also useful but not yet causal. Lion reaches `/usr/lib/libsasl2.2.dylib` and then aborts. The Snow Leopard control continues by loading several CoreGraphics/ATS resource libraries before the probe reaches its window marker. This narrows the timing but does not establish which initializer or Carbon API triggered the abort.

## Safety constraints

For this step:

- do not rerun the Carbon GUI probe;
- do not rebuild or instrument the PPC probe yet;
- do not attach GDB to a live Rosetta process;
- do not use dtruss or DTrace;
- do not modify XNU;
- do not copy Snow Leopard frameworks or libraries to Lion;
- do not rebuild a dyld cache;
- do not alter `/usr/oah/dyld`;
- preserve `/cores/core.1311` unchanged;
- do not commit any extracted runtime window from `payload/`.

This step uses Apple GDB only in postmortem mode against the existing core.

## Prepared collector

The runtime repository provides:

```text
scripts/collect-lion-carbon-sigabrt-core.sh
```

The collector verifies Lion 10.7.5, the preserved core, Apple GDB, and the validated Rosetta translator SHA-256.

It records:

- complete x86 register state;
- backtrace;
- runtime-decrypted instructions around the common syscall wrapper at `0xb815ac07`;
- a wider instruction window around direct caller `0xb8179fb4`;
- an additional window around frame 2 at `0xb80c6b13`;
- further caller-frame disassembly;
- stack and frame words;
- raw instruction bytes.

It extracts three small runtime-decrypted binary windows under ignored `payload/`:

```text
payload/lion-carbon-sigabrt-wrapper-window.bin
payload/lion-carbon-sigabrt-caller-window.bin
payload/lion-carbon-sigabrt-frame2-window.bin
```

with SHA-256 sidecars.

## Exact procedure

Perform this on the Lion 10.7.5 machine from the runtime checkout.

### 1. Update the runtime repository

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm these files exist:

```text
docs/carbon-gui-sigabrt-postmortem.md
scripts/collect-lion-carbon-sigabrt-core.sh
```

### 2. Confirm the preserved core

```sh
ls -lh /cores/core.1311
```

Do not rename, move, compress, or modify it.

### 3. Run the read-only postmortem collector

```sh
/bin/bash ./scripts/collect-lion-carbon-sigabrt-core.sh
```

The collector does not launch Rosetta.

### 4. Confirm all outputs

Expected:

```text
payload/lion-carbon-sigabrt-core.txt

payload/lion-carbon-sigabrt-wrapper-window.bin
payload/lion-carbon-sigabrt-wrapper-window.bin.sha256

payload/lion-carbon-sigabrt-caller-window.bin
payload/lion-carbon-sigabrt-caller-window.bin.sha256

payload/lion-carbon-sigabrt-frame2-window.bin
payload/lion-carbon-sigabrt-frame2-window.bin.sha256
```

Verify:

```sh
ls -lh \
  ./payload/lion-carbon-sigabrt-core.txt \
  ./payload/lion-carbon-sigabrt-wrapper-window.bin \
  ./payload/lion-carbon-sigabrt-caller-window.bin \
  ./payload/lion-carbon-sigabrt-frame2-window.bin

cat ./payload/lion-carbon-sigabrt-wrapper-window.bin.sha256
cat ./payload/lion-carbon-sigabrt-caller-window.bin.sha256
cat ./payload/lion-carbon-sigabrt-frame2-window.bin.sha256
```

The expected binary sizes are:

- wrapper window: 256 bytes;
- direct-caller window: 512 bytes;
- frame-2 window: 384 bytes.

### 5. Stop after collection

Do not run the Carbon GUI probe again and do not start another framework experiment.

Preserve `/cores/core.1311` plus every generated postmortem artifact.

## What will be determined from the output

The first decision is whether the SIGABRT is a deliberate self-signal issued through Rosetta's host syscall path.

The expected confirming evidence would be:

1. the wrapper at `0xb815ac07` is immediately after the host syscall transition;
2. the caller supplies the signal-delivery syscall number and arguments matching PID 1311 / signal 6;
3. the syscall returned success rather than an error;
4. the caller chain can be related to a guest PPC abort/fatal path.

If those points are not supported, the actual instruction path takes precedence and no self-signal conclusion should be retained.

The second decision is whether the available call state identifies the guest subsystem responsible for the abort. If the postmortem does not resolve that far, the next experiment will be a **milestone-instrumented version of the same Carbon probe** that prints and flushes markers before and after each Carbon/Process Manager call. That experiment will be prepared only after reviewing this core evidence.

## Non-goals

This postmortem step does not:

- claim that ApplicationServices, HIToolbox, CoreGraphics, ATS, or LaunchServices is the cause;
- copy any framework from Snow Leopard;
- modify the Rosetta shims;
- change the kernel;
- rerun the failing process;
- test Cocoa;
- test a real-world PPC application.

It is a read-only localization step.


## Observed postmortem result: guest syscall 37 self-SIGABRT

The read-only collector completed successfully against the preserved non-debugged `/cores/core.1311`. All three GDB collection passes returned status 0.

The extracted runtime-decrypted binary windows were internally consistent with their SHA-256 sidecars:

```text
wrapper: e884a4964e83de18569bc67beb1461c1169d62717f99683fc1ba62dda585ad37
caller:  90cacec6dbac8900998e078ca03a2e96746e506e747deb55b0eaffc3e37a4341
frame2:  0178da0e4cbe240bf4ae41d3dc357222bf5e328ff0864acfc3c9f1d2ce8eb00b
```

The host syscall sequence is now resolved mechanically:

1. The Rosetta wrapper around `0xb815abe8` moves its final argument into `EAX` and executes `int $0x80`.
2. The direct caller at `0xb8179f8e` places `0x25` in that syscall-number slot.
3. `0x25` is decimal 37. Both Snow Leopard and Lion XNU define syscall 37 as `kill(int pid, int signum, int posix)`.
4. The wrapper arguments in the preserved frame are PID `0x51f` (1311), signal `6` (SIGABRT), and posix flag `1`.
5. At the crash EIP, `EAX=0` and the carry flag is clear, so the host `kill()` syscall itself succeeded.

Therefore Rosetta is not aborting because Lion rejected another host syscall. It is faithfully executing a **guest-requested self-SIGABRT**.

This closes the immediate host-kernel syscall question. The remaining problem is guest-side localization: the current core does not identify which PPC framework initializer or which early Process Manager/Carbon API path decided to call `kill(self, SIGABRT)`.

The next controlled step is therefore the milestone-instrumented Carbon experiment in `docs/carbon-gui-milestone-experiment.md`. It prints unbuffered markers at `main()` entry and immediately before/after every early Carbon/Process Manager call while keeping all kernel/runtime conditions unchanged.

Do not create another XNU patch, copy frameworks, or alter the Rosetta cache before that milestone result is reviewed.
