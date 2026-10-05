# Process Manager RegisterApplication / ASN callsite audit

## Objective

Localize the common initialization path shared by the three translated-PPC Process Manager failures before attempting any behavioral workaround.

The completed HIServices audit establishes that:

- the validated Snow Leopard Rosetta shared cache and map are identical on Snow Leopard and Lion;
- HIServices, ApplicationServices, CarbonCore, and AE are all present in that Rosetta cache map;
- the Rosetta ApplicationServices shim and `Interposers.dylib` have identical full-file and architecture-slice hashes on both systems;
- Snow Leopard's PPC HIServices implementation calls the same internal `__RegisterApplication` routine before `GetCurrentProcess`, `GetProcessPID`, and `GetProcessForPID` proceed;
- both systems have `coreservicesd`, WindowServer, and the `com.apple.pbs` launchd job, so the current evidence does not support a simple "missing helper process" explanation;
- the HIServices strings on both releases explicitly describe aborting when an application ASN cannot be obtained, and both contain the `LSDoNotAbortIfNoASN` / `LSDONOTABORTIFNOASN` names.

This makes `__RegisterApplication` and its LaunchServices/coreservicesd ASN acquisition path the next concrete boundary.

The purpose of this stage is to determine exactly what `__RegisterApplication` calls, where the no-ASN abort branch sits, and how the client/server-facing ASN code differs between Snow Leopard and Lion.

## Prepared tooling

The runtime repository provides:

```text
scripts/audit-process-manager-registerapplication.py
docs/process-manager-registerapplication-callsite-audit.md
```

The analyzer is read-only and Python-2-compatible. The first execution exposed a reporting defect: escaped parser expressions caused every intended disassembly selection to end with `selected_symbol_windows=0`, even though the preceding `nm` inventory clearly contained targets such as `__RegisterApplication`. That first run is preserved as useful symbol/string inventory, but it did **not** complete the intended callsite localization.

Current `main` contains analyzer version 2. It replaces the fragile regex-based address parser, validates that code windows were actually selected, adds the x86_64 LaunchServices slice needed for the native `coreservicesd` side, and records Rosetta-cache membership for both HIServices and LaunchServices. A run is valid only when the report ends with `RESULT: PASS`.

The corrected analyzer inspects:

### HIServices

For i386 and, when present, ppc7400:

- `__RegisterApplication` / `_RegisterApplication`;
- direct references/callers of that routine;
- `GetCurrentProcess`;
- `GetProcessPID`;
- `GetProcessForPID`;
- Process Manager initialization symbols;
- registration/ASN/CPS/CoreGraphics strings and imports.

### LaunchServices

For i386 and, when present, ppc7400:

- `_LSGetCurrentApplicationASN`-family symbols;
- ASN creation/extraction helpers;
- application-information lookup helpers;
- application registration symbols when present;
- other nearby symbols matching the registration/ASN filter.

### coreservicesd

For available i386/x86_64 slices:

- registration/ASN/session strings;
- matching symbols/imports;
- code windows for matching symbols when symbols are present.

The script creates temporary thin slices under the system temporary directory and deletes them on exit.

## Why this audit comes before using LSDoNotAbortIfNoASN

The first audit found the `LSDoNotAbortIfNoASN`/`LSDONOTABORTIFNOASN` names, but it did not show the exact control flow that consumes them.

Do not set that variable yet.

Before changing behavior, establish whether suppressing the abort would:

- return a defined error cleanly;
- leave Process Manager globals uninitialized;
- continue into CPS/CoreGraphics registration with invalid state; or
- merely move the failure to a later call.

The callsite audit is intended to answer that first.

## Safety constraints

For this audit:

- do not launch the PPC test application;
- do not set `LSDoNotAbortIfNoASN` or `LSDONOTABORTIFNOASN`;
- do not call another Process Manager API permutation;
- do not modify HIServices/ApplicationServices/LaunchServices/CoreServices;
- do not modify `coreservicesd` or launchd jobs;
- do not modify Rosetta shims;
- do not broaden the private LaunchServices compatibility patch;
- do not change the Rosetta cache or `/usr/oah/dyld`;
- do not install Snow Leopard frameworks on Lion;
- do not modify XNU;
- do not use live GDB, DTrace, or dtruss.

This is a static/read-only localization step.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-registerapplication.py
docs/process-manager-registerapplication-callsite-audit.md
```

No kernel rebuild is part of this stage.

## Phase B — Snow Leopard callsite audit

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-registerapplication.py \
  ./process-manager-registerapplication-v2-snowleopard.txt
```

Require:

```text
Created: ./process-manager-registerapplication-v2-snowleopard.txt
No PowerPC application was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion callsite audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-registerapplication.py \
  ./payload/process-manager-registerapplication-v2-lion.txt
```

Require the same read-only completion message **and `RESULT: PASS`**. If `RESULT: FAIL` appears, stop and return that report without rerunning the PPC application.

Do not retry the PPC application after the audit.

## Phase D — stop and return evidence

Return:

```text
process-manager-registerapplication-v2-snowleopard.txt
process-manager-registerapplication-v2-lion.txt
```

Keep the previous reports available:

```text
process-manager-hiservices-snowleopard.txt
process-manager-hiservices-lion.txt
```

No Apple binary should be uploaded at this stage.

## Result of the first execution

The first reports confirmed several useful facts but failed their intended code-window objective:

- Lion HIServices contains `__RegisterApplication`, `GetProcessForPID`, and `GetProcessPID`, yet the report ended that slice with `selected_symbol_windows=0`;
- Snow Leopard likewise exposed the relevant HIServices and LaunchServices symbols, including the PPC variants, but every analyzed slice still reported zero selected windows;
- this is a tooling defect, not evidence that those functions lack disassembly or that the call path is absent.

The defect was traced to over-escaped parser expressions in analyzer version 1. Therefore do **not** infer the no-ASN branch, CPS registration order, or safe behavior of `LSDoNotAbortIfNoASN` from the first reports.

The authoritative next action is simply to rerun this same read-only audit with analyzer version 2 and return the two v2 reports above. No PPC process should be launched during this rerun.

## What will be decided next

The review will determine which of these cases is supported.

### 1. `__RegisterApplication` aborts specifically because current ASN acquisition fails

If the callsite shows a clean failure from the LaunchServices/coreservicesd ASN lookup followed by the abort branch, the next experiment can be designed around that exact condition. Only then should the documented no-abort switch be considered, and only with milestones that prove whether state remains valid.

### 2. `__RegisterApplication` reaches CPS/CoreGraphics registration and fails there

Then the next target is the WindowServer/CPS registration protocol rather than LaunchServices ASN lookup.

### 3. Snow Leopard PPC client code is stable, but Lion native LaunchServices/coreservicesd semantics differ

Then prepare a narrow client/server protocol or registration-state audit around the specific differing function. Do not transplant the entire Snow Leopard framework or daemon.

### 4. The callsite still cannot identify the failure branch

Only then prepare a controlled postmortem or minimal behavior-preserving diagnostic around `__RegisterApplication`.

## Current interpretation to preserve

The first HIServices audit does not support an XNU failure or a Rosetta-shim mismatch.

The three failing Process Manager entry points share lazy registration through `__RegisterApplication`, while the preserved Rosetta client-side runtime components are aligned. The unresolved issue is now the application-ASN / Process Manager registration path that bridges the Snow Leopard PPC client environment to Lion's native user-space services.

No XNU modification is indicated.

## Non-goals

This audit does not:

- make Process Manager APIs succeed;
- suppress the current abort;
- patch HIServices;
- patch LaunchServices;
- alter coreservicesd;
- install Snow Leopard system frameworks;
- change the kernel;
- launch the PPC application.

It is the narrow read-only step needed before any compatibility experiment is justified.
