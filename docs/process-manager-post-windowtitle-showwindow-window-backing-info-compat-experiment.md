# Process Manager ShowWindow WindowBackingInfo ID compatibility experiment

## Objective

The read-only Snow-PPC/Lion-i386 backing-lock audit identifies a precise generated-MIG routine collision behind the live `_CGSBindWindowBacking` shared-memory mapping failure.

Snow Leopard PPC uses:

```text
__CGSGetWindowInfo          0x7262 / 0x72c6
__CGSGetWindowBackingInfo   0x7263 / 0x72c7
```

Lion i386 uses:

```text
__CGSGetWindowInfo          0x7263 / 0x72c7
__CGSGetWindowBackingInfo   0x7264 / 0x72c8
```

For `__CGSGetWindowBackingInfo`, both releases retain the same live-relevant generated-MIG contract:

```text
request bits                0x1513
Mach option                 0x3
send / receive              0x24 / 0x3c
request scalar              one 32-bit window ID at 0x20
success / error reply       0x34 / 0x24
reply result                0x20
success outputs             two paired 32-bit words at 0x24/0x28 and 0x2c/0x30
NDR                        standard generated-MIG reply NDR at 0x18
```

The corresponding server stubs call the same semantic `__CGXGetWindowBackingInfo` / `_CGXGetWindowBackingInfo` family. Both implementations obtain two paired backing-state values from the target window's backing object and return success when the window/backing state is valid; release-specific object offsets differ but the output shape and semantic path agree.

The important collision is therefore not a missing Lion routine. An unchanged Snow PPC `0x7263` request is accepted by Lion as **GetWindowInfo**, not GetWindowBackingInfo. That explains the live baseline: Mach transport succeeds, Lion returns a result-zero `0x72c7 / 0x34` reply, but the PPC caller interprets the wrong routine's four output words as backing shared-memory information and immediately reports `_CGSBindWindowBacking: cannot map backing data shmem`.

This stage tests exactly one ID-only correction at the first observed backing-info call.

## Prepared compatibility implementation

Current runtime `main` provides:

```text
scripts/build-ppc-process-manager-post-windowtitle-showwindow-window-backing-info-compat-on-snowleopard.sh
```

The short artifact name is:

```text
pm-wbi-compat.dylib
```

`WBI` means Window Backing Info.

The accepted upstream core build ID remains unchanged. The new compatibility path has an independent marker:

```text
PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1
```

The adapter is deliberately limited to the first exact legacy `__CGSGetWindowBackingInfo` transaction observed in the established ShowWindow chronology. It requires:

```text
bits                       0x1513
request ID                 0x7263
option                     0x3
send / receive             0x24 / 0x3c
nonzero window ID
remote port                learned ShowWindow application port
NewWindow                  exactly one prior accepted call
release-backing            exactly one prior accepted call
create-alpha               exactly one prior accepted call
OrderFrontConditionally    zero prior calls
AddTrackingArea            zero prior calls
SetFrontWindow             zero prior calls
ColorProfileClient         zero prior calls
ResolveColorProfile        zero prior calls
adapter call index          1
adapter maximum             1
```

For that transaction only, it:

```text
copies the request into a private buffer
changes request ID only     0x7263 -> 0x7264
preserves the window ID and every other request byte
sends the private request to Lion
requires native reply ID    0x72c8
accepts native 0x34 success/result 0 or native 0x24 error/nonzero result
changes reply ID only       0x72c8 -> 0x72c7
preserves NDR, result, both output pairs, and every other reply byte
copies the adapted reply back to the PPC caller
```

No output value, shared-memory ID/reference, address, length, or backing state is synthesized.

## Safety constraints

- Perform one Snow Leopard passthrough control before Lion.
- Perform the syscall-295 preflight before the Lion subject.
- Perform exactly one Lion compatibility run.
- Keep the accepted ResolveColorProfile and ColorProfileClient adapters enabled on Lion.
- Do not adapt a second `0x7263` call in this stage. Snow's successful control uses one backing-info call; the Lion baseline's later repeated calls follow the first failed bind.
- Do not adapt `CGSGetWindowInfo` itself.
- Do not modify reply output words or shared-memory references.
- Do not expand the exact-six notification broker in this stage.
- Do not revisit `CGSShapeWindow`, `CGSReleaseColorProfile`, CoreUI, or RawCamera.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.
- No kernel rebuild or reboot.

## Phase A — update repositories

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

## Phase B — build the WindowBackingInfo compatibility artifact on Snow Leopard

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-window-backing-info-compat-on-snowleopard.sh || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-window-backing-info-compat-on-snowleopard.sh || exit 1
```

Expected outputs:

```text
pm-wbi-compat.dylib
pm-wbi-compat.dylib.info.txt
pm-wbi-compat.dylib.sha256
```

Require the accepted ColorProfileClient v2 core build ID, resolver trace/compatibility markers, the new WindowBackingInfo marker, embedded distributed-notifications ingress v2, a 32-bit PPC Mach-O dylib, and exactly two `__interpose` tuples.

## Phase C — Snow Leopard behavior-preserving passthrough control

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
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=passthrough
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
  ./pm-wbi-compat.dylib \
  ./pm-wbi-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./pm-wbi-snow.log || exit 1
```

Require:

```text
PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1
PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:
  mode=passthrough
  exact=YES
  applicationPortExact=YES
  nonzero windowId
PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:PASSTHROUGH
no PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS
0x7263 / 0x72c7 / 0x34 / result 0
S01_AFTER_ShowWindow
M24_SUCCESS
RESULT: PASS
```

Do not proceed to Lion if the Snow control fails or if more than one target backing-info call is observed.

## Phase D — transfer the compatibility artifact to Lion

Transfer:

```text
pm-wbi-compat.dylib
pm-wbi-compat.dylib.info.txt
pm-wbi-compat.dylib.sha256
pm-wbi-snow.log
```

Place the dylib, info, and SHA sidecar under Lion's `payload/` directory and verify the SHA before execution.

## Phase E — syscall-295 preflight on Lion

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-pm-wbi.log" || exit 1
```

Require the accepted kernel SHA, `result=-1 errno=9 saw_sigsys=0`, exit status 0, and `RESULT: PASS`.

## Phase F — exactly one Lion WindowBackingInfo compatibility run

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
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=lion-id-v1
export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=lion-id-v1
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
  ./payload/pm-wbi-compat.dylib \
  ./payload/pm-wbi-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-pm-wbi.log
```

Do not run the Lion subject a second time.

## Lion acceptance discriminator

The first backing-info call must show:

```text
PM_CGS_WINDOW_BACKING_INFO_COMPAT_CALL:
  index=1
  adapted=0
  mode=lion-id-v1
  exact=YES
  applicationPortExact=YES
  nonzero windowId
  newWindowCompatCalls=1
  releaseBackingCompatCalls=1
  opacityCreateCompatCalls=1
  orderFrontCompatCalls=0
  addTrackingCompatCalls=0
  setFrontWindowCompatCalls=0
  colorProfileClientCompatCalls=0
  colorProfileResolveCompatCalls=0

PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REQUEST:
  index=1
  legacyId=0x00007263
  lionId=0x00007264
  send=0x00000024
  recv=0x0000003c
  changedBytes=1
  bodyChangedBytes=0
  sourceChangedBytes=0

PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_MACH_RETURN:
  index=1
  kr=0
```

### Native backing-info success

The desired native reply is:

```text
PM_CGS_WINDOW_BACKING_INFO_COMPAT_NATIVE_REPLY:
  index=1
  size=0x00000034
  id=0x000072c8
  resultRaw=0x00000000
  replyClass=SUCCESS

PM_CGS_WINDOW_BACKING_INFO_COMPAT_ADAPTED_REPLY:
  nativeId=0x000072c8
  legacyId=0x000072c7
  changedBytes=1
  bodyChangedBytes=0
  resultRaw=0x00000000
  replyClass=SUCCESS

PM_CGS_WINDOW_BACKING_INFO_COMPAT_RESULT:ADAPTER_PASS
```

Then inspect chronology, not just the marker. The strongest confirmation is:

- no immediate `_CGSBindWindowBacking: cannot map backing data shmem`;
- no immediate `_CGSLockWindow: Unable to lock window`;
- no second WindowBackingInfo compatibility call;
- the accepted ColorProfileClient and ResolveColorProfile adapters still pass when reached;
- preserve the first later diagnostic or milestone;
- if `S01_AFTER_ShowWindow` appears, preserve all subsequent milestones and the runner result.

Do not pre-authorize the seventh notification registration, ShapeWindow, CoreUI, or RawCamera path even if the backing failure disappears.

### Native semantic error

If Lion returns `0x72c8 / 0x24` with a nonzero result, the ID collision is corrected but native backing-state semantics still reject the window. Preserve the result and do not rewrite reply outputs.

### Predicate rejection or repeated backing-info call

If `exact=NO`, `applicationPortExact=NO`, chronology counters differ, or another `0x7263` call occurs after the single adapted call, stop. Do not relax the predicate or raise the one-call cap until the resulting chronology is reviewed.

## Return

Return these six primary artifacts:

```text
pm-wbi-compat.dylib.info.txt
pm-wbi-compat.dylib.sha256
pm-wbi-snow.log
sys295-pm-wbi.log
lion-pm-wbi.log
lion-pm-wbi.raw.log
```

Also retain and return any newly named crash/plist/core diagnostic if the Lion runner produces one. Do not upload the dylib itself unless specifically requested.

## Current boundary

```text
ResolveColorProfile                              accepted adapter PASS
Snow GetWindowBackingInfo                        0x7263 / 0x72c7
Lion GetWindowInfo                               0x7263 / 0x72c7
Lion GetWindowBackingInfo                        0x7264 / 0x72c8
wire geometry                                    same for backing-info helper
live legacy 0x7263 on Lion                       wrong-routine success collision
observed consequence                             invalid backing shmem outputs
compatibility under test                         0x7263 -> 0x7264, 0x72c8 -> 0x72c7
reply outputs                                    preserve verbatim
adapter maximum                                  one call
seventh notification registration                held
CGSShapeWindow                                   held
XNU                                              no change indicated
```


## Observed result — WindowBackingInfo compatibility is live-proven

The Snow passthrough control completed ShowWindow, disposal, M24, and PASS with exactly one target `0x7263 / 0x72c7` backing-info transaction. The syscall-295 preflight also remained healthy.

The single Lion compatibility run satisfied the exact one-call gate. The adapter saw the first application-port backing-info request before the later ShowWindow compatibility calls, changed only request ID `0x7263 -> 0x7264`, received native `0x72c8 / 0x34 / result 0`, and changed only the reply ID `0x72c8 -> 0x72c7`. The request body, window ID, result, and both reply output pairs were preserved. No second WindowBackingInfo compatibility call occurred.

The prior immediate `_CGSBindWindowBacking: cannot map backing data shmem` and `_CGSLockWindow: Unable to lock window` failures disappeared. Later in the same run, ColorProfileClient and ResolveColorProfile each still passed their existing exact adapters.

ShowWindow still does not return because the exact-six notification broker reaches a new, later boundary: request index 7 has Mach bits `0x1111`, message ID 4, message size 356, binary-plist payload 322, and is rejected with status 25 / `BROKER_REJECT_NAME`. RawCamera loading and the later CoreUI diagnostics remain downstream of that deliberately closed notification boundary.

WindowBackingInfo compatibility is therefore accepted as live-proven. Do not broaden its one-call rule or rewrite its output values.

The authoritative next procedure is:

```text
docs/process-manager-showwindow-seventh-notification-schema-audit.md
```

That stage keeps the exact six reviewed registrations active, captures and decodes exactly the seventh payload, deliberately preserves status 25, and stops for review. It does not authorize a seventh registration, ShapeWindow compatibility, RawCamera/CoreUI workarounds, or an XNU change.

## Completed boundary

```text
WindowBackingInfo legacy request                  0x7263
WindowBackingInfo Lion request                    0x7264
WindowBackingInfo native reply                    0x72c8 / 0x34 / result 0
WindowBackingInfo PPC-facing reply                0x72c7 / 0x34 / result 0
request/reply body changes                        0
adapter calls                                     exactly one
backing-data shmem mapping failure                cleared
_CGSLockWindow failure                            cleared
ColorProfileClient compatibility                  PASS
ResolveColorProfile compatibility                 PASS
sixth notification registration                   accepted
seventh notification request                      id=4 size=356 payload=322
exact-six broker seventh-request result            status 25 / name reject
next step                                         capture/decode seventh payload
CGSShapeWindow                                    held
RawCamera / CoreUI                                held
XNU                                               no change indicated
```
