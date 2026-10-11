# Process Manager CreateNewWindow exact distributed-notification registrations

## Objective

The real-schema audit is complete. The Lion run captured exactly three legacy requests, all of them `register` operations, with no capture failures and unchanged protected hashes. The three dictionaries are:

| Registration | name | object | behavior |
| --- | --- | --- | ---: |
| 1 | `com.apple.MCX._managementStatusChangedForDomains` | `com.apple.MCX` | 1 |
| 2 | `com.apple.CFPreferences._domainsChangedExternally` | `com.apple.CFPreferences` | 1 |
| 3 | `AppleColorPreferencesChangedNotification` | `kCFNotificationAnyObject` | 4 |

All three also contain the same eight-key shape:

`behavior`, `client`, `counter`, `entry`, `message_type`, `name`, `object`, and `sessionid`.

In the captured run, `client` is the accepted CreateNewWindow subject, `counter=1`, all three `sessionid` values are the same, and each `entry` is a distinct run-time identity.

This closes the schema question that blocked the first integrated broker retry. The original standalone broker cannot simply have its proof-name predicate removed: it stores only one active registration, while the real CreateNewWindow path installs three registrations before returning. The third request also carries Snow's serialized `kCFNotificationAnyObject` sentinel, which must be normalized to a public CoreFoundation any-object registration rather than treated as a literal object string.

The next single experiment therefore installs only these three reviewed registrations through Lion's public native distributed-notification API and retries `CreateNewWindow`.

## Prepared files

Current `main` adds:

```text
tests/native-distributed-notifications-createwindow-registration-broker.c
scripts/build-lion-native-distributed-notifications-createwindow-registration-broker.sh
docs/process-manager-createwindow-distributed-notifications-real-registration-experiment.md
```

and extends:

```text
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

with the opt-in mode:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-register-v1
```

The registration broker build ID is:

```text
distributed-notifications-createwindow-registration-broker-v1
```

## Exact compatibility policy

This stage is deliberately narrower than a general distributed-notification bridge.

The broker accepts only:

- `message_type=register`;
- the exact accepted CreateNewWindow client basename;
- exactly the three name/object/behavior tuples listed above;
- the exact eight-key register dictionary shape;
- `counter=1`;
- positive run-time `entry` identities;
- one common non-empty `sessionid` across the three registrations;
- one occurrence of each reviewed tuple.

The first two registrations pass their exact object strings to `CFNotificationCenterAddObserver`. The third maps the serialized `kCFNotificationAnyObject` sentinel to a NULL public object filter. The broker retains each registration's `entry/counter` pair so a native callback can be reconstructed into the already-proven legacy callback payload if one occurs.

The broker rejects all `post`, `unregister`, `suspend`, `session_reset`, unknown-name, duplicate-registration, extra-key, and otherwise unreviewed requests in this experiment. If a new request appears, stop and review it rather than broadening policy in the same run.

## Safety constraints

For this stage:

- reuse the exact accepted PPC CreateNewWindow subject unchanged;
- reuse the exact accepted combined CoreServices/CPS/distributed-notifications compatibility dylib unchanged;
- reuse the exact accepted Security and CGS compatibility dylibs unchanged;
- do not rebuild any PPC artifact;
- build only the new native i386 registration broker on Lion;
- do not expose a global `.2` service;
- do not modify launchd, distnoted, WindowServer, CoreFoundation, HIToolbox, Rosetta, dyld, shared caches, or XNU;
- do not add wildcard notification-name policy;
- do not authorize post/unregister/session-reset/suspend semantics;
- perform exactly one Lion CreateNewWindow run and stop.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current main

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build the exact registration broker on Lion

Syntax-check the builder:

```sh
/bin/bash -n ./scripts/build-lion-native-distributed-notifications-createwindow-registration-broker.sh
```

Then build:

```sh
/bin/bash ./scripts/build-lion-native-distributed-notifications-createwindow-registration-broker.sh \
  ./native-distributed-notifications-createwindow-registration-broker
```

Require:

```text
i386 Mach-O
build_id=distributed-notifications-createwindow-registration-broker-v1
all three reviewed notification names present
kCFNotificationAnyObject sentinel present
CFNotificationCenterGetDistributedCenter import
CFNotificationCenterAddObserver import
CFNotificationCenterRemoveObserver import
SHA-256 sidecar
info sidecar
```

Do not use the older standalone proof broker for this run.

## Phase C — repeat the established native safety gate

Repeat the existing syscall-295 compatibility probe and require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Do not continue if the kernel identity or syscall behavior has changed.

## Phase D — exactly one Lion real-registration CreateNewWindow run

Syntax-check the integration runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Set the established kernel SHA and run once from the logged-in Aqua console user's Terminal:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'

ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-register-v1 \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-registration-broker \
  ./native-distributed-notifications-createwindow-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-distnotify-real-registration.log
```

The strongest success result is:

```text
three PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT markers
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=3 callback=<n> rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
M21_AFTER_CreateNewWindow
PM_POSTIDENTITY_STATUS:CreateNewWindow=0
nonzero WindowRef
M23_AFTER_DisposeWindow
M24_SUCCESS
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PASS
```

If all three registrations are accepted but `CreateNewWindow` still does not return, the runner must report:

```text
RESULT: CREATENEWWINDOW_DISTNOTIFY_REGISTRATIONS_ESTABLISHED_CREATEWINDOW_NO_RETURN
```

That result would move the boundary beyond the reviewed notification-registration schema and require analysis of the new crash/core and any immediately preceding log activity before another compatibility change.

If the broker rejects a new request, stop on:

```text
RESULT: CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PROTOCOL_REJECTED
```

and return the raw log before changing policy.

## Phase E — return evidence and stop

Return:

```text
native-distributed-notifications-createwindow-registration-broker.info.txt
native-distributed-notifications-createwindow-registration-broker.sha256
syscall295-probe-process-manager-createwindow-distnotify-real-registration.log
lion-ppc-process-manager-createwindow-distnotify-real-registration.log
lion-ppc-process-manager-createwindow-distnotify-real-registration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner if one is produced.

Stop after Phase E.

## Decision gate

- If `CREATENEWWINDOW_DISTNOTIFY_REAL_REGISTRATION_PASS` is reached, the three real registration semantics are sufficient for this CreateNewWindow path and the investigation advances beyond window creation.
- If the exact registration summary passes but `CreateNewWindow` still aborts, do not broaden distributed-notification policy automatically; analyze the new post-registration boundary.
- If any unreviewed request is rejected, audit that exact request first.
- No additional XNU change is indicated by the current evidence.

## Returned Phase D result

The completed Lion exact-registration run returned:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=3 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
createwindow_validation_exec_status=134
protected_hashes_unchanged=YES
RESULT: CREATENEWWINDOW_DISTNOTIFY_REGISTRATIONS_ESTABLISHED_CREATEWINDOW_NO_RETURN
```

Immediately after the third reviewed registration was accepted, HIToolbox again logged the framework-bundle resource URL failure and TTheme damage `-4960`, and `M21_AFTER_CreateNewWindow` was not reached. This closes distributed-notification registration as the immediate blocker: no registration was rejected, no callback occurred, and no further legacy notification operation was observed before the abort.

The historical Library record now becomes directly relevant to the next unresolved boundary. Snow PPC HIToolbox `_MakeThemeFSRef` requests the `Extras` / `rsrc` resource through `CFBundleCopyResourceURLForLocalization`; Snow's HIToolbox bundle contains `Extras.rsrc`, while Lion's contains `Extras2.rsrc` but not `Extras.rsrc`. A prior standalone PPC CFBundle probe reproduced that resource-URL differential. However, `Extras.rsrc` and `Extras2.rsrc` are not byte-equivalent resource payloads, so no redirection or substitution is authorized.

Current `main` therefore advances to:

```text
docs/process-manager-createwindow-hitoolbox-cfbundle-live-trace-experiment.md
```

That experiment is pass-through and diagnostic only: it traces the exact live `com.apple.HIToolbox` / `Extras` / `rsrc` CFBundle lookup first on Snow's successful CreateNewWindow control and then once on Lion with the now-proven three-registration broker. No additional distributed-notification semantics and no XNU change are indicated.

