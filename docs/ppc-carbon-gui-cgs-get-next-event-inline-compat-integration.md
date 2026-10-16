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

Current `main` provides the following files; repository identity is verified on
the modern staging system before transfer, not by Git commands on Snow Leopard
or Lion:

```text
tests/ppc-process-manager-coreservices-sessioninit-compat-interposer.c
scripts/build-ppc-carbon-gui-cgs-next-event-inline-compat-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-cgs-next-event-inline-control.sh
scripts/run-lion-ppc-carbon-gui-cgs-next-event-inline-integration.sh
scripts/summarize-ppc-carbon-gui-hitoolbox-titlebar-drag-trace.py
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

## Phase A — stage and transfer current main without Git on legacy targets

Do not run Git on Snow Leopard or Lion. These systems are treated as offline
legacy execution targets. Obtain current `main` on a modern TLS-capable system,
verify the repository there, then transfer the repository tree to Snow Leopard
and Lion by your normal method. If you archive the tree for transfer, verify the
archive SHA-256 before and after transfer.

On Snow Leopard and Lion, provenance checks in this procedure use
`/usr/bin/shasum -a 256` only. The builders do not invoke Git, and the runners
do not use Git blob IDs or `.info.txt` metadata as acceptance gates.
`.info.txt` files remain useful as returned diagnostic evidence, but artifact
identity is the computed SHA-256 plus its SHA-256 sidecar; embedded build markers
are checked only as a semantic sanity check on the loaded binary.

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

Artifact identity for this phase is SHA-256 based. The required
accepted dependencies are:

```text
pm-hitoolbox-titlebar-drag-trace-v2.dylib
  SHA-256  c8bc82713e4342c651cd2e3784d9d963597700a35cdcd739bba3c7dab8381093
  semantic marker hitoolbox-titlebar-drag-trace-v2

pm-titlebar-bsearch-six-key-compat.dylib
  SHA-256  6bd11d4e9b271eab926f56f9cf99f4c4fb606db1d69a98f062cc398561488c72

pm-coreui-windowframe-shared-art-slot0-compat.dylib
  SHA-256  e4031504390ca8fda8abaf1259feafc938f46ab8a5f4f7848ade1368fa7c5692
  semantic marker coreui-windowframe-shared-art-slot0-compat-v2
```

The earlier standalone `pm-coreui-image-bitmapinfo-compat.dylib` has SHA-256
`87a7c0cf397db0b93a0ad83af3b3fea71d9c8dd77c224ad5fc5d9729b9e7b9b5`;
it is a historical partial-fix artifact and must not replace the accepted
slot-0 v2 artifact above. No Git blob ID is used in this phase.

The historical filename `pm-hitoolbox-titlebar-drag-trace.dylib` is
ambiguous. The Library artifact with that exact unsuffixed name is the **v1**
DragWindow/FindWindow interposer, SHA-256
`294ebfc3697bff7e06e21d00e781ca1d29d7a5d028ce6f857e8869877e89d70f`,
and it is not suitable for this experiment because it cannot observe the
dispatcher path isolated by the corrected Snow control. The later v2 dispatcher
monitor was historically built under the same basename and has SHA-256
`c8bc82713e4342c651cd2e3784d9d963597700a35cdcd739bba3c7dab8381093`.
To prevent another v1/v2 collision, current instructions build and use the
distinct local filename `pm-hitoolbox-titlebar-drag-trace-v2.dylib`.

Before the Phase C run, rebuild the v2 trace on Snow Leopard from the transferred
verified tree:

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
  ./scripts/build-ppc-hitoolbox-titlebar-drag-trace-on-snowleopard.sh \
  ./payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib || exit 1
```

Require its generated SHA-256 sidecar to report
`c8bc82713e4342c651cd2e3784d9d963597700a35cdcd739bba3c7dab8381093`
before continuing.

Example from the repository root:

```sh
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_EXPECTED_SHA256=c8bc82713e4342c651cd2e3784d9d963597700a35cdcd739bba3c7dab8381093
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_OBSERVER_DURATION_MS=9000

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SHA256=e4031504390ca8fda8abaf1259feafc938f46ab8a5f4f7848ade1368fa7c5692

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

On Lion, use the repository tree already verified and transferred from the modern
staging system; do not run Git on Lion. Set the same accepted titlebar/image
artifact paths plus the v2 drag trace. Set the accepted kernel hash exactly as
in the preceding full-stack procedure.

Then run:

```sh
export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3

export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_PATH="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-titlebar-drag-trace-v2.dylib.sha256"
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_TRACE_EXPECTED_SHA256=c8bc82713e4342c651cd2e3784d9d963597700a35cdcd739bba3c7dab8381093
export ROSETTA_HITOOLBOX_TITLEBAR_DRAG_OBSERVER_DURATION_MS=9000

export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_PATH="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib"
export ROSETTA_COREUI_TITLEBAR_BSEARCH_COMPAT_SHA256_FILE="$PWD/payload/pm-titlebar-bsearch-six-key-compat.dylib.sha256"

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SHA256=e4031504390ca8fda8abaf1259feafc938f46ab8a5f4f7848ade1368fa7c5692

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
