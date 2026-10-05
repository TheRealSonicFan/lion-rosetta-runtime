# Process Manager / HIServices implementation audit

## Objective

Determine why three independent translated-PPC Process Manager identity calls now self-abort on Lion before returning:

- `GetCurrentProcess()`;
- `GetProcessPID({0,kCurrentProcess}, ...)`;
- `GetProcessForPID(getpid(), ...)`.

The exact GetProcessForPID-first control succeeds on Snow Leopard 10.6.8, reaches a usable PSN, completes foreground conversion/window creation, and exits normally. On Lion 10.7.5 the same PPC executable reaches `M01_BEFORE_GetProcessForPID` and then self-SIGABRTs before `M02_AFTER_GetProcessForPID`.

This closes the remaining API-permutation question. The next task is not another Process Manager probe and not another XNU change. It is a read-only differential audit of the Process Manager/HIServices implementation and its Rosetta-facing provenance.

## Why provenance must be audited first

The current Lion runtime uses the validated Snow Leopard Rosetta shared cache while Lion also retains its own on-disk ApplicationServices/HIServices binaries. `DYLD_PRINT_LIBRARIES` reports canonical system paths, which by itself does not establish whether a translated guest image was sourced from the Rosetta cache or from an on-disk framework.

The audit therefore records both:

1. Rosetta shared-cache identity and map membership for HIServices/ApplicationServices/CarbonCore/AE; and
2. architecture-specific static information from the installed binaries and Rosetta ApplicationServices/Interposers shims.

This prevents a misleading Snow Leopard-versus-Lion comparison of the wrong image.

## Prepared tooling

The runtime repository provides:

```text
scripts/audit-process-manager-hiservices.py
docs/process-manager-hiservices-audit.md
```

The analyzer is Python-2-compatible for the stock Snow Leopard/Lion environments. It is read-only with respect to the installed system.

It records:

- OS/build and `kern.exec.archhandler.powerpc`;
- Rosetta cache/map SHA-256 and map membership for the relevant framework paths;
- currently running Process Manager/LaunchServices/session helper candidates;
- full-file architecture/hash information for:
  - HIServices;
  - ApplicationServices;
  - CarbonCore;
  - AE;
  - the Rosetta ApplicationServices shim;
  - Rosetta `Interposers.dylib`;
- i386 and PPC/ppc7400 slice hashes when available;
- dependencies, filtered Process Manager/CPS/PSN/ASN strings and symbols;
- targeted disassembly windows for exported/internal symbols that match the Process Manager identity family.

Temporary thin slices are created only under the system temporary directory and deleted on exit.

## Safety constraints

For this audit:

- do not launch the PPC test application again;
- do not call another Process Manager API permutation;
- do not modify or replace HIServices/ApplicationServices/CarbonCore/AE;
- do not modify Rosetta shims;
- do not install Snow Leopard frameworks on Lion;
- do not modify the private LaunchServices compatibility copy;
- do not modify LaunchServices registration/database state;
- do not change `/usr/oah/dyld` or the Rosetta shared cache;
- do not modify XNU;
- do not use live GDB, DTrace, or dtruss.

This stage is static/read-only evidence collection only.

## Phase A — update the runtime checkout

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Confirm:

```text
scripts/audit-process-manager-hiservices.py
docs/process-manager-hiservices-audit.md
```

No kernel rebuild is part of this stage.

## Phase B — Snow Leopard audit

On the validated Snow Leopard 10.6.8 machine:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-hiservices.py \
  ./process-manager-hiservices-snowleopard.txt
```

Require the terminal to end with:

```text
Created: ./process-manager-hiservices-snowleopard.txt
No PowerPC application was launched and no system file was modified.
```

Preserve the report unchanged.

## Phase C — Lion audit

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime

/usr/bin/python ./scripts/audit-process-manager-hiservices.py \
  ./payload/process-manager-hiservices-lion.txt
```

Require the same read-only completion message.

Do not retry the PPC application after this audit.

## Phase D — stop and return evidence

Return:

```text
process-manager-hiservices-snowleopard.txt
process-manager-hiservices-lion.txt
```

Also keep the just-completed GetProcessForPID-first evidence available, especially:

```text
ppc-process-manager-getprocessforpid-first-snowleopard-control.log
lion-ppc-process-manager-getprocessforpid-first-experiment.log
lion-ppc-process-manager-getprocessforpid-first-milestone.log
RosettaProcessManagerPIDFirst_2026-10-04-233032_Andys-Mac.crash
```

No Apple framework binary should be uploaded at this stage. If the reports do not contain enough static information to resolve a call path, request only the exact binary/slice needed for the next offline analysis.

## What will be compared

The first review will answer four questions in order.

### 1. Which image owns the Process Manager entry points?

Determine whether `GetCurrentProcess`, `GetProcessPID`, `GetProcessForPID`, `TransformProcessType`, and related entry points are implemented by HIServices, another system framework, or a Rosetta shim/interposer in each environment.

### 2. Is the translated guest using a cache image with Snow Leopard provenance?

Use the validated Rosetta-cache SHA and map membership to distinguish the translated guest image path from Lion's on-disk i386 implementation. A canonical `/System/Library/...` load path is not, by itself, proof of on-disk provenance.

### 3. Does the implementation depend on a backend/session registration service?

Compare filtered CPS/PSN/ASN/Process Manager strings, imported calls, and relevant helper/job state. If all three API entry points converge on the same registration/IPC/backend routine, that becomes the next concrete target.

### 4. Is there a Snow Leopard-to-Lion host-side implementation difference?

If the guest-facing image/shim is effectively the same but its native backend differs, localize that differential before designing any compatibility layer.

## Decision gate

Do not design a HIServices patch from the current abort alone.

Possible outcomes:

- **shared backend dependency identified:** prepare a narrower read-only callsite/IPC audit of that backend;
- **Rosetta shim/interposer owns the failing path:** audit that shim's calls into the host environment before touching system frameworks;
- **native HIServices implementation difference identified:** prepare a targeted static callsite comparison around the exact divergence;
- **provenance ambiguity remains:** resolve the cache/on-disk image identity first;
- **no useful static difference:** only then prepare a controlled postmortem/instrumentation experiment, still without broad framework replacement.

## Current interpretation to preserve

The new GetProcessForPID-first result is consistent with the already decoded Rosetta guest-requested abort family rather than a new kernel syscall failure. The validated syscall-295 kernel and earlier commpage/runtime gates remain prerequisites, but the unresolved boundary is now user-space Process Manager registration/backend behavior.

Do not broaden the private LaunchServices patch, transplant Snow Leopard HIServices/ApplicationServices, or modify XNU from this result.

## Non-goals

This audit does not:

- make Process Manager calls succeed;
- patch HIServices or any Rosetta shim;
- install a Snow Leopard framework on Lion;
- change LaunchServices policy;
- modify XNU;
- rerun the failing PPC application.

It is the read-only differential step required before any compatibility design.


## Observed result

The Snow Leopard and Lion reports resolve the first-stage differential sufficiently to narrow the next audit.

### Rosetta-cache provenance

Both systems report the exact validated Rosetta cache and map identities:

```text
dyld_shared_cache_rosetta
2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911

dyld_shared_cache_rosetta.map
66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9
```

The map contains HIServices, ApplicationServices, CarbonCore, and AE on both systems.

Lion's installed HIServices contains x86_64/i386 but no PPC slice, while the translated PPC Process Manager calls execute successfully far enough to enter the exported Process Manager entry points. Together with the matching Rosetta cache/map, this makes the restored Snow Leopard PPC cache image the relevant guest-side HIServices provenance rather than Lion's on-disk i386 implementation.

### Rosetta shims are not the differential

The Rosetta ApplicationServices shim has the same full-file, i386-slice, and ppc7400-slice hashes on Snow Leopard and Lion. Rosetta `Interposers.dylib` likewise matches exactly in both slices.

The filtered shim/interposer symbol sets do not own the Process Manager identity APIs. The Process Manager entry points are in HIServices.

### Shared lazy-registration path

Snow Leopard's PPC HIServices implementation shows that all three already-failing entry points share the same initialization action:

- `GetCurrentProcess` calls `__RegisterApplication` before returning the cached PSN;
- `GetProcessPID` calls `__RegisterApplication` before ASN/application-information lookup;
- `GetProcessForPID` calls `__RegisterApplication` before PID-to-ASN lookup.

This is the first concrete common subroutine shared by all three Lion aborts.

### ASN/backend evidence

Both Snow Leopard and Lion HIServices contain the names:

```text
LSDONOTABORTIFNOASN
LSDoNotAbortIfNoASN
```

and explicit fatal diagnostics for failing to obtain an application ASN from CoreServices/coreservicesd. Lion's wording is more explicit that an application requiring an ASN aborts when coreservicesd cannot provide one.

Both systems also have `coreservicesd`, WindowServer, and a `com.apple.pbs` launchd job. Therefore the current evidence does not support a simple missing-helper explanation.

### Decision

Do not patch HIServices, set the no-abort variable, or modify XNU yet.

The next step is the narrower read-only callsite audit in:

```text
docs/process-manager-registerapplication-callsite-audit.md
scripts/audit-process-manager-registerapplication.py
```

That audit targets `__RegisterApplication`, the exact no-ASN branch, LaunchServices ASN helpers, and coreservicesd-facing registration code before any behavioral experiment is attempted.
