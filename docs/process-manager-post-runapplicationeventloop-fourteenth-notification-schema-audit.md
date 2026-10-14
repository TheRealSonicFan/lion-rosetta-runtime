# Post-RunApplicationEventLoop fourteenth distributed-notification schema audit

## Objective

Capture and decode **only request 14** while preserving the exact reviewed first-thirteen registration sequence and every inherited compatibility gate. Request 14 is captured once and deliberately rejected after capture; request 15 or later remains unreviewed tail traffic and must also be rejected.

The exact request-13 registration boundary is live-proven. Registration 13 was accepted exactly as:

```text
message_type=register
name=AppleKeyboardMenuPreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
publicBehavior=2
counter=1
client=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
sessionid=<the established same-session value>
entry=<positive unique per-run value>
```

Request 14 is the next unreviewed boundary. Only its transport geometry is known:

```text
index          14
bits           0x00001111
id             4
size           336
payload        302
```

Do **not** infer request 14's plist schema from its 302-byte payload, from request 12 having the same transport size, or from any earlier notification registration.

## Pinned implementation

Current runtime `main` provides:

```text
tests/native-distnotify-runapplicationeventloop-fourteenth-schema-audit-broker.c
scripts/build-lion-dn-runapplicationeventloop-14-schema-audit-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
```

Pinned blobs:

```text
request-14 audit broker source          57259e8035ef9868c824fe829b42a4d7c1c679de
request-14 audit broker builder         83d30bbf0c01e9dd4703f87a03e11c3626f5fea4
Lion integration runner                 c484d0f49667d9ebbc521ca50867fd48a76f84c0
RunApplicationEventLoop subject         97e410dd71e545c393e0ce6889678a6436ff8ea1
XNU syscall-295 runner                  eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

Accepted fixed identities remain:

```text
subject SHA-256
059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7

v3 CoreServices compatibility SHA-256
28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578

exact-six titlebar compatibility SHA-256
6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

HIToolbox Extras resource SHA-256
a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197

private dyld SHA-256
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb

accepted Lion kernel SHA-256
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

## Request-14 audit broker contract

Build ID:

```text
distributed-notifications-runapplicationeventloop-fourteenth-schema-audit-broker-v1
```

The broker accepts exactly this first-thirteen sequence:

```text
registration 1  -> allowed 0,  counter 1
registration 2  -> allowed 1,  counter 1
registration 3  -> allowed 2,  counter 1
registration 4  -> allowed 3,  counter 1
registration 5  -> allowed 4,  counter 1
registration 6  -> allowed 3,  counter 2
registration 7  -> allowed 5,  counter 1
registration 8  -> allowed 6,  counter 1
registration 9  -> allowed 7,  counter 1
registration 10 -> allowed 8,  counter 1
registration 11 -> allowed 9,  counter 1
registration 12 -> allowed 10, counter 1
registration 13 -> allowed 11, counter 1
```

The latest reviewed entries are:

```text
registration 12
allowed=10
name=AppleLanguagePreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
counter=1

registration 13
allowed=11
name=AppleKeyboardMenuPreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
counter=1
```

For the first thirteen registrations the broker still requires exactly eight dictionary keys, the established client string, a non-empty same-session identifier, a positive unique entry, the exact expected counter, and the exact name/object/behavior sequence.

Once thirteen registrations have been accepted, the broker does **not** authorize request 14. Instead it:
1. captures the first next binary plist and XML rendering into the dedicated audit report;
2. returns status 25 intentionally for that captured request;
3. rejects all later traffic as unreviewed post-boundary tail traffic;
4. does not count these intentional boundary/tail rejects as an exact-sequence failure.

The broker must finish with one audit capture, zero audit failures, zero unexpected rejects, and an exact first-thirteen registration state.

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Reuse the exact Snow-proven PPC subject; do not rebuild it on Lion.
- Keep `ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2`.
- Keep the reviewed first-seven base mode exactly `lion-showwindow-seventh-register-v1`.
- Enable only `ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REPORT` for the new audit.
- Keep request-8 through request-13 schema-audit modes unset.
- Keep exact-eight through exact-thirteen registration modes unset.
- Preserve the reviewed first thirteen exactly.
- Capture request 14 once, reject it after capture, and reject request 15 or later.
- Do not accept request 14 in this step.
- Do not inspect or infer request 15+ schema.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add another Carbon/window/timer API.
- Do not broaden CGS, CoreUI, titlebar, notification, or other compatibility.
- Do not modify Rosetta, dyld, frameworks, resources, caches, or XNU.
- No kernel rebuild or reboot.
- Run the PPC subject exactly once before review.

## Phase A — update and pin

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/native-distnotify-runapplicationeventloop-fourteenth-schema-audit-broker.c)" = \
  "57259e8035ef9868c824fe829b42a4d7c1c679de" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-14-schema-audit-broker.sh)" = \
  "83d30bbf0c01e9dd4703f87a03e11c3626f5fea4" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "c484d0f49667d9ebbc521ca50867fd48a76f84c0" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-14-schema-audit-broker.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if Phase A fails.

## Phase B — verify the exact PPC subject

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1
```

Do not rebuild the PPC subject.

## Phase C — build only the request-14 schema-audit broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-14-schema-audit-broker.sh \
  ./dn-runapplicationeventloop-14-schema-audit-broker || exit 1
```

Require:

```text
architecture: i386
build_id=distributed-notifications-runapplicationeventloop-fourteenth-schema-audit-broker-v1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_POLICY:index=12 allowed=10 counter=1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_REGISTRATION_POLICY:index=13 allowed=11 counter=1
AppleLanguagePreferencesChangedNotification
AppleKeyboardMenuPreferencesChangedNotification
kCFNotificationAnyObject
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_CAPTURE:
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REJECT:
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_TAIL_REJECT:
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_SUMMARY:
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_FOURTEENTH_AUDIT_PASS
```

The generated info and SHA sidecars must agree with the binary.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-fourteenth-audit.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion request-14 schema-audit run

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_REGISTRATION_MODE
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE
unset ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=lion-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=lion-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=lion-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=lion-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=lion-installeventlooptimer-v1
export ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2

export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-selectwindow-id-v1
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=lion-id-v1

export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1

export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REPORT="$PWD/lion-runapplicationeventloop-fourteenth-schema-audit.txt"

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=lion-exact-six-v1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/pm-selectwindow-orderfront-compat.dylib \
  ./payload/pm-selectwindow-orderfront-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-runapplicationeventloop-14-schema-audit-broker \
  ./dn-runapplicationeventloop-14-schema-audit-broker.sha256 \
  ./payload/lion-runapplicationeventloop-fourteenth-schema-audit.log
```

Do not run the PPC subject a second time before review.

## Acceptance discriminator

Require exact registration 13 to remain accepted once:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:
  index=13
  allowed=11
  behavior=4
  publicBehavior=2
  anyObject=YES
  entry=<positive unique per-run value>
  counter=0x1
```

Require request 14 to appear with the observed geometry and be captured exactly once:

```text
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:
  index=14
  bits=0x00001111
  id=4
  size=336
  payload=302

PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_CAPTURE:index=1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REJECT:status=25 intentional=YES capture=YES
```

Require the broker to preserve the first-thirteen state:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=13 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_SUMMARY:captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=<tail count> exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_FOURTEENTH_AUDIT_PASS
```

If the observed wave is unchanged, request indexes 15 through 21 produce 7 post-boundary tail rejects. That count is descriptive only and is not permission to inspect or accept those requests.

Require the inherited event-loop chain to remain intact:

```text
S14_BEFORE_RunApplicationEventLoop
timer callback ENTER
timer callback BEFORE_QuitApplicationEventLoop
timer callback AFTER_QuitApplicationEventLoop
timer callback EXIT
S15_AFTER_RunApplicationEventLoop
fired=1
RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS
M24_SUCCESS
PPC subject exit 0
protected hashes unchanged
no new diagnostic
```

Require WBI/ColorProfileClient/ResolveColorProfile adapter PASS counts of 1/1/1, OrderFront adapter PASS count 2, all six titlebar translations exactly once, and zero titlebar guard rejects.

The runner must end:

```text
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_NOTIFICATION_SCHEMA_AUDIT_PASS
```

Then inspect only the request-14 plist in `lion-runapplicationeventloop-fourteenth-schema-audit.txt`. Do not add an exact-fourteen registration rule until that returned artifact has been reviewed.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-14-schema-audit-broker.info.txt
dn-runapplicationeventloop-14-schema-audit-broker.sha256
sys295-runapplicationeventloop-fourteenth-audit.log
payload/lion-runapplicationeventloop-fourteenth-schema-audit.log
payload/lion-runapplicationeventloop-fourteenth-schema-audit.raw.log
lion-runapplicationeventloop-fourteenth-schema-audit.txt
```

Also return any newly named crash report or crash plist if the runner reports one.

## Observed Phase-E preflight failure

The first Phase-E attempt did **not** execute the PPC subject. The processed integration log stopped at `ERROR: broker build marker missing`, and the raw log remained empty. The broker artifact itself was valid i386 and its reported SHA-256 matched the sidecar, so the failure was not a broker build failure.

The root cause was runner control flow introduced with the request-14 mode: the request-14 validation block accidentally split the initial broker-selection `if/elif` chain. The later base-registration branch then overwrote the request-14 audit build ID with the exact-seven base broker build ID, causing the generic broker-marker preflight to reject the correctly built request-14 audit broker before the subject launched. The runner has been corrected.

Because the previous exact-thirteen run already exposed a stable eight-request tail, requests 14–21, this single-request procedure is now superseded by `docs/process-manager-post-runapplicationeventloop-remaining-notifications-schema-audit.md`. That procedure captures and decodes all eight remaining requests in one run while still rejecting all eight after capture.

## Current boundary

```text
request-13 exact registration                       LIVE-PROVEN PASS
request-14-only Phase E                             PRE-SUBJECT PREFLIGHT FAIL
failure cause                                       runner broker-selection control-flow bug
PPC subject executed                                NO
raw log                                             empty
remaining observed registrations                    8 (requests 14–21)
next step                                           one-shot capture/decode requests 14–21
bulk acceptance                                     NOT YET AUTHORIZED
RemoveEventLoopTimer / DisposeEventLoopTimerUPP     HELD
new compatibility families                         NO
titlebar policy broadening                         NO
XNU                                                 no source change indicated
```
