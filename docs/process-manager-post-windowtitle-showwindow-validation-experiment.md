# Post-window-title ShowWindow validation experiment

## Objective

The first translated-PPC FontServer rendezvous compatibility rule has now passed live under Lion and `SetWindowTitleWithCFString` returns success. The next controlled discriminator is exactly one `ShowWindow(window)` call on that same returned `WindowRef`.

This experiment does not add any new compatibility rule. It preserves the accepted Process Manager, CoreGraphics, HIToolbox, distributed-notification, FontServer bootstrap, and FontServer rendezvous paths unchanged and asks only whether the already-created, titled Carbon window can cross the visibility transition.

Do not combine this step with `SelectWindow`, `IsWindowVisible`, timer APIs, or `RunApplicationEventLoop`.

## Closed prerequisite

The reviewed Lion rendezvous integration produced:

```text
FontServer bootstrap adapter                         PASS
legacy rendezvous request                            0x32c8 / 0x18 / 0x3c
native rendezvous request                            0x32e7 / receive 0x40
native reply                                         0x334b / complex 0x38
protocol version                                     5
legacy-facing adapted reply                          0x332c / complex 0x34
descriptor / NDR                                     preserved
explicit size                                        0x1000 preserved
FontServer rendezvous adapter                        PASS
FontServer RPC count                                 1
SetWindowTitleWithCFString                           0
SETWINDOWTITLE_PASS                                  reached
DisposeWindow / M24                                  complete
new diagnostics                                      none
protected hashes                                     unchanged
RESULT                                               POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_INTEGRATION_PASS
```

No later FontServer RPC occurred in that successful title run. Therefore there is no additional FontServer operation to audit before advancing to `ShowWindow`.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-windowtitle.c
scripts/build-ppc-process-manager-showwindow-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

The new subject build ID is:

```text
cps-showwindow-validation-v1
```

The required basename remains unchanged:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
```

This is required by the already-reviewed Process Manager registration predicate.

The only new subject operation is inserted after successful title assignment and before `CFRelease(title)`:

```text
S00_BEFORE_ShowWindow
ShowWindow(window)
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
```

The subject then releases the title and disposes the window exactly as before.

## Safety constraints

- Build the new PPC subject only on Snow Leopard 10.6.8.
- Preserve the exact output basename.
- Reuse the accepted CoreServices compatibility dylib, Security dylib, HIToolbox Extras compatibility dylib/resource, FontServer rendezvous v5 dylib, and exact-five native notification broker unchanged.
- Run one Snow positive control before Lion.
- Repeat syscall 295 on Lion before the Lion run.
- Run exactly one Lion ShowWindow attempt before review.
- Keep `SelectWindow`, `IsWindowVisible`, timer APIs, and the event loop out of this subject.
- Do not add a ShowWindow/CGS compatibility adapter or broaden Mach tracing in this run.
- Do not change the FontServer rendezvous predicate.
- Do not add a sixth distributed-notification registration.
- Do not restart or signal WindowServer, fontd, distnoted, launchd, or any other service.
- Do not patch CoreGraphics, HIToolbox, CoreText, ATS, Rosetta, dyld, caches, or XNU.
- Preserve any new crash/core diagnostic named by the runner.
- No XNU rebuild or reboot.

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

## Phase B — build only the new ShowWindow subject on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-showwindow-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-showwindow-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Require:

```text
build ID                              cps-showwindow-validation-v1
architecture                          thin 32-bit PPC
LC_LOAD_DYLINKER                      /usr/oah/dyld
ShowWindow import                     present
S00 marker                            present
S01 marker                            present
SHOWWINDOW_PASS marker                present
```

Do not rebuild the accepted compatibility dylibs.

## Phase C — Snow Leopard positive control

Unset unrelated passive trace modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
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

Run:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-snowleopard-control.log
```

Require:

```text
title path                              PASS
FontServer rendezvous                  passthrough exactly once
S00_BEFORE_ShowWindow                  reached
S01_AFTER_ShowWindow                   reached
SHOWWINDOW_PASS                        reached
CFRelease                              complete
DisposeWindow / M24                    complete
control_status                         0
RESULT                                 POST_WINDOWTITLE_SHOWWINDOW_SNOW_CONTROL_PASS
RESULT                                 PASS
```

Stop if Snow does not remain behavior-preserving.

## Phase D — transfer only the new subject and Snow evidence

Transfer to Lion:

```text
payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-post-windowtitle-showwindow-snowleopard-control.log
```

Reuse the accepted compatibility artifacts and broker unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-validation.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion ShowWindow run

Unset unrelated audit/passive modes:

```sh
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-windowtitle-fontserver-register-v1
```

Syntax-check and run exactly once:

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
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-validation.log
```

The accepted upstream chain must remain intact through:

```text
Process Manager registration / SetFrontProcess       PASS
CreateNewWindow                                      PASS
NewWindow / release-backing / create-alpha adapters PASS
FontServer bootstrap                                 PASS
first rendezvous adapter                             PASS exactly once
fifth notification registration                     accepted
SetWindowTitleWithCFString                           0
SETWINDOWTITLE_PASS                                  reached
```

Then evaluate only the new boundary.

### ShowWindow returns

Require:

```text
PM_POSTWINDOWSHOW_MILESTONE:S00_BEFORE_ShowWindow
PM_POSTWINDOWSHOW_MILESTONE:S01_AFTER_ShowWindow
PM_POSTWINDOWSHOW_RESULT:SHOWWINDOW_PASS
PM_POSTWINDOWTITLE_MILESTONE:T04_BEFORE_CFRelease
PM_POSTWINDOWTITLE_MILESTONE:T05_AFTER_CFRelease
PM_POSTIDENTITY_MILESTONE:M24_SUCCESS
new diagnostics                                      none
protected_hashes_unchanged                           YES
RESULT: POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_PASS
```

This closes the ShowWindow gate. Do not immediately add `SelectWindow`; review the complete result first.

### S00 appears but S01 does not

Expected classification:

```text
RESULT: POST_WINDOWTITLE_SHOWWINDOW_NO_RETURN
```

Preserve the full report/raw log and any diagnostic. Do not add a compatibility rule from this result alone. The next stage would be a ShowWindow-specific passive transport trace.

### S00 does not appear

Expected classification:

```text
RESULT: POST_WINDOWTITLE_SHOWWINDOW_NOT_REACHED
```

Treat this as an upstream regression and do not investigate ShowWindow internals yet.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
ppc-process-manager-post-windowtitle-showwindow-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-validation.log
lion-ppc-process-manager-post-windowtitle-showwindow-validation.log
lion-ppc-process-manager-post-windowtitle-showwindow-validation.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner if available. Do not upload the subject executable itself. Stop after this run.

## Current boundary

```text
CreateNewWindow                              -> PASS
SetWindowTitleWithCFString                   -> PASS
FontServer rendezvous compatibility          -> PASS live
FontServer RPCs required by title            -> exactly one
ShowWindow                                   -> next isolated discriminator
SelectWindow / visibility / event loop       -> held
XNU                                          -> no change indicated
```


## Observed result — sixth distributed-notification boundary precedes ShowWindow return

The Snow control passed: the exact subject reached `S01_AFTER_ShowWindow`, emitted `SHOWWINDOW_PASS`, completed release/disposal, and returned 0.

The first Lion run preserved all accepted upstream compatibility through title assignment and entered `ShowWindow` at `S00_BEFORE_ShowWindow`, but did not reach `S01_AFTER_ShowWindow`. Before return, the ingress bridge observed a sixth legacy distributed-notification request:

```text
index                    6
bits                     0x00001111
id                       4
Mach size                320
payload                  287
exact-five broker status 20
```

The exact-five broker classified that request as a schema reject, then reported `register=5 callback=0 rejects=1 exact=NO`. The subject exited 139 and Lion named a crash report plus core. Protected hashes remained unchanged. The single FontServer rendezvous adapter still passed and no additional FontServer RPC was introduced.

This explicit sixth-request rejection is a narrower controlled boundary than the generic ShowWindow no-return classification. Do not begin a broad ShowWindow/CGS passive trace yet, and do not infer a sixth registration schema from status 20. The authoritative next procedure is:

```text
docs/process-manager-post-windowtitle-showwindow-sixth-distributed-notification-schema-audit.md
```

That stage reuses the accepted ShowWindow subject and compatibility artifacts unchanged, captures exactly the sixth 287-byte payload as binary plist plus XML, deliberately preserves status 20, and stops for review. No XNU change is indicated.
