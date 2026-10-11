# Process Manager CreateNewWindow CGS NewWindow transport trace

## Objective

Dynamically confirm the exact legacy CoreGraphics NewWindow transaction reached by the unchanged Snow Leopard PPC client after the accepted Dock bootstrap repair, before designing any request adapter.

The completed static audit establishes a narrow generated-MIG differential for the inline window-creation helper.

Snow Leopard PPC `__CGSCreateWindowInline`:

```text
request id              0x7394
expected reply id       0x73f8
request bits            0x1513
mach_msg option         0x3
receive size            0x40
send size               0x38 + 4*countA + 4*countB
accepted reply sizes    0x38 success / 0x24 error
```

Lion i386 `__CGSCreateWindowInline`:

```text
request id              0x739a
expected reply id       0x73fe
request bits            0x1513
mach_msg option         0x3
receive size            0x40
send size               0x38 + 4*countA + 4*countB
accepted reply sizes    0x38 success / 0x24 error
```

Both generated clients use the same visible variable-array construction and NDR-aware reply handling. The material static delta in the inline helper is the routine-ID pair `0x7394/0x73f8 -> 0x739a/0x73fe`.

The higher-level `CGSNewWindowWithOpaqueShape` wrapper on both releases selects the inline helper when both encoded region counts are at most `0x3fff`; otherwise it falls back to `__CGSCreateWindow`. The current Carbon test is expected to take the inline path, but this stage must prove that dynamically rather than assume it.

## Prepared implementation

Current runtime `main` provides:

```text
scripts/build-ppc-process-manager-createwindow-cgs-newwindow-trace-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

The trace build has build ID:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-trace-v1
```

It preserves the accepted CoreServices/session/server-version/CPS/SetFront/distributed-notifications behavior and adds only passive `mach_msg` recognition for the statically proven NewWindow IDs. It does not rewrite request IDs, sizes, payloads, ports, replies, or return values.

Trace kinds:

```text
CGS_CREATE_WINDOW_INLINE_LEGACY   0x7394 -> 0x73f8
CGS_CREATE_WINDOW_INLINE_LION     0x739a -> 0x73fe
```

The unchanged Snow PPC subject is expected to emit only the legacy kind.

## Safety constraints

For this stage:

- rebuild only the new passive CoreServices/NewWindow trace dylib on Snow Leopard;
- do not rebuild the PPC CreateNewWindow subject;
- do not rebuild the accepted Security, Dock-aware CGS, HIToolbox Extras, or native notification artifacts;
- keep the exact four-registration broker and exact Snow `Extras.rsrc` fallback unchanged;
- run a full Snow CreateNewWindow control first;
- on Lion adapt only the already accepted compatibility boundaries; the NewWindow trace itself is passive;
- do not translate `0x7394` to `0x739a` yet;
- do not rewrite `0x73fe` to `0x73f8` yet;
- do not broaden the trace to unknown CGS/Mach traffic;
- run exactly one Lion CreateNewWindow trace before review;
- do not patch CoreGraphics, WindowServer, HIToolbox, Rosetta, dyld, launchd, or XNU;
- no XNU rebuild or reboot.

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

## Phase B — build only the passive trace dylib on Snow Leopard

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime

/bin/bash -n ./scripts/build-ppc-process-manager-createwindow-cgs-newwindow-trace-on-snowleopard.sh

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-createwindow-cgs-newwindow-trace-on-snowleopard.sh \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib
```

Require:

```text
32-bit PPC dylib
exactly two __interpose tuples
build id ends in distnotify-ingress-newwindow-trace-v1
embedded distributed-notifications ingress v2 marker
CGS_CREATE_WINDOW_INLINE_LEGACY marker
CGS_CREATE_WINDOW_INLINE_LION marker
.info.txt sidecar
.sha256 sidecar
```

Do not rebuild any other accepted artifact.

## Phase C — Snow full CreateNewWindow control with passive trace

Use the accepted Dock-aware CGS interposer and exact Snow Extras fallback.

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=passthrough
export ROSETTA_CGS_NEWWINDOW_TRACE_MODE=passthrough
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=snow-force-external-v1
```

Syntax-check the existing Snow runner:

```sh
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Run:

```sh
/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib \
  ./ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./ppc-process-manager-createwindow-cgs-newwindow-transport-trace-snowleopard-control.log
```

Hard gate:

```text
PM_CGS_CONNECTION_TRACE_REQUEST:... kind=CGS_CREATE_WINDOW_INLINE_LEGACY ... id=0x00007394 expectedReply=0x000073f8 option=0x00000003 ... recv=0x00000040
PM_CGS_CONNECTION_TRACE_MACH_RETURN:... kind=CGS_CREATE_WINDOW_INLINE_LEGACY kr=0
PM_CGS_CONNECTION_TRACE_REPLY:... kind=CGS_CREATE_WINDOW_INLINE_LEGACY ... id=0x000073f8 ... idMatch=YES
CreateNewWindow=0
nonzero WindowRef
DisposeWindow
M24_SUCCESS
RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Record the exact dynamic `send=...` value and request/reply words. If the legacy inline request is not observed, stop; do not broaden the trace.

## Phase D — transfer only the new trace artifact

Transfer to Lion:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib.sha256
ppc-process-manager-createwindow-cgs-newwindow-transport-trace-snowleopard-control.log
```

Do not rebuild the PPC dylib on Lion.

## Phase E — repeat the established syscall-295 safety gate on Lion

Run the same native syscall-295 routing probe used by the prior CreateNewWindow stages and save:

```text
syscall295-probe-process-manager-createwindow-cgs-newwindow-transport-trace.log
```

Require:

```text
result=-1
errno=9
saw_sigsys=0
RESULT: PASS
```

Do not continue if this gate fails.

## Phase F — exactly one Lion passive NewWindow trace

Unset obsolete schema-audit and CFBundle live-trace variables from earlier stages. Keep the established expected kernel hash.

Set:

```sh
export ROSETTA_CGS_DOCKSERVER_BOOTSTRAP_COMPAT_MODE=lion-dockserver-v1
export ROSETTA_CGS_NEWWINDOW_TRACE_MODE=lion-passive-v1
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-createwindow-post-extras-register-v1
```

Syntax-check:

```sh
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Run the established integration runner, changing only the CoreServices dylib pair to the new passive-trace build while retaining the accepted Dock-aware CGS interposer and exact-four broker:

```sh
/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib \
  ./payload/ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-bootstrap-compat.dylib.sha256 \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker \
  ./native-distributed-notifications-createwindow-post-extras-registration-broker.sha256 \
  ./payload/lion-ppc-process-manager-createwindow-cgs-newwindow-transport-trace.log
```

Require the accepted upstream gates to remain true:

```text
session bootstrap adapter PASS
server-version compatibility PASS
CPS registration compatibility PASS
SetFrontProcess compatibility PASS
four notification registrations, zero rejects
native notification broker PASS
exact Extras fallback original=NULL fallback=NONNULL
Dock bootstrap adapter PASS with valid send right
protected hashes unchanged
```

The passive NewWindow trace must show exactly one legacy inline request:

```text
kind=CGS_CREATE_WINDOW_INLINE_LEGACY
bits=0x00001513
id=0x00007394
expectedReply=0x000073f8
option=0x00000003
recv=0x00000040
```

Preserve the exact dynamic send size, request words, Mach return, reply bits/size/id, and reply words. Do not alter the request in this run.

Expected reviewed result if Lion accepts the Mach transport but returns the legacy-facing failure is:

```text
RESULT: CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_LEGACY_REPLY_OBSERVED
```

## Phase G — return evidence and stop

Return:

```text
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib.info.txt
ppc-process-manager-coreservices-sessioninit-cps-registration-setfront-distnotify-ingress-newwindow-trace.dylib.sha256
ppc-process-manager-createwindow-cgs-newwindow-transport-trace-snowleopard-control.log
syscall295-probe-process-manager-createwindow-cgs-newwindow-transport-trace.log
lion-ppc-process-manager-createwindow-cgs-newwindow-transport-trace.log
lion-ppc-process-manager-createwindow-cgs-newwindow-transport-trace.raw.log
```

Also return any new crash/core diagnostic named by the runner. Do not return the proprietary Snow `Extras.rsrc`.

Stop after Phase G.

## Decision gate

### Legacy `0x7394 -> 0x73f8` is observed on both systems; Snow succeeds and Lion returns the existing failure

This dynamically closes attribution to the inline NewWindow legacy transaction. Compare exact request/reply words and NDR-decoded Lion status. If the payload shape remains consistent with the static audit, the next stage may be a standalone copied-buffer proof of the narrow `0x7394 -> 0x739a` / `0x73fe -> 0x73f8` ID conversion. Do not integrate that conversion before the trace is reviewed.

### Legacy request is not observed

Stop. Determine whether the live path selected the non-inline `__CGSCreateWindow` fallback; do not broaden to arbitrary CGS traffic.

### Mach transport fails

Preserve the exact Mach return and stop. Do not infer server-side MIG validation from a client-side transport failure.

### Reply ID or shape differs from the static legacy contract

Preserve the exact reply and stop. Refine the protocol model before any adapter.

### CreateNewWindow unexpectedly succeeds

Stop and preserve the full report; do not add an adapter.

## Current boundary

```text
PPC execution / Rosetta                                      -> PASS
syscall 295                                                  -> PASS
accepted pre-window compatibility stack                      -> PASS
integrated com.apple.dock.server adaptation                  -> PASS
static Snow inline NewWindow request                         -> 0x7394 / reply 0x73f8
static Lion inline NewWindow request                         -> 0x739a / reply 0x73fe
visible inline envelope/layout                               -> otherwise structurally aligned
live Snow/Lion inline NewWindow transaction                  -> next gate
next step                                                    -> passive exact 0x7394 transport trace
```

No additional XNU change is indicated.


## Observed completed result — legacy NewWindow transaction isolated

The returned Snow and Lion evidence matches the first decision branch of this experiment exactly.

Snow Leopard PPC:

~~~text
request kind             CGS_CREATE_WINDOW_INLINE_LEGACY
request / reply          0x7394 / 0x73f8
bits                     0x1513
send / receive           0x68 / 0x40
Mach result              0
reply size               0x38
CreateNewWindow          0
WindowRef                nonzero
DisposeWindow            reached
RESULT                   CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_SNOW_CONTROL_PASS
~~~

Lion translated PPC:

~~~text
request kind             CGS_CREATE_WINDOW_INLINE_LEGACY
request / reply          0x7394 / 0x73f8
bits                     0x1513
send / receive           0x68 / 0x40
visible request words    identical to Snow through offset 0x40
Mach result              0
reply size               0x24
raw result               0xd0feffff
decoded result           -304
CreateNewWindow          -304
WindowRef                null
legacy request count     1
RESULT                   CREATENEWWINDOW_CGS_NEWWINDOW_TRACE_LEGACY_REPLY_OBSERVED
~~~

The failure is therefore a normal server-side legacy NewWindow rejection after successful Mach transport, not a transport fault. Together with the completed static differential, the remaining compatibility hypothesis is the narrow generated-MIG routine-ID change from Snow 0x7394/0x73f8 to Lion native 0x739a/0x73fe.

The authoritative next procedure is:

~~~text
docs/process-manager-createwindow-cgs-newwindow-compat-protocol-adapter-experiment.md
~~~

That stage is a standalone copied-buffer policy proof with no Mach IPC. It proves ID-only request/reply conversion and preserves an error result unchanged before any live adapter is considered. No XNU change is indicated.
