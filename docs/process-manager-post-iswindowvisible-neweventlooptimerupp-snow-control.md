# Post-IsWindowVisible NewEventLoopTimerUPP Snow control

## Objective

Advance exactly one Carbon operation beyond the live-proven Lion `IsWindowVisible(window)` boundary by testing only creation of an `EventLoopTimerUPP` on Snow Leopard 10.6.8 / 10K549.

This stage is Snow-only. It does **not** install a timer and does **not** enter an event loop. It does not authorize a Lion timer run.

The preceding Lion visibility stage is closed:

```text
ShowWindow                                      PASS
SelectWindow                                    PASS
IsWindowVisible                                 visible=1 / PASS
M24_SUCCESS                                     reached
subject exit                                    0
exact-seven notifications                       PASS
WindowBackingInfo                               accepted Lion baseline
ResolveColorProfile                             accepted Lion baseline
OrderFront                                      2 / 2 / 2, one SelectWindow-bounded
exact-six titlebar                              six translations, zero guard rejects
protected hashes                                unchanged
final                                           POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_PASS
```

The next question is only whether the restored PPC process can create the callback UPP object with `NewEventLoopTimerUPP`. The callback is never installed or invoked in this stage.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-neweventlooptimerupp.c
scripts/build-ppc-process-manager-neweventlooptimerupp-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
NewEventLoopTimerUPP subject source   a2dd3716bb06cc7c54d247a010451a48a5dd80b3
NewEventLoopTimerUPP Snow builder     20423ad2e1aa0f44bead8ecfec50f07a2ab34526
Snow integration runner               f08f790eb67673e795f3c10e275102bc9059a790
v3 CoreServices artifact SHA-256      28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578
exact-six titlebar artifact SHA-256    6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72
```

New subject build ID:

```text
cps-neweventlooptimerupp-validation-v1
```

New Snow validation mode:

```text
snow-neweventlooptimerupp-v1
```

The public sequence is exactly:

```text
CreateNewWindow
SetWindowTitleWithCFString
ShowWindow
SelectWindow
IsWindowVisible
NewEventLoopTimerUPP
CFRelease
DisposeWindow
```

The subject intentionally does not call `InstallEventLoopTimer`, `DisposeEventLoopTimerUPP`, or `RunApplicationEventLoop`. The small UPP allocation, if any, is reclaimed when the short-lived process exits; this keeps the boundary isolated to UPP creation.

### Phase B correction

The first Phase B builder incorrectly treated `_NewEventLoopTimerUPP` as a mandatory undefined Mach-O import. That is too strict for this PPC build: the SDK/header/compiler may lower the UPP-construction expression without leaving an undefined `_NewEventLoopTimerUPP` symbol. The failed message `error: output does not import _NewEventLoopTimerUPP` therefore reports a builder linkage-assumption failure, not a failed compile and not a Rosetta/Carbon runtime result.

The corrected builder pins the exact source expression `timer_upp = NewEventLoopTimerUPP(ProbeTimer);`, continues to require the surrounding Carbon/Process Manager imports, and records whether `_NewEventLoopTimerUPP` survived as an undefined import only as diagnostic metadata. The runtime proof remains the S06/S07 markers, a nonzero UPP pointer, `NEWEVENTLOOPTIMERUPP_PASS`, and inherited control PASS in Phase C.

New markers:

```text
PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP
PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP
PM_POSTWINDOWTIMERUPP_POINTER:pointer=... nonzero=YES
PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS
```

## Safety constraints

- Run only on Snow Leopard 10.6.8 / 10K549.
- Do not run the new subject on Lion yet.
- Do not rebuild or modify the proven v3 compatibility dylib.
- Keep every compatibility family in Snow passthrough mode.
- Keep the exact-six titlebar wrapper in passthrough mode.
- Do not install, remove, fire, or dispose an event-loop timer in this stage.
- Do not call `GetMainEventLoop`, `InstallEventLoopTimer`, `RunApplicationEventLoop`, or `QuitApplicationEventLoop`.
- Do not add another public window operation.
- Do not broaden titlebar/CGS compatibility or add a timer-specific adapter from Snow observations.
- Do not patch system frameworks/resources, Rosetta, dyld, caches, or XNU.
- No kernel rebuild or reboot.

## Phase A — update and preflight

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-neweventlooptimerupp.c)" = \
  "a2dd3716bb06cc7c54d247a010451a48a5dd80b3" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-neweventlooptimerupp-on-snowleopard.sh)" = \
  "20423ad2e1aa0f44bead8ecfec50f07a2ab34526" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "f08f790eb67673e795f3c10e275102bc9059a790" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-neweventlooptimerupp-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the NewEventLoopTimerUPP subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-neweventlooptimerupp-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-neweventlooptimerupp-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
imports _ShowWindow
imports _SelectWindow
imports _IsWindowVisible
neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)
neweventlooptimerupp_linkage=undefined-import
```

The final linkage line may instead be:

```text
neweventlooptimerupp_linkage=sdk-lowered-no-undefined-import
```

Either linkage value is valid. Phase B must **not** require an undefined `_NewEventLoopTimerUPP` symbol. The exact pinned source expression proves that the requested UPP constructor is present in the subject, while Phase C proves its behavior by requiring S06/S07, a nonzero pointer, and `NEWEVENTLOOPTIMERUPP_PASS`.

Do not rebuild a compatibility dylib.

## Phase C — Snow UPP-creation control

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
  ./pm-neweventlooptimerupp-snow.log || exit 1
```

Require:

```text
PM_CPS_CREATEWINDOW_BUILD_ID:cps-neweventlooptimerupp-validation-v1

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
PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS

M24_SUCCESS
control_status=0

cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1

coreui_titlebar_unexpected_action_count=0

RESULT: POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_SNOW_CONTROL_PASS
RESULT: PASS
```

All six titlebar target actions must remain passthrough. There must be no titlebar translation/guard reject, no compatibility `ADAPTER_PASS`, no `NEWEVENTLOOPTIMERUPP_NULL`, and no later FAIL.

Do not infer a compatibility requirement from a passive diagnostic if the UPP creation returns a nonzero object and the inherited control remains PASS.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-neweventlooptimerupp-snow.log
```

Do not transfer or execute this new subject on Lion until the Snow evidence is reviewed.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP                             NEXT: Snow control only
InstallEventLoopTimer                            HELD
RunApplicationEventLoop                         HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
