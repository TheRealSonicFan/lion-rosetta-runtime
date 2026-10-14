# Post-RunApplicationEventLoop eighth distributed-notification schema audit

## Objective

Capture and decode **only the first unreviewed distributed-notification request after the already accepted exact-seven sequence** during the Lion `RunApplicationEventLoop()` timer-side-quit v2 run.

The previous guarded Lion transfer did **not** fail at the Carbon event-loop boundary. With the exact Snow-proven subject SHA-256

```text
059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7
```

Lion reached S14, dispatched the installed timer exactly once, returned from callback-side `QuitApplicationEventLoop()`, reached callback EXIT and S15, reported `fired=1`, emitted `RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS`, reached `M24_SUCCESS`, and exited the PPC subject with status 0.

The run stopped at a narrower, later protocol boundary: the exact-seven broker accepted the reviewed first seven registrations, then the active event loop emitted a new request wave. The first unreviewed request is:

```text
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_MACH_REQUEST:
  index=8
  bits=0x00001111
  id=4
  size=332
  payload=298
```

The exact-seven broker rejected request indexes 8 through 21, for 14 rejects total, and therefore ended `register=7 callback=0 rejects=14 exact=NO`. That result does **not** authorize an eighth registration rule. The next operation is to capture/decode request 8 only.

## Pinned implementation

Current runtime `main` provides:

```text
tests/native-distnotify-runapplicationeventloop-eighth-schema-audit-broker.c
scripts/build-lion-dn-runapplicationeventloop-8-schema-audit-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
```

Pinned blobs:

```text
eighth-request audit broker source    2c7c51b95c54ed2137b88a721f767b755f153574
eighth-request audit broker builder   8fc8f9e9240bac648742dbbb421acb7410e0d67f
Lion integration runner               efe82cbc140478e2749e685f9e57e42430f0dfd5
RunApplicationEventLoop subject       97e410dd71e545c393e0ce6889678a6436ff8ea1
XNU syscall-295 runner                eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

Accepted fixed identities remain:

```text
subject SHA-256
059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7

v3 CoreServices compatibility SHA-256
28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578

exact-six titlebar compatibility SHA-256
6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

HIToolbox Extras resource SHA-256
a0866d6cf2d48fac7787e8cf9e90264071642c0d39aa809636e7d478016a9197

private dyld SHA-256
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb

accepted Lion kernel SHA-256
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

## Audit broker contract

The new native broker:

- preserves the exact first-seven registration policy unchanged;
- accepts exactly those seven reviewed registrations;
- captures **only the first request after registration 7** into an audit report;
- intentionally returns status 25 for that captured request;
- rejects every later request in the same run as post-boundary tail traffic without capturing or accepting it;
- does not add any eighth allowed notification name, object, behavior, counter, or sequence;
- reports PASS only when the first seven remain exact, exactly one request-8 capture succeeds, and no unexpected pre-boundary rejection occurs.

Build ID:

```text
distributed-notifications-runapplicationeventloop-eighth-schema-audit-broker-v1
```

Audit environment variable:

```text
ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT
```

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Reuse the exact Snow-proven PPC subject; do not rebuild it on Lion.
- Keep `ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2`.
- Keep the direct no-active-loop Quit validation mode unset.
- Keep `ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1`; the audit broker preserves those exact seven registrations.
- Do not add an eighth registration policy.
- Do not inspect or accept request 9 or later in this step; the broker may count them only as post-boundary rejected tail traffic.
- Do not call `RemoveEventLoopTimer` or `DisposeEventLoopTimerUPP`.
- Do not add another Carbon/window/timer API.
- Do not broaden CGS, CoreUI, titlebar, notification, or other compatibility.
- Do not modify Rosetta, dyld, frameworks, resources, caches, or XNU.
- No kernel rebuild or reboot.
- Run the PPC subject exactly once before review.

## Phase A — update and pin

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" || exit 1

test "$(git hash-object ./tests/native-distnotify-runapplicationeventloop-eighth-schema-audit-broker.c)" = \
  "2c7c51b95c54ed2137b88a721f767b755f153574" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-8-schema-audit-broker.sh)" = \
  "8fc8f9e9240bac648742dbbb421acb7410e0d67f" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "efe82cbc140478e2749e685f9e57e42430f0dfd5" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-8-schema-audit-broker.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if Phase A fails.

## Phase B — verify the exact PPC subject and fixed payloads

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Do not rebuild any PPC payload.

## Phase C — build only the request-8 audit broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-8-schema-audit-broker.sh \
  ./dn-runapplicationeventloop-8-schema-audit-broker || exit 1
```

Require:

```text
architecture: i386
build_id=distributed-notifications-runapplicationeventloop-eighth-schema-audit-broker-v1
```

The generated `.info.txt` and `.sha256` must agree with the broker binary. Do not substitute the ordinary exact-seven broker in this audit.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-eighth-audit.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion request-8 schema audit

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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT="$PWD/payload/lion-runapplicationeventloop-eighth-schema-audit.txt"

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
  ./dn-runapplicationeventloop-8-schema-audit-broker \
  ./dn-runapplicationeventloop-8-schema-audit-broker.sha256 \
  ./payload/lion-runapplicationeventloop-eighth-schema-audit.log
```

Do not run it a second time before review.

## Acceptance discriminator

Require the unchanged subject/event-loop chain:

```text
Lion 10.7.5 / 11G63
accepted kernel SHA
exact subject SHA
SHOWWINDOW_PASS
SELECTWINDOW_PASS
ISWINDOWVISIBLE_PASS
NEWEVENTLOOPTIMERUPP_PASS
GETMAINEVENTLOOP_PASS
INSTALLEVENTLOOPTIMER_PASS
S14_BEFORE_RunApplicationEventLoop
timer callback ENTER / BEFORE_Quit / AFTER_Quit / EXIT exactly once
S15_AFTER_RunApplicationEventLoop
fired=1
RUNAPPLICATIONEVENTLOOP_TIMER_QUIT_PASS
M24_SUCCESS
PPC subject exit status 0
```

The already reviewed notification sequence must remain exact through registration 7:

```text
seventh registration index=7 allowed=5 behavior=4 publicBehavior=2 anyObject=YES counter=1
register summary = register=7 callback=0 rejects=0 exact=YES
```

Then require the new capture boundary:

```text
request index 8  bits=0x1111 id=4 size=332 payload=298
RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_CAPTURE exactly 1
intentional request-8 reject status=25 capture=YES
audit summary captures=1 failures=0 unexpectedRejects=0 postBoundaryRejects=<nonnegative> exact=YES
broker result RUNAPPLICATIONEVENTLOOP_EIGHTH_AUDIT_PASS
```

At this rejected boundary, preserve the already accepted compatibility counts observed before any request-8 policy exists:

```text
WindowBackingInfo ADAPTER_PASS count = 1
ColorProfileClient ADAPTER_PASS count = 1
ResolveColorProfile ADAPTER_PASS count = 1
OrderFront ADAPTER_PASS count = 2
all six titlebar translations = 1 each
titlebar guard rejects = 0
protected hashes unchanged
```

The runner must end:

```text
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_EIGHTH_NOTIFICATION_SCHEMA_AUDIT_PASS
```

The audit report must contain exactly one block:

```text
=== RUNAPPLICATIONEVENTLOOP_EIGHTH_REQUEST 1 BEGIN ===
binary_length=298
xml_length=...
binary_hex=...
<?xml ...>
...
=== RUNAPPLICATIONEVENTLOOP_EIGHTH_REQUEST 1 END ===
```

Request 9 and later may still be rejected and counted as `postBoundaryRejects`; they are outside this step and must not be decoded, accepted, or used to broaden policy.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-8-schema-audit-broker.info.txt
dn-runapplicationeventloop-8-schema-audit-broker.sha256
sys295-runapplicationeventloop-eighth-audit.log
payload/lion-runapplicationeventloop-eighth-schema-audit.log
payload/lion-runapplicationeventloop-eighth-schema-audit.raw.log
payload/lion-runapplicationeventloop-eighth-schema-audit.txt
```

Also return any new crash report or crash plist explicitly named by the runner. Do not upload a large core unless requested.

## Decision gate

Review the request-8 XML and exact binary bytes before deciding whether it extends a known notification tuple or introduces a new name/schema. Only the exact reviewed request may become a future compatibility policy. Do not infer request 9 or later from request 8.

## Current boundary

```text
RunApplicationEventLoop timer-side-quit Snow        LIVE-PROVEN PASS
RunApplicationEventLoop timer-side-quit Lion        semantic sequence LIVE-PROVEN through S15
exact-seven notification policy on Lion             LIVE-PROVEN through registration 7
first active-loop extra notification request        index=8 id=4 size=332 payload=298; unreviewed
request indexes 8..21 in prior run                  rejected; no policy authorized
next step                                           capture/decode request 8 only
RemoveEventLoopTimer / DisposeEventLoopTimerUPP     HELD
new compatibility families                         NO
titlebar policy broadening                         NO
XNU                                                 no source change indicated
```
