# Post-RunApplicationEventLoop twelfth distributed-notification registration

## Objective

Accept **only the reviewed request-12 registration** while preserving the exact first-eleven registration sequence and every inherited compatibility gate. Request 13 or later remains unreviewed and must be rejected.

The request-12 schema audit is a clean PASS. The audited request is exactly:

```text
message_type=register
name=AppleLanguagePreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
publicBehavior=2
counter=1
client=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
sessionid=<the established same-session value>
entry=<positive unique per-run value>
```

Its audited binary plist length is 302 bytes and XML rendering length is 659 bytes. Its legacy Mach geometry is:

```text
index          12
bits           0x00001111
id             4
size           336
payload        302
```

Request 13 is the next unreviewed boundary. Only its observed transport geometry is known:

```text
index          13
bits           0x00001111
id             4
size           356
payload        323
```

Do not infer request 13's plist schema from that geometry.

## Pinned implementation

Current runtime `main` provides:

```text
tests/native-dn-runapplicationeventloop-12-registration-broker.c
scripts/build-lion-dn-runapplicationeventloop-12-registration-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
```

Pinned blobs:

```text
exact-twelve broker source             89bf625bb98d2ea7fc889ee32a197a2bdbc56c4a
exact-twelve broker builder            c8e5d00c2f70762022ef5f082abe70916ddb54bb
Lion integration runner                c2866860022eef2b21876c070504b40b7b687ef6
RunApplicationEventLoop subject        97e410dd71e545c393e0ce6889678a6436ff8ea1
XNU syscall-295 runner                 eaecc9bfbf4d780664c7e66471a832a0289aebb6
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

## Exact-twelve broker contract

Build ID:

```text
distributed-notifications-runapplicationeventloop-twelfth-registration-broker-v1
```

The broker accepts exactly this first-twelve sequence:

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
```

The two latest reviewed entries are:

```text
registration 11
allowed=9
name=AppleTextBehaviorPreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
counter=1

registration 12
allowed=10
name=AppleLanguagePreferencesChangedNotification
object=kCFNotificationAnyObject
behavior=4
counter=1
```

The broker still requires exactly eight dictionary keys, the established client string, a non-empty same-session identifier, a positive unique entry, the exact expected counter, and the exact name/object/behavior sequence. Any request after the reviewed first twelve is rejected.

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Reuse the exact Snow-proven PPC subject; do not rebuild it on Lion.
- Keep `ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2`.
- Keep the reviewed first-seven base mode exactly `lion-showwindow-seventh-register-v1`.
- Enable only `ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE=lion-twelfth-register-v1` for the new registration extension.
- Keep request-8/request-9/request-10/request-11/request-12 schema-audit modes unset.
- Keep exact-eight/exact-nine/exact-ten/exact-eleven registration modes unset.
- Accept request 12 only as the reviewed tuple above.
- Reject request 13 or later.
- Do not decode request 13 in this step.
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

test "$(git hash-object ./tests/native-dn-runapplicationeventloop-12-registration-broker.c)" = \
  "89bf625bb98d2ea7fc889ee32a197a2bdbc56c4a" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-12-registration-broker.sh)" = \
  "c8e5d00c2f70762022ef5f082abe70916ddb54bb" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "c2866860022eef2b21876c070504b40b7b687ef6" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-12-registration-broker.sh || exit 1
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

## Phase C — build only the exact-twelve broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-12-registration-broker.sh \
  ./dn-runapplicationeventloop-12-registration-broker || exit 1
```

Require:

```text
architecture: i386
build_id=distributed-notifications-runapplicationeventloop-twelfth-registration-broker-v1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_POLICY:index=11 allowed=9 counter=1
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_POLICY:index=12 allowed=10 counter=1
AppleTextBehaviorPreferencesChangedNotification
AppleLanguagePreferencesChangedNotification
kCFNotificationAnyObject
```

The generated info and SHA sidecars must agree with the binary.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-twelfth-registration.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion exact-twelve registration run

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
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE
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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE=lion-twelfth-register-v1

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
  ./dn-runapplicationeventloop-12-registration-broker \
  ./dn-runapplicationeventloop-12-registration-broker.sha256 \
  ./payload/lion-runapplicationeventloop-twelfth-registration.log
```

Do not run the PPC subject a second time before review.

## Acceptance discriminator

Require exact registration 12 once:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_ACCEPT:
  index=12
  allowed=10
  behavior=4
  publicBehavior=2
  anyObject=YES
  entry=<positive unique per-run value>
  counter=0x1
```

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

### Expected narrow boundary — request 13 appears

If exact registration 12 is accepted and the next unreviewed request appears, require:

```text
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:index=13 bits=0x00001111 id=4 size=356 payload=323
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_PASS_THIRTEENTH_PROTOCOL_REJECTED
```

Preserve request 13's Mach geometry and broker rejection. The exact-twelve broker may end non-exact/FAIL solely because request 13+ is deliberately unreviewed and rejected; that is expected for this discriminator. Do not decode or accept request 13 in this step.

### Full integration pass — no request 13 appears

If no thirteenth request appears, require:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=12 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS
```

The inherited event-loop and integrity gates above must also pass.

### Any other result

Stop. Do not relax the sequence, name, object, behavior, counter, entry/session predicates, or any existing compatibility adapter.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-12-registration-broker.info.txt
dn-runapplicationeventloop-12-registration-broker.sha256
sys295-runapplicationeventloop-twelfth-registration.log
payload/lion-runapplicationeventloop-twelfth-registration.log
payload/lion-runapplicationeventloop-twelfth-registration.raw.log
```

Also return any newly named crash report or crash plist if the runner reports one.

## Observed result

The exact-twelve registration run is a clean narrow-boundary PASS. Registration 12 was accepted exactly once as allowed 10 / `AppleLanguagePreferencesChangedNotification` / `kCFNotificationAnyObject` / behavior 4 / Coalesce / counter 1, then request 13 appeared at `bits=0x1111 id=4 size=356 payload=323` and requests 13–21 were deliberately rejected as unreviewed traffic. The exact-twelve broker therefore ended `register=12 callback=0 rejects=9 exact=NO` / `FAIL` solely because those nine later requests were intentionally outside policy; the runner still ended `POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TWELFTH_NOTIFICATION_REGISTRATION_PASS_THIRTEENTH_PROTOCOL_REJECTED`. The inherited timer-side-quit sequence completed through S15 and `M24_SUCCESS`, PPC exit remained 0, WBI/ColorProfileClient/ResolveColorProfile and OrderFront counts stayed exact, all six titlebar translations stayed exact with zero guard rejects, no new diagnostic appeared, and protected hashes remained unchanged. This live-proves the exact request-12 registration and authorizes only request-13 schema capture next.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        semantic sequence LIVE-PROVEN through S15
request-8 exact registration                        LIVE-PROVEN PASS
request-9 exact registration                        LIVE-PROVEN PASS
request-10 exact registration                       LIVE-PROVEN PASS
request-11 exact registration                       LIVE-PROVEN PASS
request-12 exact registration                       LIVE-PROVEN PASS
request-12 operation                                register
request-12 name                                     AppleLanguagePreferencesChangedNotification
request-12 object                                   kCFNotificationAnyObject
request-12 behavior                                 4 / Coalesce
request-12 counter                                  1
request-13 geometry                                 bits=0x1111 id=4 size=356 payload=323
next step                                           capture/decode request 13 only
request 13                                          unreviewed / reject after capture
request 14+                                         unreviewed tail / reject
RemoveEventLoopTimer / DisposeEventLoopTimerUPP     HELD
new compatibility families                         NO
titlebar policy broadening                         NO
XNU                                                 no source change indicated
```
