# Process Manager ShowWindow color-profile client live trace experiment

## Objective

The completed static Snow-Leopard-versus-Lion CoreGraphics audit identifies the next exact ShowWindow boundary without authorizing a compatibility rewrite.

The generated MIG helper used by `CGSColorProfileCreateWithColorProfileID` is protocol-equivalent across releases except for its routine IDs:

```text
                         Snow Leopard PPC       Lion i386
request ID               0x74d4                 0x74d6
reply ID                 0x7538                 0x753a
request bits             0x80001513             0x80001513
mach_msg option          0x3                    0x3
send size                0x34                   0x34
receive size             0x30                   0x30
port descriptors         1                      1
descriptor disposition   0x13                   0x13
descriptor type          0x00                   0x00
NDR offset               0x28                   0x28
PID offset               0x30                   0x30
success reply size       0x28                   0x28
error reply size         0x24                   0x24
result offset            0x20                   0x20
client-ID offset         0x24                   0x24
```

The caller-side control flow is also equivalent. On a cache miss, `CGSColorProfileCreateWithColorProfileID` obtains the CGS server port, gets the process ID, invokes `__CGSColorProfileClient`, and logs `Cannot initialize color profile client` if that RPC returns a nonzero result. `_CGSWindowColorProfile` then reports the requested profile ID as invalid when profile creation returns null. This makes the color-profile client initialization failure upstream of the later window-context/null-context diagnostics.

The existing application-CGS passive tracer did not expose `0x74d4` because that tracer is restricted to the established application connection port, while this helper is sent through the `_CGSServerPort` path. The next experiment therefore adds a target-only passive trace for the exact color-profile client routine regardless of which nonzero CGS server port carries it.

This stage does **not** rewrite `0x74d4`. Its purpose is to prove the live Snow success shape and the live Lion legacy failure before an ID-only adapter is authorized.

## Prepared trace

Current runtime `main` provides:

```text
scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace-on-snowleopard.sh
```

and extends the existing restored-stack Snow/Lion runners with:

```text
Snow Leopard  ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE=snow-passive-v1
Lion          ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE=lion-passive-v1
```

The trace recognizes only exact `0x74d4` or `0x74d6` color-profile client routine IDs and records the request envelope, descriptor metadata, PID, Mach return, reply envelope, raw result, and returned client ID. It performs no request or reply mutation.

## Safety constraints

- Reuse the accepted ShowWindow subject, exact-six notification broker, Security interposer, HIToolbox Extras resource compatibility, DockServer/FontServer paths, NewWindow, release-backing, create-alpha, AddTrackingArea, OrderFrontConditionally, and SetFrontWindow paths unchanged.
- Do not adapt `0x74d4 -> 0x74d6` in this stage.
- Do not synthesize a color-profile client ID.
- Do not force `CGSColorProfileCreateWithColorProfileID`, `_CGSWindowColorProfile`, `CGWindowContextCreate`, ColorSync, CoreUI, or RawCamera to succeed.
- Do not adapt the earlier held `CGSShapeWindow` rejection.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- Run exactly one Lion integration after the Snow control.
- Preserve every new crash/core diagnostic named by the Lion runner.

No XNU source change, kernel rebuild, or reboot is part of this stage.

## Phase A — update repositories

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD
```

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

cd "$ROSETTA_XNU" || exit 1
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build the passive-trace interposer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace-on-snowleopard.sh || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace-on-snowleopard.sh || exit 1
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.sha256
```

Require PPC7400, exactly two `__interpose` tuples, ingress v2, and build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace-v1
```

Stop if build, architecture, marker, or hash validation fails.

## Phase C — Snow Leopard positive control

Use the same accepted Snow restored stack as the completed SetFrontWindow control and add only the passive color-profile client trace mode:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE=snow-passive-v1
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

/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace-snowleopard-control.log || exit 1
```

Require at least one exact legacy color-profile client transaction and require its first-order shape to be:

```text
kind                      CGS_COLOR_PROFILE_CLIENT_LEGACY
request                    0x74d4
bits                       0x80001513
send / receive             0x34 / 0x30
descriptor count           1
descriptor disposition     0x13
descriptor type            0x00
PID                        nonzero
mach_msg                   success
reply                      0x7538
reply size                 0x28
result                     0
client ID                  nonzero
Lion-native 0x74d6         not observed
S01_AFTER_ShowWindow       reached
SHOWWINDOW_PASS            reached
DisposeWindow / M24        complete
RESULT                     POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_SNOW_CONTROL_PASS
RESULT                     PASS
```

Stop if the passive trace changes Snow behavior.

## Phase D — transfer the trace artifact

Transfer from Snow Leopard to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace-snowleopard-control.log
```

Place the dylib, `.info.txt`, and `.sha256` under Lion's `payload/` directory and place the Snow control log at the runtime root. Verify the transferred dylib SHA-256 against its sidecar before execution.

## Phase E — repeat syscall 295 on Lion

Use the existing accepted i386 probe:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash -n "$ROSETTA_XNU/tools/run_syscall295_probe.sh" || exit 1

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/syscall295-probe-process-manager-post-windowtitle-showwindow-color-profile-client-trace.log" || exit 1
```

Require the established kernel SHA, `result=-1 errno=9 saw_sigsys=0`, exit status 0, and `RESULT: PASS`.

## Phase F — exactly one Lion passive trace

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-sixth-register-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH=./payload/ppc-hitoolbox-extras-resource-compat.dylib
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE=./payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH=./payload/SnowLeopard-HIToolbox-Extras.rsrc
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace.log
```

Do not run the Lion subject a second time.

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_LEGACY_MINUS304`

This is the leading expected discriminator. Require an exact legacy `0x74d4` request, successful Mach transport, simple legacy-facing `0x7538 / 0x24` error reply carrying raw `-304 / 0xd0feffff`, no `0x74d6` request, the accepted upstream adapters unchanged, exact-six broker PASS, and protected hashes unchanged.

If confirmed, the static and live evidence together authorize preparation of a separate exact ID-only ColorProfileClient compatibility experiment: request `0x74d4 -> 0x74d6`, native `0x753a` reply mapped back to `0x7538`, with the descriptor/body and result semantics preserved. Do not implement that conversion during this trace run.

### Legacy request succeeds on Lion

Stop. Do not add an ID adapter; the color-profile failure must then be elsewhere in client-ID caching or later resolution.

### Different envelope, transport error, or different native failure

Stop. Preserve the first run and review the exact trace before changing recognition or compatibility policy.

## Return

Return these six primary artifacts:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-trace.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-color-profile-client-trace.log
lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace.log
lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the dylib itself unless specifically requested.

## Current boundary

```text
SetFrontWindow                                   accepted adapter PASS
ColorProfileClient Snow PPC helper              0x74d4 / 0x7538
ColorProfileClient Lion i386 helper             0x74d6 / 0x753a
wire geometry                                   equivalent, ID-only +2 statically proven
live legacy ColorProfileClient transaction       not yet directly observed
window color-profile failure                     downstream of client-init failure
CGWindowContext/CoreUI/RawCamera                 downstream/held
CGSShapeWindow                                   held
next step                                        exact passive ColorProfileClient live trace
XNU                                              no change indicated
```
