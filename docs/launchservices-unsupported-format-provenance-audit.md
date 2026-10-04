# LaunchServices unsupported-format provenance audit

## Objective

Determine exactly how Lion LaunchServices marks the validated PowerPC application as `unsupported-format`, and compare that provenance with Snow Leopard before designing any LaunchServices compatibility change.

The corrected callsite audit has now resolved the launch rejection mechanically:

### Snow Leopard

The sole `kLSNoRosettaEnvironmentErr (-10665)` site is inside `_LSLaunch`. Snow Leopard calls `_LSAppMeetsRosettaRequirement`, initializes the pending launch result to `-10665`, and continues only when the Rosetta requirement check returns its accepting value.

### Lion

The sole `-10665` site is also inside `_LSLaunch`, but the Rosetta requirement checker is gone. Lion instead:

1. calls `_LSBundleDataGetUnsupportedFormatFlag`;
2. continues normally when that flag is clear;
3. when the flag is set, inspects an additional bundle-data bit;
4. returns either:
   - `kLSNoRosettaEnvironmentErr (-10665)`, or
   - `kLSExecutableIncorrectFormat (-10661)`.

For the observed PPC application, LaunchServices returns `-10665`, matching the registered `unsupported-format ppc` classification from the earlier database audit.

This establishes that Lion's launch-time rejection is driven by a bundle-registration format flag rather than a dynamic Rosetta availability check.

The remaining design question is therefore **where that unsupported-format flag is set and which architecture-validity path creates it for PPC**.

## Prepared analyzer

The repository provides:

```text
scripts/audit-launchservices-unsupported-format-provenance.py
```

The analyzer is Python-2-compatible and examines only the installed i386 LaunchServices slice.

It records:

- every symbol whose name mentions `UnsupportedFormat`, architecture availability, or bundle registration;
- the complete body of `_LSBundleDataGetUnsupportedFormatFlag`;
- the complete bodies of:
  - `_LSBundleCopyArchitecturesValidOnCurrentSystem`,
  - `_LSBundleCopyArchitecturesAvailable`,
  - `_LSGetCPUArchitecture`,
  - `_LSGetVersionForArchitecture`;
- every direct caller of those functions;
- all direct callers and bodies of any `UnsupportedFormat` getter/setter helpers present in the binary.

The purpose is to identify the registration-time code that converts a PPC executable into the persisted `unsupported-format` state.

## Safety constraints

For this audit:

- do not launch the PPC application;
- do not run `open`;
- do not run `lsregister -f`, `lsregister -u`, or rebuild the LaunchServices database;
- do not install Snow Leopard Rosetta receipts on Lion;
- do not patch LaunchServices;
- do not copy Snow Leopard CoreServices/LaunchServices binaries to Lion;
- do not modify XNU or Rosetta;
- do not change the application bundle;
- do not use live GDB, DTrace, or dtruss.

The analyzer creates a temporary i386 copy under `/tmp` and deletes it before exit.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-launchservices-unsupported-format-provenance.py
docs/launchservices-unsupported-format-provenance-audit.md
```

## Phase B — Snow Leopard provenance audit

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-launchservices-unsupported-format-provenance.py \
  ./launchservices-unsupported-format-provenance-snowleopard.txt
```

Require:

```text
Created: ./launchservices-unsupported-format-provenance-snowleopard.txt
No application was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion provenance audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-launchservices-unsupported-format-provenance.py \
  ./payload/launchservices-unsupported-format-provenance-lion.txt
```

Require the same read-only completion message.

Do not retry the PPC application afterward.

## Phase D — stop and return evidence

Return:

```text
launchservices-unsupported-format-provenance-snowleopard.txt
launchservices-unsupported-format-provenance-lion.txt
```

Keep the earlier callsite reports available, but do not overwrite them:

```text
launchservices-ppc-gate-callsite-snowleopard.txt
launchservices-ppc-gate-callsite-lion.txt
```

## Decision gate

The next engineering step depends on the provenance result.

### Registration-time architecture policy is isolated

If Lion's registration path calls `_LSBundleCopyArchitecturesValidOnCurrentSystem` and sets the unsupported-format flag because the valid architecture set excludes PPC, the next experiment will target that single registration-time decision. A minimal compatibility patch should alter only PPC/Rosetta classification and preserve Lion's handling of all other unsupported formats.

### A dedicated unsupported-format setter exists

If a specific setter/helper is identified, its caller and inputs become the preferred patch point rather than the broader launch routine.

### No setter path is recoverable statically

If the flag originates through opaque database packing or indirect dispatch, the next experiment will be a native read-only attribute probe plus a narrowly scoped private LaunchServices copy, not an on-disk system-framework patch.

## Important interpretation

The corrected callsite audit already proves that **receipts are not consulted at launch time** in Lion's `-10665` path. Installing Snow Leopard Rosetta receipts would therefore be premature unless this provenance audit finds a registration-time provider that explicitly consumes them.

The provenance result changes that interpretation: the launch-time unsupported-format flag is computed dynamically by _LSBundleDataGetUnsupportedFormatFlag from the bundle-data architecture bits and current CPU policy. No dedicated unsupported-format setter was identified. The current preferred direction is therefore to restore the minimum Snow Leopard-equivalent PPC compatibility decision in that helper, not to transplant Snow Leopard LaunchServices wholesale.

## Non-goals

This audit does not:

- clear the unsupported-format flag;
- edit the LaunchServices database;
- patch the framework;
- install receipts;
- launch the PPC application;
- modify Finder;
- change XNU;
- address the later shell-launch `GetCurrentProcess` boundary.

It is the final provenance step before a controlled LaunchServices compatibility experiment can be designed.

## Observed provenance result: Lion removed the Intel-to-PPC fallback

The provenance audit completed successfully on Snow Leopard 10.6.8 and Lion 10.7.5.

The decisive comparison is _LSBundleDataGetUnsupportedFormatFlag.

### Snow Leopard

Snow Leopard calls _LSGetPhysicalCPUType. On Intel/x86_64 hosts it first checks the native Intel architecture flags. If those are absent, it falls back to a second mask test that accepts a PPC-only bundle when the PPC architecture bit 0x02000000 is present and the relevant exclusion bits are clear.

This is the Rosetta-era compatibility path.

### Lion

Lion's corresponding helper calls _LSGetCPUType. Its x86_64-host branch tests only the native Intel mask 0x14000000; if that mask is absent, the common path returns 0x00400000, the unsupported-format flag. The Snow Leopard PPC fallback is gone.

For the validated PPC-only Carbon application, this explains both the unsupported-format ppc classification shown by LaunchServices and the later _LSLaunch conversion of that result into kLSNoRosettaEnvironmentErr (-10665).

The audit also found no dedicated unsupported-format setter symbol. The helper computes the flag from bundle data and CPU policy, so the earlier wording that treated it as a purely persisted database bit was incomplete.

_LSBundleCopyArchitecturesValidOnCurrentSystem exists on both systems and retains closely corresponding architecture-filtering logic. The immediately demonstrated Snow-Leopard-to-Lion regression is therefore the removed PPC fallback inside _LSBundleDataGetUnsupportedFormatFlag.

This is sufficient to justify a controlled compatibility experiment, but not an on-disk framework patch.

The next experiment is documented in docs/private-launchservices-ppc-compat-experiment.md. It creates a private copy of Lion's i386 LaunchServices, applies a one-byte test-only change that admits the PPC architecture bit at this exact x86_64-host gate, proves that /usr/bin/open loaded the private framework, and then performs one guarded launch of the already validated PPC application.

Do not modify the installed LaunchServices framework or database.