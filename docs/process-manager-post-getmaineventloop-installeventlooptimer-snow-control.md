# Post-GetMainEventLoop InstallEventLoopTimer Snow control

## Objective

Advance exactly one public Carbon operation beyond the live-proven Lion `GetMainEventLoop()` boundary by isolating `InstallEventLoopTimer` on Snow Leopard 10.6.8 first.

The historical Carbon milestone used:

```text
InstallEventLoopTimer(GetMainEventLoop(),
                      2.0 * kEventDurationSecond,
                      0.0,
                      timerUPP,
                      &gTimerFired,
                      &timer)
```

The preceding Snow/Lion controls have already isolated and live-proven both nested prerequisites: `NewEventLoopTimerUPP(ProbeTimer)` and `GetMainEventLoop()`. This stage therefore installs only the timer, using the already obtained EventLoopRef and UPP, and then exits normally without entering the event loop. It does **not** remove the timer, dispose the UPP, or run the event loop; process teardown is intentionally used so no second public timer operation is introduced.

## Reviewed predecessor

The guarded Lion `GetMainEventLoop()` integration is closed:

```text
Lion 10.7.5 / 11G63
accepted kernel SHA
exact Snow subject SHA-256=27a91765c2815bd885828a1785776cb0fa0c30f146b92d682be84b0691e724f8
S06_BEFORE_NewEventLoopTimerUPP
S07_AFTER_NewEventLoopTimerUPP
UPP pointer=nonzero
NEWEVENTLOOPTIMERUPP_PASS
S08_BEFORE_GetMainEventLoop
S09_AFTER_GetMainEventLoop
EventLoopRef=0x004a6da0 nonzero=YES
GETMAINEVENTLOOP_PASS
M24_SUCCESS
createwindow_validation_exec_status=0
exact-seven register=7 callback=0 rejects=0 exact=YES
protected_hashes_unchanged=YES
new diagnostics=none
final=POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_PASS
```

No GetMainEventLoop-specific compatibility rule is indicated.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-installeventlooptimer.c
scripts/build-ppc-process-manager-installeventlooptimer-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
InstallEventLoopTimer subject       b2c78be3e80f0a13029ee73639132d562d4f4ce1
InstallEventLoopTimer Snow builder  73824b2f23a78ca05983eee7df747e9e07fbec76
Snow full-stack runner              f97ff3c472c7be73819df2346a3c999d8fa639af
```

The new subject preserves every already proven operation and adds only:

```text
S10_BEFORE_InstallEventLoopTimer
InstallEventLoopTimer(main_event_loop,
                      2.0 * kEventDurationSecond,
                      0.0,
                      timer_upp,
                      &g_timer_fired,
                      &timer_ref)
S11_AFTER_InstallEventLoopTimer
PM_POSTWINDOWTIMERINSTALL_STATUS:InstallEventLoopTimer=<status>
PM_POSTWINDOWTIMERINSTALL_POINTER:pointer=<value> nonzero=<YES|NO>
PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=<0|1>
PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS
```

The callback has a diagnostic marker if it fires unexpectedly, but this control never enters the event loop. Acceptance requires `fired=0` and no callback marker.

## Safety constraints

- Run the new subject on Snow Leopard only.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Do not call `RunApplicationEventLoop` or `QuitApplicationEventLoop`.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add another public Carbon/window/timer operation.
- Do not broaden any CGS/CoreUI/titlebar/notification policy.
- Do not patch Rosetta, dyld, framework binaries, resources, caches, or XNU.
- No kernel rebuild or reboot.
- Do not infer a callback/event-loop result from timer installation alone.

## Phase A — update and pin

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-installeventlooptimer.c)" = \
  "b2c78be3e80f0a13029ee73639132d562d4f4ce1" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-installeventlooptimer-on-snowleopard.sh)" = \
  "73824b2f23a78ca05983eee7df747e9e07fbec76" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "f97ff3c472c7be73819df2346a3c999d8fa639af" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-installeventlooptimer-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the InstallEventLoopTimer subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-installeventlooptimer-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-installeventlooptimer-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)
getmaineventloop_source_expression=GetMainEventLoop()
getmaineventloop_linkage=undefined-import
installeventlooptimer_source_expression=InstallEventLoopTimer(main_event_loop,2.0*kEventDurationSecond,0.0,timer_upp,&g_timer_fired,&timer_ref)
installeventlooptimer_linkage=undefined-import
installeventlooptimer_callback_expected_before_event_loop=0
imports _GetMainEventLoop
imports _InstallEventLoopTimer
```

The NewEventLoopTimerUPP linkage remains diagnostic only and may be `sdk-lowered-no-undefined-import`.

Do not rebuild any compatibility dylib.

## Phase C — Snow InstallEventLoopTimer control

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

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=snow-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=snow-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=snow-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=snow-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=snow-installeventlooptimer-v1

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
  ./pm-installeventlooptimer-snow.log || exit 1
```

Require:

```text
PM_CPS_CREATEWINDOW_BUILD_ID:cps-installeventlooptimer-validation-v1
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
S05_AFTER_IsWindowVisible
PM_POSTWINDOWVISIBLE_VALUE:visible=1
ISWINDOWVISIBLE_PASS
S06_BEFORE_NewEventLoopTimerUPP
S07_AFTER_NewEventLoopTimerUPP
PM_POSTWINDOWTIMERUPP_POINTER:pointer=<nonzero> nonzero=YES
NEWEVENTLOOPTIMERUPP_PASS
S08_BEFORE_GetMainEventLoop
S09_AFTER_GetMainEventLoop
PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=<nonzero> nonzero=YES
GETMAINEVENTLOOP_PASS
S10_BEFORE_InstallEventLoopTimer
S11_AFTER_InstallEventLoopTimer
PM_POSTWINDOWTIMERINSTALL_STATUS:InstallEventLoopTimer=0
PM_POSTWINDOWTIMERINSTALL_POINTER:pointer=<nonzero> nonzero=YES
PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=0
PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS
M24_SUCCESS
control_status=0
cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1
coreui_titlebar_unexpected_action_count=0
RESULT: POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_SNOW_CONTROL_PASS
RESULT: PASS
```

All six titlebar target actions must remain passthrough. There must be no compatibility `ADAPTER_PASS`, no install-error/null-timer marker, no `PM_POSTWINDOWTIMER_CALLBACK:FIRED`, and no later FAIL.

If S10 appears without S11, preserve the complete log and stop at the `InstallEventLoopTimer` no-return boundary. If S11 returns nonzero status, a null timer reference, or an unexpected callback, preserve the complete log and do not proceed to event-loop execution.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-installeventlooptimer-snow.log
```

Do not transfer or execute this new subject on Lion until the Snow evidence is reviewed.

## Reviewed Snow result

The Snow Leopard 10.6.8 / 10K549 control passes completely. The exact PPC7400 subject SHA-256 is `e2716844ad59ceb12319a63446e876f4a274276e320b2ec80656aad25a1e040d`; it uses `/usr/oah/dyld`, preserves SDK-lowered `NewEventLoopTimerUPP(ProbeTimer)`, and carries undefined imports for both `_GetMainEventLoop` and `_InstallEventLoopTimer`. After the inherited window/visibility/UPP/main-loop path passes, S10 and S11 both execute, `InstallEventLoopTimer` returns status 0, the EventLoopTimerRef is nonzero (`0x0041f400`), the callback remains unfired (`fired=0`), and `INSTALLEVENTLOOPTIMER_PASS` is emitted.

Cleanup reaches `M24_SUCCESS` with `control_status=0`; both OrderFront calls remain passthrough with exactly one SelectWindow-bounded call, all six titlebar targets remain passthrough with zero unexpected action, no compatibility family emits `ADAPTER_PASS`, and the run ends `POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_SNOW_CONTROL_PASS` / `PASS`. No timer-install-specific compatibility rule is indicated.

The subsequent guarded Lion `InstallEventLoopTimer` run also passes with the exact Snow-proven subject. Lion reaches S10/S11, returns status 0 and nonzero EventLoopTimerRef `0x00333db0`, keeps the callback unfired, emits `INSTALLEVENTLOOPTIMER_PASS`, reaches `M24_SUCCESS`, exits 0, preserves exact-seven and all accepted user-space compatibility counts, changes no protected hash, creates no new diagnostic, and ends with `POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_PASS`.

Current `main` therefore advances only to `docs/process-manager-post-installeventlooptimer-quitapplicationeventloop-snow-control.md`. That Snow-first control isolates the historical callback-side prerequisite `QuitApplicationEventLoop()` as a direct call while no application event loop is active, so the call/return ABI boundary is proven before `RunApplicationEventLoop` is introduced. Do not infer active-loop quit semantics, dispatch the timer callback, run the application event loop, remove the timer, or dispose the UPP until that result is reviewed.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Snow                    PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop                         NEXT: Snow call/return control only
timer callback dispatch                         HELD
RunApplicationEventLoop                         HELD
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
