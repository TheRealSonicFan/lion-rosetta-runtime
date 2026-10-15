# PPC Carbon GUI HIToolbox titlebar input-route live trace

## Status

SNOW v2 CONTROL PASS / LION EVENT-TRANSPORT FAILURE ISOLATED. The corrected Lion Phase E produced a real report. The v2 dispatcher monitor loaded, installed successfully, and extended the diagnostic timer, but captured no mouse event. The unchanged CGS passive trace simultaneously records the legacy `0x7292 / 0x72f6` event transaction returning a simple 0x24 error reply whose PPC/NDR-swapped result is -304, immediately followed by `MIG: server type check failure: CGSGetNextEventRecord (Inline)`. The WindowServer observer records no movement. This is the first direct interaction-path failure and supersedes the earlier public-hit discriminator. The next controlled step is `docs/ppc-carbon-gui-cgs-get-next-event-record-protocol-audit.md`.

The first Snow live attempt did not fail the restored rendering stack. The
shared-art rendering summary remained an exact Snow PASS, the v1 trace artifact
loaded, and the native observer saw the 400x222 window throughout the active
interval, but the v1 interposer recorded zero `DragWindow` and zero
`FindWindow` calls and the window did not move.

The static routing report explains why the v1 trace boundary was unsound:
`HIWindowFrameView::TrackSelf` and `HandleWindowEvent` branch directly to
`DragWindow` inside the same HIToolbox Mach-O image, and `DragWindow` itself
branches directly to `TWindowTracker::TrackWindow`. A dyld
`__interpose` tuple does not rewrite those already-linked intra-image branch
instructions. Therefore zero v1 wrapper calls cannot be interpreted as
"Snow never dispatched DragWindow".

The historical smoke subject also quits after only two seconds. That window is
too short for a reliable manual interaction gate.

Current `main` replaces the v1 boundary with a v2 passive public Carbon-event
monitor:

- installs an `eventNotHandledErr` handler on
  `GetEventDispatcherTarget()` for mouse-down / mouse-dragged / mouse-up,
- reads the event's public global mouse location,
- calls public `FindWindow` only as an observation and records the returned
  classic part code without modifying it,
- interposes only the smoke subject's direct
  `InstallEventLoopTimer(2.0, 0.0, ...)` call and extends that one diagnostic
  quit timer to eight seconds,
- automatically extends the existing native observer window to nine seconds
  whenever the v2 trace is loaded.

The v2 monitor does not interpose or patch `HIWindowFrameView::TrackSelf`,
`ThemeWindowDef::HitSelf`, `DragWindow`, `TWindowTracker`, or any private
C++ HIToolbox method.

The public APIs and signatures used by this implementation were checked against
the Mac OS X 10.6 SDK Carbon/HIToolbox headers before the v2 source and builder
were pinned.

## Objective

First re-establish the Snow positive control with a reliable manual gesture.
The decisive Snow evidence is now:

```text
dispatcher sees mouse-down
public FindWindow(mouse-down point) == inDrag (4)
native observer records 400x222 window movement
```

Only after that Snow control passes may the same monitor be transferred to Lion.
The Lion result then distinguishes:

```text
public hit != inDrag
    live public hit classification differs

public hit == inDrag, observer does not move
    failure is after public titlebar hit classification

public hit == inDrag, observer moves
    non-draggable symptom did not reproduce
```

No part-code translation follows automatically from any result.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-hitoolbox-titlebar-drag-trace-interposer.c
Git blob 2c91ae875f0497b7aed96eb8b47a8ca7cbb06768

scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh
Git blob 2f65457b15e242783358414968d8c9baf974c937

scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py
Git blob 4b193f02f704d9b98050e18558665c8a0aa6b6a9

scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh
Git blob dcf8acaa9ccd9eae6a01099e7dcffb5bfe366fe8

scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh
Git blob 185e319f0c9fa1abeb485c5b19ccd2a69c67728e
```

Contract:

```text
trace_build_id=hitoolbox-titlebar-drag-trace-v2
analyzer_version=2
audit_contract=carbon-gui-hitoolbox-titlebar-input-route-live-v2
```

## Safety constraints

- Perform exactly one click-drag-release gesture in an empty titlebar area.
- Do not click the close/minimize/zoom controls.
- The v2 monitor must return `eventNotHandledErr`; it must not consume or
  synthesize input.
- Public `FindWindow` is observation-only; preserve its returned part code.
- Do not alter hit masks, part codes, event routing, actions, or drag tracking.
- Do not interpose private HIToolbox C++ methods.
- Retain the completed exact-five slot-0 mapping, exact-two corner
  `bitmapInfo=0x2002` rule, and exact-six traffic-light rule unchanged.
- Keep the distributed-notification broker unchanged.
- Do not add or broaden a CGS rule.
- Do not modify CoreUI/HIToolbox resources, Rosetta caches, or XNU.

## Phase A — update and pin

On Snow Leopard 10.6.8 / 10K549:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-hitoolbox-titlebar-drag-trace-interposer.c)" = \
  "2c91ae875f0497b7aed96eb8b47a8ca7cbb06768" || exit 1
test "$(git hash-object ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh)" = \
  "2f65457b15e242783358414968d8c9baf974c937" || exit 1
test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py)" = \
  "4b193f02f704d9b98050e18558665c8a0aa6b6a9" || exit 1
test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh)" = \
  "dcf8acaa9ccd9eae6a01099e7dcffb5bfe366fe8" || exit 1

/bin/bash -n ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py","rb").read(),"drag-summary.py","exec")' || exit 1
```

Do not reuse the v1 `pm-hitoolbox-titlebar-drag-trace.dylib`; rebuild it.

## Phase B — rebuild v2 on Snow

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh \
  ./payload/pm-hitoolbox-titlebar-drag-trace.dylib || exit 1
```

Require:

```text
interposer_source_git_blob=2c91ae875f0497b7aed96eb8b47a8ca7cbb06768
trace_build_id=hitoolbox-titlebar-drag-trace-v2
Mach-O ... ppc / ppc7400
__interpose size 0x00000008
```

The single interpose tuple is only `InstallEventLoopTimer`. The event handler
uses supported Carbon Event Manager registration rather than dyld interposition.

## Phase C — rerun Snow positive input control

Reuse the already accepted v2 CoreUI slot-0 artifact.

Start the command first. When the target window appears, click and drag once
from the empty middle titlebar area by at least 40 pixels, then release. The
v2 diagnostic leaves the subject open for eight seconds, so do not rush the
gesture.

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

Require the rendering summary to remain PASS and the input-route summary to
contain:

```text
analyzer_version=2
audit_contract=carbon-gui-hitoolbox-titlebar-input-route-live-v2
mode=snow
manual_drag_attempted=YES
build_marker_count=1
handler_install_count=1
handler_install_statuses=0
timer_marker_count=1
timer_mode=snow-passive-v2
timer_from_ms=2000
timer_to_ms=8000
timer_exact=YES
timer_status=0
observer_pass_count=1
observer_moved=YES
mouse_down_count >= 1
mouse_down_valid_findwindow_count >= 1
mouse_down_in_drag_count >= 1
routing_state=SNOW_PUBLIC_HIT_IN_DRAG_MOVED
public_FindWindow_observation_only=YES
part_code_rewrite_authorized=NO
private_HIToolbox_patch_authorized=NO
titlebar_input_route_live_trace_exact=YES
RESULT: PASS
```

If this Snow control fails, stop and return the regenerated input-route summary,
rendering summary, raw subject log, observer log, and v2 build info. Do not run
Lion.

## Phase D — transfer after Snow PASS only

After the Snow v2 control passes, transfer exactly:

```text
pm-hitoolbox-titlebar-drag-trace.dylib
pm-hitoolbox-titlebar-drag-trace.dylib.info.txt
pm-hitoolbox-titlebar-drag-trace.dylib.sha256
```

to Lion's `payload/`.

## Phase E — Lion discriminator after Snow PASS

The previous revision of this procedure was incomplete here: it told the
operator to summarize `./payload/lion-ppc-carbon-gui-titlebar-drag-live.log`
without first invoking the Lion runner that creates that report. The resulting
`IOError: [Errno 2]` is therefore a documentation/workflow failure, not Lion
runtime evidence.

On Lion first update and pin:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh)" = \
  "185e319f0c9fa1abeb485c5b19ccd2a69c67728e" || exit 1
test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py)" = \
  "4b193f02f704d9b98050e18558665c8a0aa6b6a9" || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py","rb").read(),"drag-summary.py","exec")' || exit 1
```

Require the transferred v2 trace artifact and the already accepted v2 CoreUI
slot-0 compatibility artifact to be present with their existing sidecars.

Perform one empty-titlebar click-drag-release gesture during the eight-second
window. The generic Lion runner may exit 1 solely because of the already-known
missing ColorSync registration; do not classify the interaction until the
dedicated rendering and input-route summaries have accepted the run.

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v2"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="4f4792987fded0609efda2a8b4c524bc7069c7fd"

export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_INFO_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.info.txt"

REPORT="$PWD/payload/lion-ppc-carbon-gui-titlebar-drag-live.log"
OBSERVER_REPORT="$PWD/payload/lion-ppc-carbon-gui-titlebar-drag-live-observer.log"

/bin/rm -f "$REPORT" "$OBSERVER_REPORT"

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
  "$REPORT" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$OBSERVER_REPORT"
RUN_RC=$?

if [ "$RUN_RC" -ne 0 ] && [ "$RUN_RC" -ne 1 ]; then
  echo "unexpected Lion runner exit: $RUN_RC" >&2
  exit "$RUN_RC"
fi

test -s "$REPORT" || {
  echo "error: Lion runner did not create report: $REPORT" >&2
  exit 66
}
test -s "$OBSERVER_REPORT" || {
  echo "error: Lion runner did not create observer report: $OBSERVER_REPORT" >&2
  exit 66
}

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py \
  "$REPORT" \
  ./ppc-carbon-gui-titlebar-drag-live-rendering-lion.txt || exit 1

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py \
  "$REPORT" \
  ./ppc-carbon-gui-hitoolbox-titlebar-drag-live-lion.txt \
  lion YES || exit 1
```

The rendering summary must remain PASS and preserve the completed exact-five
slot-0 / exact-two corner-format contract. The input-route summary must report
`RESULT: PASS` and one of:

```text
PUBLIC_HIT_NOT_IN_DRAG
PUBLIC_HIT_IN_DRAG_NO_MOVE
PUBLIC_HIT_IN_DRAG_MOVED
```

`NO_VALID_PUBLIC_HIT`, a missing report, or any summary FAIL is a hard stop.

## Observed Lion v2 result

The Snow positive control passes exactly: the dispatcher handler installs,
the subject timer is extended to eight seconds, six mouse-downs have valid
public `FindWindow` results, all six classify as `inDrag (4)`, and the
independent observer records movement.

On Lion, the same v2 monitor installs with status 0 and the subject's 2-second
timer is extended to 8 seconds, but no
`PM_HITOOLBOX_TITLEBAR_INPUT_EVENT` line appears. The 400x222 observer window
remains at x=120, y=98 until the subject exits.

At the attempted interaction boundary, Snow PPC CoreGraphics sends:

```text
request 0x7292
reply   0x72f6
bits    0x1513
send    0x18
recv    0x4030
```

and receives a successful variable-size event record. Lion receives instead a
simple 0x24 reply with raw error word `0xd0feffff`; applying the PPC/NDR
byte-order convention gives `0xfffffed0`, signed -304. CoreGraphics then logs
exactly:

```text
MIG: server type check failure: CGSGetNextEventRecord (Inline)
```

The user's beach-ball observation is therefore consistent with the event loop
failing at its WindowServer event-retrieval RPC before the public Carbon
dispatcher handler can see the mouse-down. Do not infer a part-code defect from
the absence of dispatcher events.

## Review gate

### Lion: PUBLIC_HIT_NOT_IN_DRAG

Stop before any translation. Compare the exact live `FindWindow` part and
mouse point against Snow and the prior frame/hit contract. A new compatibility
rule is not authorized by one divergent part result alone.

### Lion: PUBLIC_HIT_IN_DRAG_NO_MOVE

The public hit classification agrees with healthy Snow but the window still
does not move. The next discriminator belongs after hit classification, around
the standard frame-view / tracker transition or the lower movement request
path. Do not patch `TWindowTracker`.

### Lion: PUBLIC_HIT_IN_DRAG_MOVED

Stop. The non-draggable symptom did not reproduce under the controlled v2
interaction window; preserve the evidence and do not add an interaction
adapter.

## Return evidence

For the immediate rerun, return:

```text
ppc-carbon-gui-hitoolbox-titlebar-drag-live-snow.txt
ppc-carbon-gui-titlebar-drag-live-rendering-snow.txt
```

If Snow passes and Lion is then run, also return:

```text
ppc-carbon-gui-hitoolbox-titlebar-drag-live-lion.txt
```

## Current boundary

```text
window-frame rendering                           RESTORED
Snow static routing                             PASS
v1 DragWindow/FindWindow dyld interpose         INVALID / same-image direct branches
historical subject manual window                2 s / insufficient
v2 dispatcher event monitor                     PREPARED
v2 diagnostic subject window                    8 s
public FindWindow                               observation only
part-code rewrite                               NOT AUTHORIZED
private HIToolbox patch                         NOT AUTHORIZED
notification policy                             unchanged
CGS policy                                      unchanged
XNU                                             no source change indicated
next step                                       docs/ppc-carbon-gui-cgs-get-next-event-record-protocol-audit.md
```
