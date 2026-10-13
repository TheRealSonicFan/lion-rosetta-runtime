# ShowWindow CoreUI/theme-path static audit

## Objective

Perform a read-only Snow Leopard-versus-Lion differential of the exact theme-rendering path identified by the preserved exact-seven ShowWindow crash.

The postmortem closes the earlier ambiguity around RawCamera and the notification broker. The fault is a real `EXC_BAD_ACCESS (SIGSEGV)` on the Rosetta-translated PPC main-thread path while Lion CoreUI is reporting an invalid art-file path. The PPC stack is:

```text
ShowWindow
  -> __ShowHideWindows
  -> WindowData::PrepareForVisibility
  -> PaintWindow
  -> HIView composited drawing
  -> HIWindowButtonView::DrawSelf
  -> __HIThemeDrawTitleBarWidgetInRect
  -> CUIRenderer::Draw
  -> CUIRenderer::Draw1Piece
  -> CUIElement::Load
  -> CUIElement::LoadFromArtFile
  -> ShowArtFilePathToStdErr
  -> fprintf / vfprintf
  -> SIGSEGV
```

The observed fault address is `0x787221c4`. The PPC crash state contains `r3=0x787221c5`, `r9=0x787221c4`, and CoreUI-address values in `r4/r15/r27`. The Rosetta host EIP is `0x8bea0843`, where the translated code executes a 32-bit load through `ECX=0x787221c4`.

This proves that the current failure is in the CoreUI/HIToolbox theme-art diagnostic/rendering path. It does **not** yet prove whether the bad pointer originates from a release-specific CoreUI path representation, a descriptor/layout mismatch, a resource/archive difference, or another upstream value consumed by `CUIElement::LoadFromArtFile`.

The next safe step is static comparison only. Do not suppress `fprintf`, replace CoreUI resources, or interpose the rendering functions before the Snow/Lion differential is reviewed.

## Postmortem provenance

The read-only collector passed all three GDB stages and produced a 512-byte crash window.

```text
Rosetta translator SHA-256
4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18

crash window SHA-256
17010dbf591b2c3b6dbdbd5d9912ce75b27ce69e09b7f5c12b5079ff0a6fefe1
```

The sidecar matches the independently returned crash-window file.

The crash report identifies:

```text
Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
Exception Codes: KERN_INVALID_ADDRESS at 0x00000000787221c4
```

The PPC backtrace identifies CoreUI directly; `RawCamera` does not appear anywhere in the preserved postmortem report. RawCamera therefore remains loaded-but-unproven and must not be modified in this stage.

A successful Snow Leopard ShowWindow control reaches `S01_AFTER_ShowWindow`, `SHOWWINDOW_PASS`, and `M24_SUCCESS` without the Lion CoreUI `Invalid ArtFile Path!` diagnostic cluster.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-showwindow-coreui-theme.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and read-only. On each host it records:

- OS/build and Rosetta arch-handler provenance;
- Rosetta shared-cache and map hashes;
- cache-map references to CoreUI and HIToolbox;
- full SHA-256, `file`, and `lipo` provenance for CoreUI and HIToolbox;
- every inspectable `ppc7400`, `ppc`, `i386`, or `x86_64` slice, deduplicated by slice hash;
- focused CoreUI symbol inventory and complete disassembly bodies for crash-path symbols such as:
  - `ShowArtFilePathToStdErr`
  - `CUIElement::LoadFromArtFile`
  - `CUIElement::Load`
  - `CUIRenderer::Draw1Piece`
  - `CUIRenderer::Draw`
  - related `CUIDescriptor` / art-file helpers;
- focused HIToolbox symbol inventory and complete disassembly bodies for:
  - `__HIThemeDrawTitleBarWidgetInRect`
  - `HIWindowButtonView::DrawSelf`
  - `HIView` composited drawing helpers
  - `PaintWindow`
  - `WindowData::PrepareForVisibility`
  - `__ShowHideWindows`
  - `ShowWindow`;
- focused cstrings including `Invalid ArtFile Path`, art/theme/archive, Aqua, scrollbar, titlebar, and related names;
- focused imports including `fprintf`/`vfprintf`, string/memory routines, CoreFoundation, CGContext, and theme-related calls;
- focused resource inventories and hashes from CoreUI and HIToolbox resource directories.

The analyzer does not assume that Snow and Lion expose the same architecture set. That architecture/provenance difference is itself part of the audit.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not run the exact-seven broker again.
- Do not attach GDB to a live process.
- Do not use DTrace or dtruss.
- Do not suppress or interpose `fprintf`, `vfprintf`, `ShowArtFilePathToStdErr`, `CUIElement::LoadFromArtFile`, or any rendering routine.
- Do not patch, copy, replace, or symlink CoreUI binaries/resources.
- Do not copy Snow Leopard theme assets or framework resources onto Lion.
- Do not patch RawCamera or ImageIO.
- Do not alter the accepted WindowBackingInfo, ColorProfileClient, ResolveColorProfile, FontServer, distributed-notification, Security, HIToolbox Extras, NewWindow, release-backing, opacity, AddTrackingArea, OrderFrontConditionally, or SetFrontWindow compatibility paths.
- Do not revisit `CGSShapeWindow` in this stage.
- Do not restart WindowServer, Dock, fontd, distnoted, launchd, or related services.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update runtime on both systems

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime
cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

ls -l ./scripts/audit-pm-showwindow-coreui-theme.py
ls -l ./docs/pm-showwindow-coreui-theme-audit.md
```

No XNU build action is required.

## Phase B — Snow Leopard static audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-showwindow-coreui-theme.py \
  ./pm-coreui-snow.txt
```

Require:

```text
Created: ./pm-coreui-snow.txt
RESULT: PASS
```

Do not launch the PPC subject after producing the report.

## Phase C — Lion static audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-showwindow-coreui-theme.py \
  ./pm-coreui-lion.txt
```

Require:

```text
Created: ./pm-coreui-lion.txt
RESULT: PASS
```

Do not launch the PPC subject after producing the report.

## Phase D — return evidence

Return exactly:

```text
pm-coreui-snow.txt
pm-coreui-lion.txt
```

Do not return framework binaries, resource archives, shared caches, or private Apple assets.

If either audit returns `RESULT: FAIL`, return both reports as produced and stop. Do not work around a missing architecture or symbol by copying a framework from the other OS.

## Review questions

The two reports must answer these questions before any live compatibility experiment is prepared:

1. Does Snow CoreUI contain the same `ShowArtFilePathToStdErr -> fprintf` diagnostic path, and if so, how is the art-path pointer obtained and validated?
2. Does Lion `CUIElement::LoadFromArtFile` use a different descriptor/path layout, offset, ownership rule, or string representation from Snow?
3. Do Snow and Lion `CUIRenderer::Draw1Piece` / `Draw` pass the same object/path state into `CUIElement::Load`?
4. Does the HIToolbox titlebar-button caller contract differ before CoreUI is entered?
5. Is the exact `Invalid ArtFile Path!` format string present in both releases, and what arguments are passed to it?
6. Are the relevant CoreUI/theme resource inventories materially different in a way that can explain the Lion-only invalid-art path?
7. Does the Rosetta cache map select the same framework paths and architecture families on both systems?

## Decision gates

### Exact CoreUI path/descriptor differential

If the reports expose one narrow release-specific field/offset/path representation change in `CUIElement::LoadFromArtFile` or its immediate caller, prepare a separate read-only or capture-only discriminator for that exact value before adapting it. Do not replace the whole CoreUI framework.

### Resource/archive differential

If code paths are equivalent but Lion is missing or structurally changes the exact theme/archive resource expected by the Snow PPC path, audit that exact resource lookup contract next. Do not copy Snow resources merely because their names differ.

### HIToolbox caller differential

If the divergence originates before CoreUI, narrow the next stage to the titlebar/button descriptor passed by `__HIThemeDrawTitleBarWidgetInRect` / `HIWindowButtonView::DrawSelf`.

### Equivalent static paths

If Snow and Lion are statically equivalent at the relevant path, the next discriminator should be a narrow live argument capture around `CUIElement::LoadFromArtFile` / `ShowArtFilePathToStdErr` on one Snow control and one Lion run. Do not suppress the diagnostic or force a successful load.

## Current boundary

```text
syscall 295 compatibility                         PASS
WindowBackingInfo compatibility                   PASS
ColorProfileClient compatibility                  PASS
ResolveColorProfile compatibility                 PASS
exact-seven distributed notifications             PASS
eighth notification request                       not observed
ShowWindow return                                 not reached
termination                                       SIGSEGV / KERN_INVALID_ADDRESS
fault address                                     0x787221c4
Rosetta host EIP                                  0x8bea0843
PPC fault path                                    vfprintf <- fprintf <- CoreUI
CoreUI function                                   ShowArtFilePathToStdErr
upstream CoreUI path                              LoadFromArtFile <- Load <- renderer
HIToolbox path                                    titlebar button drawing
RawCamera                                         absent from crash stack / held
CGSShapeWindow                                    held
next step                                         Snow/Lion CoreUI + HIToolbox static differential
XNU                                               no change indicated
```
