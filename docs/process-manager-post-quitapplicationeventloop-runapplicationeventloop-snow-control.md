# Post-QuitApplicationEventLoop RunApplicationEventLoop Snow control — corrected timer-quit v2

## Objective

Advance exactly one new public Carbon call, `RunApplicationEventLoop()`, beyond the live-proven Snow and Lion `QuitApplicationEventLoop()` call/return boundary.

The first version of this control attempted to call `QuitApplicationEventLoop()` before entering `RunApplicationEventLoop()`, expecting the posted application-quit event to make the subsequent event loop return immediately. The returned Snow evidence disproves that assumption: the subject reached S14, never reached S15, remained in `RunApplicationEventLoop()` until the already installed two-second timer fired, then hit the deliberate callback tripwire and exited 48. This is a test-design failure, not evidence for a new compatibility rule.

The corrected v2 control follows the historical Carbon pattern instead. The already proven `QuitApplicationEventLoop()` API is called from the installed one-shot timer callback while `RunApplicationEventLoop()` is active. The callback must execute exactly once, return from `QuitApplicationEventLoop()`, return from the callback, and then allow `RunApplicationEventLoop()` to return. `RemoveEventLoopTimer` and `DisposeEventLoopTimerUPP` remain held; the short-lived process owns cleanup at exit.

This stage therefore adds only one **new public Carbon API** (`RunApplicationEventLoop`), but it necessarily validates two new contextual behaviors at the same time: timer callback dispatch while the application event loop is running, and the already-proven `QuitApplicationEventLoop` call in its active-loop callback context. Do not interpret those semantics as separately isolated API proofs.

## Reviewed v1 failure

The failed Snow 10.6.8 / 10K549 run used:

```text
build_id=cps-runapplicationeventloop-prequeued-quit-validation-v1
subject SHA-256=d439befca55217639e4e01fd649d53d016809acd13fbe3dbae440dd1ffec7cfc
source SHA-256=b6352cb2d94683d67106af51563e1cdfdbaab45e920d8b5a85364593bb9ab4ee
dyld=/usr/oah/dyld
arch=ppc7400
```

The inherited stack passed through timer installation and the direct prequeue call:

```text
InstallEventLoopTimer=0
EventLoopTimerRef=nonzero
timer callback before event-loop entry=0
S12_BEFORE_QuitApplicationEventLoop
S13_AFTER_QuitApplicationEventLoop
QUITAPPLICATIONEVENTLOOP_PASS
S14_BEFORE_RunApplicationEventLoop
```

Then:

```text
S15_AFTER_RunApplicationEventLoop=ABSENT
PM_POSTWINDOWTIMER_CALLBACK:FIRED
control_status=48
RESULT: FAIL
```

Therefore the prequeued quit did not terminate the subsequent `RunApplicationEventLoop()` before the two-second one-shot timer became dispatchable. The v1 prequeue model is retired and must not be repeated.

## Corrected implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

The filenames are retained for continuity, but the implementation is now timer-side-quit v2.

Pinned blobs:

```text
RunApplicationEventLoop subject       97e410dd71e545c393e0ce6889678a6436ff8ea1
RunApplicationEventLoop Snow builder  5691e3d2b73115f38e85907e07ba20dfbd46dfd0
Snow full-stack runner                 42327c5b78707e6b3ba0e6b2e3927ec89588735b
```

Corrected build ID:

```text
cps-runapplicationeventloop-timer-quit-validation-v2
```

Corrected mode:

```text
ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=snow-runapplicationeventloop-timer-quit-v2
```

The v2 subject deliberately does **not** execute the earlier direct S12/S13 prequeue call. The already-proven quit API is instead called only from the timer callback while the application event loop is active:

```text
S14_BEFORE_RunApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:ENTER
PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop
QuitApplicationEventLoop()
PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:EXIT
S15_AFTER_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1
PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS
```

The one-shot timer interval remains two seconds and its repeat interval remains zero.

## Safety constraints

- Run the corrected subject on Snow Leopard only.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Do not set `ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE` in this corrected stage; the direct prequeue design is retired.
- Do not add another public Carbon/window/timer operation.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add a timer-, event-loop-, or quit-specific compatibility interposer from this failure.
- Do not broaden CGS/CoreUI/titlebar/notification compatibility.
- Do not patch Rosetta, dyld, frameworks, resources, caches, or XNU.
- No kernel rebuild or reboot.
- If S14 is reached and neither the callback ENTER marker nor S15 appears within 10 seconds, interrupt externally, preserve the complete log, and stop.
- If the callback ENTER marker appears but the callback does not reach AFTER_QuitApplicationEventLoop and EXIT, preserve the complete log and stop.
- Do not execute a Lion v2 integration until the corrected Snow result is reviewed.

## Phase A — update and pin

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh)" = \
  "5691e3d2b73115f38e85907e07ba20dfbd46dfd0" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "42327c5b78707e6b3ba0e6b2e3927ec89588735b" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — rebuild only the corrected v2 subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-runapplicationeventloop-timer-quit-validation-v2
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)
getmaineventloop_source_expression=GetMainEventLoop()
installeventlooptimer_source_expression=InstallEventLoopTimer(...)
quitapplicationeventloop_source_expression=QuitApplicationEventLoop()
quitapplicationeventloop_linkage=undefined-import
quitapplicationeventloop_context=installed-timer-callback-while-runapplicationeventloop-active
quitapplicationeventloop_callback_expected=1
runapplicationeventloop_source_expression=RunApplicationEventLoop()
runapplicationeventloop_linkage=undefined-import
runapplicationeventloop_exit_condition=installed-timer-callback-calls-QuitApplicationEventLoop
runapplicationeventloop_callback_expected=1
runapplicationeventloop_callback_contract=exactly-one-callback-before-return
imports _QuitApplicationEventLoop
imports _RunApplicationEventLoop
```

Do not rebuild any compatibility dylib.

## Phase C — corrected Snow timer-side-quit control

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

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=snow-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=snow-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=snow-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=snow-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=snow-installeventlooptimer-v1
export ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=snow-runapplicationeventloop-timer-quit-v2

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
  ./pm-runapplicationeventloop-timer-quit-snow.log || exit 1
```

Require the complete inherited sequence through `INSTALLEVENTLOOPTIMER_PASS`, then exactly:

```text
PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:ENTER
PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:EXIT
PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1
PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS
M24_SUCCESS
control_status=0
runapplicationeventloop_timer_callback_enter_count=1
runapplicationeventloop_timer_callback_before_quit_count=1
runapplicationeventloop_timer_callback_after_quit_count=1
runapplicationeventloop_timer_callback_exit_count=1
cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1
coreui_titlebar_unexpected_action_count=0
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_SNOW_CONTROL_PASS
RESULT: PASS
```

All six titlebar target actions must remain passthrough. There must be no compatibility `ADAPTER_PASS`, no legacy `PM_POSTWINDOWTIMER_CALLBACK:FIRED` marker, no `RUNAPPLICATIONEVENTLOOP_TIMER_CALLBACK_COUNT_MISMATCH`, and no later FAIL.

Failure classification:

- S14 absent: inherited regression; stop.
- S14 present but callback ENTER absent after 10 seconds: event-loop/timer dispatch boundary; interrupt externally, preserve the log, and stop.
- callback ENTER present but BEFORE_Quit absent: callback-body failure before the already proven quit call; stop.
- BEFORE_Quit present but AFTER_Quit absent: active-loop callback-side `QuitApplicationEventLoop` no-return boundary; stop.
- callback EXIT present but S15 absent: `RunApplicationEventLoop` did not return after a completed callback-side quit; stop.
- S15 present with `fired!=1` or callback marker counts other than one: callback-state/count mismatch; stop.
- Any new compatibility behavior or diagnostic: preserve evidence and do not broaden compatibility.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-runapplicationeventloop-timer-quit-snow.log
```

Do not transfer or execute the corrected v2 subject on Lion until the Snow evidence is reviewed.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop on Snow                 PASS (direct no-active-loop)
QuitApplicationEventLoop on Lion                 LIVE-PROVEN PASS (direct no-active-loop)
RunApplicationEventLoop prequeued-quit v1        FAILED TEST DESIGN; RETIRED
RunApplicationEventLoop timer-side-quit v2       NEXT: corrected Snow control
timer callback dispatch                         exercised only inside corrected v2
active-loop callback-side Quit                   exercised only inside corrected v2
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
