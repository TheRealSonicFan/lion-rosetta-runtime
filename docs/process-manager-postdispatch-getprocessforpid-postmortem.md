# Process Manager post-dispatch GetProcessForPID postmortem

## Objective

Analyze the preserved Lion crash/core from the first `GetProcessForPID(getpid(), &psn)` call made **after** the real Snow Leopard PPC LaunchServices process-dispatch setup had already succeeded in the same process.

Do not rerun the PPC subject and do not enable `LSDONOTABORTIFNOASN` yet.

The immediate question is now narrower than before: determine the actual termination signal and Rosetta host-side call state for the failure that occurred after:

```text
getProcessDispatchTable() -> nonzero
getProcessesServerPort()  -> nonzero
GetProcessForPID          -> entered
```

but before `GetProcessForPID` returned.

## Evidence entering this stage

The Snow Leopard 10.6.8 positive control completed the same sequence and returned:

```text
dispatch table = 0xa0bbf59c
server port    = 0x00002003
GetProcessForPID status = 0
PSN high       = 0x00000000
PSN low        = 0x0008f08f
RESULT         = PASS
```

It also continued far enough inside the identity path to perform a non-target distributed-notifications bootstrap lookup and a second Security `SessionGetInfo` call for the concrete session ID.

The Lion 10.7.5 run first re-proved every prerequisite:

```text
CoreServices bootstrap adapter            = PASS
CoreServices ServerCheckin adapter         = PASS
Security SessionGetInfo AuditInfo adapter  = PASS
dispatch table                             = 0xa0bbf59c
process-services port                      = 0x00009103
LSDONOTABORTIFNOASN                        = unset
```

It then reached:

```text
PM_POSTDISPATCH_MILESTONE:M05_BEFORE_GetProcessForPID
```

and never reached the after-return marker. The runner recorded process exit status `138` and produced:

```text
/Users/Andy/Library/Logs/DiagnosticReports/ppc-process-manager-postdispatch-getprocessforpid-private-dyld_2026-10-08-034514_Andys-Mac.crash
/cores/core.17940
```

All protected hashes remained unchanged and syscall 295 still passed with EBADF/no SIGSYS.

## Why a postmortem is required before the no-ASN override

The historical Process Manager failures were proven `EXC_CRASH (SIGABRT)` / guest-requested `kill(self, SIGABRT, 1)` paths.

This new run was labeled `POSTDISPATCH_GETPROCESSFORPID_ABORT_BEFORE_RETURN` by the first version of the runner solely because the call never returned. That label was too coarse: the runner did not inspect the crash signal, and the observed exit status is `138`, not the historical `134` used by the confirmed SIGABRT cases.

Therefore do **not** infer that the later HIServices no-ASN abort has been reached merely from the old result label.

Current `main` corrects future runner classification:

- exit status 134 before return -> `POSTDISPATCH_GETPROCESSFORPID_SIGABRT_BEFORE_RETURN`;
- any other non-returning status -> `POSTDISPATCH_GETPROCESSFORPID_TERMINATED_BEFORE_RETURN exit_status=...`.

The current preserved crash/core must decide which path actually occurred.

## Prepared collector

Current runtime `main` provides:

```text
scripts/collect-lion-postdispatch-getprocessforpid-core.sh
docs/process-manager-postdispatch-getprocessforpid-postmortem.md
```

The collector is read-only. It:

- verifies Lion 10.7.5;
- verifies the validated Rosetta translator SHA-256;
- opens only the preserved core with Apple GDB in postmortem mode;
- records complete x86 register state and backtraces;
- records instructions and bytes around the actual core `EIP` without assuming the historical Rosetta syscall-wrapper address;
- records stack/frame memory;
- embeds the preserved crash report in the text output;
- extracts one 512-byte runtime window centered on the actual crash `EIP`;
- does not attach to a live process or modify any system file.

## Safety constraints

- do not rerun the post-dispatch PPC subject;
- do not set `LSDONOTABORTIFNOASN=0`;
- do not run the older no-ASN bundle discriminator again;
- do not interpose or suppress `abort`;
- do not patch HIServices, LaunchServices, CoreServices, Security, coreservicesd, Rosetta, dyld, the cache, or XNU;
- do not restart daemons;
- do not attach GDB to a live process;
- do not use DTrace/dtruss;
- preserve the existing crash report and `/cores/core.17940`.

## Phase A — update the runtime repository

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

No Snow Leopard action, kernel rebuild, or reboot is required for this read-only stage.

## Phase B — confirm the preserved evidence

```sh
ls -lh \
  /cores/core.17940 \
  "$HOME/Library/Logs/DiagnosticReports/ppc-process-manager-postdispatch-getprocessforpid-private-dyld_2026-10-08-034514_Andys-Mac.crash"
```

If either file is missing, stop. Do not rerun the PPC subject to recreate it.

## Phase C — run the read-only postmortem collector

```sh
/bin/bash ./scripts/collect-lion-postdispatch-getprocessforpid-core.sh \
  /cores/core.17940 \
  "$HOME/Library/Logs/DiagnosticReports/ppc-process-manager-postdispatch-getprocessforpid-private-dyld_2026-10-08-034514_Andys-Mac.crash" \
  ./payload/lion-postdispatch-getprocessforpid-postmortem.txt
```

Require:

```text
Created:
  .../lion-postdispatch-getprocessforpid-postmortem.txt
  .../lion-postdispatch-getprocessforpid-crash-window.bin
  .../lion-postdispatch-getprocessforpid-crash-window.bin.sha256
No live process was attached and no system file was modified.
RESULT: PASS
```

If the collector fails, preserve its text report and stop.

## Phase D — return evidence

Return:

```text
lion-postdispatch-getprocessforpid-postmortem.txt
lion-postdispatch-getprocessforpid-crash-window.bin
lion-postdispatch-getprocessforpid-crash-window.bin.sha256
```

Do not upload the entire core unless specifically requested after the collector output is reviewed.

## Decision gate

### Confirmed guest-requested SIGABRT

If the crash report/core proves the same guest-requested SIGABRT family as the historical Process Manager failures, the earlier LaunchServices dispatch-table abort is already excluded by the same-process nonzero table/port markers.

Only then does the next controlled behavior test become the exact process-local:

```text
LSDONOTABORTIFNOASN=0
```

repeat of this **post-dispatch** probe. That future discriminator must keep both proven compatibility adapters active and stop immediately after the one `GetProcessForPID` result.

### Different signal or different Rosetta host path

If the current failure is SIGBUS, SIGSEGV, SIGILL, or another non-SIGABRT path, do not apply the no-ASN override. The crash PC, caller state, and stack become the next boundary.

### Core/crash mismatch or unreadable evidence

Treat this as an evidence/provenance problem. Do not rerun the PPC subject merely to obtain a cleaner crash.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo API adaptation -> PASS
InitializeProcessesServices wire transaction -> PASS
real LaunchServices process-dispatch setup -> PASS
GetProcessForPID entered after proven dispatch setup -> TERMINATED before return
actual termination signal/call path -> next proof
```

No additional XNU change is indicated.
