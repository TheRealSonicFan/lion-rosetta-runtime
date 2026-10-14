# Post-QuitApplicationEventLoop RunApplicationEventLoop Lion integration — timer-side quit v2

## Objective

Transfer the **exact Snow-proven** `RunApplicationEventLoop()` timer-side-quit v2 subject to Lion and perform one guarded Lion integration run.

The Snow control is now closed PASS with subject SHA-256:

```text
059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7
```

Its source SHA-256 and build identity are:

```text
source_sha256=b5f2c461a93c3cdb6bc9601b7540abba9f622ba3e70d46c736b361ad5051d166
build_id=cps-runapplicationeventloop-timer-quit-validation-v2
```

Snow proves the complete timer-side-quit sequence with no new compatibility behavior:

```text
InstallEventLoopTimer status=0
EventLoopTimerRef=<nonzero>
PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=0
INSTALLEVENTLOOPTIMER_PASS

S14_BEFORE_RunApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:ENTER
PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:EXIT
S15_AFTER_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1
RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS

M24_SUCCESS
control_status=0
OrderFront calls/traces/passthrough = 3/3/3
SelectWindow-bounded OrderFront = 1
RunApplicationEventLoop-bounded OrderFront = 1
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_SNOW_CONTROL_PASS
RESULT: PASS
```

The Snow run also shows exactly one additional `WindowBackingInfo` call between S14 and S15. The guarded Lion runner therefore preserves the already accepted first WBI call and, only in this v2 mode, requires exactly one additional S14-to-S15 WBI call to pass the existing `lion-id-v1` adapter. `ResolveColorProfile` remains at its accepted Lion count of one.

This stage introduces no new public Carbon API beyond the already Snow-proven `RunApplicationEventLoop()`. It transfers the exact Snow-proven contextual behavior: one installed timer callback dispatch, callback-side `QuitApplicationEventLoop()`, callback return, then `RunApplicationEventLoop()` return.

## Pinned implementation

Current runtime `main` provides:

```text
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/native-dn-showwindow-7-registration-broker.c
scripts/build-lion-dn-showwindow-7-registration-broker.sh
```

The historical subject filename is retained for continuity; the compiled configuration is timer-side-quit v2.

Pinned blobs:

```text
RunApplicationEventLoop subject source  97e410dd71e545c393e0ce6889678a6436ff8ea1
Lion integration runner                 2423cd2cad6904548619cbee23c00509eb94d3cc
exact-seven broker source               9d137becc45bac476fa70218db4839b28be0e219
exact-seven broker builder              d909dd6a3eba657854feb8d09bf2793c33a2bea9
XNU syscall-295 runner                  eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

Accepted fixed artifacts remain:

```text
v3 CoreServices compatibility SHA-256
28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578

exact-six titlebar compatibility SHA-256
6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

exact-seven broker SHA-256
7360bcd68e0b5bc473540143e1bd7fb1cb1544a60f530d1c2f6df57469db46a9

HIToolbox Extras resource SHA-256
a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197

private dyld SHA-256
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb

accepted Lion kernel SHA-256
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Transfer the exact Snow-proven v2 subject; do not rebuild it on Lion.
- Do not set `ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE`; the direct no-active-loop quit stage is already closed.
- Set only the new mode `lion-runapplicationeventloop-timer-quit-v2` on top of the accepted InstallEventLoopTimer-era Lion stack.
- Keep the exact-seven notification broker and exact-six titlebar policy unchanged.
- Keep all accepted Lion CGS compatibility modes unchanged; the runner only tightens expected call counts/scopes for behavior already observed on Snow.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add another Carbon/window/timer API.
- Do not broaden compatibility or titlebar policy from this run.
- Do not modify Rosetta, dyld, frameworks, resources, caches, or XNU.
- No kernel rebuild or reboot.
- Run exactly once before review.
- If S14 appears but the callback ENTER marker does not appear within 10 seconds, interrupt externally, preserve the raw log, and stop.
- If callback ENTER appears but callback AFTER_Quit or EXIT does not appear, preserve the raw log and stop.

## Phase A — update and pin

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "2423cd2cad6904548619cbee23c00509eb94d3cc" || exit 1

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

## Phase B — transfer and verify the exact Snow-proven v2 subject

Copy these exact successful Snow files into Lion runtime `payload/`:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
```

On Lion:

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1

/usr/bin/grep -Fq 'source_sha256=b5f2c461a93c3cdb6bc9601b7540abba9f622ba3e70d46c736b361ad5051d166' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'build_id=cps-runapplicationeventloop-timer-quit-validation-v2' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'quitapplicationeventloop_context=installed-timer-callback-while-runapplicationeventloop-active' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'runapplicationeventloop_exit_condition=installed-timer-callback-calls-QuitApplicationEventLoop' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq 'runapplicationeventloop_callback_contract=exactly-one-callback-before-return' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq '_QuitApplicationEventLoop' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1
/usr/bin/grep -Fq '_RunApplicationEventLoop' \
  ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.info.txt || exit 1

/usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
  /usr/bin/grep -Fq 'PM_CPS_CREATEWINDOW_BUILD_ID:cps-runapplicationeventloop-timer-quit-validation-v2' || exit 1

for marker in \
  'PM_POSTWINDOWTIMERINSTALL_RESULT:INSTALLEVENTLOOPTIMER_PASS' \
  'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop' \
  'PM_POSTWINDOWTIMER_CALLBACK:ENTER' \
  'PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop' \
  'PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop' \
  'PM_POSTWINDOWTIMER_CALLBACK:EXIT' \
  'PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop' \
  'PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=' \
  'PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS'
do
  /usr/bin/strings ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | \
    /usr/bin/grep -Fq "$marker" || exit 1
done

test "$(/usr/bin/shasum -a 256 ./payload/pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Do not rebuild the subject or either compatibility dylib.

## Phase C — rebuild the exact-seven native broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-showwindow-7-registration-broker.sh \
  ./dn-showwindow-7-registration-broker || exit 1

test "$(/usr/bin/shasum -a 256 ./dn-showwindow-7-registration-broker | /usr/bin/awk '{print $1}')" = \
  "7360bcd68e0b5bc473540143e1bd7fb1cb1544a60f530d1c2f6df57469db46a9" || exit 1
```

Require i386 and build ID:

```text
distributed-notifications-showwindow-seventh-registration-broker-v1
```

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-timer-quit.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

Stop if this fails.

## Phase E — exactly one Lion timer-side-quit v2 integration

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
unset ROSETTA_POST_INSTALLEVENTLOOPTIMER_QUITAPPLICATIONEVENTLOOP_VALIDATION_MODE

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=lion-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=lion-showwindow-v1
export ROSETTA_POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_MODE=lion-selectwindow-v1
export ROSETTA_POST_SELECTWINDOW_ISWINDOWVISIBLE_VALIDATION_MODE=lion-iswindowvisible-v1
export ROSETTA_POST_ISWINDOWVISIBLE_NEWEVENTLOOPTIMERUPP_VALIDATION_MODE=lion-neweventlooptimerupp-v1
export ROSETTA_POST_NEWEVENTLOOPTIMERUPP_GETMAINEVENTLOOP_VALIDATION_MODE=lion-getmaineventloop-v1
export ROSETTA_POST_GETMAINEVENTLOOP_INSTALLEVENTLOOPTIMER_VALIDATION_MODE=lion-installeventlooptimer-v1
export ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2

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
  ./payload/lion-runapplicationeventloop-timer-quit.log
```

Do not run it a second time before review. The raw transcript is:

```text
payload/lion-runapplicationeventloop-timer-quit.raw.log
```

## Acceptance discriminator

All inherited Lion predicates must remain accepted:

```text
Lion 10.7.5 / 11G63
accepted kernel SHA
subject SHA-256=059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7
private dyld exact
v3 CoreServices exact
exact-six titlebar exact
HIToolbox Extras resource exact

exact-seven broker PASS
register=7 callback=0 rejects=0 exact=YES
no eighth notification request

SHOWWINDOW_PASS
SELECTWINDOW_PASS
ISWINDOWVISIBLE_PASS
NEWEVENTLOOPTIMERUPP_PASS
GETMAINEVENTLOOP_PASS
InstallEventLoopTimer=0
EventLoopTimerRef=<nonzero>
PM_POSTWINDOWTIMERINSTALL_CALLBACK:fired=0
INSTALLEVENTLOOPTIMER_PASS
```

Then require the transferred Snow-proven event-loop sequence:

```text
PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S14_BEFORE_RunApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:ENTER
PM_POSTWINDOWTIMER_CALLBACK:BEFORE_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:AFTER_QuitApplicationEventLoop
PM_POSTWINDOWTIMER_CALLBACK:EXIT
PM_POSTWINDOWEVENTLOOPRUN_MILESTONE:S15_AFTER_RunApplicationEventLoop
PM_POSTWINDOWEVENTLOOPRUN_CALLBACK:fired=1
PM_POSTWINDOWEVENTLOOPRUN_RESULT:RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS

runapplicationeventloop_timer_callback_enter_count=1
runapplicationeventloop_timer_callback_before_quit_count=1
runapplicationeventloop_timer_callback_after_quit_count=1
runapplicationeventloop_timer_callback_exit_count=1
```

The accepted compatibility counts for this stage are narrowly scoped:

```text
WindowBackingInfo calls / ADAPTER_PASS / passthrough = 2 / 2 / 0
RunApplicationEventLoop-bounded WindowBackingInfo = 1
ResolveColorProfile calls / ADAPTER_PASS / passthrough = 1 / 1 / 0
ColorProfileClient accepted success

OrderFront calls / traces / ADAPTER_PASS = 3 / 3 / 3
SelectWindow-bounded OrderFront = 1
RunApplicationEventLoop-bounded OrderFront = 1

all six exact titlebar translations present
titlebar guard reject count = 0
```

Finally require:

```text
M24_SUCCESS
PPC subject exit status 0
protected hashes unchanged
no new diagnostic
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_VALIDATION_PASS
```

There must be no legacy `PM_POSTWINDOWTIMER_CALLBACK:FIRED`, no callback-count mismatch, no unexpected compatibility passthrough for WBI/Resolve/OrderFront, no eighth notification request, and no protected-hash change.

Failure classification:

- S14 absent: inherited regression; stop.
- S14 present but callback ENTER absent after 10 seconds: Lion event-loop/timer-dispatch boundary; interrupt externally and preserve evidence.
- callback ENTER present but BEFORE_Quit absent: callback-body failure before the already proven quit call.
- BEFORE_Quit present but AFTER_Quit absent: active-loop callback-side `QuitApplicationEventLoop` no-return boundary.
- callback EXIT present but S15 absent: `RunApplicationEventLoop` no-return boundary after callback-side quit.
- WBI total not exactly two, or S14-to-S15 WBI count not exactly one: preserve evidence; do not broaden the adapter.
- OrderFront total not exactly three, or S14-to-S15 OrderFront count not exactly one: preserve evidence; do not broaden the adapter.
- Any new diagnostic, unexpected notification, protected-hash change, or new compatibility behavior: stop and preserve evidence.

## Return evidence

Return exactly:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-runapplicationeventloop-timer-quit.log
payload/lion-runapplicationeventloop-timer-quit.log
payload/lion-runapplicationeventloop-timer-quit.raw.log
```

Also return any new crash report or crash plist explicitly named by the runner. Do not upload a large core unless requested.

## Reviewed Lion result — Carbon semantics pass; request 8 is the new boundary

The exact Snow-proven v2 subject ran on Lion 10.7.5 / 11G63 with exact SHA-256 `059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7` and the accepted kernel. The fresh syscall-295 probe again returned EBADF without SIGSYS.

The inherited ShowWindow / SelectWindow / IsWindowVisible / NewEventLoopTimerUPP / GetMainEventLoop / InstallEventLoopTimer sequence passed. Lion then reached S14, dispatched the installed timer exactly once, returned from callback-side `QuitApplicationEventLoop()`, reached callback EXIT and S15, reported `fired=1`, emitted `RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS`, reached `M24_SUCCESS`, and the PPC subject exited 0. All six titlebar translations remained exact, no new diagnostic was created, and protected hashes remained unchanged.

The integration did not reach the planned final runner PASS because active event-loop processing exposed a later distributed-notification boundary. The exact-seven broker accepted the reviewed seven registrations, then request indexes 8 through 21 appeared and were rejected. The first unreviewed request has legacy Mach geometry `index=8 bits=0x00001111 id=4 size=332 payload=298`. The broker therefore ended `register=7 callback=0 rejects=14 exact=NO`, and the runner correctly classified `POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_PASS_EIGHTH_PROTOCOL_REJECTED`.

This is not evidence of a `RunApplicationEventLoop`, timer-callback, callback-side Quit, or XNU failure. It also does not authorize the previously predicted extra Lion WBI/OrderFront calls: with request 8 still rejected, this run preserved only the already accepted WBI count of one and OrderFront adapter count of two. Current `main` now advances to `docs/process-manager-post-runapplicationeventloop-eighth-notification-schema-audit.md`, which accepts only the existing seven registrations, captures/decode request 8, and rejects all later tail traffic without adding a notification policy.

## Current boundary

```text
ShowWindow on Lion                               LIVE-PROVEN PASS
SelectWindow on Lion                             LIVE-PROVEN PASS
IsWindowVisible on Lion                          LIVE-PROVEN PASS
NewEventLoopTimerUPP on Lion                     LIVE-PROVEN PASS
GetMainEventLoop on Lion                         LIVE-PROVEN PASS
InstallEventLoopTimer on Lion                    LIVE-PROVEN PASS
QuitApplicationEventLoop direct/no-active-loop   LIVE-PROVEN PASS on Snow + Lion
RunApplicationEventLoop timer-side-quit v2 Snow  LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit v2 Lion  semantic sequence LIVE-PROVEN through S15
timer callback dispatch on Lion                  LIVE-PROVEN PASS in v2 context
active-loop callback-side Quit on Lion           LIVE-PROVEN PASS in v2 context
exact-seven notification policy                 LIVE-PROVEN through registration 7
request 8 after event-loop activation            unreviewed; NEXT schema audit
RemoveEventLoopTimer / DisposeEventLoopTimerUPP  HELD
new compatibility families                      NO
titlebar policy broadening                      NO
XNU                                              no source change indicated
```
