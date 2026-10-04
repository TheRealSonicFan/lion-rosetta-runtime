# LaunchServices PPC gate callsite audit

## Objective

Resolve the exact i386 LaunchServices function and branch that returns `kLSNoRosettaEnvironmentErr (-10665)` on Lion, and compare it directly with Snow Leopard's Rosetta-aware path.

The first static audit established an important structural result but also exposed two limitations in the original analyzer:

1. several target symbol names were written with one leading underscore instead of the two-character Mach-O symbol spelling reported by Apple `nm`, so the report incorrectly printed `symbol=ABSENT` for functions that were visibly present in the symbol table;
2. the broad textual search for `d657` also matched instruction addresses ending in those digits, producing irrelevant disassembly contexts.

The current evidence that remains valid is:

- Snow Leopard LaunchServices contains explicit `_LSAppMeetsRosettaRequirement` logic and one real `-10665` return path that calls it immediately before deciding whether to continue;
- Lion LaunchServices contains exactly one raw `-10665` value in its i386 slice and an instruction that computes a return value from `0xffffd657`, but the enclosing function and tested flag were not named by the first report;
- `coreservicesd`, `lsregister`, and `open` do not contain the `-10665` constant in their i386 slices;
- Lion's registered PPC application is marked `unsupported-format`, whereas the Snow Leopard registration record is not.

This second-pass audit corrects the symbol handling and localizes the exact LaunchServices callsite before any receipt, database, or binary modification is considered.

## Prepared analyzer

The repository provides:

```text
scripts/audit-launchservices-ppc-gate-callsite.py
```

It is Python-2-compatible and analyzes only the installed LaunchServices i386 slice.

It records:

- the exact instructions whose **operands**, rather than instruction addresses, reference `0xffffd657`;
- the nearest enclosing Mach-O symbol for each true error site;
- a wide instruction window around each site;
- resolved direct-call targets within those windows when symbols are available;
- corrected windows for the architecture/Rosetta functions using their actual Mach-O symbol names;
- direct callers of the function that encloses the `-10665` site;
- nearby symbols around each error site.

The corrected target set includes:

```text
__LSBundleCopyArchitecturesAvailable
__LSBundleCopyArchitecturesValidOnCurrentSystem
__LSGetCPUArchitecture
__LSGetVersionForArchitecture
__LSAppMeetsRosettaRequirement
__LSSetShouldFatApplicationLaunchPPC
__LSShouldFatApplicationLaunchPPC
__ZL15_LSAppCheckTypePK12LSBundleDataPKvl
__ZL21_LSGetArchFlagsForURLPK7__CFURL
```

No application is launched and no system state is changed.

## Safety constraints

For this audit:

- do not launch the PPC app;
- do not rerun `open`;
- do not modify or rebuild the LaunchServices database;
- do not install Snow Leopard Rosetta receipts on Lion;
- do not patch or replace LaunchServices;
- do not copy Snow Leopard frameworks to Lion;
- do not modify XNU or Rosetta;
- do not use live GDB, dtruss, or DTrace.

The analyzer creates a temporary i386 copy of LaunchServices under `/tmp` and deletes it on exit.

## Phase A — update the runtime checkout

On both Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-launchservices-ppc-gate-callsite.py
docs/launchservices-ppc-gate-callsite-audit.md
```

## Phase B — Snow Leopard callsite audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-launchservices-ppc-gate-callsite.py \
  ./launchservices-ppc-gate-callsite-snowleopard.txt
```

Require:

```text
Created: ./launchservices-ppc-gate-callsite-snowleopard.txt
No application was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion callsite audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-launchservices-ppc-gate-callsite.py \
  ./payload/launchservices-ppc-gate-callsite-lion.txt
```

Require the same read-only completion message.

Do not retry the PPC application afterward.

## Phase D — stop and return evidence

Return:

```text
launchservices-ppc-gate-callsite-snowleopard.txt
launchservices-ppc-gate-callsite-lion.txt
```

Keep the first-pass static reports available, but do not regenerate or overwrite them:

```text
launchservices-ppc-gate-snowleopard.txt
launchservices-ppc-gate-lion.txt
```

## Decision gate

The next engineering step depends on the exact Lion enclosing function and branch.

### Lion still contains a conditional external-state gate

If the Lion callsite is conditional on a recognizable external capability/metadata provider, the next experiment will test that provider directly. Only then would a controlled metadata or receipt experiment be justified.

### Lion directly rejects an architecture/item flag

If the Lion callsite directly maps an internal architecture/item flag to `-10665`, and the surrounding code shows that PPC is classified unsupported before any Rosetta-availability provider is consulted, then the next design problem is a **minimal LaunchServices compatibility patch or interposition**. The goal would be to restore only the Snow Leopard-equivalent PPC/Rosetta acceptance decision while leaving Lion's normal architecture policy unchanged.

No patch should be generated until this callsite audit proves that branch.

### The error site belongs to an unexpected function

If the exact enclosing function does not match the current architecture-validity hypothesis, stop and follow the actual function/call graph rather than forcing a Rosetta interpretation.

## What to return for review

Return only the two callsite reports.

No framework binary, package receipt, or LaunchServices database needs to be uploaded.

## Non-goals

This audit does not:

- modify LaunchServices;
- install receipts;
- change the registered app record;
- make PPC apps launch;
- alter Finder;
- change XNU;
- repair the later shell-launch `GetCurrentProcess` boundary.

It is the final read-only localization step before deciding whether a controlled LaunchServices compatibility modification is justified.
