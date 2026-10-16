# PPC Carbon GUI CGS GetSharedWindow reply-shape compatibility integration

## Status

**GETWINDOWSHAPE TARGET PROVEN / GETSHAREDWINDOW REPLY-SHAPE BRIDGE NEXT.**

The returned v8 experiment proves the GetWindowShape adapter itself. On Lion,
all 21 exact legacy `0x724e` requests were converted to native `0x724f`,
all 21 native `0x72b3` replies were accepted and returned as legacy
`0x72b2`, there were zero adapter rejects, and the former
`CGSGetWindowBounds` type-check diagnostic fell to zero. The final v8 runner
still failed because the application remained downstream-stalled: the Carbon
dispatcher received zero mouse events, WindowServer movement remained zero,
the exact-21 notification sequence did not complete, and
`_CGSFindSharedWindow` emitted 31 client type-check failures.

The first repeated post-GetWindowShape failure is now exact. The Snow client
sends `__CGSGetSharedWindow` as:

```text
request/reply      0x7258 / 0x72bc
bits               0x1513
mach option        0x3
send / receive     0x24 / 0x38
success reply      simple 0x30
error reply        simple 0x24
success outputs    offsets 0x24, 0x28, 0x2c
```

Lion's native helper is:

```text
request/reply      0x7259 / 0x72bd
bits               0x1513
mach option        0x3
send / receive     0x24 / 0x3c
success reply      simple 0x34
error reply        simple 0x24
success outputs    offsets 0x24, 0x28, 0x2c, 0x30
```

The old Snow IDs are not GetSharedWindow on Lion: `0x7258/0x72bc` are
owned by `__CGSGetSharedWindowState`. That explains the live Lion reply:
a simple `0x28` state reply is returned to the Snow
`__CGSGetSharedWindow` client, which rejects it and then reports WID 8.

The cross-release `__CGSFindSharedWindow` callers resolve the reply-layout
difference rather than leaving it as a guess. Snow passes three output
addresses to `__CGSGetSharedWindow`; Lion passes four. The first two have
the same downstream uses on both releases, Lion's third native output is the
new field, and Lion's fourth output has the same downstream role as Snow's
third. Therefore the exact legacy projection is:

```text
native Lion 0x24 -> legacy Snow 0x24
native Lion 0x28 -> legacy Snow 0x28
native Lion 0x2c -> dropped (Lion-only field)
native Lion 0x30 -> legacy Snow 0x2c
```

No value is invented and no endian conversion is performed by the adapter;
the raw NDR and scalar bytes remain for the PPC MIG client to interpret.

## Prepared runtime

Current `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-carbon-gui-cgs-get-shared-window-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-cgs-get-shared-window-control.sh
scripts/run-lion-ppc-carbon-gui-cgs-get-shared-window-integration.sh
```

The v9 combined PPC build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-next-event-inline-getwindowshape-getsharedwindow-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v9
```

The v9 source SHA-256 pinned by the Snow builder is:

```text
74cc2994d4328863e8fe5669324badd162a72f99722c123675f5faa2c5c9da07
```

The new compatibility mode is:

```text
ROSETTA_CGS_GET_SHARED_WINDOW_COMPAT_MODE=lion-reply-shape-v1
```

Its exact legacy request predicate requires request ID `0x7258`, bits
`0x1513`, option `0x3`, send `0x24`, caller receive capacity `0x38`,
nonzero remote/reply ports, reply port equal to the Mach receive name, no
timeout/notify port, the local NDR record, and a nonzero window ID.

For an exact Lion call the adapter copies the request into a private buffer,
changes only `0x7258 -> 0x7259`, and raises only the private native receive
capacity from `0x38` to `0x3c`. It accepts only native reply ID
`0x72bd` with simple `0x24` error or simple `0x34` success geometry.
An error reply gets only the reply ID conversion. A success reply is projected
from `0x34` to `0x30` by dropping the Lion-only third output, moving the
fourth native output into Snow's third-output slot, and changing only the
header size/reply ID required by the legacy contract. Request-source and
reply-layout postchecks guard the transformation.

## Safety constraints

- Build v9 only on Snow Leopard 10.6.8 / 10K549.
- Require the Snow passthrough/titlebar-drag control before Lion.
- Perform one Lion integration run after the Snow control passes.
- Keep the proven inline-event and GetWindowShape adapters enabled.
- Keep the exact-21 notification policy unchanged.
- Do not adapt the out-of-line event helper in the same run.
- Do not alter `0x721f/0x7283`, DisplayBounds behavior, or unrelated CGS
  traffic.
- Do not change event payloads, NDR data, Carbon hit parts, CoreUI rendering,
  private HIToolbox, CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
- Verify the repository on a modern TLS-capable staging system and transfer
  the tree/artifacts offline. Do not require Git operations on Snow or Lion.
  Verify built/transferred artifacts by SHA-256 and sidecars.

## Phase A — build v9 on Snow Leopard

From the transferred current runtime tree:

```sh
./scripts/build-ppc-carbon-gui-cgs-get-shared-window-compat-on-snowleopard.sh
```

This creates:

```text
pm-carbon-gui-cgs-get-shared-window-compat.dylib
pm-carbon-gui-cgs-get-shared-window-compat.dylib.info.txt
pm-carbon-gui-cgs-get-shared-window-compat.dylib.sha256
```

## Phase B — Snow positive control

Use the accepted v2 dispatcher monitor:

```sh
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH=./pm-hitoolbox-titlebar-drag-trace-v2.dylib
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE=./pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256
./scripts/run-snowleopard-ppc-carbon-gui-cgs-get-shared-window-control.sh
```

During the active timer interval, press and drag the titlebar. Require:

```text
get_shared_window_call_count >= 1
get_shared_window_exact_count == get_shared_window_call_count
get_shared_window_passthrough_count == get_shared_window_call_count
get_shared_window_adapter_pass_count = 0
get_shared_window_reject_count = 0
titlebar_drag_mouse_down_in_drag_count >= 1
observer_moved_count = 1
RESULT: PPC_CARBON_GUI_CGS_GET_SHARED_WINDOW_SNOW_CONTROL_PASS
RESULT: PASS
```

If Snow fails, stop and return the Snow logs. Do not transfer v9 to Lion.

## Phase C — transfer the accepted v9 artifact

Transfer the v9 dylib, its `.info.txt`, and its `.sha256` sidecar to Lion
with the accepted stack. Verify the dylib against its sidecar on Lion.

## Phase D — one Lion integration run

From the Lion runtime tree:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256"
./scripts/run-lion-ppc-carbon-gui-cgs-get-shared-window-integration.sh
```

Perform the same titlebar gesture during the monitor interval. The targeted
SharedWindow bridge is proven if the runner emits:

```text
get_shared_window_exact_count >= 1
get_shared_window_adapted_request_count == get_shared_window_exact_count
(native success + native error) == get_shared_window_exact_count
(adapted success + adapted error) == get_shared_window_exact_count
get_shared_window_adapter_pass_count == get_shared_window_exact_count
get_shared_window_reject_count = 0
get_shared_window_native_success_count >= 1
find_shared_window_typecheck_diagnostic_count = 0
RESULT: PPC_CARBON_GUI_CGS_GET_SHARED_WINDOW_COMPAT_TARGET_PASS
```

The full runner deliberately keeps the exact-21 notification and prior
accepted-stack gates. Consequently a target-pass marker may coexist with a
final `RESULT: FAIL`; that means this adapter is accepted but a later
boundary still prevents full interaction. Do not broaden the SharedWindow
bridge in that case. In particular, if the target passes and the remaining
first event-path type-check is `CGSGetNextEventRecord (Outofline)`, return
the logs for the next one-boundary decision.

## Return evidence

Return:

```text
pm-carbon-gui-cgs-get-shared-window-compat.dylib.info.txt
pm-carbon-gui-cgs-get-shared-window-compat.dylib.sha256
ppc-carbon-gui-cgs-get-shared-window-snow.log
ppc-carbon-gui-cgs-get-shared-window-snow-observer.log
lion-ppc-carbon-gui-cgs-get-shared-window.log
lion-ppc-carbon-gui-cgs-get-shared-window.raw.log
lion-ppc-carbon-gui-cgs-get-shared-window-observer.log
```

Do not return the dylib itself unless requested.

## Current boundary

```text
Snow v8 GetWindowShape control                     PASS
Lion GetWindowShape adapter                       PASS 21/21
old CGSGetWindowBounds type-check                 eliminated
Lion _CGSFindSharedWindow failures                31
Lion old 0x7258/0x72bc owner                      GetSharedWindowState
Snow native GetSharedWindow                       7258/72bc, recv38, simple success30
Lion native GetSharedWindow                       7259/72bd, recv3c, simple success34
new compatibility under test                      exact reply-shape projection
out-of-line next-event                            deferred
private HIToolbox patch                           not authorized
notification policy                               exact-21 unchanged
XNU                                               unchanged
```
