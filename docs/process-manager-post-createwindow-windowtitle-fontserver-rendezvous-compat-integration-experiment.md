# Post-CreateNewWindow window-title FontServer rendezvous compatibility integration

## Objective

Integrate only the now-proven first FontServer rendezvous conversion into the existing two-tuple FontServer bootstrap/RPC interposer, while leaving every later FontServer RPC unchanged and passively traced.

The completed no-IPC copied-buffer proof established:

```text
legacy request                    0x32c8
Lion native request               0x32e7
send size                         0x18
legacy receive size               0x3c
Lion receive size                 0x40
request bytes changed             1
request body bytes changed        0
source request bytes changed      0

Lion native success reply         0x334b / complex 0x38
required protocol version         5
legacy success reply              0x332c / complex 0x34
descriptor preserved              YES
NDR preserved                     YES
explicit size relocated           YES
protocol bytes removed            4
native source reply changed       0

modeled simple error reply        0x334b / 0x24
legacy simple error reply         0x332c / 0x24
nonzero result preserved          YES
```

The native Lion one-shot trace independently confirmed the live `0x32e7 -> 0x334b/0x38` version-5 server path. This stage therefore sends exactly one adapted transaction: the first legacy `0x32c8` rendezvous. No later FontServer routine is translated.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-cgs-session-bootstrap-compat-interposer.c
scripts/build-ppc-process-manager-cgs-dockserver-fontserver-rendezvous-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Integration build ID:

```text
cgs-session-bootstrap-dockserver-fontserver-rendezvous-compat-v5
```

Runtime mode:

```text
Snow  ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=passthrough
Lion  ROSETTA_CGS_FONTSERVER_RENDEZVOUS_COMPAT_MODE=lion-rendezvous-v1
```

The integration build still contains exactly two PPC `__DATA,__interpose` tuples:

```text
bootstrap_look_up
mach_msg
```

The existing FontServer bootstrap adapter remains unchanged. RPC tracing also remains enabled so later unadapted FontServer traffic is visible if the title call proceeds beyond rendezvous.

## Exact live policy

The adapter is eligible only for the first message sent to the exact `com.apple.FontServer` service port learned from the successful bootstrap lookup, with:

```text
request ID        0x32c8
bits              0x1513
option            0x3
send              0x18
legacy receive    0x3c
reply port        nonzero and equal to the header local port
timeout           none
notify            null
RPC index         1
```

The pre-wrapper `msgh_size` and reserved header words are not predicates.

For that transaction only, the adapter copies the request to a private `0x40`-byte buffer, changes only `0x32c8 -> 0x32e7`, and calls the original `mach_msg` with receive size `0x40`. The original caller request buffer remains unchanged.

A native complex success must be `0x334b / 0x38`, complex, descriptor count 1, nonzero descriptor address and size, cross-endian NDR, decoded protocol version 5, and nonzero decoded explicit size equal to the descriptor size. The adapter then constructs a separate legacy reply: it changes size to `0x34`, changes the reply ID to `0x332c`, preserves the descriptor and NDR bytes, removes the version scalar, and moves the raw explicit-size word from native offset `0x34` to legacy offset `0x30`.

A native simple error must be `0x334b / 0x24`. Only the reply ID is changed to `0x332c`; NDR and the nonzero result are preserved.

Every later FontServer request, including `0x32d9`, `0x32db`, and `0x32cb`, is passthrough-only and remains visible in the passive trace.

## Safety constraints

- Build the integration dylib only on Snow Leopard 10.6.8.
- Run one Snow positive control before Lion.
- Reuse the accepted PPC title subject, CoreServices adapter, Security adapter, HIToolbox Extras compatibility artifact/resource, and exact-five Lion notification broker unchanged.
- Snow must use strict rendezvous passthrough and complete the title call.
- Repeat syscall 295 on Lion before the integration run.
- On Lion, adapt only RPC index 1 when it is exactly the legacy `0x32c8/0x18/0x3c` envelope.
- Do not adapt, suppress, retry, or normalize any later FontServer RPC.
- Do not issue a second legacy request if native rendezvous fails.
- Do not modify the OOL payload, descriptor bytes, or mapped memory.
- Do not hard-code the captured OOL address or native-i386 descriptor-flags numeric value as PPC predicates.
- Do not add a sixth distributed-notification registration.
- Do not patch CoreText, ATS, FontRegistry, `libATSServer.dylib`, `fontd`, launchd, Rosetta, dyld, caches, or XNU.
- Do not restart or signal any system service.
- Run exactly one Lion integration attempt before review.
- Preserve every new crash/core diagnostic named by the runner.
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

## Phase B — build the v5 FontServer integration interposer on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-cgs-dockserver-fontserver-rendezvous-compat-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-cgs-dockserver-fontserver-rendezvous-compat-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib
ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256
```

Require thin 32-bit PPC, exactly two `__interpose` tuples, build ID v5, bootstrap markers, passive RPC trace markers, and all `PM_CGS_FONTSERVER_RENDEZVOUS_COMPAT_` markers.

## Phase C — Snow Leopard full-title passthrough control

Unset older unrelated trace modes:

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
  ./ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-snowleopard-control.log
```

Require:

```text
FontServer bootstrap lookup                         succeeds normally
RPC trace index 1                                   0x32c8 / 0x18 / 0x3c
RENDEZVOUS_COMPAT_CALL index 1                      mode=passthrough exact=YES
RENDEZVOUS_COMPAT_RESULT                            PASSTHROUGH
RENDEZVOUS_COMPAT_RESULT                            no ADAPTER_PASS
legacy reply                                        0x332c / complex 0x34
SetWindowTitleWithCFString                          0
SETWINDOWTITLE_PASS                                 reached
CFRelease / DisposeWindow / M24                     complete
RESULT                                              POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_SNOW_CONTROL_PASS
RESULT                                              PASS
```

Stop if Snow does not remain behavior-preserving.

## Phase D — transfer the v5 interposer and Snow evidence

Transfer to Lion:

```text
payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib
payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.info.txt
payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-snowleopard-control.log
```

Reuse every other previously accepted artifact unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion title integration run

Unset unrelated audit/trace modes:

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

Syntax-check and run:

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
  ./payload/lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration.log
```

Require the accepted upstream chain through CreateNewWindow, FontServer bootstrap, and the exact fifth notification registration. Then require the first FontServer transaction to show:

```text
RPC trace request index 1                            legacy 0x32c8 / 0x18 / 0x3c
RENDEZVOUS_COMPAT_CALL index 1                       rpcIndex=1 mode=lion-rendezvous-v1 exact=YES
RENDEZVOUS_COMPAT_ADAPTED_REQUEST                    0x32c8 -> 0x32e7, recv 0x3c -> 0x40
RENDEZVOUS_COMPAT_NATIVE_MACH_RETURN                 0
RENDEZVOUS_COMPAT_NATIVE_REPLY                       0x334b / complex 0x38 / version 5
RENDEZVOUS_COMPAT_ADAPTED_REPLY                      0x332c / complex 0x34 / descriptor+NDR preserved
RENDEZVOUS_COMPAT_RESULT                             ADAPTER_PASS
RPC trace reply index 1                              legacy-facing 0x332c / complex 0x34
```

Only one `ADAPTER_PASS` is allowed. If later FontServer RPCs occur, they must show passive trace records and rendezvous predicate rejection/passthrough rather than another adaptation.

### If the title returns

Require `T03_AFTER_SetWindowTitleWithCFString`, title status 0, title PASS, CFRelease, DisposeWindow, M24, and:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_INTEGRATION_PASS
```

### If rendezvous succeeds but the title still does not return

Require:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN
```

Preserve all later passive FontServer RPC records. They identify the next boundary; do not adapt one in the same run.

### If native rendezvous returns a simple error

The adapter must preserve the nonzero result in a legacy `0x332c/0x24` reply and the runner will classify:

```text
RESULT: POST_CREATEWINDOW_WINDOWTITLE_FONTSERVER_RENDEZVOUS_COMPAT_NATIVE_ERROR_PRESERVED
```

Stop; do not retry or normalize it.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.info.txt
ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256
ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-snowleopard-control.log
syscall295-probe-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration.log
lion-ppc-process-manager-post-createwindow-windowtitle-fontserver-rendezvous-compat-integration.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner if available. Do not upload the built dylib itself. Stop after this run.

## Decision gate

### Full title integration passes

The first FontServer rendezvous compatibility boundary is closed. Do not broaden the adapter automatically; the next stage should move beyond the title call only after reviewing the complete run for any newly reached behavior.

### Rendezvous adapter passes but title does not return

The first rendezvous mismatch is closed and the passive trace identifies the next exact FontServer operation. Audit only that next operation before considering another compatibility rule.

### Native simple error is preserved

The native server precondition differs in the translated context. Preserve the exact status and investigate it before any additional FontServer translation.

### Adapter predicate or structural reply validation fails

Stop. Do not relax the predicate or convert the reply until the observed live geometry is reviewed.

## Current boundary

```text
Snow legacy rendezvous                      -> dynamically successful
Lion native Rendezvous2                     -> dynamically successful
copied-buffer conversion policy             -> PASS
live translated-PPC rendezvous conversion   -> next step
later FontServer RPCs                       -> trace-only / no adaptation
XNU                                         -> no change indicated
```
