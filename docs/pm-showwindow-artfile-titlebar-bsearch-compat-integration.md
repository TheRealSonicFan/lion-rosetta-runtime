# ShowWindow titlebar exact-three-key bsearch compatibility integration

## Objective

Run the first controlled live compatibility proof for the CoreUI titlebar ArtFile namespace mismatch using the exact boundary and exact byte policy already proven statically.

The completed boundary audit establishes:

```text
Snow PPC Load -> LoadFromArtFile              direct internal branch
LoadFromArtFile symbol interposition          rejected as ordinary boundary
LoadFromArtFile -> libSystem bsearch          one lazy-bound external stub
bsearch call relative address                 0x294f4
bsearch comparator relative address           0x25c08
Lion Rosetta PPC CoreUI contract              accepted identical Snow cache
Lion ArtFile environment                      accepted / PASS
preferred process-local boundary              libSystem bsearch
```

The completed policy proof separately establishes the only authorized translations:

```text
clear  a613161f7a000000 -> 9914172272000000
minus  a6161f567a000000 -> 9917225572000000
zoom   a6161f7ab6000000 -> 99172272a9000000
```

This experiment combines those two proofs. It does not introduce a component-wide remap and it does not mutate CoreUI's original path buffer or any ArtFile resource.

## Prepared compatibility artifact

Current runtime `main` provides:

```text
tests/ppc-coreui-titlebar-bsearch-compat-interposer.c
scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh
```

Source identities:

```text
compat build ID   coreui-titlebar-bsearch-exact-three-v1
source git blob   ced22138eb0b02a0e0474f933bebe4abce0b286f
builder git blob  91dcca963ddcd8517ba518726657545fe974fe3c
Lion runner blob  bd0d65f52324f9126d5dcb966d10ea5debe08282
Snow runner blob  bb0cc234b4243eda5d0b9086353c83cdddac6c3e
exact-seven broker source blob   9d137becc45bac476fa70218db4839b28be0e219
exact-seven broker builder blob  d909dd6a3eba657854feb8d09bf2793c33a2bea9
```

Default artifact name:

```text
pm-titlebar-bsearch-compat.dylib
```

The dylib contains exactly one PPC `__DATA,__interpose` tuple for `bsearch`. The replacement obtains the original routine from the tuple's replacee pointer and does not use `dlsym`.

### Snow mode

```text
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=passthrough
```

For one of the three exact Snow keys, the wrapper requires the old CoreUI callsite/comparator relationship and Snow ArtFile geometry, records `action=PASSTHROUGH`, and calls the original `bsearch` with the original arguments unchanged.

### Lion mode

```text
ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=lion-exact-three-v1
```

For one of the three exact Snow keys, the wrapper requires all of:

```text
12-byte lookup record
first four search-record bytes                zero
caller/comparator relative relationship       exact old PPC CoreUI contract
record count                                  2674
path length                                   8
component count                               169
index start                                   0x0b9d
payload start                                 0x088f8
runner host                                   Lion 10.7.5 / 11G63
runner ArtFile SHA                            accepted Lion SHA
```

Only then does it copy the 12-byte search record to private stack storage, replace the eight path bytes with the corresponding proven Lion key, and call the real `bsearch`. The original CoreUI path buffer, index, and ArtFile mapping remain unchanged.

Every non-target call is passthrough.

## Safety constraints

- Perform the Snow Leopard passthrough control first.
- Do not proceed to Lion if the Snow control fails.
- Repeat the accepted syscall-295 probe before the Lion subject.
- Run the Lion PPC ShowWindow subject exactly once.
- Reuse the exact-seven notification broker and every accepted upstream compatibility artifact unchanged.
- Do not add or accept an eighth notification request.
- Do not change WindowBackingInfo, ColorProfileClient, ResolveColorProfile, FontServer, tracking, ordering, or SetFrontWindow predicates.
- Do not adapt `CGSShapeWindow`.
- Keep RawCamera held until the result of this run is reviewed.
- Do not interpose `LoadFromArtFile`, `ShowArtFilePathToStdErr`, `fprintf`, or `vfprintf`.
- Do not mutate CoreUI memory or patch/substitute any ArtFile.
- Do not broaden beyond the three exact eight-byte source keys.
- Do not install the compatibility dylib system-wide.
- Do not modify Rosetta, dyld, caches, launchd, WindowServer, distnoted, CoreUI, HIToolbox, or XNU.
- No kernel rebuild or reboot.

## Phase A — update and preflight

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1

echo "local_head=$LOCAL_HEAD"
echo "origin_main=$REMOTE_HEAD"

test "$LOCAL_HEAD" = "$REMOTE_HEAD" || exit 1

test "$(git hash-object ./tests/ppc-coreui-titlebar-bsearch-compat-interposer.c)" =   "ced22138eb0b02a0e0474f933bebe4abce0b286f" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh)" =   "91dcca963ddcd8517ba518726657545fe974fe3c" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh)" =   "bd0d65f52324f9126d5dcb966d10ea5debe08282" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh || exit 1
```

On Lion, also update the accepted XNU repository used only for the syscall-295 probe:

```sh
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
cd "$ROSETTA_XNU" || exit 1
git pull --ff-only origin main || exit 1
```

## Phase B — build the compatibility dylib on Snow Leopard

The builder preflight was corrected on current `main`: the earlier revision over-escaped the quoted `BUILD_ID` literal and could falsely report a current source file as stale. A current checkout must therefore use builder blob `91dcca963ddcd8517ba518726657545fe974fe3c` before running this phase.

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 /bin/bash ./scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh   ./pm-titlebar-bsearch-compat.dylib || exit 1
```

Expected:

```text
pm-titlebar-bsearch-compat.dylib
pm-titlebar-bsearch-compat.dylib.info.txt
pm-titlebar-bsearch-compat.dylib.sha256
```

Require the info report to show:

```text
compat_build_id=coreui-titlebar-bsearch-exact-three-v1
32-bit PPC Mach-O
exactly one __DATA,__interpose tuple
interpose section size 0x00000008
_bsearch reference present
_rosetta_bsearch present
no _dlsym import
PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-three-v1
```

## Phase C — Snow Leopard passthrough control

Use the established successful ShowWindow control and add only the new titlebar dylib in passthrough mode.

On Snow Leopard:

```sh
cd "$RUNTIME" || exit 1

unset ROSETTA_CGS_NEWWINDOW_TRACE_MODE
unset ROSETTA_CGS_POST_NEWWINDOW_RELEASEBACKING_TRACE_MODE
unset ROSETTA_CGS_POST_RELEASEBACKING_OPACITY_TRACE_MODE
unset ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_TRACE_MODE
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_EXTRAS_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_FONTSERVER_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SCHEMA_AUDIT_REPORT
unset ROSETTA_DISTRIBUTED_NOTIFICATIONS_POST_SHOWWINDOW_SEVENTH_SCHEMA_AUDIT_REPORT

export ROSETTA_POST_CREATEWINDOW_TITLE_VALIDATION_MODE=snow-windowtitle-v1
export ROSETTA_POST_WINDOWTITLE_SHOWWINDOW_VALIDATION_MODE=snow-showwindow-v1
export ROSETTA_CGS_SHOWWINDOW_UNKNOWN_TRACE_MODE=snow-passive-v1
export ROSETTA_CGS_SHOWWINDOW_ADD_TRACKING_AREA_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_ORDER_FRONT_CONDITIONALLY_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_SET_FRONT_WINDOW_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_CLIENT_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_COLOR_PROFILE_RESOLVE_COMPAT_MODE=passthrough
export ROSETTA_CGS_SHOWWINDOW_WINDOW_BACKING_INFO_COMPAT_MODE=passthrough
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

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/pm-titlebar-bsearch-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/pm-titlebar-bsearch-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=passthrough

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh   ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld   ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256   ./pm-wbi-compat.dylib   ./pm-wbi-compat.dylib.sha256   ./ppc-process-manager-security-session-auditinfo-api.dylib   ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256   ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib   ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256   ./pm-titlebar-bsearch-snow.log || exit 1
```

Require the existing Snow ShowWindow control to remain successful and additionally require:

```text
PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-three-v1
PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=clear mode=passthrough action=PASSTHROUGH
PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=minus mode=passthrough action=PASSTHROUGH
PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=zoom mode=passthrough action=PASSTHROUGH
coreui_titlebar_clear_passthrough_count >= 1
coreui_titlebar_minus_passthrough_count >= 1
coreui_titlebar_zoom_passthrough_count >= 1
coreui_titlebar_unexpected_action_count=0
S01_AFTER_ShowWindow
M24_SUCCESS
RESULT: PASS
```

The Snow control must contain no `action=TRANSLATED`.

If Phase C fails, stop. Do not run Lion.

## Phase D — transfer only the new artifact

Copy these three files from Snow Leopard to Lion and place them under Lion runtime `payload/`:

```text
pm-titlebar-bsearch-compat.dylib
pm-titlebar-bsearch-compat.dylib.info.txt
pm-titlebar-bsearch-compat.dylib.sha256
```

Retain `pm-titlebar-bsearch-snow.log` as returned evidence.

## Recovery note for the pre-launch Phase F failure

The earlier Lion attempt that stopped on `TITLEBAR_BSEARCH_ABS: unbound variable` terminated inside runner initialization, before artifact-path validation and before the PPC subject launch. It therefore does **not** consume the single authorized Lion ShowWindow run. If the Snow Phase C passthrough control already passed, retain that log and do not repeat Snow solely because of this harness failure.

The runner initialization order is corrected on current `main`; require Lion runner blob `bd0d65f52324f9126d5dcb966d10ea5debe08282`.

## Phase E — build the exact-seven broker on Lion

The titlebar experiment reuses the previously reviewed exact-seven broker policy, but the executable is a generated Lion-native artifact and is not stored in Git. Build it before the syscall probe / ShowWindow run:

```sh
cd "$RUNTIME" || exit 1

test "$(git hash-object ./tests/native-dn-showwindow-7-registration-broker.c)" =   "9d137becc45bac476fa70218db4839b28be0e219" || exit 1

test "$(git hash-object ./scripts/build-lion-dn-showwindow-7-registration-broker.sh)" =   "d909dd6a3eba657854feb8d09bf2793c33a2bea9" || exit 1

/bin/bash -n ./scripts/build-lion-dn-showwindow-7-registration-broker.sh || exit 1
/bin/bash ./scripts/build-lion-dn-showwindow-7-registration-broker.sh   ./dn-showwindow-7-registration-broker || exit 1
```

Require:

```text
dn-showwindow-7-registration-broker
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
architecture i386
build ID distributed-notifications-showwindow-seventh-registration-broker-v1
```

Do not substitute an older sixth-request broker or a generic ingress broker.

## Phase F — syscall-295 preflight on Lion

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
export ROSETTA_XNU=/path/to/lion-rosetta-xnu
export XNU_SRC=/path/to/xnu-build-directory
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash "$ROSETTA_XNU/tools/run_syscall295_probe.sh"   "$XNU_SRC/syscall295-probe"   "$RUNTIME/sys295-titlebar-bsearch.log" || exit 1
```

Require:

```text
result=-1 errno=9 saw_sigsys=0
probe_exit_status=0
RESULT: PASS
```

## Phase G — exactly one Lion exact-seven ShowWindow run

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

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=lion-exact-three-v1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

/bin/bash ./scripts/run-lion-ppc-process-manager-createwindow-distnotify-integration.sh   ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld   ./payload/ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256   ./payload/pm-wbi-compat.dylib   ./payload/pm-wbi-compat.dylib.sha256   ./payload/ppc-process-manager-security-session-auditinfo-api.dylib   ./payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256   ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib   ./payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256   ./dn-showwindow-7-registration-broker   ./dn-showwindow-7-registration-broker.sha256   ./payload/lion-titlebar-bsearch.log
```

Do not run the Lion subject a second time before review.

## Lion acceptance discriminator

First require the accepted upstream chain to remain intact through exact-seven registration:

```text
WindowBackingInfo compatibility                ADAPTER_PASS exactly once
ColorProfileClient compatibility               ADAPTER_PASS exactly once
ResolveColorProfile compatibility              ADAPTER_PASS exactly once
FontServer rendezvous compatibility            ADAPTER_PASS exactly once
seven notification registrations               exact / no rejects
broker                                          PASS
S00_BEFORE_ShowWindow                           reached
no eighth notification request                 required
```

Then require the titlebar compatibility boundary:

```text
PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-three-v1
PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=clear mode=lion-exact-three-v1 action=TRANSLATED
PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=minus mode=lion-exact-three-v1 action=TRANSLATED
PM_COREUI_TITLEBAR_BSEARCH_TARGET:path=zoom mode=lion-exact-three-v1 action=TRANSLATED

coreui_titlebar_clear_translated_count >= 1
coreui_titlebar_minus_translated_count >= 1
coreui_titlebar_zoom_translated_count >= 1
coreui_titlebar_guard_reject_count=0
```

The old three exact Snow titlebar-key failures must not reappear as the same CoreUI invalid-path sequence.

## Review gates

### ShowWindow returns

If `S01_AFTER_ShowWindow` and `SHOWWINDOW_PASS` appear, the exact titlebar ArtFile compatibility boundary is live-proven. Preserve all later milestones and diagnostics and stop for review. Do not add a later Carbon operation in the same investigation step.

### Titlebar keys translate, but a later failure occurs

If all three translation predicates pass but ShowWindow still does not return, preserve the first subsequent diagnostic and every new crash/core artifact named by the runner. The next investigation must begin at that downstream boundary; do not broaden the ArtFile translation policy.

### A required titlebar key does not reach the interposer

If any of the three translated counts is zero, or a guard rejection is logged, stop. Treat that as an integration-predicate failure; do not relax the comparator, record geometry, release/resource identity, or eight-byte key match.

### An eighth distributed-notification request appears

Stop. The exact-seven notification policy remains authoritative; do not accept an eighth request in this stage.

### Snow passthrough control fails

Do not run Lion. Fix only the compatibility artifact/harness.

## Return evidence

Return:

```text
pm-titlebar-bsearch-compat.dylib.info.txt
pm-titlebar-bsearch-compat.dylib.sha256
pm-titlebar-bsearch-snow.log
dn-showwindow-7-registration-broker.info.txt
dn-showwindow-7-registration-broker.sha256
sys295-titlebar-bsearch.log
lion-titlebar-bsearch.log
lion-titlebar-bsearch.raw.log
```

Also return every new crash report or core diagnostic explicitly named by the Lion runner. Do not return the compatibility dylib itself unless specifically requested.

## Observed live result — 2026-10-13

The returned evidence closes the prepared exact-three integration gate positively but does **not** close ShowWindow:

- the Snow Leopard passthrough control reached all three exact target keys without translation, returned from ShowWindow, reached `M24_SUCCESS`, and ended `RESULT: PASS`;
- the Lion syscall-295 preflight again returned `EBADF` with no `SIGSYS`;
- the Lion exact-seven broker accepted exactly seven registrations with no rejection and ended `PASS`;
- the Lion CoreUI bsearch compatibility dylib translated each of the three proven keys exactly once with zero guard rejects;
- ShowWindow still did not return and the subject exited 139;
- immediately before termination, CoreUI emitted a **different residual three-key invalid-path set**:
  - `a60113167a000000`
  - `a60116567a000000`
  - `a601167ab6000000`
- the runner named a new crash report, crash plist, and `/cores/core.9821`.

This proves the original exact-three bsearch compatibility policy is live and correctly reached; it also proves that the original three keys were not the complete titlebar ArtFile lookup surface exercised by this ShowWindow path. The returned crash report classified the termination as the same CoreUI diagnostic-helper fault class, with the same `ShowArtFilePathToStdErr +220 -> LoadFromArtFile +1840 -> Load +132` chain and the same Rosetta host `EIP=0x8bea0843`, now faulting at `0x7872a1c4`. The residual exact-three static proof has since passed on both Snow and Lion, including unique valid Lion targets, zero overlap with the original policy, 6,120/0 near-miss failures, and zero local-record changes. The 500+ MB core remains preserved but is not required. Do **not** add the residual three keys to the live policy yet. The next authoritative stage is the read-only combined six-key proof in `docs/pm-showwindow-artfile-titlebar-combined-six-key-policy-proof.md`. No further Lion PPC run is authorized until that combined proof is reviewed.

## Current boundary

```text
exact three-key translation policy                PROVEN
Snow/Lion release-resource guards                 PROVEN
non-target identity behavior                      PROVEN
old Load -> LoadFromArtFile                       direct internal branch
old LoadFromArtFile -> bsearch                    one external lazy-bound stub
chosen integration boundary                       libSystem bsearch
live interposer implementation                    LIVE-PROVEN FOR ORIGINAL THREE KEYS
Snow passthrough control                          PASS
Lion exact-three live proof                       PASS: all three translated, zero guard rejects
ShowWindow return                                 NO: exit 139
residual invalid ArtFile keys                      a60113167a / a60116567a / a601167ab6
next evidence gate                                combined exact-six static policy proof
core.9821                                         preserve; not required now
PPC Lion rerun                                    NOT AUTHORIZED BEFORE STATIC PROOF REVIEW
CoreUI/ArtFile patch                              NO
XNU                                               no change indicated
```
