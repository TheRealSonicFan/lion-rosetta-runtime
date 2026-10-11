# Process Manager CreateNewWindow CGS release-backing compatibility integration experiment

## Objective

Integrate the now-proven ID-only compatibility policy for the first post-NewWindow `CGSSetWindowToReleaseBackingOnOrderOut` transaction into the existing combined CoreServices `mach_msg` interposer, while leaving the accepted NewWindow adapter and all later CoreGraphics traffic unchanged.

The prerequisites are complete:

```text
Snow legacy request / reply      0x724b / 0x72af
Lion native request / reply      0x724c / 0x72b0
request bits                     0x1513
mach_msg option                  0x3
send / receive                   0x28 / 0x2c
reply size                       0x24
```

The live passive trace showed Snow returning result 0 and completing CreateNewWindow, while Lion sent the same legacy envelope and received Mach success plus the expected legacy reply ID carrying raw result `0xd0feffff`, decoded as `-304`. The standalone copied-buffer proof then established that changing only `0x724b -> 0x724c` and `0x72b0 -> 0x72af` changes exactly one byte in each copied message, changes zero body bytes, leaves the source request untouched, preserves success result 0, and preserves a nonzero `-304` result unchanged.

This stage is the first live native-ID release-backing request. No payload scalar, port, message size, NDR record, or server result is fabricated.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-compat-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Compile-time mode:

```text
PM_CGS_RELEASEBACKING_COMPAT_INTEGRATION
```

Runtime modes:

```text
Snow  ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough
Lion  ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
```

Combined build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-v1
```

The dylib retains exactly two PPC interpose tuples: `bootstrap_look_up2` and `mach_msg`.

## Exact live predicate and policy

The release-backing handler is eligible only for the first exact legacy release-backing transaction after the already accepted NewWindow compatibility call. It requires:

```text
bits                         0x1513
request ID                   0x724b
option                       0x3
send / receive               0x28 / 0x2c
remote port                  nonzero
reply port                   receive port, nonzero
timeout                      0
notify                       MACH_PORT_NULL
NDR                          exact local NDR
window ID at 0x20            nonzero
release flag at 0x24         1
release-backing calls        1
NewWindow compatibility calls 1
```

The window ID is deliberately not fixed to the value captured in any earlier run because the Snow and Lion traces already proved that it is a per-run object value while the request layout is stable.

On Lion the adapter:

1. copies the exact 0x28-byte request to a private buffer;
2. changes only request ID `0x724b` to `0x724c`;
3. requires exactly one changed request byte, zero body-byte changes, and zero source-buffer changes;
4. calls the original `mach_msg` with unchanged option, send/receive sizes, ports, timeout, notify, NDR, window ID, and release flag;
5. accepts only native reply `0x72b0` with bits `0x1200`, size `0x24`, and cross-endian NDR;
6. decodes but does not rewrite the native result scalar;
7. changes only native reply ID `0x72b0` to legacy `0x72af`;
8. requires exactly one changed reply byte, zero body-byte changes, and identical decoded result;
9. copies the legacy-facing reply back to the PPC caller.

A native nonzero result is propagated unchanged. The adapter never converts an error to success.

## Safety constraints

- Build only the new combined release-backing compatibility dylib on Snow Leopard 10.6.8.
- Reuse the accepted CreateNewWindow subject unchanged.
- Reuse the accepted Security, Dock-aware CGS, HIToolbox Extras, exact-four notification broker, and staged Snow `Extras.rsrc` unchanged.
- Keep the NewWindow ID-only compatibility policy unchanged.
- On Snow, both NewWindow and release-backing compatibility remain strict passthrough.
- Repeat the established syscall-295 safety gate on Lion.
- Keep `ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE` unset during the live integration run.
- Do not broaden the release-backing predicate.
- Do not translate opacity, display-bounds, ShapeWindow, or any other later CoreGraphics transaction.
- Do not normalize or suppress a nonzero native release-backing result.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, launchd, or XNU.
- Do not restart or signal WindowServer or launchd jobs.
- Run the Lion integration exactly once before review.
- Preserve every new crash/core diagnostic.
- No XNU rebuild or reboot.

## Phase A — update repositories

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the XNU documentation checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build only the release-backing integration dylib on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-compat-integration-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-releasebacking-compat-integration-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.sha256
```

Require a 32-bit PPC dylib, exactly two interpose tuples, the combined build ID above, embedded distributed-notifications ingress v2, all accepted NewWindow compatibility markers, both release-backing trace-kind strings, and all release-backing compatibility call/request/native-reply/adapted-reply/PASS/PASSTHROUGH markers.

Do not rebuild any other accepted artifact.

## Phase C — Snow Leopard full passthrough control

Unset `ROSETTA_CGS_NEWWINDOW_TRACE_MODE` and `ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE`. Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check and run the existing Snow full-stack control, changing only the CoreServices dylib pair:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-cgs-releasebacking-compat-integration-snowleopard-control.log
```

Hard gate:

```text
NewWindow compatibility call              index=1 mode=passthrough exact=YES
NewWindow result                          PASSTHROUGH
release-backing compatibility call        index=1 mode=passthrough exact=YES
release-backing result                    PASSTHROUGH
no release-backing ADAPTER_PASS
legacy release-backing request            0x724b / 0x28 / 0x2c
legacy release-backing reply              0x72af / 0x24 / result 0
CreateNewWindow                           0
WindowRef                                 nonzero
DisposeWindow                             reached
M24_SUCCESS                               reached
RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

Stop if Phase C fails.

## Phase D — transfer only the new integration artifact

Transfer to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.sha256
ppc-process-manager-createwindow-cgs-releasebacking-compat-integration-snowleopard-control.log
```

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat the established syscall-295 safety gate on Lion

Run the same native routing probe and save:

```text
syscall295-probe-process-manager-createwindow-cgs-releasebacking-compat-integration.log
```

Require `result=-1`, `errno=9`, `saw_sigsys=0`, and `RESULT: PASS`.

## Phase F — exactly one Lion live release-backing compatibility integration

Unset `ROSETTA_CGS_NEWWINDOW_TRACE_MODE`, `ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE`, and obsolete schema-audit variables. Keep the established expected kernel hash.

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Syntax-check the existing Lion runner, then run it with only the CoreServices dylib pair changed:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-integration.log
```

Require all accepted upstream gates to remain true through NewWindow native success.

The release-backing adapter must show exactly one exact call and one-byte request-ID conversion:

```text
legacy request ID          0x724b
native request ID          0x724c
send / receive             0x28 / 0x2c
request changed bytes      1
request body changes       0
source request changes     0
release flag               1
```

### Desired native-success branch

```text
native reply               0x72b0 / 0x24 / result 0 / SUCCESS
legacy-facing reply        0x72af / 0x24 / result 0
reply changed bytes        1
reply body changes         0
PM_CGS_RELEASEBACKING_COMPAT_RESULT:ADAPTER_PASS
```

If CreateNewWindow then returns 0 with a nonzero WindowRef and reaches DisposeWindow/M24, the runner emits:

```text
RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_INTEGRATION_PASS
```

If the release-backing adapter succeeds but CreateNewWindow still does not return because a later CoreGraphics operation becomes the next boundary, the runner emits:

```text
RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN
```

Stop there and preserve the first subsequent CoreGraphics diagnostic/transport evidence. Do not adapt the next helper in the same run.

### Native error branch

If Lion returns native `0x72b0 / 0x24` with a nonzero decoded result, the adapter must preserve it while changing only the reply ID to `0x72af`. The runner emits:

```text
RESULT: CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_ERROR_PRESERVED
```

Stop there. Do not normalize the server result.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat.dylib.sha256
ppc-process-manager-createwindow-cgs-releasebacking-compat-integration-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-releasebacking-compat-integration.log
lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-integration.log
lion-ppc-process-manager-createwindow-cgs-releasebacking-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the runner. Stop after Phase G.

## Decision gate

### `CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_INTEGRATION_PASS`

The exact release-backing generated-MIG ID conversion is sufficient and the restored translated-PPC path now completes CreateNewWindow and immediate DisposeWindow under the full compatibility stack. Preserve the result and review the next application/event-loop milestone rather than broadening either CGS adapter.

### `CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`

The release-backing native transaction succeeded and a later CoreGraphics operation is now the first live blocker. Keep both NewWindow and release-backing adapters unchanged. Use only the first subsequent live boundary to choose the next static/passive discriminator.

### `CREATENEWWINDOW_CGS_RELEASEBACKING_COMPAT_NATIVE_ERROR_PRESERVED`

The ID-only conversion is structurally correct but not sufficient. Preserve the exact native result and do not change the payload or normalize the error.

### Predicate, reply-shape, or Mach failure

Preserve the exact request/reply envelope and stop. Do not broaden the predicate.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
Dock bootstrap compatibility                    -> PASS
NewWindow ID-only live integration              -> native Lion success
release-backing passive trace                    -> legacy Lion reply / -304
release-backing copied-buffer policy             -> PASS
next step                                       -> one exact live 0x724b -> 0x724c integration
```

No additional XNU change is indicated.
