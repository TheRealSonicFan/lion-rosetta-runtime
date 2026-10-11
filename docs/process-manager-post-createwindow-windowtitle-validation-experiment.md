# Process Manager restored-stack post-CreateNewWindow window-title validation experiment

## Objective

Advance exactly one application-level operation beyond the now-complete restored-stack `CreateNewWindow` construction gate.

The accepted Lion run now proves:

```text
NewWindow ID-only adapter                  native success
release-backing ID-only adapter            native success
opacity create-alpha ID-only adapter       native success
CreateNewWindow                            0
WindowRef                                  nonzero
DisposeWindow                              returned
M24_SUCCESS                                reached
process exit                               0
new crash/core diagnostic                  none
protected hashes                           unchanged
```

Several CoreGraphics diagnostics still appear internally during the successful `CreateNewWindow` call, including display-bounds, ShapeWindow, backing-map/lock, and display-color-space errors. They are not the next authorized compatibility targets because the public construction API now returns success and the current subject immediately disposes the object.

The historical Carbon GUI flow performs `CFStringCreateWithCString` and then `SetWindowTitleWithCFString` before `ShowWindow`. Command-line CoreFoundation string creation was already validated earlier, so this experiment uses that operation only to supply a title and makes `SetWindowTitleWithCFString` the first new window-object discriminator. It then releases the string and disposes the window. It does not show, select, query visibility, install a timer, or enter the application event loop.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-windowtitle.c
scripts/build-ppc-process-manager-windowtitle-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Subject build ID:

```text
cps-windowtitle-validation-v1
```

Required executable basename remains:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

Do not rename it. The accepted CPS registration adapter remains intentionally predicate-gated to that exact basename.

Runner validation modes:

```text
Snow  ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
Lion  ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
```

No compatibility-interposer source change is part of this experiment. Reuse the already accepted combined CoreServices dylib whose build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-v1
```

## Subject sequence

The subject preserves the complete accepted Process Manager path:

```text
GetProcessForPID(getpid())
GetProcessPID
TransformProcessType(...foreground...)
SetFrontProcess
GetFrontProcess
GetCurrentProcess
CreateNewWindow
```

After requiring `CreateNewWindow == 0` and a nonzero WindowRef, it performs only:

```text
T00_BEFORE_CFStringCreateWithCString
CFStringCreateWithCString("Rosetta PPC Restored Stack")
T01_AFTER_CFStringCreateWithCString
require nonzero CFStringRef
T02_BEFORE_SetWindowTitleWithCFString
SetWindowTitleWithCFString(window, title)
T03_AFTER_SetWindowTitleWithCFString
require OSStatus == 0
T04_BEFORE_CFRelease
CFRelease(title)
T05_AFTER_CFRelease
DisposeWindow
M24_SUCCESS
```

Success marker:

```text
PM_POSTWINDOWTITLE_RESULT:SETWINDOWTITLE_PASS
```

## Safety constraints

- Build only the new PPC subject on Snow Leopard 10.6.8.
- Keep the exact executable basename required by the existing registration predicate.
- Reuse the accepted CoreServices, Security, Dock bootstrap, HIToolbox Extras, Snow `Extras.rsrc`, and exact-four notification broker artifacts unchanged.
- Keep the accepted NewWindow, release-backing, and opacity create-alpha adapters unchanged.
- Snow compatibility modes remain strict passthrough.
- Repeat the established syscall-295 gate on Lion.
- Keep all old passive-trace modes unset.
- Do not call `ShowWindow`, `SelectWindow`, `IsWindowVisible`, timer APIs, or `RunApplicationEventLoop`.
- Do not adapt terminate-alpha, display-bounds, ShapeWindow, backing-map/lock, or display-color-space traffic in this run.
- Do not patch CoreGraphics, HIToolbox, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, launchd, or XNU.
- Do not restart or signal WindowServer or launchd jobs.
- Run the Lion validation exactly once before review.
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

## Phase B — build only the window-title subject on Snow Leopard

Because the new subject must retain the exact registration-predicate basename, preserve any prior copy you still need before building.

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-windowtitle-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-windowtitle-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Require:

```text
build ID                         cps-windowtitle-validation-v1
architecture                     32-bit PPC
LC_LOAD_DYLINKER                 /usr/oah/dyld
imports                          existing Process Manager/CreateNewWindow calls
imports                          CFStringCreateWithCString
imports                          SetWindowTitleWithCFString
imports                          CFRelease
imports                          DisposeWindow
all T00..T05 markers             present
SETWINDOWTITLE_PASS marker       present
```

Stop if Phase B fails. Do not rebuild any accepted compatibility dylib.

## Phase C — Snow Leopard full passthrough control

Unset all passive trace modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check and run the existing full-stack Snow control using the accepted opacity create-alpha compatibility dylib:

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
  ./ppc-process-manager-post-createwindow-windowtitle-snowleopard-control.log
```

Hard gate:

```text
all accepted compatibility calls          passthrough / exact
CreateNewWindow                            0
WindowRef                                  nonzero
CFStringRef                                nonzero
SetWindowTitleWithCFString                 0
SETWINDOWTITLE_PASS                        reached
CFRelease                                  completed
DisposeWindow                              completed
M24_SUCCESS                                reached
RESULT: POST_CREATEWINDOW_WINDOWTITLE_SNOW_CONTROL_PASS
RESULT: PASS
```

Stop if Phase C fails.

## Phase D — transfer the exact new subject to Lion

Transfer:

```text
payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-post-createwindow-windowtitle-snowleopard-control.log
```

Do not rebuild the PPC subject on Lion. Reuse all accepted compatibility artifacts unchanged.

## Phase E — repeat syscall 295 on Lion

Run the established native routing probe and save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-validation.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion restored-stack window-title validation

Unset passive and obsolete audit modes:

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
  ./payload/lion-ppc-process-manager-post-createwindow-windowtitle-validation.log
```

Require all accepted upstream gates to remain true through create-alpha native success and `CreateNewWindow=0` with a nonzero WindowRef.

Then require:

```text
T00_BEFORE_CFStringCreateWithCString       reached
T01_AFTER_CFStringCreateWithCString        reached
CFStringRef                                nonzero
CFSTRING_PASS                              reached
T02_BEFORE_SetWindowTitleWithCFString      reached
T03_AFTER_SetWindowTitleWithCFString       reached
SetWindowTitleWithCFString                 0
SETWINDOWTITLE_PASS                        reached
T04_BEFORE_CFRelease                       reached
T05_AFTER_CFRelease                        reached
DisposeWindow                              completed
M24_SUCCESS                                reached
process exit                               0
new diagnostics                            none
protected hashes                           unchanged
RESULT: POST_CREATEWINDOW_WINDOWTITLE_VALIDATION_PASS
```

The runner has explicit classifications for a CFString no-return/failure, SetWindowTitle not reached/no-return/error, and incomplete CFRelease. Stop on the first such result and preserve all diagnostics.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-post-createwindow-windowtitle-snowleopard-control.log
syscall295-probe-process-manager-post-createwindow-windowtitle-validation.log
lion-ppc-process-manager-post-createwindow-windowtitle-validation.log
lion-ppc-process-manager-post-createwindow-windowtitle-validation.raw.log
```

Also return every new crash/core diagnostic named by the runner. Stop after Phase G.

## Decision gate

### `POST_CREATEWINDOW_WINDOWTITLE_VALIDATION_PASS`

The returned WindowRef is usable for the first historical post-construction window operation. Keep all current compatibility adapters unchanged. The next gate should advance only to `ShowWindow`, not directly to SelectWindow, visibility checks, or the event loop.

### SetWindowTitle no-return or error

The title operation is the first newly observed failing boundary. Preserve its exact diagnostics and transport context before authorizing any new compatibility logic.

### CFString failure

Treat it as a CoreFoundation regression because command-line CoreFoundation had already passed. Do not infer a window protocol defect.

### Residual CreateNewWindow CoreGraphics diagnostics only

If the same display-bounds/ShapeWindow/backing/display-color-space messages recur but SetWindowTitle succeeds, continue to classify them as non-blocking for this stage. Do not adapt them solely because they are logged.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
Process Manager identity / foreground            -> PASS
distributed-notification + HIToolbox + Dock      -> PASS
NewWindow / release-backing / create-alpha       -> native Lion success
CreateNewWindow public API                       -> PASS
immediate DisposeWindow                          -> PASS
next step                                        -> SetWindowTitleWithCFString only
```

No additional XNU change is indicated.


## Observed Lion result — FontServer bootstrap is the first window-title boundary

The Snow Leopard full-stack control passed the complete title sequence. After `T02_BEFORE_SetWindowTitleWithCFString`, Snow loaded `libFontRegistry.dylib`, performed ordinary `bootstrap_look_up("com.apple.FontServer")`, received `kr=0` with a nonzero service port, returned from `SetWindowTitleWithCFString` with status 0, released the title, disposed the window, and reached `M24_SUCCESS`.

The Lion run preserves every accepted upstream gate: the subject hash matches, syscall 295 remains EBADF/no-SIGSYS, CreateNewWindow returns 0 with a nonzero WindowRef, and `CFStringCreateWithCString` returns a nonzero object. Lion then reaches `T02_BEFORE_SetWindowTitleWithCFString` and loads the same FontRegistry component, but its first newly divergent operation is:

```text
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH:reason=NON_TARGET ... name=com.apple.FontServer
PM_CGS_SESSION_BOOTSTRAP_COMPAT_PASSTHROUGH_RETURN:kr=-304 hex=0xfffffed0 servicePort=0x00000000
```

This occurs before the fifth distributed-notification request. That later request has payload length 321 and is rejected with status 25 by the deliberately exact-four broker; the broker summary becomes `register=4 ... rejects=1 exact=NO`. The run then repeatedly retries the failing FontServer lookup, CoreText reports invalid font-server IPC destinations, `T03_AFTER_SetWindowTitleWithCFString` is never reached, the subject exits 138, and the runner names a new crash report plus `/cores/core.44137`. Protected hashes remain unchanged.

The returned top-level label `CREATENEWWINDOW_POST_EXTRAS_REGISTRATION_PROTOCOL_REJECTED` was therefore too coarse for this new post-CreateNewWindow stage: it classified the later broker rejection before the earlier title-specific boundary. The Lion runner has been corrected so the same evidence would classify as:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_BOOTSTRAP_MINUS304
```

Do not broaden the notification allowlist yet. The first Snow/Lion divergence is the exact `com.apple.FontServer` bootstrap lookup.

The authoritative next stage is:

```text
docs/process-manager-post-createwindow-fontserver-bootstrap-protocol-adapter-experiment.md
```

It is standalone. It requires an ordinary Snow `com.apple.FontServer` lookup to return a nonzero port, then sends exactly one already-established Lion-format launchd lookup request for the same service with request ID `0x194`, send size `0xbc`, PID 0, zero UUID, flags 0, and expected reply ID `0x1f8`. It does not rerun the window-title subject, accept the fifth notification, or alter any accepted CreateNewWindow adapter. No XNU change is indicated.
