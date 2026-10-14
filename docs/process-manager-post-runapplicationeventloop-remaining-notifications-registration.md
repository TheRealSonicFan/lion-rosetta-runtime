# Post-RunApplicationEventLoop remaining distributed-notification registration

**Status: COMPLETE — PASS.** The guarded exact twenty-one-registration Lion run passed with zero broker rejects and no request after index 21. The next isolated boundary is `RemoveEventLoopTimer()` on Snow Leopard.

## Objective

Accept **only the eight reviewed registrations at request indexes 14 through 21** while preserving the exact first-thirteen registration sequence and every inherited compatibility gate. This produces one exact twenty-one-registration user-space policy. Any request after index 21 remains unreviewed and must be rejected.

The remaining-wave schema audit is a clean PASS. It captured exactly eight requests, reported zero capture failures, zero unexpected rejects, and zero post-boundary rejects, while the inherited Lion event-loop run completed through S15 and `M24_SUCCESS` with protected hashes unchanged.

All eight audited requests use the established registration schema:

```text
message_type=register
object=kCFNotificationAnyObject
behavior=4
publicBehavior=2
counter=1
client=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
sessionid=<the established same-session value>
entry=<positive unique per-run value>
```

The reviewed continuation is:

```text
request  allowed  name                                                       Mach size/payload
14       12       AppleKeyboardPreferencesChangedNotification                336 / 302
15       13       AppleKeyboardPreferencesSelectedItemsChangedNotification   364 / 332
16       14       AppleSelectedInputMethodPasteboardInvalidNotification      364 / 329
17       15       AppleTextInputMenuExtraDidLoadNotification                 336 / 301
18       16       AppleInstalledInputSourcesChangedNotification              336 / 304
19       17       AppleEnabledInputSourcesChangedNotification                336 / 302
20       18       AppleSelectedInputSourcesChangedNotification               336 / 303
21       19       com.apple.accessibility.api                                320 / 286
```

Do not generalize from these eight names to any later request.

## Pinned implementation

Current runtime `main` provides:

```text
tests/native-dn-runapplicationeventloop-remaining-registration-broker.c
scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
```

Pinned blobs:

```text
exact remaining-wave broker source       03504584b0d1e9e97c1fd3663ee4590c692ab940
exact remaining-wave broker builder      5f10c92f15d2a79c76bf07ae68eae58228d0e486
Lion integration runner                  7b0b7efc7afb00097930889ca2f6b2891b08c483
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

## Exact remaining-wave broker contract

Build ID:

```text
distributed-notifications-runapplicationeventloop-remaining-registration-broker-v1
```

The broker accepts exactly this twenty-one-registration sequence:

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
registration 14 -> allowed 12, counter 1
registration 15 -> allowed 13, counter 1
registration 16 -> allowed 14, counter 1
registration 17 -> allowed 15, counter 1
registration 18 -> allowed 16, counter 1
registration 19 -> allowed 17, counter 1
registration 20 -> allowed 18, counter 1
registration 21 -> allowed 19, counter 1
```

The broker requires exactly eight dictionary keys, the established client string, a non-empty same-session identifier, a positive unique entry, the exact expected counter, and the exact name/object/behavior sequence. A request after the reviewed first twenty-one is rejected and prevents the exact PASS.

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Reuse the exact Snow-proven PPC subject; do not rebuild it on Lion.
- Keep `ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2`.
- Keep the reviewed first-seven base mode exactly `lion-showwindow-seventh-register-v1`.
- Enable only `ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_REGISTRATION_MODE=lion-remaining-register-v1` for the new registration extension.
- Keep every request-8 through request-14 single-request schema-audit mode unset.
- Keep the remaining-wave schema-audit mode unset.
- Keep exact-eight through exact-thirteen registration modes unset.
- Accept requests 14–21 only as the reviewed tuples above.
- Reject any request after 21.
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

test "$(git hash-object ./tests/native-dn-runapplicationeventloop-remaining-registration-broker.c)" = \
  "03504584b0d1e9e97c1fd3663ee4590c692ab940" || exit 1
test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh)" = \
  "5f10c92f15d2a79c76bf07ae68eae58228d0e486" || exit 1
test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "7b0b7efc7afb00097930889ca2f6b2891b08c483" || exit 1
test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh || exit 1
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

## Phase C — build only the exact remaining-wave broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh \
  ./dn-runapplicationeventloop-remaining-registration-broker || exit 1
```

Require i386, the exact build ID above, the policy markers through registration 21, all eight reviewed request-14 through request-21 notification literals, and matching binary/info/SHA sidecars.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-remaining-registration.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion exact remaining-wave registration run

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
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_REGISTRATION_MODE
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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_REGISTRATION_MODE=lion-remaining-register-v1

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
  ./dn-runapplicationeventloop-remaining-registration-broker \
  ./dn-runapplicationeventloop-remaining-registration-broker.sha256 \
  ./payload/lion-runapplicationeventloop-remaining-registration.log
```

Do not run the PPC subject a second time before review.

## Acceptance discriminator

Require registrations 14 through 21 to be accepted exactly once with the exact index/allowed pairs and behavior/object/counter contract above.

Require:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=21 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_REMAINING_NOTIFICATIONS_REGISTRATION_PASS
```

Also require the inherited timer-side-quit chain through S15 and `M24_SUCCESS`, PPC exit 0, WBI/ColorProfileClient/ResolveColorProfile counts 1/1/1, OrderFront count 2, all six titlebar translations once, zero titlebar guard rejects, no new diagnostics, and unchanged protected hashes.

If a request after 21 appears, or any reviewed registration differs in name/object/behavior/counter/client/session/entry semantics, stop. Do not broaden the broker.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-remaining-registration-broker.info.txt
dn-runapplicationeventloop-remaining-registration-broker.sha256
sys295-runapplicationeventloop-remaining-registration.log
payload/lion-runapplicationeventloop-remaining-registration.log
payload/lion-runapplicationeventloop-remaining-registration.raw.log
```

Also return any newly named crash report or crash plist if the runner reports one.

## Observed result

The exact remaining-wave registration run is a clean PASS. Registrations 14 through 21 were each accepted exactly once at allowed indexes 12 through 19, with behavior 4 / Coalesce, AnyObject, counter 1, positive unique entries, and the established client/session contract. The broker ended `register=21 callback=0 rejects=0 exact=YES` and `PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS`; the ingress interposer ended with exactly 21 requests and no later distributed-notification request. The timer callback still executed exactly once, callback-side Quit returned, S15 and `M24_SUCCESS` were reached, all six titlebar translations remained exact with zero guard rejects, no new diagnostic appeared, protected hashes were unchanged, and the runner ended `POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_REMAINING_NOTIFICATIONS_REGISTRATION_PASS`. The fresh syscall-295 preflight again returned EBADF without SIGSYS on the accepted kernel. This closes the notification-registration tail and authorizes no further notification-policy broadening.

## Current boundary

```text
request-13 exact registration                       LIVE-PROVEN PASS
requests 14-21 schema audit                         LIVE-PROVEN PASS
requests 14-21 exact acceptance                     LIVE-PROVEN PASS
total reviewed notification registrations           21
post-request-21 traffic observed                     none in reviewed exact run
post-request-21 policy                               unreviewed / reject if seen
RunApplicationEventLoop timer-side-quit Lion         LIVE-PROVEN through S15
RemoveEventLoopTimer                                 NEXT: isolated Snow control
DisposeEventLoopTimerUPP                             HELD
new compatibility families                          NO
titlebar policy broadening                          NO
XNU                                                  no source change indicated
```
