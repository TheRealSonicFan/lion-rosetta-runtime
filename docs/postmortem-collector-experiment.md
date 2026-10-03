# Postmortem collector experiment

## Objective

Confirm the cause of the Lion Rosetta cache-bypass `SIGSYS` using the already-preserved non-debugged core dump, without rerunning Rosetta and without modifying the kernel or runtime.

The current evidence is:

- the cache-validation-bypass run removed the stale Rosetta-cache rejection;
- guest dyld reported the PPC subject as loaded;
- `translate` then terminated with status 140;
- the crash report records `EXC_CRASH (SIGSYS)`;
- the crashed x86 thread has `EIP=0xb815ac07`, `EAX=0x0000004e`, and EFLAGS `0x00000247` with carry set;
- public source comparison makes retired syscall 295, `shared_region_map_np`, the leading explanation.

This experiment does not patch XNU. Its only purpose is to collect the runtime-decrypted instruction and call-state evidence needed to confirm or reject that explanation.

## Safety rules

For this experiment:

- do not rerun `/usr/libexec/oah/translate`;
- do not run the PPC smoke test;
- do not attach GDB to a live `translate` process;
- do not modify XNU or install another kernel;
- do not install a PPC `libgcc_s.1.dylib`;
- do not rebuild or replace any dyld shared cache;
- do not modify Lion's `/usr/lib`;
- do not delete, move, or overwrite `/cores/core.1090`;
- do not commit any generated `payload/` artifact.

Apple GDB is used only in postmortem mode against the existing core. Rosetta's live `PT_DENY_ATTACH` behavior is therefore not involved.

## Prepared collector

The repository provides:

```text
scripts/collect-lion-shared-region-sigsys-core.sh
```

The collector verifies:

- Mac OS X 10.7.5;
- Apple GDB exists;
- the preserved core exists;
- the installed Snow Leopard Rosetta `translate` has the validated SHA-256.

It then records:

- complete x86 register state;
- backtrace;
- instructions beginning at the crash EIP;
- a wider runtime-decrypted instruction window;
- raw bytes around the crash site;
- caller-frame instructions;
- stack and frame words.

It also extracts a 256-byte runtime-decrypted code window around the crash site. The binary stays under ignored `payload/`.

## Exact procedure

Perform these steps on the Lion 10.7.5 machine from the `lion-rosetta-runtime` checkout.

### 1. Update the repository

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

The checkout must contain:

```text
docs/postmortem-collector-experiment.md
scripts/collect-lion-shared-region-sigsys-core.sh
```

### 2. Confirm the preserved core is still present

```sh
ls -lh /cores/core.1090
```

Do not rename, move, compress, or modify the core before collection.

### 3. Run the postmortem collector

Invoke the script through `/bin/bash`; executable mode is not required:

```sh
/bin/bash ./scripts/collect-lion-shared-region-sigsys-core.sh
```

The default input is:

```text
/cores/core.1090
```

No Rosetta process is launched by this script.

### 4. Confirm the collector produced all three outputs

Expected files:

```text
payload/lion-shared-region-sigsys-core.txt
payload/lion-shared-region-sigsys-window.bin
payload/lion-shared-region-sigsys-window.bin.sha256
```

Verify them:

```sh
ls -lh \
  ./payload/lion-shared-region-sigsys-core.txt \
  ./payload/lion-shared-region-sigsys-window.bin \
  ./payload/lion-shared-region-sigsys-window.bin.sha256

cat ./payload/lion-shared-region-sigsys-window.bin.sha256
```

The binary window must be exactly 256 bytes. The collector checks this itself and stops if the size is unexpected.

### 5. Stop after collection

Do not run any further Rosetta, dyld, library, cache, or kernel experiment after this collector completes.

Preserve:

```text
/cores/core.1090
payload/lion-shared-region-sigsys-core.txt
payload/lion-shared-region-sigsys-window.bin
payload/lion-shared-region-sigsys-window.bin.sha256
```

For analysis, share only the three generated `payload/` files first. The full core should remain on the Lion machine unless a later analysis step specifically requires another extraction.

## Failure handling

If the collector stops with an error, do not improvise another GDB command or rerun Rosetta.

Preserve the generated text report if one exists and record the exact terminal output. The likely failure classes are:

- the preserved core is missing;
- the installed translator hash differs from the validated Snow Leopard binary;
- Apple GDB cannot read the core;
- the expected crash EIP is not present;
- the 256-byte runtime window cannot be extracted.

Any of those conditions should be resolved before continuing.

## What will be tested from the outputs

The collected evidence will be considered sufficient to move toward an XNU compatibility design only if it confirms a coherent failed Unix-syscall return path around `0xb815ac07`.

The expected confirming evidence is:

1. the runtime-decrypted instruction sequence is consistent with returning from, or handling the error from, a syscall transition;
2. the preserved state shows `EAX=ENOSYS (78 / 0x4e)` with the carry flag set;
3. the nearby caller/call-state can be reconciled with the guest dyld shared-region mapping path;
4. there is no earlier failure that explains the `SIGSYS` more directly.

If those points are confirmed, the following phase will be source design for a minimal Lion XNU compatibility restoration of the old syscall-295 `shared_region_map_np` ABI.

If they are not confirmed, no syscall-295 patch should be created yet.

## Explicit non-goals

This experiment does not:

- modify syscall 295;
- port Snow Leopard's entire shared-region implementation;
- add guest libraries;
- fix the normal PPC exec path;
- change the private dyld experiment;
- rebuild a kernel;
- prove that every later Rosetta dependency is satisfied.

It is a read-only evidence-collection step only.
