# Process Manager CreateNewWindow exact fourth distributed-notification registration

## Objective

The post-Extras schema audit passed and captured exactly one newly reachable fourth legacy distributed-notification request after the exact Snow Leopard HIToolbox `Extras.rsrc` fallback.

The captured request is an ordinary eight-key `register` dictionary:

```text
message_type = register
client       = ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name         = AppleAquaColorVariantChanged
object       = kCFNotificationAnyObject
behavior     = 4
counter      = 1
entry        = run-time registration identity
sessionid    = current session identifier
```

It is structurally the same registration form already reviewed for `AppleColorPreferencesChangedNotification`: any-object scope, legacy behavior 4, counter 1, the same PPC client identity, and the same per-run session. The existing ABI audit maps legacy behavior 4 to public `CFNotificationSuspensionBehaviorCoalesce`.

The notification is also present in the Snow Leopard HIToolbox string inventory in the same appearance-preference cluster as `AppleColorPreferencesChangedNotification`, and it is present in Lion HIToolbox as well. Combined with the live request being emitted by the restored Snow PPC client only after the exact Snow theme resource becomes usable, this is sufficient to authorize **only this exact fourth registration**. It does not authorize any fifth name, wildcard policy, new operation, all-session behavior, or broader notification compatibility.

The next controlled question is whether accepting this exact fourth registration closes the distributed-notification boundary and leaves the already observed `com.apple.dock.server` bootstrap failure as the next CreateNewWindow boundary.

## Prepared files

Current `main` adds:

```text
tests/native-distributed-notifications-createwindow-post-extras-registration-broker.c
scripts/build-lion-native-distributed-notifications-createwindow-post-extras-registration-broker.sh
docs/process-manager-createwindow-post-extras-distributed-notification-registration-experiment.md
```

and extends:

```text
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

with the opt-in mode:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

New native broker build ID:

```text
distributed-notifications-createwindow-post-extras-registration-broker-v1
```

The broker accepts exactly these four simultaneous registrations and no others:

```text
1. com.apple.MCX._managementStatusChangedForDomains
   object=com.apple.MCX
   legacy behavior=1

2. com.apple.CFPreferences._domainsChangedExternally
   object=com.apple.CFPreferences
   legacy behavior=1

3. AppleColorPreferencesChangedNotification
   object=kCFNotificationAnyObject
   legacy behavior=4

4. AppleAquaColorVariantChanged
   object=kCFNotificationAnyObject
   legacy behavior=4
```

All four retain the existing exact schema checks, common-session enforcement, distinct `entry` state, callback reconstruction, and public CoreFoundation distributed-notification backend. Every unreviewed name or operation is still rejected.

## Safety constraints

For this stage:

- reuse the exact PPC CreateNewWindow subject unchanged;
- reuse the exact combined CoreServices/CPS/distributed-notifications compatibility dylib unchanged;
- reuse the exact Security and CGS compatibility dylibs unchanged;
- reuse the exact PPC HIToolbox `Extras.rsrc` compatibility dylib unchanged;
- reuse the SHA-pinned staged Snow Leopard `Extras.rsrc` unchanged;
- build only the new native i386 exact-four-registration broker on Lion;
- do not rebuild any PPC artifact;
- do not rerun the Snow resource control;
- accept only `AppleAquaColorVariantChanged` as the fourth reviewed name;
- do not accept any additional notification if one appears;
- do not alter the `com.apple.dock.server` lookup in this experiment;
- do not modify HIToolbox, CoreFoundation, Rosetta, dyld, launchd, distnoted, WindowServer, shared caches, or XNU.

No XNU rebuild or reboot is part of this stage.

## Phase A — update current runtime main on Lion

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

Keep the accepted exact resource and PPC compatibility artifacts from the preceding experiments.

## Phase B — build the exact-four native registration broker

Syntax-check:

```sh
/bin/bash -n ./scripts/build-lion-native-distributed-notifications-createwindow-post-extras-registration-broker.sh
```

Build:

```sh
/bin/bash ./scripts/build-lion-native-distributed-notifications-createwindow-post-extras-registration-broker.sh \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker
```

Require:

```text
i386 Mach-O
build_id=distributed-notifications-createwindow-post-extras-registration-broker-v1
CFPropertyListCreateWithData import
CFPropertyListCreateData import
CFNotificationCenterGetDistributedCenter import
CFNotificationCenterAddObserver import
CFNotificationCenterRemoveObserver import
all four exact notification-name literals
kCFNotificationAnyObject literal
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

Stop if the kernel identity or routing result changed.

## Phase D — exactly one Lion exact-four-registration run

Do not load the older CFBundle trace dylib and do not set the post-Extras schema-audit report variable.

Retain the exact resource compatibility settings:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256='<established Lion mach_kernel SHA-256>'

unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1

export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Syntax-check the established Lion runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Run the same accepted Lion integration command as the preceding schema-audit stage, except use these positional broker arguments:

```text
./native-distributed-notifications-createwindow-post-extras-registration-broker
./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256
```

Use a new report path such as:

```text
payload/lion-ppc-process-manager-createwindow-post-extras-registration.log
```

The exact-four notification gate requires:

```text
four PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT markers
no PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_REJECT marker
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=4 callback=<n> rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
at least one exact HIToolbox Extras target
mode=lion-fallback-external-v1 original=NULL fallback=NONNULL
protected_hashes_unchanged=YES
```

If a fifth or otherwise unreviewed request appears and is rejected, stop on:

```text
RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATION_PROTOCOL_REJECTED
```

Do not broaden the broker in the same run.

If all four registrations are established and the already observed dock lookup remains the next failure:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=NON_TARGET ... name=com.apple.dock.server
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=-304 ...
PM_POSTIDENTITY_MILESTONE:M21_AFTER_CreateNewWindow
PM_POSTIDENTITY_STATUS:CreateNewWindow=-304
RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATIONS_ESTABLISHED_DOCK_SERVER_MINUS304
```

stop there. That result closes the currently reviewed notification sequence as the immediate blocker and promotes the exact `com.apple.dock.server` bootstrap lookup to the next diagnostic boundary. Do not modify the dock lookup in this experiment.

A stronger success is:

```text
PM_POSTIDENTITY_STATUS:CreateNewWindow=0
nonzero WindowRef
M23_AFTER_DisposeWindow
M24_SUCCESS
RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATION_PASS
```

## Phase E — return evidence and stop

Return:

```text
native-distributed-notifications-createwindow-post-extras-registration-broker.info.txt
native-distributed-notifications-createwindow-post-extras-registration-broker.sha256
syscall295-probe-process-manager-createwindow-post-extras-registration.log
lion-ppc-process-manager-createwindow-post-extras-registration.log
lion-ppc-process-manager-createwindow-post-extras-registration.raw.log
```

Also return any new crash/core diagnostic named by the runner if one is produced and available.

Do not return or upload the proprietary `SnowLeopard-HIToolbox-Extras.rsrc` file itself.

Stop after Phase E.

## Decision gate

- If `CREATENEWWINDOW_POST_EXTRAS_REGISTRATIONS_ESTABLISHED_DOCK_SERVER_MINUS304` is reached, distributed-notification registration is no longer the immediate boundary. The next stage must audit the exact Snow-versus-Lion `com.apple.dock.server` bootstrap contract before changing CGS/bootstrap compatibility.
- If `CREATENEWWINDOW_POST_EXTRAS_REGISTRATION_PASS` is reached, CreateNewWindow has succeeded with the exact four-registration notification policy and exact Snow theme-resource fallback; advance to the next post-window lifecycle milestone.
- If a fifth request is rejected, capture and review that exact request before extending policy.
- No wildcard notification policy is authorized.
- No XNU change is indicated.


## Observed result — exact four registrations established; Dock lookup is next boundary

The Lion exact-four run reached:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=4 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=NON_TARGET ... name=com.apple.dock.server
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=-304 ... servicePort=0
PM_POSTIDENTITY_STATUS:CreateNewWindow=-304
RESULT: CREATENEWWINDOW_POST_EXTRAS_REGISTRATIONS_ESTABLISHED_DOCK_SERVER_MINUS304
```

No new crash/core diagnostic was produced and protected hashes remained unchanged. This closes the reviewed four-registration distributed-notification sequence as the immediate blocker. The exact Snow `Extras.rsrc` fallback also remains established; neither notification policy nor HIToolbox resource compatibility should be broadened further at this boundary.

The authoritative next stage is:

```text
docs/process-manager-createwindow-dockserver-bootstrap-protocol-adapter-experiment.md
```

That stage is deliberately standalone. It first proves ordinary `bootstrap_look_up("com.apple.dock.server")` on Snow Leopard, then sends exactly one already-established Lion-format `0xbc` launchd lookup request on Lion with PID 0, zero instance UUID, and flags 0. It does not rerun CreateNewWindow or integrate Dock lookup compatibility yet. No XNU change is indicated.
