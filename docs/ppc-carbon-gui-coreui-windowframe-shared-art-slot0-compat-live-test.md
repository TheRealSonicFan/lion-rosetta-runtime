# PPC Carbon GUI CoreUI window-frame shared-art slot-0 compatibility live test

## Status

COMPLETED PARTIAL VISUAL RESULT / FULL-STACK RUNNER FAIL.

The Snow passthrough control passed exactly. On Lion, all five slot-0 substitutions returned `ADAPTER_PASS`, all three ImageIO source bindings were established, all six accepted titlebar bitmap-info adaptations passed, and the 400x222 window reached the screen. The titlebar background became opaque/restored with the Snow-era appearance, but the top-left and top-right corners remained absent; dragging also remained nonfunctional.

The full-stack runner failed for a separate, precisely localized reason: the exact-21 notification broker accepted registrations 1..6, then the previously accepted registration 7 (`com.apple.ColorSync.DisplayProfileNotification`, payload 276) was absent. Current requests 7..20 match the prior accepted requests 8..21 sequence by payload geometry, so the broker rejected the shifted tail as state mismatches. Do not broaden the notification policy yet.

The next controlled step is `docs/ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-audit.md`.

The Snow/Lion external-boundary summaries both pass. The raw branch preserves
exact legacy IDs, the ImageIO branch recovers exactly `0x4e90`, `0x4e8f`,
and `0x4e91` at `CGImageSourceCreateWithDataProvider`, and each returned
source pointer correlates one-to-one with the final
`CGImageSourceCreateImageAtIndex` call. No private CoreUI patch or resource
rewrite is required.

This procedure introduces the first guarded window-frame shared-art
compatibility behavior.

## Compatibility contract

The adapter changes only the five proven legacy frame roles:

```text
0x4e8d -> 0x4e75
0x4e8e -> 0x4e76
0x4e8f -> 0x4e77
0x4e90 -> 0x4e78
0x4e91 -> 0x4e79
```

and returns only Lion's existing 11x11 / 484-byte slot-0 pixels.

Raw branch guards:

```text
0x4e8e  old live geometry 256x256 / bpr1024
0x4e8d  old live geometry 2x62 / bpr8
caller  CreateImageFromBytes -> CGImageCreate return 0x0002ad34
bpc/bpp 8/32
bitmapInfo 0x2
decode NULL
interpolate YES
intent default
```

ImageIO branch guards:

```text
legacy IDs exactly 0x4e90,0x4e8f,0x4e91
source creation caller return 0x0002ae28
final image caller return 0x0002afe8
source pointer must have been bound to the exact recovered legacy ID
```

For the ImageIO branch, the original ImageIO result is created first only to
obtain its release-local color space. The replacement image is then created
from the mapped Lion slot-0 provider using the healthy Snow raw image contract;
the original result is released only after a non-NULL replacement exists.
Failure falls back to the original result.

The Lion SArtFile is opened read-only and mapped privately. The adapter also
validates the exact five mapped record headers, type/count values, slot-0
geometry/length, and provider offsets before returning any replacement.

## Pre-commit verification already performed

Before committing the adapter source:

- the exact five mapped Lion record/header/provider offsets were cross-checked
  against the accepted analyzer-v2 Lion relocation report;
- the C source passed a GNU89 syntax check with `-Wall -Wextra -Werror`
  against stubs for the public ApplicationServices interfaces;
- the builder passed `bash -n`;
- the summarizer passed Python bytecode compilation.

The actual Snow Leopard/Xcode 3.2.6 PPC compile remains a required Phase-B
gate; do not proceed if it fails.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-windowframe-shared-art-slot0-compat-interposer.c
Git blob bce1c68b4c29ad736c89a1d0b7f5e923198cb561

scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh
Git blob 6cab7f5ed0e8f26e26dd963c185cc95d99eb00d6

scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat.py
Git blob 2cf5e70fdb0fd6db25b5390f8fc47c1c9eda85f7
```

Build contract:

```text
compat_build_id=coreui-windowframe-shared-art-slot0-compat-v1
interposer_source_git_blob=bce1c68b4c29ad736c89a1d0b7f5e923198cb561
```

The artifact retains the accepted exact-six titlebar-control
`bitmapInfo 0x2 -> 0x2002` Lion adaptation unchanged.

## Safety constraints

- Do not modify SArtFile, ArtFile, ArtFile200, CoreUI, HIToolbox, or the
  Rosetta cache.
- Do not copy Snow image bytes to Lion.
- Do not interpose private C++ CoreUI methods.
- Do not broaden the five-ID mapping.
- Do not alter non-target providers, sources, image indices, or images.
- Keep every accepted CGS, notification, titlebar exact-six, and bitmap-info
  rule unchanged.
- Do not change CGContext state, hit masks, classic part codes, mouse routing,
  or control actions.
- Do not click or drag the titlebar during this visual rendering test.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-windowframe-shared-art-slot0-compat-interposer.c)" = \
  "bce1c68b4c29ad736c89a1d0b7f5e923198cb561" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh)" = \
  "6cab7f5ed0e8f26e26dd963c185cc95d99eb00d6" || exit 1

test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat.py)" = \
  "2cf5e70fdb0fd6db25b5390f8fc47c1c9eda85f7" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat.py","rb").read(),"slot0-summary.py","exec")' || exit 1
```

## Phase B — build on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

/bin/bash ./scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh \
  ./payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib || exit 1
```

Require the info file to contain the build/source pins above and an
`__DATA,__interpose` section of exactly four 32-bit PPC tuples.

If compilation fails, stop and return the transcript before any live run.

## Phase C — Snow passthrough control

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="bce1c68b4c29ad736c89a1d0b7f5e923198cb561"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-shared-art-slot0-compat-snow.log \
  ./ppc-carbon-gui-shared-art-slot0-compat-snow-observer.log || exit 1

/usr/bin/python ../scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat.py \
  ./ppc-carbon-gui-shared-art-slot0-compat-snow.log \
  ../ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat-snow.txt || exit 1
```

Require:

```text
mode=snow
runner_result_pass=YES
snow_raw_passthrough_count=5
source_bind_count=0
adapter_call_count=0
adapter_result_count=0
shared_art_slot0_compat_exact=YES
RESULT: PASS
```

Manual Snow gate:

```text
Snow titlebar/window frame visually normal: YES
```

Do not proceed if Snow fails or looks different.

## Phase D — transfer only the new artifact

Transfer exactly:

```text
pm-coreui-windowframe-shared-art-slot0-compat.dylib
pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt
pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256
```

to Lion's runtime `payload/`.

## Phase E — Lion preflight

Before loading the artifact on Lion, require the exact audited resource:

```sh
SART="/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"

test "$(/usr/bin/stat -f '%z' "$SART")" = "9370228" || exit 1
test "$(/usr/bin/shasum -a 256 "$SART" | /usr/bin/awk '{print $1}')" = \
  "29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b" || exit 1
```

## Phase F — Lion integration

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="bce1c68b4c29ad736c89a1d0b7f5e923198cb561"

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
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-slot0-compat.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-slot0-compat-observer.log" || exit 1

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat.py \
  ./payload/lion-ppc-carbon-gui-shared-art-slot0-compat.log \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat-lion.txt || exit 1
```

Require:

```text
mode=lion
runner_result_pass=YES
source_bind_count=3
adapter_call_count=5
adapter_result_count=5
shared_art_slot0_compat_exact=YES
RESULT: PASS
```

The five `RESULT` activities must all be `ADAPTER_PASS`, with exactly:

```text
RAW     0x4e8e -> 0x4e76
RAW     0x4e8d -> 0x4e75
IMAGEIO 0x4e90 -> 0x4e78
IMAGEIO 0x4e8f -> 0x4e77
IMAGEIO 0x4e91 -> 0x4e79
```

Manual Lion rendering gate, without clicking or dragging:

```text
Lion titlebar/window-frame background restored: YES/NO/PARTIAL
Lion traffic-light controls remain visually sharp: YES/NO
```

## Review gate

### Both summaries pass and Lion frame background is restored

The frame-image compatibility hypothesis is confirmed. Preserve the exact-five
slot-0 adapter and exact-six bitmap-info adapter as the visual rendering
contract. The next investigation may return to the still-unresolved
interaction failure, but it must start from passive event/action routing
evidence; do not rewrite classic hit part codes.

### Both summaries pass but the Lion frame background is still absent

The shared-art construction mismatch is corrected but is not the final visual
cause. Preserve the result as a negative visual experiment and move to the
frame composition/draw-state boundary; do not broaden the image mapping.

### Any adapter result falls back or the full-stack runner fails

Stop. Do not interpret the visual result. Return the summary and raw failure
transcript before further changes.

### Snow changes visually

Reject the adapter and stop.

## Return evidence

Return:

```text
ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat-snow.txt
ppc-carbon-gui-coreui-windowframe-shared-art-slot0-compat-lion.txt
```

and the two manual Lion rendering observations above.

## Current boundary

```text
external-boundary Snow summary                   PASS
external-boundary Lion summary                   PASS
exact-five legacy-ID/source correlation          PROVEN
private CoreUI patch                             NOT REQUIRED
resource rewrite                                 NOT REQUIRED
Lion slot0 resources                             existing Lion bytes only
slot0 compatibility adapter                      LIVE-PROVEN PARTIAL VISUAL EFFECT
Lion top corners                                 MISSING
exact-21 notification sequence                   one known registration deleted / runner FAIL
interaction behavior                             STILL FAILS / separate defect
next step                                        static mapped-slot0 pixel-format audit
XNU                                              no source change indicated
```
