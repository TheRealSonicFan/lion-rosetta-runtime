# PPC Carbon GUI HIToolbox CUIDraw ingress passive live trace

## Status

COMPLETED LIVE-PROVEN PASS. Version 2 proves CUIDraw executes from HIToolbox on both systems, but from different live offsets than the original six-slot hypothesis. The first eight Snow/Lion requests are equivalent; Snow has one additional menu-title call. The next controlled step is `docs/ppc-carbon-gui-hitoolbox-cuidraw-caller-resolution-audit.md`.

## Phase A repair note

An earlier current-main runner edit accidentally duplicated a tail block through shell-text replacement expansion, leaving the Snow runner with an unterminated single quote and an unexpected EOF. The Snow and Lion runners have now both been rebuilt from their last known-good optional-trace versions, then re-applied with only the v2 build/source/mode pins and trace counters. Their current blobs are the Phase A pins below. Do not use the superseded runner blobs from an older checkout.

## Why this rerun is required

The v1 trace artifact was valid and loaded, and both accepted runtime stacks remained healthy, but neither complete subject log contained any v1 runtime trace marker. The v1 interposer emitted its build marker only after all of these checks succeeded:

1. `CUIDraw` had been intercepted;
2. `dladdr` resolved the caller;
3. the caller image path contained `/HIToolbox.framework/`;
4. the caller return offset matched one of the six statically proven Snow PPC document-window `CUIDraw` sites.

A zero-marker run therefore cannot distinguish a real no-`CUIDraw` execution path from a caller-classification failure. Do not infer request-stream equivalence and do not move down into CoreUI/resource interpretation from the v1 result.

Version 2 removes that ambiguity.

## Version 2 behavior

Current runtime `main` provides:

```text
tests/ppc-hitoolbox-windowframe-cuidraw-trace-interposer.c
Git blob d9419ec4ac62ba651a45eaa2bb515a8bb38c9793

scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh
Git blob 887ed8dc2ab9fa2f2e2e0f0135d2da22394b80cf

scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh
Git blob f6ca0508679663cd65ba96b5be30620f05f1a5b8

scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh
Git blob 6f6f93a288674fdabe99cb6e7c18d6ade6216136
```

Trace build contract:

```text
trace_build_id=hitoolbox-windowframe-cuidraw-trace-v2
interposer_source_git_blob=d9419ec4ac62ba651a45eaa2bb515a8bb38c9793
```

Version 2 changes diagnostics only:

- a constructor emits the build marker immediately when the dylib is loaded;
- every intercepted `CUIDraw` call is logged before caller filtering;
- each call records whether `dladdr` succeeded;
- each call records whether the caller resolves inside HIToolbox;
- each HIToolbox call records the caller offset and whether it is one of the original six slots;
- rectangle and pointer-presence fields are recorded for every call;
- option dictionaries are decoded only for HIToolbox callers;
- every call invokes the original `CUIDraw` unchanged.

No argument, CoreFoundation object, CGContext, CoreUI renderer, result pointer, or return state is modified.

## Safety constraints

- Retain every currently accepted compatibility artifact.
- Retain `CGImageCreate bitmapInfo 0x2 -> 0x2002` on Lion.
- Retain the exact-six titlebar key translation.
- Do not change any CUIDraw option or rectangle.
- Do not alter titlebar metrics, pixels, resources, ArtFile records, hit masks, or part codes.
- Do not add a CGS rule.
- Do not interpose `FindWindow`, `DragWindow`, `HIThemeGetWindowRegionHit`, or `ThemeWindowDef::HitSelf`.
- Do not manually drag the window during this diagnostic.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — pull and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-hitoolbox-windowframe-cuidraw-trace-interposer.c)" = \
  "d9419ec4ac62ba651a45eaa2bb515a8bb38c9793" || exit 1

test "$(git hash-object ./scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh)" = \
  "887ed8dc2ab9fa2f2e2e0f0135d2da22394b80cf" || exit 1

test "$(git hash-object ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh)" = \
  "f6ca0508679663cd65ba96b5be30620f05f1a5b8" || exit 1

test "$(git hash-object ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh)" = \
  "6f6f93a288674fdabe99cb6e7c18d6ade6216136" || exit 1

/bin/bash -n ./scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh || exit 1
/bin/bash -n ./scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh || exit 1
/bin/bash -n ./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh || exit 1
```

## Phase B — rebuild v2 on Snow Leopard

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-hitoolbox-windowframe-cuidraw-trace-on-snowleopard.sh \
  ./payload/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib || exit 1
```

Require:

```text
trace_build_id=hitoolbox-windowframe-cuidraw-trace-v2
interposer_source_git_blob=d9419ec4ac62ba651a45eaa2bb515a8bb38c9793
```

Require one PPC `__DATA,__interpose` tuple replacing only `CUIDraw`.

## Phase C — Snow ingress trace

Use the accepted Snow artifacts and the new v2 trace:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_PATH="$PWD/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_SHA256_FILE="$PWD/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.sha256"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_INFO_FILE="$PWD/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.info.txt"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-cuidraw-ingress-v2-snow.log \
  ./ppc-carbon-gui-cuidraw-ingress-v2-snow-observer.log || exit 1
```

Require the existing Snow full-stack control to remain PASS.

The runner now emits:

```text
windowframe_cuidraw_trace_build_count=
windowframe_cuidraw_trace_call_count=
windowframe_cuidraw_trace_hitoolbox_count=
windowframe_cuidraw_trace_target_slot_count=
windowframe_cuidraw_trace_passthrough_count=
```

Require:

```text
windowframe_cuidraw_trace_build_count=1
windowframe_cuidraw_trace_passthrough_count == windowframe_cuidraw_trace_call_count
```

A call count of zero is valid diagnostic evidence in v2 because the constructor marker independently proves the trace dylib executed.

Manual Snow gate:

```text
Snow titlebar visually normal: YES/NO
```

Do not drag the window.

## Phase D — transfer only v2

Transfer exactly:

```text
pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib
pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.info.txt
pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.sha256
```

Do not replace any accepted compatibility artifact.

## Phase E — Lion ingress trace

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_PATH="$PWD/payload/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_SHA256_FILE="$PWD/payload/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.sha256"
export ROSETTA_HITOOLBOX_WINDOWFRAME_CUIDRAW_TRACE_INFO_FILE="$PWD/payload/pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.info.txt"

./scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh \
  "$PWD/payload/ppc-carbon-gui-smoketest-private-dyld" \
  "$PWD/payload/ppc-carbon-gui-smoketest-private-dyld.sha256" \
  "$PWD/payload/pm-carbon-gui-backing-sync-compat.dylib" \
  "$PWD/payload/pm-carbon-gui-backing-sync-compat.dylib.sha256" \
  "$PWD/payload/ppc-process-manager-security-session-auditinfo-api.dylib" \
  "$PWD/payload/ppc-process-manager-security-session-auditinfo-api.dylib.sha256" \
  "$PWD/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib" \
  "$PWD/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib.sha256" \
  "$PWD/dn-carbon-gui-registration-broker" \
  "$PWD/dn-carbon-gui-registration-broker.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-cuidraw-ingress-v2.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-cuidraw-ingress-v2-observer.log" || exit 1
```

The raw log is:

```text
payload/lion-ppc-carbon-gui-cuidraw-ingress-v2.raw.log
```

Require the existing Lion restored-stack/bitmap-info integration to remain PASS.

Require:

```text
windowframe_cuidraw_trace_build_count=1
windowframe_cuidraw_trace_passthrough_count == windowframe_cuidraw_trace_call_count
```

Again, zero calls are valid diagnostic evidence if the build count is one.

Manual Lion gate:

```text
Lion titlebar visually normal: YES/NO/PARTIAL
```

Do not drag the window.

## Decision gate

### Snow calls > 0 and Lion calls > 0

Compare the complete call streams.

- If target-slot counts are nonzero, the v1 caller predicate was the problem; use the v2 caller/image/offset evidence to repair the narrow frame trace and compare option dictionaries.
- If HIToolbox calls are nonzero but target slots remain zero, identify the actual HIToolbox caller offsets before any adaptation.
- If only non-HIToolbox calls appear, the old Snow PPC frame helper is not the live CUIDraw caller; do not adapt the six static frame slots.

### Snow calls > 0 and Lion calls = 0

This is a strong release-specific branch discriminator: the healthy Snow subject reaches CUIDraw and Lion does not. The next step should isolate the old PPC `__HIThemeUseCoreUI` / non-CoreUI branch decision without changing it.

### Snow calls = 0 and Lion calls > 0

The old PPC runtime takes a Lion-only CUIDraw path. Review the Lion callers before any frame adaptation.

### Snow calls = 0 and Lion calls = 0

The live frame does not reach interposed `CUIDraw` on either OS despite the trace constructor executing. Stop pursuing the separate Snow CoreUI frame helper. The next static discriminator is the shared old-PPC non-CoreUI path:

```text
DataEngine::DrawWindowFrame(...)
DataEngine::GetWindowRegionHitMask(...)
LayoutEngine draw/hit helpers
```

That path is especially relevant because it can account for both the missing titlebar/frame background and the non-draggable titlebar without inventing a part-code translation.

## Observed result — live CUIDraw ingress is now resolved

The returned v2 artifact matches the pinned identity:

```text
interposer_source_git_blob=d9419ec4ac62ba651a45eaa2bb515a8bb38c9793
trace_build_id=hitoolbox-windowframe-cuidraw-trace-v2
artifact_sha256=0feb833c50e40c92593b2922a94b6c8e7302849f8a8dd6bcd1326c8c8b6288db
```

Snow:

```text
windowframe_cuidraw_trace_build_count=1
windowframe_cuidraw_trace_call_count=9
windowframe_cuidraw_trace_hitoolbox_count=9
windowframe_cuidraw_trace_target_slot_count=0
windowframe_cuidraw_trace_passthrough_count=9
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_SNOW_CONTROL_PASS
RESULT: PASS
```

Lion:

```text
windowframe_cuidraw_trace_build_count=1
windowframe_cuidraw_trace_call_count=8
windowframe_cuidraw_trace_hitoolbox_count=8
windowframe_cuidraw_trace_target_slot_count=0
windowframe_cuidraw_trace_passthrough_count=8
RESULT: PPC_CARBON_GUI_COREUI_IMAGE_BITMAPINFO_COMPAT_PASS
RESULT: PASS
```

The first eight call records match exactly after ignoring only the trace mode label. In particular, both systems issue two identical `kCUIWidgetWindowFrame` draws from caller offset `0x000bc5e8`: one inactive and one normal, each for the 400x222 frame with `regularwin`, unified titlebar height 22, title separator enabled, and flipped coordinates. Both also issue the same six titlebar-control requests from `0x00022374`.

Snow's ninth call is from `0x0001f340` and requests `kCUIWidgetMenuTitle`; it is unrelated to the missing document-window titlebar/frame background.

This closes CUIDraw request construction as the immediate mismatch: no rectangle or option-dictionary adaptation is authorized. The v1 six caller offsets were simply not the actual live callers for this subject.

Follow `docs/ppc-carbon-gui-hitoolbox-cuidraw-caller-resolution-audit.md` next. It statically maps the three observed Snow-PPC offsets to their containing HIToolbox functions and compares those same symbol names with Lion native HIToolbox before the investigation moves below CUIDraw into the CoreUI window-frame renderer/resource contract.

## Return evidence

Return:

```text
pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.info.txt
pm-hitoolbox-windowframe-cuidraw-trace-v2.dylib.sha256
ppc-carbon-gui-cuidraw-ingress-v2-snow.log
ppc-carbon-gui-cuidraw-ingress-v2-snow-observer.log
lion-ppc-carbon-gui-cuidraw-ingress-v2.log
lion-ppc-carbon-gui-cuidraw-ingress-v2.raw.log
lion-ppc-carbon-gui-cuidraw-ingress-v2-observer.log
```

Also state:

```text
Snow titlebar visually normal: YES/NO
Lion titlebar visually normal: YES/NO/PARTIAL
```

## Current boundary

```text
v2 trace constructor marker                      1 / 1
v2 CUIDraw calls                                 9 Snow / 8 Lion
v2 HIToolbox calls                               9 Snow / 8 Lion
v2 original target slots                         0 / 0
first eight request stream                       EQUIVALENT
window-frame caller                              0x000bc5e8 on both
window-frame request                             EQUIVALENT
Snow-only ninth call                             0x0001f340 / kCUIWidgetMenuTitle
CUIDraw argument mutation                        NONE / NOT AUTHORIZED
bitmapInfo 0x2 -> 0x2002                         RETAIN
part-code translation                            NOT AUTHORIZED
next step                                       docs/ppc-carbon-gui-hitoolbox-cuidraw-caller-resolution-audit.md
XNU                                             no source change indicated
```
