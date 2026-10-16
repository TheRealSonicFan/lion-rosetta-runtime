# PPC Carbon GUI CGS GetWindowShape compatibility integration

## Status

**STATIC DIFFERENTIAL RESOLVED / EXACT GETWINDOWSHAPE INTEGRATION NEXT.**

The returned post-inline static reports pass on Snow Leopard 10.6.8/10K549
and Lion 10.7.5/11G63 with the accepted CoreGraphics SHA-256 binaries. Together
with the earlier complete static reports from those same binaries, they resolve
the next live failure as another generated-MIG ID collision.

The public `CGSGetWindowBounds` path calls `__CGSGetWindowShape` on both
releases:

```text
Snow PPC   __CGSGetWindowShape  request 0x724e  reply 0x72b2  bits 0x1513  send 0x24  recv 0x3c
Lion i386  __CGSGetWindowShape  request 0x724f  reply 0x72b3  bits 0x1513  send 0x24  recv 0x3c
```

Lion reuses Snow's old `0x724e/0x72b2` pair for
`__CGSSetWindowShapeInline`. That collision exactly explains the live
`CGSGetWindowBounds` server type-check failure. The release-local
`__CGSGetWindowShape` request geometry is otherwise identical, so this
experiment changes only:

```text
request ID       0x724e -> 0x724f
native reply ID  0x72b3 -> 0x72b2
```

The audit also resolves two later families, but they are deliberately not
adapted in this step. Snow `__CGSGetPortStreamOutofline` uses
`0x7293/0x72f7` while Lion uses `0x7296/0x72fa`, with the same
`0x18/0x3c` envelope. By contrast, `__CGSGetSharedWindow` changes both IDs
and success-reply geometry: Snow uses `0x7258/0x72bc`, receive `0x38`,
complex success size `0x30`; Lion uses `0x7259/0x72bd`, receive `0x3c`,
complex success size `0x34`. Therefore the SharedWindow path is **not**
authorized for an ID-only adapter. The `0x721f/0x7283` pair is
`__CGSGetSystemWindow` on both releases and is not a
`CGSGetDisplayBounds` migration.

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
inline next-event 0x7292 -> 0x7295                 proven
CGSGetWindowBounds lower helper                    __CGSGetWindowShape
Snow GetWindowShape IDs                            0x724e / 0x72b2
Lion GetWindowShape IDs                            0x724f / 0x72b3
GetWindowShape wire geometry                       equivalent 0x24 / 0x3c
compatibility under test                           ID-only
SharedWindow                                       geometry changed; deferred
out-of-line event retrieval                        ID-only candidate; deferred
0x721f / 0x7283                                    same GetSystemWindow family
private HIToolbox patch                            not authorized
XNU                                                unchanged
```
