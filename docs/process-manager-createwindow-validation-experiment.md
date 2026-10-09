# Process Manager restored-stack CreateNewWindow validation experiment

## Objective

Advance beyond the now-restored Process Manager identity/foreground path to the first Carbon window-system operation that historically followed it: `CreateNewWindow`.

The immediately preceding GetCurrentProcess validation now proves on Lion:

```text
CPS application registration              PASS
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType(...foreground...)     PASS
SetFrontProcess                           PASS
GetFrontProcess                           exact PSN match PASS
GetCurrentProcess                         exact PSN match PASS
new diagnostic                            none
protected hashes                          unchanged
RESULT                                    GETCURRENTPROCESS_VALIDATION_PASS
```

The historic Carbon milestone subject originally stopped on Lion inside `GetCurrentProcess`, before `CreateNewWindow` could execute. That identity abort is now absent under the complete restored stack. This stage therefore tests only window object creation and immediate disposal. It does not show/select the window and does not enter an event loop.

## Subject

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-createwindow.c
scripts/build-ppc-process-manager-createwindow-on-snowleopard.sh
```

Build ID:

```text
cps-createwindow-validation-v1
```

Required executable basename:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

The basename remains exact because the accepted CPS registration adapter is deliberately predicate-gated to the known registration string. This experiment does not broaden that predicate.

The subject executes:

```text
GetProcessForPID(getpid())
GetProcessPID(returned PSN)
TransformProcessType(returned PSN, foreground)
SetFrontProcess(returned PSN)
GetFrontProcess(&frontPSN)
require frontPSN == returned PSN
GetCurrentProcess(&currentPSN)
require currentPSN == returned PSN
CreateNewWindow(kDocumentWindowClass,
                kWindowStandardDocumentAttributes |
                kWindowStandardHandlerAttribute,
                bounds,
                &window)
require status == 0 and window != NULL
DisposeWindow(window)
exit
```

The bounds are the same small document-window rectangle used by the historical Carbon milestone probe:

```text
top=120 left=120 bottom=320 right=520
```

## Compatibility stack

Reuse unchanged:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib
```

The combined CoreServices compatibility build remains:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-v1
```

No CreateNewWindow-specific interposer, CGS rewrite, WindowServer workaround, or synthesized window object is introduced.

Snow uses passthrough for all compatibility modes. Lion uses the already accepted modes unchanged:

```text
ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1
ROSETTA_CPS_REGISTRATION_COMPAT_MODE=lion-create-application-v1
ROSETTA_CPS_SETFRONT_COMPAT_MODE=lion-setfront-v1
```

## Success condition

Before window creation, require the complete restored path:

```text
registration adapter                      PASS on Lion
GetProcessForPID                          PASS
GetProcessPID                             exact PID round-trip PASS
TransformProcessType                      PASS
SetFront adapter                          PASS on Lion
SetFrontProcess                           0
GetFrontProcess                           exact PSN match
GetCurrentProcess                         exact PSN match
no second registration call
no second SetFront compatibility call
```

Then require:

```text
M20_BEFORE_CreateNewWindow                reached
M21_AFTER_CreateNewWindow                 reached
CreateNewWindow                           0
window pointer                            nonzero
CREATENEWWINDOW_PASS                      reached
M22_BEFORE_DisposeWindow                  reached
M23_AFTER_DisposeWindow                   reached
M24_SUCCESS                               reached
```

## Safety constraints

- build only the new PPC subject on Snow Leopard 10.6.8;
- reuse every accepted compatibility dylib unchanged;
- require Snow control before Lion;
- keep `LSDONOTABORTIFNOASN` unset;
- call `CreateNewWindow` exactly once;
- dispose the window immediately after successful creation;
- do not call `ShowWindow`, `SelectWindow`, `IsWindowVisible`, `SetWindowTitleWithCFString`, or event-loop/timer APIs;
- do not synthesize a `WindowRef`;
- do not add a CreateNewWindow/WindowServer/CGS compatibility adapter;
- do not broaden the CPS registration or SetFrontProcess predicates;
- do not patch HIToolbox, CoreGraphics, HIServices, WindowServer, Rosetta, dyld, libSystem, the Rosetta cache, or XNU;
- do not restart or signal WindowServer, coreservicesd, securityd, or launchd jobs;
- do not use GDB, DTrace, dtruss, or live injection;
- run Lion exactly once before review.

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

No kernel rebuild or reboot is part of this stage.

## Phase B — build the CreateNewWindow subject on Snow Leopard

Build only the new subject:

```sh
cd /path/to/lion-rosetta-runtime

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-process-manager-createwindow-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Require:

```text
build_id=cps-createwindow-validation-v1
required_basename=ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
architecture=ppc7400
LC_LOAD_DYLINKER=/usr/oah/dyld
imports GetProcessForPID
imports GetProcessPID
imports TransformProcessType
imports SetFrontProcess
imports GetFrontProcess
imports GetCurrentProcess
imports CreateNewWindow
imports DisposeWindow
```

If Phase B fails, stop.

## Phase C — Snow Leopard passthrough control

Keep the accepted compatibility dylibs and SHA sidecars beside the new subject.

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-control.sh
```

Require final `RESULT: PASS` and:

```text
registration compatibility               passthrough
SetFront compatibility                   passthrough
GetProcessForPID                         PASS
GetProcessPID                            exact PID round-trip PASS
TransformProcessType                     PASS
SetFrontProcess                          0
GetFrontProcess                          exact PSN match
GetCurrentProcess                        exact PSN match
CreateNewWindow                          0
window pointer                           nonzero
CREATENEWWINDOW_PASS                     reached
M24_SUCCESS                              reached
```

Phase C is a hard gate.

## Phase D — transfer exact subject to Lion

Transfer:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-createwindow-snowleopard-control.log
```

Reuse unchanged on Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-compat.dylib.sha256
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-security-session-auditinfo-api.dylib.sha256
ppc-process-manager-cgs-session-bootstrap-compat.dylib
ppc-process-manager-cgs-session-bootstrap-compat.dylib.sha256
```

Do not rebuild compatibility dylibs on Lion.

## Phase E — repeat Lion native safety gates

Run the established native commpage probe and preserve the syscall-295 result as:

```text
syscall295-probe-process-manager-createwindow-validation.log
```

Require the established EBADF/no-SIGSYS PASS.

## Phase F — exactly one Lion CreateNewWindow validation

From the logged-in Aqua console user's Lion Terminal:

```sh
cd /path/to/lion-rosetta-runtime

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
  /bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-validation.sh
```

Desired result:

```text
registration adapter                    PASS
GetProcessForPID                        PASS
GetProcessPID                           exact PID round-trip PASS
TransformProcessType                    PASS
SetFront adapter                        PASS
SetFrontProcess                         0
GetFrontProcess                         exact PSN match
GetCurrentProcess                       exact PSN match
M20_BEFORE_CreateNewWindow              reached
M21_AFTER_CreateNewWindow               reached
CreateNewWindow                         0
window pointer                          nonzero
CREATENEWWINDOW_PASS                    reached
DisposeWindow                           returned
M24_SUCCESS                             reached
new diagnostic                          none
protected hashes                        unchanged

RESULT: CREATENEWWINDOW_VALIDATION_PASS
```

Run Phase F once only.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-createwindow-snowleopard-control.log
syscall295-probe-process-manager-createwindow-validation.log
lion-ppc-process-manager-createwindow-validation.log
lion-ppc-process-manager-createwindow-validation.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner.

Stop after Phase G.

## Result interpretation

### `CREATENEWWINDOW_VALIDATION_PASS`

The restored Process Manager path is sufficient to cross the first Carbon window-creation boundary. The next stage may separately test title/show/select/visibility behavior before any event-loop work.

### `CREATENEWWINDOW_NO_RETURN`

Window creation is the next active boundary. Preserve crash/core evidence and stop; audit the exact call path before adding compatibility behavior.

### `CREATENEWWINDOW_RETURNED_ERROR`

The API returns normally with a semantic failure. Preserve the exact OSStatus and stop.

### `CREATENEWWINDOW_NULL_OR_INVALID`

The API reports success or returns but provides no usable window. Preserve the raw state and stop; do not synthesize a window object.

## Current boundary

```text
syscall 295 compatibility                    -> PASS
CoreServices / Security                     -> PASS
SessionUniverse InitConnection v5           -> PASS
session-port compatibility bridge           -> PASS
server-version normalization                -> PASS
default CoreGraphics connection             -> established
CPS registration                            -> accepted
GetProcessPID                               -> PASS
TransformProcessType                        -> PASS
SetFrontProcess integration                 -> PASS
GetFrontProcess                             -> PASS
GetCurrentProcess                           -> PASS
next step                                   -> CreateNewWindow only
ShowWindow / visibility / event loop        -> held until this gate is reviewed
```

No additional XNU change is indicated.


## Observed completed result — CreateNewWindow now reaches a distributed-notifications bootstrap failure

The returned Snow control and Lion validation localize the first post-Process-Manager failure.

Snow:

```text
legacy bootstrap lookup                   com.apple.distributed_notifications.2
pid / flags                               0 / 8
lookup result                             0
service port                              nonzero
CreateNewWindow                           0
WindowRef                                 nonzero
DisposeWindow                             returned
RESULT                                    PASS
```

Lion:

```text
registration / identity / SetFront path   PASS through GetCurrentProcess
M20_BEFORE_CreateNewWindow                reached
legacy bootstrap lookup                   com.apple.distributed_notifications.2
pid / flags                               0 / 8
lookup result                             -304
service port                              0
HIToolbox diagnostic                      failed to copy resource URL
HIToolbox damage code                     -4960
TTheme instance                           0
process termination                       SIGABRT / exit 134
M21_AFTER_CreateNewWindow                 not reached
protected hashes                          unchanged
RESULT                                    CREATENEWWINDOW_NO_RETURN
```

The latest crash report confirms an `EXC_CRASH (SIGABRT)` on the main thread. The visible HIToolbox abort occurs after the exact distributed-notifications bootstrap lookup fails and before `CreateNewWindow` can return.

This changes the active boundary: do not audit or adapt a window-server CreateNewWindow RPC yet. Snow proves the exact old service-name lookup is valid there, while Lion's unchanged PPC `bootstrap_look_up2` path returns the same `-304` class already encountered at the earlier CoreServices launchd lookup boundary.

The authoritative next stage is:

```text
docs/distributed-notifications-bootstrap-compat-protocol-experiment.md
```

That stage does not call `CreateNewWindow`. It uses a standalone PPC lookup probe and the already-proven Lion-format launchd `0x194/0x1f8` formatter to test exactly `com.apple.distributed_notifications.2`, pid 0, flags 8. Only if that standalone policy proof succeeds may the service tuple be integrated into the normal compatibility build and window creation retried.
