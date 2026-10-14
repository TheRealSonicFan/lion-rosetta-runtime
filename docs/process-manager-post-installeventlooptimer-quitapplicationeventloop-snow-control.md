# Post-InstallEventLoopTimer QuitApplicationEventLoop Snow control

## Objective

Advance exactly one public Carbon operation beyond the live-proven Lion `InstallEventLoopTimer` boundary by isolating `QuitApplicationEventLoop()` on Snow Leopard 10.6.8 first.

The historical Carbon milestone invokes `QuitApplicationEventLoop()` from the timer callback after `RunApplicationEventLoop()` has started. Testing that historical pair immediately would introduce a second new public Carbon operation in the same step. This control therefore proves only the `QuitApplicationEventLoop()` call/return ABI boundary with no application event loop active. It does **not** claim active-loop quit semantics and does not exercise timer callback dispatch.

The closed predecessor is:

```text
Lion 10.7.5 / 11G63
subject SHA-256=e2716844ad59ceb12319a63446e876f4a274276e320b2ec80656aad25a1e040d
InstallEventLoopTimer status=0
EventLoopTimerRef=0x00333db0 nonzero=YES
callback fired=0
INSTALLEVENTLOOPTIMER_PASS
M24_SUCCESS
subject exit=0
exact-seven register=7 callback=0 rejects=0 exact=YES
all six titlebar translations=1
titlebar guard rejects=0
protected_hashes_unchanged=YES
new diagnostics=none
final=POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_PASS
```

No timer-install-specific compatibility rule is indicated.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-quitapplicationeventloop.c
scripts/build-ppc-process-manager-quitapplicationeventloop-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
QuitApplicationEventLoop subject       fb836df7a60cb1d9c1c9b3db8284eb27586bc2b4
QuitApplicationEventLoop Snow builder  d02bd9c9001b74b95e5654134bb3f547b51412cb
Snow full-stack runner                  d6eaaa559be2b9b49ba1b8fae50f32bf90aefede
```

The new subject preserves every already proven public operation and adds only:

```text
S12_BEFORE_QuitApplicationEventLoop
QuitApplicationEventLoop()
S13_AFTER_QuitApplicationEventLoop
PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=0
PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS
```

The already installed one-shot timer remains installed until process exit. Because this stage never enters the application event loop, the timer callback must remain unfired.

## Safety constraints

- Run the new subject on Snow Leopard only.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Do not call `RunApplicationEventLoop` or deliberately dispatch the timer callback.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add another public Carbon/window/timer operation.
- Do not infer active-loop quit behavior from this control.
- Do not broaden any CGS/CoreUI/titlebar/notification policy.
- Do not patch Rosetta, dyld, framework binaries, resources, caches, or XNU.
- No kernel rebuild or reboot.

## Phase A — update and pin

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-quitapplicationeventloop.c)" = \
  "fb836df7a60cb1d9c1c9b3db8284eb27586bc2b4" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-quitapplicationeventloop-on-snowleopard.sh)" = \
  "d02bd9c9001b74b95e5654134bb3f547b51412cb" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "d6eaaa559be2b9b49ba1b8fae50f32bf90aefede" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-quitapplicationeventloop-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the QuitApplicationEventLoop subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-quitapplicationeventloop-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-quitapplicationeventloop-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)
getmaineventloop_source_expression=GetMainEventLoop()
installeventlooptimer_source_expression=InstallEventLoopTimer(main_event_loop,2.0*kEventDurationSecond,0.0,timer_upp,&g_timer_fired,&timer_ref)
quitapplicationeventloop_source_expression=QuitApplicationEventLoop()
quitapplicationeventloop_linkage=undefined-import
quitapplicationeventloop_context=no-active-application-event-loop
quitapplicationeventloop_callback_expected=0
imports _GetMainEventLoop
imports _InstallEventLoopTimer
imports _QuitApplicationEventLoop
```

Do not rebuild any compatibility dylib.

## Phase C — Snow QuitApplicationEventLoop control

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
export ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE=snow-quitapplicationeventloop-v1

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
  ./pm-quitapplicationeventloop-snow.log || exit 1
```

Require the complete inherited sequence through `INSTALLEVENTLOOPTIMER_PASS`, then:

```text
PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S12_BEFORE_QuitApplicationEventLoop
PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S13_AFTER_QuitApplicationEventLoop
PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=0
PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS
M24_SUCCESS
control_status=0
cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1
coreui_titlebar_unexpected_action_count=0
RESULT: POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_SNOW_CONTROL_PASS
RESULT: PASS
```

All six titlebar target actions must remain passthrough. There must be no compatibility `ADAPTER_PASS`, no `PM_POSTWINDOWTIMER_CALLBACK:FIRED`, no unexpected-callback result, and no later FAIL.

If S12 appears without S13, preserve the complete log and stop at the `QuitApplicationEventLoop` no-return boundary. Do not proceed to `RunApplicationEventLoop` from a failed or ambiguous result.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-quitapplicationeventloop-snow.log
```

Do not transfer or execute this new subject on Lion until the Snow evidence is reviewed.

## Reviewed Snow result

The Snow Leopard 10.6.8 / 10K549 call/return control passes completely. The exact PPC7400 subject SHA-256 is `af36d6efe9e3193c3b68ac149d50be5627f1ba33ad0c5223e2ed1bdf3982eb01`; its build ID is `cps-quitapplicationeventloop-validation-v1`, it uses `/usr/oah/dyld`, and it carries undefined imports for `_GetMainEventLoop`, `_InstallEventLoopTimer`, and `_QuitApplicationEventLoop`. The inherited timer installation still returns status 0 with EventLoopTimerRef `0x0041f400` and callback `fired=0`. S12 and S13 both execute, the callback remains unfired after the direct no-active-loop quit call, and `QUITAPPLICATIONEVENTLOOP_PASS` is emitted.

Cleanup reaches `M24_SUCCESS` with `control_status=0`; all six titlebar actions remain passthrough with zero unexpected action, both OrderFront calls remain passthrough with exactly one SelectWindow-bounded call, no compatibility family emits `ADAPTER_PASS`, and the run ends `POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_SNOW_CONTROL_PASS` / `PASS`. This proves only the direct `QuitApplicationEventLoop()` call/return ABI boundary while no application event loop is active; it does not prove active-loop quit semantics.

The subsequent guarded Lion no-active-loop `QuitApplicationEventLoop()` run also passes with the exact Snow-proven subject. Lion reaches S12/S13, preserves callback `fired=0`, emits `QUITAPPLICATIONEVENTLOOP_PASS`, reaches `M24_SUCCESS`, exits 0, preserves exact-seven and all accepted user-space compatibility counts, changes no protected hash, creates no new diagnostic, and ends with `POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_PASS`.

The subsequent Snow event-loop work first retired the prequeued-quit v1 design, then live-proved timer-side-quit v2 with exact subject SHA-256 `059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7`: the installed timer dispatches exactly once while `RunApplicationEventLoop()` is active, callback-side `QuitApplicationEventLoop()` returns, the callback exits, and the event loop returns with `fired=1`. Current `main` now advances to the exact-binary Lion transfer in `docs/process-manager-post-quitapplicationeventloop-runapplicationeventloop-lion-integration.md`.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop direct/no-active-loop   LIVE-PROVEN PASS on Snow + Lion
RunApplicationEventLoop timer-side-quit v2 Snow  LIVE-PROVEN PASS
timer callback dispatch on Snow                  LIVE-PROVEN PASS in v2 context
active-loop callback-side Quit on Snow            LIVE-PROVEN PASS in v2 context
RunApplicationEventLoop timer-side-quit v2 Lion  NEXT: guarded exact-binary transfer
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no source change indicated
```
