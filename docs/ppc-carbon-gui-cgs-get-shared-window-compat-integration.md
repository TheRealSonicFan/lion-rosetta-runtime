# PPC Carbon GUI CGS GetSharedWindow reply-shape compatibility integration

## Status

**GETSHAREDWINDOW TARGET PROVEN / DRAG DELTA SOURCE NEXT.**

The returned v9 Snow control is a clean PASS and retains the accepted public
titlebar drag. The Lion run proves the GetSharedWindow bridge at scale: 847
exact legacy calls were adapted, 847 native success replies were projected
back to the Snow contract, zero adapter rejects occurred, and the former
`_CGSFindSharedWindow` client type-check count fell to zero. The previously
observed out-of-line next-event type-check also did not recur.

Most importantly, Carbon input is no longer stalled. Lion records a public
mouse-down at `h=317 v=111` with `FindWindow` part `4` (`inDrag`),
the beach ball is gone, and WindowServer records movement. The remaining
failure is now movement geometry: the window starts at `(120,98)`, then
jumps off-screen. The live move requests show the client itself sending
`(-317,-98)` and then vertical delta `17118 = 0x42de`; `0x42de` is
the high halfword of float `111.0`, matching the mouse-down vertical
coordinate. This localizes the next question to the old PPC
`DragWindow/TDragTracker/TWindowTracker` point-to-delta path, before
WindowServer applies the move.

The bridge remains accepted for the next experiment. Do not change its
reply projection merely because later `Invalid window 0x8` diagnostics
remain; the targeted MIG client-shape failure is eliminated and the new
off-screen symptom has a more direct, payload-level discriminator.

The authoritative next procedure is
`docs/ppc-carbon-gui-titlebar-drag-delta-source-audit.md`. It is static-only;
do not rerun this v9 live experiment unless investigating its historical
result.

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
Snow GetSharedWindow control                       PASS
Lion GetSharedWindow exact calls                   847
Lion GetSharedWindow adapter passes                847
Lion GetSharedWindow rejects                       0
Lion _CGSFindSharedWindow type-check               0
Lion out-of-line next-event type-check             0
Lion public titlebar mouse-down                    YES / inDrag (4)
Lion WindowServer movement                         YES
initial window origin                              (120,98)
first move delta                                   (-317,-98)
second vertical move delta                         17118 / 0x42de
remaining symptom                                  off-screen drag geometry
next action                                        static drag-delta source audit
0x7218 payload rewrite                             not authorized
private HIToolbox patch                            not authorized
notification policy                               exact-21 unchanged
XNU                                               unchanged
```
