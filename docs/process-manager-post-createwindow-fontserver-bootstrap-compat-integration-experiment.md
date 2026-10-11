# Process Manager post-CreateNewWindow FontServer bootstrap compatibility integration experiment

## Objective

Integrate only the now-proven `com.apple.FontServer` launchd lookup conversion into the existing CGS bootstrap compatibility interposer, then rerun the restored-stack window-title validation exactly once.

The prerequisite is complete:

```text
Snow ordinary PPC lookup       com.apple.FontServer -> kr=0, nonzero port
Lion legacy PPC lookup         com.apple.FontServer -> -304, zero port
Lion-format standalone lookup  request 0x194 / 0xbc / PID 0 / UUID zero / flags 0
Lion-format reply              0x1f8 / 0x28 / descriptor count 1 / valid send right
RESULT                         FONTSERVER_BOOTSTRAP_PROTOCOL_ADAPTER_PASS
```

No new diagnostic was produced by the standalone proof, protected runtime/kernel identities remained unchanged, and syscall 295 remained EBADF/no-SIGSYS.

This stage does not broaden distributed-notification policy. The fifth notification request observed in the previous title run occurred after the first FontServer `-304` divergence and remains deliberately rejected by the exact-four broker until this FontServer integration identifies the next live boundary.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c
scripts/build-ppc-process-manager-cgs-dockserver-fontserver-bootstrap-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

New CGS bootstrap build ID:

```text
cgs-session-bootstrap-dockserver-fontserver-compat-v3
```

The dylib still has exactly one PPC `__interpose` tuple, for `bootstrap_look_up`.

Runtime modes:

```text
Snow  ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
Snow  ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
Lion  ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
Lion  ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
```

All existing WindowServer-session and Dock-server behavior is preserved.

## Exact FontServer compatibility policy

The new branch is eligible only when the interposed function is called with the exact case-sensitive service name:

```text
com.apple.FontServer
```

Snow mode calls the original `bootstrap_look_up` unchanged.

Lion mode builds the already-proven ordinary lookup request:

```text
request ID                    0x00000194
bits                          0x00001513
send size                     0x000000bc
receive size                  0x0000006c
service offset                0x20
target PID offset             0xa0
target PID                    0
instance UUID offset          0xa4
instance UUID                 all zero
flags offset                  0xb4
flags                         0
expected reply ID             0x000001f8
success reply size            0x28
```

A success reply must be complex, contain descriptor count 1, return a nonzero port, and that port must carry a send right. The adapter returns that exact send right to the legacy caller. Simple native server errors are propagated unchanged. No FontServer RPC method is synthesized or translated.

Multiple exact FontServer lookups are allowed because the title path may request the service more than once. The Lion runner requires every observed FontServer compatibility call to end in `ADAPTER_PASS`; one failure or incomplete call stops the experiment.

## Safety constraints

- Build only the new CGS bootstrap compatibility dylib on Snow Leopard 10.6.8.
- Reuse the accepted window-title subject unchanged.
- Reuse the accepted CoreServices, Security, HIToolbox Extras/resource, and exact-four notification broker artifacts unchanged.
- Keep NewWindow, release-backing, opacity create-alpha, Dock, CPS, Process Manager, and notification compatibility behavior unchanged.
- Snow Dock and FontServer modes must both be strict passthrough.
- Repeat syscall 295 on Lion.
- Keep all passive trace modes unset.
- Do not accept, rewrite, or otherwise broaden the fifth distributed-notification request in this run.
- Do not add a FontServer RPC adapter; only resolve the exact bootstrap service port.
- Do not show/select/query the window or enter the event loop.
- Do not patch CoreText, ATS, CoreGraphics, HIToolbox, FontServer/fontd, launchd, Rosetta, dyld, shared caches, or XNU.
- Do not restart or signal FontServer/fontd, WindowServer, Dock, launchd, or related jobs.
- Run the Lion integration exactly once before review.
- Preserve every new crash/core diagnostic named by the runner.
- No XNU rebuild or reboot.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update XNU documentation:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build only the combined Dock + FontServer CGS interposer on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-cgs-dockserver-fontserver-bootstrap-compat-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-cgs-dockserver-fontserver-bootstrap-compat-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.sha256
```

Require:

```text
architecture                     thin 32-bit PPC
__interpose size                 0x8, exactly one PPC tuple
build ID                         cgs-session-bootstrap-dockserver-fontserver-compat-v3
service markers                  windowserver.session / windowserver.active / dock.server / FontServer
Dock ADAPTER_PASS marker         present
FontServer ADAPTER_PASS marker   present
bootstrap_look_up import         present
bootstrap_look_up2 import        absent
```

Stop if Phase B fails. Do not rebuild any other accepted artifact.

## Phase C — Snow Leopard full-stack title control with strict passthrough

Unset passive modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
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
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-post-createwindow-windowtitle-fontserver-compat-snowleopard-control.log
```

Hard gate:

```text
WindowServer/session compatibility              passthrough
Dock compatibility                              passthrough
FontServer compatibility call                   index 1 or later, mode=passthrough
FontServer passthrough reason                   FONT_SNOW_PASSTHROUGH
FontServer original return                      kr=0, servicePort=nonzero
no FontServer ADAPTER_PASS                      required
CreateNewWindow                                 0, nonzero WindowRef
CFStringCreateWithCString                       nonzero
SetWindowTitleWithCFString                      0
CFRelease                                       completed
DisposeWindow                                   completed
M24_SUCCESS                                     reached
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

Stop if Phase C fails.

## Phase D — transfer only the new CGS interposer plus Snow control evidence

Transfer to Lion:

```text
payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib
payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.info.txt
payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-compat-snowleopard-control.log
```

Reuse every other accepted Lion artifact unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-compat-integration.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion window-title run with FontServer lookup compatibility

Unset passive/audit modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Keep the established expected kernel hash. Syntax-check and run:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-compat-integration.log
```

Require the accepted upstream chain through CreateNewWindow and T02 to remain unchanged.

For every FontServer compatibility call, require:

```text
mode                            lion-fontserver-v1
name                            com.apple.FontServer
request ID                      0x194
send / receive                  0xbc / 0x6c
PID                             0
UUID                            ZERO
flags                           0
Mach return                     0
reply ID                        0x1f8
reply size                      0x28
descriptor count                1
service port                    nonzero
send right                      YES
adapter return                  kr=0
result                          ADAPTER_PASS
```

The runner records the number of FontServer calls and PASS results and requires them to match.

### Desired full title-success branch

If the exact-four notification broker is sufficient and the title path completes:

```text
T03_AFTER_SetWindowTitleWithCFString       reached
SetWindowTitleWithCFString                 0
SETWINDOWTITLE_PASS                        reached
CFRelease                                  completed
DisposeWindow                              completed
M24_SUCCESS                                reached
broker                                     PASS
process exit                               0
new diagnostics                            none
protected hashes                           unchanged
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_INTEGRATION_PASS
```

### Expected newly exposed notification boundary

If at least one FontServer adapter call passes and the next newly exposed fifth notification is rejected by the unchanged exact-four broker, the runner emits:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_PASS_NOTIFICATION_PROTOCOL_REJECTED
```

Stop. Preserve the raw fifth request and all diagnostics. Do not accept it in the same run.

### Other post-adapter no-return

If every FontServer lookup passes, no notification rejection occurs, but T03 is still not reached, the runner emits:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN
```

Stop on the first subsequent transport/API diagnostic.

### Adapter failure

Any FontServer `ADAPTER_FAIL`, missing lookup call, missing PASS, or call/PASS count mismatch is a hard stop. Do not broaden the service predicate.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-compat.dylib.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-compat-snowleopard-control.log
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-compat-integration.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-compat-integration.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner. Stop after Phase G.

## Decision gate

### `POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_INTEGRATION_PASS`

The returned WindowRef is usable through title assignment under the restored stack. Keep all compatibility paths unchanged and advance only to `ShowWindow`.

### `POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_PASS_NOTIFICATION_PROTOCOL_REJECTED`

The FontServer lookup boundary is closed and the fifth distributed-notification request is now the first blocker. Do not broaden the existing broker directly; capture/audit that exact request schema first, using the same pattern previously used for the fourth request.

### `POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`

The FontServer lookup succeeded but another title-path operation is now first. Preserve that exact boundary and choose a narrow discriminator from it.

### FontServer adapter failure

Preserve the exact request/reply and stop. Do not adapt FontServer RPC traffic or widen the service predicate.

## Current boundary

```text
PPC execution / Rosetta                               -> PASS
syscall 295                                           -> PASS
Process Manager / notification / HIToolbox / Dock     -> PASS through CreateNewWindow
NewWindow / release-backing / create-alpha            -> native Lion success
CreateNewWindow                                       -> 0, nonzero WindowRef
CFStringCreateWithCString                             -> PASS
Snow FontServer legacy lookup                         -> PASS, nonzero port
Lion FontServer legacy lookup                         -> -304, zero port
Lion FontServer exact 0xbc standalone lookup          -> PASS, valid send right
next step                                             -> exact FontServer live integration
```

No additional XNU change is indicated.
