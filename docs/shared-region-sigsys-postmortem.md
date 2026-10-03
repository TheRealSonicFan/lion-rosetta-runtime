# Rosetta SIGSYS shared-region postmortem

## Purpose

The cache-validation-bypass experiment moved Rosetta past the stale Snow Leopard shared-cache rejection. The direct translator reported the PPC subject as loaded and then terminated with status 140. The matching Lion crash report records:

- `EXC_CRASH (SIGSYS)`;
- crashed x86 thread EIP `0xb815ac07`;
- `EAX=0x0000004e`;
- EFLAGS `0x00000247`, whose carry bit is set.

The carry flag plus `EAX=0x4e` is consistent with an i386 Darwin system-call error return. Darwin `ENOSYS` is decimal 78 (`0x4e`).

Public source comparison gives a specific candidate:

- Snow Leopard-era dyld's split-segment helper calls `syscall(295, fd, count, mappings)` for `shared_region_map_np`.
- Snow Leopard XNU exposes syscall 295 as `shared_region_map_np`.
- Lion exposes syscall 295 as `nosys`, annotated `old shared_region_map_np`.
- XNU `nosys` sends `SIGSYS` and returns `ENOSYS`.

This is strong evidence for a retired shared-region syscall ABI, but it is not yet sufficient justification to patch Lion. The next step is read-only postmortem confirmation from the preserved non-debugged core.

## Safety constraints

For this step:

- do not rerun Rosetta;
- do not attach GDB to a live `translate` process;
- do not modify XNU;
- do not install a private `libgcc_s.1.dylib`;
- do not rebuild or replace any dyld shared cache;
- do not modify Lion's `/usr/lib`;
- preserve `/cores/core.1090`.

The analysis uses Apple GDB only against the existing core file. Rosetta's `PT_DENY_ATTACH` behavior is therefore not involved.

## Prepared collector

The runtime repository provides:

```
scripts/collect-lion-shared-region-sigsys-core.sh
```

The collector is intentionally read-only. It verifies:

- Mac OS X 10.7.5;
- the preserved core exists;
- the installed Snow Leopard `translate` SHA-256 is the validated value.

It then opens the core postmortem with Apple GDB and records:

- registers;
- backtrace;
- runtime-decrypted instructions at and around `0xb815ac07`;
- raw instruction bytes around the crash site;
- a caller-frame instruction window;
- stack/frame words for call-site reconstruction.

It also extracts only a 256-byte runtime-decrypted code window around the crash. The small binary remains under ignored `payload/` and must not be committed.

The default core is:

```
/cores/core.1090
```

The default outputs are:

```
payload/lion-shared-region-sigsys-core.txt
payload/lion-shared-region-sigsys-window.bin
payload/lion-shared-region-sigsys-window.bin.sha256
```

Because the new collector is a repository text file and executable mode is not assumed by the runbook, invoke it through `/bin/bash`.

## Confirmation criteria

The postmortem result is sufficient to proceed toward an XNU compatibility design only if the runtime-decrypted instruction context is consistent with a failed Unix system-call return and the surrounding call state can be reconciled with the legacy shared-region path.

The strongest confirming pattern would be:

1. the crash EIP is immediately after, or in the error path following, the host syscall transition;
2. the returned state preserves `EAX=ENOSYS (78)` with carry set;
3. nearby code/call state identifies the operation as the guest dyld shared-region mapping path;
4. there is no earlier new failure that better explains the SIGSYS.

If the code window does not support that chain, stop and analyze the actual call site before proposing a kernel change.

## Decision after confirmation

If the core confirms syscall 295 as the failing boundary, the following engineering phase will be a **minimal Lion XNU compatibility restoration for the old `shared_region_map_np` ABI**.

That phase should not blindly import Snow Leopard's entire implementation. The preferred design is to restore the old syscall entry only for compatibility and adapt its old three-argument mapping description to Lion's existing shared-region machinery while retaining Lion's native interfaces and behavior for normal processes. The implementation must be source-reviewed against both XNU 1504.15.3 and XNU 1699.32.7 before a patch is generated.

No such kernel patch is part of the present postmortem step.
