# ShowWindow titlebar exact-six-key Lion integration

## Objective

Run one controlled Lion 10.7.5 / 11G63 ShowWindow integration with the exact-six CoreUI titlebar `bsearch` compatibility artifact after the combined static proof and Snow transparency control have both passed.

This stage changes no policy beyond the six exact mappings already proven:

```text
disabled-clear  a613161f7a000000 -> 9914172272000000
disabled-minus  a6161f567a000000 -> 9917225572000000
disabled-zoom   a6161f7ab6000000 -> 99172272a9000000
active-clear    a60113167a000000 -> 9901141772000000
active-minus    a60116567a000000 -> 9901175572000000
active-zoom     a601167ab6000000 -> 99011772a9000000
```

The Snow control proved that all six source keys reach the old PPC CoreUI lookup boundary under the existing callsite/comparator and archive-geometry predicates while passthrough remains transparent.

## Pinned implementation

Current runtime `main` provides:

```text
compat build ID       coreui-titlebar-bsearch-exact-six-v2
Lion mode              lion-exact-six-v1
compat source blob     5a5dbe1b564e844d51eb6fd6361136e86c850e31
Snow builder blob      97a012681fb3332421065a7875d78671780eb5cf
Snow runner blob       37d128e3ecd838503b745e0d53c25b633c8c4ee0
Lion runner blob       22e8a987f935156167c4051ab76488b6cc1c0592
exact-seven source     9d137becc45bac476fa70218db4839b28be0e219
exact-seven builder    d909dd6a3eba657854feb8d09bf2793c33a2bea9
artifact SHA-256       6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72
```

The Lion runner requires all six exact translation markers and zero guard rejects. The existing release/resource, 12-byte record, zero-prefix, caller/comparator, exact-seven notification, and ArtFile-identity guards remain unchanged.

## Safety constraints

- Do not run the Lion PPC subject until every preflight below passes.
- Repeat the syscall-295 probe before the subject.
- Run the Lion PPC ShowWindow subject exactly once in this stage.
- Reuse the accepted exact-seven notification broker; do not accept an eighth request.
- Do not broaden the six-key policy.
- Do not relax caller/comparator, record-prefix, archive-geometry, or Lion resource guards.
- Do not interpose `LoadFromArtFile`, `ShowArtFilePathToStdErr`, `fprintf`, or `vfprintf`.
- Do not patch CoreUI or `ArtFile.bin`.
- Keep RawCamera and `CGSShapeWindow` held.
- Do not change any accepted upstream CoreServices, Security, CGS, HIToolbox, FontServer, WindowBackingInfo, color-profile, or distributed-notification policy.
- Preserve `core.9821`; do not upload it unless later evidence requires it.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and preflight on Lion

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1
test "$LOCAL_HEAD" = "$REMOTE_HEAD" || exit 1

test "$(git hash-object ./tests/ppc-coreui-titlebar-bsearch-compat-interposer.c)" =   "5a5dbe1b564e844d51eb6fd6361136e86c850e31" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" =   "22e8a987f935156167c4051ab76488b6cc1c0592" || exit 1

test "$(git hash-object ./tests/native-dn-showwindow-7-registration-broker.c)" =   "9d137becc45bac476fa70218db4839b28be0e219" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-showwindow-7-registration-broker.sh)" =   "d909dd6a3eba657854feb8d09bf2793c33a2bea9" || exit 1

/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1
/bin/bash -n ./scripts/build-lion-dn-showwindow-7-registration-broker.sh || exit 1

cd "$ROSETTA_XNU" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
```

Do not proceed if Phase A fails.

## Phase B — transfer and verify only the new exact-six artifact

Copy these three files from the successful Snow build into Lion runtime `payload/`:

```text
pm-titlebar-bsearch-six-key-compat.dylib
pm-titlebar-bsearch-six-key-compat.dylib.info.txt
pm-titlebar-bsearch-six-key-compat.dylib.sha256
```

Then on Lion:

```sh
cd "$RUNTIME" || exit 1

test -f ./payload/pm-titlebar-bsearch-six-key-compat.dylib || exit 1
test -f ./payload/pm-titlebar-bsearch-six-key-compat.dylib.info.txt || exit 1
test -f ./payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256 || exit 1

test "$(/usr/bin/awk 'NR==1 {print $1}' ./payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256)" =   "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1

test "$(/usr/bin/shasum -a 256 ./payload/pm-titlebar-bsearch-six-key-compat.dylib | /usr/bin/awk '{print $1}')" =   "6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72" || exit 1

/usr/bin/strings ./payload/pm-titlebar-bsearch-six-key-compat.dylib |   /usr/bin/grep -Fq 'PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-six-v2' || exit 1
```

Do not substitute the old exact-three artifact.

## Phase C — rebuild the accepted exact-seven broker

The broker is native i386 and rebuilding it does not launch the PPC subject:

```sh
cd "$RUNTIME" || exit 1

/bin/bash ./scripts/build-lion-dn-showwindow-7-registration-broker.sh   ./dn-showwindow-7-registration-broker || exit 1
```

Require:

```text
architecture i386
build ID distributed-notifications-showwindow-seventh-registration-broker-v1
```

Do not substitute the sixth-request or generic ingress broker.

## Phase D — fresh syscall-295 preflight

On Lion:

```sh
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh"   "$XNU_SRC/syscall295-probe"   "$RUNTIME/sys295-titlebar-bsearch-six-key.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

If this fails, stop. Do not run the PPC subject.

## Phase E — exactly one Lion exact-six ShowWindow run

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
export ROSETTA_DISTRIBUTED_NOTIFICATIONS_REAL_REGISTRATION_MODE=lion-showwindow-seventh-register-v1

export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_PATH="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib"
export ROSETTA_HITOOLBOX_EXTRAS_COMPAT_SHA256_FILE="$PWD/payload/ppc-hitoolbox-extras-resource-compat.dylib.sha256"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_PATH="$PWD/payload/SnowLeopard-HIToolbox-Extras.rsrc"
export ROSETTA_HITOOLBOX_EXTRAS_RESOURCE_MODE=lion-fallback-external-v1

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=lion-exact-six-v1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh   ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld   ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256   ./payload/pm-wbi-compat.dylib   ./payload/pm-wbi-compat.dylib.sha256   ./payload/ppc-process-manager-security-session-auditinfo-api.dylib   ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256   ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib   ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256   ./dn-showwindow-7-registration-broker   ./dn-showwindow-7-registration-broker.sha256   ./payload/lion-titlebar-bsearch-six-key.log
```

Do not run this command a second time before review.

## Acceptance discriminator

First require the accepted upstream chain to remain intact through the exact-seven registration gate, including broker `PASS`, no rejected/eighth notification request, and `S00_BEFORE_ShowWindow`.

Then require all six titlebar markers:

```text
PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-six-v2

path=disabled-clear mode=lion-exact-six-v1 action=TRANSLATED
path=disabled-minus mode=lion-exact-six-v1 action=TRANSLATED
path=disabled-zoom mode=lion-exact-six-v1 action=TRANSLATED
path=active-clear mode=lion-exact-six-v1 action=TRANSLATED
path=active-minus mode=lion-exact-six-v1 action=TRANSLATED
path=active-zoom mode=lion-exact-six-v1 action=TRANSLATED

coreui_titlebar_disabled_clear_translated_count >= 1
coreui_titlebar_disabled_minus_translated_count >= 1
coreui_titlebar_disabled_zoom_translated_count >= 1
coreui_titlebar_active_clear_translated_count >= 1
coreui_titlebar_active_minus_translated_count >= 1
coreui_titlebar_active_zoom_translated_count >= 1
coreui_titlebar_guard_reject_count=0
```

The six known invalid Snow keys must not recur as CoreUI invalid-path diagnostics.

## Review gates

If `S01_AFTER_ShowWindow` and `SHOWWINDOW_PASS` appear, the exact-six titlebar compatibility boundary is live-proven. Preserve all later milestones and stop for review.

If all six translations pass but ShowWindow still does not return, preserve the first subsequent diagnostic and every new crash/core artifact named by the runner. Do not broaden the six-key policy.

If a required translation count is zero or a guard reject appears, stop and treat it as an exact predicate failure; do not relax a guard.

If an eighth distributed-notification request appears, stop; exact-seven remains authoritative.

## Return evidence

Return:

```text
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-titlebar-bsearch-six-key.log
payload/lion-titlebar-bsearch-six-key.log
payload/lion-titlebar-bsearch-six-key.raw.log
```

Also return every new crash report or crash plist explicitly named by the Lion runner. Do not upload a large core unless requested after the crash report is reviewed.

## Observed result — exact-six ShowWindow gate closed

The returned Lion evidence passes this integration completely:

```text
Lion release/build                             10.7.5 / 11G63
kernel SHA                                     accepted
syscall 295                                    EBADF / no SIGSYS / PASS
exact-seven broker                             PASS
exact-seven registrations                      7 / rejects 0 / exact YES
exact-six artifact SHA                         6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72
disabled-clear/minus/zoom                      translated once each
active-clear/minus/zoom                        translated once each
titlebar guard rejects                         0
CoreUI Invalid ArtFile Path                    none
S01_AFTER_ShowWindow                           reached
SHOWWINDOW_PASS                                reached
DisposeWindow / M24_SUCCESS                    reached
subject exit                                   0
new crash/core diagnostics                     none
protected hashes                               unchanged
final runner result                            POST_WINDOWTITLE_SHOWWINDOW_SEVENTH_NOTIFICATION_REGISTRATION_INTEGRATION_PASS
```

This live-proves the exact-six CoreUI titlebar translation boundary and closes ShowWindow as the active blocker. A transient `_CGSLockWindow: Cannot synchronize window backing store` diagnostic remains visible during the successful call, but it is no longer a blocking boundary because ShowWindow returns and the process completes normally; do not expand CGS compatibility from that diagnostic alone.

The next isolated public API discriminator is `SelectWindow(window)`. Current `main` provides a new subject mode and a Snow-only control in `docs/process-manager-post-showwindow-selectwindow-snow-control.md`. Do not run the SelectWindow subject on Lion until that Snow control has been reviewed.

## Current boundary

```text
combined exact-six static policy               PASS
exact-six Snow passthrough                     PASS
exact-six Lion live translation                PASS: all six once
ShowWindow                                     PASS
exact-seven notifications                      PASS
new crash/core diagnostics                     none
SelectWindow                                   NEXT: Snow control only
IsWindowVisible / timers / event loop           HELD
six-key policy broadening                      NO
core.9821                                      preserve; historical
CoreUI/ArtFile patch                           NO
XNU                                            no change indicated
```
