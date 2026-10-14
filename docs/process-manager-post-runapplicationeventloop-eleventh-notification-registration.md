# Post-RunApplicationEventLoop exact-eleventh notification registration

## Objective

Accept exactly the one request-11 schema reviewed by the preceding Lion audit, while preserving every earlier compatibility gate and rejecting any unreviewed request 12 or later.

The request-11 schema audit passed cleanly. The reviewed first ten registrations remained exact, request 11 was captured once, ten later requests were rejected only as post-boundary tail traffic, the timer-side-quit event-loop sequence still completed through S15 and `M24_SUCCESS`, the PPC subject exited 0, no new diagnostic appeared, and protected hashes remained unchanged.

The captured request 11 decodes as:

```text
message_type  register
client        ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
name          AppleTextBehaviorPreferencesChangedNotification
object        kCFNotificationAnyObject
behavior      4
counter       1
entry         positive per-run identity
sessionid     established session
```

The captured legacy Mach request geometry was:

```text
index          11
bits           0x00001111
id             4
size           356
payload        323
```

This authorizes only one narrow sequence extension: registration index 11 may match the exact tuple above. It does not authorize request 12, another `AppleTextBehaviorPreferencesChangedNotification`, a different object, behavior, counter, client, or session.

The next observed request has only its transport geometry reviewed:

```text
index          12
bits           0x00001111
id             4
size           336
payload        302
```

Do not decode or accept request 12 in this operation.

## Pinned implementation

Current runtime `main` provides:

```text
tests/native-dn-runapplicationeventloop-11-registration-broker.c
scripts/build-lion-dn-runapplicationeventloop-11-registration-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
```

Pinned blobs:

```text
exact-eleven registration broker source     af7b36759b077615b41ecb6ac56b9cedb593c78e
exact-eleven registration broker builder    ba185126625c92f5fc390df6f66e711acfe2e9db
Lion integration runner                     bfed8f4ed8cb4fb72cff273abd286a0fea3e15cf
RunApplicationEventLoop subject          97e410dd71e545c393e0ce6889678a6436ff8ea1
XNU syscall-295 runner                   eaecc9bfbf4d780664c7e66471a832a0289aebb6
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

## Exact-eleven broker contract

Build ID:

```text
distributed-notifications-runapplicationeventloop-eleventh-registration-broker-v1
```

The exact sequence is:

```text
registration 1  -> allowed 0, counter 1
registration 2  -> allowed 1, counter 1
registration 3  -> allowed 2, counter 1
registration 4  -> allowed 3, counter 1
registration 5  -> allowed 4, counter 1
registration 6  -> allowed 3, counter 2
registration 7  -> allowed 5, counter 1
registration 8  -> allowed 6, counter 1
registration 9  -> allowed 7, counter 1
registration 10 -> allowed 8, counter 1
registration 11 -> allowed 9, counter 1
```

The new allowed entry is exactly:

```text
allowed=9
name=AppleTextBehaviorPreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
publicBehavior=2
counter=1
```

The broker must reject any twelfth request. Request 12 is a new boundary and remains unreviewed.

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Reuse the exact Snow-proven PPC subject; do not rebuild it on Lion.
- Keep `ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2`.
- Keep direct no-active-loop Quit mode unset.
- Keep the reviewed first-seven base mode exactly `lion-showwindow-seventh-register-v1`.
- Enable only `ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE=lion-eleventh-register-v1` for this extension.
- Keep request-8, request-9, request-10, and request-11 schema-audit report modes unset.
- Keep exact-eight, exact-nine, and exact-ten registration modes unset; the exact-eleven broker contains the reviewed first-eleven sequence itself.
- Do not accept request 12.
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

test "$(git hash-object ./tests/native-dn-runapplicationeventloop-11-registration-broker.c)" = \
  "af7b36759b077615b41ecb6ac56b9cedb593c78e" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-11-registration-broker.sh)" = \
  "ba185126625c92f5fc390df6f66e711acfe2e9db" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "bfed8f4ed8cb4fb72cff273abd286a0fea3e15cf" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-11-registration-broker.sh || exit 1
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

## Phase C — build only the exact-eleven native broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-11-registration-broker.sh \
  ./dn-runapplicationeventloop-11-registration-broker || exit 1
```

Require:

```text
architecture: i386
build_id=distributed-notifications-runapplicationeventloop-eleventh-registration-broker-v1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_POLICY:index=8 allowed=6 counter=1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_POLICY:index=9 allowed=7 counter=1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_POLICY:index=10 allowed=8 counter=1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1
AppleDatePreferencesChangedNotification
AppleTimePreferencesChangedNotification
AppleNumberPreferencesChangedNotification
AppleTextBehaviorPreferencesChangedNotification
```

The generated info and SHA sidecars must agree with the binary.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-eleventh-registration.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion exact-eleven registration run

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
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE
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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE=lion-eleventh-register-v1

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
  ./dn-runapplicationeventloop-11-registration-broker \
  ./dn-runapplicationeventloop-11-registration-broker.sha256 \
  ./payload/lion-runapplicationeventloop-eleventh-registration.log
```

Do not run the PPC subject a second time before review.

## Acceptance discriminator

Require exact registration 11:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:
  index=11
  allowed=9
  behavior=4
  publicBehavior=2
  anyObject=YES
  entry=<positive unique per-run value>
  counter=0x1

eleventh_notification_registration_accept_count=1
```

Require the inherited event-loop chain to remain intact through the boundary:

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

### Expected narrow boundary — request 12 appears

If exact registration 11 is accepted and the next unreviewed request appears, the runner must stop with:

```text
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_PASS_TWELFTH_PROTOCOL_REJECTED
```

Preserve request 12's Mach geometry and broker rejection. The exact-eleven broker may end non-exact/FAIL solely because request 12+ is deliberately unreviewed and rejected; that is expected for this discriminator. Do not decode or accept request 12 in this step.

### Full integration pass — no request 12 appears

If no twelfth request appears, require:

```text
broker summary register=11 callback=0 rejects=0 exact=YES
broker result PASS
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_ELEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS
```

The inherited event-loop and integrity gates above must also pass.

### Any other result

Stop. Do not relax the sequence, name, object, behavior, counter, entry/session predicates, or any existing compatibility adapter.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-11-registration-broker.info.txt
dn-runapplicationeventloop-11-registration-broker.sha256
sys295-runapplicationeventloop-eleventh-registration.log
payload/lion-runapplicationeventloop-eleventh-registration.log
payload/lion-runapplicationeventloop-eleventh-registration.raw.log
```

Also return any newly named crash report or crash plist if the runner reports one.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        semantic sequence LIVE-PROVEN through S15
request-8 exact registration                        LIVE-PROVEN PASS
request-9 exact registration                        LIVE-PROVEN PASS
request-10 exact registration                       LIVE-PROVEN PASS
request-11 schema audit                             PASS
request-11 operation                                register
request-11 name                                     AppleTextBehaviorPreferencesChangedNotification
request-11 object                                   kCFNotificationAnyObject
request-11 behavior                                 4 / Coalesce
request-11 counter                                  1
request-12 geometry                                 bits=0x1111 id=4 size=336 payload=302
next step                                           accept exact request 11 once
request 12                                          unreviewed / reject
request 13+                                         unreviewed tail / reject
RemoveEventLoopTimer / DisposeEventLoopTimerUPP     HELD
new compatibility families                         NO
titlebar policy broadening                         NO
XNU                                                 no source change indicated
```
