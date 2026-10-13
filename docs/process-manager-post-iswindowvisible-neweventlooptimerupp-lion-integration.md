# Post-IsWindowVisible NewEventLoopTimerUPP Lion integration

## Objective

Run exactly one guarded Lion 10.7.5 / 11G63 integration using the exact Snow-proven PPC subject that adds only `NewEventLoopTimerUPP(ProbeTimer)` after the live-proven `ShowWindow`, `SelectWindow`, and `IsWindowVisible` sequence.

The Snow control is closed:

```text
build_id=cps-neweventlooptimerupp-validation-v1
subject SHA-256=73a02dac78c61531ab1f1922011de7116f1a384ede55616c1c16bf6bc966020b
arch=ppc7400
dyld=/usr/oah/dyld
NewEventLoopTimerUPP source expression=present
linkage=sdk-lowered-no-undefined-import
ShowWindow=PASS
SelectWindow=PASS
IsWindowVisible=visible=1 / PASS
NewEventLoopTimerUPP pointer=nonzero / PASS
M24_SUCCESS=reached
control_status=0
OrderFront total / trace / passthrough=2 / 2 / 2
SelectWindow-bounded OrderFront=1
all six titlebar keys=passthrough
titlebar unexpected action=0
compatibility ADAPTER_PASS on Snow=0
final=POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_SNOW_CONTROL_PASS / PASS
```

The Snow result does not authorize a timer install or event-loop entry. It also confirms that this build does not carry an undefined `_NewEventLoopTimerUPP` symbol; that is expected for this SDK-lowered UPP construction and is not an acceptance requirement on Lion. The Lion discriminator is the subject's S06/S07 execution markers, nonzero pointer, and `NEWEVENTLOOPTIMERUPP_PASS`.

## Prepared implementation

Current runtime `main` provides the guarded Lion mode:

```text
ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=lion-neweventlooptimerupp-v1
```

Pinned runtime runner:

```text
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
07cb635cb134ee3faca42151f8b626ae9670bcb0
```

Exact Snow-proven subject:

```text
build ID   cps-neweventlooptimerupp-validation-v1
SHA-256    73a02dac78c61531ab1f1922011de7116f1a384ede55616c1c16bf6bc966020b
basename   ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
dyld       /usr/oah/dyld
arch       ppc7400
linkage    sdk-lowered-no-undefined-import
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
- Do not add a NewEventLoopTimerUPP-specific compatibility interposer.
- Do not require an undefined `_NewEventLoopTimerUPP` import.
- Do not call `GetMainEventLoop`, `InstallEventLoopTimer`, `DisposeEventLoopTimerUPP`, `RunApplicationEventLoop`, or `QuitApplicationEventLoop`.
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
  "07cb635cb134ee3faca42151f8b626ae9670bcb0" || exit 1

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

## Phase B — transfer and verify the exact Snow NewEventLoopTimerUPP subject

Copy these exact successful Snow files into Lion runtime `payload/`:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

Keep the already accepted full-stack v3 and exact-six titlebar artifacts from the IsWindowVisible integration. On Lion verify:

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "73a02dac78c61531ab1f1922011de7116f1a384ede55616c1c16bf6bc966020b" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "73a02dac78c61531ab1f1922011de7116f1a384ede55616c1c16bf6bc966020b" || exit 1

/usr/bin/grep -Fq 'build_id=cps-neweventlooptimerupp-validation-v1' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'neweventlooptimerupp_source_expression=NewEventLoopTimerUPP(ProbeTimer)' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'neweventlooptimerupp_linkage=sdk-lowered-no-undefined-import' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1

/usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
  /usr/bin/grep -Fq 'PM_CPS_CREATEWINDOW_BUILD_ID:cps-neweventlooptimerupp-validation-v1' || exit 1

for marker in \
  'PM_POSTWINDOWVISIBLE_MILESTONE:S04_BEFORE_IsWindowVisible' \
  'PM_POSTWINDOWVISIBLE_MILESTONE:S05_AFTER_IsWindowVisible' \
  'PM_POSTWINDOWVISIBLE_RESULT:ISWINDOWVISIBLE_PASS' \
  'PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP' \
  'PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP' \
  'PM_POSTWINDOWTIMERUPP_POINTER:pointer=' \
  'PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS'
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
  "$RUNTIME/sys295-neweventlooptimerupp.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

Stop if this fails.

## Phase E — exactly one Lion NewEventLoopTimerUPP run

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
  ./payload/lion-neweventlooptimerupp.log
```

Do not run it a second time before review. The raw transcript is:

```text
payload/lion-neweventlooptimerupp.raw.log
```

## Acceptance discriminator

All accepted IsWindowVisible-era predicates must remain unchanged:

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
S02_BEFORE_SelectWindow
S03_AFTER_SelectWindow
SELECTWINDOW_PASS
S04_BEFORE_IsWindowVisible
S05_AFTER_IsWindowVisible
PM_POSTWINDOWVISIBLE_VALUE:visible=1
ISWINDOWVISIBLE_PASS
```

Then require only the new UPP-creation boundary:

```text
PM_POSTWINDOWTIMERUPP_MILESTONE:S06_BEFORE_NewEventLoopTimerUPP
PM_POSTWINDOWTIMERUPP_MILESTONE:S07_AFTER_NewEventLoopTimerUPP
PM_POSTWINDOWTIMERUPP_POINTER:pointer=<nonzero> nonzero=YES
PM_POSTWINDOWTIMERUPP_RESULT:NEWEVENTLOOPTIMERUPP_PASS
M24_SUCCESS
subject exit 0
RESULT: POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_PASS
```

If S06 appears without S07, stop at the UPP-creation no-return boundary. If S07 appears but the pointer is null or the PASS marker is absent, preserve the complete raw log; do not add an adapter from that observation alone.

If any inherited compatibility count changes, an eighth notification appears, the titlebar guard rejects, or a new crash is created, stop and preserve evidence. Do not broaden compatibility.

## Return evidence

Return exactly:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-neweventlooptimerupp.log
payload/lion-neweventlooptimerupp.log
payload/lion-neweventlooptimerupp.raw.log
```

Also return any new crash report or crash plist explicitly named by the runner. Do not upload a large core unless requested.

## Reviewed Lion result

The guarded Lion 10.7.5 / 11G63 run passes completely with the exact Snow-proven subject SHA-256 `73a02dac78c61531ab1f1922011de7116f1a384ede55616c1c16bf6bc966020b`. The accepted kernel, Rosetta, private dyld, shared-cache, CoreGraphics, v3 CoreServices, exact-six titlebar, security, CGS, HIToolbox Extras, and exact-seven broker identities all match their pinned values. The fresh syscall-295 preflight again reaches the compatibility front-end and returns EBADF without SIGSYS.

After the inherited ShowWindow/SelectWindow/IsWindowVisible path succeeds, S06 and S07 both execute, `NewEventLoopTimerUPP(ProbeTimer)` returns the same nonzero pointer value `0x000021e4`, and `NEWEVENTLOOPTIMERUPP_PASS` is emitted. Cleanup reaches `M24_SUCCESS`, the PPC execution status is 0, exact-seven remains `register=7 callback=0 rejects=0 exact=YES`, all six titlebar translations occur once with zero guard rejects, WindowBackingInfo and ResolveColorProfile each preserve one successful adapter call, both OrderFront calls preserve successful adaptation with exactly one SelectWindow-bounded call, protected hashes remain unchanged, no new diagnostic is created, and the runner ends with `POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_PASS`.

This closes UPP construction as a live Lion boundary without a new compatibility rule. The historical next timer expression nests `GetMainEventLoop()` inside `InstallEventLoopTimer(...)`; to avoid conflating those two calls, current `main` advances first to the isolated Snow-only `GetMainEventLoop()` control in `docs/process-manager-post-neweventlooptimerupp-getmaineventloop-snow-control.md`. Do not install a timer or enter the event loop until that pointer-acquisition result is reviewed.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Snow                     PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop                                 NEXT: Snow control only
InstallEventLoopTimer                            HELD
RunApplicationEventLoop                         HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no change indicated
```
