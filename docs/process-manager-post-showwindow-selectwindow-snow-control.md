# Post-ShowWindow SelectWindow Snow control

## Objective

Advance one public Carbon window operation beyond the now-live-proven Lion ShowWindow boundary. The only new subject operation is exactly one `SelectWindow(window)` call after a successful `ShowWindow(window)` return and before title release/disposal.

This stage is Snow Leopard only. It proves that the new subject and the already accepted compatibility stack remain behavior-preserving before any Lion SelectWindow run is authorized.

The reviewed exact-six Lion run closed the ShowWindow gate:

```text
syscall 295                                      PASS
exact-seven notification broker                 PASS
exact-six titlebar build                         coreui-titlebar-bsearch-exact-six-v2
disabled-clear/minus/zoom translations           1 each
active-clear/minus/zoom translations             1 each
titlebar guard rejects                           0
S01_AFTER_ShowWindow                             reached
SHOWWINDOW_PASS                                  reached
M24_SUCCESS                                      reached
subject exit                                     0
new crash/core diagnostics                       none
protected hashes                                 unchanged
final runner result                              POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS
```

The prior `_CGSLockWindow: Cannot synchronize window backing store` diagnostic may still appear transiently inside ShowWindow, but it is not a blocking boundary: the public ShowWindow call returned, cleanup completed, and the process exited successfully. Do not reopen that diagnostic in this stage.

## Prepared subject

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-windowtitle.c
scripts/build-ppc-process-manager-selectwindow-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Pinned identities:

```text
subject source blob       6d873470f27e99de997301ef2d0c757ac6b61a6a
SelectWindow builder blob 421b427360da6412c14231f0839495cd4ab15bc1
Snow runner blob          0543b841e27b452a1b4992ed092715257a4f0841
Lion runner blob          2fa50e8637feff16ffd267e6d6ad09cfcb2c717e
subject build ID          cps-selectwindow-validation-v1
required basename         ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
Snow SelectWindow mode    snow-selectwindow-v1
future Lion mode          lion-selectwindow-v1
```

The new subject sequence is:

```text
S00_BEFORE_ShowWindow
ShowWindow(window)
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
S02_BEFORE_SelectWindow
SelectWindow(window)
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
CFRelease(title)
DisposeWindow(window)
M24_SUCCESS
```

No visibility query, timer, event loop, or second window operation is added.

## Safety constraints

- Run this stage only on Snow Leopard 10.6.8 / 10K549.
- Do not run the new SelectWindow subject on Lion yet.
- Reuse the exact-six titlebar compatibility artifact in `passthrough` mode.
- Reuse every accepted CoreServices, Security, CGS, HIToolbox, FontServer, and distributed-notification compatibility component unchanged.
- Do not add a new titlebar key or CGS rule from Snow observations.
- Do not add `IsWindowVisible`, `BringToFront`, timers, Carbon event-loop calls, or application-event handling.
- Do not patch CoreUI, HIToolbox, CoreGraphics, ArtFile resources, Rosetta, dyld, caches, or XNU.
- Preserve `core.9821`; it remains historical and is not needed for this stage.
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

test "$(git hash-object ./tests/ppc-process-manager-postidentity-windowtitle.c)" =   "6d873470f27e99de997301ef2d0c757ac6b61a6a" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-selectwindow-on-snowleopard.sh)" =   "421b427360da6412c14231f0839495cd4ab15bc1" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" =   "0543b841e27b452a1b4992ed092715257a4f0841" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-selectwindow-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1
```

Stop if Phase A fails.

## Phase B — build only the SelectWindow subject

The exact basename is part of the accepted Process Manager registration predicate, so do not rename the executable:

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 /bin/bash ./scripts/build-ppc-process-manager-selectwindow-on-snowleopard.sh || exit 1
```

Require:

```text
build_id=cps-selectwindow-validation-v1
32-bit PPC
LC_LOAD_DYLINKER=/usr/oah/dyld
_ShowWindow import present
_SelectWindow import present
S00/S01 ShowWindow markers present
S02/S03 SelectWindow markers present
SELECTWINDOW_PASS marker present
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

## Reviewed Phase C failure — runner predicate corrected

The first SelectWindow Snow run did **not** fail in the subject or compatibility stack. It reached `S01_AFTER_ShowWindow`, entered and returned from `SelectWindow`, emitted `SELECTWINDOW_PASS`, reached `M24_SUCCESS`, exited with `control_status=0`, and preserved all six titlebar keys in passthrough. The failure was in the control runner: it retained the earlier ShowWindow-only assertion that exactly one `CGSOrderFrontConditionally` call must occur.

The new API adds one additional, native Snow `CGSOrderFrontConditionally` transaction while `SelectWindow` executes. The reviewed first control observed:

```text
ShowWindow OrderFrontConditionally              index 1, passthrough, exact YES
SelectWindow S02                                reached
SelectWindow OrderFrontConditionally            index 2, passthrough, exact YES
SelectWindow-bounded OrderFrontConditionally    exactly 1
SelectWindow S03                                reached
SELECTWINDOW_PASS                               reached
total OrderFrontConditionally calls             2
total matching legacy traces                    2
```

The corrected runner keeps the historical exact-one predicate for every non-SelectWindow control, but under `snow-selectwindow-v1` requires exactly two total calls, exactly two matching legacy traces, exactly two passthrough results, and exactly one call bounded between `S02_BEFORE_SelectWindow` and `S03_AFTER_SelectWindow`. That bounded call must be `index=2`, `mode=passthrough`, `exact=YES`, with `opacityCreateCompatCalls=1 addTrackingCompatCalls=1`. It does not authorize or add a compatibility rule.

The prior runner also emitted `RESULT: POST_SHOWWINDOW_SELECTWINDOW_SNOW_CONTROL_PASS` before finishing the inherited CGS assertions. That marker has been moved to the final success branch, so it can no longer precede a later `RESULT: FAIL`.

If the already-built subject still matches the returned SHA-256 `cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259`, do **not** rebuild it for the retry. Pull current `main`, re-run Phase A's runner hash/syntax checks, then repeat Phase C only.

## Phase C — Snow positive control

Use the existing accepted Snow stack and exact-six titlebar artifact:

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

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh   ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld   ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256   ./pm-wbi-compat.dylib   ./pm-wbi-compat.dylib.sha256   ./ppc-process-manager-security-session-auditinfo-api.dylib   ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256   ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib   ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256   ./pm-selectwindow-snow.log || exit 1
```

Require:

```text
PM_CPS_CREATEWINDOW_BUILD_ID:cps-selectwindow-validation-v1
S00_BEFORE_ShowWindow
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
S02_BEFORE_SelectWindow
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
M24_SUCCESS
control_status=0

coreui_titlebar_disabled_clear_passthrough_count >= 1
coreui_titlebar_disabled_minus_passthrough_count >= 1
coreui_titlebar_disabled_zoom_passthrough_count >= 1
coreui_titlebar_active_clear_passthrough_count >= 1
coreui_titlebar_active_minus_passthrough_count >= 1
coreui_titlebar_active_zoom_passthrough_count >= 1
coreui_titlebar_unexpected_action_count=0

cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL:index=2 mode=passthrough exact=YES ... opacityCreateCompatCalls=1 addTrackingCompatCalls=1

RESULT: POST_SHOWWINDOW_SELECTWINDOW_SNOW_CONTROL_PASS
RESULT: PASS
```

No `action=TRANSLATED` or `GUARD_REJECT_PASSTHROUGH` may appear.

If SelectWindow does not return on Snow or any accepted control regresses, stop. Do not run Lion.

## Phase D — return evidence

Return exactly:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-selectwindow-snow.log
```

Do not transfer or execute the SelectWindow subject on Lion until this evidence is reviewed.

## Completed result

The corrected Snow control now passes completely. The subject remains the previously built `cps-selectwindow-validation-v1` PPC7400 executable with SHA-256 `cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259`. Snow returned from `ShowWindow`, entered and returned from `SelectWindow`, emitted `SELECTWINDOW_PASS`, reached `M24_SUCCESS`, and exited with `control_status=0`. The exact-six CoreUI titlebar wrapper remained pure passthrough for all six keys with zero unexpected actions.

The corrected discriminator also passes exactly as intended: two total `CGSOrderFrontConditionally` calls, two matching legacy traces, two passthrough results, and exactly one call bounded by the SelectWindow S02/S03 markers. The second call is `index=2`, `mode=passthrough`, `exact=YES`, with `opacityCreateCompatCalls=1 addTrackingCompatCalls=1`. Final results are `POST_SHOWWINDOW_SELECTWINDOW_SNOW_CONTROL_PASS` and `PASS`.

This closes the Snow public-API control. It also proves that Lion cannot safely reuse the old one-call `lion-id-v1` OrderFront adapter unchanged: the existing compatibility source deliberately adapts only call index 1 and would reject/pass through the second SelectWindow call. Current `main` therefore introduces a separately guarded `lion-selectwindow-id-v1` mode and a new v3 combined compatibility build. The next stage is the Snow build/passthrough gate in `docs/process-manager-post-showwindow-selectwindow-orderfront-compat-snow-control.md`; no Lion SelectWindow run is authorized yet.

## Current boundary

```text
CreateNewWindow                                  PASS
SetWindowTitleWithCFString                       PASS
ShowWindow on Lion                               LIVE-PROVEN PASS
exact-six CoreUI titlebar compatibility          LIVE-PROVEN
SelectWindow on Snow                             PASS
SelectWindow OrderFront call #2                  PROVEN: one bounded legacy call
new Lion SelectWindow OrderFront mode            PREPARED
new combined v3 compatibility artifact           NEXT: Snow build/control
Lion SelectWindow                                NOT YET AUTHORIZED
IsWindowVisible / timers / event loop             HELD
new titlebar compatibility                        NO
XNU                                               no change indicated
```
