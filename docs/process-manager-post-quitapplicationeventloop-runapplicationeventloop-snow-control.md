# Post-QuitApplicationEventLoop RunApplicationEventLoop Snow control

## Objective

Advance exactly one public Carbon operation beyond the live-proven Lion `QuitApplicationEventLoop()` call/return boundary by isolating `RunApplicationEventLoop()` on Snow Leopard 10.6.8 first.

The historical Carbon milestone enters `RunApplicationEventLoop()`, lets the installed one-shot timer fire, and calls `QuitApplicationEventLoop()` from that timer callback. Running that full interaction now would combine event-loop entry, timer callback dispatch, and active-loop quit semantics in one step. This control avoids that broadening.

The already proven `QuitApplicationEventLoop()` call is executed **before** `RunApplicationEventLoop()`. Apple Technical Q&A QA1061 describes `QuitApplicationEventLoop` as a simple wrapper that posts a `kEventClassApplication/kEventAppQuit` event to the event loop. The new subject therefore prequeues that quit event, then adds only the new public call `RunApplicationEventLoop()`. Acceptance requires the event loop to consume the prequeued quit and return before the installed two-second timer callback runs.

The callback remains a failure tripwire only: under this validation macro, if it is dispatched unexpectedly it emits the existing `PM_POSTWINDOWTIMER_CALLBACK:FIRED` marker and immediately calls `_exit(48)`. This bounds the ordinary failure case without adding another Carbon operation or claiming callback success.

The closed predecessor is:

```text
Snow QuitApplicationEventLoop no-active-loop call/return = PASS
Lion QuitApplicationEventLoop no-active-loop call/return = PASS
exact Snow/Lion quit subject SHA-256 =
  af36d6efe9e3193c3b68ac149d50be5627f1ba33ad0c5223e2ed1bdf3982eb01
Lion S12 / S13 = reached
Lion callback fired=0
Lion QUITAPPLICATIONEVENTLOOP_PASS
Lion M24_SUCCESS
Lion subject exit=0
Lion exact-seven register=7 callback=0 rejects=0 exact=YES
Lion protected hashes unchanged
Lion new diagnostics=none
Lion final=POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_PASS
```

No quit-specific compatibility rule is indicated.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
RunApplicationEventLoop subject       8eb7dd0496ed1731eaf04f18a4d0e69edf5d1db6
RunApplicationEventLoop Snow builder  a0a8bfb3b0a6c62626a0ae292d229d54d9a20d8d
Snow full-stack runner                 d77dd2dc514bf6a9bcc8afd5e02fbe53e8752e85
```

The new build ID is:

```text
cps-runapplicationeventloop-prequeued-quit-validation-v1
```

The cumulative subject preserves every already proven public operation and adds only:

```text
S14_BEFORE_RunApplicationEventLoop
RunApplicationEventLoop()
S15_AFTER_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=0
PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_PREQUEUED_QUIT_PASS
```

The already installed two-second one-shot timer remains installed until process exit. Its callback must not be dispatched on an accepted run.

## Safety constraints

- Run this new subject on Snow Leopard only.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Prequeue the quit only with the already proven direct `QuitApplicationEventLoop()` call before event-loop entry.
- Do not call `QuitApplicationEventLoop()` from the timer callback.
- Do not deliberately dispatch the timer callback.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add another public Carbon/window/timer operation.
- Do not treat the callback tripwire as a successful callback test.
- Do not infer active-loop callback-side quit semantics from this control.
- Do not broaden CGS/CoreUI/titlebar/notification compatibility.
- Do not patch Rosetta, dyld, framework binaries, resources, caches, or XNU.
- No kernel rebuild or reboot.
- If S14 is reached but neither S15 nor the callback tripwire appears within 10 seconds, interrupt the run externally, preserve the complete log, and stop. Do not retry before review.

## Phase A — update and pin

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "8eb7dd0496ed1731eaf04f18a4d0e69edf5d1db6" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh)" = \
  "a0a8bfb3b0a6c62626a0ae292d229d54d9a20d8d" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "d77dd2dc514bf6a9bcc8afd5e02fbe53e8752e85" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the prequeued-quit RunApplicationEventLoop subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-runapplicationeventloop-prequeued-quit-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-runapplicationeventloop-prequeued-quit-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
quitapplicationeventloop_source_expression=QuitApplicationEventLoop()
quitapplicationeventloop_linkage=undefined-import
quitapplicationeventloop_context=prequeue-before-runapplicationeventloop
runapplicationeventloop_source_expression=RunApplicationEventLoop()
runapplicationeventloop_linkage=undefined-import
runapplicationeventloop_exit_condition=prequeued-kEventAppQuit
runapplicationeventloop_callback_expected=0
runapplicationeventloop_callback_failure_tripwire=_exit(48)
imports _QuitApplicationEventLoop
imports _RunApplicationEventLoop
```

Do not rebuild any compatibility dylib.

## Phase C — Snow prequeued-quit RunApplicationEventLoop control

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
export ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=snow-runapplicationeventloop-prequeued-quit-v1

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
  ./pm-runapplicationeventloop-prequeued-quit-snow.log || exit 1
```

Require the complete inherited sequence through `QUITAPPLICATIONEVENTLOOP_PASS`, then:

```text
PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=0
PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_PREQUEUED_QUIT_PASS
M24_SUCCESS
control_status=0
cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1
coreui_titlebar_unexpected_action_count=0
RESULT: POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_SNOW_CONTROL_PASS
RESULT: PASS
```

All six titlebar target actions must remain passthrough. There must be no compatibility `ADAPTER_PASS`, no `PM_POSTWINDOWTIMER_CALLBACK:FIRED`, no RunApplicationEventLoop unexpected-callback result, and no later FAIL.

Failure classification:

- S14 absent: inherited regression; stop.
- S14 present, callback tripwire present, S15 absent: the prequeued quit did not return the application event loop before the installed timer became dispatchable; stop with the callback evidence.
- S14 present, neither S15 nor callback tripwire after 10 seconds: externally interrupt, preserve the complete log, and stop.
- S15 present with callback state nonzero: semantic failure; stop.
- Any new compatibility behavior or diagnostic: preserve evidence and do not broaden compatibility.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-runapplicationeventloop-prequeued-quit-snow.log
```

Do not transfer or execute this new subject on Lion until the Snow evidence is reviewed.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop on Snow                 PASS
QuitApplicationEventLoop on Lion                 LIVE-PROVEN PASS
RunApplicationEventLoop                          NEXT: Snow prequeued-quit call/return control
timer callback dispatch                         HELD (tripwire only)
active-loop callback-side Quit                   HELD
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
