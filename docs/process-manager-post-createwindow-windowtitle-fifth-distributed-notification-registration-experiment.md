# Post-CreateNewWindow window-title fifth distributed-notification registration experiment

## Objective

Accept only the now-reviewed fifth legacy distributed-notification registration exposed by the live FontServer-compatible title path, then rerun the unchanged PPC window-title subject exactly once.

The fifth-request schema audit passed and captured one exact eight-key registration dictionary:

```text
message_type  register
client        ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name          com_apple_CoreText_FontManagerChangedNotification
object        kCFNotificationAnyObject
behavior      1
counter       1
entry         positive per-process registration value
sessionid     same session scope as the first four registrations
```

The captured run used `sessionid="78"` and `entry=3854864`; these are runtime values, not constants to hard-code. The broker therefore preserves the existing policy: session ID must equal the already established session ID, counter must be 1, entry must be positive and unique, and the name/object/behavior tuple must match exactly.

This fifth request is structurally consistent with the four already reviewed registrations: the same eight dictionary keys, same client, same session scope and counter semantics, the established `kCFNotificationAnyObject` sentinel, and legacy behavior 1, which the existing bridge already maps to `CFNotificationSuspensionBehaviorDeliverImmediately` for the first two accepted registrations.

## Prepared implementation

Current runtime `main` provides:

```text
tests/native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.c
scripts/build-lion-native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-createwindow-windowtitle-fifth-distributed-notification-registration-experiment.md
```

Native broker build ID:

```text
distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker-v1
```

New runner registration mode:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-windowtitle-fontserver-register-v1
```

The broker allowlist contains exactly five entries. Entry 4 is:

```text
name       com_apple_CoreText_FontManagerChangedNotification
object     kCFNotificationAnyObject
behavior   1
```

No wildcard name or behavior is added.

## Safety constraints

- Reuse the accepted PPC window-title subject unchanged.
- Reuse the accepted CoreServices, Security, Dock+FontServer bootstrap, HIToolbox Extras/resource, NewWindow, release-backing, and opacity create-alpha artifacts unchanged.
- Build only the new native i386 exact-five broker on Lion 10.7.5.
- Do not rebuild anything on Snow Leopard.
- Repeat syscall 295 before the one Lion integration run.
- Keep FontServer compatibility exactly as accepted.
- Accept exactly the five reviewed notification registrations; no sixth name is authorized.
- Keep callback translation unchanged.
- If a sixth request is rejected, stop and audit that request before widening the broker.
- Do not modify CoreText, ATS, CoreGraphics, HIToolbox, FontServer/fontd, distnoted, launchd, Rosetta, dyld, caches, or XNU.
- Do not show/select/query the window or enter the event loop.
- Do not restart or signal system services.
- Run exactly once before review.
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

## Phase B — build only the exact-five native broker on Lion

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-lion-native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sh

/bin/bash ./scripts/build-lion-native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sh
```

Expected outputs:

```text
native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker
native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.info.txt
native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sha256
```

Require:

```text
architecture                  i386
build ID                      distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker-v1
all five exact names          present
CoreText fifth name           com_apple_CoreText_FontManagerChangedNotification
kCFNotificationAnyObject      present
broker PASS marker            present
```

Stop if Phase B fails.

## Phase C — repeat syscall 295

Save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-fifth-notification-registration.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase D — exactly one Lion title run with the exact fifth registration enabled

Unset audit/passive modes:

```sh
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-windowtitle-fontserver-register-v1
```

Keep the established expected kernel hash. Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Run exactly once:

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
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-registration.log
```

Require the complete accepted path through `CreateNewWindow=0`, nonzero WindowRef, CFString creation, and the exact FontServer adapter PASS.

Require exactly one fifth accept marker matching:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:
index=5
allowed=4
behavior=1
publicBehavior=4
anyObject=YES
counter=0x1
```

The fifth request must remain the audited envelope:

```text
bits       0x00001111
id         4
size       356
payload    321
```

### Desired title-success branch

If no new request or API boundary intervenes:

```text
T03_AFTER_SetWindowTitleWithCFString               reached
SetWindowTitleWithCFString                         0
SETWINDOWTITLE_PASS                                reached
T04_BEFORE_CFRelease / T05_AFTER_CFRelease         reached
DisposeWindow                                      completed
M24_SUCCESS                                        reached
registration summary                               register=5, rejects=0, exact=YES
broker result                                      PASS
broker exit                                        0
process exit                                       0
new diagnostics                                    none
protected hashes                                   unchanged
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS
```

### Sixth request boundary

If the fifth registration is accepted and a later unreviewed notification request is rejected, the runner emits:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_PASS_SIXTH_PROTOCOL_REJECTED
```

Stop. Preserve the raw request and diagnostics. Do not widen the broker in the same run.

### Other post-fifth no-return

If the fifth registration is accepted, no broker rejection occurs, but `T03` is still not reached, the runner emits:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_PASS_POST_RPC_NO_RETURN
```

Stop at the first new transport/API diagnostic.

## Phase E — return evidence and stop

Return:

```text
native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.info.txt
native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sha256
syscall295-probe-process-manager-post-createwindow-windowtitle-fifth-notification-registration.log
lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-registration.log
lion-ppc-process-manager-post-createwindow-windowtitle-fifth-notification-registration.raw.log
```

Also return every new crash/core diagnostic named by the runner. Stop after Phase E.

## Decision gate

### `POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS`

The window-title gate is closed under the restored stack. Preserve all accepted compatibility unchanged and advance only to `ShowWindow`. Do not combine `ShowWindow` with `SelectWindow`, `IsWindowVisible`, timers, or the event loop.

### `POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_PASS_SIXTH_PROTOCOL_REJECTED`

The exact fifth registration is accepted and the sixth notification is the next blocker. Audit exactly that request before any further allowlist change.

### `POST_CREATEWINDOW_WINDOWTITLE_FIFTH_NOTIFICATION_REGISTRATION_PASS_POST_RPC_NO_RETURN`

The fifth notification is no longer the blocker; identify the first subsequent title-path operation or IPC failure and isolate only that boundary.

### Fifth registration not accepted

Do not broaden the policy. Reconcile the live request against the audited eight-key tuple.

## Current boundary

```text
CreateNewWindow                                      -> PASS
CFStringCreateWithCString                            -> PASS
FontServer exact Lion bootstrap lookup               -> PASS
first four distributed-notification registrations   -> PASS
fifth request schema                                 -> audited exactly
fifth notification name                              -> com_apple_CoreText_FontManagerChangedNotification
fifth object                                         -> kCFNotificationAnyObject
fifth legacy behavior                                -> 1
next step                                            -> exact fifth registration integration
```

No additional XNU change is indicated.


## Observed result — fifth registration accepted; FontServer RPC is next

The exact-five integration run accepted the reviewed fifth registration exactly:

```text
index=5
allowed=4
name=com_apple_CoreText_FontManagerChangedNotification
object=kCFNotificationAnyObject
behavior=1
publicBehavior=4
counter=1
status=0
```

The broker finished with `register=5 callback=0 rejects=0 exact=YES` and `RESULT: PASS`. No sixth notification rejection was observed. The FontServer bootstrap adapter also continued to pass with a valid send right.

`SetWindowTitleWithCFString` still did not reach T03. Before and after the fifth registration was accepted, CoreText repeatedly reported `CopyFontForName received mig IPC error (FFFFFED0) from font server`, followed by `CopyPropertiesForFontsMatchingRequest` with the same code. The subject exited 138 and named a crash report/core, while protected hashes remained unchanged.

This closes the fifth-notification boundary. The next unresolved boundary is the first legacy FontServer RPC itself. The current logging does not expose that request's Mach ID, send/receive sizes, body layout, or reply shape, so no RPC adaptation is yet authorized.

The authoritative next procedure is:

```text
docs/process-manager-post-createwindow-windowtitle-fontserver-rpc-transport-trace-experiment.md
```

That stage is passive: prove the trace build preserves Snow's successful title path, then record only Mach messages sent to the exact FontServer service port during one Lion exact-five title run. No XNU change is indicated.
