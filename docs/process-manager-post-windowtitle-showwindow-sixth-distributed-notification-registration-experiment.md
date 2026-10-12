# Post-ShowWindow exact sixth distributed-notification registration integration

## Objective

Accept only the exact sixth legacy distributed-notification registration proven by the preceding ShowWindow schema audit, then rerun the unchanged ShowWindow subject exactly once to determine the next boundary.

The audit closed the schema ambiguity. Request index 6 is not a new notification name or a new operation. It is another ordinary eight-key `register` record:

```text
message_type  register
client        ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name          AppleAquaColorVariantChanged
object        kCFNotificationAnyObject
behavior      4
counter       2
entry         positive run-time registration identity
sessionid     current established session
```

In the captured run the sixth entry was `0x003a6dc0`, distinct from the already accepted fourth `AppleAquaColorVariantChanged` entry `0x003a6d60`. The filter tuple is otherwise identical to the reviewed fourth request; the only schema-level change is the per-registration `counter` advancing from 1 to 2.

The previously reviewed distributed-notifications ABI treats Snow `entry/counter` as per-registration callback identity that the broker must retain. It is therefore valid to represent this as a second broker registration record for the same reviewed name/filter, using a distinct Lion public observer record and retaining the exact second `entry/counter` pair for callback reconstruction. This does **not** authorize arbitrary duplicate registrations, arbitrary counters, another notification name, or another operation.

## Prepared files

Current runtime `main` provides:

```text
tests/native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.c
scripts/build-lion-native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-windowtitle-showwindow-sixth-distributed-notification-registration-experiment.md
```

Native broker build ID:

```text
distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker-v1
```

Runner registration mode:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-sixth-register-v1
```

The broker is sequence-gated to exactly six accepted registration records:

```text
request  allowed tuple                                        counter
1        MCX management status                                1
2        CFPreferences domains changed                        1
3        AppleColorPreferencesChangedNotification             1
4        AppleAquaColorVariantChanged                         1
5        com_apple_CoreText_FontManagerChangedNotification    1
6        AppleAquaColorVariantChanged                         2
```

The sixth request must keep the reviewed AnyObject scope, legacy behavior 4, a positive unique entry, and the same established session. A seventh request or any sequence/counter/filter mismatch remains rejected.

## Safety constraints

- Reuse the accepted `cps-showwindow-validation-v1` PPC subject unchanged.
- Reuse all accepted CoreServices, Security, CGS, FontServer rendezvous, HIToolbox Extras/resource, and syscall-295 artifacts unchanged.
- Do not rerun or rebuild the Snow Leopard subject for this stage.
- Build only the new native i386 exact-six broker on Lion 10.7.5.
- Repeat syscall 295 before the one Lion integration run.
- Accept only the exact six-request sequence above.
- Do not generalize `counter=2` to arbitrary counters.
- Do not generalize duplicate `AppleAquaColorVariantChanged` registrations.
- Do not add a seventh notification policy.
- Do not change the FontServer rendezvous adapter.
- Do not add a ShowWindow/CGS compatibility adapter yet.
- Do not adapt the color-profile, window-context, tracking-area, RawCamera, CoreUI, or rendering diagnostics in the same run.
- Do not add `SelectWindow`, visibility queries, timers, or an event loop.
- Do not restart or signal WindowServer, distnoted, fontd, Dock, launchd, or related jobs.
- No XNU source change, rebuild, or reboot.
- Run exactly one Lion integration attempt before review.

## Phase A — update repositories

On Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD

cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build only the exact-six broker on Lion

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-lion-native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sh

/bin/bash ./scripts/build-lion-native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sh
```

Expected outputs:

```text
native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker
native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.info.txt
native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256
```

Require:

```text
architecture        i386
build ID            distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker-v1
policy marker       index=6 allowed=3 counter=2
five reviewed names present
CoreFoundation observer imports present
```

Stop if the build gate fails.

## Phase C — repeat syscall 295

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-sixth-notification-registration.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase D — exactly one Lion integration run

Unset all schema-audit modes and unrelated passive traces:

```sh
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set the accepted stack and exact-six broker mode:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-sixth-register-v1
```

Syntax-check the runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Then run exactly once:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-registration.log
```

Require the accepted upstream chain through title assignment and the exact sixth registration:

```text
CreateNewWindow                                      PASS
FontServer rendezvous adapter                        PASS exactly once
fifth registration                                   index=5 allowed=4 counter=1
sixth registration                                   index=6 allowed=3 behavior=4
sixth public behavior                                2 / Coalesce
sixth AnyObject                                      YES
sixth counter                                        2
registration summary                                 register=6 rejects=0 exact=YES
broker result                                        PASS
protected hashes                                     unchanged
```

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS`

Require:

```text
S00_BEFORE_ShowWindow
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
T04_BEFORE_CFRelease
T05_AFTER_CFRelease
M22_BEFORE_DisposeWindow
M23_AFTER_DisposeWindow
M24_SUCCESS
process exit 0
no new crash/core diagnostic
```

This closes the ShowWindow gate. Stop and review before adding any later Carbon operation.

### `POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_REGISTRATION_PASS_SEVENTH_PROTOCOL_REJECTED`

The exact sixth registration is accepted, but a seventh unreviewed distributed-notification request becomes the new boundary. Do not broaden the broker. Capture/decode that exact request next.

### `POST_WINDOWTITLE_SHOWWINDOW_NO_RETURN`

The exact sixth registration is accepted and no further notification request is rejected, but `ShowWindow` still does not return. Only then does the next discriminator move to the already observed ShowWindow-side CoreGraphics/window-context/tracking activity. Do not infer which diagnostic requires adaptation without a passive protocol trace.

### Any broker mismatch

Do not widen the six-request policy. Resolve the exact sequence, counter, entry, session, or build mismatch first.

## Return

Return:

```text
native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.info.txt
native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256
syscall295-probe-process-manager-post-windowtitle-showwindow-sixth-notification-registration.log
lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-registration.log
lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-registration.raw.log
```

Also return every new crash/core diagnostic named by the runner, if any. Stop after this single Lion run.

## Current boundary

```text
CreateNewWindow                              -> PASS
SetWindowTitleWithCFString                   -> PASS
FontServer rendezvous compatibility          -> PASS live
ShowWindow Snow control                      -> PASS
ShowWindow Lion                              -> entered
sixth legacy notification request            -> reviewed register
sixth name/object/behavior                    -> same as accepted request 4
sixth counter                                 -> 2
sixth entry                                   -> distinct positive identity
next step                                     -> exact-six registration integration
later notification/CGS work                  -> held
XNU                                           -> no change indicated
```


## Observed result — exact-six registration accepted; ShowWindow still does not return

The integration run closes the sixth-registration gate. The new native broker built as i386 with the expected build ID and hash, syscall 295 remained healthy, and Lion accepted request 6 exactly as the reviewed second `AppleAquaColorVariantChanged` registration:

```text
index          6
allowed        3
behavior       4
publicBehavior 2
anyObject      YES
counter        2
entry          positive and distinct
```

The broker ended with:

```text
register=6
callback=0
rejects=0
exact=YES
RESULT: PASS
```

No seventh distributed-notification request appeared. All previously accepted FontServer rendezvous, NewWindow, release-backing, and create-alpha compatibility paths remained successful and protected hashes remained unchanged.

The ShowWindow boundary itself remains open: `S00_BEFORE_ShowWindow` is reached, `S01_AFTER_ShowWindow` is absent, the process exits 139, and a new crash/core is generated. The raw log repeats the ShowWindow-side CoreGraphics failure cluster and specifically reports `MIG: server type check failure: CGSAddTrackingArea`.

The authoritative next procedure is:

```text
docs/process-manager-post-windowtitle-showwindow-cgs-passive-transport-trace-experiment.md
```

That stage is behavior-preserving. It traces previously unclassified application-CGS Mach traffic during the ShowWindow call window on Snow and Lion, without adapting any request or reply. No seventh notification policy, color-profile/window-context fix, or XNU change is authorized.
