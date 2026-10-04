# LaunchServices PPC gate static audit

## Objective

Identify the code path that makes Lion LaunchServices classify a PowerPC application as unsupported and return `kLSNoRosettaEnvironmentErr (-10665)`, without modifying package receipts, LaunchServices state, frameworks, Rosetta, or XNU.

The preceding environment audit established several concrete differences between the successful Snow Leopard LaunchServices control and Lion:

- the kernel PowerPC handler, Rosetta `translate`, `RosettaNonGrata`, and `RosettaVersion.plist` identities match;
- Snow Leopard has Rosetta package receipts, while Lion currently does not;
- Snow Leopard LaunchServices contains x86_64, i386, and ppc7400 slices; Lion LaunchServices contains x86_64 and i386 only;
- Snow Leopard LaunchServices contains explicit Rosetta/OAH logic and strings including `/usr/libexec/oah/translate`, `App required Rosetta`, `RosettaRequirements`, `_LSAppMeetsRosettaRequirement`, and `exceptionalRosettaRequirements`;
- those Rosetta-specific symbols/strings are absent from Lion LaunchServices;
- the same application bundle is registered on both systems, but Lion's registration record adds the item flag `unsupported-format`;
- Lion then returns `-10665` before executing the app.

These facts make a LaunchServices implementation/policy difference the leading explanation. The missing Snow Leopard package receipts remain a secondary difference, but they must **not** be installed on Lion yet: first determine whether Lion's own LaunchServices code still contains a dynamic Rosetta-availability path that could consume such metadata, or whether PowerPC support was structurally retired.

## Prepared analyzer

The runtime repository provides:

```text
scripts/audit-launchservices-ppc-gate-static.py
```

The script is Python-2-compatible for the stock Snow Leopard/Lion environments.

It analyzes the installed i386 code from:

```text
LaunchServices
CarbonCore
coreservicesd
lsregister
/usr/bin/open
```

For each binary it records:

- full-file and i386-slice SHA-256;
- architecture information;
- filtered Rosetta/OAH/PowerPC strings;
- filtered symbols/imports;
- raw occurrences of the 32-bit value for `-10665` (`0xffffd657`);
- disassembly context where `otool` exposes that error constant.

For LaunchServices specifically, it also records runtime-independent static instruction windows for these functions when symbols are present:

```text
_LSBundleCopyArchitecturesAvailable
_LSBundleCopyArchitecturesValidOnCurrentSystem
_LSGetCPUArchitecture
_LSGetVersionForArchitecture
_LSAppMeetsRosettaRequirement
__ZL15_LSAppCheckTypePK12LSBundleDataPKvl
__ZL21_LSGetArchFlagsForURLPK7__CFURL
__ZL28_LSAppCheckDictionaryVersionPK14__CFDictionaryP9LSContextP6FSNodejl
```

The goal is to see whether Lion's i386 LaunchServices still has a conditional Rosetta-availability decision or instead marks PPC invalid through a different architecture-validity path.

## Safety constraints

For this audit:

- do not run the PPC application;
- do not run `open` on the application;
- do not call `lsregister -f`, `lsregister -u`, or rebuild the LaunchServices database;
- do not install the Snow Leopard Rosetta receipts on Lion;
- do not copy Snow Leopard LaunchServices, CarbonCore, or CoreServices binaries to Lion;
- do not modify XNU;
- do not modify Rosetta shims or `/usr/oah/dyld`;
- do not rebuild any dyld cache;
- do not use a live debugger or DTrace.

The analyzer creates temporary **i386 copies** under `/tmp` with `lipo -thin` and deletes them before exiting. It never writes to the installed binaries.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-launchservices-ppc-gate-static.py
docs/launchservices-ppc-gate-static-audit.md
```

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-launchservices-ppc-gate-static.py \
  ./launchservices-ppc-gate-snowleopard.txt
```

Require the terminal to end with:

```text
Created: ./launchservices-ppc-gate-snowleopard.txt
No application was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion static audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-launchservices-ppc-gate-static.py \
  ./payload/launchservices-ppc-gate-lion.txt
```

Require the same read-only completion message.

Do not retry the PPC application after this audit.

## Phase D — stop and return evidence

Return:

```text
launchservices-ppc-gate-snowleopard.txt
launchservices-ppc-gate-lion.txt
```

Keep the earlier environment-audit reports available as supporting evidence:

```text
launchservices-rosetta-snowleopard.txt
launchservices-rosetta-lion.txt
```

No framework binary or receipt file needs to be uploaded at this stage.

## What will be decided next

The static comparison should distinguish among three materially different cases.

### 1. Lion contains an identifiable conditional Rosetta-availability check

If the Lion i386 decision path still conditionally tests some external state before returning `-10665`, the next experiment will target that **specific state provider**. Only then would a controlled receipt/metadata experiment be justified.

### 2. Lion structurally removed the Snow Leopard Rosetta path

If Snow Leopard's `_LSAppMeetsRosettaRequirement`/Rosetta logic has no Lion equivalent and Lion's valid-architecture path directly excludes PPC, the next engineering problem is a LaunchServices compatibility shim or minimal binary/source-independent redirection strategy. Do not transplant the Snow Leopard framework wholesale.

### 3. The error is generated outside LaunchServices.framework

If the `-10665` path is instead localized to CarbonCore, `coreservicesd`, `lsregister`, or another audited helper, the next step will focus on that component rather than LaunchServices.framework.

## Current interpretation to preserve

The missing Rosetta package receipts on Lion are a real Snow Leopard/Lion difference, but current evidence does **not** establish that installing them would restore LaunchServices support. The stronger evidence is structural: Lion's LaunchServices binary lacks Snow Leopard's explicit Rosetta/OAH symbols and records the PPC app as `unsupported-format`.

Therefore do not install receipts until this static audit shows a code path that could plausibly depend on them.

## Non-goals

This audit does not:

- make LaunchServices accept PPC applications;
- patch a closed-source framework;
- install package receipts;
- rebuild the LaunchServices database;
- modify Finder behavior;
- change XNU;
- repair the later shell-launch `GetCurrentProcess` boundary.

It is a read-only static localization of the earlier LaunchServices PPC availability gate.
