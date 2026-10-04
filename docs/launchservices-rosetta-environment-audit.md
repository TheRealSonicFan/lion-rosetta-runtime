# LaunchServices Rosetta environment audit

## Objective

Determine why Lion LaunchServices refuses to launch the already validated PowerPC Carbon application bundle with result code `-10665`, before proposing any LaunchServices, framework, Rosetta-shim, or kernel modification.

The preceding experiment established that the bundle itself is not the immediate problem:

- the Snow Leopard and Lion bundle manifests have identical executable and Info.plist hashes;
- the same PPC executable and private dyld launch successfully through LaunchServices on Snow Leopard;
- on Lion, `lsregister -f` succeeds but `open -n -W` returns `LSOpenURLsWithRole() failed with error -10665`;
- no application process starts on Lion, so no milestone file is created;
- no crash/core diagnostic is generated.

LaunchServices defines `-10665` as `kLSNoRosettaEnvironmentErr`: a PowerPC launch required a Rosetta environment that LaunchServices considered unavailable.

This audit compares the LaunchServices/Rosetta availability state on Snow Leopard 10.6.8 and Lion 10.7.5 without launching the PPC application.

## Prepared tooling

The runtime repository provides:

```text
scripts/audit-launchservices-rosetta-environment.sh
docs/launchservices-rosetta-environment-audit.md
```

The audit is read-only. It records:

- OS/build and console-user identity;
- `kern.exec.archhandler.powerpc`;
- Rosetta `translate`, `RosettaNonGrata`, `RosettaVersion.plist`, and receipt candidates;
- LaunchServices framework architecture, dependencies, and SHA-256;
- LaunchServices strings and symbols related to Rosetta/OAH/PowerPC/architecture checks;
- LaunchServices helper identities;
- LaunchServices/CoreServices processes;
- the existing LaunchServices registration record for the test bundle, when present;
- the app's Info.plist architecture/environment entries.

It does **not** run `open`, execute the PPC binary, register/unregister the bundle, attach a debugger, or modify a system file.

## Safety constraints

For this audit:

- do not rerun the PPC Carbon application;
- do not call `lsregister -f`, `lsregister -u`, or rebuild the LaunchServices database;
- do not replace Lion LaunchServices or CoreServices components;
- do not copy Snow Leopard framework binaries to Lion;
- do not change XNU;
- do not modify `/usr/oah/dyld`;
- do not change the Rosetta cache;
- do not use DTrace, dtruss, or live GDB.

Preserve the existing Snow Leopard and Lion app bundles until the audit is complete.

## Phase A — update the runtime checkout

On both Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-launchservices-rosetta-environment.sh
docs/launchservices-rosetta-environment-audit.md
```

## Phase B — Snow Leopard read-only audit

On the Snow Leopard 10.6.8 control system, from the runtime checkout, run:

```sh
/bin/bash ./scripts/audit-launchservices-rosetta-environment.sh \
  ./launchservices-rosetta-snowleopard.txt \
  ./RosettaCarbonLaunchServices.app
```

The app path is used for inspection only. The script does not launch it or modify its registration.

Require the script to finish with:

```text
Created: ./launchservices-rosetta-snowleopard.txt
No process was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion read-only audit

On Lion 10.7.5, from the runtime checkout, run:

```sh
/bin/bash ./scripts/audit-launchservices-rosetta-environment.sh \
  ./payload/launchservices-rosetta-lion.txt \
  ./payload/RosettaCarbonLaunchServices.app
```

Require the same read-only completion message.

Do not retry `open` after the audit.

## Phase D — preserve and return evidence

Return:

```text
launchservices-rosetta-snowleopard.txt
launchservices-rosetta-lion.txt
```

No binary framework should be uploaded at this stage.

Also preserve the prior LaunchServices experiment artifacts, especially:

```text
ppc-carbon-launchservices-snowleopard-control.log
snowleopard-RosettaCarbonLaunchServices.app.manifest.txt
RosettaCarbonLaunchServices.app.manifest.txt
lion-ppc-carbon-launchservices-experiment.log
lion-ppc-carbon-launchservices-open.raw.log
```

## What will be compared

The next review will compare four layers:

1. **Rosetta runtime state** — whether LaunchServices-visible Rosetta metadata differs despite the working kernel architecture handler and translator.
2. **LaunchServices framework implementation** — whether Snow Leopard and Lion expose different Rosetta/OAH strings, symbols, or imported capability checks.
3. **Registration state** — whether the same bundle is recorded differently in the two LaunchServices databases.
4. **Support-process state** — whether a Snow Leopard LaunchServices/CoreServices helper associated with Rosetta availability is absent on Lion.

The goal is to identify the smallest factual difference that explains why Snow Leopard accepts the PPC app while Lion returns `kLSNoRosettaEnvironmentErr`.

## Decision gate

No LaunchServices patch or framework transplant should be designed until this audit is reviewed.

Possible outcomes include:

- **metadata/capability-state difference:** investigate the exact state provider before touching LaunchServices code;
- **LaunchServices implementation difference:** perform targeted static/postmortem analysis of the relevant Lion decision path;
- **registration-record difference:** isolate that database/registration field with another non-destructive control;
- **no useful static difference:** prepare a small native LaunchServices diagnostic that calls the launch API directly and records its decision path inputs, without starting Rosetta.

## Non-goals

This audit does not:

- make LaunchServices accept PPC applications;
- bypass `kLSNoRosettaEnvironmentErr`;
- patch a closed-source Apple framework;
- copy Snow Leopard LaunchServices to Lion;
- alter Finder behavior;
- repair `GetCurrentProcess`;
- test another PPC GUI application.

It is a read-only differential audit of the LaunchServices Rosetta availability gate.


## Observed differential result

The Snow Leopard/Lion read-only audit found a clear LaunchServices implementation difference while confirming that the core Rosetta runtime state is otherwise aligned.

Shared state:

- both systems report `kern.exec.archhandler.powerpc: /usr/libexec/oah/translate`;
- `translate`, `RosettaNonGrata`, and `RosettaVersion.plist` have the same validated identities;
- the same PPC bundle definition is registered, including the same `LSArchitecturePriority` and `LSEnvironment` values.

Important differences:

1. **Rosetta receipts**
   - Snow Leopard has `com.apple.pkg.Rosetta` and `com.apple.pkg.update.rosetta.10.6.8.combo` receipts.
   - Lion currently has no Rosetta receipt entries.

2. **LaunchServices binary composition**
   - Snow Leopard LaunchServices contains x86_64, i386, and ppc7400 slices.
   - Lion LaunchServices contains only x86_64 and i386 slices.

3. **Explicit Rosetta logic**
   - Snow Leopard LaunchServices contains `/usr/libexec/oah/translate`, `App required Rosetta`, `RosettaRequirements`, `_LSAppMeetsRosettaRequirement`, and `exceptionalRosettaRequirements`.
   - those explicit Rosetta/OAH strings and symbols are absent from Lion LaunchServices.

4. **Registered application classification**
   - Snow Leopard records the test app as a PPC application without `unsupported-format`.
   - Lion records the same PPC app with the additional `unsupported-format` item flag.

The receipts difference is real but is not yet sufficient justification to install Snow Leopard receipts on Lion. The stronger evidence is that Lion's LaunchServices implementation itself no longer contains the Snow Leopard Rosetta-specific decision machinery and classifies the registered PPC executable as unsupported.

The next step is therefore a targeted read-only static audit of the i386 LaunchServices/CarbonCore/CoreServices decision code, documented in `docs/launchservices-ppc-gate-static-audit.md`. That audit searches for the `-10665` return path and disassembles the architecture-validity functions on both systems before any metadata or framework modification is attempted.
