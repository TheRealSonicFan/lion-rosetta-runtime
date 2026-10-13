# Post-NewEventLoopTimerUPP GetMainEventLoop Snow control

## Objective

Advance one operation beyond the live-proven Lion `NewEventLoopTimerUPP(ProbeTimer)` boundary by isolating `GetMainEventLoop()` on Snow Leopard 10.6.8 first.

The historical Carbon milestone called `InstallEventLoopTimer(GetMainEventLoop(), ...)` as one expression. Testing `InstallEventLoopTimer` next without separating the nested `GetMainEventLoop()` call would make any no-return or bad-reference result ambiguous. This stage therefore obtains only the main event-loop reference, requires it to be non-null, and exits normally. It does **not** install, remove, fire, or dispose a timer and does not enter an event loop.

## Reviewed predecessor

The guarded Lion NewEventLoopTimerUPP integration is closed:

```text
Lion 10.7.5 / 11G63
accepted kernel SHA
exact Snow subject SHA-256=73a02dac78c61531ab1f1922011de7116f1a384ede55616c1c16bf6bc966020b
S06_BEFORE_NewEventLoopTimerUPP
S07_AFTER_NewEventLoopTimerUPP
UPP pointer=0x000021e4 nonzero=YES
NEWEVENTLOOPTIMERUPP_PASS
M24_SUCCESS
createwindow_validation_exec_status=0
exact-seven register=7 callback=0 rejects=0 exact=YES
protected_hashes_unchanged=YES
new diagnostics=none
final=POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_PASS
```

No timer/UPP compatibility rule is indicated.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-getmaineventloop.c
scripts/build-ppc-process-manager-getmaineventloop-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
GetMainEventLoop subject       e4265ef2c7e7d74ec28efa94ab82d8549a08cf5d
GetMainEventLoop Snow builder  0441b45fd3a7c0b31ec28c3cbee49cadd899dc47
Snow full-stack runner         edcea90038d780594cd6b3573607b747eedadf71
```

The new subject keeps every already proven operation and adds only:

```text
S08_BEFORE_GetMainEventLoop
main_event_loop = GetMainEventLoop();
S09_AFTER_GetMainEventLoop
PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=<value> nonzero=YES
PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS
```

## Safety constraints

- Run the new subject on Snow Leopard only.
- Keep every compatibility mode on Snow in passthrough.
- Keep the exact-six titlebar wrapper in passthrough.
- Do not call `InstallEventLoopTimer`, `RemoveEventLoopTimer`, `DisposeEventLoopTimerUPP`, `RunApplicationEventLoop`, or `QuitApplicationEventLoop`.
- Do not add another public Carbon/window operation.
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

test "$(git hash-object ./tests/ppc-process-manager-postidentity-getmaineventloop.c)" = \
  "e4265ef2c7e7d74ec28efa94ab82d8549a08cf5d" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-getmaineventloop-on-snowleopard.sh)" = \
  "0441b45fd3a7c0b31ec28c3cbee49cadd899dc47" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "edcea90038d780594cd6b3573607b747eedadf71" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-getmaineventloop-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the GetMainEventLoop subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-getmaineventloop-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the info report to show:

```text
build_id=cps-getmaineventloop-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER=/usr/oah/dyld
neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)
getmaineventloop_source_expression=GetMainEventLoop()
getmaineventloop_linkage=undefined-import
imports _GetMainEventLoop
```

The NewEventLoopTimerUPP linkage remains diagnostic only and may still be `sdk-lowered-no-undefined-import`.

Do not rebuild any compatibility dylib.

## Phase C — Snow GetMainEventLoop control

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
  ./pm-getmaineventloop-snow.log || exit 1
```

Require:

```text
PM_CPS_CREATEWINDOW_BUILD_ID:cps-getmaineventloop-validation-v1
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
PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS
M24_SUCCESS
control_status=0
cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1
coreui_titlebar_unexpected_action_count=0
RESULT: POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_SNOW_CONTROL_PASS
RESULT: PASS
```

All six titlebar target actions must remain passthrough. There must be no compatibility `ADAPTER_PASS`, no `GETMAINEVENTLOOP_NULL`, and no later FAIL.

If S08 appears without S09, preserve the complete log and stop at the `GetMainEventLoop` no-return boundary. If S09 returns a null reference, preserve the complete log and do not proceed to timer installation.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-getmaineventloop-snow.log
```

Do not transfer or execute this new subject on Lion until the Snow evidence is reviewed.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Snow                     PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop                                 NEXT: Snow control only
InstallEventLoopTimer                            HELD
RunApplicationEventLoop                         HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
