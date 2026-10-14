# PPC Carbon GUI Snow-PPC ArtFile loader field-contract audit

## Status

COMPLETED STATIC PASS. Both releases satisfy the Snow-PPC one-cell record contract; the remaining differences are confined to directly consumed render metrics and release-local image geometry. The next controlled step is `docs/ppc-carbon-gui-artfile-render-state-audit.md`.

## Reviewed result that advances this step

The returned trace artifact matches the prepared source/build contract:

```text
interposer_source_git_blob=32e6413d78ba3da7d327c35e199c46af1cc00b78
compat_build_id=coreui-artfile-bsearch-exact-six-allkeys-trace-v1
artifact_sha256=bf83cba94fce60955f791341dfab6865f8bdc7e22f08ce11f674fd0d5eb690aa
```

Snow Leopard passes with:

```text
artfile_trace_unique_count=6
artfile_trace_outside_six_unique_count=0
artfile_trace_miss_unique_count=0
artfile_trace_limit_count=0
RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion passes with:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
artfile_trace_unique_count=6
artfile_trace_known_six_count=6
artfile_trace_outside_six_unique_count=0
artfile_trace_miss_unique_count=0
artfile_trace_limit_count=0
RESULT: PPC_CARBON_GUI_ARTFILE_BSEARCH_ALLKEYS_TRACE_PASS
RESULT: PASS
```

The six Snow raw keys are exactly the previously accepted titlebar-control keys. On Lion those same raw bytes decode to unrelated Lion-local component names, but the exact-six adapter replaces each with the unique semantic-equivalent Lion key and every effective lookup returns HIT. No seventh ArtFile lookup occurs on either release.

The WindowServer observers still reach the exact 400x222 titled window. Manual review remains unchanged: Snow is visually normal; Lion remains only partially correct.

This closes the hypothesis that the transparent titlebar background or distorted controls are caused by an additional non-`titlebarcontrols` lookup passing through this old PPC `LoadFromArtFile -> bsearch` boundary. It does **not** prove that no other CoreUI/resource mechanism participates in frame drawing.

The next step is the field-level proof already required by the prior rendering-contract audit: decode Lion's exact-six ArtFile10 records using the **actual Snow-PPC `CUIElement::LoadFromArtFile` field-access contract** before considering any record-field adapter.

## Objective

Prove exactly which bytes of the `0x68` serialized ArtFile record header are consumed by the Snow-era PPC loader and verify whether the Lion exact-six records are structurally valid under that old contract.

The audit distinguishes:

1. the fixed halfword values directly loaded from offsets `0x00..0x1c`;
2. the `0x1e` halfword, which is copied but is not a direct fixed halfword load in the pinned Snow function;
3. the per-cell image data offset array beginning at `0x20`;
4. the per-cell image width array beginning at `0x44`;
5. the per-cell image height array beginning at `0x56`;
6. the exact payload span consumed by the one-cell titlebar records.

For the current exact-six records the expected cell count is 1x1. The decisive structural equation is therefore:

```text
record_span == cell_data_offset + cell_width * cell_height * 4
```

with `cell_data_offset == 0x68`.

This stage is static and read-only. It does not launch the PPC subject.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py
Git blob 46e2e1e87141db3ac4718d64557be520ec2d92e7
```

Analyzer contract:

```text
analyzer_version=1
audit_contract=carbon-gui-artfile-snow-loader-field-contract-v1
```

On Snow Leopard the analyzer verifies the accepted PPC CoreUI identities and exact `LoadFromArtFile` instruction contract, including:

```text
LoadFromArtFile address                0x29408
serialized header copy length          0x68
serialized header stack base           r1+0x118
direct fixed halfword reads            0x00,0x02,...,0x1c
direct fixed halfword read at 0x1e     none
cell data-offset array base             0x20
cell width array base                   0x44
cell height array base                  0x56
```

On Lion the analyzer verifies the accepted Rosetta shared-cache/cache-map identities and applies that already-proven Snow PPC loader contract to the accepted Lion ArtFile10 records.

For each exact-six record it reports:

```text
count0
count1
cell_count
metric_s16_0x04_to_0x1c
raw_u16_0x1e
cell0_body_offset
cell0_width
cell0_height
cell0_body_bytes
cell0_end
old_loader_1x1_record_exact
```

The names of the signed metric fields are intentionally not guessed. This audit proves byte consumption and structural validity first.

## Safety constraints

- Do not launch the PPC Carbon subject.
- Do not rerun the all-ArtFile trace.
- Do not build or replace any compatibility dylib.
- Do not add or change any titlebar mapping.
- Do not patch any `0x68` header field.
- Do not substitute Snow payload bytes or `titlebarcontrols.xml`.
- Do not force ArtFile200 or a scale factor.
- Do not interpose `LoadFromArtFile`, `memcpy`, renderer routines, image providers, or CoreGraphics drawing.
- Do not change ShapeWindow, backing synchronization, WindowBackingInfo, color-profile, notification, CPS, or later CGS compatibility.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py)" = \
  "46e2e1e87141db3ac4718d64557be520ec2d92e7" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-artfile-snow-loader-field-contract-v1"$' \
  ./scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py","rb").read(),"audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py","exec")' || exit 1
```

Do not proceed if Phase A fails.

## Phase B — Snow loader/record report

On Snow Leopard 10.6.8 / 10K549:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py \
  ./ppc-carbon-gui-artfile-snow-loader-fields-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
rosetta_cache_expected=YES
rosetta_cache_map_expected=YES
snow_loader_instruction_contract=PASS
header_copy_length=0x68
direct_halfword_0x1e_observed=NO
cell_data_offset_array_base=0x20
cell_width_array_base=0x44
cell_height_array_base=0x56
exact_six_old_loader_record_count=6
exact_six_old_loader_cell_contract_count=6
old_loader_field_contract_exact=YES
RESULT: PASS
```

For every exact-six path require:

```text
count0=1
count1=1
cell_count=1
cell0_body_offset=0x68
old_loader_1x1_record_exact=YES
```

Do not launch the PPC subject after producing the report.

## Phase C — Lion record-under-Snow-loader report

On Lion 10.7.5 / 11G63:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-artfile-snow-loader-field-contract.py \
  ./ppc-carbon-gui-artfile-snow-loader-fields-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
rosetta_cache_expected=YES
rosetta_cache_map_expected=YES
runtime_ppc_loader_source=dyld_shared_cache_rosetta
runtime_ppc_loader_contract=accepted_identical_snow_ppc_cache
header_copy_length=0x68
cell_data_offset_array_base=0x20
cell_width_array_base=0x44
cell_height_array_base=0x56
exact_six_old_loader_record_count=6
exact_six_old_loader_cell_contract_count=6
old_loader_field_contract_exact=YES
RESULT: PASS
```

For every exact-six path require:

```text
count0=1
count1=1
cell_count=1
cell0_body_offset=0x68
old_loader_1x1_record_exact=YES
```

Do not launch the PPC subject after producing the report.

## Review gate

Review the Snow and Lion reports together.

### Both reports pass and all Lion one-cell spans close exactly

This proves that the old PPC loader can structurally locate and size the Lion image body. Do not patch the data offset, width, height, or the unconsumed `0x1e` halfword.

Compare only `metric_s16_0x04_to_0x1c` across the six Snow/Lion semantic pairs. If the release delta is confined to these directly consumed renderer metrics, the next controlled discriminator should capture the downstream element/render-state values generated from those metrics before authorizing any field rewrite.

### Lion cell contract fails

Stop. Isolate the first exact field/array offset that makes the old-loader calculation invalid. Prepare a field-specific proof; do not rewrite the whole header or payload.

### Snow loader instruction contract fails

Stop. Treat the analyzer as stale and do not infer field semantics from the hard-coded map.

## Observed result — record structure passes; metric and image-format discrimination remains

Both returned reports pass.

Snow's exact-six records are all 1x1 cells with `body_offset=0x68`, `14x16` image geometry, 896 image bytes, and a 1000-byte exact record span. All six share the directly consumed metric vector:

```text
0,2,14,14, 0,2,14,14, 0,2,14,14, 2
```

Lion's semantic-equivalent exact-six records are likewise valid under the same cached Snow-PPC loader contract: `body_offset=0x68`, `16x16` image geometry, 1024 image bytes, and a 1128-byte exact record span. All six share:

```text
2,2,13,14, 1,2,14,14, 1,2,14,14, 2
```

The `0x1e` halfword differs (`0xbfff` on Snow, `0x0000` on Lion) but the pinned Snow loader does not directly consume it, so it is not an authorized compatibility target. The data-offset, width, and height arrays all decode exactly and must not be patched.

The next discriminator is not a metric rewrite. The release-local CoreUI disassembly shows that the thirteen metric values land in the same three four-float regions plus one scalar in `CUIElement`, while the image-construction contracts differ: Snow PPC can reach `CGImageCreate` with default-byte-order bitmap-info values `0x2` or `0x4` and has a conditional `CWMatchBitmap` path; Lion native CoreUI uses `0x2002`, explicitly selecting 32-bit little-endian alpha-first interpretation.

Follow `docs/ppc-carbon-gui-artfile-render-state-audit.md` next. It statically verifies those consumer mappings and compares the raw exact-six image bodies under byte-0 versus byte-3 alpha diagnostics. Do not change any metric or pixel byte until those reports are reviewed.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-artfile-snow-loader-fields-snow.txt
ppc-carbon-gui-artfile-snow-loader-fields-lion.txt
```

No binaries are required.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
all validated ArtFile live keys                  exact six only on both releases
outside-six ArtFile live lookups                 0
ArtFile live misses                              0
titlebar exact-six translations                  6 / guard rejects 0
Lion titlebar                                    PARTIAL / unchanged
non-titlebarcontrols bsearch-key hypothesis      CLOSED for current subject
old Snow-PPC loader header consumption           STATIC-PROVEN PASS
Snow exact-six metrics                           0,2,14,14 / 0,2,14,14 / 0,2,14,14 / 2
Lion exact-six metrics                           2,2,13,14 / 1,2,14,14 / 1,2,14,14 / 2
data-offset/width/height arrays                   COMPATIBLE
field 0x1e                                       NOT DIRECTLY CONSUMED
next step                                        docs/ppc-carbon-gui-artfile-render-state-audit.md
new mappings                                     NOT AUTHORIZED
metric/header/payload substitution               NOT AUTHORIZED
ArtFile200 forcing                               NOT AUTHORIZED
XNU                                              no source change indicated
```
