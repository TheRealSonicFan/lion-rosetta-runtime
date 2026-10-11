# Post-CreateNewWindow window-title FontServer RPC transport trace experiment

## Objective

Identify the first failing legacy FontServer RPC after the exact `com.apple.FontServer` bootstrap lookup and the exact fifth distributed-notification registration both succeed.

The current live boundary is now:

```text
CreateNewWindow                                      -> PASS
CFStringCreateWithCString                            -> PASS
SetWindowTitleWithCFString                           -> entered
FontServer bootstrap lookup                          -> PASS, valid send right
fifth notification registration                      -> accepted exactly
sixth notification request                           -> not observed
CoreText CopyFontForName                             -> repeated FFFFFED0
CoreText CopyPropertiesForFontsMatchingRequest       -> FFFFFED0
T03_AFTER_SetWindowTitleWithCFString                  -> not reached
broker summary                                       -> register=5, rejects=0, exact=YES
```

`FFFFFED0` is `-304`, the same MIG bad-arguments class already seen at earlier Snow-to-Lion protocol boundaries. The current log does not expose the FontServer request ID, send/receive sizes, Mach header, reply ID/size, or exact request body. No FontServer RPC adapter is authorized until that transport is observed directly.

The crash report and core named by the previous run were not supplied with the result. They are downstream of the repeated FontServer RPC failures and are not required for this passive transport discriminator. Preserve them if available.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c
scripts/build-ppc-process-manager-cgs-dockserver-fontserver-bootstrap-rpc-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-createwindow-windowtitle-fontserver-rpc-transport-trace-experiment.md
```

Trace build ID:

```text
cgs-session-bootstrap-dockserver-fontserver-compat-rpc-trace-v4
```

The trace build contains exactly two PPC `__DATA,__interpose` tuples:

```text
bootstrap_look_up
mach_msg
```

The bootstrap behavior is unchanged from the accepted v3 interposer. The new `mach_msg` tuple is passive. It records only messages whose remote port equals the exact FontServer service port learned by the successful `com.apple.FontServer` lookup.

Trace modes:

```text
Snow  ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=snow-passive-v1
Lion  ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
```

For each targeted FontServer RPC the tracer records:

```text
request index
request ID
remote port
msgh_bits
observed header msgh_size
mach_msg options
authoritative send size argument
receive size argument
receive port
timeout / notify
request bytes, capped at 0x400 bytes with explicit truncation marker
mach_msg return
reply bits / size / ID when Mach transport succeeds
reply word 0x20 for simple replies >= 0x24 bytes
reply bytes, capped at 0x400 bytes
```

Nothing is rewritten.

## Safety constraints

- Build only the trace variant on Snow Leopard 10.6.8.
- Reuse the accepted PPC window-title subject unchanged.
- Reuse the accepted CoreServices, Security, HIToolbox Extras/resource, NewWindow, release-backing, opacity create-alpha, and exact-five notification broker artifacts unchanged.
- Snow must use strict Dock and FontServer bootstrap passthrough.
- Snow must complete `SetWindowTitleWithCFString=0`, CFRelease, DisposeWindow, and M24 while the tracer is loaded.
- Repeat syscall 295 on Lion before the Lion trace run.
- Lion must retain the accepted FontServer bootstrap adapter and exact-five notification broker.
- Trace only; do not alter a FontServer request, reply, port, message ID, size, body, timeout, or return value.
- Do not add a sixth notification allowlist entry.
- Do not infer a FontServer RPC mapping from the CoreText error string alone.
- Do not patch CoreText, ATS, FontRegistry, FontServer/fontd, CoreGraphics, HIToolbox, distnoted, launchd, Rosetta, dyld, caches, or XNU.
- Do not restart or signal any system service.
- Do not show/select/query the window or enter the event loop.
- Run one Snow control and exactly one Lion trace before review.
- Preserve every new crash/core diagnostic named by the Lion runner.
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

## Phase B — build only the FontServer RPC trace variant on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-cgs-dockserver-fontserver-bootstrap-rpc-trace-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-cgs-dockserver-fontserver-bootstrap-rpc-trace-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.sha256
```

Require:

```text
architecture                         thin 32-bit PPC
build ID                             cgs-session-bootstrap-dockserver-fontserver-compat-rpc-trace-v4
__interpose size                     0x10, exactly two PPC tuples
bootstrap_look_up import             present
mach_msg import                      present
FontServer bootstrap marker          present
FontServer RPC request marker        present
FontServer RPC reply marker          present
```

Stop if Phase B fails.

## Phase C — Snow Leopard full title positive control with passive FontServer RPC trace

Unset older CGS trace modes:

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
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=snow-passive-v1
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
  ./ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.sha256 \
  ./ppc-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace-snowleopard-control.log
```

Require:

```text
FontServer ordinary lookup                    kr=0, nonzero port
FontServer bootstrap adapter                  not used
RPC trace port marker                         present
RPC request index 1                           present, mode=snow-passive-v1
RPC Mach return index 1                       present
RPC reply index 1                             present
request and reply hex                         present
SetWindowTitleWithCFString                    0
SETWINDOWTITLE_PASS                           reached
CFRelease / DisposeWindow / M24               complete
RESULT                                        POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_SNOW_CONTROL_PASS
RESULT                                        PASS
```

Preserve the complete trace, including every FontServer RPC before T03. Stop if the Snow control does not remain behavior-preserving.

## Phase D — transfer only the new trace interposer and Snow control evidence

Transfer:

```text
payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib
payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.info.txt
payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace-snowleopard-control.log
```

Reuse the accepted title subject, CoreServices/Security/HIToolbox artifacts, resource file, and exact-five native broker unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion title run with passive FontServer RPC tracing

Unset older audit/passive modes:

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
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_FONTSERVER_BOOTSTRAP_COMPAT_MODE=lion-fontserver-v1
export ROSETTA_CGS_FONTSERVER_RPC_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_OPACITY_ALPHA_CREATE_COMPAT_MODE=lion-id-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-windowtitle-fontserver-register-v1
```

Keep the established expected kernel hash. Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Then run exactly once:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.sha256 \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker \
  ./native-distributed-notifications-post-createwindow-windowtitle-fontserver-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace.log
```

Require the accepted chain:

```text
CreateNewWindow                                  0, nonzero WindowRef
CFStringCreateWithCString                        PASS
T02                                              reached
FontServer bootstrap adapter                     PASS
fifth notification registration                 accepted exactly
broker                                           register=5, rejects=0, exact=YES
```

Then require at least one targeted FontServer RPC trace:

```text
PM_CGS_FONTSERVER_RPC_TRACE_REQUEST:index=1 mode=lion-passive-v1 ...
PM_CGS_FONTSERVER_RPC_TRACE_REQUEST_HEX:index=1 ...
PM_CGS_FONTSERVER_RPC_TRACE_MACH_RETURN:index=1 ...
```

If Mach transport succeeds, preserve:

```text
PM_CGS_FONTSERVER_RPC_TRACE_REPLY:index=1 ...
PM_CGS_FONTSERVER_RPC_TRACE_REPLY_HEX:index=1 ...
```

Expected classification if T03 is still not reached:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RPC_TRACE_CAPTURED
```

Do not rerun before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-fontserver-bootstrap-rpc-trace.dylib.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace-snowleopard-control.log
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rpc-trace.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner if available. Stop after Phase G.

## Decision gate

### Snow first RPC succeeds; Lion same legacy RPC returns simple `-304`

The active boundary is a FontServer MIG request/reply protocol mismatch. Do not adapt it yet. The next stage is a static Snow-versus-Lion audit of the exact captured request ID/body layout and the corresponding native Lion client/server method.

### Snow and Lion request IDs or sizes differ before the server reply

Preserve the exact ordered traces. Reconcile which caller/method is first in each OS before any adapter design.

### Lion `mach_msg` itself fails

Treat the transport error as the boundary; do not infer a MIG server rejection.

### No targeted RPC is captured

The service-port predicate is incomplete or the failing path uses another endpoint. Do not broaden tracing globally until the exact endpoint is identified.

### Title unexpectedly returns successfully with trace enabled

Preserve the trace and environment. The trace build may have changed timing or ordering; do not advance to ShowWindow until that difference is understood.

## Current boundary

```text
PPC execution / Rosetta                               -> PASS
syscall 295                                           -> PASS
CreateNewWindow                                       -> PASS
FontServer bootstrap                                  -> PASS
distributed notifications 1-5                        -> PASS
SetWindowTitleWithCFString                            -> entered
CoreText FontServer RPC                               -> FFFFFED0 / exact transport unresolved
next step                                             -> passive Snow/Lion FontServer RPC transport trace
```

No additional XNU change is indicated.


## Observed result — first FontServer RPC diverges before CopyFontForName

The completed Snow/Lion passive trace resolves the first transport boundary.

Snow Leopard 10.6.8 sends exactly one FontServer RPC during the title call:

```text
request ID      0x000032c8
bits            0x00001513
send            0x00000018
receive         0x0000003c
mach_msg        0
reply ID        0x0000332c
reply size      0x00000034
reply complex   YES
```

The title then reaches T03, returns `SetWindowTitleWithCFString=0`, completes CFRelease and DisposeWindow, reaches M24, and the control passes.

Lion reaches the same exact `0x32c8 / 0x18 / 0x3c` request first, with successful Mach transport, but receives:

```text
reply ID        0x0000332c
reply size      0x00000024
reply complex   NO
raw word 0x20   bytes 65 fd ff ff
```

The Lion PPC-facing trace later emits raw reply bytes `d0 fe ff ff` for `0x32d9`, while CoreText reports that later status as `FFFFFED0`. Correlating those byte orders establishes the first reply value as `0xfffffd65` / signed `-667`; its semantic name remains unresolved.

Lion retries `0x32c8`, then later sends `0x32d9` and `0x32db`, which receive simple `-304/MIG_BAD_ARGUMENTS` replies, while `0x32cb` receives a complex `0x34` reply. The exact-five notification broker remains successful, all 16 traced FontServer calls return from `mach_msg`, and protected hashes remain unchanged.

Therefore `0x32d9/-304` is not the first FontServer divergence. The first new boundary is the `0x32c8` success-on-Snow versus simple-status-on-Lion result.

The authoritative next stage is:

```text
docs/process-manager-post-createwindow-windowtitle-fontserver-first-rpc-protocol-audit.md
```

That stage is static/read-only. Do not rerun the translated-PPC title path or adapt any FontServer RPC before the shipped Snow and Lion clients/server binaries identify the exact `0x32c8` operation and Lion-native replacement/precondition.
