# Post-RunApplicationEventLoop RemoveEventLoopTimer Snow control

**Status: COMPLETE — PASS.** The isolated Snow control returned `RemoveEventLoopTimer=0`, preserved the proven timer-side-quit sequence, and completed with the dedicated Snow PASS discriminator. The next step is the exact-binary Lion transfer in `docs/process-manager-post-runapplicationeventloop-removeeventlooptimer-lion-integration.md`.

## Objective

Advance exactly one new public Carbon cleanup call, `RemoveEventLoopTimer()`, beyond the now live-proven RunApplicationEventLoop timer-side-quit path and the closed twenty-one-registration distributed-notification boundary.

The reviewed Lion run accepts all 21 known notification registrations exactly, reaches the timer callback once, returns from callback-side `QuitApplicationEventLoop()`, reaches S15 and `M24_SUCCESS`, exits 0, creates no new diagnostic, and preserves protected hashes. No request after notification index 21 was observed. The next unresolved boundary is therefore timer cleanup, not notification policy or XNU.

This control isolates only `RemoveEventLoopTimer(timer_ref)` on Snow Leopard. `DisposeEventLoopTimerUPP()` remains held.

## Pinned implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-removeeventlooptimer.c
scripts/build-ppc-process-manager-removeeventlooptimer-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
RemoveEventLoopTimer subject       e9a88a33c7e2e5521ef4bc8c7ba5c512a15581d9
RemoveEventLoopTimer Snow builder  6201630d19efa50c0241ccec037020203310fd34
Snow full-stack runner             4c459e3c7cf20c0f8c613da2e215ea277f470abc
```

Build ID:

```text
cps-removeeventlooptimer-validation-v1
```

New control mode:

```text
ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE=snow-removeeventlooptimer-v1
```

The subject preserves the proven timer-side-quit sequence and then executes only:

```text
PM_POSTWINDOWTIMERREMOVE_MILESTONE:S16_BEFORE_RemoveEventLoopTimer
RemoveEventLoopTimer(timer_ref)
PM_POSTWINDOWTIMERREMOVE_MILESTONE:S17_AFTER_RemoveEventLoopTimer
PM_POSTWINDOWTIMERREMOVE_STATUS:RemoveEventLoopTimer=<status>
PM_POSTWINDOWTIMERREMOVE_RESULT:REMOVEEVENTLOOPTIMER_PASS
```

The builder requires an undefined `_RemoveEventLoopTimer` import and rejects any undefined `_DisposeEventLoopTimerUPP` import.

## Safety constraints

- Snow Leopard 10.6.8 / 10K549 only for this control.
- Build a fresh PPC subject from the pinned source; do not reuse the Lion exact-registration subject.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Preserve `snow-runapplicationeventloop-timer-quit-v2` and its exactly-one callback contract.
- Add only `RemoveEventLoopTimer()`.
- Do not call or import `DisposeEventLoopTimerUPP()`.
- Do not add another Carbon/window/timer operation.
- Do not broaden CGS, CoreUI, titlebar, notification, or other compatibility.
- Do not patch Rosetta, dyld, frameworks, resources, caches, or XNU.
- No kernel rebuild or reboot.
- Run the subject exactly once before review.

## Phase A — update and pin

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-removeeventlooptimer.c)" = \
  "e9a88a33c7e2e5521ef4bc8c7ba5c512a15581d9" || exit 1
test "$(git hash-object ./scripts/build-ppc-process-manager-removeeventlooptimer-on-snowleopard.sh)" = \
  "6201630d19efa50c0241ccec037020203310fd34" || exit 1
test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "4c459e3c7cf20c0f8c613da2e215ea277f470abc" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-removeeventlooptimer-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1
test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the RemoveEventLoopTimer subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-removeeventlooptimer-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-removeeventlooptimer-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
runapplicationeventloop_source_expression=RunApplicationEventLoop()
runapplicationeventloop_linkage=undefined-import
removeeventlooptimer_source_expression=RemoveEventLoopTimer(timer_ref)
removeeventlooptimer_linkage=undefined-import
removeeventlooptimer_expected_status=0
disposeeventlooptimerupp=held
imports _RemoveEventLoopTimer
does not import _DisposeEventLoopTimerUPP
```

Do not rebuild compatibility dylibs.

## Phase C — exactly one Snow RemoveEventLoopTimer control

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

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=snow-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=snow-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=snow-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=snow-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=snow-installeventlooptimer-v1
export ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=snow-runapplicationeventloop-timer-quit-v2
export ROSETTA_POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_VALIDATION_MODE=snow-removeeventlooptimer-v1

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
  ./pm-removeeventlooptimer-snow.log || exit 1
```

Require the complete inherited timer-side-quit sequence through:

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
M24_SUCCESS
control_status=0
removeeventlooptimer_status=0
RESULT: POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_SNOW_CONTROL_PASS
RESULT: PASS
```

The inherited callback counts must remain exactly one; Snow compatibility must remain passthrough; all six titlebar target actions must remain passthrough with zero unexpected actions; and the existing RunApplicationEventLoop-bounded OrderFront accounting must remain exact. There must be no `REMOVEEVENTLOOPTIMER_RETURNED_ERROR`, compatibility `ADAPTER_PASS`, new diagnostic, or later FAIL.

## Failure classification

- S15 absent: inherited RunApplicationEventLoop regression; stop.
- S16 absent after S15: subject/control-flow mismatch; stop.
- S16 present but S17 absent: `RemoveEventLoopTimer()` no-return boundary; preserve the complete log.
- S17 present with nonzero status: native Snow API error boundary; preserve evidence and do not add compatibility.
- Any callback-count, compatibility, titlebar, or diagnostic regression: stop and preserve evidence.

## Return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-removeeventlooptimer-snow.log
```

Do not run a Lion RemoveEventLoopTimer transfer and do not add `DisposeEventLoopTimerUPP()` until this Snow result is reviewed.

## Reviewed Snow result

The exact Snow Leopard 10.6.8 / 10K549 control used subject SHA-256 `dd7800673066de223ea214833b940a64c838fe0f2b6c9cde8a67276c9b8ebae2`, source SHA-256 `2021886ba715439a9f2f4fbcb206170b1dae652ddd3c2a616f6ee494d47a1dde`, build ID `cps-removeeventlooptimer-validation-v1`, PowerPC 7400, and `/usr/oah/dyld`. The binary imports `_RemoveEventLoopTimer` and does not import `_DisposeEventLoopTimerUPP`.

The inherited timer-side-quit sequence remained exact through S15 with one callback. S16 and S17 both executed, `RemoveEventLoopTimer=0`, `REMOVEEVENTLOOPTIMER_PASS` was emitted, cleanup reached `M24_SUCCESS`, and `control_status=0`. All six titlebar actions remained passthrough with zero unexpected actions; OrderFront remained 3/3/3 passthrough with one SelectWindow-bounded and one RunApplicationEventLoop-bounded call. The runner ended `POST_RUNAPPLICATIONEVENTLOOP_REMOVEEVENTLOOPTIMER_SNOW_CONTROL_PASS` and `RESULT: PASS`.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        LIVE-PROVEN through S15
all 21 reviewed Lion notification registrations     LIVE-PROVEN PASS
RemoveEventLoopTimer Snow                            LIVE-PROVEN PASS
RemoveEventLoopTimer Lion                            NEXT: exact-binary guarded transfer
DisposeEventLoopTimerUPP                             HELD
new compatibility families                          NO
titlebar policy broadening                          NO
XNU                                                  no source change indicated
```
