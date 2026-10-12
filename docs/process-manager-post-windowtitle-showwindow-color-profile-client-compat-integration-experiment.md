# Process Manager ShowWindow ColorProfileClient compatibility integration

## Objective

The completed passive live trace proved the exact ColorProfileClient boundary predicted by the Snow-Leopard-versus-Lion CoreGraphics differential.

The accepted live evidence is:

```text
Snow PPC request / reply        0x74d4 / 0x7538
Snow reply                      size 0x28, result 0, client ID nonzero
Lion legacy request             0x74d4
Lion legacy reply               0x7538 / size 0x24 / raw 0xd0feffff (-304)
Lion legacy attempts observed   4
Lion-native request observed    none
Lion i386 helper IDs            0x74d6 / 0x753a
wire geometry                   otherwise equivalent
```

The Lion legacy requests use a non-application CGS server port, Mach transport succeeds, and the `-304` result is immediately followed by the CoreGraphics `Cannot initialize color profile client` diagnostics. The accepted NewWindow, release-backing, create-alpha, AddTrackingArea, OrderFrontConditionally, SetFrontWindow, exact-six distributed-notifications, Security, FontServer, and HIToolbox paths remain intact.

This experiment therefore adds one narrowly gated user-space compatibility rule. It does not change XNU.

## Phase-C v1 control failure and v2 correction

The first compatibility-capable Snow control reached the real legacy ColorProfileClient request and preserved its successful reply, ShowWindow return, disposal, and exit status, but the harness ended in `RESULT: FAIL`. The passive trace classified that request `exact=YES`, while the compatibility call printed `exact=NO` even though its bits, IDs, sizes, descriptor geometry, PID, and all compatibility-call counters matched the expected Snow control.

That discrepancy was a recognition bug in compatibility build v1, not a Snow Leopard behavior change. The compatibility predicate incorrectly required `gCGSShowWindowTracePort` to have already been learned from `CGS_CREATE_WINDOW_INLINE_LEGACY` and required the ColorProfileClient remote port to differ from it. Snow's successful ColorProfileClient initialization occurs at `M20_BEFORE_CreateNewWindow`, before the first CreateNewWindow request, so that application-CGS port is necessarily still unknown at this point.

Compatibility build v2 fixes the gate by making `exact` mean the same structural request geometry already proven by the passive trace. The Lion-only server-port provenance test is now a separate `lionPortExact` predicate and remains mandatory before any ID adaptation. Thus the Snow passthrough control must report `exact=YES lionPortExact=NO applicationPort=0x00000000`, while the Lion adapter is permitted only with `exact=YES lionPortExact=YES` and a nonzero learned application port. The ID-only adapter still preserves the NDR/body bytes verbatim; NDR value equality is not an extra recognition constraint.

Any v1 compatibility dylib is stale after this correction. Pull current runtime `main`, rebuild Phase B, and repeat Phase C. Do not transfer the v1 artifact or proceed to Lion from a v1 `RESULT: FAIL`.

## Compatibility rule

Runtime mode:

```text
Snow Leopard  ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=passthrough
Lion          ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=lion-id-v1
```

The Lion adapter is eligible only for the first exact legacy ColorProfileClient request in the `S00_BEFORE_ShowWindow` interval. The live ordering is itself part of the predicate: Lion reaches this first ColorProfileClient call after the accepted NewWindow, release-backing, and create-alpha conversions, but before OrderFrontConditionally, AddTrackingArea, or SetFrontWindow has been called. The later three legacy ColorProfileClient retries remain out of scope. The request must retain the proven complex-MIG geometry:

```text
request ID               0x74d4
request bits             0x80001513
mach_msg option          0x3
send size                0x34
receive size             0x30
port descriptors         1
descriptor disposition   0x13
descriptor type          0x00
descriptor port          nonzero
PID                      nonzero
CGS server port          nonzero and distinct from the application CGS port
NewWindow compat calls   1
release-backing calls    1
create-alpha calls       1
OrderFront calls         0
AddTrackingArea calls    0
SetFrontWindow calls     0
```

Snow has different ordering: its one successful legacy ColorProfileClient initialization is observed at `M20_BEFORE_CreateNewWindow`, before the NewWindow/release/create-alpha calls. Snow therefore runs the compatibility-capable interposer strictly in `passthrough` mode and is required to preserve that earlier successful transaction without using Lion's ordering predicate.

The adapter copies the request to private storage and changes only the request ID `0x74d4 -> 0x74d6`. The source request, descriptor, PID, and all body bytes must remain unchanged.

For a native Lion reply, the adapter accepts only reply ID `0x753a` with the established simple-reply bits. A success reply must be size `0x28`, raw result zero, and return a nonzero client ID; an error reply must be size `0x24` with a nonzero raw result. The adapter changes only `0x753a -> 0x7538` before returning to the PPC client and preserves the complete reply body, including result and client-ID bytes.

A second exact legacy ColorProfileClient request is not adapted by this stage. If the first conversion succeeds but the client still retries, the runner reports `POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_RETRY_AFTER_ADAPTER`; stop and preserve that run rather than broadening the predicate.

## Safety constraints

- Reuse the accepted `cps-showwindow-validation-v1` subject unchanged.
- Reuse the exact-six distributed-notifications broker unchanged.
- Reuse the accepted Security, HIToolbox Extras, DockServer, FontServer rendezvous, NewWindow, release-backing, create-alpha, AddTrackingArea, OrderFrontConditionally, and SetFrontWindow paths unchanged.
- Do not synthesize a color-profile client ID.
- Do not modify the descriptor, PID, NDR/body fields, result, or client-ID bytes.
- Do not force `CGSColorProfileCreateWithColorProfileID`, `_CGSWindowColorProfile`, `CGWindowContextCreate`, ColorSync, CoreUI, RawCamera, or later rendering calls to succeed.
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

## Phase B — build the compatibility interposer on Snow Leopard

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat-on-snowleopard.sh || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat-on-snowleopard.sh || exit 1
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.sha256
```

Require a 32-bit PPC dylib, exactly two `__interpose` tuples, embedded distributed-notifications ingress v2, and build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat-v2
```

Stop if build, architecture, marker, or hash validation fails.

## Phase C — Snow Leopard behavior-preserving control

Use the same accepted Snow restored stack and enable only the new ColorProfileClient compatibility mode as passthrough:

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

/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat-snowleopard-control.log || exit 1
```

Require exactly one ColorProfileClient compatibility call with `mode=passthrough`, `exact=YES`, `lionPortExact=NO`, and `applicationPort=0x00000000`, with the logged NewWindow/release-backing/create-alpha/OrderFront/AddTrackingArea/SetFrontWindow compatibility counts all still zero at that Snow call, no adapter PASS marker, and the established Snow transaction unchanged:

```text
request                    0x74d4
reply                      0x7538
reply size                 0x28
result                     0
client ID                  nonzero
S01_AFTER_ShowWindow       reached
SHOWWINDOW_PASS            reached
DisposeWindow / M24        complete
RESULT                     POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_SNOW_CONTROL_PASS
RESULT                     PASS
```

Stop if the compatibility-capable interposer changes Snow behavior.

## Phase D — transfer the compatibility artifact

Transfer from Snow Leopard to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat-snowleopard-control.log
```

Place the dylib, `.info.txt`, and `.sha256` under Lion's `payload/` directory and the Snow control log at the runtime root. Verify the transferred dylib against its SHA-256 sidecar before execution.

## Phase E — repeat syscall 295 on Lion

Use the accepted i386 probe and unchanged kernel SHA:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash -n "$ROSETTA_XNU/tools/run_syscall295_probe.sh" || exit 1

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/syscall295-probe-process-manager-post-windowtitle-showwindow-color-profile-client-compat.log" || exit 1
```

Require the established kernel SHA, `result=-1 errno=9 saw_sigsys=0`, exit status 0, and `RESULT: PASS`.

## Phase F — exactly one Lion compatibility integration

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

/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat.log
```

Do not run the Lion subject a second time.

## Decision gate

### ColorProfileClient adapter succeeds

The leading expected result is one exact compatibility call at the first Lion ShowWindow color-profile attempt, with `lionPortExact=YES`, a nonzero learned application-CGS port distinct from the ColorProfileClient remote port, NewWindow/release-backing/create-alpha compatibility counts equal to 1, and OrderFront/AddTrackingArea/SetFrontWindow counts equal to 0:

```text
legacy request             0x74d4
adapted native request     0x74d6
request changed bytes      1
request body changes       0
native Mach return         0
native reply               0x753a
native success size        0x28
native result              0
native client ID           nonzero
legacy-facing reply        0x7538
reply changed bytes        1
reply body changes         0
adapter result             PASS
```

If `ShowWindow` then returns and the subject reaches `SHOWWINDOW_PASS` and M24, this compatibility boundary is complete. The runner will report `POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_INTEGRATION_PASS`; the next investigation should start only from whatever new post-ShowWindow boundary is actually exposed.

If the adapter succeeds but `ShowWindow` still does not return, preserve the first run. The runner will report `POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`. Analyze the first new downstream diagnostic or exact CGS transaction after the successful ColorProfileClient reply; do not broaden this adapter speculatively.

### Native Lion ColorProfileClient returns an error

If the adapted `0x74d6` request receives a well-formed native `0x753a / 0x24` error, the adapter maps only the reply ID back to `0x7538` and preserves the error body. The runner reports `POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_NATIVE_ERROR_PRESERVED`. Stop and investigate that native error rather than forcing success.

### Predicate, transport, or reply shape differs

Stop. Preserve the single run and all named diagnostics. Do not relax the request predicate, synthesize a client ID, or change reply semantics until the mismatch is understood.

## Return

Return these six primary artifacts:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-color-profile-client-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-color-profile-client-compat.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the dylib itself unless specifically requested.

## Current boundary

```text
SetFrontWindow                               accepted adapter PASS
ColorProfileClient Snow PPC                 0x74d4 / 0x7538, result 0, client ID nonzero; v2 structural exact
ColorProfileClient Lion legacy live         0x74d4 / 0x7538, transport success, raw -304
ColorProfileClient Lion native helper       0x74d6 / 0x753a
wire geometry                               equivalent; exact ID-only conversion authorized
next step                                   one exact ColorProfileClient compatibility integration
CGWindowContext/CoreUI/RawCamera            downstream/held
CGSShapeWindow                              held
XNU                                         no change indicated
```


## Completed v2 integration result — 2026-10-12

The rebuilt Snow Leopard v2 control passed. It observed exactly one legacy ColorProfileClient compatibility call in strict `passthrough` mode, preserved the successful `0x74d4 -> 0x7538 / 0x28` transaction with result 0 and a nonzero client ID, reached `S01_AFTER_ShowWindow`, completed disposal, and ended with both the ColorProfileClient Snow-control PASS marker and `RESULT: PASS`.

The Lion syscall-295 preflight also passed with the accepted kernel SHA: syscall 295 returned `-1 / errno=9` with no SIGSYS and the probe exited 0.

The single Lion compatibility run then satisfied the exact v2 predicate. The first legacy ColorProfileClient request had `exact=YES`, `lionPortExact=YES`, a distinct nonzero server port, NewWindow/release/create-alpha call counts of 1, and OrderFront/AddTrackingArea/SetFrontWindow counts of 0. The adapter changed only request ID `0x74d4 -> 0x74d6`; Lion returned native `0x753a / 0x28`, result 0, with a nonzero client ID; the adapter changed only reply ID `0x753a -> 0x7538` and returned the body unchanged. The adapter reported PASS. No second ColorProfileClient compatibility call occurred, so the earlier repeated client-initialization retries are eliminated.

The first-order failure has moved downstream. Immediately after the successful PPC-facing `0x7538 / 0x28` reply, CoreGraphics now reports `CGSColorProfileCreateWithColorProfileID: Cannot resolve color profile id(1)`, followed by the invalid-window-profile and window-context failure cascade. The accepted OrderFrontConditionally, AddTrackingArea, unchanged `0x7268 / 0x72cc`, SetFrontWindow, exact-six notification broker, FontServer, and upstream compatibility paths remain successful; protected hashes remain unchanged. `S01_AFTER_ShowWindow` is still absent and the process exits 139, producing the named crash/plist/core diagnostics. The runner correctly classifies the result as `POST_WINDOWTITLE_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`.

Existing static CoreGraphics evidence shows that `CGSColorProfileCreateWithColorProfileID` calls `__CGSResolveColorProfile` after successful ColorProfileClient initialization on both Snow Leopard and Lion. Therefore the ColorProfileClient compatibility rule is complete and must not be broadened. The authoritative next gate is the read-only [ColorProfile resolve protocol audit](process-manager-post-windowtitle-showwindow-color-profile-resolve-protocol-audit.md). It compares the Snow PPC and Lion i386 `__CGSResolveColorProfile` client helper and corresponding server-side resolve/release family before any new live trace or adapter is authorized. No XNU change, kernel rebuild, or reboot is indicated.
