# Post-RemoveEventLoopTimer DisposeEventLoopTimerUPP Lion integration

**Status: COMPLETE — PASS.** The exact Snow-proven UPP-disposal subject transferred unchanged to Lion, preserved the exact twenty-one notification policy and accepted runtime gates, returned through S18/S19, and completed with the dedicated Lion PASS discriminator. The incremental Carbon window/event-loop lifecycle is now closed through cleanup; current work advances to `docs/ppc-carbon-gui-restored-stack-retest.md`, which reruns the original Snow-positive Carbon GUI smoke binary under the completed restored stack.

## Objective

Transfer the **exact Snow-proven** `DisposeEventLoopTimerUPP()` subject to Lion 10.7.5 / 11G63 and perform exactly one guarded integration run on top of the already live-proven `RemoveEventLoopTimer()` boundary and exact twenty-one distributed-notification policy.

The Snow control is closed PASS with:

```text
subject SHA-256
15848bd9dc1a7837dbb6a0756b96e5f83f58d549c88dcfe4eeeeaa28ca8e204c

source SHA-256
84b1ccb5a7fe61f04443fbd3878a8a114e5fd902bc87275ea7d4bd28f523e4db

build ID
cps-disposeeventlooptimerupp-validation-v1

DisposeEventLoopTimerUPP linkage
sdk-lowered-no-undefined-import
```

Snow proves the inherited timer-side-quit sequence, then:

```text
S16_BEFORE_RemoveEventLoopTimer
S17_AFTER_RemoveEventLoopTimer
RemoveEventLoopTimer=0
REMOVEEVENTLOOPTIMER_PASS
PM_POSTWINDOWTIMERUPPDISPOSE_POINTER:before=<nonzero> nonzero=YES
S18_BEFORE_DisposeEventLoopTimerUPP
S19_AFTER_DisposeEventLoopTimerUPP
DISPOSEEVENTLOOPTIMERUPP_PASS
M24_SUCCESS
control_status=0
RESULT: POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_SNOW_CONTROL_PASS
RESULT: PASS
```

The Snow SDK lowers `DisposeEventLoopTimerUPP(timer_upp)` without an undefined `_DisposeEventLoopTimerUPP` import. This Lion stage transfers the exact binary; do not rebuild it on Lion and do not infer that UPP disposal is absent merely because that undefined symbol is absent.

## Pinned implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-disposeeventlooptimerupp.c
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/native-dn-runapplicationeventloop-remaining-registration-broker.c
scripts/build-lion-dn-runapplicationeventloop-remaining-registration-broker.sh
```

Pinned blobs:

```text
DisposeEventLoopTimerUPP subject source   05034299592c24baf0d0edb7b4f51d6968aa256b
Lion integration runner                   a8d773a85e765ca8dbce768dca4083021a9f46ce
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
ROSETTA_POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_MODE=lion-disposeeventlooptimerupp-v1
```

It is valid only with:

```text
ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2
ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE=lion-removeeventlooptimer-v1
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
- Preserve the live-proven `RemoveEventLoopTimer()` step unchanged.
- Add no new Carbon/window/timer operation beyond the Snow-proven `DisposeEventLoopTimerUPP(timer_upp)` step.
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

test "$(git hash-object ./tests/ppc-process-manager-postidentity-disposeeventlooptimerupp.c)" = \
  "05034299592c24baf0d0edb7b4f51d6968aa256b" || exit 1
test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "a8d773a85e765ca8dbce768dca4083021a9f46ce" || exit 1
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
  "15848bd9dc1a7837dbb6a0756b96e5f83f58d549c88dcfe4eeeeaa28ca8e204c" || exit 1
test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "15848bd9dc1a7837dbb6a0756b96e5f83f58d549c88dcfe4eeeeaa28ca8e204c" || exit 1

/usr/bin/grep -Fq 'source_sha256=84b1ccb5a7fe61f04443fbd3878a8a114e5fd902bc87275ea7d4bd28f523e4db' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'build_id=cps-disposeeventlooptimerupp-validation-v1' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'removeeventlooptimer_source_expression=RemoveEventLoopTimer(timer_ref)' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'removeeventlooptimer_linkage=undefined-import' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'disposeeventlooptimerupp_source_expression=DisposeEventLoopTimerUPP(timer_upp)' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'disposeeventlooptimerupp_linkage=sdk-lowered-no-undefined-import' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'disposeeventlooptimerupp_expected_result=pass' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq '_RemoveEventLoopTimer' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
if /usr/bin/grep -Fq '_DisposeEventLoopTimerUPP' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt; then
  exit 1
fi

for marker in \
  'PM_POSTWINDOWTIMERREMOVE_MILESTONE:S16_BEFORE_RemoveEventLoopTimer' \
  'PM_POSTWINDOWTIMERREMOVE_MILESTONE:S17_AFTER_RemoveEventLoopTimer' \
  'PM_POSTWINDOWTIMERREMOVE_STATUS:RemoveEventLoopTimer=' \
  'PM_POSTWINDOWTIMERREMOVE_RESULT:REMOVEEVENTLOOPTIMER_PASS' \
  'PM_POSTWINDOWTIMERUPPDISPOSE_POINTER:before=' \
  'PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S18_BEFORE_DisposeEventLoopTimerUPP' \
  'PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S19_AFTER_DisposeEventLoopTimerUPP' \
  'PM_POSTWINDOWTIMERUPPDISPOSE_RESULT:DISPOSEEVENTLOOPTIMERUPP_PASS'
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

Require i386 and build ID:

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
  "$RUNTIME/sys295-disposeeventlooptimerupp.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion DisposeEventLoopTimerUPP transfer

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
unset ROSETTA_POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_MODE
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
export ROSETTA_POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_MODE=lion-disposeeventlooptimerupp-v1

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
  ./payload/lion-disposeeventlooptimerupp.log
```

Do not run the PPC subject a second time before review. The raw transcript is:

```text
payload/lion-disposeeventlooptimerupp.raw.log
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

Require the inherited timer-side-quit and removal chain exactly once through:

```text
S14_BEFORE_RunApplicationEventLoop
timer callback ENTER
timer callback BEFORE_QuitApplicationEventLoop
timer callback AFTER_QuitApplicationEventLoop
timer callback EXIT
S15_AFTER_RunApplicationEventLoop
fired=1
RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS
S16_BEFORE_RemoveEventLoopTimer
S17_AFTER_RemoveEventLoopTimer
RemoveEventLoopTimer=0
REMOVEEVENTLOOPTIMER_PASS
```

Then require exactly:

```text
PM_POSTWINDOWTIMERUPPDISPOSE_POINTER:before=<nonzero> nonzero=YES
PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S18_BEFORE_DisposeEventLoopTimerUPP
PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S19_AFTER_DisposeEventLoopTimerUPP
PM_POSTWINDOWTIMERUPPDISPOSE_RESULT:DISPOSEEVENTLOOPTIMERUPP_PASS
disposeeventlooptimerupp_before_count=1
disposeeventlooptimerupp_after_count=1
disposeeventlooptimerupp_pass_count=1
```

Also require PPC exit 0, `M24_SUCCESS`, WBI / ColorProfileClient / ResolveColorProfile adapter-pass counts 1 / 1 / 1, OrderFront adapter-pass count 2, all six exact titlebar translations once, zero titlebar guard rejects, no new diagnostic, and unchanged protected hashes.

Final discriminator:

```text
RESULT: POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_PASS
```

There must be no `REMOVEEVENTLOOPTIMER_RETURNED_ERROR`, no `DISPOSEEVENTLOOPTIMERUPP_NULL_UPP`, no notification request after 21, no broker reject, no new compatibility behavior, and no protected-hash change.

## Failure classification

- S17 absent or Remove status nonzero: inherited Remove regression; stop.
- UPP pointer null before S18: cleanup-state mismatch; stop.
- S18 absent after Remove PASS: subject/control-flow mismatch; stop.
- S18 present but S19 absent: Lion `DisposeEventLoopTimerUPP()` no-return boundary; preserve the raw log.
- S19 present but dedicated PASS absent: subject/control-flow mismatch; stop.
- Any request after notification 21: preserve evidence and do not broaden the broker.
- Any compatibility/titlebar/integrity regression: stop and preserve evidence.
- Do not add a Dispose-specific compatibility interposer from a failed transfer without reviewing the exact evidence.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-remaining-registration-broker.info.txt
dn-runapplicationeventloop-remaining-registration-broker.sha256
sys295-disposeeventlooptimerupp.log
payload/lion-disposeeventlooptimerupp.log
payload/lion-disposeeventlooptimerupp.raw.log
```

Also return any newly named crash report or crash plist if the runner reports one.

## Reviewed Lion result

The exact Snow-proven PPC subject ran on Lion 10.7.5 / 11G63 with subject SHA-256 `15848bd9dc1a7837dbb6a0756b96e5f83f58d549c88dcfe4eeeeaa28ca8e204c` and accepted kernel SHA-256 `fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3`. The fresh syscall-295 probe again returned EBADF without SIGSYS.

The inherited timer-side-quit path completed exactly once, `RemoveEventLoopTimer()` returned status 0, and the UPP pointer remained nonzero. S18 and S19 each executed exactly once and `DISPOSEEVENTLOOPTIMERUPP_PASS` was emitted. Cleanup continued through title release, `DisposeWindow`, and `M24_SUCCESS`.

The exact twenty-one distributed-notification broker remained closed with `register=21 callback=0 rejects=0 exact=YES` / `PASS`, broker exit 0, and ingress exit `lookups=1 requests=21 callbacks=0`; no request 22 and no broker reject were observed. The six titlebar translations remained exact with zero guard rejects, no new diagnostic appeared, protected hashes were unchanged, the accepted WBI / ColorProfileClient / ResolveColorProfile adapter counts remained 1 / 1 / 1, OrderFront remained 2, and the runner ended `POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_PASS`.

This closes the incremental Carbon GUI lifecycle through event-loop timer disposal and window cleanup. The next controlled question is no longer another isolated API boundary: it is whether the original Snow-positive `ppc-carbon-gui-smoketest` that historically aborted on Lion now completes unchanged under the fully restored stack.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        LIVE-PROVEN PASS
all 21 reviewed Lion notification registrations     LIVE-PROVEN PASS
RemoveEventLoopTimer Snow                            LIVE-PROVEN PASS
RemoveEventLoopTimer Lion                            LIVE-PROVEN PASS
DisposeEventLoopTimerUPP Snow                        LIVE-PROVEN PASS
DisposeEventLoopTimerUPP Lion                        LIVE-PROVEN PASS
original Carbon GUI smoke under restored stack       NEXT: exact historical-binary retest
new compatibility families                          NO
titlebar policy broadening                          NO
XNU                                                  no source change indicated
```
