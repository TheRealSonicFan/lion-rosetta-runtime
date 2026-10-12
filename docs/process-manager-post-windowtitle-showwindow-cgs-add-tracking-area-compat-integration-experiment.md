# Process Manager ShowWindow CGSAddTrackingArea compatibility integration

## Objective

Validate one exact generated-MIG compatibility rule for the already observed ShowWindow tracking-area request, without broadening any neighboring CoreGraphics behavior.

The completed static audit closes the protocol question for the live inline path:

```text
                               Snow PPC              Lion i386
inline request / reply         0x7388 / 0x73ec      0x738e / 0x73f2
header bits                    0x1513                0x1513
mach_msg option                0x3                   0x3
send size                      0x3c + 4*count        0x3c + 4*count
receive size                   0x2c                  0x2c
accepted reply size            0x24                  0x24
count limit                    0x1000                0x1000
NDR/result handling            equivalent             equivalent
```

The previously captured ShowWindow request has `count=9`, so its send size is exactly `0x3c + 4*9 = 0x60`. The Snow control returned result 0 for this exact `0x7388 / 0x73ec` transaction. Lion rejected the unchanged legacy ID with `-304 / MIG_BAD_ARGUMENTS` and immediately logged `CGSAddTrackingArea` server type-check failure.

Lion also contains a different non-inline `__CGSAddTrackingArea` transaction using `0x72d8 / 0x733c`, bits `0x80001513`, and send size `0x4c`. That is not the live ShowWindow request and is explicitly out of scope.

This experiment therefore adapts only the first exact observed inline request:

```text
PPC request ID        0x7388
Lion request ID       0x738e
PPC reply ID          0x73ec
Lion reply ID         0x73f2
bits                  0x1513
option                0x3
send / receive        0x60 / 0x2c
window ID             nonzero
count                 9
```

No payload field, size, port, NDR record, result value, or other request is changed.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
docs/process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-integration-experiment.md
```

Compatibility build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat-v1
```

Runtime mode:

```text
Snow Leopard  ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
Lion          ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
```

The existing ShowWindow unknown-CGS trace remains enabled in both controls. The target `0x7388` transaction becomes a named known trace kind, while other unclassified ShowWindow traffic continues to be passively recorded.

## Adapter invariants

The Lion adapter is authorized only when all of these conditions hold:

- the established application CGS port is the same port learned from the accepted NewWindow path;
- request bits are exactly `0x1513`;
- request ID is exactly `0x7388`;
- Mach option is exactly `0x3`;
- send size is exactly `0x60`;
- receive size is exactly `0x2c`;
- NDR is the expected legacy NDR;
- window ID is nonzero;
- count is exactly 9;
- `send_size == 0x3c + 4*count`;
- this is the first exact tracking-area compatibility call;
- the accepted create-alpha compatibility call has already occurred exactly once.

For that one request, the adapter copies the message into a private buffer and changes only request ID `0x7388 -> 0x738e`. It requires a Lion reply with ID `0x73f2`, size `0x24`, expected NDR/result geometry, then changes only the reply ID `0x73f2 -> 0x73ec` before returning it to the unchanged PPC client.

Any predicate mismatch passes through unchanged. Any unexpected native reply is not synthesized into success.

## Safety constraints

- Reuse the existing `cps-showwindow-validation-v1` subject unchanged.
- Reuse the exact-six native notification broker unchanged.
- Reuse the accepted Security, CGS session/DockServer/FontServer rendezvous, HIToolbox Extras, and staged Snow `Extras.rsrc` artifacts unchanged.
- Build only the new PPC CoreServices/distributed-notifications compatibility dylib on Snow Leopard.
- Do not rebuild the PPC subject.
- Do not modify the exact-six broker.
- Do not adapt `0x72e7`, `0x72f2`, `0x7268`, or any other ShowWindow CGS request in this stage.
- Do not adapt the non-inline `0x72d8 / 0x733c` tracking-area routine.
- Do not patch color-profile, window-context, RawCamera, CoreUI, or rendering behavior.
- Do not add `SelectWindow`, `IsWindowVisible`, timers, or an event loop.
- Do not patch system frameworks, Rosetta, dyld, caches, launchd, or XNU.
- Do not restart or signal WindowServer, distnoted, fontd, Dock, launchd, or related jobs.
- Run exactly one Lion integration attempt after the Snow control.
- Preserve every new crash/core diagnostic named by the Lion runner.

No XNU source change, kernel rebuild, or reboot is part of this stage.

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

## Phase B — build the compatibility dylib on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-on-snowleopard.sh
```

Expected outputs:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.sha256
```

Require:

```text
architecture                                      32-bit PPC / ppc7400
__interpose tuples                                exactly 2
build ID                                          ...showwindow-addtrackingarea-compat-v1
embedded distributed-notifications ingress       v2
CGS_ADD_TRACKING_AREA_INLINE_LEGACY               present
CGS_ADD_TRACKING_AREA_INLINE_LION                 present
PM_CGS_ADD_TRACKING_AREA_COMPAT_CALL              present
PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REQUEST   present
PM_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_REPLY      present
PM_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTED_REPLY     present
PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT:ADAPTER_PASS present
```

Stop if the shell syntax check, compile, architecture check, marker check, or hash output fails.

## Phase C — Snow Leopard behavior-preserving control

Unset unrelated audit and passive-trace modes:

```sh
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
```

Set the accepted Snow stack:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
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

Syntax-check and run:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-snowleopard-control.log
```

Require:

```text
tracking-area compatibility call              exactly 1
mode                                           passthrough
predicate                                      exact=YES
legacy request                                 0x7388
legacy expected reply                          0x73ec
send / receive                                 0x60 / 0x2c
count                                          9
native adaptation                              NOT performed
tracking request mach_msg                      success
legacy reply                                   0x73ec / 0x24 / result 0
S00_BEFORE_ShowWindow                          reached
S01_AFTER_ShowWindow                           reached
SHOWWINDOW_PASS                                reached
DisposeWindow / M24                            complete
control_status                                 0
RESULT                                         POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_SNOW_CONTROL_PASS
RESULT                                         PASS
```

Stop if the Snow control changes behavior or the target predicate does not match exactly.

## Phase D — transfer only the new compatibility artifact

Transfer to Lion:

```text
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.info.txt
payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-snowleopard-control.log
```

Reuse the existing subject, Security interposer, CGS FontServer-rendezvous interposer, exact-six broker, HIToolbox Extras compatibility dylib, and staged resource unchanged.

## Phase E — repeat syscall 295 on Lion

Save:

```text
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

## Phase F — exactly one Lion integration

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

Set the accepted Lion stack plus the exact tracking-area adapter:

```sh
export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
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

Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Then run exactly once:

```sh
ROSETTA_EXPECTED_KERNEL_SHA256="$ROSETTA_EXPECTED_KERNEL_SHA256" \
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat.log
```

Require the accepted upstream chain to remain intact and require exactly one tracking-area adaptation:

```text
CreateNewWindow                                  PASS
SetWindowTitleWithCFString                       PASS
FontServer rendezvous                           adapter PASS exactly once
six notifications                               accepted, zero rejects, exact=YES
create-alpha                                    adapter PASS exactly once
S00_BEFORE_ShowWindow                           reached
tracking adapter call                           exactly 1
tracking predicate                              exact=YES
tracking count                                  9
adapted request                                 0x7388 -> 0x738e
send / receive                                  0x60 / 0x2c
request changed bytes                           1, body=0, source=0
native mach_msg                                 success
native reply                                    0x73f2 / 0x24 / result 0
adapted PPC reply                               0x73ec / 0x24 / result 0
reply changed bytes                             1, body=0
PM_CGS_ADD_TRACKING_AREA_COMPAT_RESULT           ADAPTER_PASS
protected hashes                                unchanged
```

## Decision gate

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_INTEGRATION_PASS`

Require:

```text
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
T04_BEFORE_CFRelease
T05_AFTER_CFRelease
M22_BEFORE_DisposeWindow
M23_AFTER_DisposeWindow
M24_SUCCESS
process exit 0
no new crash/core diagnostic
```

This closes the ShowWindow tracking-area gate and, if no other failure remains, closes ShowWindow itself. Stop before adding `SelectWindow`; review the complete trace first.

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_ADAPTER_PASS_POST_RPC_NO_RETURN`

The exact tracking-area conversion succeeded, but ShowWindow still did not return. Do not adapt another request immediately. Review the same run's continuing unknown-CGS trace and diagnostic ordering to identify the first remaining deterministic boundary. The previously observed `0x72e7` and `0x72f2` failures are candidates only if they persist in the new run; they are not pre-authorized.

### `POST_WINDOWTITLE_SHOWWINDOW_CGS_ADD_TRACKING_AREA_COMPAT_NATIVE_ERROR_PRESERVED`

The Lion-native `0x738e` transaction returned a valid reply with a nonzero result. Preserve that result and stop. Treat the next question as argument/state semantics rather than widening the ID adapter.

### Predicate or reply mismatch

For:

```text
...PREDICATE_NOT_REACHED
...REQUEST_ADAPTER_NOT_PASSED
...SUCCESS_REPLY_ADAPTER_NOT_PASSED
...NATIVE_REPLY_UNEXPECTED
```

stop and resolve the exact adapter model. Do not broaden tracking-area recognition or patch neighboring CGS traffic.

### Seventh notification request

If a seventh notification request appears, do not widen notification policy. Audit it separately.

## Return

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-compat.dylib.sha256
ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat-snowleopard-control.log
syscall295-probe-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat.log
lion-ppc-process-manager-post-windowtitle-showwindow-cgs-add-tracking-area-compat.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the executable subject or compatibility dylib itself unless specifically requested.

## Current boundary

```text
PPC execution / syscall 295                    -> PASS
accepted pre-ShowWindow compatibility stack    -> PASS
six reviewed notifications                     -> accepted, zero rejects
Snow inline CGSAddTrackingArea                 -> 0x7388 / 0x73ec, success
Lion native inline CGSAddTrackingArea          -> 0x738e / 0x73f2
wire geometry                                  -> equivalent
live legacy request count                      -> 9 / send 0x60
Lion legacy-ID attempt                         -> -304 + server type-check failure
next step                                      -> one exact inline ID compatibility integration
neighboring ShowWindow CGS requests            -> held
XNU                                             -> no change indicated
```


## Observed result — tracking-area adapter passes; ShowWindow remains open

The prepared compatibility dylib built as PPC7400 with the expected `showwindow-addtrackingarea-compat-v1` build ID, two PPC interpose tuples, and SHA-256 `061cecf39a48050f105f293b47c5f5181e056ef4bc31ded93f6bc9dd3d2f81cd`. The Snow Leopard control matched the exact count-9 tracking request in passthrough mode and completed `S01_AFTER_ShowWindow`, disposal, and final `RESULT: PASS`. Syscall 295 on Lion remained healthy.

The one Lion integration proves the exact tracking-area conversion succeeds:

```text
predicate              exact=YES
count                  9
legacy request         0x7388
native request         0x738e
request changed bytes  1
request body changes   0
native reply           0x73f2 / 0x24 / result 0
legacy reply           0x73ec / 0x24 / result 0
reply changed bytes    1
reply body changes     0
adapter                PASS
```

The previous `CGSAddTrackingArea` server type-check failure is no longer present. ShowWindow nevertheless does not return: `S01` remains absent, the process exits 139, and a new crash/plist/core set is reported.

The continuing post-`S00` application-CGS sequence now exposes three unknown transactions around the successful adapter:

```text
0x72e7 -> 0x734b   result -304
0x7388 -> 0x73ec   adapted result 0
0x7268 -> 0x72cc   result 0
0x72f2 -> 0x7356   result -304
```

The repeated color-profile/window-context failures remain, and their first cluster occurs before the `0x72e7` request. Therefore no additional live conversion is authorized yet.

The authoritative next procedure is:

```text
docs/process-manager-post-windowtitle-showwindow-post-tracking-cgs-protocol-audit.md
```

That stage is static and read-only. It attributes the exact `0x72e7 / 0x734b` and `0x72f2 / 0x7356` contracts on Snow PPC and Lion i386 before deciding whether either `-304` is an ID/ABI mismatch or merely a consequence of the earlier color-profile/window-context failure. The known earlier `CGSShapeWindow` rejection remains held; no XNU change is indicated.
