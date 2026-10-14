# Post-RunApplicationEventLoop RemoveEventLoopTimer Lion integration

## Objective

Transfer the **exact Snow-proven** `RemoveEventLoopTimer()` subject to Lion 10.7.5 / 11G63 and perform exactly one guarded integration run on top of the live-proven exact twenty-one distributed-notification policy.

The Snow control is closed PASS with:

```text
subject SHA-256
dd7800673066de223ea214833b940a64c838fe0f2b6c9cde8a67276c9b8ebae2

source SHA-256
2021886ba715439a9f2f4fbcb206170b1dae652ddd3c2a616f6ee494d47a1dde

build ID
cps-removeeventlooptimer-validation-v1
```

Snow proves the inherited timer-side-quit sequence, then:

```text
S16_BEFORE_RemoveEventLoopTimer
S17_AFTER_RemoveEventLoopTimer
RemoveEventLoopTimer=0
REMOVEEVENTLOOPTIMER_PASS
M24_SUCCESS
control_status=0
RESULT: POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_SNOW_CONTROL_PASS
RESULT: PASS
```

The Snow binary imports `_RemoveEventLoopTimer` and does not import `_DisposeEventLoopTimerUPP`. This Lion stage transfers that exact binary; it does not introduce `DisposeEventLoopTimerUPP()`.

## Pinned implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-removeeventlooptimer.c
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/native-dn-runapplicationeventloop-remaining-registration-broker.c
scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh
```

Pinned blobs:

```text
RemoveEventLoopTimer subject source       e9a88a33c7e2e5521ef4bc8c7ba5c512a15581d9
Lion integration runner                   e7af86839399bcd26d5a15719888d76c76bf08a6
exact twenty-one broker source            03504584b0d1e9e97c1fd3663ee4590c692ab940
exact twenty-one broker builder           5f10c92f15d2a79c76bf07ae68eae58228d0e486
XNU syscall-295 runner                    eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

Accepted fixed identities remain:

```text
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

New Lion validation mode:

```text
ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE=lion-removeeventlooptimer-v1
```

It is valid only with:

```text
ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2
ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1
ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_REGISTRATION_MODE=lion-remaining-register-v1
```

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Transfer the exact Snow-proven subject; do not rebuild it on Lion.
- Keep the exact twenty-one notification broker unchanged.
- Keep every request-8 through request-14 schema-audit mode unset.
- Keep the remaining-wave schema-audit mode unset.
- Keep exact-eight through exact-thirteen registration modes unset.
- Add only `RemoveEventLoopTimer(timer_ref)` beyond the live-proven S15 boundary.
- Do not call or import `DisposeEventLoopTimerUPP()`.
- Reject any notification request after index 21.
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

test "$(git hash-object ./tests/ppc-process-manager-postidentity-removeeventlooptimer.c)" = \
  "e9a88a33c7e2e5521ef4bc8c7ba5c512a15581d9" || exit 1
test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "e7af86839399bcd26d5a15719888d76c76bf08a6" || exit 1
test "$(git hash-object ./tests/native-dn-runapplicationeventloop-remaining-registration-broker.c)" = \
  "03504584b0d1e9e97c1fd3663ee4590c692ab940" || exit 1
test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh)" = \
  "5f10c92f15d2a79c76bf07ae68eae58228d0e486" || exit 1

/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1
/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if Phase A fails.

## Phase B — transfer and verify the exact Snow-proven subject

Copy these successful Snow files into Lion runtime `payload/`:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

On Lion:

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "dd7800673066de223ea214833b940a64c838fe0f2b6c9cde8a67276c9b8ebae2" || exit 1
test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "dd7800673066de223ea214833b940a64c838fe0f2b6c9cde8a67276c9b8ebae2" || exit 1

/usr/bin/grep -Fq 'source_sha256=2021886ba715439a9f2f4fbcb206170b1dae652ddd3c2a616f6ee494d47a1dde' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'build_id=cps-removeeventlooptimer-validation-v1' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'removeeventlooptimer_source_expression=RemoveEventLoopTimer(timer_ref)' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'removeeventlooptimer_linkage=undefined-import' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'disposeeventlooptimerupp=held' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq '_RemoveEventLoopTimer' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
if /usr/bin/grep -Fq '_DisposeEventLoopTimerUPP' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt; then
  exit 1
fi

for marker in \
  'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' \
  'PM_POSTWINDOWTIMERREMOVE_MILESTONE:S16_BEFORE_RemoveEventLoopTimer' \
  'PM_POSTWINDOWTIMERREMOVE_MILESTONE:S17_AFTER_RemoveEventLoopTimer' \
  'PM_POSTWINDOWTIMERREMOVE_STATUS:RemoveEventLoopTimer=' \
  'PM_POSTWINDOWTIMERREMOVE_RESULT:REMOVEEVENTLOOPTIMER_PASS'
do
  /usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
    /usr/bin/grep -Fq "$marker" || exit 1
done
```

Do not rebuild the PPC subject.

## Phase C — rebuild only the exact twenty-one native broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh \
  ./dn-runapplicationeventloop-remaining-registration-broker || exit 1
```

Require i386, build ID:

```text
distributed-notifications-runapplicationeventloop-remaining-registration-broker-v1
```

Require matching broker binary/info/SHA sidecars and the exact policy markers through registration 21. Do not modify the broker policy.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-removeeventlooptimer.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion RemoveEventLoopTimer transfer

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
unset ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE
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
export ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE=lion-removeeventlooptimer-v1

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
  ./payload/lion-removeeventlooptimer.log
```

Do not run the PPC subject a second time before review. The raw transcript is:

```text
payload/lion-removeeventlooptimer.raw.log
```

## Acceptance discriminator

Require the exact twenty-one registration policy to remain closed:

```text
registrations 14-21 accepted exactly once at allowed indexes 12-19
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=21 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:PASS
no broker reject
no notification request after index 21
```

Require the inherited timer-side-quit chain exactly once through:

```text
S14_BEFORE_RunApplicationEventLoop
timer callback ENTER
timer callback BEFORE_QuitApplicationEventLoop
timer callback AFTER_QuitApplicationEventLoop
timer callback EXIT
S15_AFTER_RunApplicationEventLoop
fired=1
RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS
```

Then require exactly:

```text
PM_POSTWINDOWTIMERREMOVE_MILESTONE:S16_BEFORE_RemoveEventLoopTimer
PM_POSTWINDOWTIMERREMOVE_MILESTONE:S17_AFTER_RemoveEventLoopTimer
PM_POSTWINDOWTIMERREMOVE_STATUS:RemoveEventLoopTimer=0
PM_POSTWINDOWTIMERREMOVE_RESULT:REMOVEEVENTLOOPTIMER_PASS
removeeventlooptimer_before_count=1
removeeventlooptimer_after_count=1
removeeventlooptimer_status_zero_count=1
removeeventlooptimer_pass_count=1
```

Also require PPC exit 0, `M24_SUCCESS`, WBI / ColorProfileClient / ResolveColorProfile adapter-pass counts 1 / 1 / 1, OrderFront adapter-pass count 2, all six exact titlebar translations once, zero titlebar guard rejects, no new diagnostic, and unchanged protected hashes.

Final discriminator:

```text
RESULT: POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_PASS
```

There must be no `REMOVEEVENTLOOPTIMER_RETURNED_ERROR`, no notification request after 21, no broker reject, no `_DisposeEventLoopTimerUPP` import, no new compatibility behavior, and no protected-hash change.

## Failure classification

- S15 absent: inherited event-loop regression; stop.
- S16 absent after S15: subject/control-flow mismatch; stop.
- S16 present but S17 absent: Lion `RemoveEventLoopTimer()` no-return boundary; preserve the raw log.
- S17 present with nonzero status: native Lion API error boundary; preserve evidence and do not add compatibility.
- Any request after notification 21: preserve evidence and do not broaden the broker.
- Any compatibility/titlebar/integrity regression: stop and preserve evidence.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-remaining-registration-broker.info.txt
dn-runapplicationeventloop-remaining-registration-broker.sha256
sys295-removeeventlooptimer.log
payload/lion-removeeventlooptimer.log
payload/lion-removeeventlooptimer.raw.log
```

Also return any newly named crash report or crash plist if the runner reports one.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        LIVE-PROVEN through S15
all 21 reviewed Lion notification registrations     LIVE-PROVEN PASS
RemoveEventLoopTimer Snow                            LIVE-PROVEN PASS
RemoveEventLoopTimer Lion                            NEXT: guarded exact-binary transfer
DisposeEventLoopTimerUPP                             HELD
new compatibility families                          NO
titlebar policy broadening                          NO
XNU                                                  no source change indicated
```
