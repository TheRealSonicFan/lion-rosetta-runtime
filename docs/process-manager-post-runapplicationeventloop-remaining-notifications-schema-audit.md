# Post-RunApplicationEventLoop remaining distributed-notification schema audit

## Objective

Audit the **entire remaining observed notification-registration wave in one Lion run** while preserving the exact reviewed first-thirteen registrations and every inherited compatibility gate.

The exact request-13 registration is live-proven. In that run, eight later request frames remained after registration 13: request indexes 14 through 21. Every one was rejected with status 25 by the exact-thirteen broker, which means the observed frames traversed the registration path but used names outside the reviewed allowlist. Their full plist schemas remain unreviewed and must not be accepted yet.

This procedure therefore captures all eight remaining requests, requests 14–21, into one audit report and deliberately rejects every one after capture. It does **not** authorize any of them.

## Why this supersedes the request-14-only rerun

The first attempt at the request-14-only Phase E did not launch the PPC subject. The integration report stopped at:

```text
ERROR: broker build marker missing
```

The broker itself was built successfully as i386 and its SHA sidecar matched. The failure was in runner control flow: the request-14 audit validation block had accidentally split the broker-selection `if/elif` chain, so the later base-registration branch overwrote `EXPECTED_BROKER_BUILD_ID` with the exact-seven broker ID. The runner has now been corrected.

Because no PPC subject execution occurred and the previous exact-thirteen run already established a stable eight-request tail, there is no evidence-based reason to continue auditing those eight registrations one at a time. The safer acceleration is one **capture-only** run for the complete remaining wave, followed by review of all eight returned plists. Only after that review may a combined exact registration policy be prepared.

## Known remaining wave

The last live exact-thirteen run observed:

```text
request 14  bits=0x00001111 id=4 size=336 payload=302
request 15  bits=0x00001111 id=4 size=364 payload=332
request 16  bits=0x00001111 id=4 size=364 payload=329
request 17  bits=0x00001111 id=4 size=336 payload=301
request 18  bits=0x00001111 id=4 size=336 payload=304
request 19  bits=0x00001111 id=4 size=336 payload=302
request 20  bits=0x00001111 id=4 size=336 payload=303
request 21  bits=0x00001111 id=4 size=320 payload=286
```

These geometries are transport observations only. Do not infer names, objects, behaviors, counters, session values, or any other plist field from payload length.

## Pinned implementation

Current runtime `main` provides:

```text
tests/native-distnotify-runapplicationeventloop-remaining-schema-audit-broker.c
scripts/build-lion-dn-runapplicationeventloop-remaining-schema-audit-broker.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c
```

Pinned blobs:

```text
remaining-wave audit broker source      a46ddbfafa4faa681bf0d614472f45521626518e
remaining-wave audit broker builder     46469bfadbf0895d664f3f93ddc171ac6505be3d
Lion integration runner                 c484d0f49667d9ebbc521ca50867fd48a76f84c0
RunApplicationEventLoop subject         97e410dd71e545c393e0ce6889678a6436ff8ea1
XNU syscall-295 runner                  eaecc9bfbf4d780664c7e66471a832a0289aebb6
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

## Remaining-wave audit broker contract

Build ID:

```text
distributed-notifications-runapplicationeventloop-remaining-schema-audit-broker-v1
```

The broker accepts the exact reviewed first-thirteen registration sequence, including:

```text
registration 12 -> allowed 10 / AppleLanguagePreferencesChangedNotification / AnyObject / behavior 4 / counter 1
registration 13 -> allowed 11 / AppleKeyboardMenuPreferencesChangedNotification / AnyObject / behavior 4 / counter 1
```

After registration 13, the broker captures exactly eight subsequent binary plists into the audit report, labels them request indexes 14 through 21, and deliberately returns status 25 for each. It will not register any of those eight. Any ninth post-boundary request is treated as unexpected tail traffic and makes the audit non-exact.

Required final broker state:

```text
register=13
callback=0
rejects=0
audit captures=8
audit failures=0
unexpected rejects=0
post-boundary tail rejects=0
exact=YES
```

## Safety constraints

- Lion 10.7.5 / 11G63 only.
- Reuse the exact Snow-proven PPC subject; do not rebuild it on Lion.
- Keep `ROSETTA_POST_QUITAPPLICATIONEVENTLOOP_RUNAPPLICATIONEVENTLOOP_VALIDATION_MODE=lion-runapplicationeventloop-timer-quit-v2`.
- Keep the reviewed first-seven base mode exactly `lion-showwindow-seventh-register-v1`.
- Enable only `ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_SCHEMA_AUDIT_REPORT` for this audit.
- Keep all request-8 through request-14 single-request schema-audit modes unset.
- Keep exact-eight through exact-thirteen registration modes unset.
- Preserve the reviewed first thirteen exactly.
- Capture requests 14–21; reject every captured request.
- Do not accept request 14–21 in this step.
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

test "$(git hash-object ./tests/native-distnotify-runapplicationeventloop-remaining-schema-audit-broker.c)" = \
  "a46ddbfafa4faa681bf0d614472f45521626518e" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-runapplicationeventloop-remaining-schema-audit-broker.sh)" = \
  "46469bfadbf0895d664f3f93ddc171ac6505be3d" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "c484d0f49667d9ebbc521ca50867fd48a76f84c0" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-postidentity-runapplicationeventloop-prequeued-quit.c)" = \
  "97e410dd71e545c393e0ce6889678a6436ff8ea1" || exit 1

/bin/bash -n ./scripts/build-lion-dn-runapplicationeventloop-remaining-schema-audit-broker.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
test "$(git hash-object ./tools/run_syscall295_probe.sh)" = \
  "eaecc9bfbf4d780664c7e66471a832a0289aebb6" || exit 1
```

Stop if Phase A fails.

## Phase B — verify the exact PPC subject

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "059341612986721ef8e513c247b3ba39cf34892f25bad3c73dc2ef97ca8102b7" || exit 1
```

Do not rebuild the PPC subject.

## Phase C — build only the remaining-wave audit broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-runapplicationeventloop-remaining-schema-audit-broker.sh \
  ./dn-runapplicationeventloop-remaining-schema-audit-broker || exit 1
```

Require i386, the exact build ID above, exact policies through request 13, the reviewed request-13 notification literal, the remaining-wave capture/reject/summary markers, and matching binary/info/SHA sidecars.

## Phase D — fresh syscall-295 preflight

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-runapplicationeventloop-remaining-audit.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase E — exactly one Lion remaining-wave schema-audit run

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_FOURTEENTH_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_EIGHTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_NINTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_ELEVENTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_TWELFTH_REGISTRATION_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_THIRTEENTH_REGISTRATION_MODE
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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_SCHEMA_AUDIT_REPORT="$PWD/lion-runapplicationeventloop-remaining-schema-audit.txt"

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
  ./dn-runapplicationeventloop-remaining-schema-audit-broker \
  ./dn-runapplicationeventloop-remaining-schema-audit-broker.sha256 \
  ./payload/lion-runapplicationeventloop-remaining-schema-audit.log
```

Do not run the PPC subject a second time before review.

## Acceptance discriminator

Require registration 13 to remain accepted exactly once, all eight known request geometries 14–21 to appear exactly in the observed order, and eight remaining-wave capture markers.

Require:

```text
PM_DISTRIBUTED_NOTIFICATIONS_CREATEWINDOW_REGISTER_SUMMARY:register=13 callback=0 rejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_RUNAPPLICATIONEVENTLOOP_REMAINING_SCHEMA_AUDIT_SUMMARY:captures=8 failures=0 unexpectedRejects=0 postBoundaryRejects=0 exact=YES
PM_DISTRIBUTED_NOTIFICATIONS_PPC_INGRESS_BROKER_RESULT:RUNAPPLICATIONEVENTLOOP_REMAINING_AUDIT_PASS
```

Also require the inherited timer-side-quit chain through S15 and `M24_SUCCESS`, PPC exit 0, WBI/ColorProfileClient/ResolveColorProfile counts 1/1/1, OrderFront count 2, all six titlebar translations once, zero titlebar guard rejects, no new diagnostics, and unchanged protected hashes.

The runner must end:

```text
RESULT: POST_INSTALLEVENTLOOPTIMER_RUNAPPLICATIONEVENTLOOP_REMAINING_NOTIFICATIONS_SCHEMA_AUDIT_PASS
```

Then review **all eight** request plists in `lion-runapplicationeventloop-remaining-schema-audit.txt`. If and only if all eight are clean reviewed registrations with compatible client/session/entry/counter semantics, the next step may use one combined exact policy for requests 14–21. If any request differs in operation or schema, stop and handle that request according to the captured evidence.

## Return evidence

Return exactly:

```text
dn-runapplicationeventloop-remaining-schema-audit-broker.info.txt
dn-runapplicationeventloop-remaining-schema-audit-broker.sha256
sys295-runapplicationeventloop-remaining-audit.log
payload/lion-runapplicationeventloop-remaining-schema-audit.log
payload/lion-runapplicationeventloop-remaining-schema-audit.raw.log
lion-runapplicationeventloop-remaining-schema-audit.txt
```

Also return any newly named crash report or crash plist if the runner reports one.

## Current boundary

```text
request-13 exact registration                       LIVE-PROVEN PASS
remaining observed registrations                    8 (requests 14–21)
request-14 through request-21 schemas                UNREVIEWED
safe one-run acceleration                           capture/decode all eight; reject all eight
bulk acceptance now                                 NOT AUTHORIZED
possible next acceptance after review               one combined exact requests-14–21 policy
request-14-only failed run                          preflight runner bug; PPC subject did not launch
RemoveEventLoopTimer / DisposeEventLoopTimerUPP     HELD
new compatibility families                         NO
titlebar policy broadening                         NO
XNU                                                 no source change indicated
```
