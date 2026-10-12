# Process Manager ShowWindow ResolveColorProfile passive live trace experiment

## Objective

The static Snow Leopard PPC / Lion i386 resolver differential is complete and both reports pass.

The client-side `__CGSResolveColorProfile` generated-MIG contract is an exact release-skew candidate:

```text
Snow request/reply          0x74d7 / 0x753b
Lion request/reply          0x74d9 / 0x753d
request bits                0x80001513 on both
Mach option                 0x3 on both
send / receive              0x38 / 0x3c on both
descriptor count            1 on both
descriptor disposition/type 0x13 / 0x00 on both
success / error reply       0x34 / 0x24 on both
request body                task-port descriptor + NDR + client ID + profile ID
success body                result + two 64-bit output pairs
```

The corresponding server stubs accept the same `0x38` complex request shape and return `0x34` on success. The server-side resolve routines on both systems follow the same live-relevant sequence: find the ColorProfile client, verify its task port, locate the requested profile ID, remap the profile data, associate the requesting PID, and return success. Implementation details differ in places, but the static evidence does not justify modifying profile state or synthesizing profile ID 1.

The current Lion failure occurs immediately after the already accepted ColorProfileClient adapter succeeds and is `CGSColorProfileCreateWithColorProfileID: Cannot resolve color profile id(1)`. Static evidence alone does not prove whether the unchanged PPC client actually emits legacy `0x74d7` on Lion and receives a generated-MIG `-304` rejection, or whether the Lion-native resolve routine is reached and rejects profile state. This stage answers only that live discriminator.

No ResolveColorProfile rewrite is authorized in this stage.

## Prepared instrumentation

Current runtime `main` provides:

```text
scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-on-snowleopard.sh
```

The build uses the already accepted ColorProfileClient compatibility implementation unchanged and adds only a target-specific passive resolver trace. The core compatibility build ID remains the accepted ColorProfileClient v2 ID so the existing validated Snow/Lion runners continue to enforce all prior gates. The trace has its own independent marker:

```text
PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:color-profile-resolve-passive-trace-v1
```

For request IDs `0x74d7` and `0x74d9`, it records only request/reply metadata and raw fixed-width fields. It never changes the resolver request, reply, client ID, profile ID, descriptor, NDR, result, or output data.

Expected trace markers:

```text
PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REQUEST:
PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REPLY:
```

## Safety constraints

- Perform one behavior-preserving Snow control before Lion.
- Perform exactly one Lion translated-PPC run after the syscall-295 preflight.
- Keep the accepted ColorProfileClient adapter enabled on Lion; otherwise the resolver boundary is not reached correctly.
- Do not add a ResolveColorProfile adapter.
- Do not rewrite `0x74d7`, `0x753b`, `0x74d9`, or `0x753d` in this stage.
- Do not synthesize or substitute the ColorProfile client ID or color profile ID 1.
- Do not force `CGSColorProfileCreateWithColorProfileID`, `_CGSWindowColorProfile`, `CGWindowContextCreate`, CoreUI, or RawCamera to succeed.
- Do not alter the accepted NewWindow, release-backing, create-alpha, OrderFrontConditionally, AddTrackingArea, SetFrontWindow, ColorProfileClient, FontServer, HIToolbox, Security, or exact-six notification compatibility paths.
- Keep the held `CGSShapeWindow` path unchanged.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.

## Phase A — update the repositories

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD
```

On Lion also update the accepted XNU checkout used only by the syscall-295 probe:

```sh
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
cd "$ROSETTA_XNU" || exit 1
git pull --ff-only
git rev-parse HEAD
```

## Phase B — build the passive resolver tracer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-on-snowleopard.sh || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-on-snowleopard.sh || exit 1
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.sha256
```

Require a 32-bit PPC Mach-O dylib, exactly two `__interpose` tuples, the accepted ColorProfileClient v2 core build ID, embedded distributed-notifications ingress v2, and the resolver-trace build marker above.

## Phase C — Snow Leopard behavior-preserving control

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
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
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=passthrough
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

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log || exit 1

/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:color-profile-resolve-passive-trace-v1' \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log || exit 1
/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_RESOLVE_LEGACY exact=YES' \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log || exit 1
/usr/bin/grep -F 'profileId=1' \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log || exit 1
/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REPLY:kind=CGS_COLOR_PROFILE_RESOLVE_LEGACY' \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log || exit 1
```

The leading expected Snow resolver transaction is:

```text
request ID                  0x74d7
request exact               YES
profile ID                  1
reply ID                    0x753b
reply size                  0x34
result                      0
ShowWindow                  PASS
M24/disposal                reached
final control               PASS
```

Stop if the resolver trace changes Snow behavior, if the request is not structurally exact, or if the Snow resolver does not succeed.

## Phase D — transfer the trace artifact to Lion

Transfer these files from Snow Leopard to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log
```

Place the dylib, `.info.txt`, and `.sha256` under Lion's `payload/` directory and keep the Snow control log at the runtime root. Verify the transferred dylib against its sidecar before execution.

## Phase E — syscall-295 preflight on Lion

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/syscall295-probe-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace.log" || exit 1
```

Require the accepted kernel SHA, `result=-1 errno=9 saw_sigsys=0`, exit status 0, and `RESULT: PASS`.

## Phase F — exactly one Lion passive resolver trace

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
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
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=lion-id-v1
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

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace.log
```

Do not run the Lion subject a second time.

## Decision gate

The leading expected discriminator is an exact legacy resolver request:

```text
PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REQUEST:
kind=CGS_COLOR_PROFILE_RESOLVE_LEGACY
exact=YES
id=0x000074d7
send=0x00000038
recv=0x0000003c
profileId=1
```

Then classify the first reply without modifying it.

### Legacy ID rejected by Lion generated-MIG dispatch

If Lion returns:

```text
reply ID                    0x753b
reply size                  0x24
resultRaw                   0xd0feffff
```

with Mach transport success, the live failure is the same generated-MIG ID skew already proven statically. Preserve this run. Only after review may an exact `0x74d7 -> 0x74d9` / `0x753d -> 0x753b` adapter be authorized.

### Lion-native resolver is reached but profile resolution fails

If the reply is not a simple legacy-facing `-304` envelope, preserve the request/reply and the first associated diagnostic. Do not infer that an ID adapter is sufficient. The next step would be to isolate the client-ID/profile-ID state relationship and server-side profile registration semantics.

### Request geometry differs

If the request is not `exact=YES`, if the profile ID is not 1, or if the envelope differs from the static contract, stop. Do not relax the predicate or rewrite any bytes.

## Return

Return these six primary artifacts:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-resolve-trace.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace.log
lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace.log
lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the dylib itself unless specifically requested.

## Current boundary

```text
ColorProfileClient adapter                 accepted PASS
ResolveColorProfile Snow static            0x74d7 / 0x753b
ResolveColorProfile Lion static            0x74d9 / 0x753d
resolver wire geometry                     matching 0x38 / 0x3c complex request
resolver success/error reply               matching 0x34 / 0x24
static result                              exact +2 generated-MIG differential
next step                                 passive live resolver discriminator
CGWindowContext/CoreUI/RawCamera           downstream/held
CGSShapeWindow                             held
XNU                                        no change indicated
```
