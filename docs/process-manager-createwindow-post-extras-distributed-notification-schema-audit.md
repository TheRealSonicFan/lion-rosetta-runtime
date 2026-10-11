# Process Manager CreateNewWindow post-Extras distributed-notification schema audit

## Objective

The exact Snow `Extras.rsrc` fallback experiment advanced the Lion CreateNewWindow path beyond the previously confirmed TTheme abort.

The returned Lion run proved all of the following in one execution:

- the exact staged Snow Leopard 10.6.8 `Extras.rsrc` hash matched the accepted resource identity;
- the PPC HIToolbox compatibility interposer matched the exact `com.apple.HIToolbox` / `Extras` / `rsrc` lookup twice;
- Lion's original lookup returned NULL both times and the process-local external fallback returned NONNULL both times;
- the old `HIToolbox: failed to copy resource URL for framework bundle.` / TTheme `-4960` abort did not recur;
- after the fallback, a **fourth** legacy distributed-notification request crossed the process-local `.2` ingress;
- the reviewed registration broker returned status 25 for that fourth request;
- the subject continued far enough to load `libCSync.A.dylib`, perform a `com.apple.dock.server` bootstrap lookup, reach `M21_AFTER_CreateNewWindow`, and return `CreateNewWindow=-304` rather than aborting inside TTheme;
- protected hashes remained unchanged.

In the current exact registration broker, status 25 is `BROKER_REJECT_NAME`. That broker intentionally contains only the three notification names previously observed before the missing-resource boundary. The fourth request is therefore not evidence that the exact Snow resource fallback failed; it is a newly exposed request that the previous three-name review could not have observed because execution stopped earlier.

The next controlled question is only: **what is the exact fourth request dictionary?**

Do not authorize that request yet. First capture its full binary-plist/XML schema while retaining the proven native registration semantics for the first three registrations and retaining the exact Snow `Extras.rsrc` fallback.

## Prepared files

Current `main` adds:

```text
tests/native-distributed-notifications-createwindow-post-extras-schema-audit-broker.c
scripts/build-lion-native-distributed-notifications-createwindow-post-extras-schema-audit-broker.sh
docs/process-manager-createwindow-post-extras-distributed-notification-schema-audit.md
```

and extends:

```text
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

with an opt-in post-Extras schema-audit mode.

New native broker build ID:

```text
distributed-notifications-createwindow-post-extras-schema-audit-broker-v1
```

This broker preserves the accepted behavior for the three reviewed registrations:

```text
com.apple.MCX._managementStatusChangedForDomains
com.apple.CFPreferences._domainsChangedExternally
AppleColorPreferencesChangedNotification
```

When the next request is otherwise valid but fails only the reviewed-name predicate, the broker:

1. writes that request's exact binary plist and XML representation to the requested audit report;
2. logs one `PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_CAPTURE` marker;
3. deliberately returns the same status 25 (`BROKER_REJECT_NAME`) to the PPC client;
4. does **not** add a native CFNotificationCenter observer for the unknown request;
5. treats exactly one such intentional capture, after the exact first three registrations, as a successful diagnostic audit.

This preserves the observed request semantics instead of silently broadening notification policy.

## Safety constraints

For this stage:

- reuse the exact PPC CreateNewWindow subject unchanged;
- reuse the exact combined CoreServices/CPS/distributed-notifications compatibility dylib unchanged;
- reuse the exact Security and CGS compatibility dylibs unchanged;
- reuse the already-built exact PPC HIToolbox `Extras.rsrc` compatibility dylib unchanged;
- reuse the exact staged Snow Leopard `Extras.rsrc` unchanged;
- build only the new native i386 post-Extras schema-audit broker on Lion;
- do not rebuild any PPC artifact;
- do not rerun the Snow control; it already proved the forced external-resource path;
- do not accept or register the fourth notification yet;
- do not modify the `Extras.rsrc` compatibility predicate;
- do not alter the `com.apple.dock.server` path yet;
- do not modify system frameworks, Rosetta, dyld, launchd, WindowServer, distnoted, shared caches, or XNU.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current runtime main on Lion

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Keep the exact resource and PPC compatibility artifacts from the preceding accepted experiment.

## Phase B — build the native post-Extras schema-audit broker on Lion

Syntax-check:

```sh
/bin/bash -n ./scripts/build-lion-native-distributed-notifications-createwindow-post-extras-schema-audit-broker.sh
```

Build:

```sh
/bin/bash ./scripts/build-lion-native-distributed-notifications-createwindow-post-extras-schema-audit-broker.sh \
  ./native-distributed-notifications-createwindow-post-extras-schema-audit-broker
```

Require:

```text
i386 Mach-O
build_id=distributed-notifications-createwindow-post-extras-schema-audit-broker-v1
CFPropertyListCreateWithData import
CFPropertyListCreateData import
CFNotificationCenterGetDistributedCenter import
CFNotificationCenterAddObserver import
CFNotificationCenterRemoveObserver import
all three previously reviewed notification-name literals
post-Extras schema-audit capture marker
post-Extras schema-audit summary marker
SHA-256 sidecar
info sidecar
```

## Phase C — repeat the syscall-295 safety gate

Repeat the established Lion syscall-295 routing probe and require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Stop if the kernel identity or syscall routing changed.

## Phase D — exactly one Lion post-Extras schema-audit run

Do not load the older CFBundle trace dylib.

Retain the exact resource compatibility settings from the preceding Phase G:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'

unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1

export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-register-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT="$PWD/payload/lion-ppc-process-manager-createwindow-post-extras-distnotify-schema-audit.txt"
```

Syntax-check the established Lion runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Run the same accepted Lion integration command as the preceding exact-resource experiment, except replace positional broker arguments 9 and 10 with:

```text
./native-distributed-notifications-createwindow-post-extras-schema-audit-broker
./native-distributed-notifications-createwindow-post-extras-schema-audit-broker.sha256
```

and use a new report path such as:

```text
payload/lion-ppc-process-manager-createwindow-post-extras-distnotify-schema-audit.log
```

The diagnostic pass requires:

```text
three previously reviewed registration accepts
at least one exact HIToolbox Extras target
mode=lion-fallback-external-v1 original=NULL fallback=NONNULL
exactly four legacy Mach requests
exactly one PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_CAPTURE
PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REJECT:status=25 intentional=YES
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=3 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:POST_EXTRAS_AUDIT_PASS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_DISTNOTIFY_POST_EXTRAS_SCHEMA_AUDIT_PASS
```

The audit report must contain exactly one:

```text
=== POST_EXTRAS_REQUEST 1 BEGIN ===
...
=== POST_EXTRAS_REQUEST 1 END ===
```

with the full binary plist hex and XML dictionary.

The fourth request is intentionally still rejected in this run. A subsequent `CreateNewWindow=-304` and/or the already observed `com.apple.dock.server` lookup is not a failure of this diagnostic stage; those are downstream evidence to analyze only after the fourth notification request has been reviewed.

## Phase E — return evidence and stop

Return:

```text
native-distributed-notifications-createwindow-post-extras-schema-audit-broker.info.txt
native-distributed-notifications-createwindow-post-extras-schema-audit-broker.sha256
syscall295-probe-process-manager-createwindow-post-extras-distnotify-schema-audit.log
lion-ppc-process-manager-createwindow-post-extras-distnotify-schema-audit.txt
lion-ppc-process-manager-createwindow-post-extras-distnotify-schema-audit.log
lion-ppc-process-manager-createwindow-post-extras-distnotify-schema-audit.raw.log
```

Also return any new crash/core diagnostic named by the runner if one is produced and available.

Do not return or upload the proprietary `SnowLeopard-HIToolbox-Extras.rsrc` file itself.

Stop after Phase E.

## Decision gate

If the fourth request is captured exactly, review its:

```text
message_type
client
name
object
behavior
counter
entry
sessionid
```

and compare it with the three already reviewed registrations and with Snow behavior before adding any registration policy.

Only if that exact request is semantically justified should the native broker be extended. The already observed `com.apple.dock.server` bootstrap failure is a downstream candidate boundary, but it must not be changed in the same experiment.

No XNU change is indicated.
