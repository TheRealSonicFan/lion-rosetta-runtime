# PPC Carbon GUI CoreUI window-frame shared-art source audit

## Status

COMPLETED STATIC PASS. Snow resolves the unique raw-bytes caller to `CUISharedArtReader::CreateImage(long,float)`, and `GetImageHeader(long)` proves the legacy lookup is an image-ID-biased offset-table lookup (`image ID - 0x4e20`). The release-local `SArtFile.bin` headers match that shared-reader contract but differ materially between Snow and Lion. The next controlled step is `docs/ppc-carbon-gui-coreui-windowframe-sartfile-record-audit.md`.

## Reviewed caller-resolution result

Both returned caller-resolution reports pass against the pinned CoreUI slices.

The divergent live return site resolves on Snow Leopard to:

```text
live_return_offset=0x0002ad34
resolved=YES
resolved_symbol=__ZN18CUISharedArtReader20CreateImageFromBytesEll
target_call_is_CGImageCreate=YES
direct_symbol_reference_count=1
```

The one direct reference is:

```text
0002af48  bl  __ZN18CUISharedArtReader20CreateImageFromBytesEll
```

The constructor calls `CUISharedArtReader::GetImageHeader(long)` first. It then reads and byte-swaps serialized fields before constructing the provider/image:

```text
header + 0x0c  -> width
header + 0x0e  -> height
header + 0x10  -> provider length
header + 0x14  -> provider data offset
```

The resulting width is also used to derive `bytesPerRow = width * 4`. This places the 11x11 versus 256x256 / 2x62 difference above CoreGraphics, at the shared-art reader/header source.

The two controls resolve independently:

```text
0x0001bdb0 -> CUIRenderer::CreateGrayCubicGradientImage(int,int,int)
0x000299e0 -> CUIElement::LoadFromArtFile(unsigned char const*)
```

Lion native CoreUI contains the `LoadFromArtFile` control symbol but does not contain the same `CUISharedArtReader::CreateImageFromBytes` or gray-gradient symbol names. This is release-refactor evidence only: the translated PPC process on Lion still executes the accepted Snow-era PPC CoreUI image.

The earlier renderer audit also established that Snow-PPC `DrawWindowFrameDark` directly requests seven legacy frame images (`0x4e8e`, `0x4e90`, `0x4e89`, `0x4e8a`, `0x4e8d`, `0x4e8f`, `0x4e91`). The present audit must determine how that path reaches the shared-art reader before any live compatibility experiment is added.

## Objective

Identify the exact static source boundary behind `CUISharedArtReader::GetImageHeader` and the unique `CreateImageFromBytes` caller.

The analyzer reports:

- the complete Snow/Lion inventory of `CUISharedArtReader` text symbols;
- the unique direct caller(s) of `CreateImageFromBytes` and their containing function bodies;
- the complete `GetImageHeader` body and its direct references;
- the complete `CreateImageFromBytes` body;
- CoreUI strings that mention ArtFile/shared-art resource names;
- size, SHA-256, and a short header prefix for `ArtFile.bin`, `ArtFile200.bin`, and `SArtFile.bin`;
- the exact pinned CoreUI slice identity.

The goal is to determine whether the divergent header comes from `SArtFile.bin`, another CoreUI archive, or an intermediate reader table/cache, and to expose the exact index/header boundary that must be compared next.

This stage is static only.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py
Git blob 819be82d8491995c5bb0232afb8432dfb78dbaee
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-shared-art-source-v1
```

Pinned CoreUI slices:

```text
Snow Leopard 10.6.8 / 10K549 / ppc7400
5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839

Lion 10.7.5 / 11G63 / i386
5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
```

## Safety constraints

- Do not launch the PPC subject.
- Do not rebuild or load a compatibility dylib.
- Retain the accepted exact-six titlebar key translation.
- Retain the exact-six `CGImageCreate bitmapInfo 0x2 -> 0x2002` adapter.
- Do not alter shared-art indices, image dimensions, provider bytes, pixels, bitmap-info, or return objects.
- Do not replace `ArtFile.bin`, `ArtFile200.bin`, `SArtFile.bin`, CoreUI, HIToolbox, or Rosetta cache files.
- Do not add an ArtFile/shared-art mapping.
- Do not change CGContext state, hit masks, classic part codes, mouse routing, or control actions.
- Do not broaden CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py)" = \
  "819be82d8491995c5bb0232afb8432dfb78dbaee" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-shared-art-source-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py","rb").read(),"audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py","exec")' || exit 1
```

## Phase B — Snow shared-art source report

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-source-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
coreui_slice_exact=YES
runtime_ppc_coreui_contract=local_snow_ppc_reference
create_from_bytes_present=YES
get_image_header_present=YES
shared_art_source_audit_exact=YES
RESULT: PASS
```

The report should resolve the `0x0002af48` direct reference to its containing function and expose the complete `GetImageHeader` implementation plus the reader symbol inventory.

Do not launch the PPC subject afterward.

## Phase C — Lion release/resource report

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-shared-art-source.py \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-source-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
required_arch=i386
coreui_slice_exact=YES
runtime_ppc_coreui_contract=accepted_snow_ppc_cache
native_lion_coreui_role=release_reference_only
shared_art_source_audit_exact=YES
RESULT: PASS
```

Absence of the Snow-named reader methods in Lion native CoreUI is not a failure. The Lion report is used to compare release-local CoreUI resource identities and refactoring only; it must not be substituted into the PPC process.

Do not launch the PPC subject afterward.

## Review gate

Review the two reports together.

### Reader resolves directly to one CoreUI archive and index/header table

Use that exact archive/index/header boundary for the next discriminator. Prefer a static record comparison first if the relevant entry can be decoded unambiguously. If a live discriminator is still required, trace only the reader/index/header values and preserve the returned bytes and geometry unchanged.

### Reader uses an intermediate table/cache populated from a release-specific archive

Resolve the population path and compare the table entry that supplies the width/height/length/data-offset fields. Do not patch the cache or replace the archive.

### The unique caller proves direct membership in the seven-image `DrawWindowFrameDark` path

Correlate the shared-art index values with the seven legacy frame-image IDs and identify which five calls correspond to Snow's 11x11 stream and which calls survive on Lion. This would establish the first frame-image source mismatch without altering rendering.

### The unique caller is unrelated to the document-window frame path

Close `0x0002ad34` as incidental and return to the held `DrawWindowFrameDark` CGContext fill/composite/backing-context discriminator.

### Reader/header source also feeds hit regions

Keep the interaction defect separate until the shared data is proven to feed both rendering and hit output. Do not patch classic part codes from this static evidence alone.

## Observed result

Both reports pass with exact pinned CoreUI slices and untouched resources.

Snow's unique `CreateImageFromBytes` reference is inside `CUISharedArtReader::CreateImage(long,float)`. That caller first uses `GetImageType` / `GetEntryCount`; its raw-bytes branches call `CreateImageFromBytes`, while another branch goes through `CreateImageSource` and `CGImageSourceCreateImageAtIndex`.

`GetImageHeader(long)` exposes the legacy image-ID translation directly: `addi r30,r3,0xb1e0` is a signed subtraction of `0x4e20`. It range-checks the resulting index against the shared-art count, reads a 32-bit offset-table entry at `index * 4`, byte-swaps it, and adds it to the mapped base. The seven known frame IDs therefore map to indices 105, 106, and 109-113.

The resource prefixes are consistent with that table contract: Snow `SArtFile.bin` begins with version 2 / count 237 and Lion with version 2 / count 348. The exact files also differ sharply in size and SHA-256 (Snow 811436 bytes; Lion 9370228 bytes). Native Lion's shared-reader symbols are refactored, but that remains release-reference evidence only because the translated PPC process still executes Snow-era CoreUI.

This is now specific enough for a static record comparison. Follow `docs/ppc-carbon-gui-coreui-windowframe-sartfile-record-audit.md`; do not launch the PPC subject or rewrite any record, image geometry, resource, hit data, CGS rule, or XNU state yet.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-shared-art-source-snow.txt
ppc-carbon-gui-coreui-windowframe-shared-art-source-lion.txt
```

No binary, resource archive, or live trace is required.

## Current boundary

```text
caller-resolution audit                         PASS
0x0002ad34 Snow symbol                          CUISharedArtReader::CreateImageFromBytes
CreateImageFromBytes -> GetImageHeader           YES
serialized width field                           header+0x0c
serialized height field                          header+0x0e
serialized provider length field                 header+0x10
serialized provider data offset field            header+0x14
Snow divergent stream                            5 x 11x11
Lion divergent stream                            256x256 + 2x62
CoreGraphics construction                        NONNULL / not the failure
Lion native same reader symbol                   ABSENT / release refactor
resource/header rewrite                          NOT AUTHORIZED
next step                                        static SArtFile frame-record audit
XNU                                              no source change indicated
```
