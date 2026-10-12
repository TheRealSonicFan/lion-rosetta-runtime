# Post-ShowWindow sixth distributed-notification schema audit

## Objective

Capture and decode exactly the sixth legacy distributed-notification request reached after the accepted window-title path enters `ShowWindow`.

The first isolated Lion `ShowWindow` run did not reach `S01_AFTER_ShowWindow`. The accepted upstream chain remained intact through the single FontServer rendezvous conversion and successful title assignment. After `S00_BEFORE_ShowWindow`, the ingress bridge observed a new sixth distributed-notification request:

```text
request index             6
Mach bits                 0x00001111
message id                4
Mach message size         320
binary-plist payload      287
exact-five broker status  20 / BROKER_REJECT_SCHEMA
```

The exact-five broker then reported one reject, the subject exited 139, and Lion named a crash report plus core. `S01_AFTER_ShowWindow` was not reached. Protected hashes remained unchanged.

Status 20 proves only that the sixth payload does not satisfy the current exact-eight-key registration predicate. It does not establish the sixth operation, dictionary shape, notification name, object semantics, behavior, or scope. Do not infer or whitelist any sixth request from the payload length or the status code.

The same ShowWindow subject completed `S01_AFTER_ShowWindow`, `SHOWWINDOW_PASS`, release, disposal, and final success on Snow Leopard. The next safe discriminator is therefore a read-only capture/decode of the exact sixth Lion payload while preserving the observed status-20 rejection.

The CoreGraphics color-profile/context and `CGSAddTrackingArea` diagnostics seen after `S00` remain unreviewed. Do not adapt them in this audit. First close the controlled sixth-request boundary.

## Prepared files

Current runtime `main` provides:

```text
tests/native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.c
scripts/build-lion-native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-windowtitle-showwindow-sixth-distributed-notification-schema-audit.md
```

Native broker build ID:

```text
distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker-v1
```

Audit report environment variable:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
```

The audit broker keeps the five reviewed registrations exact and active:

```text
0  com.apple.MCX._managementStatusChangedForDomains
   object=com.apple.MCX
   legacy behavior=1

1  com.apple.CFPreferences._domainsChangedExternally
   object=com.apple.CFPreferences
   legacy behavior=1

2  AppleColorPreferencesChangedNotification
   object=kCFNotificationAnyObject
   legacy behavior=4

3  AppleAquaColorVariantChanged
   object=kCFNotificationAnyObject
   legacy behavior=4

4  com_apple_CoreText_FontManagerChangedNotification
   object=kCFNotificationAnyObject
   legacy behavior=1
```

Only after all five have been accepted does it capture the next request as exact binary plist bytes plus XML. It deliberately returns status 20, matching the observed exact-five broker rejection, and does not accept or register the sixth request.

## Safety constraints

- Reuse the already-built `cps-showwindow-validation-v1` PPC subject unchanged.
- Reuse the accepted CoreServices, Security, HIToolbox Extras/resource, FontServer rendezvous v5, and other compatibility artifacts unchanged.
- Do not rebuild the PPC subject or rerun Snow Leopard for this stage.
- Build only the new native i386 audit broker on Lion 10.7.5.
- Repeat syscall 295 before the one Lion audit run.
- Keep the exact five reviewed notification registrations active.
- Capture exactly one sixth request.
- Preserve the observed status-20 rejection for that request.
- Do not accept, register, synthesize, edit, replay, or translate the sixth request.
- Do not broaden the distributed-notification schema.
- Do not change the FontServer rendezvous rule.
- Do not add a ShowWindow/CGS compatibility adapter.
- Do not adapt color-profile, window-context, tracking-area, rendering, RawCamera, or CoreUI traffic in this run.
- Do not add `SelectWindow`, `IsWindowVisible`, timers, or the event loop.
- Do not restart or signal WindowServer, fontd, distnoted, launchd, Dock, or related jobs.
- Preserve every crash/core diagnostic named by the runner if available.
- No XNU source change, rebuild, or reboot.
- Run the Lion audit exactly once before review.

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

## Phase B — build only the sixth-request audit broker on Lion

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-lion-native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.sh

/bin/bash ./scripts/build-lion-native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.sh
```

Expected outputs:

```text
native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker
native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.info.txt
native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.sha256
```

Require:

```text
architecture                          i386
build ID                              distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker-v1
five reviewed registration names     present
POST_SHOWWINDOW capture marker        present
POST_SHOWWINDOW reject marker         present
POST_SHOWWINDOW summary marker        present
POST_SHOWWINDOW_AUDIT_PASS marker     present
```

Stop if Phase B fails.

## Phase C — repeat syscall 295

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase D — exactly one Lion sixth-request audit

Unset older audit and unrelated passive-trace modes:

```sh
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set the accepted stack plus the new audit output:

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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-windowtitle-fontserver-register-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT="$PWD/payload/lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.txt"
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
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.log
```

The runner must observe the accepted chain through:

```text
CreateNewWindow                                      PASS
first five notification registrations               accepted exactly
FontServer bootstrap                                 PASS
first FontServer rendezvous adapter                  PASS exactly once
SetWindowTitleWithCFString                           0
SETWINDOWTITLE_PASS                                  reached
S00_BEFORE_ShowWindow                                reached
```

Then require:

```text
legacy Mach request count                            6
request index 6                                      bits=0x1111
request index 6                                      id=4
request index 6                                      size=320
request index 6                                      payload=287
POST_SHOWWINDOW_SCHEMA_AUDIT_CAPTURE                 exactly 1
intentional reject                                   status=20
registration summary                                 register=5 callback=0 rejects=0 exact=YES
audit summary                                        captures=1 failures=0 unexpectedRejects=0 exact=YES
broker result                                        POST_SHOWWINDOW_AUDIT_PASS
protected hashes                                     unchanged
RESULT                                               POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_SCHEMA_AUDIT_PASS
```

The subject may again exit after the intentional rejection and may name crash/core diagnostics. That does not invalidate the audit if the exact capture/broker gates pass. Preserve those diagnostics if available, but do not use them to broaden compatibility before the sixth payload is reviewed.

## Phase E — inspect the audit report, then stop

The audit report must contain exactly one block:

```text
=== POST_SHOWWINDOW_REQUEST 1 BEGIN ===
binary_length=287
xml_length=...
binary_hex=...
<?xml ...>
...
=== POST_SHOWWINDOW_REQUEST 1 END ===
```

Do not add any sixth notification policy yet.

Return:

```text
native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.info.txt
native-distributed-notifications-post-windowtitle-showwindow-sixth-schema-audit-broker.sha256
syscall295-probe-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.log
lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.log
lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.raw.log
lion-ppc-process-manager-post-windowtitle-showwindow-sixth-notification-schema-audit.txt
```

Also return each crash/core diagnostic named by the audit run if available. Stop after evidence collection.

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_SIXTH_NOTIFICATION_SCHEMA_AUDIT_PASS`

Review the XML and exact binary bytes before deciding whether the sixth request is another registration or a different operation/schema. Only an exact reviewed request may become a compatibility policy.

### Capture or broker mismatch

Do not modify the allowlist. Resolve the audit mismatch first.

## Current boundary

```text
CreateNewWindow                              -> PASS
SetWindowTitleWithCFString                   -> PASS
FontServer rendezvous compatibility          -> PASS live
ShowWindow Snow control                      -> PASS
ShowWindow Lion                              -> entered, no return
sixth legacy notification request            -> id=4 size=320 payload=287
exact-five broker result                     -> status 20 / schema reject
next step                                    -> capture/decode exact sixth binary plist
SelectWindow / visibility / event loop       -> held
XNU                                          -> no change indicated
```


## Observed result — sixth request is a second reviewed Aqua-variant registration

The audit passed exactly once. The captured 287-byte binary plist decodes as an eight-key `register` dictionary:

```text
message_type  register
client        ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name          AppleAquaColorVariantChanged
object        kCFNotificationAnyObject
behavior      4
counter       2
entry         3829184 / 0x003a6dc0 in the captured run
sessionid     78 in the captured run
```

This is not a sixth notification name. It is a second registration for the already reviewed `AppleAquaColorVariantChanged` filter. The first registration for that filter in the same run was request index 4 with behavior 4, AnyObject scope, counter 1, and entry `0x003a6d60`; the sixth entry is distinct and the counter advances to 2.

The existing ABI model already treats Snow `entry/counter` as per-registration callback identity retained by the bridge. The exact next policy therefore does not relax the broker to arbitrary duplicates or arbitrary counters: it permits only the observed six-request sequence, with request 6 fixed to allowed tuple 3 and counter 2, a positive unique entry, and the established session.

The authoritative next procedure is:

```text
docs/process-manager-post-windowtitle-showwindow-sixth-distributed-notification-registration-experiment.md
```

Build only the new native exact-six broker on Lion, repeat syscall 295, and rerun the unchanged ShowWindow subject exactly once. If a seventh notification request appears, reject it and stop for another schema audit; if no further notification request is rejected but `ShowWindow` still does not return, only then advance to a passive ShowWindow-side CGS/window-context discriminator. No XNU change is indicated.
