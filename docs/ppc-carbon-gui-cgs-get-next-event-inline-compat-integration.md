# PPC Carbon GUI CGS next-event inline compatibility integration

## Status

**NEXT CONTROLLED LIVE STEP.**

The event-retrieval protocol differential is closed. Snow PPC and Lion i386
use the same `__CGSGetPortStreamInline` generated-MIG wire shape but different
IDs:

```text
Snow PPC   request 0x7292  reply 0x72f6  bits 0x1513  send 0x18  recv 0x4030
Lion i386  request 0x7295  reply 0x72f9  bits 0x1513  send 0x18  recv 0x4030
```

Lion reuses Snow's old `0x7292 / 0x72f6` pair for
`__CGSGetDisplayPalette`, whose request geometry is `0x24 / 0x0c30`.
That exact ID collision explains the live -304
`CGSGetNextEventRecord (Inline)` server type-check failure.

This experiment changes only the generated-MIG IDs for the exact legacy
header-only event-stream request:

```text
request ID       0x7292 -> 0x7295
native reply ID  0x72f9 -> 0x72f6
```

No other request byte, reply byte, port, Mach bits, size, NDR byte, stream
length, or event payload is changed.

## Prepared runtime

Current `main` provides:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
  Git blob e26a28d22837e125a8de920a326e14aac3602486

scripts/build-ppc-carbon-gui-cgs-next-event-inline-compat-on-snowleopard.sh
  Git blob a5451f72ef35aba3843b914ac783d9264d959a10

scripts/run-snowleopard-ppc-carbon-gui-cgs-next-event-inline-control.sh
  Git blob d5e4ebba8e13f40ce7510b415dd623370bdb9af2

scripts/run-lion-ppc-carbon-gui-cgs-next-event-inline-integration.sh
  Git blob 3a7c9ddf74d10ba1ab704996b74ad5627d71fc76

scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py
  Git blob 4b193f02f704d9b98050e18558665c8a0aa6b6a9
```

The new combined PPC build ID is:

```text
dual-bootstrap-servercheckin-sessioninit-v5-cgs-server-version-compat-cps-registration-carbon-smoketest-compat-setfront-compat-distnotify-ingress-newwindow-compat-releasebacking-compat-opacity-alpha-create-compat-shapewindow-inline-backing-sync-next-event-inline-showwindow-addtrackingarea-orderfront-setfrontwindow-colorprofileclient-selectwindow-orderfront-compat-v7
```

The next-event predicate requires exactly:

```text
legacy request ID  0x7292
bits               0x1513
mach option        0x3
send size          0x18
receive size       0x4030
remote port        nonzero
reply port         nonzero and equal to mach_msg receive name
timeout            MACH_MSG_TIMEOUT_NONE
notify             MACH_PORT_NULL
```

The adapter copies the exact request into a private receive-sized buffer,
changes only the request ID, sends that copy, requires the native reply ID
`0x72f9`, changes only the reply ID back to `0x72f6`, and copies the
native reply back. Variable stream replies and simple replies are preserved
byte-for-byte apart from the ID word.

## Safety constraints

- Use the exact historical PPC Carbon GUI subject already pinned by the runners.
- Build the new PPC compatibility artifact only on Snow Leopard 10.6.8 /
  10K549.
- Require the Snow passthrough control before transferring the new artifact to
  Lion.
- Perform exactly one Lion integration run.
- Keep the exact-21 notification policy and every previously accepted
  compatibility rule unchanged.
- Keep the accepted CoreUI frame/titlebar/image compatibility unchanged.
- Keep the v2 public titlebar dispatcher monitor observation-only.
- Do not change classic part codes, hit masks, event-record bytes, NDR, stream
  lengths, Mach ports, or Mach sizes.
- Do not patch CoreGraphics, HIToolbox, WindowServer, Rosetta caches, or XNU.
- Do not test another PPC application in this phase.

## Phase A — pull and pin current main

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c)" = \
  "e26a28d22837e125a8de920a326e14aac3602486" || exit 1

test "$(git hash-object ./scripts/build-ppc-carbon-gui-cgs-next-event-inline-compat-on-snowleopard.sh)" = \
  "a5451f72ef35aba3843b914ac783d9264d959a10" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-cgs-next-event-inline-control.sh)" = \
  "d5e4ebba8e13f40ce7510b415dd623370bdb9af2" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-cgs-next-event-inline-integration.sh)" = \
  "3a7c9ddf74d10ba1ab704996b74ad5627d71fc76" || exit 1
```

## Phase B — build the v7 full-stack PPC artifact on Snow

From the runtime repository root:

```sh
/bin/bash ./scripts/build-ppc-carbon-gui-cgs-next-event-inline-compat-on-snowleopard.sh \
  ./payload/pm-carbon-gui-cgs-next-event-inline-compat.dylib || exit 1
```

Require:

```text
PPC 32-bit dylib
exactly the existing two interpose tuples
PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:PASSTHROUGH
PM_CGS_NEXT_EVENT_INLINE_COMPAT_RESULT:ADAPTER_PASS
CGS_NEXT_EVENT_INLINE_LEGACY
CGS_NEXT_EVENT_INLINE_LION
```

Do not transfer the artifact to Lion until Phase C passes.

## Phase C — Snow passthrough + drag positive control

Use the already accepted titlebar-drag v2 trace and accepted slot-0/image
compatibility artifacts. Set their paths as in the preceding titlebar-input
procedure. In particular, the drag trace must be loaded so the public
dispatcher can record the manual gesture.

Artifact identity for this phase is the **slot-0 v2** compatibility artifact,
not the earlier standalone bitmap-info v1 artifact:

```text
pm-coreui-image-bitmapinfo-compat.dylib
  SHA-256  87a7c0cf397db0b93a0ad83af3b3fea71d9c8dd77c224ad5fc5d9729b9e7b9b5
  source blob 9d44128acbe49de49621104c9ffc2b0c0cd74589
  historical partial-fix artifact; do not substitute for the restored-frame run

pm-coreui-windowframe-shared-art-slot0-compat.dylib
  SHA-256  e4031504390ca8fda8abaf1259feafc938f46ab8a5f4f7848ade1368fa7c5692
  source blob 4f4792987fded0609efda2a8b4c524bc7069c7fd
  build ID coreui-windowframe-shared-art-slot0-compat-v2
  required current accepted artifact
```


Example from the repository root:

```sh
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_INFO_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.info.txt"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_OBSERVER_DURATION_MS=9000

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID=coreui-windowframe-shared-art-slot0-compat-v2
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB=4f4792987fded0609efda2a8b4c524bc7069c7fd

/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-cgs-next-event-inline-control.sh \
  "$PWD/payload/ppc-carbon-gui-smoketest-private-dyld" \
  "$PWD/payload/ppc-carbon-gui-smoketest-private-dyld.sha256" \
  "$PWD/payload/pm-carbon-gui-cgs-next-event-inline-compat.dylib" \
  "$PWD/payload/pm-carbon-gui-cgs-next-event-inline-compat.dylib.sha256" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/ppc-carbon-gui-cgs-next-event-inline-snow.log" \
  "$PWD/payload/ppc-carbon-gui-cgs-next-event-inline-snow-observer.log"
```

During the nine-second window, perform one normal titlebar drag.

Require the machine gate:

```text
next_event_inline_exact_count >= 1
next_event_inline_passthrough_count == next_event_inline_exact_count
next_event_inline_adapter_pass_count=0
next_event_inline_reject_count=0
RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_SNOW_CONTROL_PASS
RESULT: PASS
```

Also require the existing public input control to record a mouse-down with
`FindWindow=inDrag (4)` and observed movement. If Snow does not pass, stop.

## Phase D — transfer only the new v7 artifact to Lion

Transfer:

```text
pm-carbon-gui-cgs-next-event-inline-compat.dylib
pm-carbon-gui-cgs-next-event-inline-compat.dylib.sha256
pm-carbon-gui-cgs-next-event-inline-compat.dylib.info.txt
```

Keep all other accepted Lion artifacts unchanged.

## Phase E — exactly one Lion next-event integration run

On Lion, pull current runtime main and set the same accepted titlebar/image
artifact paths plus the v2 drag trace. Set the accepted kernel hash exactly as
in the preceding full-stack procedure.

Then run:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_INFO_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace.dylib.info.txt"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_OBSERVER_DURATION_MS=9000

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID=coreui-windowframe-shared-art-slot0-compat-v2
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB=4f4792987fded0609efda2a8b4c524bc7069c7fd

/bin/bash ./scripts/run-lion-ppc-carbon-gui-cgs-next-event-inline-integration.sh
```

During the nine-second diagnostic window, perform one normal titlebar drag.

The event adapter gate requires:

```text
next_event_inline_exact_count >= 1
next_event_inline_adapted_request_count == next_event_inline_exact_count
next_event_inline_native_reply_count == next_event_inline_exact_count
next_event_inline_native_stream_count >= 1
next_event_inline_adapted_reply_count == next_event_inline_exact_count
next_event_inline_adapter_pass_count == next_event_inline_exact_count
next_event_inline_reject_count=0
next_event_inline_typecheck_diagnostic_count=0
RESULT: PPC_CARBON_GUI_CGS_NEXT_EVENT_INLINE_COMPAT_PASS
RESULT: PASS
```

Each adapted request must report exactly one changed byte and zero body/source
changes. Each adapted reply must report exactly one changed byte and zero body
changes.

## Phase F — summarize the public titlebar-input result

Run the existing v2 summarizer on the combined Snow and Lion logs:

```sh
/usr/bin/python ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py \
  ./payload/ppc-carbon-gui-cgs-next-event-inline-snow.log \
  ./payload/ppc-carbon-gui-cgs-next-event-inline-snow-summary.txt \
  snow YES

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py \
  ./payload/lion-ppc-carbon-gui-cgs-next-event-inline.log \
  ./payload/lion-ppc-carbon-gui-cgs-next-event-inline-summary.txt \
  lion YES
```

The decisive discriminator is:

- if Lion now records a public dispatcher mouse-down, the event-stream ID
  collision is causally upstream of the prior missing-input symptom;
- if it also records `FindWindow=inDrag (4)` and observer movement, the
  titlebar interaction defect is closed;
- if event retrieval succeeds but no public dispatcher mouse-down appears, stop
  and move one boundary upward between the stream dispatcher and Carbon Event
  Manager;
- if the exact ID adapter fails or the old type-check diagnostic remains, stop
  without broadening the predicate.

## Return evidence

Return:

```text
pm-carbon-gui-cgs-next-event-inline-compat.dylib.info.txt
pm-carbon-gui-cgs-next-event-inline-compat.dylib.sha256
ppc-carbon-gui-cgs-next-event-inline-snow.log
ppc-carbon-gui-cgs-next-event-inline-snow-summary.txt
lion-ppc-carbon-gui-cgs-next-event-inline.log
lion-ppc-carbon-gui-cgs-next-event-inline.raw.log
lion-ppc-carbon-gui-cgs-next-event-inline-observer.log
lion-ppc-carbon-gui-cgs-next-event-inline-summary.txt
```

Do not return the dylib itself unless requested.

## Current boundary

```text
native helper mapping                            RESOLVED
Snow inline IDs                                  0x7292 / 0x72f6
Lion inline IDs                                  0x7295 / 0x72f9
wire geometry                                    equivalent 0x18 / 0x4030
Lion old-ID collision                            __CGSGetDisplayPalette
compatibility under test                         ID-only
public dispatcher monitor                        retained / observation-only
classic part-code translation                    none
notification policy                              unchanged
XNU                                              unchanged
```
