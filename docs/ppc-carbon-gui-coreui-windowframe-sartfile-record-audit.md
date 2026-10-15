# PPC Carbon GUI CoreUI window-frame SArtFile frame-record audit

## Status

NEXT CONTROLLED STATIC STEP after the shared-art source audit tied the divergent non-button image path to Snow-PPC `CUISharedArtReader` and exposed the exact legacy image-ID-to-header lookup contract.

## Reviewed shared-art source result

Both returned shared-art source reports pass with exact pinned CoreUI slices and unchanged resource files.

On Snow Leopard, `CUISharedArtReader::CreateImageFromBytes(long,long)` has exactly one direct caller:

```text
CUISharedArtReader::CreateImage(float)
  0x0002af48 -> CUISharedArtReader::CreateImageFromBytes(long,long)
```

The same caller first dispatches through `GetImageType` / `GetEntryCount`; the scale-1 raw-bytes path calls `CreateImageFromBytes`, while another branch uses `CreateImageSource` and ImageIO. This means the next discriminator must identify which of the seven window-frame image IDs are raw shared-art records and what geometry their release-local records contain.

The Snow `GetImageHeader(long)` implementation provides the exact lookup formula:

```text
addi r30,r3,0xb1e0
```

The signed immediate is `-0x4e20`, so:

```text
shared-art index = image ID - 0x4e20
```

It then range-checks that index against the shared-art entry count, loads a 32-bit offset-table entry at `index * 4`, byte-swaps the offset, and adds it to the mapped shared-art base.

The seven legacy frame-image IDs already proven in Snow-PPC `DrawWindowFrameDark` therefore map to:

```text
0x4e89 -> index 105
0x4e8a -> index 106
0x4e8d -> index 109
0x4e8e -> index 110
0x4e8f -> index 111
0x4e90 -> index 112
0x4e91 -> index 113
```

The release-local `SArtFile.bin` headers match this reader contract:

```text
Snow: version 2, entry count 237, size 811436
Lion: version 2, entry count 348, size 9370228
```

The files differ radically in size and SHA-256, while Lion also has an `ArtFile200.bin`. No resource replacement or mapping is authorized from that fact alone.

## Objective

Perform a read-only decode of the seven exact `SArtFile.bin` entries used by the Snow-PPC window-frame renderer, on both Snow Leopard and Lion.

The analyzer:

- verifies the pinned CoreUI slice and exact release-local `SArtFile.bin`;
- parses the little-endian shared-art version/count and offset table;
- maps each legacy frame-image ID through `image_id - 0x4e20`;
- records the release-local header offset and a short header prefix;
- decodes the two `CreateImageFromBytes` constructor slots that the Snow reader can select at scale 1:
  - width;
  - height;
  - provider length;
  - provider data offset;
- emits Snow's `CUISharedArtReader::Setup`, `GetImageHeader`, `GetImageType`, `GetEntryCount`, and `CreateImage` bodies so the record fields can be correlated with the actual branch semantics.

The purpose is to determine which exact frame-image IDs account for Snow's five 11x11 raw-image calls and which release-local Lion records instead produce the observed 256x256 / 2x62 geometry.

This stage is static only.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py
Git blob 35f893dac52ad8e5bfdc5b28504b8e6b63ea685a
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-sartfile-records-v1
```

Pinned CoreUI slices:

```text
Snow Leopard 10.6.8 / 10K549 / ppc7400
5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839

Lion 10.7.5 / 11G63 / i386
5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
```

Pinned `SArtFile.bin` identities:

```text
Snow Leopard
size 811436
62eb745beaafa0a24111c0ac3b3452cebfda4aeec5e56e51b054ae2d62f778b2

Lion
size 9370228
29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b
```

## Safety constraints

- Do not launch the PPC subject.
- Do not rebuild or load a compatibility dylib.
- Do not modify `SArtFile.bin`, `ArtFile.bin`, `ArtFile200.bin`, CoreUI, HIToolbox, or the Rosetta cache.
- Do not copy Snow shared-art records or image bytes to Lion.
- Do not change a shared-art index, record offset, width, height, provider length, provider offset, image type, or entry count.
- Retain the accepted exact-six titlebar key translation and exact-six bitmap-info adapter unchanged.
- Do not change CGContext state, hit masks, classic part codes, mouse routing, or control actions.
- Do not broaden CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py)" = \
  "35f893dac52ad8e5bfdc5b28504b8e6b63ea685a" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-sartfile-records-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py","rb").read(),"audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py","exec")' || exit 1
```

## Phase B — Snow SArtFile frame-record report

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py \
  ./ppc-carbon-gui-coreui-windowframe-sartfile-records-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
coreui_slice_exact=YES
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=237
runtime_ppc_coreui_contract=local_snow_ppc_reference
target_frame_image_count=7
sartfile_frame_record_audit_exact=YES
RESULT: PASS
```

Require all seven image IDs to report `record_valid=YES`:

```text
0x4e8e
0x4e90
0x4e89
0x4e8a
0x4e8d
0x4e8f
0x4e91
```

Do not launch the PPC subject afterward.

## Phase C — Lion SArtFile frame-record report

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py \
  ./ppc-carbon-gui-coreui-windowframe-sartfile-records-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
required_arch=i386
coreui_slice_exact=YES
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=348
runtime_ppc_coreui_contract=accepted_snow_ppc_cache
native_lion_coreui_role=release_reference_only
target_frame_image_count=7
sartfile_frame_record_audit_exact=YES
RESULT: PASS
```

Do not launch the PPC subject afterward.

## Review gate

Review the two reports together.

### Five exact frame IDs decode as 11x11 on Snow and map to the Lion 256x256 / 2x62 records

This would identify the first concrete resource-record mismatch in the missing titlebar/frame background path. The next step should be a passive, ID-gated live trace of `CUISharedArtReader::CreateImage` / `GetImageHeader` inputs and selected slot on Snow and Lion before any record adaptation is considered.

### The seven record geometries differ statically but do not explain the live call counts

Use Snow's emitted `GetImageType` / `GetEntryCount` / `CreateImage` branch contract to identify which records enter the raw-bytes versus ImageIO path, then trace only that selection state.

### The SArtFile records are geometrically equivalent

Close the archive record hypothesis. The next discriminator becomes reader setup/mapped-base/cache state or the held CGContext/backing-state path rather than record rewriting.

### Any record also supplies hit-region data

Do not infer a part-code fix from shared storage alone. First prove the exact live hit-region consumer and output.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-sartfile-records-snow.txt
ppc-carbon-gui-coreui-windowframe-sartfile-records-lion.txt
```

No binary, resource archive, or live trace is required.

## Current boundary

```text
shared-art source audit                          PASS
Snow CreateImageFromBytes direct caller          CUISharedArtReader::CreateImage(float)
Snow shared-art ID bias                          image ID - 0x4e20
target frame-image indices                       105,106,109,110,111,112,113
Snow SArtFile                                    v2 / 237 entries / 811436 bytes
Lion SArtFile                                    v2 / 348 entries / 9370228 bytes
live Snow divergent stream                       5 x 11x11
live Lion divergent stream                       256x256 + 2x62
resource/record rewrite                          NOT AUTHORIZED
next step                                        static SArtFile frame-record audit
XNU                                              no source change indicated
```
