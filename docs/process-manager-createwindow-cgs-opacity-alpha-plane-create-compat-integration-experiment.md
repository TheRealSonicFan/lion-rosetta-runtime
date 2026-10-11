# Process Manager CreateNewWindow CGS opacity create-alpha compatibility integration experiment

## Objective

Integrate only the now-proven ID-only compatibility policy for the live `__CGSCreateWindowAlphaPlane` transaction beneath `CGSSetWindowOpacity`, while preserving the accepted NewWindow and release-backing adapters unchanged and leaving terminate-alpha, display-bounds, ShapeWindow, and all later CoreGraphics traffic untouched.

The prerequisites are complete:

```text
Snow/legacy create request / reply    0x724f / 0x72b3
Lion native create request / reply    0x7250 / 0x72b4
request bits                          0x1513
mach_msg option                       0x3
send / receive                        0x24 / 0x2c
reply size                            0x24
```

The Snow positive control selected CREATE, returned `0x72b3 / 0x24 / result 0`, and completed CreateNewWindow through DisposeWindow/M24. The Lion passive trace selected the same CREATE branch after native-success NewWindow and release-backing transactions, but the unchanged legacy `0x724f` request returned `MACH_RCV_TOO_LARGE (0x10004004)`.

The standalone copied-buffer proof then established:

```text
request 0x724f -> 0x7250          changed bytes 1
request body changes               0
source request changes             0
reply 0x72b4 -> 0x72b3            changed bytes 1
reply body changes                 0
success result 0                   preserved
modeled nonzero result -304        preserved
new diagnostics                    none
protected hashes                   unchanged
RESULT                              CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_POLICY_PROOF_PASS
```

This stage is therefore the first live Lion-native create-alpha request. It does not alter receive size, request body, NDR data, ports, timeout, notify, or server result.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-integration-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Compile-time mode:

```text
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION
```

Runtime modes:

```text
Snow  ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=passthrough
Lion  ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
```

Combined build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-v1
```

The dylib still contains exactly two PPC interpose tuples: `bootstrap_look_up2` and `mach_msg`.

## Exact live predicate and policy

The create-alpha compatibility handler is eligible only for the first exact legacy create-alpha transaction after the accepted NewWindow and release-backing compatibility calls. It requires:

```text
bits                              0x1513
request ID                        0x724f
option                            0x3
send / receive                    0x24 / 0x2c
remote port                       nonzero
reply port                        receive port, nonzero
timeout                           MACH_MSG_TIMEOUT_NONE
notify                            MACH_PORT_NULL
NDR                               exact local NDR
window ID at 0x20                 nonzero
create-alpha compatibility calls  1
release-backing compatibility calls 1
NewWindow compatibility calls     1
```

The window ID is intentionally not hard-coded: the accepted live traces already showed it is a per-run object value.

On Lion the adapter:

1. copies the exact `0x24` request to a private buffer;
2. changes only request ID `0x724f -> 0x7250`;
3. requires exactly one changed request byte, zero body-byte changes, and zero source-buffer changes;
4. calls the original `mach_msg` with unchanged option, send/receive sizes, ports, timeout, notify, NDR, and window ID;
5. accepts only native reply `0x72b4` with bits `0x1200`, size `0x24`, and cross-endian NDR;
6. decodes but never rewrites the native result scalar;
7. changes only native reply ID `0x72b4 -> 0x72b3`;
8. requires exactly one changed reply byte, zero body-byte changes, and identical decoded result;
9. copies the legacy-facing reply back to the PPC caller.

Any native nonzero result remains nonzero and unchanged. The adapter never converts an error to success.

The numeric collision `0x7250/0x72b4` with Snow terminate-alpha is contained inside the private native request/reply buffer. The translated PPC caller still sees only its legacy CREATE pair `0x724f/0x72b3`.

## Safety constraints

- Build only the new combined opacity create-alpha integration dylib on Snow Leopard 10.6.8.
- Reuse the accepted CreateNewWindow subject, Security interposer, Dock bootstrap adapter, HIToolbox Extras compatibility dylib/resource, and exact-four notification broker unchanged.
- Keep the accepted NewWindow and release-backing compatibility policies unchanged.
- On Snow, NewWindow, release-backing, and opacity create-alpha compatibility must all remain strict passthrough.
- Repeat the established syscall-295 gate on Lion.
- Keep `ROSETTA_CGS_NEWWINDOW_TRACE_MODE`, `ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE`, and `ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE` unset during the integration run.
- Do not add `MACH_RCV_LARGE` and do not change the PPC client's `0x2c` receive size.
- Do not broaden the create-alpha predicate.
- Do not adapt terminate-alpha, `CGSGetDisplayBounds`, `CGSShapeWindow`, or any later helper in this run.
- Do not normalize or suppress a nonzero native opacity result.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, launchd, or XNU.
- Do not restart or signal WindowServer or launchd jobs.
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

On Lion also update the XNU documentation checkout:

```sh
cd /path/to/lion-rosetta-xnu
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build only the opacity create-alpha integration dylib on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-integration-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-integration-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256
```

Require a 32-bit PPC dylib, exactly two interpose tuples, the combined build ID above, embedded distributed-notifications ingress v2, all accepted NewWindow/release-backing markers, and all opacity create-alpha compatibility call/request/native-reply/adapted-reply/PASS/PASSTHROUGH markers.

Stop if Phase B fails. Do not rebuild any other accepted artifact.

## Phase C — Snow Leopard full passthrough control

Unset old passive trace modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check and run the existing full-stack Snow control with only the CoreServices dylib pair changed:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration-snowleopard-control.log
```

Hard gate:

```text
NewWindow compatibility                    index=1 mode=passthrough exact=YES
NewWindow result                           PASSTHROUGH
release-backing compatibility              index=1 mode=passthrough exact=YES
release-backing result                     PASSTHROUGH
create-alpha compatibility                 index=1 mode=passthrough exact=YES
create-alpha result                        PASSTHROUGH
legacy create-alpha request                0x724f / 0x24 / 0x2c
legacy create-alpha reply                  0x72b3 / 0x24 / result 0
no create-alpha ADAPTER_PASS
CreateNewWindow                            0
WindowRef                                  nonzero
DisposeWindow                              reached
M24_SUCCESS                                reached
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

Stop if Phase C fails.

## Phase D — transfer only the new integration artifact

Transfer to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256
ppc-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration-snowleopard-control.log
```

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat syscall 295 on Lion

Run the established native routing probe and save:

```text
syscall295-probe-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion live opacity create-alpha compatibility integration

Unset passive modes and obsolete schema-audit variables:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
```

Keep the established expected kernel hash, then set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Syntax-check and run the existing Lion runner with only the CoreServices dylib pair changed:

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
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration.log
```

Require all accepted upstream gates to remain true: NewWindow must return native `0x73fe / 0x38 / result 0` and release-backing must return native `0x72b0 / 0x24 / result 0`, with both adapters reporting `ADAPTER_PASS`.

Then require exactly one create-alpha compatibility call:

```text
mode                             lion-id-v1
exact                            YES
legacy request                   0x724f
native request                   0x7250
send / receive                   0x24 / 0x2c
window ID                        nonzero
release-backing compat calls     1
NewWindow compat calls           1
request changed bytes            1
request body changes             0
source request changes           0
```

### Desired native-success branch

```text
native reply                     0x72b4 / 0x24 / result 0 / SUCCESS
legacy-facing reply              0x72b3 / 0x24 / result 0
reply changed bytes              1
reply body changes               0
PM_CGS_OPACITY_ALPHA_CREATE_COMPAT_RESULT:ADAPTER_PASS
```

The old `(ipc/rcv) msg too large: CGSSetWindowOpacity` diagnostic must no longer be attributed to this exact create-alpha transaction if the adapter returns native Mach success.

If CreateNewWindow then returns 0 with a nonzero WindowRef and reaches DisposeWindow/M24, the runner emits:

```text
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION_PASS
```

If the create-alpha adapter succeeds but CreateNewWindow still does not reach M21 because a later CoreGraphics operation becomes the next blocker, the runner emits:

```text
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN
```

Stop and preserve the first subsequent diagnostic/transport boundary. Do not adapt it in the same run.

### Native error branch

If Lion returns native `0x72b4 / 0x24` with a nonzero decoded result, the adapter must preserve that result unchanged while converting only the reply ID to `0x72b3`. The runner emits:

```text
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_ERROR_PRESERVED
```

Stop. Do not normalize the result or alter payload fields.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256
ppc-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration.log
lion-ppc-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration.log
lion-ppc-process-manager-createwindow-cgs-opacity-alpha-create-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the runner. Stop after Phase G.

## Decision gate

### `CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_INTEGRATION_PASS`

The exact create-alpha generated-MIG ID conversion is sufficient and the restored translated-PPC CreateNewWindow path now completes through immediate disposal. Preserve the complete result and advance only to the next explicit application milestone.

### `CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`

The create-alpha native transaction succeeded and a later CoreGraphics operation is now the first live blocker. Keep NewWindow, release-backing, and create-alpha adapters unchanged. Use only the first subsequent live boundary to select the next static/passive discriminator. Do not jump directly to ShapeWindow if an earlier operation appears.

### `CREATENEWWINDOW_CGS_OPACITY_ALPHA_CREATE_COMPAT_NATIVE_ERROR_PRESERVED`

The ID-only transformation is structurally correct but not sufficient. Preserve the exact native result and do not broaden the predicate or rewrite payload/result fields.

### Predicate, reply-envelope, or Mach failure

Preserve the exact request/reply evidence and stop. Do not broaden the adapter.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
NewWindow ID-only live integration              -> native Lion success
release-backing ID-only live integration        -> native Lion success
opacity create-alpha branch trace               -> 0x724f / MACH_RCV_TOO_LARGE
opacity create-alpha copied-buffer policy       -> PASS
next step                                       -> one exact live 0x724f -> 0x7250 integration
```

No additional XNU change is indicated.


## Observed completed result — create-alpha live integration passed

The returned evidence closes the CreateNewWindow compatibility chain through the exact live opacity create-alpha transaction.

Artifact provenance:

```text
combined build ID              dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-v1
architecture                   ppc7400
__interpose size               0x10 (exactly two PPC tuples)
combined dylib SHA-256         6d7f6d6a6aaa56512caa107c6b70a60e7ea30e63196b78c960899bd237cb5f25
Snow passthrough control       PASS
syscall 295                    EBADF / no SIGSYS / PASS
```

The Lion run reached exactly one create-alpha compatibility call after exactly one accepted NewWindow and one accepted release-backing compatibility call:

```text
legacy create request          0x724f
native Lion request            0x7250
send / receive                 0x24 / 0x2c
window ID                      0x251
request changed bytes          1
request body changes           0
source request changes         0
native Mach return             0
native reply                   0x72b4 / 0x24 / result 0
legacy-facing reply            0x72b3 / 0x24 / result 0
reply changed bytes            1
reply body changes             0
adapter result                 PASS
```

After that native-success conversion, public `CreateNewWindow` returned 0 with a nonzero WindowRef, immediate `DisposeWindow` returned, and `M24_SUCCESS` was reached. The exact-four distributed-notification broker passed, process exit status was 0, no new crash/core diagnostic was created, and protected hashes remained unchanged.

Several CoreGraphics diagnostics remain visible inside the successful `CreateNewWindow` call, including `CGSGetDisplayBounds (display 0)`, `CGSShapeWindow` type-check failure, backing-map/lock failures, and invalid display-color-space. Because they no longer prevent `CreateNewWindow` from returning a valid object and the test disposes that object immediately, they are not independently authorized compatibility targets yet.

The CreateNewWindow construction gate is therefore complete. The next controlled discriminator is the first post-construction operation from the historical Carbon GUI flow: create the already-proven CoreFoundation title string and call `SetWindowTitleWithCFString` on the returned WindowRef, then dispose the window without showing/selecting it or entering the event loop. Follow:

```text
docs/process-manager-post-createwindow-windowtitle-validation-experiment.md
```

Keep the accepted NewWindow, release-backing, and create-alpha adapters byte-for-byte unchanged. Do not adapt terminate-alpha, display-bounds, ShapeWindow, backing, visibility, or event-loop traffic unless a later experiment makes one of them the first failing observable. No XNU change is indicated.
