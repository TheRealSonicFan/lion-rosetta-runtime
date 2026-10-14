# Post-NewEventLoopTimerUPP GetMainEventLoop Lion integration

## Objective

Run exactly one guarded Lion 10.7.5 / 11G63 integration using the exact Snow-proven PPC subject that adds only `GetMainEventLoop()` after the already live-proven `ShowWindow`, `SelectWindow`, `IsWindowVisible`, and `NewEventLoopTimerUPP(ProbeTimer)` sequence.

The Snow control is closed:

```text
build_id=cps-getmaineventloop-validation-v1
subject SHA-256=27a91765c2815bd885828a1785776cb0fa0c30f146b92d682be84b0691e724f8
arch=ppc7400
dyld=/usr/oah/dyld
NewEventLoopTimerUPP source expression=present
NewEventLoopTimerUPP linkage=sdk-lowered-no-undefined-import
GetMainEventLoop source expression=present
GetMainEventLoop linkage=undefined-import
ShowWindow=PASS
SelectWindow=PASS
IsWindowVisible=visible=1 / PASS
NewEventLoopTimerUPP pointer=nonzero / PASS
GetMainEventLoop pointer=0x0040ce70 nonzero=YES / PASS
M24_SUCCESS=reached
control_status=0
OrderFront total / trace / passthrough=2 / 2 / 2
SelectWindow-bounded OrderFront=1
all six titlebar keys=passthrough
titlebar unexpected action=0
compatibility ADAPTER_PASS on Snow=0
final=POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_SNOW_CONTROL_PASS / PASS
```

The Snow result authorizes only the same isolated `GetMainEventLoop()` boundary on Lion. It does **not** authorize `InstallEventLoopTimer`, timer firing/removal, UPP disposal, or event-loop entry.

## Prepared implementation

Current runtime `main` provides the guarded Lion mode:

```text
ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=lion-getmaineventloop-v1
```

Pinned runtime runner:

```text
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
4f899f36bc1a4a4a3ae64870d28dd5c6e5aff79f
```

Exact Snow-proven subject:

```text
source blob e4265ef2c7e7d74ec28efa94ab82d8549a08cf5d
build ID   cps-getmaineventloop-validation-v1
SHA-256    27a91765c2815bd885828a1785776cb0fa0c30f146b92d682be84b0691e724f8
basename   ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
dyld       /usr/oah/dyld
arch       ppc7400
GetMainEventLoop import _GetMainEventLoop
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
- Do not add a GetMainEventLoop-specific compatibility interposer.
- Do not require any specific EventLoopRef address; require only nonzero.
- Do not call `InstallEventLoopTimer`, `RemoveEventLoopTimer`, `DisposeEventLoopTimerUPP`, `RunApplicationEventLoop`, or `QuitApplicationEventLoop`.
- Do not add another public Carbon/window operation.
- Do not patch CoreUI, HIToolbox, CoreGraphics, ArtFile resources, Rosetta, dyld, caches, launchd, WindowServer, or XNU.
- Repeat the fresh syscall-295 preflight before the PPC run.
- Execute the new PPC subject exactly once on Lion, then stop for review.
- If a new crash report/plist is produced, preserve it; do not upload a large core unless requested.

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
  "4f899f36bc1a4a4a3ae64870d28dd5c6e5aff79f" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-getmaineventloop.c)" = \
  "e4265ef2c7e7d74ec28efa94ab82d8549a08cf5d" || exit 1

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

## Phase B — transfer and verify the exact Snow GetMainEventLoop subject

Copy these exact successful Snow files into Lion runtime `payload/`:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Keep the already accepted full-stack v3 and exact-six titlebar artifacts from the NewEventLoopTimerUPP integration. On Lion verify:

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "27a91765c2815bd885828a1785776cb0fa0c30f146b92d682be84b0691e724f8" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "27a91765c2815bd885828a1785776cb0fa0c30f146b92d682be84b0691e724f8" || exit 1

/usr/bin/grep -Fq 'build_id=cps-getmaineventloop-validation-v1' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'getmaineventloop_source_expression=GetMainEventLoop()' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'getmaineventloop_linkage=undefined-import' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq '_GetMainEventLoop' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1

/usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
  /usr/bin/grep -Fq 'PM_CPS_CREATEWINDOW_BUILD_ID:cps-getmaineventloop-validation-v1' || exit 1

for marker in \
  'PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP' \
  'PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP' \
  'PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS' \
  'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S08_BEFORE_GetMainEventLoop' \
  'PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S09_AFTER_GetMainEventLoop' \
  'PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=' \
  'PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS'
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
  "$RUNTIME/sys295-getmaineventloop.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

Stop if this fails.

## Phase E — exactly one Lion GetMainEventLoop run

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
  ./payload/lion-getmaineventloop.log
```

Do not run it a second time before review. The raw transcript is:

```text
payload/lion-getmaineventloop.raw.log
```

## Acceptance discriminator

All accepted NewEventLoopTimerUPP-era predicates must remain unchanged:

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
OrderFront index 1 exact success
OrderFront index 2 exact success

all six exact titlebar translations present
titlebar guard reject count = 0

S01_AFTER_ShowWindow
SHOWWINDOW_PASS
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
S05_AFTER_IsWindowVisible
PM_POSTWINDOWVISIBLE_VALUE:visible=1
ISWINDOWVISIBLE_PASS
S06_BEFORE_NewEventLoopTimerUPP
S07_AFTER_NewEventLoopTimerUPP
PM_POSTWINDOWTIMERUPP_POINTER:pointer=<nonzero> nonzero=YES
NEWEVENTLOOPTIMERUPP_PASS
```

Then require only the new main-event-loop boundary:

```text
PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S08_BEFORE_GetMainEventLoop
PM_POSTWINDOWMAINEVENTLOOP_MILESTONE:S09_AFTER_GetMainEventLoop
PM_POSTWINDOWMAINEVENTLOOP_POINTER:pointer=<nonzero> nonzero=YES
PM_POSTWINDOWMAINEVENTLOOP_RESULT:GETMAINEVENTLOOP_PASS
M24_SUCCESS
subject exit 0
RESULT: POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_PASS
```

If S08 appears without S09, stop at the `GetMainEventLoop` no-return boundary. If S09 appears but the pointer is null or the PASS marker is absent, preserve the complete raw log; do not add an adapter from that observation alone.

If any inherited compatibility count changes, an eighth notification appears, the titlebar guard rejects, or a new crash is created, stop and preserve evidence. Do not broaden compatibility.

## Return evidence

Return exactly:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-getmaineventloop.log
payload/lion-getmaineventloop.log
payload/lion-getmaineventloop.raw.log
```

Also return any new crash report or crash plist explicitly named by the runner. Do not upload a large core unless requested.

## Reviewed Lion result

The guarded Lion 10.7.5 / 11G63 `GetMainEventLoop()` run passes completely with the exact Snow-proven subject SHA-256 `27a91765c2815bd885828a1785776cb0fa0c30f146b92d682be84b0691e724f8`. The accepted kernel, Rosetta, private dyld, shared-cache, CoreGraphics, v3 CoreServices, exact-six titlebar, security, CGS, HIToolbox Extras, and exact-seven broker identities all match their pinned values. The fresh syscall-295 preflight again reaches the compatibility front-end and returns EBADF without SIGSYS.

After the inherited ShowWindow/SelectWindow/IsWindowVisible/NewEventLoopTimerUPP path succeeds, S08 and S09 both execute, `GetMainEventLoop()` returns the nonzero EventLoopRef `0x004a6da0`, and `GETMAINEVENTLOOP_PASS` is emitted. Cleanup reaches `M24_SUCCESS`, the PPC execution status is 0, exact-seven remains `register=7 callback=0 rejects=0 exact=YES`, all six titlebar translations occur once with zero guard rejects, WindowBackingInfo and ResolveColorProfile each preserve one successful adapter call, both OrderFront calls preserve successful adaptation with exactly one SelectWindow-bounded call, protected hashes remain unchanged, no new diagnostic is created, and the runner ends with `POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_PASS`.

This closes main-event-loop acquisition as a live Lion boundary without a new compatibility rule. The subsequent Snow-first and guarded Lion `InstallEventLoopTimer` stages also pass with exact subject SHA-256 `e2716844ad59ceb12319a63446e876f4a274276e320b2ec80656aad25a1e040d`; Lion returns status 0 and nonzero EventLoopTimerRef `0x00333db0`, keeps callback `fired=0`, reaches `M24_SUCCESS`, preserves exact-seven and the accepted user-space stack, and ends with `POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_PASS`. Current `main` therefore advances to `docs/process-manager-post-installeventlooptimer-quitapplicationeventloop-snow-control.md`, which isolates only the direct `QuitApplicationEventLoop()` call/return boundary on Snow before application-event-loop entry is attempted. `RunApplicationEventLoop`, timer callback dispatch, `RemoveEventLoopTimer`, and `DisposeEventLoopTimerUPP` remain held.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Snow                         PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Snow                    PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop                         NEXT: Snow call/return control only
RunApplicationEventLoop                         HELD
timer callback dispatch                         HELD
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
