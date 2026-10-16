# PPC Carbon GUI CGS GetWindowShape compatibility integration

## Status

**TARGETED ADAPTER PROVEN / GETSHAREDWINDOW NEXT.**

The returned v8 Snow control passes with the public Carbon titlebar path
intact. The Lion run then proves the GetWindowShape adapter itself: 21 exact
legacy requests were adapted, all 21 native replies were accepted and returned
to the PPC client, zero adapter rejects occurred, and the former
`CGSGetWindowBounds` type-check diagnostic disappeared.

The final v8 integration result is nevertheless FAIL because the failure moved
downstream. Lion recorded 31 `_CGSFindSharedWindow` client type-check
failures, one `CGSGetNextEventRecord (Outofline)` server type-check failure,
zero titlebar dispatcher events, and zero WindowServer movement. The
notification broker also stopped at six accepted registrations rather than the
unchanged exact-21 gate. These are downstream/full-stack failures, not evidence
against the 21/21 GetWindowShape conversion.

The SharedWindow static interpretation is now corrected and completed. Both
releases use **simple**, not complex, success replies: Snow
`__CGSGetSharedWindow` uses `0x7258/0x72bc`, receive `0x38`, success
size `0x30`; Lion uses `0x7259/0x72bd`, receive `0x3c`, success size
`0x34`. Cross-release `__CGSFindSharedWindow` callers show that Lion added
one output field before the final Snow-semantic field, authorizing a guarded
reply-shape projection rather than an ID-only adapter.

The authoritative next procedure is
`docs/ppc-carbon-gui-cgs-get-shared-window-compat-integration.md`.
Do not rerun this v8 experiment unless investigating its historical result.

## Prepared runtime

Current `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-carbon-gui-cgs-get-window-shape-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-cgs-get-window-shape-control.sh
scripts/run-lion-ppc-carbon-gui-cgs-get-window-shape-integration.sh
```

The v8 combined PPC build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-next-event-inline-getwindowshape-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v8
```

The GetWindowShape predicate requires exactly:

```text
legacy request ID  0x724e
bits               0x1513
mach option        0x3
send size          0x24
receive size       0x3c
remote port        nonzero
reply port         nonzero and equal to mach_msg receive name
timeout            MACH_MSG_TIMEOUT_NONE
notify             MACH_PORT_NULL
request NDR        native local NDR record
window ID          nonzero
```

The adapter copies the request into a private buffer, changes only the request
ID, calls Lion with the unchanged `0x24/0x3c` geometry, accepts only native
reply ID `0x72b3` with either the helper's simple `0x24` reply shape or
complex `0x34` reply shape, changes only the reply ID back to `0x72b2`,
and verifies byte-change/source invariants. It does not synthesize or resize a
reply.

## Safety constraints

- Build the v8 artifact only on Snow Leopard 10.6.8/10K549.
- Require the Snow passthrough/titlebar-drag control before transferring the
  v8 artifact to Lion.
- Perform one Lion integration run.
- Keep the already proven inline event adapter enabled on Lion.
- Do not adapt `0x7258/0x72bc` SharedWindow in this step.
- Do not adapt `0x7293/0x72f7` out-of-line event retrieval in this step.
- Do not adapt `0x721f/0x7283`.
- Do not change event payloads, NDR data, message sizes, Carbon hit parts,
  notifications, rendering compatibility, HIToolbox, CoreGraphics,
  WindowServer, Rosetta caches, or XNU.
- Verify the repository tree on a modern TLS-capable staging system and
  transfer it to Snow/Lion. Do not require Git operations on either legacy
  system. Use SHA-256 and the generated sidecar for the built artifact.

## Phase A — build v8 on Snow Leopard

From the transferred current runtime tree on Snow Leopard:

```sh
./scripts/build-ppc-carbon-gui-cgs-get-window-shape-compat-on-snowleopard.sh
```

This creates:

```text
pm-carbon-gui-cgs-get-window-shape-compat.dylib
pm-carbon-gui-cgs-get-window-shape-compat.dylib.info.txt
pm-carbon-gui-cgs-get-window-shape-compat.dylib.sha256
```

Do not substitute a dylib from an earlier build ID. Keep the generated
SHA-256 sidecar with the binary.

## Phase B — Snow positive control

Use the accepted v2 dispatcher monitor, not the obsolete v1 titlebar trace.
From the Snow runtime directory:

```sh
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH=./pm-hitoolbox-titlebar-drag-trace-v2.dylib
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE=./pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256
./scripts/run-snowleopard-ppc-carbon-gui-cgs-get-window-shape-control.sh
```

During the active timer interval, press and drag the titlebar as in the
accepted Snow v2 control. Require all of the following:

```text
get_window_shape_exact_count >= 1
get_window_shape_passthrough_count == get_window_shape_exact_count
get_window_shape_adapter_pass_count = 0
get_window_shape_reject_count = 0
titlebar_drag_mouse_down_in_drag_count >= 1
observer_moved_count = 1
RESULT: PPC_CARBON_GUI_CGS_GET_WINDOW_SHAPE_SNOW_CONTROL_PASS
RESULT: PASS
```

If Snow fails, stop and return the Snow logs; do not transfer the v8 dylib to
Lion.

## Phase C — transfer the accepted v8 artifact

After the Snow control passes, transfer the v8 dylib, its `.info.txt`, and
its `.sha256` sidecar to Lion together with the already accepted full-stack
payload. Verify the transferred dylib against its SHA-256 sidecar on Lion.

## Phase D — one Lion integration run

From the Lion runtime tree:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256"
./scripts/run-lion-ppc-carbon-gui-cgs-get-window-shape-integration.sh
```

During the dispatcher-monitor interval, perform the same titlebar press/drag
gesture. The targeted compatibility result is successful if:

```text
get_window_shape_exact_count >= 1
get_window_shape_adapted_request_count == get_window_shape_exact_count
get_window_shape_native_reply_count == get_window_shape_exact_count
get_window_shape_adapted_reply_count == get_window_shape_exact_count
get_window_shape_adapter_pass_count == get_window_shape_exact_count
get_window_shape_reject_count = 0
get_window_bounds_typecheck_diagnostic_count = 0
RESULT: PASS
```

The runner reports
`PPC_CARBON_GUI_CGS_GET_WINDOW_SHAPE_COMPAT_TITLEBAR_DRAG_RESTORED` if
public Carbon input reaches `FindWindow=inDrag (4)` and WindowServer movement
returns. Otherwise it reports
`PPC_CARBON_GUI_CGS_GET_WINDOW_SHAPE_COMPAT_BOUNDARY_MOVED`; that is still a
successful test of this one adapter and means the next failure must be chosen
from the resulting raw trace rather than guessed in advance.

The counts for `_CGSFindSharedWindow`,
`CGSGetNextEventRecord (Outofline)`, and `CGSGetDisplayBounds` are
informational discriminators only.

## Return evidence

Return:

```text
pm-carbon-gui-cgs-get-window-shape-compat.dylib.info.txt
pm-carbon-gui-cgs-get-window-shape-compat.dylib.sha256
ppc-carbon-gui-cgs-get-window-shape-snow.log
ppc-carbon-gui-cgs-get-window-shape-snow-observer.log
lion-ppc-carbon-gui-cgs-get-window-shape.log
lion-ppc-carbon-gui-cgs-get-window-shape.raw.log
lion-ppc-carbon-gui-cgs-get-window-shape-observer.log
```

Do not return the dylib itself unless requested.

## Current boundary

```text
Snow GetWindowShape control                        PASS
Lion GetWindowShape exact calls                    21
Lion GetWindowShape adapter passes                 21
Lion GetWindowShape rejects                        0
old CGSGetWindowBounds diagnostic                  0 / eliminated
Lion _CGSFindSharedWindow type-check failures      31
Lion next-event out-of-line type-check             1
Lion titlebar dispatcher events                    0
Lion WindowServer movement                         NO
next action                                        exact GetSharedWindow reply-shape bridge
private HIToolbox patch                            not authorized
notification policy                               exact-21 unchanged
XNU                                               unchanged
```
