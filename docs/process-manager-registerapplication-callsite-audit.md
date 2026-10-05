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

The analyzer is read-only and Python-2-compatible. It inspects:

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
  ./process-manager-registerapplication-snowleopard.txt
```

Require:

```text
Created: ./process-manager-registerapplication-snowleopard.txt
No PowerPC application was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion callsite audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-registerapplication.py \
  ./payload/process-manager-registerapplication-lion.txt
```

Require the same read-only completion message.

Do not retry the PPC application after the audit.

## Phase D — stop and return evidence

Return:

```text
process-manager-registerapplication-snowleopard.txt
process-manager-registerapplication-lion.txt
```

Keep the previous reports available:

```text
process-manager-hiservices-snowleopard.txt
process-manager-hiservices-lion.txt
```

No Apple binary should be uploaded at this stage.

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
