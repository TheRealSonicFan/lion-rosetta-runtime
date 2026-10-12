# Process Manager post-ShowWindow passive CGS transport trace

## Objective

The exact-six distributed-notification registration gate is closed. Lion accepts all six reviewed registrations, including request 6 as the second `AppleAquaColorVariantChanged` observer with counter 2, and no seventh notification request appears. The unchanged ShowWindow subject still reaches `S00_BEFORE_ShowWindow` but does not reach `S01_AFTER_ShowWindow`; the process exits 139 and generates a crash/core diagnostic.

The raw run also repeats the ShowWindow-side CoreGraphics failure cluster, including:

```text
CGSColorProfileCreateWithColorProfileID: Cannot initialize color profile client
_CGSWindowColorProfile: Invalid color profile id = 0x1
CGWindowContextCreate: failed to create context delegate.
MIG: server type check failure: CGSAddTrackingArea
```

The next controlled question is therefore transport-only: which previously unclassified CGS Mach transactions occur between `S00_BEFORE_ShowWindow` and the return/crash boundary on Snow Leopard and Lion, and which transaction aligns with the `CGSAddTrackingArea` MIG type-check failure?

This stage does **not** adapt any CGS request or reply.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-windowtitle-showwindow-cgs-passive-transport-trace-experiment.md
```

Trace build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace-v1
```

Trace mode:

```text
Snow Leopard  ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
Lion          ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
```

The trace is deliberately narrow and behavior-preserving. It records the application CGS connection port from the already accepted NewWindow transaction, waits until the already accepted create-alpha transaction has been reached, and then logs only previously unclassified send+receive Mach messages sent to that same CGS port. Known server-version, CPS, NewWindow, release-backing, and create-alpha IDs keep their existing paths. Unknown requests are forwarded through the original `mach_msg` unchanged. Request, return, success-reply, and failure-buffer bytes are logged; no byte is rewritten.

The runner counts trace records only inside the ShowWindow call window: after `S00_BEFORE_ShowWindow` and before `S01_AFTER_ShowWindow` when that return marker exists.

## Safety constraints

- Reuse the accepted `cps-showwindow-validation-v1` subject unchanged.
- Reuse the exact-six native notification broker unchanged on Lion.
- Reuse Security, CGS session/DockServer/FontServer rendezvous, HIToolbox Extras, and staged Snow `Extras.rsrc` artifacts unchanged.
- Build only the new PPC CoreServices/distributed-notifications trace dylib on Snow Leopard.
- The trace must remain passive; do not change request IDs, reply IDs, payloads, sizes, ports, or return values.
- Do not add any `CGSAddTrackingArea`, color-profile, window-context, RawCamera, CoreUI, or rendering adapter.
- Do not add a seventh notification policy.
- Do not add `SelectWindow`, `IsWindowVisible`, timers, or an event loop.
- Do not patch system frameworks, Rosetta, dyld, caches, or XNU.
- Do not restart or signal WindowServer, distnoted, fontd, Dock, launchd, or related jobs.
- Preserve every new crash/core diagnostic named by the Lion runner.
- Perform exactly one Lion trace run before review.

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

## Phase B — build only the passive CGS trace dylib on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.sha256
```

Require thin 32-bit PPC, exactly two `__interpose` tuples, the trace build ID above, the embedded distributed-notifications ingress v2 marker, all accepted compatibility markers, and these new markers:

```text
PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST:
PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST_HEX:
PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN:
PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_FAILURE_BUFFER_HEX:
PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REPLY_HEX:
```

Stop if the build gate fails.

## Phase C — Snow Leopard positive control with passive trace

Unset unrelated trace/audit modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
```

Set the accepted Snow stack plus the passive trace:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
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
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace-snowleopard-control.log
```

Require:

```text
title path                                      PASS
FontServer rendezvous                          passthrough exactly once
S00_BEFORE_ShowWindow                          reached
one or more unknown CGS trace requests         between S00 and S01
trace request/return counts                    equal
S01_AFTER_ShowWindow                           reached
SHOWWINDOW_PASS                                reached
DisposeWindow / M24                            complete
control_status                                 0
RESULT                                         POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_SNOW_CONTROL_PASS
RESULT                                         PASS
```

Stop if Snow behavior changes or the trace does not observe the ShowWindow call window.

## Phase D — transfer only the new trace evidence to Lion

Transfer:

```text
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.info.txt
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace-snowleopard-control.log
```

Reuse the existing ShowWindow subject, exact-six native broker, Security interposer, CGS FontServer-rendezvous interposer, HIToolbox Extras compatibility dylib, and staged `SnowLeopard-HIToolbox-Extras.rsrc` unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-passive-trace.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion passive trace run

Unset schema-audit and superseded trace modes:

```sh
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
```

Set the accepted Lion stack plus the passive trace:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
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

Syntax-check the runner:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Then run exactly once:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace.log
```

The accepted upstream chain must remain unchanged:

```text
CreateNewWindow                              PASS
SetWindowTitleWithCFString                   PASS
FontServer rendezvous                       adapter PASS exactly once
sixth notification                          accepted, counter=2
registration summary                        register=6 rejects=0 exact=YES
S00_BEFORE_ShowWindow                       reached
protected hashes                            unchanged
```

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_CAPTURED`

This is the expected result if ShowWindow still does not return. Require one or more `PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_REQUEST` records after S00 and a matching number of `PM_CGS_SHOWWINDOW_UNKNOWN_TRACE_MACH_RETURN` records. Preserve the full request/reply/failure-buffer hex and every new crash/core diagnostic.

Stop. Compare the Snow and Lion S00-to-S01/crash transactions before authorizing any adapter. The immediate analysis target is the transaction adjacent to the Lion `MIG: server type check failure: CGSAddTrackingArea` diagnostic.

### `POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_SHOWWINDOW_PASS`

If the passive trace run unexpectedly reaches S01, `SHOWWINDOW_PASS`, disposal/M24, exits 0, and creates no diagnostic, ShowWindow itself is closed. Stop before adding `SelectWindow`.

### `POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_NOT_REACHED`

No unknown application-CGS transaction was observed after S00. Do not infer a CGS adapter; inspect the returned crash/core and raw diagnostic ordering before changing the trace boundary.

### `POST_WINDOWTITLE_SHOWWINDOW_UNKNOWN_CGS_TRACE_INCOMPLETE`

A traced request did not produce its matching return record. Preserve the crash/core and trace bytes; do not adapt until the exact transport failure is understood.

### Any seventh notification rejection

Do not widen notification policy. Audit the seventh request instead.

## Return

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-unknown-trace.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-passive-trace.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-passive-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner. Do not upload the executable subject or the trace dylib itself unless specifically requested.

## Current boundary

```text
CreateNewWindow                              -> PASS
SetWindowTitleWithCFString                   -> PASS
FontServer rendezvous compatibility          -> PASS live
six reviewed notifications                   -> accepted
seventh notification                         -> not observed
ShowWindow Snow                              -> PASS
ShowWindow Lion                              -> S00 reached, S01 absent
Lion process                                 -> exit 139 + crash/core
repeatable diagnostic                        -> CGSAddTrackingArea MIG server type-check failure
next step                                    -> passive unknown-CGS transport trace
live CGS adaptation                          -> not authorized
XNU                                           -> no change indicated
```
