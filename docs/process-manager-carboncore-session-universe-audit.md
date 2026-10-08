# Process Manager CarbonCore session-universe differential audit

## Objective

Localize the new failure exposed by the post-dispatch `GetProcessForPID` postmortem before any further behavior-changing experiment.

The preserved Lion core proves that the failure is **not** the historical guest-requested no-ASN SIGABRT. The process dies with a protected-zero-page access while `GetProcessForPID` is inside the CarbonCore filesystem/session-universe path reached from LaunchServices application check-in.

The next step is therefore a read-only Snow Leopard/Lion differential audit of the exact CarbonCore functions on the preserved PPC stack.

## Evidence established by the postmortem

The collector completed with `RESULT: PASS` and verified the 512-byte crash window.

The Lion crash report records:

```text
Exception Type:  EXC_BAD_ACCESS (SIGBUS)
Exception Codes: KERN_PROTECTION_FAILURE at 0x000000000000003c
```

The PPC stack is:

```text
GetProcessForPID
  -> __RegisterApplication
  -> __LSApplicationCheckIn
  -> __CSCheckFix
  -> _GetBugsForOurBundleIDFromCoreservicesd
  -> __CFBundleCopyInfoDictionaryInResourceForkWithAllocator
  -> _CFURLGetFSRef
  -> __CFGetFSRefFromURL
  -> FSPathMakeRefInternal
  -> PathGetObjectInfo
  -> FSMount::FSMount
  -> _FileIDTreeGetVRefNumForDevice
  -> _FSNodeStorageGetAndLockCurrentUniverse
  -> __SCSessionUniverseByUIDAcquireAndLock
  -> protected-zero-page fault
```

The PPC state at the fault includes:

```text
r3  = 0x0000003c
r9  = 0x4d555458
r10 = 0xd0feffff
r29 = 0x00009103
```

The postmortem's Rosetta host instruction at `0xb80c5d10` performs a memory load from host `EDI`, and `EDI=0x3c`, matching the protected fault address.

The value `0xd0feffff`, when byte-swapped as a PPC-visible 32-bit value, becomes:

```text
0xfffffed0 = -304 = MIG_BAD_ARGUMENTS
```

That is a useful protocol clue but **not yet causal proof**. The register may be stale or may belong to a different sub-operation. The next audit must establish whether the session-universe path actually issues or consumes a MIG/CoreServices transaction whose error handling can leave the pointer/state used at the fault invalid.

The crash-window SHA-256 is:

```text
6e1ccbb59f4a75bf57abc7ccf3fdb74d92927741e736274d00011615e75bbd70
```

## Why the no-ASN override is not the next step

The previous historical Process Manager crashes were `EXC_CRASH (SIGABRT)` caused by a guest-requested `kill(self, SIGABRT, 1)`.

This crash is instead `EXC_BAD_ACCESS (SIGBUS)` at `0x3c`, with a concrete CarbonCore stack below `__LSApplicationCheckIn`.

Therefore:

- do not set `LSDONOTABORTIFNOASN=0`;
- do not suppress `abort`;
- do not rerun `GetProcessForPID`;
- do not infer that the HIServices no-ASN branch has been reached.

The current boundary is the CarbonCore session-universe/filesystem support path invoked during LaunchServices check-in.

## Prepared tooling

Current runtime `main` provides:

```text
scripts/audit-process-manager-carboncore-session-universe.py
docs/process-manager-carboncore-session-universe-audit.md
```

The analyzer is Python-2-compatible and read-only. It records:

- OS/build and PowerPC architecture-handler state;
- Rosetta shared-cache/map identities and CarbonCore cache-map membership;
- CarbonCore full-file and architecture-slice identities;
- Snow Leopard PPC and native architecture windows, and Lion native architecture windows, for:
  - `__SCSessionUniverseByUIDAcquireAndLock`;
  - `_FSNodeStorageGetAndLockCurrentUniverse`;
  - `_FileIDTreeGetVRefNumForDevice`;
  - `FSMount`;
  - `PathGetObjectInfo`;
  - `FSPathMakeRefInternal`;
  - `_GetBugsForOurBundleIDFromCoreservicesd`;
  - `__CSCheckFix`;
- related CarbonCore imports/symbols involving:
  - `SCSession` / client/server session objects;
  - Mach/MIG helpers;
  - bootstrap helpers;
  - session/UID helpers;
  - mutex/locking helpers;
- relevant CarbonCore cstrings;
- a best-effort coreservicesd symbol/import inventory for the same families;
- the observed Lion postmortem constants, including the `0x3c`, `MUTX`, and possible `MIG_BAD_ARGUMENTS` clue.

The analyzer does not invoke any of those private functions.

On Snow Leopard, the PPC crash-path symbols are required as a tooling/provenance gate because that is the code family actually executed by Rosetta. On Lion, the native i386 slice must be readable and disassemblable, but the exact Snow Leopard symbol names are **not** required to exist: disappearance or renaming of that session-universe path is itself potentially meaningful semantic evidence rather than a tooling failure.

## Safety constraints

For this stage:

- do not launch the PPC subject;
- do not rerun the no-ASN discriminator;
- do not set `LSDONOTABORTIFNOASN`;
- do not call any private CarbonCore session-universe function;
- do not send a custom Mach/MIG request;
- do not patch CarbonCore, LaunchServices, HIServices, CoreFoundation, coreservicesd, or Security;
- do not alter the Rosetta shared cache;
- do not restart or signal coreservicesd, WindowServer, pbs, or launchd;
- do not modify XNU;
- do not use live GDB, DTrace, or dtruss.

This is static/read-only evidence collection only.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion, update the XNU checkout for documentation consistency:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

No kernel rebuild or reboot is part of this stage.

## Phase B — Snow Leopard audit

On validated Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-carboncore-session-universe.py \
  ./process-manager-carboncore-session-universe-snowleopard.txt
```

Require:

```text
Created: ./process-manager-carboncore-session-universe-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return that report unchanged. Do not run the Lion audit until the tooling issue is reviewed.

## Phase C — Lion audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-carboncore-session-universe.py \
  ./payload/process-manager-carboncore-session-universe-lion.txt
```

Require:

```text
Created: ./payload/process-manager-carboncore-session-universe-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If it fails, stop. Do not compensate by rerunning the PPC subject.

## Phase D — return evidence

Return exactly:

```text
process-manager-carboncore-session-universe-snowleopard.txt
process-manager-carboncore-session-universe-lion.txt
```

Keep the completed postmortem files available but do not rerun the core collector unless requested.

## Decision gate

### A. Snow PPC session-universe client has a legacy Mach/MIG contract absent or changed on Lion

If the audited PPC path shows a concrete request/reply contract or state transition that is not compatible with Lion's native path, localize that exact transaction before writing any compatibility code.

A later adapter must target only that transaction/state boundary.

### B. The protocol is aligned but error handling differs

If both releases use the same underlying operation but Snow PPC assumes state that Lion does not establish, identify the first divergent return/state transition. The possible `MIG_BAD_ARGUMENTS` register value becomes relevant only if the disassembly proves that it is live on the fault path.

### C. The fault is purely local CarbonCore state initialization

If no external transaction is involved and the old PPC code dereferences an uninitialized local/session-universe object on Lion, the next experiment should instrument or adapt only the state-creation boundary, not Process Manager or LaunchServices globally.

### D. Static evidence is still insufficient

Only then prepare a minimal diagnostic around the exact session-universe call boundary. Do not use the no-ASN override as a substitute for understanding this SIGBUS.

## Current boundary

```text
syscall 295 compatibility -> PASS
CoreServices bootstrap adaptation -> PASS
CoreServices ServerCheckin adaptation -> PASS
SessionGetInfo AuditInfo API adaptation -> PASS
InitializeProcessesServices wire transaction -> PASS
real LaunchServices process-dispatch setup -> PASS
GetProcessForPID entered after proven dispatch setup -> YES
historical no-ASN SIGABRT -> NOT THIS FAILURE
CarbonCore __SCSessionUniverseByUIDAcquireAndLock path -> SIGBUS at 0x3c
session-universe protocol/state differential -> next proof
```

No additional XNU change is indicated.
