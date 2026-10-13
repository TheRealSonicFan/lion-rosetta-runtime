# ShowWindow titlebar exact-six-key Snow passthrough control

## Objective

Build the exact-six CoreUI titlebar `bsearch` compatibility artifact on Snow Leopard and prove that all six statically authorized Snow titlebar keys reach the existing old-CoreUI lookup boundary while the wrapper leaves every lookup unchanged.

This stage is Snow-only. It does not authorize transfer to Lion or any new Lion PPC run.

The static combined policy is already closed:

```text
disabled-clear  a613161f7a000000 -> 9914172272000000
disabled-minus  a6161f567a000000 -> 9917225572000000
disabled-zoom   a6161f7ab6000000 -> 99172272a9000000
active-clear    a60113167a000000 -> 9901141772000000
active-minus    a60116567a000000 -> 9901175572000000
active-zoom     a601167ab6000000 -> 99011772a9000000
```

The new compatibility source preserves the exact previously proven boundary guards and changes only the authorized key table from three entries to six.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-titlebar-bsearch-compat-interposer.c
scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh
```

Pinned identities:

```text
compat build ID   coreui-titlebar-bsearch-exact-six-v2
source git blob   5a5dbe1b564e844d51eb6fd6361136e86c850e31
builder git blob  97a012681fb3332421065a7875d78671780eb5cf
Snow runner blob  37d128e3ecd838503b745e0d53c25b633c8c4ee0
Snow mode         passthrough
future Lion mode  lion-exact-six-v1
```

The Lion runner intentionally still rejects the exact-six mode. That is a safety gate, not a defect.

## Safety constraints

- Run only on Snow Leopard 10.6.8 / 10K549.
- Do not transfer the new dylib to Lion yet.
- Do not edit or enable the Lion runner for exact-six mode.
- Do not rerun the PPC subject on Lion.
- Do not change the exact-seven notification policy or any accepted compatibility adapter.
- Do not patch CoreUI or any ArtFile resource.
- Do not broaden beyond the six exact eight-byte source keys above.
- Do not interpose `LoadFromArtFile`, `ShowArtFilePathToStdErr`, `fprintf`, or `vfprintf`.
- Preserve `core.9821`; it is not required for this stage.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and preflight

On Snow Leopard:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1
test "$LOCAL_HEAD" = "$REMOTE_HEAD" || exit 1

test "$(git hash-object ./tests/ppc-coreui-titlebar-bsearch-compat-interposer.c)" =   "5a5dbe1b564e844d51eb6fd6361136e86c850e31" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh)" =   "97a012681fb3332421065a7875d78671780eb5cf" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh)" =   "37d128e3ecd838503b745e0d53c25b633c8c4ee0" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh || exit 1
```

Do not proceed if Phase A fails.

## Phase B — build exact-six compatibility dylib

On Snow Leopard:

```sh
cd "$RUNTIME" || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 /bin/bash ./scripts/build-ppc-coreui-titlebar-bsearch-compat-on-snowleopard.sh   ./pm-titlebar-bsearch-six-key-compat.dylib || exit 1
```

Expected outputs:

```text
pm-titlebar-bsearch-six-key-compat.dylib
pm-titlebar-bsearch-six-key-compat.dylib.info.txt
pm-titlebar-bsearch-six-key-compat.dylib.sha256
```

Require the info report to show:

```text
compat_build_id=coreui-titlebar-bsearch-exact-six-v2
32-bit PPC Mach-O
exactly one __DATA,__interpose tuple
interpose section size 0x00000008
_bsearch reference present
_rosetta_bsearch present
no _dlsym import
PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-six-v2
```

## Phase C — Snow exact-six passthrough control

Use the same accepted Snow ShowWindow control stack as the earlier exact-three run and change only the titlebar compatibility artifact path.

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

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/pm-titlebar-bsearch-six-key-compat.dylib.sha256"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_MODE=passthrough

/bin/bash ./scripts/run-snowleopard-ppc-process-manager-createwindow-distnotify-integration-control.sh   ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld   ./ppc-process-manager-cgs-session-bootstrap-integration-private-dyld.sha256   ./pm-wbi-compat.dylib   ./pm-wbi-compat.dylib.sha256   ./ppc-process-manager-security-session-auditinfo-api.dylib   ./ppc-process-manager-security-session-auditinfo-api.dylib.sha256   ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib   ./ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256   ./pm-titlebar-bsearch-six-key-snow.log || exit 1
```

Require all six target markers at least once:

```text
PM_COREUI_TITLEBAR_BSEARCH_BUILD_ID:coreui-titlebar-bsearch-exact-six-v2

path=disabled-clear mode=passthrough action=PASSTHROUGH
path=disabled-minus mode=passthrough action=PASSTHROUGH
path=disabled-zoom mode=passthrough action=PASSTHROUGH
path=active-clear mode=passthrough action=PASSTHROUGH
path=active-minus mode=passthrough action=PASSTHROUGH
path=active-zoom mode=passthrough action=PASSTHROUGH

coreui_titlebar_disabled_clear_passthrough_count >= 1
coreui_titlebar_disabled_minus_passthrough_count >= 1
coreui_titlebar_disabled_zoom_passthrough_count >= 1
coreui_titlebar_active_clear_passthrough_count >= 1
coreui_titlebar_active_minus_passthrough_count >= 1
coreui_titlebar_active_zoom_passthrough_count >= 1
coreui_titlebar_unexpected_action_count=0

S01_AFTER_ShowWindow
M24_SUCCESS
RESULT: PASS
```

There must be no `action=TRANSLATED` and no `GUARD_REJECT_PASSTHROUGH`.

If the Snow control fails, stop. Do not alter a guard or proceed to Lion.

## Phase D — return evidence

Return exactly:

```text
pm-titlebar-bsearch-six-key-compat.dylib.info.txt
pm-titlebar-bsearch-six-key-compat.dylib.sha256
pm-titlebar-bsearch-six-key-snow.log
```

Do not return the dylib itself unless requested.

## Completed result

The returned Snow evidence passes the exact-six control completely. The artifact is a PPC7400 dylib with exactly one 8-byte `__DATA,__interpose` tuple, imports `_bsearch`, contains local `_rosetta_bsearch`, carries build ID `coreui-titlebar-bsearch-exact-six-v2`, and hashes to `6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72`. The runtime control loaded that exact artifact, observed each of the six disabled/active clear/minus/zoom keys once in `passthrough` mode, observed zero translated or guard-reject actions, returned from ShowWindow, reached `M24_SUCCESS`, and ended `RESULT: PASS`.

The Snow transparency gate is therefore closed positively. Current `main` now enables the Lion runner only for build ID `coreui-titlebar-bsearch-exact-six-v2` in mode `lion-exact-six-v1` and requires all six translation predicates. Proceed only through `docs/pm-showwindow-artfile-titlebar-six-key-lion-integration.md`.

## Current boundary

```text
combined exact-six static policy               PASS
exact-six compatibility source                 PREPARED
exact-six Snow build                           PASS
exact-six Snow passthrough                     PASS: all six observed once
Lion exact-six runner                          PREPARED
fresh syscall-295 preflight                    NEXT
single Lion exact-six ShowWindow run           AUTHORIZED AFTER PREFLIGHT
core.9821                                      preserve; not required now
CoreUI/ArtFile patch                           NO
XNU                                            no change indicated
```
