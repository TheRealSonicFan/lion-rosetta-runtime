# Post-InstallEventLoopTimer QuitApplicationEventLoop Lion integration

## Objective

Run exactly one guarded Lion 10.7.5 / 11G63 integration using the exact Snow-proven PPC subject that adds only a direct `QuitApplicationEventLoop()` call after the already live-proven ShowWindow / SelectWindow / IsWindowVisible / NewEventLoopTimerUPP / GetMainEventLoop / InstallEventLoopTimer sequence.

The Snow control is closed:

```text
build_id=cps-quitapplicationeventloop-validation-v1
subject SHA-256=af36d6efe9e3193c3b68ac149d50be5627f1ba33ad0c5223e2ed1bdf3982eb01
arch=ppc7400
dyld=/usr/oah/dyld
QuitApplicationEventLoop source expression=present
QuitApplicationEventLoop linkage=undefined-import
context=no-active-application-event-loop
InstallEventLoopTimer status=0
EventLoopTimerRef=0x0041f400 nonzero=YES
timer callback before/after quit call=0
S12_BEFORE_QuitApplicationEventLoop=reached
S13_AFTER_QuitApplicationEventLoop=reached
QuitApplicationEventLoop=PASS
M24_SUCCESS=reached
control_status=0
OrderFront total / trace / passthrough=2 / 2 / 2
SelectWindow-bounded OrderFront=1
all six titlebar keys=passthrough
titlebar unexpected action=0
compatibility ADAPTER_PASS on Snow=0
final=POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_SNOW_CONTROL_PASS / PASS
```

The Snow result authorizes only the same no-active-loop `QuitApplicationEventLoop()` call/return boundary on Lion. It does **not** authorize `RunApplicationEventLoop`, timer callback dispatch, active-loop quit semantics, `RemoveEventLoopTimer`, or `DisposeEventLoopTimerUPP`.

## Prepared implementation

Current runtime `main` provides:

```text
ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-quitapplicationeventloop-v1
```

Pinned runtime runner:

```text
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
f03e5182acee1366425e9cee513f12b2bf11347f
```

Exact Snow-proven subject:

```text
source blob fb836df7a60cb1d9c1c9b3db8284eb27586bc2b4
source SHA-256 4ced526da2e647c6627d5f9f610f8bb94668f6605ea7464a4ad3f50a5d103810
build ID cps-quitapplicationeventloop-validation-v1
SHA-256 af36d6efe9e3193c3b68ac149d50be5627f1ba33ad0c5223e2ed1bdf3982eb01
basename ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
dyld /usr/oah/dyld
arch ppc7400
imports _GetMainEventLoop, _InstallEventLoopTimer, _QuitApplicationEventLoop
```

Accepted compatibility artifacts remain unchanged:

```text
v3 full-stack CoreServices artifact
  28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578

exact-six titlebar artifact
  6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

exact-seven broker
  build ID distributed-notifications-showwindow-seventh-registration-broker-v1
  SHA-256 7360bcd68e0b5bc473540143e1bd7fb1cb1544a60f530d1c2f6df57469db46a9
```

## Safety constraints

- Do not alter any compatibility rule, request/reply mapping, titlebar key, notification count, or protected system file.
- Do not add a QuitApplicationEventLoop-specific compatibility interposer.
- Do not call `RunApplicationEventLoop`; no application event loop may be active in this stage.
- Do not deliberately dispatch the timer callback.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not infer active-loop quit behavior from this no-active-loop call/return control.
- Do not add another public Carbon/window/timer operation.
- Do not patch CoreUI, HIToolbox, CoreGraphics, ArtFile resources, Rosetta, dyld, caches, launchd, WindowServer, or XNU.
- Repeat the fresh syscall-295 preflight before the PPC run.
- Execute the new PPC subject exactly once on Lion, then stop for review.
- Preserve any new crash report/plist; do not upload a large core unless requested.

## Phase A — update and pin repositories

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "f03e5182acee1366425e9cee513f12b2bf11347f" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-quitapplicationeventloop.c)" = \
  "fb836df7a60cb1d9c1c9b3db8284eb27586bc2b4" || exit 1

test "$(git hash-object ./tests/native-dn-showwindow-7-registration-broker.c)" = \
  "9d137becc45bac476fa70218db4839b28be0e219" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-showwindow-7-registration-broker.sh)" = \
  "d909dd6a3eba657854feb8d09bf2793c33a2bea9" || exit 1

/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1
/bin/bash -n ./scripts/build-lion-dn-showwindow-7-registration-broker.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if Phase A fails.

## Phase B — transfer and verify the exact Snow QuitApplicationEventLoop subject

Copy these exact successful Snow files into Lion runtime `payload/`:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

On Lion verify:

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "af36d6efe9e3193c3b68ac149d50be5627f1ba33ad0c5223e2ed1bdf3982eb01" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "af36d6efe9e3193c3b68ac149d50be5627f1ba33ad0c5223e2ed1bdf3982eb01" || exit 1

/usr/bin/grep -Fq 'build_id=cps-quitapplicationeventloop-validation-v1' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'quitapplicationeventloop_source_expression=QuitApplicationEventLoop()' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'quitapplicationeventloop_linkage=undefined-import' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'quitapplicationeventloop_context=no-active-application-event-loop' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq '_QuitApplicationEventLoop' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1

/usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
  /usr/bin/grep -Fq 'PM_CPS_CREATEWINDOW_BUILD_ID:cps-quitapplicationeventloop-validation-v1' || exit 1

for marker in \
  'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS' \
  'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S12_BEFORE_QuitApplicationEventLoop' \
  'PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S13_AFTER_QuitApplicationEventLoop' \
  'PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=' \
  'PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS'
do
  /usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
    /usr/bin/grep -Fq "$marker" || exit 1
done

test "$(/usr/bin/shasum -a 256 ./payload/pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Do not rebuild either compatibility dylib.

## Phase C — rebuild the exact-seven native broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-showwindow-7-registration-broker.sh \
  ./dn-showwindow-7-registration-broker || exit 1

test "$(/usr/bin/shasum -a 256 ./dn-showwindow-7-registration-broker | /usr/bin/awk '{print $1}')" = \
  "7360bcd68e0b5bc473540143e1bd7fb1cb1544a60f530d1c2f6df57469db46a9" || exit 1
```

Require i386 and build ID `distributed-notifications-showwindow-seventh-registration-broker-v1`.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-quitapplicationeventloop.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

Stop if this fails.

## Phase E — exactly one Lion QuitApplicationEventLoop run

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_PATH
unset ROSETTA_HITOOLBOX_CFBUNDLE_TRACE_SHA256_FILE

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=lion-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=lion-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=lion-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=lion-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=lion-installeventlooptimer-v1
export ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-quitapplicationeventloop-v1

export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=lion-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=lion-inline-id-v1
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=lion-selectwindow-id-v1
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

export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=lion-exact-six-v1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256 \
  ./payload/pm-selectwindow-orderfront-compat.dylib \
  ./payload/pm-selectwindow-orderfront-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./dn-showwindow-7-registration-broker \
  ./dn-showwindow-7-registration-broker.sha256 \
  ./payload/lion-quitapplicationeventloop.log
```

Do not run it a second time before review. The raw transcript is:

```text
payload/lion-quitapplicationeventloop.raw.log
```

## Acceptance discriminator

All accepted InstallEventLoopTimer-era predicates must remain unchanged:

```text
Lion 10.7.5 / 11G63
accepted kernel SHA
exact-seven broker PASS
register=7 callback=0 rejects=0 exact=YES
no eighth notification request

WindowBackingInfo: exactly 1 call / 1 ADAPTER_PASS / 0 passthrough
ResolveColorProfile: exactly 1 call / 1 ADAPTER_PASS / 0 passthrough
ColorProfileClient accepted success

OrderFront calls / traces / adapter passes = 2 / 2 / 2
SelectWindow-bounded OrderFront call count = 1

all six exact titlebar translations present
titlebar guard reject count = 0

SHOWWINDOW_PASS
SELECTWINDOW_PASS
ISWINDOWVISIBLE_PASS
NEWEVENTLOOPTIMERUPP_PASS
GETMAINEVENTLOOP_PASS
InstallEventLoopTimer status=0
EventLoopTimerRef=<nonzero> nonzero=YES
PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=0
INSTALLEVENTLOOPTIMER_PASS
```

Then require only the new quit-call boundary:

```text
PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S12_BEFORE_QuitApplicationEventLoop
PM_POSTWINDOWEVENTLOOPQUIT_MILESTONE:S13_AFTER_QuitApplicationEventLoop
PM_POSTWINDOWEVENTLOOPQUIT_CALLBACK:fired=0
PM_POSTWINDOWEVENTLOOPQUIT_RESULT:QUITAPPLICATIONEVENTLOOP_PASS
M24_SUCCESS
subject exit 0
RESULT: POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_PASS
```

There must be no `PM_POSTWINDOWTIMER_CALLBACK:FIRED`, no unexpected-callback result, no new diagnostic, no eighth notification request, and no protected-hash change.

If S12 appears without S13, stop at the `QuitApplicationEventLoop` no-return boundary. If S13 appears but callback state changes or the PASS marker is missing, preserve the complete raw log; do not add an adapter from that observation alone.

## Return evidence

Return exactly:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-quitapplicationeventloop.log
payload/lion-quitapplicationeventloop.log
payload/lion-quitapplicationeventloop.raw.log
```

Also return any new crash report or crash plist explicitly named by the runner. Do not upload a large core unless requested.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop on Snow                 PASS (no-active-loop call/return)
QuitApplicationEventLoop on Lion                 NEXT: one guarded no-active-loop run
timer callback dispatch                         HELD
RunApplicationEventLoop                         HELD
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
