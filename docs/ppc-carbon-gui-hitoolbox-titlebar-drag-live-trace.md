# PPC Carbon GUI HIToolbox titlebar drag live trace

## Status

NEXT CONTROLLED LIVE DISCRIMINATOR after the completed Snow PPC drag-routing
audit.

The static audit passes on the exact Snow 10.6.8 / 10K549 PPC HIToolbox and
therefore also describes the accepted PPC HIToolbox image executed under
Rosetta on Lion. It resolves a narrow public boundary:

```text
HIWindowFrameView::TrackSelf(EventRef,...)
    -> DragWindow                         call site 0x000b85cc

HandleWindowEvent(EventRef)
    -> DragWindow                         call site 0x0015c094

DragWindow
    -> TDragTracker
    -> TWindowTracker::TrackWindow
```

The same report preserves the already-proven hit chain:

```text
ThemeWindowDef::HitSelf
    -> GetThemeWindowRegionHit
    -> HIThemeGetWindowRegionHit
```

No classic part-code rewrite or private HIToolbox patch is authorized.

## Objective

Perform one controlled manual drag gesture on the empty titlebar under Snow and
one under Lion while tracing only the public `DragWindow` and `FindWindow`
boundaries. The trace does not alter their arguments, return values, hit masks,
part codes, event routing, tracking, or window bounds.

The existing native CGWindow observer independently determines whether the
400x222 target window actually moved.

This distinguishes:

```text
manual gesture -> no DragWindow call
    upstream event/frame-view dispatch boundary

manual gesture -> DragWindow entered -> no movement
    DragWindow / TWindowTracker / lower movement boundary

manual gesture -> DragWindow entered -> movement
    current non-draggable observation did not reproduce
```

`FindWindow` activity is recorded as supporting evidence only. It is not
rewritten and is not required to be on the HIWindowFrameView path.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-hitoolbox-titlebar-drag-trace-interposer.c
Git blob a364995f4bf9e5456158de2b78ec75aa6ed8c95a

scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh
Git blob a2e804f38695faa5031ea1f8d36e0c9d71f02b82

scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py
Git blob 5852a250ac0d86dcbc0aa420253967e055c0cdb7

scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh
Git blob b0f3084639b549c8372b871a4691dc39110cc9cd

scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh
Git blob 9150a8733a58c93aabe557415f53ca4751214cbe
```

Trace contract:

```text
trace_build_id=hitoolbox-titlebar-drag-trace-v1
audit_contract=carbon-gui-hitoolbox-titlebar-drag-live-v1
```

The two existing CoreUI runners gained only an optional
`ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH` hook. When unset, their prior
behavior is unchanged.

## Safety constraints

- Perform exactly one click-drag-release gesture in an empty titlebar area.
- Do not click the close/minimize/zoom controls.
- Do not alter hit masks, classic part codes, event routing, actions, or
  `DragWindow` arguments/results.
- Do not interpose any private C++ HIToolbox method.
- Keep the completed exact-five shared-art mapping, exact-two corner
  `bitmapInfo=0x2002` rule, and exact-six traffic-light rule unchanged.
- Keep the distributed-notification broker unchanged.
- Do not add or broaden a CGS rule.
- Do not modify CoreUI/HIToolbox resources, Rosetta caches, or XNU.
- No kernel rebuild or reboot is required.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1
```

On Snow Leopard require:

```sh
test "$(git hash-object ./tests/ppc-hitoolbox-titlebar-drag-trace-interposer.c)" = \
  "a364995f4bf9e5456158de2b78ec75aa6ed8c95a" || exit 1
test "$(git hash-object ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh)" = \
  "a2e804f38695faa5031ea1f8d36e0c9d71f02b82" || exit 1
test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py)" = \
  "5852a250ac0d86dcbc0aa420253967e055c0cdb7" || exit 1
test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh)" = \
  "b0f3084639b549c8372b871a4691dc39110cc9cd" || exit 1
/bin/bash -n ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py","rb").read(),"drag-summary.py","exec")' || exit 1
```

On Lion require:

```sh
test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh)" = \
  "9150a8733a58c93aabe557415f53ca4751214cbe" || exit 1
test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py)" = \
  "5852a250ac0d86dcbc0aa420253967e055c0cdb7" || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py","rb").read(),"drag-summary.py","exec")' || exit 1
```

## Phase B — build the passive PPC trace on Snow

```sh
cd /path/to/lion-rosetta-runtime || exit 1

CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh \
  ./payload/pm-hitoolbox-titlebar-drag-trace.dylib || exit 1
```

Require the info report to contain:

```text
interposer_source_git_blob=a364995f4bf9e5456158de2b78ec75aa6ed8c95a
trace_build_id=hitoolbox-titlebar-drag-trace-v1
```

and require a 32-bit PPC artifact with exactly two interpose tuples for
`DragWindow` and `FindWindow`.

## Phase C — Snow positive drag control

Reuse the already-built v2 shared-art format compatibility artifact.

Before invoking the command, place the mouse pointer near the middle of the
empty titlebar area. As soon as the window is fully visible, wait briefly so
the observer records the initial position, then perform exactly one clear
click-drag-release gesture to move it at least 40 pixels horizontally. Do not
touch a traffic-light control.

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v2"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="4f4792987fded0609efda2a8b4c524bc7069c7fd"

export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/pm-hitoolbox-titlebar-drag-trace.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/pm-hitoolbox-titlebar-drag-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_INFO_FILE="$PWD/pm-hitoolbox-titlebar-drag-trace.dylib.info.txt"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-titlebar-drag-live-snow.log \
  ./ppc-carbon-gui-titlebar-drag-live-snow-observer.log || exit 1

/usr/bin/python ../scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py \
  ./ppc-carbon-gui-titlebar-drag-live-snow.log \
  ../ppc-carbon-gui-titlebar-drag-live-rendering-snow.txt || exit 1

/usr/bin/python ../scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py \
  ./ppc-carbon-gui-titlebar-drag-live-snow.log \
  ../ppc-carbon-gui-hitoolbox-titlebar-drag-live-snow.txt \
  snow YES || exit 1
```

Require the rendering summary to remain PASS and the drag summary to contain:

```text
mode=snow
manual_drag_attempted=YES
build_marker_count=1
observer_pass_count=1
observer_moved=YES
drag_call_count >= 1
drag_call_count == drag_result_count
hitoolbox_drag_call_count == drag_call_count
drag_moved_result_count >= 1
routing_state=SNOW_DRAGWINDOW_MOVED
part_code_rewrite_authorized=NO
private_HIToolbox_patch_authorized=NO
titlebar_drag_live_trace_exact=YES
RESULT: PASS
```

If Snow does not move, stop. Do not run Lion; repeat only if the two-second
manual gesture window was clearly missed.

## Phase D — transfer only the passive trace artifact

Transfer these three files from Snow to Lion's `payload/`:

```text
pm-hitoolbox-titlebar-drag-trace.dylib
pm-hitoolbox-titlebar-drag-trace.dylib.info.txt
pm-hitoolbox-titlebar-drag-trace.dylib.sha256
```

Do not replace the existing v2 shared-art compatibility artifact.

## Phase E — one Lion drag discriminator

Before invoking the command, place the mouse pointer near the middle of the
empty restored titlebar. Once the window is fully visible, wait briefly for the
initial observer sample, then perform exactly one clear click-drag-release
gesture at least 40 pixels horizontally. This is the only interaction in the
run.

The generic runner may still exit 1 solely because of the already-proven
missing ColorSync registration. Do not classify the run until the existing
format summarizer has accepted that exact oracle.

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v2"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="4f4792987fded0609efda2a8b4c524bc7069c7fd"

export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_INFO_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.info.txt"

./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh \
  "$PWD/payload/ppc-carbon-gui-smoketest-private-dyld" \
  "$PWD/payload/ppc-carbon-gui-smoketest-private-dyld.sha256" \
  "$PWD/payload/pm-carbon-gui-backing-sync-compat.dylib" \
  "$PWD/payload/pm-carbon-gui-backing-sync-compat.dylib.sha256" \
  "$PWD/payload/ppc-process-manager-security-session-auditinfo-api.dylib" \
  "$PWD/payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256" \
  "$PWD/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib" \
  "$PWD/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256" \
  "$PWD/dn-carbon-gui-registration-broker" \
  "$PWD/dn-carbon-gui-registration-broker.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-titlebar-drag-live.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-titlebar-drag-live-observer.log"
RUN_RC=$?

if [ "$RUN_RC" -ne 0 ] && [ "$RUN_RC" -ne 1 ]; then
  echo "unexpected Lion runner exit: $RUN_RC" >&2
  exit "$RUN_RC"
fi

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py \
  ./payload/lion-ppc-carbon-gui-titlebar-drag-live.log \
  ./ppc-carbon-gui-titlebar-drag-live-rendering-lion.txt || exit 1

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py \
  ./payload/lion-ppc-carbon-gui-titlebar-drag-live.log \
  ./ppc-carbon-gui-hitoolbox-titlebar-drag-live-lion.txt \
  lion YES || exit 1
```

The existing rendering summary must still report the exact five slot-0
adaptations and either full runner PASS or the exact known notification shift.

The drag summary must report `RESULT: PASS` and exactly one of these routing
states:

```text
NO_DRAGWINDOW_DISPATCH
DRAGWINDOW_ENTERED_NO_MOVE
DRAGWINDOW_MOVED
```

`OBSERVER_MOVED_WITHOUT_DRAGWINDOW` is a hard stop because it contradicts the
public drag boundary being traced.

## Review gate

### Lion: NO_DRAGWINDOW_DISPATCH

The failing gesture never crosses the public `DragWindow` boundary although
Snow does. The defect is upstream of drag tracking. Review the same-run
`FindWindow` evidence, then trace the public Carbon event delivery /
HIWindowFrameView dispatch boundary without changing the returned part code.

### Lion: DRAGWINDOW_ENTERED_NO_MOVE

The titlebar gesture reaches the same public drag primitive as Snow, but the
window does not move. The next discriminator moves below `DragWindow` toward
the existing `TWindowTracker::TrackWindow` path and its lower WindowServer/CGS
movement requests. Do not patch the private tracker.

### Lion: DRAGWINDOW_MOVED

Stop. The current non-draggable symptom did not reproduce under the exact
controlled stack. Preserve both logs and observer reports and do not add an
interaction adapter.

## Return evidence

If both summaries pass, return exactly:

```text
ppc-carbon-gui-hitoolbox-titlebar-drag-live-snow.txt
ppc-carbon-gui-hitoolbox-titlebar-drag-live-lion.txt
```

If either rendering summary fails, return that rendering summary plus the
corresponding raw log instead and stop.

## Current boundary

```text
window-frame rendering                            RESTORED
Snow static drag routing                         PASS
HIWindowFrameView::TrackSelf -> DragWindow       DIRECT / PROVEN
DragWindow -> TWindowTracker::TrackWindow        DIRECT / PROVEN
hit-mask -> classic part mapping                 unchanged / no rewrite
interaction compatibility                        NONE
next step                                        Snow/Lion passive DragWindow reachability
notification policy                              unchanged
CGS policy                                       unchanged
XNU                                              no source change indicated
```
