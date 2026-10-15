# PPC Carbon GUI CoreUI window-frame shared-art external-boundary live trace

## Status

NEXT CONTROLLED LIVE STEP.

The completed static slot-0 boundary audit proves that the five-ID semantic
relocation is necessary but that an ID-only remap is insufficient. It also
identifies a passive external-only way to recover the missing ImageIO IDs:

- raw branch: `CreateImageFromBytes(long,long)` preserves the caller's legacy
  image ID in its saved incoming `r30`; this is already live-proven at
  `CGImageCreate`;
- ImageIO branch: `CreateImageSource(long)` is entered while the parent
  `CreateImage(long,float)` still has the original legacy ID in live `r30`;
  its prologue saves that incoming `r30` at frame offset `+0x58`;
- therefore calls from `CreateImageSource` to
  `CGDataProviderCreateWithData` and
  `CGImageSourceCreateWithDataProvider` can recover the exact legacy ID
  before `CreateImage(long,float)` later clears/reuses `r30`;
- the returned `CGImageSourceRef` can then be correlated by pointer with the
  later `CGImageSourceCreateImageAtIndex` call.

This trace changes no provider, image source, geometry, resource byte, image
ID, or return value. It retains only the previously accepted exact-six
`bitmapInfo 0x2 -> 0x2002` adaptation on Lion.

## Objective

Live-prove that the external CoreGraphics/ImageIO boundary retains enough
context to implement an exact-five compatibility adapter without patching
private CoreUI methods or rewriting resources.

Expected target partition:

```text
Snow raw:    0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
Snow ImageIO target sources: none

Lion raw:    0x4e8e,0x4e8d
Lion ImageIO target sources: 0x4e90,0x4e8f,0x4e91
```

For ImageIO targets, the trace must prove the chain:

```text
legacy image ID
  -> CGDataProviderCreateWithData provider
  -> CGImageSourceCreateWithDataProvider returned source pointer
  -> CGImageSourceCreateImageAtIndex same source pointer
  -> non-NULL CGImage
```

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-windowframe-shared-art-external-boundary-trace-compat-interposer.c
Git blob a1e8bcf34a4894aa90e4fc948c8ca6d176113149

scripts/build-ppc-coreui-windowframe-shared-art-external-boundary-trace-compat-on-snowleopard.sh
Git blob e1adc4a31f85b7ff35068440b118764150b87265

scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-trace.py
Git blob c7b820409d1b101dcd40d2a078aaf0b950740542
```

Build contract:

```text
compat_build_id=coreui-windowframe-shared-art-external-boundary-trace-compat-v1
interposer_source_git_blob=a1e8bcf34a4894aa90e4fc948c8ca6d176113149
```

The dylib interposes exactly four public external APIs:

```text
CGDataProviderCreateWithData
CGImageCreate
CGImageSourceCreateWithDataProvider
CGImageSourceCreateImageAtIndex
```

Only `CGImageCreate` retains compatibility behavior, and only for the existing
exact-six titlebar-control predicate.

## Safety constraints

- Do not patch or interpose private C++ CoreUI methods.
- Do not map `0x4e8d..0x4e91` to `0x4e75..0x4e79` yet.
- Do not force slot 0.
- Do not modify provider data/length, image geometry, source pointers, image
  indices, resource bytes, or returned images.
- Keep every accepted CGS, notification, HIToolbox Extras, titlebar exact-six,
  and bitmap-info rule unchanged.
- Do not modify SArtFile, ArtFile, ArtFile200, CoreUI, HIToolbox, or the
  Rosetta cache.
- Do not change hit masks, part codes, mouse routing, CGContext state, or CGS
  policy.
- Do not modify XNU, rebuild the kernel, or reboot.
- Do not click or drag the titlebar during the trace.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-windowframe-shared-art-external-boundary-trace-compat-interposer.c)" = \
  "a1e8bcf34a4894aa90e4fc948c8ca6d176113149" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-windowframe-shared-art-external-boundary-trace-compat-on-snowleopard.sh)" = \
  "e1adc4a31f85b7ff35068440b118764150b87265" || exit 1

test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-trace.py)" = \
  "c7b820409d1b101dcd40d2a078aaf0b950740542" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-windowframe-shared-art-external-boundary-trace-compat-on-snowleopard.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-trace.py","rb").read(),"external-boundary-summary.py","exec")' || exit 1
```

## Phase B — build on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-windowframe-shared-art-external-boundary-trace-compat-on-snowleopard.sh \
  ./payload/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib || exit 1
```

Require the info file to contain the build/source pins above and an
`__DATA,__interpose` section of exactly four 32-bit PPC tuples.

## Phase C — Snow positive control

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-external-boundary-trace-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="a1e8bcf34a4894aa90e4fc948c8ca6d176113149"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-shared-art-external-boundary-snow.log \
  ./ppc-carbon-gui-shared-art-external-boundary-snow-observer.log || exit 1

/usr/bin/python ../scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-trace.py \
  ./ppc-carbon-gui-shared-art-external-boundary-snow.log \
  ../ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-snow.txt || exit 1
```

Require summary:

```text
mode=snow
raw_target_call_count=5
raw_provider_target_count=5
imageio_source_target_count=0
correlated_final_target_count=0
external_boundary_trace_exact=YES
RESULT: PASS
```

Do not proceed to Lion if Snow fails.

## Phase D — transfer only the new artifact

Transfer exactly:

```text
pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib
pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib.info.txt
pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib.sha256
```

to Lion's runtime `payload/`.

## Phase E — Lion integration trace

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-external-boundary-trace-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-external-boundary-trace-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="a1e8bcf34a4894aa90e4fc948c8ca6d176113149"

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
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-external-boundary.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-external-boundary-observer.log" || exit 1

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-trace.py \
  ./payload/lion-ppc-carbon-gui-shared-art-external-boundary.log \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-lion.txt || exit 1
```

Require summary:

```text
mode=lion
raw_target_call_count=2
raw_provider_target_count=2
imageio_source_target_count=3
correlated_final_target_count=3
external_boundary_trace_exact=YES
RESULT: PASS
```

The three correlated ImageIO IDs must be exactly:

```text
0x4e90
0x4e8f
0x4e91
```

and every correlated final result must be non-NULL.

## Review gate

### Both summaries pass and all three ImageIO sources correlate exactly

The external-only implementation boundary is proven. The next step may design
a guarded exact-five compatibility adapter using only public CoreGraphics /
ImageIO interposition and Lion resource bytes:

- raw branch: replace only the two target raw images with mapped Lion slot-0
  representations;
- ImageIO branch: bind the three target source pointers to their legacy IDs and
  return mapped Lion slot-0 images at final image creation;
- every non-target call remains passthrough;
- Snow remains pure passthrough.

Do not implement that adapter before both live summaries pass.

### Snow target recovery fails

Stop. The stack-frame assumption is wrong for the new provider/source
wrappers.

### Lion ImageIO source IDs are not exactly the expected three

Stop. Do not infer the missing IDs from static type/count partition alone.

### Source pointers do not correlate one-to-one with final ImageIO calls

Stop. A source-pointer keyed adapter is not justified; design a trace-only
per-thread correlation experiment instead.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-snow.txt
ppc-carbon-gui-coreui-windowframe-shared-art-external-boundary-lion.txt
```

## Current boundary

```text
five-ID semantic relocation                     PROVEN
Lion mapped slot0                                11x11 / 484
Lion mapped slot1                                22x22 / 1936
private CUISharedArtReader interposition          NOT AUTHORIZED
raw external boundary                            exact-ID recovery already proven
ImageIO source external boundary                 statically viable / live proof required
new compatibility behavior                       NONE in this trace
next step                                        Snow/Lion external-boundary correlation trace
XNU                                              no source change indicated
```
