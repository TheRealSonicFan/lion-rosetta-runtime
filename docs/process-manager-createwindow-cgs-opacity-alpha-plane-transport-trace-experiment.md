# Process Manager CreateNewWindow CGS opacity alpha-plane transport trace experiment

## Objective

Passively identify the exact opacity alpha-plane generated-MIG transaction that executes after the accepted NewWindow and release-backing compatibility stages. This stage does not adapt opacity traffic.

The focused static audit now passes on both Snow Leopard PPC and Lion i386. It proves that the public `CGSSetWindowOpacity` wrapper can call either `__CGSCreateWindowAlphaPlane` or `__CGSTerminateWindowAlphaPlane`, and that both helpers are direct generated-MIG clients with matching wire geometry but shifted routine IDs.

Static contracts:

```text
                              Snow PPC             Lion i386
create request/reply          0x724f / 0x72b3      0x7250 / 0x72b4
terminate request/reply       0x7250 / 0x72b4      0x7251 / 0x72b5
header bits                   0x1513               0x1513
mach_msg option               0x3                  0x3
send size                     0x24                 0x24
receive size                  0x2c                 0x2c
accepted reply size           0x24                 0x24
NDR/result handling           equivalent            equivalent
```

The important ambiguity is that Snow's **terminate** request/reply IDs are numerically identical to Lion's **create** request/reply IDs:

```text
Snow terminate               0x7250 / 0x72b4
Lion create                  0x7250 / 0x72b4
```

Therefore static evidence alone is not sufficient to authorize any opacity ID translation. The next live observation must first identify which branch the translated PPC caller actually takes.

The immediately preceding accepted Lion run reached native success through release-backing and then emitted:

```text
(ipc/rcv) msg too large: CGSSetWindowOpacity
```

before the later display-bounds and ShapeWindow diagnostics. This stage is limited to that first opacity boundary.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Compile-time mode:

```text
PM_CGS_POST_RELEASEBACKING_OPACITY_TRACE
```

Runtime modes:

```text
Snow  ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE=passthrough
Lion  ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE=lion-passive-v1
```

Combined build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace-v1
```

The combined dylib keeps exactly two PPC interpose tuples, `bootstrap_look_up2` and `mach_msg`. The accepted NewWindow and release-backing adapters remain unchanged.

## Trace policy

The trace recognizes only the two translated-PPC legacy opacity alpha-plane request IDs:

```text
0x724f  CGS_CREATE_WINDOW_ALPHA_PLANE_LEGACY
0x7250  CGS_TERMINATE_WINDOW_ALPHA_PLANE_LEGACY
```

It records the existing message header, option, send/receive sizes, ports, request body words, Mach return, and—only on Mach success—the returned reply envelope. It never rewrites either opacity request or reply.

Because `0x7250` is simultaneously Lion's native create-alpha-plane routine ID, the trace deliberately labels `0x7250` according to the translated PPC caller's legacy contract: **legacy terminate**. This is a caller-side trace classification, not a claim about how Lion WindowServer interprets the number.

If `mach_msg` returns a receive error, the trace records a bounded post-call buffer snapshot under:

```text
PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:
```

That snapshot is diagnostic only and is not interpreted as a valid MIG reply.

## Safety constraints

- Build only the new opacity alpha-plane trace dylib on Snow Leopard 10.6.8.
- Keep the accepted CreateNewWindow subject, Security interposer, Dock bootstrap compatibility dylib, HIToolbox Extras compatibility dylib/resource, and exact-four notification broker unchanged.
- Keep the accepted NewWindow and release-backing compatibility policies unchanged.
- On Snow, NewWindow and release-backing compatibility remain strict passthrough.
- On Lion, NewWindow and release-backing retain their accepted live modes.
- Do not rewrite `0x724f`, `0x7250`, `0x72b3`, `0x72b4`, or any opacity body field in this stage.
- Do not add `MACH_RCV_LARGE` or change the PPC client's receive size. The observed `0x2c` receive contract must remain untouched.
- Do not trace or adapt `CGSGetDisplayBounds` or `CGSShapeWindow`.
- Repeat the established syscall-295 safety gate before the Lion run.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, libSystem, launchd, the Rosetta cache, or XNU.
- Do not restart or signal WindowServer or launchd jobs.
- Run the Lion trace exactly once before review.
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

## Phase B — build only the opacity alpha-plane trace dylib on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.sha256
```

Require 32-bit PPC, exactly two interpose tuples, the build ID above, the accepted NewWindow/release-backing markers, both legacy opacity alpha-plane trace-kind strings, and the failure-buffer marker.

Stop if Phase B fails.

## Phase C — Snow Leopard full passthrough control and branch identification

Unset obsolete/live-only trace variables:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
```

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=passthrough
export ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check and run the existing full-stack Snow control, changing only the CoreServices dylib pair:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace-snowleopard-control.log
```

Require all accepted upstream Snow gates, including `CreateNewWindow=0`, nonzero WindowRef, DisposeWindow, and M24.

The opacity trace must observe exactly one of these two successful legacy transactions:

```text
CREATE:
bits=0x1513 request=0x724f expectedReply=0x72b3 option=0x3 send=0x24 recv=0x2c
Mach return 0
reply bits=0x1200 size=0x24 id=0x72b3 idMatch=YES

or

TERMINATE:
bits=0x1513 request=0x7250 expectedReply=0x72b4 option=0x3 send=0x24 recv=0x2c
Mach return 0
reply bits=0x1200 size=0x24 id=0x72b4 idMatch=YES
```

Hard gate:

```text
cgs_opacity_alpha_legacy_trace_count=1
cgs_opacity_alpha_legacy_kind=CREATE|TERMINATE
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

No `PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:` line may execute on Snow.

Stop if Phase C fails.

## Phase D — transfer only the new trace artifact

Transfer to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.sha256
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace-snowleopard-control.log
```

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat syscall 295 on Lion

Run the established native syscall-295 routing probe and save:

```text
syscall295-probe-process-manager-createwindow-cgs-opacity-alpha-plane-trace.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion passive opacity alpha-plane trace

Unset old passive modes and obsolete schema-audit variables. Keep the established expected kernel hash.

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_NEWWINDOW_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_RELEASEBACKING_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE=lion-passive-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Also ensure:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
```

Syntax-check and run the existing Lion runner with only the CoreServices dylib pair changed:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh

ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace.log
```

Require the accepted NewWindow and release-backing adapters to remain exact native-success paths before interpreting opacity.

Then require exactly one legacy opacity alpha-plane request:

```text
CREATE      0x724f -> expected legacy reply 0x72b3
or
TERMINATE   0x7250 -> expected legacy reply 0x72b4

bits         0x1513
option       0x3
send         0x24
receive      0x2c
```

The runner classifies the observed branch without changing it.

### Receive-too-large branch

If the PPC client reproduces the current opacity boundary, `mach_msg` should return:

```text
kr=268451844
hex=0x10004004
```

which is `MACH_RCV_TOO_LARGE`. The runner then emits one of:

```text
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_CREATE_MACH_RCV_TOO_LARGE_OBSERVED
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_TERMINATE_MACH_RCV_TOO_LARGE_OBSERVED
```

and the raw log must also contain one `PM_CGS_OPACITY_ALPHA_TRACE_FAILURE_BUFFER:` line for that same branch. Treat its post-call fields as diagnostic bytes only, not as a valid reply.

### Mach-success branch

If the legacy request returns Mach success, the runner records the actual legacy-facing reply. In particular:

- a CREATE request with `0x72b3 / 0x24` is classified as a legacy create reply;
- a TERMINATE request `0x7250` with `0x72b4 / 0x24` is classified as an **ID-collision reply**, because that same numeric request/reply pair is Lion's native create-alpha-plane contract.

Do not infer semantic correctness from the collision branch even if Mach transport succeeds.

Do not rerun before review.

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace.dylib.sha256
ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-opacity-alpha-plane-trace.log
lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace.log
lion-ppc-process-manager-createwindow-cgs-opacity-alpha-plane-trace.raw.log
```

Also return every new crash/core diagnostic named by the runner. Stop after Phase G.

## Decision gate

### Snow and Lion both select CREATE; Lion returns `MACH_RCV_TOO_LARGE`

This would align the live failure with the static create-alpha differential:

```text
Snow  0x724f / 0x72b3
Lion  0x7250 / 0x72b4
```

Do **not** integrate a live adapter immediately. The next stage should first prove the exact proposed create-alpha request/reply ID conversion on copied buffers with no Mach IPC, preserving the complete `0x24` request body and modeled success/error reply results.

### Snow and Lion both select TERMINATE

The numeric collision is active:

```text
Snow terminate  0x7250 / 0x72b4
Lion create     0x7250 / 0x72b4
Lion terminate  0x7251 / 0x72b5
```

Do not treat a Mach-success `0x72b4` reply as proof that termination semantics succeeded. Review the live argument/state evidence before defining any conversion.

### Snow and Lion select different branches

Stop. The issue is not yet a simple generated-MIG numbering differential. Compare opacity boolean/window backing state before any compatibility policy.

### No exact alpha-plane request is observed

Stop and reassess the wrapper/transport model using the preserved diagnostics. Do not broaden to later CoreGraphics helpers.

### CreateWindow unexpectedly completes

Preserve the exact trace and stop. Do not add another adapter in the same run.

## Current boundary

```text
PPC execution / Rosetta                         -> PASS
syscall 295                                     -> PASS
accepted pre-window compatibility stack         -> PASS
NewWindow ID-only integration                   -> native Lion success
release-backing ID-only integration             -> native Lion success
opacity static alpha-plane audit                -> PASS
create IDs Snow/Lion                            -> 0x724f/0x72b3 vs 0x7250/0x72b4
terminate IDs Snow/Lion                         -> 0x7250/0x72b4 vs 0x7251/0x72b5
first live opacity diagnostic                    -> MACH receive-too-large
next step                                       -> passive legacy branch/transport trace
```

No additional XNU change is indicated.


## Observed completed result — create-alpha branch reproduced with receive-too-large

The returned Snow control and Lion passive trace close the branch ambiguity.

Artifact/control provenance:

```text
combined build ID             dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-trace-v1
artifact SHA-256              860571c102912714dc972771c976b90d48c5c3678363ecb25e0fea5db067f4b1
architecture                  ppc7400
interpose section size        0x10
Snow opacity branch           CREATE
Snow control                  PASS / CreateNewWindow=0 / nonzero WindowRef / Dispose / M24
syscall 295                   EBADF / no SIGSYS / PASS
Lion opacity branch           CREATE
protected hashes              unchanged
```

The Snow live transaction was:

```text
request                       0x724f
expected reply                0x72b3
bits                          0x1513
option                        0x3
send / receive                0x24 / 0x2c
window ID                     0x113
Mach return                   0
reply                         0x72b3 / 0x24
decoded result                0
```

The Lion live transaction reached the same legacy create-alpha request after both accepted upstream adapters had already completed with native success:

```text
NewWindow native reply        0x73fe / 0x38 / result 0
release-backing native reply  0x72b0 / 0x24 / result 0
opacity request               0x724f
expected legacy reply         0x72b3
bits                          0x1513
option                        0x3
send / receive                0x24 / 0x2c
window ID                     0x239
Mach return                   0x10004004 / MACH_RCV_TOO_LARGE
failure snapshot postId       0x72b3
failure snapshot postSize     0x18
```

The runner observed exactly one opacity alpha-plane request, classified it as CREATE, observed no terminate-alpha request, and emitted:

```text
RESULT: CREATENEWWINDOW_CGS_OPACITY_ALPHA_TRACE_CREATE_MACH_RCV_TOO_LARGE_OBSERVED
```

The later `CGSGetDisplayBounds` and `CGSShapeWindow` diagnostics remain downstream and are not promoted to the active boundary. The new crash/core files from this run are preserved evidence, but they are not required to choose the next discriminator because the exact first failing transaction is already identified.

The authoritative next procedure is:

```text
docs/process-manager-createwindow-cgs-opacity-alpha-plane-create-compat-protocol-adapter-experiment.md
```

That next stage performs no Mach IPC. It proves on copied buffers that only request ID `0x724f -> 0x7250` and reply ID `0x72b4 -> 0x72b3` change, with zero body/source changes and result preservation. No live opacity adapter is authorized until that local proof passes and is reviewed.
