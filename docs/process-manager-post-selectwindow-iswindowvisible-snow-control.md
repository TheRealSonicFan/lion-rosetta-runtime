# Post-SelectWindow IsWindowVisible Snow control

## Objective

Advance exactly one public Carbon operation beyond the live-proven Lion `SelectWindow(window)` boundary by testing `IsWindowVisible(window)` first on Snow Leopard 10.6.8 / 10K549 under the complete accepted stack in strict passthrough mode.

This stage is Snow-only. It does not authorize a Lion IsWindowVisible run.

The preceding Lion SelectWindow integration is closed:

```text
ShowWindow                                      PASS
SelectWindow                                    PASS
OrderFront call 1 adapter                       PASS
OrderFront call 2 adapter                       PASS
WindowBackingInfo baseline                      PASS
ResolveColorProfile baseline                    PASS
exact-six CoreUI titlebar                       PASS
exact-seven notifications                       PASS
M24_SUCCESS                                     reached
subject exit                                    0
new diagnostics                                 none
final result                                    POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_PASS
```

The next question is only whether the already shown/selected native Snow window reports visible through the public `IsWindowVisible` API. Do not combine this with timer creation, timer installation, event-loop entry, another window operation, or another compatibility rule.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-iswindowvisible.c
scripts/build-ppc-process-manager-iswindowvisible-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned blobs:

```text
IsWindowVisible subject source       15837a5a2cec282066793ee9e54bfbeafe23c9fa
IsWindowVisible Snow builder         3d9c49b1daadf03558c7c20c0cc06735ef20af40
Snow integration runner              9cd663db8bf0ee9631e377ed5ae1b15b2780328e
v3 CoreServices compat source        2c167877c92e6777189c0b4f8657f5570e1a0acb
v3 CoreServices artifact SHA-256     28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578
exact-six titlebar artifact SHA-256   6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72
```

New subject build ID:

```text
cps-iswindowvisible-validation-v1
```

New Snow validation mode:

```text
snow-iswindowvisible-v1
```

The subject sequence is exactly:

```text
CreateNewWindow
SetWindowTitleWithCFString
ShowWindow
SelectWindow
IsWindowVisible
CFRelease
DisposeWindow
```

The IsWindowVisible boundary emits:

```text
PM_POSTWINDOWVISIBLE_MILESTONE:S04_BEFORE_IsWindowVisible
PM_POSTWINDOWVISIBLE_MILESTONE:S05_AFTER_IsWindowVisible
PM_POSTWINDOWVISIBLE_VALUE:visible=1
PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_PASS
```

A false result is reported explicitly and fails the control.

## Safety constraints

- Run only on Snow Leopard 10.6.8 / 10K549.
- Do not run the new subject on Lion yet.
- Do not modify the already accepted v3 CoreServices compatibility artifact.
- Keep every compatibility mode on Snow in `passthrough`.
- Keep the exact-six titlebar wrapper in `passthrough`.
- Do not add a new titlebar key or CGS rule from Snow observations.
- Do not add timers, `NewEventLoopTimerUPP`, `InstallEventLoopTimer`, `RunApplicationEventLoop`, `BringToFront`, or another public window operation.
- Do not patch CoreUI, HIToolbox, CoreGraphics, ArtFile resources, Rosetta, dyld, caches, or XNU.
- No kernel rebuild or reboot.

## Phase A — update and preflight

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1
test "$LOCAL_HEAD" = "$REMOTE_HEAD" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-iswindowvisible.c)" = \
  "15837a5a2cec282066793ee9e54bfbeafe23c9fa" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-iswindowvisible-on-snowleopard.sh)" = \
  "3d9c49b1daadf03558c7c20c0cc06735ef20af40" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "9cd663db8bf0ee9631e377ed5ae1b15b2780328e" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-iswindowvisible-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

test "$(/usr/bin/shasum -a 256 ./pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1
```

Stop if Phase A fails.

## Phase B — build only the new IsWindowVisible subject

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-iswindowvisible-on-snowleopard.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld || exit 1
```

Require the generated info report to show:

```text
build_id=cps-iswindowvisible-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
32-bit PowerPC / ppc7400
LC_LOAD_DYLINKER = /usr/oah/dyld
imports _ShowWindow
imports _SelectWindow
imports _IsWindowVisible
```

Do not rebuild any compatibility dylib.

## Phase C — Snow IsWindowVisible control

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
  ./pm-iswindowvisible-snow.log || exit 1
```

Require:

```text
PM_CPS_CREATEWINDOW_BUILD_ID:cps-iswindowvisible-validation-v1
S00_BEFORE_ShowWindow
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
S02_BEFORE_SelectWindow
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
S04_BEFORE_IsWindowVisible
S05_AFTER_IsWindowVisible
PM_POSTWINDOWVISIBLE_VALUE:visible=1
PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_PASS
M24_SUCCESS
control_status=0

cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1

coreui_titlebar_disabled_clear_passthrough_count >= 1
coreui_titlebar_disabled_minus_passthrough_count >= 1
coreui_titlebar_disabled_zoom_passthrough_count >= 1
coreui_titlebar_active_clear_passthrough_count >= 1
coreui_titlebar_active_minus_passthrough_count >= 1
coreui_titlebar_active_zoom_passthrough_count >= 1
coreui_titlebar_unexpected_action_count=0

RESULT: POST_SELECTWINDOW_ISWINDOWVISIBLE_SNOW_CONTROL_PASS
RESULT: PASS
```

There must be no `PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_FALSE`, no CoreUI titlebar translation/guard reject, and no `ADAPTER_PASS` for any compatibility family on Snow.

Do not infer a new compatibility requirement merely from additional passive CGS traffic. If the public API returns true and the inherited stack remains passthrough, stop for review before any Lion IsWindowVisible run.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-iswindowvisible-snow.log
```

Do not transfer or execute the IsWindowVisible subject on Lion until this evidence is reviewed.

## Current boundary

```text
CreateNewWindow                                  PASS
SetWindowTitleWithCFString                       PASS
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
SelectWindow second OrderFront adapter           LIVE-PROVEN
IsWindowVisible                                  NEXT: Snow control only
timers / event loop                              HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
