# Post-ShowWindow SelectWindow OrderFront compatibility Snow control

## Objective

Build the new combined PPC compatibility artifact that adds one narrowly guarded Lion-only adaptation for the second `CGSOrderFrontConditionally` request issued by `SelectWindow(window)`, then prove on Snow Leopard that the rebuilt artifact remains behavior-preserving in `passthrough` mode.

This stage is Snow-only. It does not authorize a Lion SelectWindow run.

## Reviewed first v3 Snow result

The first returned v3 artifact, SHA-256 `6400ab1fc790e93bd404c3f15f02f26c66d11b816498e09f717a700f4c29337b`, passed the SelectWindow/OrderFront Snow transparency predicates: both exact legacy OrderFront calls were passthrough, exactly one was bounded by S02/S03, `SelectWindow` returned, `M24_SUCCESS` was reached, all six CoreUI titlebar keys remained passthrough, and the final Snow result was PASS.

That artifact is **not approved for Lion**. Review of its build recipe showed that the new builder had inherited the earlier ColorProfileClient-only compile flags and therefore omitted the already accepted `ResolveColorProfile` and `WindowBackingInfo` compatibility modules that are part of the live-proven Lion ShowWindow baseline. The returned log correspondingly contains no `PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_*` or `PM_CGS_WINDOW_BACKING_INFO_COMPAT_*` markers. This is a build-composition gap, not a failure of the new second-OrderFront guard.

Current `main` corrects only that composition error: the v3 builder now includes the same accepted ResolveColorProfile trace/compatibility and WindowBackingInfo compatibility compile flags and marker checks as the previously proven WBI build, while retaining the new `lion-selectwindow-id-v1` OrderFront mode. A fresh Snow build and passthrough control of this Lion-complete v3 artifact is required before any Lion transfer or execution.

The corrected SelectWindow Snow control already proved the new public API sequence:

```text
ShowWindow                                      PASS
SelectWindow                                    PASS
SelectWindow-bounded OrderFront legacy call     exactly 1
total OrderFront legacy calls                   2
M24_SUCCESS                                     reached
control_status                                  0
final Snow control                              PASS
```

The second call is not a new protocol shape. It is the same exact Snow `CGS_ORDER_FRONT_CONDITIONALLY_LEGACY` request family already adapted for ShowWindow, but it occurs at compatibility call index 2 after `CGSAddTrackingArea` has occurred once. The old Lion mode intentionally allowed only index 1 with `addTrackingCompatCalls=0`; passing the second legacy request through unchanged on Lion is therefore not an acceptable next experiment.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-post-showwindow-selectwindow-order-front-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Pinned identities:

```text
CoreServices compat source blob  2c167877c92e6777189c0b4f8657f5570e1a0acb
SelectWindow compat builder blob c0e0b4c363595b3781305f8da785e1708ba2d41a
Snow runner blob                 aff24e231e7c8915065973aaf2db9419ea8f90ae
Lion runner blob                 356a04c149c43a4ced783536b0ef630fcea54de9
SelectWindow subject source      6d873470f27e99de997301ef2d0c757ac6b61a6a
SelectWindow subject builder     421b427360da6412c14231f0839495cd4ab15bc1
subject SHA-256                  cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259
```

New combined build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v3
```

New Lion-only OrderFront mode:

```text
lion-selectwindow-id-v1
```

The v3 source preserves the historical `lion-id-v1` predicate for non-SelectWindow runs. Under `lion-selectwindow-id-v1`, it may adapt only:

```text
call 1: exact legacy request, opacityCreateCompatCalls=1, addTrackingCompatCalls=0
call 2: exact legacy request, opacityCreateCompatCalls=1, addTrackingCompatCalls=1
```

Any other call index, request shape, or provenance remains rejected to passthrough.

## Safety constraints

- Run this stage only on Snow Leopard 10.6.8 / 10K549.
- Do not transfer the new v3 artifact to Lion yet.
- Do not run the SelectWindow subject on Lion yet.
- Use `passthrough` for the OrderFront compatibility mode on Snow.
- Do not broaden the request ID mapping or accept a third OrderFront call.
- Do not change the exact-six CoreUI titlebar policy.
- Reuse the accepted SelectWindow subject; do not rebuild it if its SHA-256 matches the pinned value.
- Reuse every accepted Security, CGS, HIToolbox, FontServer, color-profile, WindowBackingInfo, and titlebar component unchanged.
- Do not add `IsWindowVisible`, timers, event-loop work, or another public window operation.
- Do not patch system frameworks/resources, Rosetta, dyld, caches, or XNU.
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

test "$(git hash-object ./tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c)" = \
  "2c167877c92e6777189c0b4f8657f5570e1a0acb" || exit 1

test "$(git hash-object ./scripts/build-ppc-process-manager-post-showwindow-selectwindow-order-front-compat-on-snowleopard.sh)" = \
  "c0e0b4c363595b3781305f8da785e1708ba2d41a" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" = \
  "aff24e231e7c8915065973aaf2db9419ea8f90ae" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "356a04c149c43a4ced783536b0ef630fcea54de9" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-post-showwindow-selectwindow-order-front-compat-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1
```

Stop if Phase A fails.

## Phase B — build the v3 compatibility artifact

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-showwindow-selectwindow-order-front-compat-on-snowleopard.sh \
  ./pm-selectwindow-orderfront-compat.dylib || exit 1
```

Expected outputs:

```text
pm-selectwindow-orderfront-compat.dylib
pm-selectwindow-orderfront-compat.dylib.info.txt
pm-selectwindow-orderfront-compat.dylib.sha256
```

Require the info report to show:

```text
build_id=<the exact v3 build ID above>
32-bit PPC Mach-O
exactly two PPC __interpose tuples
embedded distributed-notifications ingress v2
```

The corrected builder must also have compiled the accepted downstream baseline into the same artifact. Require the built strings to contain all of:

```text
lion-selectwindow-id-v1
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1
PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1
PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:color-profile-resolve-passive-trace-v1
```

If any is absent, stop; do not run the Snow subject and do not transfer the artifact to Lion.

## Phase C — verify and reuse the existing SelectWindow subject

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259" || exit 1
```

Do not rebuild the subject if this passes.

## Phase D — Snow v3 passthrough control

Use the same accepted Snow stack and change only the combined CoreServices compatibility artifact from the old v2 file to the new v3 file:

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

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./pm-selectwindow-orderfront-compat.dylib \
  ./pm-selectwindow-orderfront-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./pm-selectwindow-orderfront-compat-snow.log || exit 1
```

Require:

```text
PM_CORESERVICES_COMPAT_BUILD_ID:<v3 build ID>
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
S02_BEFORE_SelectWindow
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
M24_SUCCESS
control_status=0

cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_passthrough_count=2
selectwindow_order_front_conditionally_call_count=1

coreui_titlebar_disabled_clear_passthrough_count=1
coreui_titlebar_disabled_minus_passthrough_count=1
coreui_titlebar_disabled_zoom_passthrough_count=1
coreui_titlebar_active_clear_passthrough_count=1
coreui_titlebar_active_minus_passthrough_count=1
coreui_titlebar_active_zoom_passthrough_count=1
coreui_titlebar_unexpected_action_count=0

RESULT: POST_SHOWWINDOW_SELECTWINDOW_SNOW_CONTROL_PASS
RESULT: PASS
```

In addition, because this corrected v3 artifact is intended to replace the live-proven WBI baseline on Lion, require the Snow raw/consolidated log to contain:

```text
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:index=1 ... mode=passthrough
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:index=2 ... mode=passthrough
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:PASSTHROUGH     exactly 2

PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1
PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:index=1 ... mode=passthrough exact=YES
PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:PASSTHROUGH      exactly 1
```

There must be no `PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS`, no ResolveColorProfile/WindowBackingInfo `ADAPTER_PASS`, and no CoreUI titlebar translation/guard-reject action on Snow.

If this control fails, stop. Do not weaken the new call-index/provenance guard and do not run Lion.

## Phase E — return evidence

Return exactly:

```text
pm-selectwindow-orderfront-compat.dylib.info.txt
pm-selectwindow-orderfront-compat.dylib.sha256
pm-selectwindow-orderfront-compat-snow.log
```

Do not transfer the dylib to Lion until this evidence is reviewed.

## Review gate

If the corrected, Lion-complete Snow v3 control passes—including the ResolveColorProfile and WindowBackingInfo passthrough predicates—the rebuilt artifact is proven transparent across the complete accepted Snow baseline. Only then may that exact dylib be transferred to Lion and used with `ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-selectwindow-id-v1`, after a fresh syscall-295 preflight, for exactly one separately authorized Lion SelectWindow run.

## Reviewed corrected full-stack result

The corrected Lion-complete v3 artifact passes the Snow gate. Its SHA-256 is `28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578`; it is PPC7400, contains exactly two PPC `__interpose` tuples, carries the expected v3 build ID, and embeds the accepted ResolveColorProfile trace/compatibility and WindowBackingInfo compatibility build IDs.

The Snow run preserves the complete accepted baseline. ResolveColorProfile is present and passthrough-only twice; WindowBackingInfo is present and passthrough-only once; neither emits `ADAPTER_PASS`. Both exact legacy OrderFront calls remain passthrough, with exactly one call bounded by the SelectWindow S02/S03 markers. `ShowWindow` and `SelectWindow` both return, all six CoreUI titlebar keys remain passthrough with zero unexpected actions, `M24_SUCCESS` is reached, `control_status=0`, and the final results are `POST_SHOWWINDOW_SELECTWINDOW_SNOW_CONTROL_PASS` and `PASS`.

This closes the corrected v3 Snow transparency gate. The exact artifact may now be transferred to Lion together with the already accepted SelectWindow subject. The next authorized stage is `docs/process-manager-post-showwindow-selectwindow-lion-integration.md`: refresh both repositories, transfer and hash-check the exact Snow artifacts, rebuild the exact-seven native broker, repeat syscall 295, and only if every preflight passes run exactly one Lion SelectWindow attempt. No new public API, compatibility family, titlebar mapping, or XNU change is authorized.

## Current boundary

```text
SelectWindow Snow API control                   PASS
second OrderFront legacy call                   PROVEN
v3 Lion-only second-call adapter source         PREPARED
corrected full-stack v3 artifact                PASS
ResolveColorProfile Snow transparency           PASS: 2 passthrough
WindowBackingInfo Snow transparency             PASS: 1 passthrough
exact-six titlebar Snow transparency             PASS
Lion SelectWindow                               NEXT: one guarded integration
IsWindowVisible / timers / event loop            HELD
XNU                                              no change indicated
```
