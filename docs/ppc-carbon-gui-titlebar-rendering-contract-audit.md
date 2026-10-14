# PPC Carbon GUI titlebar rendering/scale contract audit

## Status

COMPLETED STATIC PASS. The exact-six ArtFile metadata is release-specific, but the current reports do not justify payload/header substitution or ArtFile200 forcing. The next controlled discriminator is `docs/ppc-carbon-gui-artfile-live-key-trace.md`.

## Reviewed result that advances this step

The exact-six passive trace artifact is valid and matches the pinned source/build identity. The Snow control and the Lion run both pass.

Snow Leopard 10.6.8 / 10K549:

```text
titlebar_trace_count=6
titlebar_trace_outside_six_count=0
titlebar_trace_limit_count=0
titlebar_trace_disabled_clear_count=1
titlebar_trace_disabled_minus_count=1
titlebar_trace_disabled_zoom_count=1
titlebar_trace_active_clear_count=1
titlebar_trace_active_minus_count=1
titlebar_trace_active_zoom_count=1
RESULT: PPC_CARBON_GUI_TITLEBAR_BSEARCH_TRACE_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion 10.7.5 / 11G63:

```text
titlebar_translated_count=6
titlebar_guard_reject_count=0
titlebar_trace_count=6
titlebar_trace_known_six_count=6
titlebar_trace_outside_six_count=0
titlebar_trace_limit_count=0
RESULT: PPC_CARBON_GUI_TITLEBAR_BSEARCH_TRACE_PASS
RESULT: PASS
```

The two live key sequences are identical: disabled close/minimize/zoom followed by active close/minimize/zoom. Snow passes those six raw keys through; Lion translates exactly those six and no other `titlebarcontrols` lookup occurs.

The manual visual result is unchanged: Snow is normal; Lion remains only partially correct, with the same transparent/background-colored titlebar and distinct but distorted traffic-light controls.

This closes the additional-titlebar-key hypothesis for the exact historical subject. The 191 outside-six semantic-equivalent archive entries found by the previous static inventory are not exercised in this run and must not be added to live policy.

## Why the next step moves to rendering/scale

The remaining mismatch is now above key selection:

- the historical subject requests exactly the same six titlebar-control semantics on Snow and Lion;
- Lion translates all six to unique release-local semantic equivalents;
- there are zero guard rejects and zero outside-six live lookups;
- the exact-six Lion records are present;
- the prior payload audit established a common fixed `0x68` record-header boundary and 32-bit image body, but it also showed release-specific record contents and geometry;
- the Rosetta process is known to execute Snow-era PPC CoreUI code while consuming Lion-era CoreUI resources;
- Lion native CoreUI adds separate ArtFile10/ArtFile20 setup and `GetArtFileInfoForScaleFactor(float)`, while Snow PPC CoreUI has one legacy `ArtFileSetupOnce()`;
- Snow carries the old UI recipe tree, while Lion does not.

The next question is therefore not "which key is missing?" but "does the Snow-era PPC renderer interpret the Lion-era titlebar record/scale/recipe contract the same way Lion's native renderer does?"

## Objective

Perform a read-only Snow-versus-Lion differential of the exact-six titlebar rendering contract.

The audit records:

1. the exact six release-local records from `ArtFile.bin` (ArtFile10) on both releases;
2. the exact six corresponding records from Lion `ArtFile200.bin` (ArtFile20);
3. the complete fixed `0x68` header of every record in raw bytes, 16-bit words, and 32-bit words;
4. the payload span and first image-body bytes for each exact-six record;
5. the local CoreUI consumer/renderer disassembly needed to interpret those records;
6. Snow's legacy `ArtFileSetupOnce()` versus Lion's ArtFile10/ArtFile20 setup and scale-selection code;
7. the presence or absence of the CoreUI recipe tree and any recipe filenames containing `title` or `window`.

This stage is static only. It does not launch the PPC subject and does not alter the already accepted live stack.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-titlebar-rendering-contract.py
```

Pinned identity:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-rendering-contract-v1
git_blob=d7c0c39dbeec87ae95e49631914c4f93fd97feee
source_sha256=4e144605459536290c4a420a5e4c5e4578f667ae9945a7c288a3db92849f203c
```

The analyzer is Python-2-compatible and read-only.

It pins the already accepted local resource identities:

Snow Leopard:

```text
CoreUI ppc7400 SHA-256
5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839

ArtFile.bin SHA-256
1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5

ArtFile200.bin
MISSING
```

Lion:

```text
CoreUI i386 SHA-256
5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b

ArtFile.bin SHA-256
0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4

ArtFile200.bin SHA-256
463bdec2bb3a3f66d35bc85e80129b8e0ea85e474e8725b093d747ffa687614f
```

The disassembly set includes, where release-local symbols exist:

```text
CUIElement::LoadFromArtFile
CUIElement::Load
CUIRenderer::Draw1Piece
CUIRenderer::DrawWindowTitleBar
CUIRenderer::DrawWindowFrameDark
CUIRenderer::DrawTitlebarButton              [Lion]
CUIRenderer::CopyWindowTitlebarImage         [Lion]
_CUIUseArtFile
ArtFileSetupOnce                             [Snow]
ArtFileInfo::ArtFile10SetupOnce              [Lion]
ArtFileInfo::ArtFile20SetupOnce              [Lion]
ArtFileInfo::GetArtFileInfoForScaleFactor    [Lion]
CUIElement::ArtFileScaleFactorAvailable      [Lion]
```

## Safety constraints

- Do not rerun the PPC Carbon subject in this stage.
- Do not rebuild or replace any compatibility dylib.
- Do not broaden the exact-six bsearch translation.
- Do not add a seventh titlebar key.
- Do not copy Snow CoreUI, ArtFile, ArtFile200, SArtFile, recipe, or titlebar payload bytes to Lion.
- Do not patch Lion CoreUI or any resource.
- Do not interpose `LoadFromArtFile`, `memcpy`, image-provider calls, renderer routines, scale-selection routines, CoreGraphics drawing, or bitmap conversion.
- Do not change ShapeWindow, backing synchronization, WindowBackingInfo, color-profile, notification, CPS, or later CGS compatibility.
- Do not test LaunchServices, Finder, Cocoa, or another PPC application.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-titlebar-rendering-contract.py)" = \
  "d7c0c39dbeec87ae95e49631914c4f93fd97feee" || exit 1

/usr/bin/shasum -a 256 ./scripts/audit-ppc-carbon-gui-titlebar-rendering-contract.py
```

Require:

```text
4e144605459536290c4a420a5e4c5e4578f667ae9945a7c288a3db92849f203c
```

No XNU checkout action is required.

## Phase B — Snow static rendering-contract report

On Snow Leopard 10.6.8 / 10K549:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-rendering-contract.py \
  ./ppc-carbon-gui-titlebar-rendering-contract-snow.txt || exit 1
```

Require:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-rendering-contract-v1
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
ArtFile10
state=PRESENT
ArtFile20
state=MISSING
archive_and_renderer_contract_exact=YES
RESULT: PASS
```

Do not launch the PPC subject after producing the report.

## Phase C — Lion static rendering-contract report

On Lion 10.7.5 / 11G63:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-rendering-contract.py \
  ./ppc-carbon-gui-titlebar-rendering-contract-lion.txt || exit 1
```

Require:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-rendering-contract-v1
product_version=10.7.5
build_version=11G63
required_arch=i386
ArtFile10
state=PRESENT
ArtFile20
state=PRESENT
archive_and_renderer_contract_exact=YES
RESULT: PASS
```

Do not launch the PPC subject after producing the report.

## Review questions

Review the two reports together before any live change.

1. Which fixed `0x68` header words differ between Snow ArtFile10 and Lion ArtFile10 for the exact-six semantics?
2. Do those differences correspond to offsets explicitly consumed or copied by Snow PPC `CUIElement::LoadFromArtFile`?
3. Are Lion ArtFile10 and ArtFile20 exact-six headers the same contract with only scale/image geometry changes, or does the record metadata itself change by generation?
4. Does Lion native CoreUI select ArtFile10 versus ArtFile20 from a scale factor that the Snow PPC implementation cannot represent or query?
5. Does the old PPC renderer use only the legacy ArtFile path while Lion's native titlebar renderer has additional titlebar-specific drawing/copy logic?
6. Is any title/window recipe actually present in Snow's recipe tree, or is the removed recipe tree irrelevant to this exact titlebar path?
7. Is the visible distortion best explained by cross-generation record-header interpretation rather than key selection or payload absence?

## Decision gates

### Cross-generation header/consumer mismatch

If a Lion ArtFile10 header field used by the Snow PPC consumer has a different meaning/layout from the Snow record at the same offset, prepare a separate exact field-level compatibility proof. Do **not** rewrite the whole payload and do not copy Snow image bytes.

### Scale-selection mismatch

If native Lion's ArtFile10/ArtFile20 selection depends on a scale factor that the Snow PPC path cannot obtain or passes differently, the next live discriminator is a narrow capture of that one scale value on Snow and Lion. Do not force ArtFile20 or substitute resources before that capture.

### Renderer-dispatch mismatch

If the archive header is compatible but Lion native titlebar rendering adds release-specific renderer behavior absent from Snow PPC CoreUI, isolate that renderer-state input next. Do not replace CoreUI wholesale.

### No relevant static differential

If the record contract, scale selection for the effective 1x path, and titlebar renderer inputs remain compatible, close those hypotheses and move to a passive all-ArtFile-key/render-state trace to determine whether the transparent titlebar background is produced by a non-`titlebarcontrols` semantic family.

## Observed result — release-specific record metadata; trace the frame/background key set before adapting fields

Both reports pass.

Snow Leopard reports six distinct exact-six ArtFile10 `0x68` headers, each with the body offset field still equal to `0x68`. Lion ArtFile10 resolves the same six semantics but all six records share one `0x68` header. Lion ArtFile20 also resolves the same six semantics and shares a second header whose scale-dependent geometry is doubled relative to ArtFile10. Snow has no ArtFile20.

The recipe/resource boundary is also release-specific: Snow's CoreUI recipe tree is present and contains `titlebarcontrols.xml`; Lion's recipe tree is absent. This is evidence of the resource-generation change, not authorization to copy the Snow recipe to Lion.

The code side makes ArtFile20 a native-Lion implementation detail rather than an immediate Rosetta compatibility target. Lion native CoreUI has `ArtFile10SetupOnce`, `ArtFile20SetupOnce`, and `GetArtFileInfoForScaleFactor(float)`. The historical PPC subject on Lion is already proven to execute Snow-era PPC CoreUI from the Rosetta cache; that code carries the legacy `ArtFileSetupOnce()` path and its own `_CUIUseArtFile` gating. Do not force ArtFile20 or substitute resources from this differential.

Most importantly for the still-transparent titlebar background, both release-local `CUIRenderer::DrawWindowTitleBar` implementations dispatch the relevant titlebar path to `CUIRenderer::DrawWindowFrameDark`. The completed live trace covered only `titlebarcontrols` keys. It did not establish which non-`titlebarcontrols` ArtFile keys the frame/background renderer requests.

A field-level `0x68` header rewrite is therefore premature. Proceed first through `docs/ppc-carbon-gui-artfile-live-key-trace.md`, which preserves the exact-six translations and passively records every unique validated ArtFile bsearch key on one Snow control and one Lion run. If live frame/background keys miss or collide under Lion, isolate those semantics before touching payload metadata. If the broader key set is semantically clean, the next stage will decode only the old Snow-PPC loader fields against Lion ArtFile10.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-titlebar-rendering-contract-snow.txt
ppc-carbon-gui-titlebar-rendering-contract-lion.txt
```

No binaries, ArtFile resources, or framework files are required.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
titlebarcontrols live set                        exact six on both releases
outside-six titlebarcontrols live lookups        0
Snow ArtFile10 exact-six headers                 6 distinct / body offset 0x68
Lion ArtFile10 exact-six headers                 1 shared / body offset 0x68
Lion ArtFile20 exact-six headers                 1 shared / scale-dependent
Snow titlebarcontrols recipe                     present
Lion recipe tree                                 absent
DrawWindowTitleBar -> DrawWindowFrameDark        static-proven on both
non-titlebarcontrols ArtFile live set             UNKNOWN
next step                                        docs/ppc-carbon-gui-artfile-live-key-trace.md
new mappings                                     NOT AUTHORIZED
payload/header substitution                      NOT AUTHORIZED
ArtFile200 forcing                               NOT AUTHORIZED
XNU                                              no source change indicated
```
