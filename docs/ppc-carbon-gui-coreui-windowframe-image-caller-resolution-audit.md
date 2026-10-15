# PPC Carbon GUI CoreUI window-frame image caller-resolution audit

## Status

NEXT CONTROLLED STATIC STEP after the all-CoreUI `CGImageCreate` live trace found one new non-button constructor stream that differs sharply between healthy Snow Leopard and faulty Lion.

## Reviewed live result

The returned diagnostic artifact matches the pinned implementation:

```text
interposer_source_git_blob=8f5d01d98de76d14becca553dbef806a54d40802
compat_build_id=coreui-windowframe-image-constructor-trace-compat-v1
artifact_sha256=9658c0987a083202b9357967ced3dd6401884f046e0c0da17612dc93b27a6274
```

Both existing compatibility stacks remain PASS and every traced `CGImageCreate` result is non-NULL.

The complete CoreUI-originating constructor streams reduce to three caller return sites:

```text
0x0001bdb0  gray-gradient control
  Snow: 2 calls, 1x22, 8 bpc / 8 bpp / bpr 1, bitmapInfo 0x0
  Lion: 2 calls, 1x22, 8 bpc / 8 bpp / bpr 1, bitmapInfo 0x0
  result: equivalent

0x000299e0  exact-six titlebar ArtFile control
  Snow: 6 calls, 14x16, bpr 56, raw bitmapInfo 0x2, effective 0x2
  Lion: 6 calls, 16x16, bpr 64, raw bitmapInfo 0x2, effective 0x2002
  result: known accepted bitmap-info compatibility path

0x0002ad34  new divergent non-button stream
  Snow: 5 calls, all 11x11, 8 bpc / 32 bpp / bpr 44, bitmapInfo 0x2
  Lion: 2 calls:
    256x256, 8 bpc / 32 bpp / bpr 1024, bitmapInfo 0x2
    2x62,     8 bpc / 32 bpp / bpr 8,    bitmapInfo 0x2
  provider: NONNULL on every call
  decode: NULL on every call
  interpolate: YES on every call
  intent: 0 on every call
  result: NONNULL on every call
```

Therefore the first new live frame-image differential is **not** a CoreGraphics constructor failure and is **not** another bitmap-info-only mismatch. The old Snow-PPC CoreUI code reaches the same return site on both systems but is asked to construct a different number and geometry of non-button images.

Do not broaden the accepted `0x2 -> 0x2002` rule to this stream.

## Manual interaction observation

The same run adds a separate functional symptom:

```text
Snow traffic-light buttons: functional
Lion traffic-light buttons: visually sharp but clicks have no effect
Lion titlebar drag: still non-functional
```

This is important, but the current image-constructor trace contains no mouse/hit-test evidence. Do not infer a part-code or hit-mask rewrite from appearance alone. Keep the interaction defect separate unless the `0x0002ad34` caller resolves to a frame/hit asset path that directly connects the two symptoms.

## Objective

Statically resolve the three live Snow-PPC `CGImageCreate` return sites to their containing CoreUI functions, with special focus on `0x0002ad34`.

The analyzer reports:

- containing symbol and bounds;
- exact call instruction immediately preceding each return site;
- verification that the call is `CGImageCreate`;
- focused resource/image references in the containing function;
- direct references to the containing symbol elsewhere in CoreUI;
- the complete containing function body;
- Lion-native same-symbol presence as a release-local reference only.

The purpose is to determine what input source drives the `0x0002ad34` dimensions before any new live interposer or resource experiment is authorized.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py
Git blob 91e40a7e7054bff9e7b6e362532484b7acc3d346
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-image-caller-resolution-v1
```

Pinned CoreUI slices:

```text
Snow Leopard 10.6.8 / 10K549 / ppc7400
5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839

Lion 10.7.5 / 11G63 / i386
5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
```

The historical PPC process on Lion is still governed by the accepted Snow-era PPC CoreUI cache identity. The Lion-native report is reference-only and must not be substituted into the PPC process.

## Safety constraints

- Do not launch the PPC subject.
- Do not rebuild or load a compatibility dylib.
- Retain the accepted exact-six titlebar key translation.
- Retain the accepted exact-six `CGImageCreate bitmapInfo 0x2 -> 0x2002` adapter.
- Do not alter `0x0002ad34` image dimensions, bitmap-info, provider, pixels, or return object.
- Do not add ArtFile mappings or substitute Snow resources.
- Do not force ArtFile200, scale factors, recipes, or frame images.
- Do not change CGContext state.
- Do not change hit masks, classic part codes, mouse routing, or control actions.
- Do not broaden CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py)" = \
  "91e40a7e7054bff9e7b6e362532484b7acc3d346" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-image-caller-resolution-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py","rb").read(),"audit-ppc-carbon-gui-coreui-windowframe-image-callers.py","exec")' || exit 1
```

## Phase B — Snow caller resolution

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py \
  ./ppc-carbon-gui-coreui-windowframe-image-callers-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
coreui_slice_exact=YES
runtime_ppc_coreui_contract=local_snow_ppc_reference
coreui_image_caller_resolution_exact=YES
RESULT: PASS
```

Require all three live sites:

```text
0x0002ad34
0x0001bdb0
0x000299e0
```

to report:

```text
resolved=YES
target_call_is_CGImageCreate=YES
```

Do not launch the PPC subject afterward.

## Phase C — transfer only the Snow text report

Copy:

```text
ppc-carbon-gui-coreui-windowframe-image-callers-snow.txt
```

to the Lion runtime working directory.

No dylib transfer is required.

## Phase D — Lion same-symbol reference

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-image-callers.py \
  ./ppc-carbon-gui-coreui-windowframe-image-callers-lion.txt \
  ./ppc-carbon-gui-coreui-windowframe-image-callers-snow.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
required_arch=i386
coreui_slice_exact=YES
runtime_ppc_coreui_contract=accepted_snow_ppc_cache
native_lion_coreui_role=same-symbol release reference
coreui_image_caller_resolution_exact=YES
RESULT: PASS
```

A Snow-resolved symbol may be absent or refactored in native Lion CoreUI; that is evidence, not a failure, as long as the Snow mapping and Lion image identity pass.

Do not launch the PPC subject afterward.

## Review gate

### `0x0002ad34` resolves to a resource/image-source loader

Identify its exact source boundary: resource name/key, file/path, cache entry, provider creation, or serialized header field.

The next experiment should observe that one source boundary on Snow and Lion. Do not replace the resource and do not rewrite the resulting geometry yet.

### `0x0002ad34` resolves to a generated/cache helper

Identify the scalar or cached input that produces 11x11 on Snow versus 256x256 / 2x62 on Lion. Trace only that input next.

### `0x0002ad34` is not on the document-window frame path

Close it as incidental initialization. The next visual discriminator becomes the Snow-PPC `DrawWindowFrameDark` CGContext fill/composite/backing-context state.

### The caller also feeds frame hit masks or regions

This would connect the new manual interaction failure to the visual defect. In that case, do not patch part codes; first trace the shared source data and the live hit-region output.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-image-callers-snow.txt
ppc-carbon-gui-coreui-windowframe-image-callers-lion.txt
```

No binary or live trace is required.

## Current boundary

```text
all-CoreUI CGImageCreate trace                     PASS
Snow total CoreUI CGImageCreate                   13
Lion total CoreUI CGImageCreate                   10
gray-gradient 0x0001bdb0                          EQUIVALENT: 2 x 1x22
exact-six 0x000299e0                              KNOWN/RETAINED compatibility
new divergent caller 0x0002ad34                   Snow 5x11x11; Lion 256x256 + 2x62
all 0x0002ad34 results                            NONNULL
new bitmapInfo adaptation                         NOT AUTHORIZED
Lion traffic-light clicks                         NON-FUNCTIONAL (manual)
Lion titlebar drag                                NON-FUNCTIONAL (manual)
next step                                         static CoreUI image caller resolution
XNU                                               no source change indicated
```
