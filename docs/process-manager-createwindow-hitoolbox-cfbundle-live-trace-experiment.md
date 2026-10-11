# Process Manager CreateNewWindow live HIToolbox CFBundle resource trace

## Objective

The exact distributed-notification registration experiment closed the registration boundary without restoring `CreateNewWindow`. The returned Lion run accepted all three reviewed legacy registrations, reported zero broker rejects and zero callbacks, then immediately emitted:

```text
HIToolbox: failed to copy resource URL for framework bundle.
HIToolbox is damaged with error -4960 and TTheme instance 0. Aborting...
```

before `M21_AFTER_CreateNewWindow`. The subject exited 134 and protected hashes remained unchanged.

This moves the unresolved boundary past distributed-notification schema/registration and back into HIToolbox theme initialization.

The historical Library record contains a coherent but not yet live-callsite-complete differential:

- Snow PPC HIToolbox `_MakeThemeFSRef` statically calls `CFBundleCopyResourceURLForLocalization` with resource name `Extras` and type `rsrc`, and takes the exact logged warning branch when that call returns NULL.
- Snow's HIToolbox Resources directory contains both `Extras.rsrc` and `Extras2.rsrc`.
- Lion's HIToolbox Resources directory contains `Extras2.rsrc` but not `Extras.rsrc`.
- a standalone PPC CFBundle probe found `Extras.rsrc` on Snow and returned NULL for it on Lion, while finding `Extras2.rsrc` on both.
- `Extras.rsrc` and `Extras2.rsrc` are not interchangeable by evidence: their classic resource maps have the same type/ID layout, but 1128 of 1134 shared resource payloads differ, including fields consumed by Snow PPC TTheme code.

Those facts make a missing `Extras.rsrc` lookup the leading explanation, but the standalone probe did not prove that the live `CreateNewWindow` aborting call is that exact lookup. The next experiment closes only that gap.

## Prepared files

Current `main` adds:

```text
tests/ppc-hitoolbox-cfbundle-resource-trace-interposer.c
scripts/build-ppc-hitoolbox-cfbundle-resource-trace-on-snowleopard.sh
docs/process-manager-createwindow-hitoolbox-cfbundle-live-trace-experiment.md
```

and extends the accepted Snow control and Lion integration runners with an optional pass-through trace dylib.

Trace build ID:

```text
hitoolbox-cfbundle-resource-trace-v1
```

The trace interposes only `CFBundleCopyResourceURLForLocalization`. It recovers the original routine from its own `__DATA,__interpose` replacee pointer, not `dlsym`, and calls the original unchanged. It records only an exact target:

```text
bundle identifier = com.apple.HIToolbox
resource name     = Extras
resource type     = rsrc
subdirectory      = NULL
localization      = NULL
```

It never rewrites the resource name, returns a synthetic URL, copies a resource, modifies a framework, or changes notification behavior.

## Safety constraints

For this stage:

- reuse the exact accepted PPC CreateNewWindow subject unchanged;
- reuse the exact accepted combined CoreServices/CPS/distributed-notifications compatibility dylib unchanged;
- reuse the exact accepted Security and CGS compatibility dylibs unchanged;
- reuse the exact accepted native registration broker on Lion;
- build only the new pass-through PPC trace dylib on Snow Leopard;
- do not copy `Extras.rsrc` to Lion;
- do not symlink `Extras.rsrc` to `Extras2.rsrc`;
- do not redirect `Extras` to `Extras2`;
- do not edit HIToolbox, CoreFoundation, Rosetta, dyld, launchd, distnoted, WindowServer, shared caches, or XNU;
- do not broaden distributed-notification policy;
- run the Snow control first, then exactly one Lion traced run only after the Snow control passes.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current main on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build the pass-through PPC trace on Snow Leopard

Syntax-check:

```sh
/bin/bash -n ./scripts/build-ppc-hitoolbox-cfbundle-resource-trace-on-snowleopard.sh
```

Build:

```sh
/bin/bash ./scripts/build-ppc-hitoolbox-cfbundle-resource-trace-on-snowleopard.sh \
  ./ppc-hitoolbox-cfbundle-resource-trace.dylib
```

Require:

```text
thin 32-bit PPC Mach-O dylib
build_id=hitoolbox-cfbundle-resource-trace-v1
CFBundleCopyResourceURLForLocalization import/reference
CFBundleGetIdentifier import
CFURLGetFileSystemRepresentation import
no dlsym import
SHA-256 sidecar
info sidecar
```

## Phase C — Snow Leopard live CreateNewWindow control with trace

Use the same exact accepted PPC subject and compatibility dylibs as the preceding integrated Snow control.

Set only the trace inputs:

```sh
export ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH="$PWD/ppc-hitoolbox-cfbundle-resource-trace.dylib"
export ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE="$PWD/ppc-hitoolbox-cfbundle-resource-trace.dylib.sha256"
```

Syntax-check the existing Snow control runner:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Then run it exactly once using the same nine positional arguments from the accepted distributed-notifications integration control, with a new output log name such as:

```text
ppc-process-manager-createwindow-hitoolbox-cfbundle-trace-snowleopard-control.log
```

Require the existing Snow CreateNewWindow success gates and additionally:

```text
PM_HITOOLBOX_CFBUNDLE_TRACE_TARGET:
  bundle=com.apple.HIToolbox
  name=Extras
  type=rsrc
  subdir=NULL
  localization=NULL

at least one target call
every target result url=NONNULL
M21_AFTER_CreateNewWindow
CreateNewWindow=0
nonzero WindowRef
M23_AFTER_DisposeWindow
M24_SUCCESS
RESULT: CREATENEWWINDOW_HITOOLBOX_CFBUNDLE_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

If the exact target is not observed on Snow, or any target lookup is NULL, stop. Do not proceed to Lion.

Unset the two trace variables after the control if desired; they will be set explicitly again on Lion.

## Phase D — transfer only the trace artifact to Lion

Transfer:

```text
ppc-hitoolbox-cfbundle-resource-trace.dylib
ppc-hitoolbox-cfbundle-resource-trace.dylib.info.txt
ppc-hitoolbox-cfbundle-resource-trace.dylib.sha256
ppc-process-manager-createwindow-hitoolbox-cfbundle-trace-snowleopard-control.log
```

Do not rebuild any PPC artifact on Lion.

Pull current runtime `main` on Lion and retain the exact native registration broker already accepted by the preceding experiment.

## Phase E — repeat the native syscall-295 safety gate

Repeat the established Lion syscall-295 probe and require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Stop if the kernel identity or probe behavior changed.

## Phase F — exactly one Lion live CreateNewWindow trace

Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Set:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'
export ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH="$PWD/ppc-hitoolbox-cfbundle-resource-trace.dylib"
export ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE="$PWD/ppc-hitoolbox-cfbundle-resource-trace.dylib.sha256"
```

Then run the same accepted Lion integration command as the real-registration experiment, with:

```sh
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-register-v1
```

and an output log such as:

```text
payload/lion-ppc-process-manager-createwindow-hitoolbox-cfbundle-trace.log
```

The decisive expected differential is:

```text
three exact distributed-notification registrations accepted
broker summary register=3 rejects=0 exact=YES
broker result PASS
M20_BEFORE_CreateNewWindow
PM_HITOOLBOX_CFBUNDLE_TRACE_TARGET: ... bundle=com.apple.HIToolbox name=Extras type=rsrc ...
at least one exact target call
every exact target result url=NULL
HIToolbox: failed to copy resource URL for framework bundle.
M21_AFTER_CreateNewWindow not reached
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_LOOKUP_CONFIRMED_NO_RETURN
```

This experiment is diagnostic. A confirmed NULL result does **not** authorize resource substitution.

If the live target returns NONNULL on Lion, or the exact target is not observed, stop and return the evidence; the missing-`Extras.rsrc` hypothesis is not established for the live abort path.

## Phase G — return evidence and stop

Return:

```text
ppc-hitoolbox-cfbundle-resource-trace.dylib.info.txt
ppc-hitoolbox-cfbundle-resource-trace.dylib.sha256
ppc-process-manager-createwindow-hitoolbox-cfbundle-trace-snowleopard-control.log
syscall295-probe-process-manager-createwindow-hitoolbox-cfbundle-trace.log
lion-ppc-process-manager-createwindow-hitoolbox-cfbundle-trace.log
lion-ppc-process-manager-createwindow-hitoolbox-cfbundle-trace.raw.log
```

Also return any new crash/core diagnostic named by the Lion runner if one is produced and available.

Stop after Phase G.

## Decision gate

If Snow's live call returns a URL and Lion's otherwise equivalent live call returns NULL immediately before the same HIToolbox warning, the missing `Extras.rsrc` boundary is confirmed. The following stage must then determine a semantically correct PPC theme-resource strategy; it must **not** assume `Extras2.rsrc` is a safe substitute because the existing resource-level comparison disproves byte-level equivalence for nearly all shared payloads.

If the live differential is not confirmed, analyze the trace and new diagnostic before proposing any resource compatibility mechanism.

No additional XNU change is indicated by the current evidence.
