# Post-RemoveEventLoopTimer DisposeEventLoopTimerUPP Snow control

**Status: COMPLETE — PASS.** The isolated Snow control preserved the timer-side-quit and RemoveEventLoopTimer sequence, disposed the nonzero timer UPP through S18/S19, and completed with the dedicated Snow PASS discriminator. The next step is the exact-binary Lion transfer in `docs/process-manager-post-removeeventlooptimer-disposeeventlooptimerupp-lion-integration.md`.

## Objective

Advance exactly one new Carbon cleanup operation, `DisposeEventLoopTimerUPP()`, beyond the now live-proven `RemoveEventLoopTimer()` boundary.

The exact Snow-proven Remove subject was transferred unchanged to Lion 10.7.5 / 11G63 with SHA-256:

```text
dd7800673066de223ea214833b940a64c838fe0f2b6c9cde8a67276c9b8ebae2
```

That Lion run preserved the exact twenty-one distributed-notification policy, the timer-side-quit sequence through S15, then completed S16/S17 with `RemoveEventLoopTimer=0`, `REMOVEEVENTLOOPTIMER_PASS`, `M24_SUCCESS`, no new diagnostic, and unchanged protected hashes. The new boundary is therefore UPP cleanup.

This control adds only:

```text
DisposeEventLoopTimerUPP(timer_upp)
```

after the proven Remove step. It does not add another Carbon/window/timer operation.

## Pinned implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-disposeeventlooptimerupp.c
scripts/build-ppc-process-manager-disposeeventlooptimerupp-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
DisposeEventLoopTimerUPP subject       05034299592c24baf0d0edb7b4f51d6968aa256b
DisposeEventLoopTimerUPP Snow builder  61948af1a75c2c603664d8a1ec228852e3a624a4
Snow full-stack runner                 5e1221f8e10c8f792e012f0ba6ffde9afdb0c845
```

Build ID:

```text
cps-disposeeventlooptimerupp-validation-v1
```

New control mode:

```text
ROSETTA_POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_MODE=snow-disposeeventlooptimerupp-v1
```

The subject preserves the proven timer-side-quit and Remove sequence and then emits:

```text
PM_POSTWINDOWTIMERUPPDISPOSE_POINTER:before=<nonzero> nonzero=YES
PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S18_BEFORE_DisposeEventLoopTimerUPP
DisposeEventLoopTimerUPP(timer_upp)
PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S19_AFTER_DisposeEventLoopTimerUPP
PM_POSTWINDOWTIMERUPPDISPOSE_RESULT:DISPOSEEVENTLOOPTIMERUPP_PASS
```

The Snow SDK may lower `DisposeEventLoopTimerUPP()` rather than emit an undefined symbol. The builder therefore records the observed linkage as exactly one of:

```text
disposeeventlooptimerupp_linkage=undefined-import
disposeeventlooptimerupp_linkage=sdk-lowered-no-undefined-import
```

Either linkage result is acceptable for this Snow control. Do not infer a missing API call solely from the absence of an undefined `_DisposeEventLoopTimerUPP` symbol; require the pinned source expression, nonzero UPP, S18/S19, and the dedicated PASS marker.

## Safety constraints

- Snow Leopard 10.6.8 / 10K549 only for this control.
- Build a fresh PPC subject from the pinned source.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Preserve `snow-runapplicationeventloop-timer-quit-v2` with exactly one callback.
- Preserve `snow-removeeventlooptimer-v1` with status 0.
- Add only `DisposeEventLoopTimerUPP(timer_upp)`.
- Do not add another Carbon/window/timer operation after UPP disposal.
- Do not broaden CGS, CoreUI, titlebar, notification, or other compatibility.
- Do not patch Rosetta, dyld, frameworks, resources, caches, or XNU.
- No kernel rebuild or reboot.
- Run the subject exactly once before review.
- Do not perform a Lion DisposeEventLoopTimerUPP transfer until this Snow result is reviewed.

## Phase A — update and pin

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-disposeeventlooptimerupp.c)" = \
  "05034299592c24baf0d0edb7b4f51d6968aa256b" || exit 1
test "$(git hash-object ./scripts/build-ppc-process-manager-disposeeventlooptimerupp-on-snowleopard.sh)" = \
  "61948af1a75c2c603664d8a1ec228852e3a624a4" || exit 1
test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "5e1221f8e10c8f792e012f0ba6ffde9afdb0c845" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-disposeeventlooptimerupp-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1
test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the DisposeEventLoopTimerUPP subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-disposeeventlooptimerupp-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-disposeeventlooptimerupp-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
runapplicationeventloop_source_expression=RunApplicationEventLoop()
runapplicationeventloop_linkage=undefined-import
removeeventlooptimer_source_expression=RemoveEventLoopTimer(timer_ref)
removeeventlooptimer_linkage=undefined-import
removeeventlooptimer_expected_status=0
disposeeventlooptimerupp_source_expression=DisposeEventLoopTimerUPP(timer_upp)
disposeeventlooptimerupp_linkage=<undefined-import OR sdk-lowered-no-undefined-import>
disposeeventlooptimerupp_expected_result=pass
```

Require `_RemoveEventLoopTimer` in the Process Manager import block. If `disposeeventlooptimerupp_linkage=undefined-import`, require `_DisposeEventLoopTimerUPP` there too; if the linkage is `sdk-lowered-no-undefined-import`, its absence is expected.

Do not rebuild compatibility dylibs.

## Phase C — exactly one Snow DisposeEventLoopTimerUPP control

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE
unset ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE
unset ROSETTA_POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_MODE

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=snow-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=snow-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=snow-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=snow-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=snow-installeventlooptimer-v1
export ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=snow-runapplicationeventloop-timer-quit-v2
export ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE=snow-removeeventlooptimer-v1
export ROSETTA_POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_VALIDATION_MODE=snow-disposeeventlooptimerupp-v1

export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=passthrough

export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=passthrough

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/pm-titlebar-bsearch-six-key-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=passthrough

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./pm-selectwindow-orderfront-compat.dylib \
  ./pm-selectwindow-orderfront-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./pm-disposeeventlooptimerupp-snow.log || exit 1
```

Require the complete inherited timer-side-quit sequence through S15 and then:

```text
PM_POSTWINDOWTIMERREMOVE_MILESTONE:S16_BEFORE_RemoveEventLoopTimer
PM_POSTWINDOWTIMERREMOVE_MILESTONE:S17_AFTER_RemoveEventLoopTimer
PM_POSTWINDOWTIMERREMOVE_STATUS:RemoveEventLoopTimer=0
PM_POSTWINDOWTIMERREMOVE_RESULT:REMOVEEVENTLOOPTIMER_PASS
removeeventlooptimer_status=0

PM_POSTWINDOWTIMERUPPDISPOSE_POINTER:before=<nonzero> nonzero=YES
PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S18_BEFORE_DisposeEventLoopTimerUPP
PM_POSTWINDOWTIMERUPPDISPOSE_MILESTONE:S19_AFTER_DisposeEventLoopTimerUPP
PM_POSTWINDOWTIMERUPPDISPOSE_RESULT:DISPOSEEVENTLOOPTIMERUPP_PASS
disposeeventlooptimerupp_before_count=1
disposeeventlooptimerupp_after_count=1
disposeeventlooptimerupp_pass_count=1

M24_SUCCESS
control_status=0
RESULT: POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_SNOW_CONTROL_PASS
RESULT: PASS
```

The inherited callback counts must remain exactly one; Snow compatibility must remain passthrough; all six titlebar target actions must remain passthrough with zero unexpected actions; OrderFront must remain 3/3/3 passthrough with one SelectWindow-bounded and one RunApplicationEventLoop-bounded call. There must be no `REMOVEEVENTLOOPTIMER_RETURNED_ERROR`, `DISPOSEEVENTLOOPTIMERUPP_NULL_UPP`, compatibility `ADAPTER_PASS`, new diagnostic, or later FAIL.

## Failure classification

- S17 absent or Remove status nonzero: inherited Remove regression; stop.
- UPP pointer is null before S18: cleanup-state mismatch; stop.
- S18 absent after Remove PASS: subject/control-flow mismatch; stop.
- S18 present but S19 absent: `DisposeEventLoopTimerUPP()` no-return boundary; preserve the complete log.
- S19 present but dedicated PASS absent: subject/control-flow mismatch; stop.
- Any callback-count, compatibility, titlebar, or diagnostic regression: stop and preserve evidence.
- Do not add a Dispose-specific compatibility interposer from a failed control without reviewing the exact evidence.

## Return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-disposeeventlooptimerupp-snow.log
```

Do not run a Lion DisposeEventLoopTimerUPP transfer until this Snow result is reviewed.

## Reviewed Snow result

The Snow Leopard 10.6.8 / 10K549 control used exact subject SHA-256 `15848bd9dc1a7837dbb6a0756b96e5f83f58d549c88dcfe4eeeeaa28ca8e204c`, source SHA-256 `84b1ccb5a7fe61f04443fbd3878a8a114e5fd902bc87275ea7d4bd28f523e4db`, build ID `cps-disposeeventlooptimerupp-validation-v1`, PowerPC 7400, and `/usr/oah/dyld`. The Snow SDK lowered `DisposeEventLoopTimerUPP(timer_upp)` without an undefined `_DisposeEventLoopTimerUPP` import, exactly as the builder permits.

The inherited timer-side-quit sequence remained exact through S15 with one callback. S16/S17 then returned `RemoveEventLoopTimer=0` and `REMOVEEVENTLOOPTIMER_PASS`. The UPP pointer remained nonzero (`0x000023a8`), S18 and S19 each executed exactly once, and `DISPOSEEVENTLOOPTIMERUPP_PASS` was emitted. Cleanup reached `M24_SUCCESS` with `control_status=0`. All six titlebar actions remained passthrough with zero unexpected actions, OrderFront remained 3/3/3 passthrough with one SelectWindow-bounded and one RunApplicationEventLoop-bounded call, and the runner ended `POST_REMOVEEVENTLOOPTIMER_DISPOSEEVENTLOOPTIMERUPP_SNOW_CONTROL_PASS` / `RESULT: PASS`.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        LIVE-PROVEN through S15
all 21 reviewed Lion notification registrations     LIVE-PROVEN PASS
RemoveEventLoopTimer Snow                            LIVE-PROVEN PASS
RemoveEventLoopTimer Lion                            LIVE-PROVEN PASS
DisposeEventLoopTimerUPP Snow                        LIVE-PROVEN PASS
DisposeEventLoopTimerUPP Lion                        NEXT: guarded exact-binary transfer
new compatibility families                          NO
titlebar policy broadening                          NO
XNU                                                  no source change indicated
```
