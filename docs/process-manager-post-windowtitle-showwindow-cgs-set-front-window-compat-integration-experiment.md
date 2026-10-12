# Process Manager ShowWindow CGSSetFrontWindow compatibility integration

## Objective

The OrderFrontConditionally integration succeeded on Lion and advanced the ShowWindow boundary. The next nonzero-window generated-MIG request is now deterministic:

```text
Snow PPC  __CGSSetFrontWindow  request 0x72f2  reply 0x7356
Lion i386 __CGSSetFrontWindow  request 0x72f5  reply 0x7359
```

The static audit already proved that both releases use request bits `0x1513`, Mach option `0x3`, send size `0x24`, receive size `0x2c`, NDR plus one 32-bit window ID, and a simple `0x24` reply containing NDR plus result. The live Snow control returns result 0 for the nonzero-window request; Lion returns `-304` when the unchanged PPC client sends the Snow ID.

This stage adds exactly one new user-space compatibility rule for the first nonzero-window SetFrontWindow request reached during ShowWindow.

## Proven live sequence

The accepted Lion path is now:

```text
OrderFrontConditionally  0x72e7 -> 0x72ea -> native 0x734e/result 0 -> PPC 0x734b
AddTrackingArea          0x7388 -> 0x738e -> native 0x73f2/result 0 -> PPC 0x73ec
0x7268 / 0x72cc         unchanged, result 0
SetFrontWindow           0x72f2 / 0x7356, result -304
```

ShowWindow does not return after the SetFrontWindow rejection.

Snow also emits a later zero-window `0x72f2` during disposal. That call is intentionally not adapted by this stage. The compatibility predicate requires a nonzero window ID.

## Prepared compatibility rule

Runtime mode:

```text
Snow Leopard  ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=passthrough
Lion          ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=lion-id-v1
```

The Lion adapter is eligible only when:

- the target is the established application CGS port;
- request bits are exactly `0x1513`;
- request ID is exactly `0x72f2`;
- option is exactly `0x3`;
- send size is exactly `0x24`;
- receive size is exactly `0x2c`;
- NDR matches the legacy client;
- window ID at offset `0x20` is nonzero;
- this is the first exact SetFrontWindow compatibility call;
- opacity/create-alpha compatibility has occurred exactly once;
- OrderFrontConditionally compatibility has occurred exactly once;
- AddTrackingArea compatibility has occurred exactly once.

For that request the adapter copies into a private buffer and changes only `0x72f2 -> 0x72f5`. It requires a native `0x7359`, simple `0x24` reply with valid NDR/result geometry, then changes only `0x7359 -> 0x7356` before returning to the PPC client. A nonzero native result is preserved.

The later zero-window legacy request remains passthrough.

## Safety constraints

- Reuse the existing `cps-showwindow-validation-v1` subject unchanged.
- Reuse the exact-six notification broker unchanged.
- Reuse the accepted Security, HIToolbox Extras, DockServer, FontServer rendezvous, NewWindow, release-backing, create-alpha, OrderFrontConditionally, and AddTrackingArea paths unchanged.
- Do not adapt the zero-window disposal-time SetFrontWindow request in this stage.
- Do not adapt the earlier `CGSShapeWindow` rejection.
- Do not patch color-profile, window-context, CoreUI, or rendering behavior.
- Do not add `SelectWindow`, an event loop, or timing workarounds.
- Do not patch Rosetta, dyld, system frameworks, launchd, caches, or XNU.
- Run exactly one Lion integration after the Snow control.
- Preserve every new crash/core diagnostic named by the Lion runner.

No XNU source change, kernel rebuild, or reboot is part of this stage.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

Confirm runtime contains:

```text
scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-on-snowleopard.sh
docs/process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-integration-experiment.md
```

## Phase B — build on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat.dylib.sha256
```

Require PPC7400, exactly two `__interpose` tuples, embedded ingress v2, build ID ending in `showwindow-addtrackingarea-orderfront-setfrontwindow-compat-v1`, and all SetFrontWindow adapter markers.

Stop if build, architecture, marker, or hash validation fails.

## Phase C — Snow Leopard behavior-preserving control

Unset superseded audit modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=passthrough
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
```

Syntax-check and run the existing Snow control runner with the new combined dylib and output:

```text
ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-snowleopard-control.log
```

Require:

```text
OrderFrontConditionally passthrough            exactly once
AddTrackingArea passthrough                    exactly once
SetFrontWindow compatibility call              exactly once, nonzero window, exact=YES
SetFrontWindow legacy trace                    exactly two requests total
SetFrontWindow adapted                         NO
nonzero-window 0x72f2 / 0x7356                 result 0
S01_AFTER_ShowWindow                           reached
SHOWWINDOW_PASS                                reached
DisposeWindow / M24                            complete
control status                                 0
RESULT: POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

The second Snow SetFrontWindow trace is the known zero-window disposal-time request and must remain outside the compatibility call count.

Stop if Snow behavior changes.

## Phase D — transfer only the new compatibility artifact

Transfer the new dylib, info file, SHA file, and Snow control log to Lion. Reuse the existing subject, Security interposer, CGS FontServer-rendezvous interposer, exact-six broker, HIToolbox Extras compatibility dylib, and staged resource unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion integration

Unset the schema-audit and superseded trace variables above, then set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-sixth-register-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
```

Syntax-check the Lion runner, then invoke it exactly once using the new combined dylib and report:

```text
payload/lion-ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat.log
```

Require the existing chain to remain accepted and require exactly one new nonzero-window adaptation:

```text
SetFrontWindow compat call                     exactly 1
predicate                                      exact=YES
request                                        0x72f2 -> 0x72f5
send / receive                                 0x24 / 0x2c
request changed bytes                          1, body=0, source=0
native mach_msg                                success
native reply                                   0x7359 / 0x24 / result 0
PPC-facing reply                               0x7356 / 0x24 / result 0
reply changed bytes                            1, body=0
PM_CGS_SET_FRONT_WINDOW_COMPAT_RESULT           ADAPTER_PASS
OrderFrontConditionally adapter                unchanged and PASS
AddTrackingArea adapter                        unchanged and PASS
exact-six registrations                        6, rejects 0, exact=YES
protected hashes                               unchanged
```

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_INTEGRATION_PASS`

Require `S01_AFTER_ShowWindow`, `SHOWWINDOW_PASS`, CF release, DisposeWindow/M24, process exit 0, and no new diagnostic. Stop and review the full trace before any further compatibility change.

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`

The exact SetFrontWindow conversion succeeded but ShowWindow still did not return. Review only the new post-adapter trace before authorizing another RPC conversion. Do not preemptively adapt the zero-window disposal request or the earlier ShapeWindow failure.

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_SET_FRONT_WINDOW_COMPAT_NATIVE_ERROR_PRESERVED`

The native Lion helper returned a valid nonzero result. Preserve it and stop; investigate argument/state semantics instead of widening the ID rewrite.

### Predicate/reply mismatch

Stop. Do not broaden recognition or add another compatibility rule.

## Return

Return exactly these primary artifacts:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the dylib itself unless specifically requested.

## Current boundary

```text
OrderFrontConditionally                          accepted adapter PASS
AddTrackingArea                                  accepted adapter PASS
0x7268 / 0x72cc                                  native success unchanged
Snow __CGSSetFrontWindow                         0x72f2 / 0x7356
Lion __CGSSetFrontWindow                         0x72f5 / 0x7359
SetFrontWindow wire geometry                     equivalent, ID-only +3
first nonzero Lion legacy SetFrontWindow          result -304
zero-window disposal SetFrontWindow              held
CGSShapeWindow                                   held
color-profile/window-context diagnostics          held
next step                                        one exact SetFrontWindow integration
XNU                                              no change indicated
```
