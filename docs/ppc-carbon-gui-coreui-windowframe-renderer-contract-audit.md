# PPC Carbon GUI CoreUI window-frame renderer contract audit

## Status

COMPLETED STATIC PASS. The Snow-PPC and Lion-native frame renderers are materially refactored below CUIDraw: Snow directly uses seven `CreateImage` calls plus two gray-gradient images, while Lion native uses no direct `CreateImage` calls and instead adds titlebar/background image-copy helpers and a tiled-image path. Because the historical Lion PPC process executes the Snow-PPC CoreUI image, the next controlled discriminator is `docs/ppc-carbon-gui-coreui-windowframe-image-constructor-live-trace.md`.

## Reviewed result that advances this step

Both caller-resolution reports pass with exact pinned HIToolbox slices.

Snow Leopard resolves the live 400x222 frame caller:

```text
live_offset=0x000bc5e8
role=window-frame
resolved=YES
resolved_symbol=__ZN17HIWindowFrameView8DrawDarkERK6CGRectmP9CGContext
body_contains_CUIDraw=YES
```

Lion native HIToolbox contains the same symbol and it also reaches CUIDraw:

```text
snow_resolved_symbol=__ZN17HIWindowFrameView8DrawDarkERK6CGRectmP9CGContext
native_same_symbol_present=YES
body_contains_CUIDraw=YES
```

The titlebar-control caller resolves independently to `__HIThemeDrawTitleBarWidgetInRect` on Snow, and Lion native contains the same symbol with CUIDraw call sites. The Snow-only ninth live request resolves to `__HIThemeCUIDraw`; its live widget is `kCUIWidgetMenuTitle`, so it remains outside the document-window frame defect.

Combined with the completed v2 ingress trace, the immediate HIToolbox boundary is now closed:

- Snow and Lion issue the same two 400x222 `kCUIWidgetWindowFrame` CUIDraw requests, with the same state/options sequence;
- both requests come from the same semantic HIToolbox function, `HIWindowFrameView::DrawDark`;
- the six button requests come from the same titlebar-widget function;
- the remaining visual difference therefore appears after CUIDraw enters the CoreUI renderer/resource path, not in the HIToolbox rectangle or option dictionary.

Do not rewrite frame arguments or part codes.

## Objective

Perform a read-only Snow-versus-Lion differential of the CoreUI path immediately below the proven live `kCUIWidgetWindowFrame` CUIDraw request.

The analyzer emits:

1. the complete release-local `CUIDraw` body;
2. `CUIRenderer::DrawWindowTitleBar`;
3. `CUIRenderer::DrawWindowFrameDark`;
4. `CUIRenderer::CreateImage`;
5. the release-local gray-gradient image helper;
6. Lion's `CopyWindowTitlebarImage` and `CopyWindowBackgroundImage` helpers where present;
7. a resolved call inventory for every emitted function;
8. focused call-site contexts for image creation, ArtFile loading, CGContext operations, and CUIDraw-related calls;
9. a focused call-count summary for the window-frame renderer.

The purpose is to determine which exact old-PPC CoreUI subpath produces the frame/titlebar background and which release-local resource or graphics boundary should be traced next.

This stage does not launch the PPC subject.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py
Git blob 38433f84d8b6c6709119cc89f68663712d8f6c71
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-renderer-contract-v1
```

Pinned CoreUI slices:

```text
Snow Leopard 10.6.8 / 10K549 / ppc7400
5ee01965d2702b9c05109d17404798509a10ef3d2019b35aefd5bc14199e0839

Lion 10.7.5 / 11G63 / i386
5218230aa2920f3aaf4983de76da758b5fb5168ed8a74636312cd1a57a9ab30b
```

The historical Lion PPC process is still interpreted against the already accepted invariant that it executes the Snow-era PPC CoreUI image from the Rosetta cache. Lion native CoreUI is a release-local reference only; do not substitute native Lion code into the PPC process.

## Existing evidence to preserve

Earlier static work already established:

- both release-local `CUIRenderer::DrawWindowTitleBar` implementations can enter `DrawWindowFrameDark`;
- Snow's `DrawWindowFrameDark` contains multiple `CreateImage` calls and gray-gradient construction;
- Lion native `DrawWindowFrameDark` contains release-specific titlebar/background image-copy helpers in addition to gradient/drawing logic;
- the all-ArtFile live trace found only the accepted six titlebar-control bsearch keys, so do not invent a new ArtFile key merely because the window-frame path is now under review;
- the exact bitmap-info conversion remains a causal fix only for the six traffic-light images.

The new audit is intended to identify the next *specific* renderer boundary. It is not permission to copy Lion-native renderer code, Snow resources, or whole frame images.

## Safety constraints

- Do not launch the PPC subject.
- Do not rebuild or load any compatibility dylib.
- Do not rerun the v2 CUIDraw trace.
- Retain the accepted `0x2 -> 0x2002` traffic-light bitmap-info adapter, but do not change it.
- Do not change CUIDraw arguments.
- Do not add ArtFile mappings.
- Do not patch CoreUI, HIToolbox, ArtFile, ArtFile200, recipes, pixels, or metrics.
- Do not interpose private C++ renderer methods yet.
- Do not change hit masks or classic window part codes.
- Do not broaden CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py)" = \
  "38433f84d8b6c6709119cc89f68663712d8f6c71" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-renderer-contract-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py","rb").read(),"audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py","exec")' || exit 1
```

## Phase B — Snow CoreUI frame-renderer report

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py \
  ./ppc-carbon-gui-coreui-windowframe-renderer-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
coreui_slice_exact=YES
live_windowframe_widget=kCUIWidgetWindowFrame
live_windowframe_rect=0,0,400,222
live_request_stream_equivalent_snow_lion=YES
windowframe_renderer_contract_exact=YES
RESULT: PASS
```

Require the Snow symbols:

```text
_CUIDraw
CUIRenderer::DrawWindowTitleBar
CUIRenderer::DrawWindowFrameDark
CUIRenderer::CreateImage
CUIRenderer::CreateGrayCubicGradientImage(int,int,int)
```

to report `present=YES`.

Do not launch the PPC subject afterward.

## Phase C — Lion CoreUI frame-renderer report

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-renderer-contract.py \
  ./ppc-carbon-gui-coreui-windowframe-renderer-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
required_arch=i386
coreui_slice_exact=YES
live_windowframe_widget=kCUIWidgetWindowFrame
live_windowframe_rect=0,0,400,222
live_request_stream_equivalent_snow_lion=YES
runtime_on_lion=accepted_snow_ppc_coreui_cache
native_lion_role=release_local_renderer_reference
windowframe_renderer_contract_exact=YES
RESULT: PASS
```

Require the Lion symbols:

```text
_CUIDraw
CUIRenderer::DrawWindowTitleBar
CUIRenderer::DrawWindowFrameDark
CUIRenderer::CreateImage
CUIRenderer::CreateGrayCubicGradientImage(...)
CUIRenderer::CopyWindowTitlebarImage
CUIRenderer::CopyWindowBackgroundImage
```

to report `present=YES`.

Do not launch the PPC subject afterward.

## Review gate

Review both reports together.

### Snow PPC frame path uses specific image/resource constructors that Lion native replaced or wrapped

Identify the smallest downstream boundary that can be observed without modifying rendering. Prefer a passive trace of an external CoreGraphics/CoreUI C API used by the old PPC frame path over patching a private C++ method.

The key question is whether the old Snow-PPC frame renderer obtains a NULL/empty image, different geometry, different colors, or different compositing input on Lion.

### Snow PPC frame path is primarily generated gradients/fills

Do not chase ArtFile mappings. Isolate the release-local color/gradient input or the first CGContext operation whose input differs between healthy Snow and faulty Lion.

### Snow PPC frame path still reaches CUIElement/ArtFile loading outside the six button calls

Reconcile that against the already completed all-ArtFile bsearch trace before any new mapping. A static reference alone is not a live lookup.

### No actionable renderer differential

If the old PPC window-frame subpath is entirely deterministic from the already-proven identical CUIDraw inputs and does not consume a release-local resource, the next discriminator should shift to the backing CGContext/window-surface state rather than adding renderer compatibility.

## Observed result

Both returned renderer-contract reports pass with exact pinned CoreUI slices.

Snow PPC `CUIRenderer::DrawWindowFrameDark` reports:

```text
CreateImage_count=7
CreateGrayCubicGradientImage_count=2
CopyWindowTitlebarImage_count=0
CopyWindowBackgroundImage_count=0
CGContextFillRect_count=4
CGContextDrawTiledImage_count=0
```

Lion native `DrawWindowFrameDark` reports:

```text
CreateImage_count=0
CreateGrayCubicGradientImage_count=1
CopyWindowTitlebarImage_count=1
CopyWindowBackgroundImage_count=1
CGContextFillRect_count=4
CGContextDrawTiledImage_count=1
```

Snow's seven direct frame-image requests are the legacy IDs `0x4e8e`, `0x4e90`, `0x4e89`, `0x4e8a`, `0x4e8d`, `0x4e8f`, and `0x4e91`. Its gray-gradient helper directly constructs an 8-bit grayscale CGImage at CoreUI return offset `0x0001bdb0`. The earlier exact bitmap-info tracer intentionally covered only the ArtFile-loader return offset `0x000299e0` and exact titlebar-button geometry, so it did not observe these frame-specific/non-button constructors.

This is a release-specific renderer refactor, but it is not authorization to invoke Lion's native copy helpers from the PPC process. The historical subject on Lion still runs Snow-era PPC CoreUI; the compatibility question is whether that old renderer constructs the same non-button images on healthy Snow and faulty Lion.

Follow `docs/ppc-carbon-gui-coreui-windowframe-image-constructor-live-trace.md` next. It preserves the exact accepted six-call bitmap-info adapter while logging every CoreUI-originating `CGImageCreate` call and result. No new bitmap-info expansion or resource substitution is authorized before that live differential is reviewed.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-renderer-snow.txt
ppc-carbon-gui-coreui-windowframe-renderer-lion.txt
```

No binary or live trace is required.

## Current boundary

```text
renderer-contract audit                         PASS on Snow and Lion
Snow PPC direct CreateImage calls                7
Snow PPC gray-gradient constructors              2
Lion native direct CreateImage calls             0
Lion native CopyWindowTitlebarImage               1
Lion native CopyWindowBackgroundImage             1
Lion native CGContextDrawTiledImage               1
historical Lion runtime renderer                  accepted Snow-PPC CoreUI cache
native Lion helper substitution                   NOT AUTHORIZED
bitmapInfo 0x2 -> 0x2002                         RETAIN exact-six only
next step                                        docs/ppc-carbon-gui-coreui-windowframe-image-constructor-live-trace.md
XNU                                              no source change indicated
```
