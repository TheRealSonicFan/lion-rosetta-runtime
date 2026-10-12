# Process Manager ShowWindow ResolveColorProfile ID compatibility experiment

## Objective

The passive live resolver trace is complete. The returned artifacts prove the same generated-MIG release skew both statically and live at the active Lion ShowWindow boundary.

Snow PPC and Lion i386 use matching ResolveColorProfile wire geometry but different routine IDs:

```text
Snow request/reply          0x74d7 / 0x753b
Lion request/reply          0x74d9 / 0x753d
request bits                0x80001513
Mach option                 0x3
send / receive              0x38 / 0x3c
descriptor count            1
descriptor disposition/type 0x13 / 0x00
success / error reply       0x34 / 0x24
```

The completed Snow control also exposed one useful chronology correction. Snow first resolves profile ID 2 before the later target profile-ID-1 resolution; both legacy `0x74d7` requests succeed with `0x753b / 0x34 / result 0`. The passive tracer labels the profile-ID-2 request `exact=NO` only because its target predicate intentionally includes `profileId=1`; that earlier request is not evidence of malformed wire geometry. The later profile-ID-1 request is `exact=YES` and succeeds, and the full Snow ShowWindow control reaches M24 and PASS.

The Lion run is decisive for the target boundary. The accepted ColorProfileClient adapter succeeds exactly once. Its native reply contains a nonzero client ID; after NDR interpretation that semantic client ID is exactly the one emitted by the following resolver request. The first Lion resolver request is the exact legacy `0x74d7` profile-ID-1 request. Mach transport succeeds, but the PPC-facing reply is `0x753b / 0x24` with raw result `0xd0feffff` (-304). The same target resolver failure occurs four times. This is the generated-MIG dispatch rejection predicted by the static differential, not evidence that Lion-native resolver semantics rejected profile state.

This stage therefore tests one narrow ID-only ResolveColorProfile compatibility conversion.

## Prepared compatibility implementation

Current runtime `main` provides:

```text
scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-compat-on-snowleopard.sh
```

The resulting short artifact name is:

```text
pm-cpc-cpr-compat.dylib
```

Abbreviations remain:

```text
CPC  ColorProfileClient
CPR  ColorProfile Resolve
```

The accepted ColorProfileClient v2 core build ID is retained so the established Snow/Lion runners continue to enforce the accepted upstream stack. ResolveColorProfile compatibility has an independent marker:

```text
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1
```

The new resolver adapter is deliberately narrower than a general message-ID translator. It can adapt only an exact legacy profile-ID-1 resolver request after the accepted ColorProfileClient adapter has succeeded in the same process. It requires the resolver's semantic client ID, remote port, reply port, and task-port descriptor to match the state captured from that successful ColorProfileClient transaction. It permits at most four adapted resolver calls, matching the observed failing baseline.

For an accepted request, it:

```text
copies the request into a private buffer
changes request ID only       0x74d7 -> 0x74d9
preserves descriptor/NDR/client ID/profile ID and every other request byte
sends the private copy to Lion
requires native reply ID      0x753d
accepts native reply size     0x34 or 0x24
changes reply ID only         0x753d -> 0x753b
preserves result/output bytes and every other reply byte
copies the adapted reply back to the PPC caller
```

It does not synthesize a client ID, force profile ID 1, alter resolver output data, or touch the related release routine.

## Safety constraints

- Perform one behavior-preserving Snow passthrough control before Lion.
- Perform the syscall-295 preflight before the Lion subject.
- Perform exactly one Lion translated-PPC compatibility run.
- Keep the accepted ColorProfileClient adapter enabled on Lion.
- Do not add compatibility for `CGSReleaseColorProfile` (`0x74d8 / 0x74da`) in this stage.
- Do not alter descriptor contents, NDR, client ID, profile ID, result, mapped-address/length outputs, or profile state.
- Do not synthesize profile ID 1 or substitute another profile ID.
- Do not force `CGSColorProfileCreateWithColorProfileID`, `_CGSWindowColorProfile`, `CGWindowContextCreate`, CoreUI, or RawCamera to succeed.
- Keep NewWindow, release-backing, create-alpha, OrderFrontConditionally, AddTrackingArea, SetFrontWindow, ColorProfileClient, FontServer, HIToolbox, Security, and exact-six notification compatibility unchanged.
- Keep the held `CGSShapeWindow` path unchanged.
- Do not patch CoreGraphics, WindowServer, Rosetta, dyld, caches, launchd, or XNU.

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

## Phase B — build the resolver compatibility artifact on Snow Leopard

On Snow Leopard 10.6.8:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1

/bin/bash -n ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-compat-on-snowleopard.sh || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
/bin/bash ./scripts/build-ppc-process-manager-post-windowtitle-showwindow-color-profile-resolve-compat-on-snowleopard.sh || exit 1
```

Expected outputs:

```text
pm-cpc-cpr-compat.dylib
pm-cpc-cpr-compat.dylib.info.txt
pm-cpc-cpr-compat.dylib.sha256
```

Require a 32-bit PPC Mach-O dylib, exactly two `__interpose` tuples, the accepted ColorProfileClient v2 core build ID, embedded distributed-notifications ingress v2, the passive resolver trace marker, and the independent resolver compatibility marker.

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
  ./pm-cpc-cpr-compat.dylib \
  ./pm-cpc-cpr-compat.dylib.sha256 \
  ./ppc-process-manager-security-session-auditinfo-api.dylib \
  ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./pm-cpr-compat-snow.log || exit 1
```

Confirm the resolver compatibility layer did not adapt anything:

```sh
/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1' ./pm-cpr-compat-snow.log || exit 1
/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:PASSTHROUGH' ./pm-cpr-compat-snow.log || exit 1
if /usr/bin/grep -Fq 'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_RESULT:ADAPTER_PASS' ./pm-cpr-compat-snow.log; then
  echo 'error: resolver adapter must not run in Snow passthrough control' >&2
  exit 1
fi
/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REQUEST:kind=CGS_COLOR_PROFILE_RESOLVE_LEGACY exact=YES' ./pm-cpr-compat-snow.log | /usr/bin/grep -F 'profileId=1' || exit 1
/usr/bin/grep -F 'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_REPLY:kind=CGS_COLOR_PROFILE_RESOLVE_LEGACY' ./pm-cpr-compat-snow.log | /usr/bin/grep -F 'size=0x00000034' | /usr/bin/grep -F 'resultRaw=0x00000000' || exit 1
/usr/bin/grep -F 'PM_POSTIDENTITY_MILESTONE:M24_SUCCESS' ./pm-cpr-compat-snow.log || exit 1
/usr/bin/grep -F 'RESULT: PASS' ./pm-cpr-compat-snow.log || exit 1
```

The earlier Snow profile-ID-2 resolver request may still appear as `exact=NO` in the passive target trace; it must remain passthrough and successful. Do not reinterpret that target-specific label as malformed wire geometry.

## Phase D — transfer the compatibility artifact to Lion

Transfer:

```text
pm-cpc-cpr-compat.dylib
pm-cpc-cpr-compat.dylib.info.txt
pm-cpc-cpr-compat.dylib.sha256
pm-cpr-compat-snow.log
```

Place the dylib, `.info.txt`, and `.sha256` in Lion's `payload/` directory. Keep the Snow control log at the runtime root. Verify the transferred dylib against its sidecar before execution.

## Phase E — syscall-295 preflight on Lion

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-pm-cpr-compat.log" || exit 1
```

Require the accepted kernel SHA, `result=-1 errno=9 saw_sigsys=0`, exit status 0, and `RESULT: PASS`.

## Phase F — exactly one Lion resolver compatibility run

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
  ./payload/pm-cpc-cpr-compat.dylib \
  ./payload/pm-cpc-cpr-compat.dylib.sha256 \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib \
  ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256 \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib \
  ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256 \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker \
  ./native-distributed-notifications-post-windowtitle-showwindow-sixth-registration-broker.sha256 \
  ./payload/lion-pm-cpr-compat.log
```

Do not run the Lion subject a second time.

## Lion acceptance discriminator

The first target resolver transaction must show all of the following:

```text
PM_CGS_COLOR_PROFILE_CLIENT_COMPAT_RESULT:ADAPTER_PASS
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_PREREQ:
  cpcAdapterPassed=YES
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_CALL:
  mode=lion-id-v1
  exact=YES
  provenanceExact=YES
  clientId == expectedClientId
  profileId=1
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_ADAPTED_REQUEST:
  legacyId=0x000074d7
  lionId=0x000074d9
  changedBytes=1
  bodyChangedBytes=0
  sourceChangedBytes=0
PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_NATIVE_MACH_RETURN:
  kr=0
```

Then classify the native Lion reply.

### Native resolver success

The desired result is:

```text
native reply ID             0x753d
native reply size           0x34
native result               0
adapted legacy reply ID     0x753b
request body changed bytes  0
reply body changed bytes    0
adapter result              ADAPTER_PASS
```

If this occurs, the ResolveColorProfile ID-only compatibility is live-proven. Compare the following execution against the passive baseline. The key advancement is disappearance of the profile-resolution `-304` diagnostics. Preserve the first new failure or milestone after that point; do not pre-authorize any downstream adapter.

If `S01_AFTER_ShowWindow` appears, preserve all subsequent milestones and the first later failure. If ShowWindow still does not return, identify the first diagnostic after the successful resolver transaction before deciding the next boundary.

### Native resolver semantic failure

If Lion accepts `0x74d9` but returns `0x753d / 0x24` with a nonzero result, generated-MIG dispatch is fixed but native resolver semantics still reject the request. Preserve the exact native result and do not broaden the ID adapter. The next stage would return to client/profile registration state with the now-proven native dispatch path.

### Provenance or envelope rejection

If `exact=NO`, `provenanceExact=NO`, client IDs do not match semantically, the captured ports differ, native reply ID is not `0x753d`, or the adapter hits its four-call cap, stop. Do not relax the predicate, raise the cap, or rewrite body bytes without a new evidence review.

## Return

Return these six primary artifacts:

```text
pm-cpc-cpr-compat.dylib.info.txt
pm-cpc-cpr-compat.dylib.sha256
pm-cpr-compat-snow.log
sys295-pm-cpr-compat.log
lion-pm-cpr-compat.log
lion-pm-cpr-compat.raw.log
```

Also return every new crash/core diagnostic named by the Lion runner, if any. Do not upload the dylib itself unless specifically requested.

## Current boundary

```text
ColorProfileClient adapter                 accepted PASS
ResolveColorProfile Snow profile 1         0x74d7 -> 0x753b / 0x34 / result 0
ResolveColorProfile Lion passive           0x74d7 -> 0x753b / 0x24 / -304
resolver generated-MIG skew                live-proven
resolver compatibility under test          0x74d7 -> 0x74d9, 0x753d -> 0x753b
resolver request/reply bodies               preserve verbatim
CGWindowContext/CoreUI/RawCamera           downstream/held
CGSReleaseColorProfile                     held
CGSShapeWindow                             held
XNU                                        no change indicated
```


## Completed result — ResolveColorProfile compatibility live-proven

The returned six primary artifacts complete this experiment.

The Snow Leopard build is the intended PPC compatibility dylib, carries the independent `color-profile-resolve-id-compat-v1` marker, retains the accepted ColorProfileClient v2 core build ID, and has the expected two interpose tuples. The Snow passthrough control makes no resolver adaptation, the target profile-ID-1 `0x74d7 / 0x753b` transaction succeeds with a `0x34` result-zero reply, ShowWindow returns, M24 is reached, and the control ends in PASS. The Lion syscall-295 preflight remains on the accepted EBADF/no-SIGSYS path.

In the single Lion run, ColorProfileClient succeeds exactly once and records semantic client ID 57. The immediately following target resolver request is `exact=YES` and `provenanceExact=YES`, with the same client ID 57, the captured server/reply/task ports, and profile ID 1. The resolver adapter changes only request ID `0x74d7 -> 0x74d9`. Lion returns native `0x753d / 0x34`, result zero, with mapped-output words present. The adapter changes only reply ID `0x753d -> 0x753b`, reports zero body changes, and returns `ADAPTER_PASS`. Only one resolver compatibility call occurs.

This removes the former first-order color-profile/window-context failure. The run contains no `Cannot resolve color profile id(1)`, no invalid-profile diagnostic, no `Failed to create window context color transform`, and no `CGWindowContextCreate: failed to create context delegate` cascade.

ShowWindow still does not reach `S01_AFTER_ShowWindow`. The first remaining repeated failure after the successful resolver is an existing `0x7263 / 0x72c7` CGS transaction. Mach transport succeeds and the simple `0x34` reply reports result zero, but CoreGraphics immediately emits `_CGSBindWindowBacking: cannot map backing data shmem` and `_CGSLockWindow: Unable to lock window`. The pair repeats seven times. Snow uses the same observed IDs and envelope without those errors and completes ShowWindow, so no ID rewrite is authorized from the live evidence.

The exact-six notification broker accepts the sixth registration after resolver success. A later seventh registration is rejected only after several backing-map failures, so broker expansion is held. RawCamera loading and later CoreUI art-file errors are also downstream of the newly isolated backing-lock failure.

The authoritative next stage is the static, read-only:

```text
docs/process-manager-post-windowtitle-showwindow-window-backing-lock-protocol-audit.md
scripts/audit-process-manager-showwindow-window-backing-lock-protocol.py
```

Do not broaden the resolver adapter, change `CGSReleaseColorProfile`, adapt `0x7263`, expand the notification broker, revisit ShapeWindow, force backing mapping, or change XNU until the Snow/Lion backing-lock differential is reviewed.

## Completed boundary

```text
ColorProfileClient adapter                         accepted PASS
ResolveColorProfile adapter                        live-proven PASS
native resolver reply                              0x753d / 0x34 / result 0
legacy-facing resolver reply                       0x753b / 0x34 / result 0
old color-profile/window-context failure           eliminated
ShowWindow                                         S00 reached, S01 absent
0x7263 / 0x72c7                                   result 0, backing map fails
backing-map/lock diagnostic repetitions            7
sixth notification registration                    accepted
seventh notification registration                  later reject, held
next step                                          static backing-lock protocol/ABI audit
XNU                                                no change indicated
```
