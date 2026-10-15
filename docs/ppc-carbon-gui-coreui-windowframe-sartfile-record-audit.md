# PPC Carbon GUI CoreUI window-frame SArtFile frame-record audit

## Status

COMPLETED CORRECTED STATIC PASS. The v2 Snow and Lion reports pass with the `+0x08` table base proven by Snow-PPC `CUISharedArtReader::Setup()`, and the corrected records now align exactly with the completed live trace. The five healthy Snow-live-active IDs are `0x4e8e`, `0x4e90`, `0x4e8d`, `0x4e8f`, and `0x4e91`; all five are Snow type-2/count-1 raw 11x11 records. On Lion, `0x4e8e` and `0x4e8d` are type-1/count-2 and were observed live as slot-1 256x256 and 2x62 respectively, while the remaining three active IDs are type-3/count-3 and account exactly for the three non-NULL ImageIO calls.

The next controlled step is `docs/ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprint-audit.md`. Do not use the superseded v1 per-image assignments for compatibility design.

## Corrected reader contract

Snow-PPC `CUISharedArtReader::Setup()` contains:

```text
0002ab34  lwz   r11,0x34f0(r30)
0002ab48  addi  r7,r11,0x8
...
0002ab74  stw   r7,0x34f8(r2)
```

Therefore the runtime offset table begins at:

```text
mapped SArtFile base + 0x08
```

`GetImageHeader(long)` still computes:

```text
shared-art index = image ID - 0x4e20
```

and indexes the installed table pointer with `index * 4`.

The v1 analyzer instead used:

```text
file offset 0x04 + index * 4
```

which is one 32-bit table entry early. Its decoded record labeled index `N` was therefore the record the runtime reaches at index `N-1`.

## Live evidence that verifies the correction

The completed Snow control recovered five exact raw IDs, all 11x11:

```text
0x4e8e
0x4e90
0x4e8d
0x4e8f
0x4e91
```

The completed Lion run recovered:

```text
0x4e8e -> 256x256
0x4e8d -> 2x62
```

Applying the corrected `+0x08` table base to the already returned v1 Lion report shifts each lookup to the next v1 table entry:

```text
runtime 0x4e8e / index 110 -> v1-decoded index 111 -> 256x256 slot
runtime 0x4e8d / index 109 -> v1-decoded index 110 -> 2x62 slot
```

Both live geometries therefore agree exactly with the corrected table base. This is a correction to the static analyzer, not a new compatibility rule.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py
Git blob b6414a4da9906d5250b6445a40d22f90281bc2d5
```

Contract:

```text
analyzer_version=2
audit_contract=carbon-gui-coreui-windowframe-sartfile-records-v2
sartfile_offset_table_base=0x08
```

On Snow, v2 also requires the static `Setup()` evidence for mapped-base `+0x08` before reporting PASS.

Pinned CoreUI and SArtFile identities are unchanged.

## Safety constraints

- Static only: do not launch the PPC subject.
- Do not rebuild or load a compatibility dylib for this correction.
- Do not modify SArtFile.bin, ArtFile.bin, ArtFile200.bin, CoreUI, HIToolbox, or the Rosetta cache.
- Do not copy Snow records or image bytes to Lion.
- Retain the exact-six titlebar semantic-key translation and exact-six bitmap-info adapter unchanged.
- Do not change CGContext state, hit masks, classic part codes, mouse routing, CGS compatibility, or XNU.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py)" = \
  "b6414a4da9906d5250b6445a40d22f90281bc2d5" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "2"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-sartfile-records-v2"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py","rb").read(),"audit-sartfile-records-v2.py","exec")' || exit 1
```

## Phase B — corrected Snow report

On Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py \
  ./ppc-carbon-gui-coreui-windowframe-sartfile-records-v2-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
coreui_slice_exact=YES
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=237
sartfile_offset_table_base=0x08
snow_setup_offset_table_base_verified=YES
target_frame_image_count=7
sartfile_frame_record_audit_exact=YES
RESULT: PASS
```

## Phase C — corrected Lion report

On Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-records.py \
  ./ppc-carbon-gui-coreui-windowframe-sartfile-records-v2-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
coreui_slice_exact=YES
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=348
sartfile_offset_table_base=0x08
snow_setup_offset_table_base_verified=accepted_snow_ppc_contract
target_frame_image_count=7
sartfile_frame_record_audit_exact=YES
RESULT: PASS
```

## Phase D — re-summarize the already captured live logs

Do not rerun the PPC subject.

The v1 live artifact itself ran successfully; only the summary's treatment of the final ImageIO call-site saved-r30 field was wrong. Current `main` provides:

```text
scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py
Git blob eaa0b391a858c9cfb4121dd9e1cbaac85a710cb6
analyzer_version=2
audit_contract=carbon-gui-coreui-windowframe-shared-art-selection-live-v2
```

Re-run the summarizer against the existing logs:

```sh
/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py \
  ./payload/lion-ppc-carbon-gui-shared-art-selection.log \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-selection-lion-v2.txt || exit 1
```

On Snow, the existing v1 summary already passed, but the same v2 summarizer may be used against the preserved Snow subject log to produce:

```text
ppc-carbon-gui-coreui-windowframe-shared-art-selection-snow-v2.txt
```

The v2 summarizer validates exact IDs only for the raw `CreateImageFromBytes` calls. At `0x0002afe8`, `CreateImage(long,float)` has already reused `r30`; the old `frame_id=0` ImageIO field is therefore not an image-ID measurement and is retained only as saved-register/count/result evidence.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-sartfile-records-v2-snow.txt
ppc-carbon-gui-coreui-windowframe-sartfile-records-v2-lion.txt
ppc-carbon-gui-coreui-windowframe-shared-art-selection-lion-v2.txt
```

If convenient, also return the Snow v2 live summary, but do not rerun the PPC subject merely to create it.

## Observed v2 result

Both corrected static reports pass. Snow proves the table base at `+0x08` and shows all seven corrected target records as 11x11 slot-0 type-2/count-1 records; the live control identifies the active five as `0x4e8e`, `0x4e90`, `0x4e8d`, `0x4e8f`, and `0x4e91`. Lion's corrected records resolve `0x4e8e` slot 1 to 256x256 and `0x4e8d` slot 1 to 2x62, exactly matching the two live raw calls. The other three Snow-active IDs are Lion type-3/count-3 records, and the Lion live trace contains exactly three non-NULL ImageIO calls, so the branch partition is now fully correlated without another PPC run.

The remaining question is whether the five Snow 11x11 provider payloads survive elsewhere in Lion's SArtFile. Follow `docs/ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprint-audit.md` next.

## Current boundary

```text
corrected SArtFile v2 audit                      PASS
Snow Setup offset-table base                     +0x08 / PROVEN
Snow live-active raw IDs                         4e8e,4e90,4e8d,4e8f,4e91
Lion raw slot-1 IDs                              4e8e=256x256;4e8d=2x62
Lion ImageIO active remainder                    4e90,4e8f,4e91
live/static branch correlation                   COMPLETE
legacy 11x11 payload survival in Lion SArtFile   UNKNOWN
resource/record rewrite                          NOT AUTHORIZED
next step                                        static payload fingerprint audit
XNU                                              no source change indicated
```
