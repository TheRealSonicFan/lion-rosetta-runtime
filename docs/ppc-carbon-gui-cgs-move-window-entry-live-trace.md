# PPC Carbon GUI CGSMoveWindow entry live trace

## Status

**COMPLETED / EXTERNAL CGSMOVEWINDOW INTERPOSE BOUNDARY BYPASSED.**

The returned tracer is structurally correct and its SHA-256 is accepted on
both systems, but the trace-specific control fails: Snow and Lion both load
the v1 tracer and emit its build marker while neither emits any
PM_CGS_MOVE_WINDOW_ENTRY or PM_CGS_MOVE_WINDOW_RESULT record. Snow still
issues 66 successful 0x7218/0x727c move transactions and completes a normal
public titlebar drag; Lion issues 14 such transactions and reproduces the bad
movement. The executing Rosetta/shared-cache path therefore bypasses this
external dyld interpose boundary. No CGSMoveWindow entry value is established
by this experiment.

The same evidence exposes a stronger release differential. Snow records zero
CGSGetDisplayBounds(display 0) diagnostics. Lion records eight. Lion's first
public titlebar mouse-down is sane at (302,109) and inDrag (4); immediately
before the first bad move, Lion reports CGSGetDisplayBounds(display 0), then
performs the movementGroup query for window 849, then successfully sends
0x7218 delta (-302,-98). The observer subsequently sees the window at
(-182,17177). Snow shows the movementGroup -> 0x7218 sequence without the
display-0 failure and with ordinary movement.

Do not rebuild or rerun this tracer. The authoritative next procedure is the
static-only docs/ppc-carbon-gui-drag-event-display-contract-audit.md. It
compares the Snow PPC executing event/display contract with Lion's native
reference contract before any event payload, display ID, move payload, or
private HIToolbox change is considered.

## Prepared current-main files

~~~text
tests/ppc-cgs-move-window-entry-trace-interposer.c
Git blob 39e90f39fb383d98ab64ea133d8aaeb9890d2f1d

scripts/build-ppc-cgs-move-window-entry-trace-on-snowleopard.sh
Git blob 90ddee10cbb413d66ac8475dfcf41795735f3e25

scripts/run-snowleopard-ppc-carbon-gui-cgs-get-shared-window-control.sh
Git blob f4b7dbbb97107200984aa8ad7849e23eb8bc27f0

scripts/run-lion-ppc-carbon-gui-cgs-get-shared-window-integration.sh
Git blob 14d69b7c5c83727579c604d35049c1ef8d5c9933
~~~

Trace build ID:

~~~text
cgs-move-window-entry-passive-v1
~~~

The existing v9 runners accept the optional artifact through
ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_PATH and
ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_SHA256_FILE. They verify its SHA-256
sidecar, build marker, and 32-bit PPC architecture, append it to the inserted
library set, and select snow-passive-v1 or lion-passive-v1.

## Trace contract

Each entry emits PM_CGS_MOVE_WINDOW_ENTRY with index, mode, connection,
window, point-nullness, x_bits/y_bits, both 16-bit halves, caller_hitoolbox,
and caller_offset. Each is paired with PM_CGS_MOVE_WINDOW_RESULT. The tracer
does not allocate a replacement point, change a coordinate, normalize a float,
call another CGS query, or alter the return code.

## Safety constraints

- Keep the accepted v9 GetSharedWindow bridge and all prior compatibility unchanged.
- Use the accepted v2 public titlebar dispatcher monitor in both runs.
- Do not add a 0x7218 payload adapter.
- Do not patch DragWindow, TDragTracker, TWindowTracker, UpdateWindowBounds,
  or WindowData::SetBounds.
- Do not add the deferred out-of-line event adapter.
- Do not change CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
- Build the passive tracer only on Snow Leopard 10.6.8 / 10K549.
- Verify the repository on a modern TLS-capable staging system, transfer the
  tree offline, and verify legacy-target artifacts by SHA-256 and sidecars.
  No Git network or Git-object operation is required on Snow or Lion.

## Phase A — build the passive tracer on Snow Leopard

From the transferred current runtime tree:

~~~sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  /bin/bash ./scripts/build-ppc-cgs-move-window-entry-trace-on-snowleopard.sh
~~~

This creates:

~~~text
pm-cgs-move-window-entry-trace.dylib
pm-cgs-move-window-entry-trace.dylib.info.txt
pm-cgs-move-window-entry-trace.dylib.sha256
~~~

Require the info file to show a 32-bit PPC dylib, one 8-byte __DATA,__interpose
tuple, the _CGSMoveWindow binding, the v1 build marker, and a SHA-256 line.

## Phase B — Snow positive control

Keep the accepted v9 and titlebar-v2 artifacts in the same locations used by
the successful GetSharedWindow control, then:

~~~sh
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH=./pm-hitoolbox-titlebar-drag-trace-v2.dylib
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE=./pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256
export ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_PATH=./pm-cgs-move-window-entry-trace.dylib
export ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_SHA256_FILE=./pm-cgs-move-window-entry-trace.dylib.sha256

/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-cgs-get-shared-window-control.sh
~~~

During the active interval, perform one normal titlebar drag with visible
directional movement. Require the existing Snow v9 control to remain PASS and
also require the v1 trace build marker, at least one snow-passive-v1 entry,
at least one caller_hitoolbox=YES entry, and matching result lines.

If Snow sees no HIToolbox call, stop and return the Snow evidence unchanged.
Do not proceed to Lion.

## Phase C — transfer the tracer

Transfer only the new tracer, its info file, and its SHA-256 sidecar into the
Lion payload alongside the already accepted v9 stack. Verify:

~~~sh
/usr/bin/shasum -a 256 ./payload/pm-cgs-move-window-entry-trace.dylib
/bin/cat ./payload/pm-cgs-move-window-entry-trace.dylib.sha256
~~~

The hashes must match.

## Phase D — one Lion comparison run

From the Lion runtime tree:

~~~sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256"
export ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_PATH="$PWD/payload/pm-cgs-move-window-entry-trace.dylib"
export ROSETTA_CGS_MOVE_WINDOW_ENTRY_TRACE_SHA256_FILE="$PWD/payload/pm-cgs-move-window-entry-trace.dylib.sha256"

/bin/bash ./scripts/run-lion-ppc-carbon-gui-cgs-get-shared-window-integration.sh
~~~

Perform the same single titlebar gesture used for Snow. The existing Lion
runner may still end in its known geometry-incomplete state; that alone is not
a passive-trace failure. Require the GetSharedWindow target pass to remain,
the titlebar mouse-down still to reach inDrag (4), the trace build marker, at
least one lion-passive-v1 entry, at least one caller_hitoolbox=YES entry, and
matching result lines.

## Review gate

If the first titlebar-associated Lion CGSMoveWindow target point is already
corrupt, the next boundary moves upstream into HIToolbox's
UpdateWindowBounds/WindowData::SetBounds construction path. Do not touch
0x7218.

If the Lion CGSMoveWindow target point is sane but the existing raw 0x7218
deltas are corrupt, the failure is inside the old Snow PPC CoreGraphics local
delta calculation between CGSMoveWindow and __CGSMoveWindow. Prepare a second
passive boundary at CGSMoveWindowList; do not patch HIToolbox.

If Snow does not see the interposed HIToolbox call, the boundary is unsound
under the Rosetta shared-cache binding model. Stop and return the evidence;
do not infer anything from the absence.

## Return evidence

Return:

~~~text
pm-cgs-move-window-entry-trace.dylib.info.txt
pm-cgs-move-window-entry-trace.dylib.sha256
ppc-carbon-gui-cgs-get-shared-window-snow.log
ppc-carbon-gui-cgs-get-shared-window-snow-observer.log
lion-ppc-carbon-gui-cgs-get-shared-window.log
lion-ppc-carbon-gui-cgs-get-shared-window.raw.log
lion-ppc-carbon-gui-cgs-get-shared-window-observer.log
~~~

Do not return the dylib itself unless requested.

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Snow public titlebar drag                         PASS / normal movement
Lion public mouse-down                            YES / inDrag (4)
CGSMoveWindow entry tracer                        loaded but 0 calls on Snow/Lion
external CGSMoveWindow interpose boundary         UNSOUND / bypassed
Snow CGSGetDisplayBounds(display 0)               0
Lion CGSGetDisplayBounds(display 0)               8
first Lion bad move delta                         (-302,-98)
move-payload rewrite                              NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
event-payload rewrite                             NOT AUTHORIZED
private HIToolbox patch                           NOT AUTHORIZED
next action                                       static drag event/display contract audit
XNU                                               unchanged
~~~
