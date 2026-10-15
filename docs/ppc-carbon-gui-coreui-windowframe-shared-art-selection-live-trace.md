# PPC Carbon GUI CoreUI window-frame shared-art selection live trace

## Status

COMPLETED LIVE RUN; SUMMARY CORRECTION ONLY. The Snow and Lion compatibility runners both passed, the Snow raw-ID control is internally consistent, and Lion produced the expected two divergent raw geometries with non-NULL results. The original v1 summary failed only because it treated the final ImageIO call site's saved-r30 value as an image ID even though `CUISharedArtReader::CreateImage(long,float)` has already reused `r30` by that point.

The same live run also exposed a separate static-audit bug: the v1 SArtFile analyzer used offset-table base `0x04`, while Snow-PPC `CUISharedArtReader::Setup()` installs the table pointer at mapped-base `+0x08`.

Do not rerun the PPC subject for either correction.

## Live result that remains valid

Snow v1 summary passed:

```text
raw_call_count=5
0x4e8e 11x11
0x4e90 11x11
0x4e8d 11x11
0x4e8f 11x11
0x4e91 11x11
imageio_call_count=0
RESULT: PASS
```

Lion's underlying compatibility runner also passed with all accepted gates intact. The live trace recorded:

```text
raw 0x4e8e -> 256x256 / bpr1024 / NONNULL
raw 0x4e8d -> 2x62 / bpr8 / NONNULL
ImageIO call count -> 3
ImageIO results -> 3 NONNULL
exact-six bitmapInfo adaptations -> 6
```

The raw-ID recovery remains valid because the `CGImageCreate` wrapper reads the `CreateImageFromBytes` frame's saved `r30`, which is the caller's live legacy image ID. The healthy Snow control proves that mechanism against five known 11x11 IDs.

## Why the ImageIO IDs are not valid measurements

The Snow-PPC `CreateImage(long,float)` body executes:

```text
0002af70  bl    CUISharedArtReader::CreateImageSource(long)
0002af74  or.   r27,r3,r3
...
0002af80  li    r30,0
...
0002afe4  bl    CGImageSourceCreateImageAtIndex
```

Therefore the saved-r30 field recovered at the final `CGImageSourceCreateImageAtIndex` boundary is not the legacy image ID. The three Lion `frame_id=0x0000` lines are expected from that call-site state and must not invalidate the run.

Current runtime `main` provides the corrected summarizer:

```text
scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py
Git blob eaa0b391a858c9cfb4121dd9e1cbaac85a710cb6
analyzer_version=2
audit_contract=carbon-gui-coreui-windowframe-shared-art-selection-live-v2
```

It validates exact-seven IDs only for raw `CreateImageFromBytes` calls and treats the ImageIO branch as count/index/result evidence.

## Static SArtFile correction exposed by the live IDs

Snow-PPC `CUISharedArtReader::Setup()` contains:

```text
addi r7,r11,0x8
...
stw  r7,0x34f8(r2)
```

so the offset table begins at mapped-base `+0x08`, not file offset `0x04`.

That one-entry correction explains the live Lion IDs exactly:

```text
runtime 0x4e8e / index 110 -> corrected entry at old-v1 index 111 -> 256x256
runtime 0x4e8d / index 109 -> corrected entry at old-v1 index 110 -> 2x62
```

The raw trace therefore validates the corrected table interpretation rather than contradicting it.

## Next step

Follow `docs/ppc-carbon-gui-coreui-windowframe-sartfile-record-audit.md`.

Run only the corrected static v2 SArtFile analyzer on Snow and Lion, then re-run the v2 summarizer against the already preserved Lion subject log. Do not rebuild or rerun the live diagnostic artifact.

Return:

```text
ppc-carbon-gui-coreui-windowframe-sartfile-records-v2-snow.txt
ppc-carbon-gui-coreui-windowframe-sartfile-records-v2-lion.txt
ppc-carbon-gui-coreui-windowframe-shared-art-selection-lion-v2.txt
```

## Safety constraints

- Retain every accepted compatibility rule unchanged.
- Do not rerun the PPC subject for this correction.
- Do not modify SArtFile/ArtFile/CoreUI/HIToolbox/Rosetta cache.
- Do not alter image IDs, types, counts, slots, geometry, providers, pixels, bitmapInfo policy, CGContext state, hit masks, part codes, mouse routing, or CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Current boundary

```text
Snow compatibility/live raw-ID control           PASS
Lion compatibility runner                        PASS
Lion raw IDs                                     0x4e8e=256x256; 0x4e8d=2x62
Lion ImageIO                                     3 calls / 3 NONNULL
v1 ImageIO frame-ID interpretation               INVALID / superseded
v1 SArtFile table base                           0x04 / WRONG / superseded
Snow Setup table base                            +0x08 / PROVEN
next step                                        corrected static SArtFile v2 audit
PPC rerun                                        NOT REQUIRED
XNU                                              no source change indicated
```
