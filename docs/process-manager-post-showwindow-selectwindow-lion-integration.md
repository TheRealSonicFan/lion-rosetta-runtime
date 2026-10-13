# Post-ShowWindow SelectWindow Lion integration

## Objective

Run exactly one controlled Lion 10.7.5 / 11G63 `SelectWindow(window)` integration after the corrected full-stack v3 compatibility artifact has passed its Snow transparency gate.

This stage changes only one live compatibility predicate relative to the already proven Lion ShowWindow baseline: `CGSOrderFrontConditionally` may adapt the second exact legacy request issued inside `SelectWindow`, under the separate `lion-selectwindow-id-v1` mode. The accepted ResolveColorProfile, WindowBackingInfo, CoreUI exact-six, distributed-notification exact-seven, Security, HIToolbox, FontServer, NewWindow, release-backing, opacity, SetFrontWindow, and ColorProfileClient policies remain unchanged.

## Reviewed Snow evidence and pinned identities

The corrected full-stack Snow control passed with:

```text
SelectWindow subject SHA-256
cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259

SelectWindow v3 compatibility artifact SHA-256
28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578

v3 build ID
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v3

CoreServices compat source blob
2c167877c92e6777189c0b4f8657f5570e1a0acb

corrected v3 Snow builder blob
c0e0b4c363595b3781305f8da785e1708ba2d41a

Snow control runner blob
aff24e231e7c8915065973aaf2db9419ea8f90ae

Lion integration runner blob
8c4056dffbb510dcd0b4c6a118c162b59eda382b

SelectWindow subject source blob
6d873470f27e99de997301ef2d0c757ac6b61a6a

SelectWindow subject builder blob
421b427360da6412c14231f0839495cd4ab15bc1

exact-seven broker source blob
9d137becc45bac476fa70218db4839b28be0e219

exact-seven broker builder blob
d909dd6a3eba657854feb8d09bf2793c33a2bea9

exact-six titlebar source blob
5a5dbe1b564e844d51eb6fd6361136e86c850e31

exact-six titlebar artifact SHA-256
6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

XNU syscall-295 runner blob
eaecc9bfbf4d780664c7e66471a832a0289aebb6
```

The corrected Snow artifact carries the accepted `color-profile-resolve-passive-trace-v1`, `color-profile-resolve-id-compat-v1`, and `window-backing-info-id-compat-v1` modules. Snow observed two ResolveColorProfile passthrough calls, one WindowBackingInfo passthrough call, two OrderFront passthrough calls with exactly one bounded by SelectWindow, all six titlebar keys as passthrough, `SELECTWINDOW_PASS`, `M24_SUCCESS`, and final PASS.

## Reviewed first Lion invocation — pre-execution runner failure

The first invocation did **not** launch the PPC subject. The consolidated report stops immediately after preflight state and records zero WindowBackingInfo and zero ResolveColorProfile calls followed by `POST_SHOWWINDOW_SELECTWINDOW_ACCEPTED_FULL_STACK_COUNT_MISMATCH`; the raw transcript is empty. The fresh syscall-295 probe passed independently.

This was a runner-ordering defect introduced by the new full-stack guard: it inspected the still-empty raw transcript before the single PPC execution point. Current `main` moves that unchanged WBI/Resolve validation block to the post-execution validation section, after the raw transcript is populated and before the two-OrderFront discriminator. No compatibility policy, request mapping, artifact, subject, broker, titlebar rule, or XNU code changed.

Because the subject was never executed, the one-run Lion SelectWindow budget has not been consumed. For the retry, pull current runtime `main`, verify the updated runner blob below, repeat the fresh syscall-295 preflight, and then repeat Phase E exactly once with the already verified artifacts and exact-seven broker. Rebuilding or retransferring unchanged artifacts is not required if their hashes still match. Stop again after that single actual PPC execution.

## Safety constraints

- Do not launch the PPC subject until every preflight below passes.
- Repeat syscall 295 immediately before the PPC run.
- Execute the Lion SelectWindow subject exactly once before review.
- Use only the exact corrected v3 artifact SHA above; do not use the first incomplete v3 artifact.
- Keep the exact-seven notification broker; do not accept an eighth request.
- Keep the exact-six CoreUI titlebar policy unchanged.
- Do not broaden the new OrderFront predicate beyond call indices 1 and 2 with their already proven provenance.
- Do not change ResolveColorProfile or WindowBackingInfo policy.
- Do not add `IsWindowVisible`, timers, event-loop work, or another Carbon window API.
- Do not patch system frameworks/resources, Rosetta, dyld, caches, launchd, WindowServer, or XNU.
- Preserve historical cores; do not upload a large core unless a later crash review specifically requires it.
- No kernel rebuild or reboot.

## Phase A — update and pin current repositories

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1
test "$LOCAL_HEAD" = "$REMOTE_HEAD" || exit 1

test "$(git hash-object ./tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c)" = \
  "2c167877c92e6777189c0b4f8657f5570e1a0acb" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" = \
  "8c4056dffbb510dcd0b4c6a118c162b59eda382b" || exit 1

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

## Phase B — transfer and verify the exact Snow-proven SelectWindow artifacts

From the successful Snow system, copy these files into Lion runtime `payload/`:

```text
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld
ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256
pm-selectwindow-orderfront-compat.dylib
pm-selectwindow-orderfront-compat.dylib.info.txt
pm-selectwindow-orderfront-compat.dylib.sha256
```

Then on Lion:

```sh
cd "$RUNTIME" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld | /usr/bin/awk '{print $1}')" = \
  "cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256)" = \
  "cde220a44e8c68f16681b128898ff48b6bbe7dc94e139b6b5ad13216d6a88259" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/pm-selectwindow-orderfront-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/pm-selectwindow-orderfront-compat.dylib.sha256)" = \
  "28d44246249f41b2de8ef5abda83733272aff2d02df79392a949b899461d0578" || exit 1

/usr/bin/strings ./payload/pm-selectwindow-orderfront-compat.dylib | \
  /usr/bin/grep -Fq 'PM_CORESERVICES_COMPAT_BUILD_ID:dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v3' || exit 1

for marker in \
  'lion-selectwindow-id-v1' \
  'PM_CGS_COLOR_PROFILE_RESOLVE_TRACE_BUILD_ID:color-profile-resolve-passive-trace-v1' \
  'PM_CGS_COLOR_PROFILE_RESOLVE_COMPAT_BUILD_ID:color-profile-resolve-id-compat-v1' \
  'PM_CGS_WINDOW_BACKING_INFO_COMPAT_BUILD_ID:window-backing-info-id-compat-v1'
do
    /usr/bin/strings ./payload/pm-selectwindow-orderfront-compat.dylib | /usr/bin/grep -Fq "$marker" || exit 1
done

test "$(/usr/bin/shasum -a 256 ./payload/pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" = \
  "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1
```

Do not substitute the earlier SHA `6400ab1fc790e93bd404c3f15f02f26c66d11b816498e09f717a700f4c29337b`; that first v3 artifact was Snow-valid but Lion-incomplete.

## Phase C — rebuild the exact-seven native broker

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-showwindow-7-registration-broker.sh \
  ./dn-showwindow-7-registration-broker || exit 1
```

Require:

```text
architecture i386
build ID distributed-notifications-showwindow-seventh-registration-broker-v1
```

Do not substitute a sixth-request, schema-audit, or generic broker.

## Phase D — fresh syscall-295 preflight

On Lion:

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh" \
  "$XNU_SRC/syscall295-probe" \
  "$RUNTIME/sys295-selectwindow-orderfront-v3.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

Stop if this fails. Do not run the PPC subject.

## Phase E — exactly one Lion SelectWindow run

On Lion:

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
  ./payload/lion-selectwindow-orderfront-v3.log
```

Do not run the command a second time before review. The runner writes the raw transcript automatically as:

```text
payload/lion-selectwindow-orderfront-v3.raw.log
```

## Acceptance discriminator

First require the accepted Lion ShowWindow baseline to remain intact:

```text
Lion 10.7.5 / 11G63
accepted custom kernel SHA
exact-seven broker PASS
seven registrations / rejects 0 / exact YES
no eighth request
WindowBackingInfo adapter: exactly 1 call, exactly 1 ADAPTER_PASS, 0 passthrough
ResolveColorProfile adapter: exactly 1 call, exactly 1 ADAPTER_PASS, 0 passthrough
ColorProfileClient accepted success
exact-six titlebar translations present
titlebar guard rejects = 0
S01_AFTER_ShowWindow
SHOWWINDOW_PASS
```

Then require the new SelectWindow boundary:

```text
PM_POSTWINDOWSELECT_MILESTONE:S02_BEFORE_SelectWindow

OrderFront call 1
mode=lion-selectwindow-id-v1
exact=YES
opacityCreateCompatCalls=1
addTrackingCompatCalls=0
native/adapted reply SUCCESS

OrderFront call 2
mode=lion-selectwindow-id-v1
exact=YES
opacityCreateCompatCalls=1
addTrackingCompatCalls=1
native/adapted reply SUCCESS

cgs_order_front_conditionally_compat_call_count=2
cgs_order_front_conditionally_legacy_trace_count=2
cgs_order_front_conditionally_adapter_pass_count=2
selectwindow_order_front_conditionally_call_count=1

PM_POSTWINDOWSELECT_MILESTONE:S03_AFTER_SelectWindow
PM_POSTWINDOWSELECT_RESULT:SELECTWINDOW_PASS
M24_SUCCESS
subject exit 0
RESULT: POST_SHOWWINDOW_SELECTWINDOW_VALIDATION_PASS
```

If `S03_AFTER_SelectWindow` and `SELECTWINDOW_PASS` appear with the two exact OrderFront adaptations and all accepted baseline predicates intact, the SelectWindow boundary is live-proven. Stop for review; do not add another public API.

If the second OrderFront call is absent, predicate-rejected, returns a native error, or a third OrderFront call appears, stop and preserve the log. Do not relax the call-index/provenance guard.

If WindowBackingInfo or ResolveColorProfile deviates from its one-call accepted Lion baseline, stop. Do not broaden those adapters.

If the exact-six titlebar wrapper rejects or a new invalid-ArtFile path appears, stop. Do not expand the six-key policy.

If an eighth distributed-notification request appears, stop; exact-seven remains authoritative.

If the process crashes or exits before SelectWindow returns, preserve every new crash report and crash plist named by the runner. Do not upload a large core unless requested after review.

## Return evidence

Return exactly:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-selectwindow-orderfront-v3.log
payload/lion-selectwindow-orderfront-v3.log
payload/lion-selectwindow-orderfront-v3.raw.log
```

Also return every new crash report or crash plist explicitly named by the runner. Do not upload a large core unless requested.

## Current boundary

```text
SelectWindow Snow API control                   PASS
corrected full-stack v3 Snow control            PASS
WindowBackingInfo Lion baseline                 LIVE-PROVEN
ResolveColorProfile Lion baseline               LIVE-PROVEN
exact-six titlebar Lion baseline                LIVE-PROVEN
exact-seven notifications                      LIVE-PROVEN
SelectWindow second OrderFront adaptation       NEXT: one Lion run
IsWindowVisible / timers / event loop            HELD
new compatibility families                      NO
XNU                                              no change indicated
```
