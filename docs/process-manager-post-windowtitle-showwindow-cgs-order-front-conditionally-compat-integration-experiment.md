# Process Manager ShowWindow CGSOrderFrontConditionally compatibility integration

## Objective

The post-tracking static audit identifies the first remaining post-`S00` `-304` transaction exactly. Snow Leopard PPC `__CGSOrderFrontConditionally` sends request `0x72e7` and expects reply `0x734b`; Lion i386 implements the same helper as request `0x72ea` / reply `0x734e`. The generated-MIG envelope and payload geometry are otherwise equivalent.

This stage adds exactly one new user-space compatibility rule for that first ordering RPC. It does not adapt the later `CGSSetFrontWindow` transaction even though the same audit independently proves that helper changed from Snow `0x72f2 / 0x7356` to Lion `0x72f5 / 0x7359`.

## Static proof

### Snow Leopard PPC

```text
symbol             __CGSOrderFrontConditionally
request ID         0x72e7
reply ID           0x734b
request bits       0x1513
Mach option        0x3
send size          0x34
receive size       0x2c
request payload    NDR + five 32-bit scalars
success reply      simple 0x24, NDR + result
```

### Lion i386

```text
symbol             __CGSOrderFrontConditionally
request ID         0x72ea
reply ID           0x734e
request bits       0x1513
Mach option        0x3
send size          0x34
receive size       0x2c
request payload    NDR + five 32-bit scalars
success reply      simple 0x24, NDR + result
```

The differential is therefore an ID-only `+3` shift for the same generated client contract. The live Snow control previously showed the legacy request succeeds, while Lion returned `MIG_BAD_ARGUMENTS` when the unchanged PPC client sent `0x72e7`.

The five request scalars are ordinary arguments. In particular, the value at offset `0x24` differed between accepted Snow and Lion runs, so it is not an invariant compatibility predicate. The window ID is the third scalar at offset `0x28` and must be nonzero.

## Prepared compatibility rule

The combined CoreServices interposer now supports:

```text
Snow Leopard  ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough
Lion          ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-id-v1
```

The Lion adapter is eligible only when all of the following are true:

- the request targets the already-established application CGS port;
- request bits are exactly `0x1513`;
- request ID is exactly `0x72e7`;
- Mach option is exactly `0x3`;
- send size is exactly `0x34`;
- receive size is exactly `0x2c`;
- NDR is the expected legacy NDR;
- the window ID at offset `0x28` is nonzero;
- this is the first exact OrderFrontConditionally compatibility call;
- the accepted opacity/create-alpha compatibility call has already occurred exactly once;
- no tracking-area compatibility call has occurred yet.

For that one request, the adapter copies the message into a private buffer and changes only request ID `0x72e7 -> 0x72ea`. It requires a Lion reply with ID `0x734e`, size `0x24`, expected NDR/result geometry, then changes only the reply ID `0x734e -> 0x734b` before returning it to the unchanged PPC client. A valid nonzero native result is preserved, not rewritten as success.

Any predicate mismatch passes through unchanged. Any unexpected native reply is not synthesized into success.

## Safety constraints

- Reuse the existing `cps-showwindow-validation-v1` subject unchanged.
- Reuse the exact-six native notification broker unchanged.
- Reuse the accepted Security, CGS session/DockServer/FontServer rendezvous, HIToolbox Extras, and staged Snow `Extras.rsrc` artifacts unchanged.
- Retain the accepted NewWindow, release-backing, create-alpha, and CGSAddTrackingArea compatibility rules unchanged.
- Build only the new PPC CoreServices/distributed-notifications compatibility dylib on Snow Leopard.
- Do not rebuild the PPC subject.
- Do not modify the exact-six broker.
- Do not adapt `0x72f2 / 0x7356` (`CGSSetFrontWindow`) in this stage.
- Do not adapt the earlier `0x724d / 0x72b1` `CGSShapeWindow` rejection.
- Do not patch color-profile, window-context, RawCamera, CoreUI, or rendering behavior.
- Do not add `SelectWindow`, `IsWindowVisible`, timers, or an event loop.
- Do not patch system frameworks, Rosetta, dyld, caches, launchd, or XNU.
- Do not restart or signal WindowServer, distnoted, fontd, Dock, launchd, or related jobs.
- Run exactly one Lion integration attempt after the Snow control.
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
scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-on-snowleopard.sh
docs/process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-integration-experiment.md
```

## Phase B — build the compatibility dylib on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.sha256
```

Require:

```text
architecture                                               32-bit PPC / ppc7400
__interpose tuples                                         exactly 2
build ID                                                   ...showwindow-addtrackingarea-orderfront-compat-v1
embedded distributed-notifications ingress                v2
CGS_ORDER_FRONT_CONDITIONALLY_LEGACY                       present
CGS_ORDER_FRONT_CONDITIONALLY_LION                         present
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_CALL               present
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REQUEST    present
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_REPLY       present
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTED_REPLY      present
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT:ADAPTER_PASS present
```

Stop if the shell syntax check, compile, architecture check, marker check, or hash output fails.

## Phase C — Snow Leopard behavior-preserving control

Unset unrelated audit and superseded trace modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
```

Set the accepted Snow stack plus both ShowWindow passthrough gates:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough
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

Syntax-check and run:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-snowleopard-control.log
```

Require the established tracking-area passthrough plus exactly one OrderFrontConditionally passthrough:

```text
OrderFront compatibility call             exactly 1
mode                                      passthrough
predicate                                 exact=YES
legacy request                            0x72e7
legacy expected reply                     0x734b
send / receive                            0x34 / 0x2c
native adaptation                         NOT performed
legacy reply                              0x734b / 0x24 / result 0
tracking-area compatibility               passthrough exactly once
S00_BEFORE_ShowWindow                     reached
S01_AFTER_ShowWindow                      reached
SHOWWINDOW_PASS                           reached
DisposeWindow / M24                       complete
control_status                            0
RESULT                                    POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_SNOW_CONTROL_PASS
RESULT                                    PASS
```

Stop if the Snow control changes behavior or the new target predicate does not match exactly.

## Phase D — transfer only the new compatibility artifact

Transfer to Lion:

```text
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.info.txt
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-snowleopard-control.log
```

Reuse the existing subject, Security interposer, CGS FontServer-rendezvous interposer, exact-six broker, HIToolbox Extras compatibility dylib, and staged resource unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion integration

Unset schema-audit and superseded trace modes as in the previous integration, then set the accepted Lion stack plus the new exact adapter:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-id-v1
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

Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Then run exactly once:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat.log
```

Require the accepted upstream chain to remain intact and require exactly one new adaptation:

```text
CreateNewWindow                                      PASS
SetWindowTitleWithCFString                           PASS
FontServer rendezvous                               adapter PASS exactly once
six notifications                                   accepted, zero rejects, exact=YES
create-alpha                                        adapter PASS exactly once
S00_BEFORE_ShowWindow                               reached
OrderFront compatibility call                       exactly 1
OrderFront predicate                                exact=YES
adapted request                                     0x72e7 -> 0x72ea
send / receive                                      0x34 / 0x2c
request changed bytes                               1, body=0, source=0
native mach_msg                                     success
native reply                                        0x734e / 0x24 / result 0
adapted PPC reply                                   0x734b / 0x24 / result 0
reply changed bytes                                 1, body=0
PM_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_RESULT       ADAPTER_PASS
tracking-area adapter                               unchanged and PASS
protected hashes                                    unchanged
```

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_INTEGRATION_PASS`

Require `S01_AFTER_ShowWindow`, `SHOWWINDOW_PASS`, CF release, DisposeWindow/M24, process exit 0, and no new crash/core diagnostic. Stop and review the complete trace before any further compatibility change.

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`

The exact first ordering conversion succeeded but ShowWindow still did not return. Review the continuing trace. If the already-proven `0x72f2 / 0x7356` `CGSSetFrontWindow` rejection persists as the next deterministic generated-MIG boundary, prepare its own exact ID-only compatibility gate; do not combine it retroactively with this adapter.

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_ORDER_FRONT_CONDITIONALLY_COMPAT_NATIVE_ERROR_PRESERVED`

Lion's native `0x72ea` transaction returned a valid nonzero result. Preserve it and stop. Treat the next question as argument/state semantics rather than widening the ID adapter.

### Predicate or reply mismatch

Stop and resolve the exact model. Do not broaden recognition, add a second ordering adapter, or patch color-profile/window-context behavior.

## Return

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-order-front-conditionally-compat.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the executable subject or compatibility dylib itself unless specifically requested.

## Current boundary

```text
post-tracking static audit                         -> PASS on Snow PPC and Lion i386
Snow __CGSOrderFrontConditionally                  -> 0x72e7 / 0x734b
Lion __CGSOrderFrontConditionally                  -> 0x72ea / 0x734e
OrderFront wire geometry                           -> equivalent, ID-only +3
Snow __CGSSetFrontWindow                           -> 0x72f2 / 0x7356
Lion __CGSSetFrontWindow                           -> 0x72f5 / 0x7359
SetFrontWindow adapter                             -> held
CGSAddTrackingArea                                 -> accepted adapter PASS
color-profile/window-context diagnostics           -> held
earlier CGSShapeWindow rejection                   -> held
next step                                          -> one exact OrderFrontConditionally integration
XNU                                                -> no change indicated
```


## Observed result — OrderFrontConditionally adapter passed; SetFrontWindow is now the next deterministic boundary

The Snow control passed with the new OrderFrontConditionally path in strict passthrough. The first nonzero-window `0x72f2 / 0x7356` SetFrontWindow call also succeeded on Snow.

On Lion, the exact OrderFrontConditionally predicate matched once and the adapter changed only `0x72e7 -> 0x72ea`, received native `0x734e / result 0`, and returned only `0x734e -> 0x734b` to the PPC client. The accepted AddTrackingArea adapter then also passed unchanged. The next unknown transaction `0x7268 / 0x72cc` succeeded unchanged.

The immediately following nonzero-window `0x72f2 / 0x7356` transaction returned `result=-304` on Lion and ShowWindow did not reach `S01_AFTER_ShowWindow`. The prior static audit already identifies this exact generated helper as `__CGSSetFrontWindow`, with Lion native IDs `0x72f5 / 0x7359` and the same `0x1513`, option `0x3`, `0x24 / 0x2c` request/receive geometry. This is therefore the next narrow ID-only compatibility boundary.

The authoritative next procedure is:

```text
docs/process-manager-post-windowtitle-showwindow-cgs-set-front-window-compat-integration-experiment.md
```

The earlier `CGSShapeWindow` rejection and the color-profile/window-context diagnostics remain held. The new Lion run also produced crash/core diagnostics; preserve them, but the next compatibility gate is already determined by the exact SetFrontWindow wire differential.
