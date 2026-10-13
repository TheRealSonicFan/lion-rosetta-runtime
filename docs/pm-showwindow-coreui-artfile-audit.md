# ShowWindow CoreUI ArtFile contract audit

## Objective

Resolve the newly proven CoreUI code/resource release mismatch before any live compatibility experiment.

The preceding Snow/Lion CoreUI/theme audit establishes that the Rosetta shared cache is byte-for-byte identical on both systems, while the on-disk CoreUI/HIToolbox frameworks and CoreUI theme resources changed substantially between Snow Leopard and Lion. The preserved Lion crash addresses also map exactly to the Snow Leopard PPC CoreUI and HIToolbox symbol offsets, proving that the failing PPC process is executing the Snow-era PPC framework code carried in the Rosetta cache while consuming Lion-era resources from disk.

This stage is read-only. It extracts the exact old/new CoreUI ArtFile code paths and inspects only the relevant resource files. It does not launch the PPC subject and does not copy or replace Apple resources.

## Accepted input evidence

### Rosetta cache is identical on Snow Leopard and Lion

Both static-audit reports record:

```text
dyld_shared_cache_rosetta SHA-256
2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911

dyld_shared_cache_rosetta.map SHA-256
66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9
```

The cache map names both CoreUI and HIToolbox on both systems.

### Snow Leopard has PPC framework slices; Lion does not

Snow Leopard CoreUI:

```text
architectures  x86_64 i386 ppc7400
version        114.0.0
PPC slice SHA  5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839
```

Lion CoreUI:

```text
architectures  x86_64 i386
version        165.11.0
i386 slice SHA 5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
```

Snow Leopard HIToolbox also contains `ppc7400`; Lion HIToolbox contains only `i386,x86_64`.

### Lion crash frames are exactly Snow PPC framework offsets

The Snow PPC CoreUI symbol inventory contains:

```text
ShowArtFilePathToStdErr(unsigned char const*)      0x291e8
CUIElement::LoadFromArtFile(unsigned char const*)  0x29408
CUIElement::Load(_QSIContext*,...)                 0x29c00
CUIRenderer::Draw1Piece(...)                       0x11b6c
CUIRenderer::Draw(...)                             0x174c4
```

Using the preserved Lion crash addresses and the offsets printed by the crash report, every CoreUI frame derives the same image base:

```text
0x924072c4 - 0x291e8 - 220  = 0x923de000
0x92407b38 - 0x29408 - 1840 = 0x923de000
0x92407c84 - 0x29c00 - 132  = 0x923de000
0x923efbc8 - 0x11b6c - 92   = 0x923de000
0x923f6220 - 0x174c4 - 3420 = 0x923de000
```

The same calculation against Snow PPC HIToolbox yields one base for all observed frames:

```text
HIThemeDrawTitleBarWidgetInRect                    -> 0x98a77000
HIWindowButtonView::DrawSelf                       -> 0x98a77000
WindowData::PrepareForVisibility                   -> 0x98a77000
__ShowHideWindows                                  -> 0x98a77000
ShowWindow                                         -> 0x98a77000
```

Therefore the Lion Rosetta process is not executing Lion's on-disk native CoreUI/HIToolbox implementations at the crash point. It is executing the Snow-era PPC implementations represented by the unchanged Rosetta cache.

### CoreUI resource generation changed materially

Snow Leopard resources:

```text
ArtFile.bin   5,946,480 bytes
SArtFile.bin    811,436 bytes
UI.bundle/Contents/Recipes/scrollbars.xml present
CoreUI resource files: 219
```

Lion resources:

```text
ArtFile.bin     4,765,184 bytes
ArtFile200.bin 18,101,720 bytes   new generation
SArtFile.bin    9,370,228 bytes
CoreUI resource files: 6
```

The hashes differ for `ArtFile.bin` and `SArtFile.bin`.

### Native Lion CoreUI changed the ArtFile contract

Snow PPC exposes:

```text
ShowArtFilePathToStdErr(unsigned char const*)
ArtFileSetupOnce()
CUIElement::Load(_QSIContext*, ...)
```

Lion native i386 exposes:

```text
ShowArtFilePathToStdErr(ArtFileInfo*, unsigned char const*)
ArtFileInfo::ArtFile10SetupOnce()
ArtFileInfo::ArtFile20SetupOnce()
ArtFileInfo::GetArtFileInfoForScaleFactor(float)
CUIElement::Load(void*, ...)
```

Lion additionally contains the `ArtFile200` resource name and the new `ArtFile200.bin` archive.

This is now the leading compatibility boundary: Snow-era PPC CoreUI code is being paired with Lion-era CoreUI archive/resource state. It is not yet safe to assume which exact archive or field causes the invalid pointer.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-coreui-artfile.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and performs only static reads.

On Snow Leopard it thins the PPC slices and emits complete function bodies for:

```text
ShowArtFilePathToStdErr(unsigned char const*)
CUIElement::LoadFromArtFile(unsigned char const*)
CUIElement::Load(_QSIContext*, ...)
ArtFileSetupOnce()
CUIElement::CreateQSIImagePath(...)
_CUIUseArtFile
CUIRenderer::Draw1Piece(...)
CUIRenderer::Draw(...)
HIThemeDrawTitleBarWidgetInRect
HIWindowButtonView::DrawSelf
WindowData::PrepareForVisibility
__ShowHideWindows
ShowWindow
```

It also machine-checks the fixed CoreUI and HIToolbox bases derived from the preserved crash.

On Lion it emits the native i386 counterpart bodies for:

```text
ShowArtFilePathToStdErr(ArtFileInfo*, unsigned char const*)
CUIElement::LoadFromArtFile(unsigned char const*)
CUIElement::Load(void*, ...)
ArtFileInfo::ArtFile10SetupOnce()
ArtFileInfo::ArtFile20SetupOnce()
ArtFileInfo::GetArtFileInfoForScaleFactor(float)
CUIElement::CreateQSIImagePath(...)
_CUIUseArtFile
CUIRenderer::Draw1Piece(...)
CUIRenderer::Draw(...)
HIThemeDrawTitleBarWidgetInRect
HIWindowButtonView::DrawSelf
WindowData::PrepareForVisibility
__ShowHideWindows
ShowWindow
```

For these CoreUI resources on each OS:

```text
ArtFile.bin
ArtFile200.bin
SArtFile.bin
UI.bundle/Contents/Recipes/scrollbars.xml
```

the analyzer records:

- existence;
- file size;
- SHA-256;
- `file` classification;
- first and last 256 bytes in hex;
- all byte offsets of the three exact invalid art paths seen on Lion;
- bounded focused printable strings containing `west.`, `colorsrgb`, `scrollbar`, `titlebar`, `ArtFile`, `SArtFile`, Aqua, or theme terms.

The exact Lion diagnostic keys are:

```text
west.clear.colorsrgb.determinate.scrollbars
west.colorsrgb.determinate.minus.scrollbars
west.colorsrgb.determinate.scrollbars
```

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not rebuild or rerun the exact-seven notification broker.
- Do not attach GDB to a live process.
- Do not use DTrace or dtruss.
- Do not copy Snow Leopard CoreUI, HIToolbox, `ArtFile.bin`, `SArtFile.bin`, `Extras.rsrc`, or any theme resource onto Lion.
- Do not replace, rename, symlink, or patch Lion CoreUI resources.
- Do not interpose `fprintf`, `vfprintf`, `ShowArtFilePathToStdErr`, `LoadFromArtFile`, `CFBundleCopyResourceURL`, or renderer routines in this stage.
- Do not modify RawCamera or ImageIO.
- Do not revisit `CGSShapeWindow`.
- Do not alter any already accepted compatibility adapter.
- Do not restart WindowServer, Dock, fontd, distnoted, launchd, or related services.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update runtime on both systems

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

ls -l ./scripts/audit-pm-coreui-artfile.py
ls -l ./docs/pm-showwindow-coreui-artfile-audit.md
```

No XNU build action is required.

## Phase B — Snow Leopard targeted ArtFile audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-coreui-artfile.py \
  ./pm-art-snow.txt
```

Require:

```text
Created: ./pm-art-snow.txt
RESULT: PASS
```

Also require these mapping gates:

```text
== CoreUI Snow-PPC crash address mapping ==
derived_base_exact=YES
derived_base=0x923de000

== HIToolbox Snow-PPC crash address mapping ==
derived_base_exact=YES
derived_base=0x98a77000
```

Do not launch the PPC subject after the audit.

## Phase C — Lion targeted ArtFile audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-coreui-artfile.py \
  ./pm-art-lion.txt
```

Require:

```text
Created: ./pm-art-lion.txt
RESULT: PASS
```

Do not launch the PPC subject after the audit.

## Phase D — return evidence

Return exactly:

```text
pm-art-snow.txt
pm-art-lion.txt
```

Do not return Apple framework binaries, shared caches, ArtFile archives, or resource bundles.

If either report returns `RESULT: FAIL`, return both reports unchanged and stop.

## Review questions

The two reports must answer these questions before any compatibility code is prepared:

1. Which exact resource path(s) does Snow PPC `ArtFileSetupOnce` open?
2. Does Snow PPC `LoadFromArtFile` assume a structure, index width, pointer layout, or path representation that Lion's `ArtFile.bin` / `SArtFile.bin` no longer satisfies?
3. Which archive contains each of the three failing `west...scrollbars` keys on Snow and Lion?
4. Are the failing keys absent on Lion, moved into `ArtFile200.bin`, or present at structurally different offsets?
5. Does native Lion choose between ArtFile10 and ArtFile20 based on scale factor or another descriptor field that old PPC CoreUI cannot represent?
6. Does the old diagnostic helper receive an archive-internal pointer while native Lion's new helper additionally needs `ArtFileInfo*` to interpret or validate that pointer?
7. Does `CreateQSIImagePath` or the immediate `Load` caller show the first release-specific divergence before `LoadFromArtFile`?
8. Can a later compatibility experiment be constrained to a private resource-lookup/path redirection, or is a narrower descriptor/value conversion required?

## Decision gates

### Old PPC loader expects Snow archive generation; Lion keys moved to ArtFile200

Prepare a **private, process-local resource-lookup discriminator first**. It must capture which archive URL/path old PPC CoreUI requests and which resource key causes the first incompatible lookup. Do not substitute Snow archives yet.

### Same keys exist in Lion ArtFile.bin but layout/record interpretation changed

Prepare a narrow loader-input capture around `CUIElement::LoadFromArtFile` sufficient to compare the byte/path/record argument on one Snow control and one Lion run. Do not suppress the failing diagnostic and do not replace the full archive.

### Native Lion introduced a required ArtFileInfo context

If the new `ArtFileInfo*` helper contract explains the path decoding and old PPC code demonstrably lacks that context, design a process-local compatibility layer around the exact resource/path resolution step. Do not redirect all CoreUI calls or all CFBundle resource lookups.

### HIToolbox caller is already equivalent

Keep HIToolbox held. The evidence already maps the Lion crash to the Snow PPC HIToolbox code; do not create a HIToolbox titlebar compatibility shim unless the targeted report finds a differing value before CoreUI entry.

## Current boundary

```text
Rosetta shared cache Snow/Lion                    identical
Rosetta cache map Snow/Lion                       identical
Lion crash CoreUI frames                          exact Snow-PPC offsets
Lion crash HIToolbox frames                       exact Snow-PPC offsets
Snow disk CoreUI                                  PPC v114 present
Lion disk CoreUI                                  native v165.11; no PPC
Snow CoreUI resources                             legacy ArtFile/SArtFile + UI.bundle
Lion CoreUI resources                             changed ArtFile/SArtFile + ArtFile200
ShowArtFilePath helper contract                    changed
exact failing archive/key                         not yet proven
next step                                         targeted ArtFile code/resource audit
PPC subject rerun                                 NO
RawCamera / ShapeWindow                           held
XNU                                                no change indicated
```
