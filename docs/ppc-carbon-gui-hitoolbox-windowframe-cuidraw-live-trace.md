# PPC Carbon GUI HIToolbox window-frame CUIDraw passive live trace

## Status

NEXT CONTROLLED LIVE DISCRIMINATOR after the completed HIToolbox frame/hit static differential.

## Static result entering this step

Both `carbon-gui-hitoolbox-frame-hit-contract-v1` reports pass with exact framework provenance.

The hit-test side does **not** expose a static part-code remap worth adapting. Snow PPC and Lion native `_HIThemeGetWindowRegionHit` both:

- construct the release-local theme draw state;
- call `DataEngine::GetWindowRegionHitMask(...)`;
- gate on the same required mask-valid bit;
- map the same mask bits to the same classic window part codes for the close, zoom, collapse, proxy/icon, title/drag, and related regions.

The instruction sequences differ by architecture and some validation details, but the returned-part semantics remain structurally aligned. The non-draggable Lion titlebar therefore does not authorize a part-code rewrite.

The frame side is different. Snow PPC `HIThemeDrawWindowFrameInternal` contains an explicit `__HIThemeUseCoreUI` branch and a separate:

```text
_HIThemeDrawDocumentWindowWithCoreUI(...)
```

helper. That helper issues six possible `CUIDraw` calls. Lion native HIToolbox removed that separate helper and folds the corresponding CoreUI drawing work into its much larger window-frame internal routine, which also contains six `CUIDraw` call sites.

The historical PPC process on Lion still executes the accepted Snow PPC HIToolbox image from `dyld_shared_cache_rosetta`. The next question is therefore not “which native Lion frame function should replace it?” but “what exact Snow-PPC CUIDraw requests are being issued on Snow versus Lion for the same historical subject?”

## Objective

Passively capture the exact `CUIDraw` calls made by the Snow PPC document-window CoreUI helper, first on healthy Snow Leopard and then on Lion with the accepted bitmap-info adapter retained.

The trace records only the six statically proven return offsets:

```text
0x000217ac
0x000218e4
0x00021968
0x000219ec
0x00021aa8
0x00021b20
```

For each matched call it records:

- call/slot index;
- caller return offset;
- raw float bits of the CGRect;
- whether the options dictionary and result pointer are present;
- the options dictionary count;
- string keys;
- string / Boolean / number values when safely representable;
- otherwise only the CoreFoundation type ID.

It then calls the original `CUIDraw` unchanged.

No CoreUI option, rectangle, context, dictionary, result pointer, image, metric, pixel, or return value is modified.

## Prepared files

Current runtime `main` provides:

```text
tests/ppc-hitoolbox-windowframe-cuidraw-trace-interposer.c
scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh
```

Build contract:

```text
trace_build_id=hitoolbox-windowframe-cuidraw-trace-v1
interposer_source_git_blob=66b3849aeb9f0514223bea07ca19f95d76b8e62c
```

The existing accepted bitmap-info Snow/Lion runners now accept an **optional** trace artifact through:

```text
ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_PATH
ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_SHA256_FILE
ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_INFO_FILE
```

When these variables are unset, the runners retain their prior behavior.

## Safety constraints

- Keep the accepted `CGImageCreate bitmapInfo 0x2 -> 0x2002` adapter enabled on Lion.
- Keep the exact-six titlebar mapping unchanged.
- Keep every accepted CGS / notification / HIToolbox Extras compatibility rule unchanged.
- Do not modify CUIDraw arguments or results.
- Do not modify titlebar metrics, ArtFile records, pixels, window shape, hit-test masks, or part codes.
- Do not interpose `ThemeWindowDef::HitSelf`, `GetThemeWindowRegionHit`, `HIThemeGetWindowRegionHit`, `FindWindow`, or `DragWindow`.
- Do not add a CGS rule.
- Do not modify XNU, rebuild the kernel, or reboot.
- Do not manually drag the window during this trace; the drag defect remains a separate discriminator.

## Phase A — update and syntax-check

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-hitoolbox-windowframe-cuidraw-trace-interposer.c)" = \
  "66b3849aeb9f0514223bea07ca19f95d76b8e62c" || exit 1

/bin/bash -n ./scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh || exit 1
```

## Phase B — build the passive trace on Snow

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh \
  ./payload/pm-hitoolbox-windowframe-cuidraw-trace.dylib || exit 1
```

Require in the build info:

```text
trace_build_id=hitoolbox-windowframe-cuidraw-trace-v1
interposer_source_git_blob=66b3849aeb9f0514223bea07ca19f95d76b8e62c
```

Require one PPC `__DATA,__interpose` tuple replacing only `CUIDraw`.

## Phase C — Snow positive-control trace

Use the already accepted artifacts in Snow's `payload/` directory.

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_PATH="$PWD/pm-hitoolbox-windowframe-cuidraw-trace.dylib"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_SHA256_FILE="$PWD/pm-hitoolbox-windowframe-cuidraw-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_INFO_FILE="$PWD/pm-hitoolbox-windowframe-cuidraw-trace.dylib.info.txt"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-windowframe-cuidraw-snow.log \
  ./ppc-carbon-gui-windowframe-cuidraw-snow-observer.log || exit 1
```

Require the existing Snow bitmap-info/full-stack control to remain PASS.

Additionally require:

```sh
CALLS="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' ./ppc-carbon-gui-windowframe-cuidraw-snow.log || true)"
PASSES="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' ./ppc-carbon-gui-windowframe-cuidraw-snow.log || true)"
[ "$CALLS" -gt 0 ] || exit 1
[ "$CALLS" -eq "$PASSES" ] || exit 1
```

Record the exact call sequence and all emitted option records. Do not require every one of the six static slots to execute; conditional frame components may legitimately skip a slot.

Manual Snow gate:

```text
Snow titlebar visually normal: YES
```

Do not drag the window during this run.

## Phase D — transfer only the new trace artifact

Transfer exactly:

```text
pm-hitoolbox-windowframe-cuidraw-trace.dylib
pm-hitoolbox-windowframe-cuidraw-trace.dylib.info.txt
pm-hitoolbox-windowframe-cuidraw-trace.dylib.sha256
```

to Lion's runtime `payload/`.

Do not replace any accepted compatibility artifact.

## Phase E — Lion passive trace

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_PATH="$PWD/payload/pm-hitoolbox-windowframe-cuidraw-trace.dylib"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-windowframe-cuidraw-trace.dylib.sha256"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_INFO_FILE="$PWD/payload/pm-hitoolbox-windowframe-cuidraw-trace.dylib.info.txt"

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
  "$PWD/payload/lion-ppc-carbon-gui-windowframe-cuidraw.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-windowframe-cuidraw-observer.log" || exit 1
```

The runner also creates:

```text
payload/lion-ppc-carbon-gui-windowframe-cuidraw.raw.log
```

Require all existing Lion bitmap-info/full-stack gates to remain PASS.

Additionally:

```sh
CALLS="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_CALL:' ./payload/lion-ppc-carbon-gui-windowframe-cuidraw.raw.log || true)"
PASSES="$(/usr/bin/grep -c '^PM_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_RESULT:PASSTHROUGH$' ./payload/lion-ppc-carbon-gui-windowframe-cuidraw.raw.log || true)"
[ "$CALLS" -gt 0 ] || exit 1
[ "$CALLS" -eq "$PASSES" ] || exit 1
```

Manual Lion gate:

```text
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not drag the window during this run.

## Decision gate

### Snow and Lion CUIDraw request streams differ

Identify the first differing caller slot, rectangle, option key/value, or result-pointer policy. The next step may isolate that exact input field, but no adaptation is authorized until its release semantics are statically confirmed.

### Snow and Lion request streams are equivalent

The remaining frame defect is below the Snow PPC HIToolbox request-construction boundary, inside CoreUI/resource interpretation or CGContext output. Do not rewrite the request dictionary. The next discriminator should move one layer down from the exact differing visual component.

### Existing full-stack gate regresses

Stop. Treat the trace as intrusive and do not broaden it.

### Dragging

This procedure does not resolve dragging. The static audit found no justified part-code translation. After the visual frame path is resolved or clearly separated, use a dedicated read-only hit-result discriminator; do not conflate it with the CUIDraw trace.

## Return evidence

Return:

```text
pm-hitoolbox-windowframe-cuidraw-trace.dylib.info.txt
pm-hitoolbox-windowframe-cuidraw-trace.dylib.sha256
ppc-carbon-gui-windowframe-cuidraw-snow.log
ppc-carbon-gui-windowframe-cuidraw-snow-observer.log
lion-ppc-carbon-gui-windowframe-cuidraw.log
lion-ppc-carbon-gui-windowframe-cuidraw.raw.log
lion-ppc-carbon-gui-windowframe-cuidraw-observer.log
```

Also state:

```text
Snow titlebar visually normal: YES/NO
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not return the trace dylib binary unless specifically requested.

## Current boundary

```text
frame/hit static audits                         PASS / exact provenance
Snow PPC frame CoreUI helper                    separate DrawDocumentWindowWithCoreUI
Lion native frame CoreUI path                   folded into frame internal
Snow helper CUIDraw static slots                6
Lion native frame CUIDraw static slots          6
hit mask producer                               DataEngine::GetWindowRegionHitMask on both
hit mask -> classic part mapping                structurally aligned
static part-code rewrite                        NOT AUTHORIZED
bitmapInfo 0x2 -> 0x2002                        RETAIN / causal partial fix
next step                                       passive Snow/Lion window-frame CUIDraw trace
manual drag during trace                        NO
XNU                                             no source change indicated
```
