# Process Manager CreateNewWindow exact Snow HIToolbox Extras resource compatibility

## Objective

The live CFBundle trace has now closed the HIToolbox resource-lookup question on the actual CreateNewWindow path.

The successful Snow Leopard control performed the exact PPC HIToolbox lookup:

```text
bundle=com.apple.HIToolbox
name=Extras
type=rsrc
subdir=NULL
localization=NULL
```

twice, and both calls returned the framework's `Extras.rsrc`; CreateNewWindow then returned 0 with a nonzero WindowRef and reached M24.

The otherwise equivalent Lion run performed the same exact lookup once, returned NULL, immediately logged the known framework-resource URL failure and TTheme `-4960` abort, and did not reach M21. The three reviewed distributed-notification registrations still completed with zero rejects and zero callbacks, and protected hashes were unchanged.

This is now a live causal boundary rather than a static or standalone-probe differential: Snow PPC HIToolbox requires its `Extras.rsrc` resource during CreateNewWindow, and Lion's HIToolbox bundle does not provide that resource name.

The next controlled question is whether supplying the **exact Snow Leopard 10.6.8 `Extras.rsrc` paired with the already-restored Snow PPC HIToolbox code**, from a process-local external path, is sufficient to move CreateNewWindow forward. This experiment does not use Lion's `Extras2.rsrc` as a substitute.

## Exact resource identity

The accepted Snow Leopard resource identity is:

```text
file:   Extras.rsrc
size:   5425538
SHA256: a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197
source: /System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Resources/Extras.rsrc
```

The resource must be copied locally from the user's own Snow Leopard 10.6.8 installation. It is proprietary Apple content and must not be committed to this repository or returned as an analysis artifact.

Current `.gitignore` explicitly excludes the default staged filename and sidecars.

## Prepared files

Current `main` adds:

```text
tests/ppc-hitoolbox-extras-resource-compat-interposer.c
scripts/prepare-snowleopard-hitoolbox-extras-resource.sh
scripts/build-ppc-hitoolbox-extras-resource-compat-on-snowleopard.sh
docs/process-manager-createwindow-hitoolbox-extras-resource-compat-experiment.md
```

and extends the accepted Snow control and Lion integration runners with an opt-in exact resource compatibility path.

Compatibility build ID:

```text
hitoolbox-extras-resource-compat-v1
```

The compatibility dylib interposes only `CFBundleCopyResourceURLForLocalization`. It recovers the original function from its own `__DATA,__interpose` replacee pointer, never through `dlsym`.

It matches only:

```text
bundle identifier = com.apple.HIToolbox
resource name     = Extras
resource type     = rsrc
subdirectory      = NULL
localization      = NULL
```

All non-target calls are passed to the original function unchanged.

Two deliberately separate modes exist:

```text
snow-force-external-v1
lion-fallback-external-v1
```

The Snow control forces the exact target to the staged external copy so the external-path mechanism itself is proven on the known-good OS. The Lion mode first calls the original CFBundle routine and falls back to the external resource **only if that exact target returns NULL**.

## Safety constraints

For this stage:

- reuse the exact accepted PPC CreateNewWindow subject unchanged;
- reuse the exact accepted CoreServices/CPS/distributed-notifications, Security, and CGS compatibility dylibs unchanged;
- reuse the exact accepted native three-registration broker on Lion;
- copy only the exact SHA-pinned Snow Leopard 10.6.8 `Extras.rsrc` into the user's working directory;
- never copy that resource into Lion's system HIToolbox framework;
- never replace or modify Lion's `Extras2.rsrc`;
- never redirect `Extras` to `Extras2`;
- never commit or upload the proprietary `Extras.rsrc` to the repository;
- do not modify HIToolbox, CoreFoundation, Rosetta, dyld, launchd, distnoted, WindowServer, shared caches, or XNU;
- do not broaden distributed-notification policy;
- do not combine the older CFBundle trace dylib and the new compatibility dylib in one run;
- run the forced external-resource Snow control first;
- perform exactly one Lion compatibility run only after that Snow control passes.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current main on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

## Phase B — stage the exact Snow Leopard Extras.rsrc locally

Syntax-check:

```sh
/bin/bash -n ./scripts/prepare-snowleopard-hitoolbox-extras-resource.sh
```

Stage the resource:

```sh
/bin/bash ./scripts/prepare-snowleopard-hitoolbox-extras-resource.sh \
  ./SnowLeopard-HIToolbox-Extras.rsrc
```

Require:

```text
output_size=5425538
output_sha256=a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197
exact_match=YES
```

Keep the staged resource untracked. Do not add it to Git.

## Phase C — build the exact PPC resource compatibility dylib on Snow Leopard

Syntax-check:

```sh
/bin/bash -n ./scripts/build-ppc-hitoolbox-extras-resource-compat-on-snowleopard.sh
```

Build:

```sh
/bin/bash ./scripts/build-ppc-hitoolbox-extras-resource-compat-on-snowleopard.sh \
  ./ppc-hitoolbox-extras-resource-compat.dylib
```

Require:

```text
thin 32-bit PPC Mach-O dylib
build_id=hitoolbox-extras-resource-compat-v1
CFBundleCopyResourceURLForLocalization import/reference
CFBundleGetIdentifier import
CFURLCreateFromFileSystemRepresentation import
no dlsym import
SHA-256 sidecar
info sidecar
```

## Phase D — Snow Leopard forced external-resource CreateNewWindow control

Do not load the older CFBundle trace dylib in this phase.

Set:

```sh
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check the established Snow runner:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Run it exactly once using the same nine positional arguments from the previously accepted Snow integration control, with a new output log such as:

```text
ppc-process-manager-createwindow-hitoolbox-extras-external-snowleopard-control.log
```

Require:

```text
at least one PM_HITOOLBOX_EXTRAS_COMPAT_TARGET with mode=snow-force-external-v1
every exact target result reports original=SKIPPED fallback=NONNULL
no HIToolbox framework-resource URL failure
M21_AFTER_CreateNewWindow
CreateNewWindow=0
nonzero WindowRef
M23_AFTER_DisposeWindow
M24_SUCCESS
RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_SNOW_CONTROL_PASS
RESULT: PASS
```

This control is essential: it proves that TTheme can consume the exact resource from the external user-owned path rather than relying on the framework-bundle location.

If it fails, stop. Do not proceed to Lion.

## Phase E — transfer the exact locally staged artifacts to Lion

Transfer only between the user's own Snow and Lion machines:

```text
SnowLeopard-HIToolbox-Extras.rsrc
SnowLeopard-HIToolbox-Extras.rsrc.info.txt
SnowLeopard-HIToolbox-Extras.rsrc.sha256
ppc-hitoolbox-extras-resource-compat.dylib
ppc-hitoolbox-extras-resource-compat.dylib.info.txt
ppc-hitoolbox-extras-resource-compat.dylib.sha256
ppc-process-manager-createwindow-hitoolbox-extras-external-snowleopard-control.log
```

Do not place `Extras.rsrc` inside `/System/Library/Frameworks` on Lion. Keep it in the working directory.

Pull current runtime `main` on Lion. Do not rebuild any PPC artifact there.

## Phase F — repeat the native syscall-295 safety gate

Repeat the established Lion syscall-295 probe and require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Stop if the kernel identity or routing result changed.

## Phase G — exactly one Lion exact-resource fallback run

Do not load the older CFBundle trace dylib.

Set:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'

unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
```

Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Then run the same accepted Lion integration command as the exact-registration experiment, retaining:

```sh
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-register-v1
```

Use a new output log such as:

```text
payload/lion-ppc-process-manager-createwindow-hitoolbox-extras-external.log
```

The compatibility dylib must show that Lion's original exact lookup is still NULL and that only then the exact Snow resource URL is supplied:

```text
PM_HITOOLBOX_EXTRAS_COMPAT_TARGET: ... mode=lion-fallback-external-v1 ... name=Extras type=rsrc ...
PM_HITOOLBOX_EXTRAS_COMPAT_RESULT: ... mode=lion-fallback-external-v1 original=NULL fallback=NONNULL
```

The strongest success result is:

```text
three exact distributed-notification registrations accepted
broker summary register=3 callback=<n> rejects=0 exact=YES
broker result PASS
at least one exact HIToolbox Extras target
original=NULL fallback=NONNULL
M21_AFTER_CreateNewWindow
CreateNewWindow=0
nonzero WindowRef
M23_AFTER_DisposeWindow
M24_SUCCESS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_PASS
```

If the exact fallback is supplied but CreateNewWindow still does not return, the runner reports:

```text
RESULT: CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_NO_RETURN
```

Stop there and analyze the new immediately following TTheme/resource boundary before widening compatibility.

If the exact original lookup unexpectedly becomes non-NULL, the fallback is NULL, or the target is not observed, stop on the corresponding incomplete result and return the evidence.

## Phase H — return evidence and stop

Return:

```text
SnowLeopard-HIToolbox-Extras.rsrc.info.txt
SnowLeopard-HIToolbox-Extras.rsrc.sha256
ppc-hitoolbox-extras-resource-compat.dylib.info.txt
ppc-hitoolbox-extras-resource-compat.dylib.sha256
ppc-process-manager-createwindow-hitoolbox-extras-external-snowleopard-control.log
syscall295-probe-process-manager-createwindow-hitoolbox-extras-external.log
lion-ppc-process-manager-createwindow-hitoolbox-extras-external.log
lion-ppc-process-manager-createwindow-hitoolbox-extras-external.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner if one is produced and available.

**Do not return or upload the proprietary `SnowLeopard-HIToolbox-Extras.rsrc` file itself.**

Stop after Phase H.

## Decision gate

- If `CREATENEWWINDOW_HITOOLBOX_EXTRAS_EXTERNAL_COMPAT_PASS` is reached, the missing exact Snow theme resource was the CreateNewWindow blocker and the investigation advances beyond window creation. A later packaging step can derive this resource locally from the user's Snow Leopard source without committing Apple content.
- If the fallback is proven but CreateNewWindow still does not return, the resource-name lookup is fixed and the next boundary is inside subsequent TTheme/resource loading; inspect that new diagnostic before any broader resource work.
- If the Snow forced-external control fails, do not run Lion: the external-resource mechanism itself has not been validated.
- No substitution with Lion's `Extras2.rsrc` is authorized.
- No additional XNU change is indicated.

## Returned Phase G result

The forced external-resource Snow control passed: the exact target was redirected to the staged Snow `Extras.rsrc` twice, both fallbacks were non-NULL, and CreateNewWindow returned 0 with a nonzero WindowRef and reached M24.

The Lion run also proved that the resource compatibility mechanism itself worked. After the first three reviewed notification registrations were accepted, the exact HIToolbox `Extras` / `rsrc` target was reached twice; Lion's original CFBundle lookup returned NULL both times and the exact staged Snow resource fallback returned NONNULL both times. The previous HIToolbox resource warning and TTheme `-4960` abort did not recur.

Execution then exposed a new fourth legacy distributed-notification request:

```text
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=4 ... payload=287
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REQUEST:length=287 status=25 createwindowRegister=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT:status=25 createwindowRegister=YES
```

In the reviewed registration broker, status 25 is `BROKER_REJECT_NAME`: the broker's allowlist contains only the three notification names observed before the missing-resource boundary. The resource fallback therefore advanced execution beyond TTheme and uncovered previously unreachable notification traffic; the `CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PROTOCOL_REJECTED` runner label does not mean that the exact resource fallback regressed.

The subject continued to `M21_AFTER_CreateNewWindow` and returned `CreateNewWindow=-304`, after a later `com.apple.dock.server` bootstrap passthrough failed with `-304`. That downstream CGS/bootstrap boundary is recorded but is not yet the next modification target.

Current `main` advances to:

```text
docs/process-manager-createwindow-post-extras-distributed-notification-schema-audit.md
```

That stage preserves the exact first three native registrations and exact Snow `Extras.rsrc` fallback, captures the full fourth request dictionary, and deliberately continues to reject it with status 25. No fourth notification policy, dock-server compatibility change, or XNU change is authorized until that request is reviewed.

