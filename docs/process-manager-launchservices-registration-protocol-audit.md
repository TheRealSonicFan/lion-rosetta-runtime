# Process Manager / LaunchServices registration-protocol audit

## Objective

Determine whether the translated-PPC Process Manager failure is caused by:

1. failure to establish the LaunchServices/CoreApplicationServices process-dispatch channel;
2. a Snow Leopard-to-Lion incompatibility in the application-registration Mach/MIG protocol; or
3. successful registration transport followed by failure to obtain a usable application ASN/PSN.

The corrected RegisterApplication callsite audit has now completed successfully on both Snow Leopard and Lion. It resolves the static control flow far enough that another Process Manager API permutation is no longer useful, but it also shows that a no-abort experiment would still be premature.

## Evidence established by the corrected callsite audit

### Rosetta provenance remains stable

Both systems report the exact validated Rosetta cache and map identities, and both HIServices and LaunchServices are present in the Rosetta cache map. A translated PPC process on Lion therefore has Snow Leopard-provenance PPC client code available for both sides of the Process Manager-to-LaunchServices client path.

### HIServices has a concrete no-PSN abort gate

Snow Leopard PPC HIServices `__RegisterApplication` performs this sequence:

- calls `_LSApplicationCheckIn`;
- if check-in does not yield process information, falls back through `_LSASNCreateWithPid` and application-information lookup;
- extracts the ASN/PSN when available;
- establishes the default WindowServer connection and calls `_CPSRegisterWithServer`;
- finally tests whether the cached PSN low half is still zero.

If the PSN is still unusable and the local abort-control flag is enabled, HIServices logs the fatal no-ASN diagnostic and calls `abort()`. If that flag is disabled, the code continues past the abort site.

The same function obtains the abort-control flag from an environment string through `getenv()`/ `atoi()`, but the corrected report does not map that PC-relative string address back to the literal name. Although the binary contains both `LSDoNotAbortIfNoASN` and `LSDONOTABORTIFNOASN`, the exact controlling name/value semantics must be proven before either is set.

### LaunchServices contains an earlier independent abort possibility

Snow Leopard PPC LaunchServices `getProcessDispatchTable()` calls `SetupCoreApplicationServicesCommunicationPort()` when its process-dispatch table is absent. If the table is still absent afterward, it calls `abort()`.

`getProcessesServerPort()` uses the same communication setup and triggers `LSReCheckInApplication()` when the backing port changes.

Therefore the currently observed self-SIGABRT cannot yet be attributed uniquely to the later HIServices no-ASN branch. It may occur earlier while establishing the LaunchServices process-services channel.

### The registration wire protocol changed between releases

The Snow Leopard PPC `_LSDoRegisterApplication` path emits a Mach/MIG request with the same registration message family used by the native implementation. The corrected reports also expose the Lion native `_XRegisterApplication` and `_LSServerRegisterApplication` server-side paths.

The message ID family is preserved, but request/reply sizes, descriptor validation, and payload-layout checks differ between the Snow Leopard PPC client and Lion native server implementations. This is evidence of protocol/schema evolution, not yet proof that Lion rejects the translated PPC request.

Before designing a compatibility bridge, establish the active native server architecture and compare the exact Snow Leopard PPC request with the Snow Leopard and Lion native server validators.

## Prepared tooling

The runtime repository provides:

```text
scripts/audit-process-manager-registration-protocol.py
docs/process-manager-launchservices-registration-protocol-audit.md
```

The analyzer is Python-2-compatible and read-only. It records:

- OS/build and PowerPC architecture handler;
- active `coreservicesd`, WindowServer, and related launchd state;
- a best-effort read-only attempt to identify the active process architecture;
- CoreServices-related LaunchDaemon metadata when present;
- architecture-specific static windows from HIServices `__RegisterApplication`;
- architecture-specific LaunchServices windows for:
  - `_LSApplicationCheckIn`;
  - `_LSDoRegisterApplication`;
  - `LSReCheckInApplication`;
  - `SetupCoreApplicationServicesCommunicationPort`;
  - `getProcessDispatchTable`;
  - `getProcessesServerPort`;
  - session-ID initialization;
  - current-ASN accessors;
  - `_XRegisterApplication`;
  - `_LSServerRegisterApplication`;
- mapped `__TEXT,__cstring` addresses for the no-ASN/environment and process-services diagnostics.

On Snow Leopard the critical comparison includes PPC LaunchServices/HIServices plus the native server slices. On Lion it includes i386/x86_64 native LaunchServices and i386 HIServices.

## Why the no-abort variable is still not tested

Do not set `LSDoNotAbortIfNoASN` or `LSDONOTABORTIFNOASN` during this stage.

The corrected callsite audit proves that bypassing the HIServices abort can continue execution, but it does **not** prove that:

- the observed Lion crash came from that exact abort site rather than the earlier LaunchServices dispatch-table abort;
- the environment literal has been identified correctly;
- the Lion process-registration RPC was accepted;
- a valid ASN/PSN or CPS registration exists after bypassing the abort.

A no-abort test before resolving those points could merely convert a well-localized failure into later invalid Process Manager state.

## Safety constraints

For this audit:

- do not launch the PPC test application;
- do not set either no-ASN environment variable;
- do not call another Process Manager API permutation;
- do not modify HIServices, LaunchServices, ApplicationServices, CoreServices, or CoreGraphics;
- do not restart or replace `coreservicesd`, WindowServer, pbs, or launchd jobs;
- do not edit LaunchServices registration/database state;
- do not broaden or install the private LaunchServices PPC-admission patch;
- do not alter the Rosetta cache, `/usr/oah/dyld`, or Rosetta shims;
- do not transplant Snow Leopard frameworks or daemons;
- do not modify XNU;
- do not use GDB, DTrace, dtruss, or live code injection.

This stage is static/read-only evidence collection.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-registration-protocol.py
docs/process-manager-launchservices-registration-protocol-audit.md
```

No kernel rebuild is part of this stage.

## Phase B — Snow Leopard protocol audit

On the validated Snow Leopard 10.6.8 system:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-registration-protocol.py \
  ./process-manager-launchservices-registration-snowleopard.txt
```

Require:

```text
Created: ./process-manager-launchservices-registration-snowleopard.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop and return that report unchanged.

## Phase C — Lion protocol audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-registration-protocol.py \
  ./payload/process-manager-launchservices-registration-lion.txt
```

Require:

```text
Created: ./payload/process-manager-launchservices-registration-lion.txt
No PowerPC application was launched and no system file was modified.
RESULT: PASS
```

If `RESULT: FAIL` appears, stop. Do not compensate by rerunning the PPC application.

## Phase D — stop and return evidence

Return:

```text
process-manager-launchservices-registration-snowleopard.txt
process-manager-launchservices-registration-lion.txt
```

Keep the two corrected callsite reports available:

```text
process-manager-registerapplication-v2-snowleopard.txt
process-manager-registerapplication-v2-lion.txt
```

No Apple framework or daemon binary should be uploaded at this stage.

## Decision gate

The next action will depend on the protocol audit.

### A. Process-dispatch setup itself is incompatible

If the Snow Leopard PPC path cannot establish the process dispatch table/port against Lion's native service model, the next target is a narrow compatibility layer for that channel. Do not test the HIServices no-abort switch first.

### B. Registration Mach/MIG schema is incompatible

If the Snow Leopard PPC request layout is accepted by Snow Leopard's native server validator but is structurally rejected by Lion's active native server validator, prepare a private protocol-adapter experiment. The adapter must be limited to the exact registration transaction; do not replace LaunchServices or coreservicesd wholesale.

### C. Registration transport appears compatible but no ASN/PSN is returned

Then a tightly instrumented no-ASN experiment may become justified. At that point the mapped cstring address must identify the exact environment variable and value semantics, and the test must carry milestones for check-in result, PSN state, CPS registration, and the first subsequent Process Manager operation.

### D. Static protocol evidence remains ambiguous

Only then prepare a controlled postmortem that distinguishes the LaunchServices dispatch-table abort from the later HIServices no-ASN abort. Do not broaden system modifications merely to obtain that distinction.

## Current interpretation to preserve

The current evidence continues to place the unresolved boundary in user-space application registration/session services.

The validated Rosetta cache, translated PPC client code, kernel architecture-handler path, commpage work, syscall-295 compatibility, and private LaunchServices admission proof remain valid prerequisites. Nothing in the corrected callsite audit indicates another XNU change.

The leading question is now whether Snow Leopard's translated PPC LaunchServices registration client can speak Lion's native process-services protocol and obtain the ASN/PSN state that HIServices requires.

## Non-goals

This audit does not:

- suppress an abort;
- make Process Manager calls succeed;
- patch or replace LaunchServices;
- alter coreservicesd;
- change the LaunchServices database;
- modify Rosetta or XNU;
- launch the PPC application.

It is the final read-only protocol-localization step before choosing between a transport compatibility experiment and a guarded no-ASN behavior test.
