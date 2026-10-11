# Post-CreateNewWindow window-title fifth distributed-notification schema audit

## Objective

Capture and decode exactly the fifth legacy distributed-notification registration request that becomes the first blocker after the exact FontServer bootstrap compatibility path succeeds.

The accepted live sequence is now:

```text
CreateNewWindow                                    -> 0, nonzero WindowRef
CFStringCreateWithCString                          -> PASS
SetWindowTitleWithCFString                         -> entered
com.apple.FontServer exact Lion lookup             -> Mach success
FontServer reply                                   -> 0x1f8 / 0x28 / one descriptor
FontServer service port                            -> nonzero send right
FontServer adapter                                 -> ADAPTER_PASS
legacy distributed-notification request index 5    -> id 4, size 356, payload 321
exact-four broker                                  -> status 25 / rejected name
SetWindowTitleWithCFString                         -> does not return
```

The fifth request is therefore the next boundary. Its name, object, suspension behavior, entry/counter values, and session scope are not yet known from the existing log. Do not infer or whitelist them from payload length alone.

The prior run also named a crash report and core after the intentional broker rejection. Those diagnostics are downstream of the exact fifth-request rejection and are not required to identify the request schema. Preserve them if they are available, but do not use them to widen compatibility in this stage.

## Prepared files

Current runtime `main` provides:

```text
tests/native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.c
scripts/build-lion-native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-createwindow-windowtitle-fifth-distributed-notification-schema-audit.md
```

Native broker build ID:

```text
distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker-v1
```

Audit report environment variable:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
```

The broker keeps the already accepted first four registrations exact:

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
```

Only after all four are accepted does the broker capture one request rejected solely for an unknown name. It writes the exact binary plist bytes plus an XML property-list representation to the audit report, deliberately returns the same status 25 to the PPC caller, and never registers that fifth request.

## Safety constraints

- Reuse the accepted PPC window-title subject unchanged.
- Reuse the accepted CoreServices, Security, Dock+FontServer bootstrap, HIToolbox Extras/resource, and other compatibility artifacts unchanged.
- Do not rebuild anything on Snow Leopard for this stage.
- Build only the new i386 audit broker on Lion 10.7.5.
- Repeat syscall 295 before the one Lion audit run.
- Keep FontServer compatibility enabled exactly as previously accepted.
- Keep the first four distributed-notification registrations exact and active.
- Capture exactly one fifth request.
- Return status 25 intentionally for that fifth request.
- Do not accept, register, synthesize, edit, replay, or translate the fifth request.
- Do not alter notification callbacks.
- Do not change NewWindow, release-backing, opacity create-alpha, Dock, FontServer, HIToolbox, Process Manager, CPS, or XNU compatibility.
- Do not show/select/query the window or enter the event loop.
- Do not restart or signal distnoted, fontd/FontServer, WindowServer, Dock, launchd, or related jobs.
- Run the Lion audit exactly once before review.
- Preserve every new crash/core diagnostic named by the runner.
- No XNU rebuild or reboot.

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

## Phase B — build only the native fifth-request audit broker on Lion

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-lion-native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.sh

/bin/bash ./scripts/build-lion-native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.sh
```

Expected outputs:

```text
native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker
native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.info.txt
native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.sha256
```

Require:

```text
architecture                  i386
build ID                      distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker-v1
four known registration names present
POST_FONTSERVER capture marker present
POST_FONTSERVER summary marker present
POST_FONTSERVER_AUDIT_PASS marker present
```

Stop if Phase B fails.

## Phase C — repeat syscall 295

Save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase D — exactly one Lion fifth-request audit

Reuse the exact accepted PPC subject and compatibility artifacts from the FontServer integration run.

Unset older audit/passive modes:

```sh
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT="$PWD/payload/lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.txt"
```

Keep the established expected kernel hash. Syntax-check:

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
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.log
```

The runner must observe:

```text
FontServer compatibility calls                     >= 1
FontServer ADAPTER_PASS count                      equals call count
legacy Mach requests                               exactly 5
request index 5                                    bits=0x1111
request index 5                                    id=4
request index 5                                    size=356
request index 5                                    payload=321
first four registration accepts                    exact
POST_FONTSERVER_SCHEMA_AUDIT_CAPTURE               exactly 1
intentional reject                                 status=25
registration summary                               register=4, rejects=0, exact=YES
audit summary                                      captures=1 failures=0 unexpectedRejects=0 exact=YES
broker result                                      POST_FONTSERVER_AUDIT_PASS
RESULT                                             POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_SCHEMA_AUDIT_PASS
```

The subject may still terminate after the intentional rejection. That does not invalidate the audit if the exact capture/broker gates above pass.

## Phase E — inspect the audit report, then stop

The audit report must contain exactly one block:

```text
=== POST_FONTSERVER_REQUEST 1 BEGIN ===
binary_length=321
xml_length=...
binary_hex=...
<?xml ...>
...
=== POST_FONTSERVER_REQUEST 1 END ===
```

Do not add the captured notification to an allowlist yet.

Return:

```text
native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.info.txt
native-distributed-notifications-post-createwindow-windowtitle-fontserver-schema-audit-broker.sha256
syscall295-probe-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.log
lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.log
lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.raw.log
lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-schema-audit.txt
```

Also return every new crash/core diagnostic named by the runner. Stop after review evidence is collected.

## Decision gate

### `POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_SCHEMA_AUDIT_PASS`

Review the XML and exact binary payload. Compare its dictionary shape, client, sessionid, counter, entry, behavior, object semantics, and notification name against the four already accepted registrations and the earlier Snow/Carbon chronology. Only after that review may an exact fifth-registration policy be prepared.

### Audit incomplete or unexpected reject

Do not modify the allowlist. Resolve the capture/broker mismatch first.

## Current boundary

```text
CreateNewWindow                                        -> PASS
CFStringCreateWithCString                              -> PASS
FontServer exact Lion bootstrap lookup                 -> PASS
first four distributed-notification registrations     -> PASS
fifth legacy notification request                     -> id=4 size=356 payload=321
fifth request broker result                            -> status 25 / unknown name
next step                                              -> capture/decode exact fifth binary plist
```

No additional XNU change is indicated.
