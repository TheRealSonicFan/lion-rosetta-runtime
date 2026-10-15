# PPC Carbon GUI HIToolbox CUIDraw caller-resolution audit

## Status

COMPLETED STATIC PASS. The live frame caller resolves to `HIWindowFrameView::DrawDark` on Snow and the same native Lion symbol is present and reaches CUIDraw. The live button caller resolves to `HIThemeDrawTitleBarWidgetInRect` on both, while the Snow-only extra resolves to `HIThemeCUIDraw` for a menu-title request. HIToolbox request construction is closed; the next controlled step is `docs/ppc-carbon-gui-coreui-windowframe-renderer-contract-audit.md`.

## Reviewed live result

The returned v2 trace artifact matches the pinned build contract:

```text
interposer_source_git_blob=d9419ec4ac62ba651a45eaa2bb515a8bb38c9793
trace_build_id=hitoolbox-windowframe-cuidraw-trace-v2
artifact_sha256=0feb833c50e40c92593b2922a94b6c8e7302849f8a8dd6bcd1326c8c8b6288db
```

Snow passes with:

```text
windowframe_cuidraw_trace_build_count=1
windowframe_cuidraw_trace_call_count=9
windowframe_cuidraw_trace_hitoolbox_count=9
windowframe_cuidraw_trace_target_slot_count=0
windowframe_cuidraw_trace_passthrough_count=9
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion passes with:

```text
windowframe_cuidraw_trace_build_count=1
windowframe_cuidraw_trace_call_count=8
windowframe_cuidraw_trace_hitoolbox_count=8
windowframe_cuidraw_trace_target_slot_count=0
windowframe_cuidraw_trace_passthrough_count=8
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_PASS
RESULT: PASS
```

The live request streams now close the v1 ambiguity.

The first eight calls are equivalent on Snow and Lion after ignoring only the trace mode string:

```text
caller 0x000bc5e8, twice
  rect      0,0,400,222
  widget    kCUIWidgetWindowFrame
  windowtype regularwin
  titlebar height 22
  draw title separator true
  is.flipped true
  states    inactive, then normal

caller 0x00022374, six times
  rect      0,0,14,16
  widgets   titlebarclose / titlebarcollapse / titlebarzoom
  states    disabled, then normal
  vertical alignment maximum
  horizontal alignment minimum
```

Snow has one additional ninth call:

```text
caller 0x0001f340
widget kCUIWidgetMenuTitle
```

That extra call is a menu-title draw and is not the missing document-window titlebar/frame background.

Therefore:

- the healthy Snow and faulty Lion runs issue the same live `kCUIWidgetWindowFrame` requests;
- the exact frame request dictionary and 400x222 rectangle are not the remaining release mismatch;
- the six titlebar-button requests are also structurally the same at this boundary, with the accepted exact-six key and bitmap-info adapters accounting for their Lion resource differences;
- the old v1 six-offset hypothesis was wrong for the actual live subject;
- no CUIDraw argument rewrite is authorized.

Before moving below CUIDraw into CoreUI renderer/resource behavior, resolve the three observed Snow-PPC HIToolbox caller offsets to their containing functions and compare the same symbols in Lion native HIToolbox.

## Objective

Statically resolve:

```text
0x000bc5e8  live kCUIWidgetWindowFrame caller
0x00022374  live titlebar-control caller
0x0001f340  Snow-only kCUIWidgetMenuTitle caller
```

against the exact Snow PPC HIToolbox image, then locate the same resolved symbol names in Lion native HIToolbox.

This is a caller-identification audit only. It does not launch the PPC subject.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py
Git blob 2deb07f3eebc31f32a60098e5467d974dd41e8ce
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-hitoolbox-cuidraw-caller-resolution-v1
```

Pinned HIToolbox slices:

```text
Snow 10.6.8 / 10K549 / ppc7400
fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f

Lion 10.7.5 / 11G63 / i386
b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6
```

For Snow, the analyzer emits the containing symbol, symbol bounds, caller delta, whether the body contains CUIDraw, and the complete function body for each live offset.

For Lion, the analyzer consumes the Snow report, finds the same resolved symbol names in the native Lion HIToolbox slice, and emits their complete native bodies when present.

## Safety constraints

- Do not launch the PPC subject.
- Do not rebuild or load the v2 trace artifact.
- Keep the bitmap-info adapter retained but do not rerun it.
- Do not modify CUIDraw arguments.
- Do not patch CoreUI, HIToolbox, ArtFile resources, window metrics, hit masks, or part codes.
- Do not broaden CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py)" = \
  "2deb07f3eebc31f32a60098e5467d974dd41e8ce" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-hitoolbox-cuidraw-caller-resolution-v1"$' \
  ./scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py","rb").read(),"audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py","exec")' || exit 1
```

## Phase B — Snow caller resolution

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py \
  ./ppc-carbon-gui-hitoolbox-cuidraw-callers-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
hitoolbox_slice_exact=YES
runtime_ppc_hitoolbox_contract=local_snow_ppc_reference
cuidraw_caller_resolution_exact=YES
RESULT: PASS
```

Require all three live offsets to report:

```text
resolved=YES
body_contains_CUIDraw=YES
```

Do not launch the PPC subject afterward.

## Phase C — transfer only the Snow text report

Copy:

```text
ppc-carbon-gui-hitoolbox-cuidraw-callers-snow.txt
```

to the Lion runtime working directory.

No dylib transfer is required.

## Phase D — Lion same-symbol reference

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-hitoolbox-cuidraw-callers.py \
  ./ppc-carbon-gui-hitoolbox-cuidraw-callers-lion.txt \
  ./ppc-carbon-gui-hitoolbox-cuidraw-callers-snow.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
required_arch=i386
hitoolbox_slice_exact=YES
runtime_ppc_hitoolbox_contract=accepted_identical_snow_ppc_cache
native_lion_hitoolbox_role=same-symbol release reference
cuidraw_caller_resolution_exact=YES
RESULT: PASS
```

Do not launch the PPC subject afterward.

## Review gate

### Window-frame caller resolves to a shared symbol on Snow and Lion

Compare the two function bodies and their immediate CUIDraw setup. If the Snow-PPC and Lion-native functions construct equivalent window-frame requests, close HIToolbox request construction and move one layer down to the CoreUI `kCUIWidgetWindowFrame` renderer/resource contract.

### Window-frame caller is Snow-only or materially refactored

Do not substitute the Lion function. Isolate the exact release-specific input or helper used by the Snow caller first.

### Titlebar-control caller resolves separately

Treat it as confirmation of the already accepted six-button path; do not broaden titlebar key translation.

### Snow-only menu-title caller

Keep it out of the window-frame defect unless later evidence directly connects it.

## Observed result

Both returned reports pass with exact pinned HIToolbox slices.

Snow resolves the live window-frame call at `0x000bc5e8` to:

```text
HIWindowFrameView::DrawDark(CGRect const&, unsigned long, CGContext*)
symbol_start=0x000bc224
caller_delta=0x3c4
body_contains_CUIDraw=YES
```

Lion native HIToolbox contains the same symbol at `0x00109bf8`, and its body also contains a CUIDraw call.

The six live titlebar-control calls at Snow offset `0x00022374` resolve to `HIThemeDrawTitleBarWidgetInRect`; Lion native contains the same symbol and CUIDraw path. The Snow-only call at `0x0001f340` resolves to `HIThemeCUIDraw`; Lion also has that symbol, but the live v2 evidence shows this ninth Snow request is `kCUIWidgetMenuTitle`, so it remains outside the document-window frame defect.

The important discriminator is now closed: the healthy Snow and faulty Lion runs send equivalent live `kCUIWidgetWindowFrame` requests from the same semantic HIToolbox frame function, and the corresponding native Lion function still uses the same CUIDraw boundary. No frame rectangle, CUIDraw dictionary, or hit-part adaptation is supported.

Proceed to `docs/ppc-carbon-gui-coreui-windowframe-renderer-contract-audit.md`. That audit stays static and moves exactly one layer below CUIDraw to identify which Snow-PPC CoreUI renderer/resource subpath actually produces the window-frame/titlebar background.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-hitoolbox-cuidraw-callers-snow.txt
ppc-carbon-gui-hitoolbox-cuidraw-callers-lion.txt
```

No live logs or binaries are required.

## Current boundary

```text
caller-resolution audit                         PASS on Snow and Lion
window-frame caller                              HIWindowFrameView::DrawDark
Snow live frame caller offset                    0x000bc5e8
Lion native same frame symbol                    PRESENT / contains CUIDraw
titlebar-control caller                          HIThemeDrawTitleBarWidgetInRect
Snow-only extra                                  HIThemeCUIDraw / kCUIWidgetMenuTitle
live window-frame request                        EQUIVALENT
HIToolbox request construction                   CLOSED
CUIDraw argument rewrite                         NOT AUTHORIZED
bitmapInfo 0x2 -> 0x2002                         RETAIN
next step                                        docs/ppc-carbon-gui-coreui-windowframe-renderer-contract-audit.md
XNU                                              no source change indicated
```
