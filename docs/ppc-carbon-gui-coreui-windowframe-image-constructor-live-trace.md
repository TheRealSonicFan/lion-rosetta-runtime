# PPC Carbon GUI CoreUI window-frame image-constructor live trace

## Status

COMPLETED LIVE-PROVEN PASS. The all-CoreUI `CGImageCreate` trace found one new non-button differential at Snow-PPC return site `0x0002ad34`: Snow makes five 11x11 calls, while Lion makes only two calls at 256x256 and 2x62. The gray-gradient stream is equivalent, the exact-six titlebar stream remains the accepted compatibility path, and every result is non-NULL. Follow `docs/ppc-carbon-gui-coreui-windowframe-image-caller-resolution-audit.md` next.

## Static result entering this step

Both renderer-contract reports pass with exact pinned CoreUI slices.

For the historical Snow-PPC path, `CUIRenderer::DrawWindowFrameDark` contains:

```text
CreateImage_count=7
CreateGrayCubicGradientImage_count=2
CopyWindowTitlebarImage_count=0
CopyWindowBackgroundImage_count=0
CGContextFillRect_count=4
CGContextDrawTiledImage_count=0
```

For Lion native CoreUI:

```text
CreateImage_count=0
CreateGrayCubicGradientImage_count=1
CopyWindowTitlebarImage_count=1
CopyWindowBackgroundImage_count=1
CGContextFillRect_count=4
CGContextDrawTiledImage_count=1
```

The historical Lion PPC process is already proven to execute the Snow-era PPC CoreUI image from the Rosetta shared cache, so native Lion's copy helpers are a release-local reference only. Do not call or substitute them from the PPC process.

The key compatibility question is now whether the old Snow-PPC frame renderer constructs the same non-button CGImages on healthy Snow and faulty Lion.

The existing accepted bitmap-info adapter cannot answer that because it intentionally logs/adapts only the ArtFile loader return site `0x000299e0` and exact titlebar-button geometry. The Snow frame renderer also creates two generated gray-gradient images; their `CGImageCreate` return site is statically proven at `0x0001bdb0`. Other frame/resource image constructors may use additional CoreUI call sites.

## Objective

Run one Snow control and one Lion integration that preserve the accepted exact-six bitmap-info rule while passively logging **every** `CGImageCreate` call whose direct caller resolves inside the cached Snow-PPC CoreUI image.

For every CoreUI call the trace records:

- CoreUI caller return offset;
- width and height;
- bits/component and bits/pixel;
- bytes/row;
- incoming `bitmapInfo`;
- provider/decode presence;
- interpolation flag;
- rendering intent;
- whether the call is the exact accepted titlebar bitmap-info target;
- NULL versus non-NULL result;
- the effective bitmap-info actually sent to CoreGraphics.

The compatibility behavior remains identical to the accepted adapter:

- Snow: exact 14x16 / 8 / 32 / 56 / `0x2` ArtFile-loader calls pass through;
- Lion: exact 16x16 / 8 / 32 / 64 / `0x2` ArtFile-loader calls change only `bitmapInfo` to `0x2002`;
- every non-target call passes through unchanged.

No pixel, provider, image object, geometry, color, CGContext, or resource byte is changed.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-windowframe-image-constructor-trace-compat-interposer.c
Git blob 8f5d01d98de76d14becca553dbef806a54d40802

scripts/build-ppc-coreui-windowframe-image-constructor-trace-compat-on-snowleopard.sh
Git blob 7a44118e068b1a8f1bb6982215878d4cd6601c3d

scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh
Git blob ccf1494011a9e3306a32c2f094e0c3437f2fa03c

scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh
Git blob 61879224e7a2136c6d26ee8710d3f96e0eb6d1a7
```

Build contract:

```text
compat_build_id=coreui-windowframe-image-constructor-trace-compat-v1
interposer_source_git_blob=8f5d01d98de76d14becca553dbef806a54d40802
```

The existing Snow/Lion bitmap-info runners now accept optional expected build/source pins through:

```text
ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID
ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB
```

Their defaults remain the previously accepted `coreui-image-bitmapinfo-compat-v1` artifact; no accepted default behavior changed.

## Safety constraints

- Keep every accepted CGS, notification, HIToolbox Extras, titlebar exact-six, and geometry rule unchanged.
- Keep the exact `0x2 -> 0x2002` adaptation only for the existing six target calls on Lion.
- Do not broaden the bitmap-info adaptation to any newly observed frame image.
- Do not alter image dimensions, providers, pixel buffers, color spaces, interpolation, rendering intent, or return objects.
- Do not add ArtFile mappings.
- Do not patch CoreUI, HIToolbox, ArtFile, ArtFile200, recipes, or metrics.
- Do not interpose private C++ renderer methods.
- Do not change hit-test masks or classic window part codes.
- Do not modify XNU, rebuild the kernel, or reboot.
- Do not manually drag the window during this trace.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-windowframe-image-constructor-trace-compat-interposer.c)" = \
  "8f5d01d98de76d14becca553dbef806a54d40802" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-windowframe-image-constructor-trace-compat-on-snowleopard.sh)" = \
  "7a44118e068b1a8f1bb6982215878d4cd6601c3d" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh)" = \
  "ccf1494011a9e3306a32c2f094e0c3437f2fa03c" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh)" = \
  "61879224e7a2136c6d26ee8710d3f96e0eb6d1a7" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-windowframe-image-constructor-trace-compat-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh || exit 1
```

## Phase B — build the trace+compat artifact on Snow Leopard

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-windowframe-image-constructor-trace-compat-on-snowleopard.sh \
  ./payload/pm-coreui-windowframe-image-constructor-trace-compat.dylib || exit 1
```

Require in the info file:

```text
compat_build_id=coreui-windowframe-image-constructor-trace-compat-v1
interposer_source_git_blob=8f5d01d98de76d14becca553dbef806a54d40802
```

Require exactly one PPC `__DATA,__interpose` tuple replacing only `CGImageCreate`.

## Phase C — Snow positive control

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/pm-coreui-windowframe-image-constructor-trace-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/pm-coreui-windowframe-image-constructor-trace-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/pm-coreui-windowframe-image-constructor-trace-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-image-constructor-trace-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="8f5d01d98de76d14becca553dbef806a54d40802"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-windowframe-image-trace-snow.log \
  ./ppc-carbon-gui-windowframe-image-trace-snow-observer.log || exit 1
```

Require the existing Snow bitmap-info/full-stack control to remain PASS.

Then require:

```sh
CALLS="$(/usr/bin/grep -c '^PM_COREUI_WINDOWFRAME_IMAGE_TRACE_CALL:' ./ppc-carbon-gui-windowframe-image-trace-snow.log || true)"
RESULTS="$(/usr/bin/grep -c '^PM_COREUI_WINDOWFRAME_IMAGE_TRACE_RESULT:' ./ppc-carbon-gui-windowframe-image-trace-snow.log || true)"
LIMIT="$(/usr/bin/grep -c '^PM_COREUI_WINDOWFRAME_IMAGE_TRACE_LIMIT:' ./ppc-carbon-gui-windowframe-image-trace-snow.log || true)"

[ "$CALLS" -gt 0 ] || exit 1
[ "$CALLS" -eq "$RESULTS" ] || exit 1
[ "$LIMIT" -eq 0 ] || exit 1
```

Record the complete ordered `CALL` and `RESULT` lines.

Manual Snow gate:

```text
Snow titlebar visually normal: YES
```

Do not proceed to Lion if that answer is NO.

## Phase D — transfer only the new artifact

Transfer exactly:

```text
pm-coreui-windowframe-image-constructor-trace-compat.dylib
pm-coreui-windowframe-image-constructor-trace-compat.dylib.info.txt
pm-coreui-windowframe-image-constructor-trace-compat.dylib.sha256
```

to Lion's runtime `payload/`.

Do not replace any other accepted artifact.

## Phase E — Lion integration trace

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-image-constructor-trace-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-image-constructor-trace-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-image-constructor-trace-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-image-constructor-trace-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="8f5d01d98de76d14becca553dbef806a54d40802"

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
  "$PWD/payload/lion-ppc-carbon-gui-windowframe-image-trace.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-windowframe-image-trace-observer.log" || exit 1
```

The runner also creates:

```text
payload/lion-ppc-carbon-gui-windowframe-image-trace.raw.log
```

Require the existing Lion full-stack/bitmap-info integration to remain PASS, including exactly six accepted bitmap-info adaptations and zero adapter NULL results.

Then require against the raw log:

```sh
CALLS="$(/usr/bin/grep -c '^PM_COREUI_WINDOWFRAME_IMAGE_TRACE_CALL:' ./payload/lion-ppc-carbon-gui-windowframe-image-trace.raw.log || true)"
RESULTS="$(/usr/bin/grep -c '^PM_COREUI_WINDOWFRAME_IMAGE_TRACE_RESULT:' ./payload/lion-ppc-carbon-gui-windowframe-image-trace.raw.log || true)"
LIMIT="$(/usr/bin/grep -c '^PM_COREUI_WINDOWFRAME_IMAGE_TRACE_LIMIT:' ./payload/lion-ppc-carbon-gui-windowframe-image-trace.raw.log || true)"

[ "$CALLS" -gt 0 ] || exit 1
[ "$CALLS" -eq "$RESULTS" ] || exit 1
[ "$LIMIT" -eq 0 ] || exit 1
```

Manual Lion gate:

```text
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not drag the window during this run.

## Review method

Pair Snow and Lion trace records by ordered CoreUI caller offset and role.

Known caller:

```text
0x0001bdb0  Snow-PPC CreateGrayCubicGradientImage -> CGImageCreate
0x000299e0  Snow-PPC ArtFile image loader -> CGImageCreate
```

The `0x000299e0` exact titlebar-control calls have an already accepted difference:

```text
Snow geometry 14x16 / raw bitmapInfo 0x2 / effective 0x2
Lion geometry 16x16 / raw bitmapInfo 0x2 / effective 0x2002
```

Do not treat that known difference as new evidence.

Focus on every other CoreUI call, especially:

- calls from `0x0001bdb0`;
- non-target calls from `0x000299e0`;
- caller offsets that occur only on one OS;
- NULL results;
- differences in geometry, bpc/bpp/bpr, raw bitmapInfo, provider/decode presence, interpolation, or intent.

## Decision gate

### Frame-related CoreUI image calls differ between healthy Snow and faulty Lion

Identify the first differing non-button call. Do not adapt it immediately.

If the differing call is from `0x000299e0`, prove the corresponding Snow/Lion resource-body channel/format contract before changing bitmap info.

If the differing call is from `0x0001bdb0`, isolate the gray-gradient input or CoreGraphics interpretation before changing any pixels or color space.

If a Lion result is NULL where Snow is non-NULL, trace only that constructor's resource/provider input next.

### All non-button CoreUI image-constructor calls are equivalent

Close image construction as the immediate frame defect. The next discriminator becomes the actual Snow-PPC frame drawing state: CGContext fill/composite operations and the backing context/surface state, not another ArtFile mapping or bitmap-info expansion.

### Existing compatibility gate regresses

Stop. Treat the diagnostic artifact as intrusive and keep the previously accepted bitmap-info artifact as authoritative.

## Observed result

The returned artifact matches the pinned trace+compat identity and both Snow/Lion compatibility runs remain PASS.

The complete live constructor differential is:

```text
caller 0x0001bdb0
  Snow: 2 x 1x22, 8 bpc / 8 bpp / bpr 1, bitmapInfo 0x0
  Lion: 2 x 1x22, 8 bpc / 8 bpp / bpr 1, bitmapInfo 0x0
  all results NONNULL
  conclusion: equivalent gray-gradient stream

caller 0x000299e0
  Snow: 6 x 14x16 / bpr 56 / raw 0x2 / effective 0x2
  Lion: 6 x 16x16 / bpr 64 / raw 0x2 / effective 0x2002
  all results NONNULL
  conclusion: known exact-six compatibility path; retain unchanged

caller 0x0002ad34
  Snow: 5 x 11x11 / bpr 44 / raw 0x2
  Lion: 1 x 256x256 / bpr 1024 / raw 0x2
        1 x 2x62 / bpr 8 / raw 0x2
  provider NONNULL / decode NULL / interpolate YES / intent 0 throughout
  all results NONNULL
  conclusion: first new non-button live differential
```

The new evidence does not support another bitmap-info rule: `0x0002ad34` differs first in call count and geometry, not constructor success. Resolve that return site to its containing Snow-PPC CoreUI function and identify the source of those dimensions before tracing or changing anything else.

Manual functional observation now also records that Snow's traffic-light buttons work, whereas Lion's sharp traffic-light images are cosmetic only and clicking them has no effect; Lion titlebar dragging remains non-functional. The current trace contains no mouse/hit-test data, so this interaction defect remains a separate held branch unless the `0x0002ad34` provenance directly connects to frame regions or masks.

Follow `docs/ppc-carbon-gui-coreui-windowframe-image-caller-resolution-audit.md` next.

## Return evidence

Return:

```text
pm-coreui-windowframe-image-constructor-trace-compat.dylib.info.txt
pm-coreui-windowframe-image-constructor-trace-compat.dylib.sha256
ppc-carbon-gui-windowframe-image-trace-snow.log
ppc-carbon-gui-windowframe-image-trace-snow-observer.log
lion-ppc-carbon-gui-windowframe-image-trace.log
lion-ppc-carbon-gui-windowframe-image-trace.raw.log
lion-ppc-carbon-gui-windowframe-image-trace-observer.log
```

Also state:

```text
Snow titlebar visually normal: YES/NO
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not return the dylib binary unless specifically requested.

## Current boundary

```text
all-CoreUI CGImageCreate trace                   PASS
Snow total CoreUI CGImageCreate                   13
Lion total CoreUI CGImageCreate                   10
0x0001bdb0 gray-gradient stream                   EQUIVALENT: 2 x 1x22
0x000299e0 exact-six stream                       KNOWN / RETAIN
0x0002ad34 new non-button stream                  Snow 5x11x11; Lion 256x256 + 2x62
all traced results                                NONNULL
accepted exact-six bitmapInfo adapter             RETAIN
new bitmapInfo broadening                         NOT AUTHORIZED
Lion titlebar controls                            VISUAL ONLY; clicks non-functional
Lion titlebar drag                                NON-FUNCTIONAL
next step                                         docs/ppc-carbon-gui-coreui-windowframe-image-caller-resolution-audit.md
XNU                                               no source change indicated
```
