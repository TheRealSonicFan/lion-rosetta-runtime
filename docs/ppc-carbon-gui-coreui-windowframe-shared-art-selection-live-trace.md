# PPC Carbon GUI CoreUI window-frame shared-art selection live trace

## Status

NEXT CONTROLLED LIVE STEP after the static SArtFile frame-record audit proved that the same seven legacy frame IDs resolve to materially different record types/geometry on Snow Leopard and Lion, including exact static candidates for both Lion raw-image geometries already seen live.

## Reviewed static result

Both returned SArtFile record reports pass against the pinned CoreUI slices and exact release-local `SArtFile.bin` files.

Snow's seven frame records are all legacy shared-art type `2` with one entry. Under the accepted Snow-PPC `CUISharedArtReader::CreateImage(long,float)` implementation, type `2` always selects raw slot 0. The decoded slot-0 geometries are:

```text
0x4e8e  11x11
0x4e90  11x11
0x4e89   1x23
0x4e8a  11x11
0x4e8d  11x11
0x4e8f  11x11
0x4e91  11x11
```

The earlier all-CoreUI constructor trace recorded exactly five Snow calls at `CreateImageFromBytes -> CGImageCreate`, all 11x11. Therefore `0x4e89` was not one of those five live raw calls, and exactly one of the six 11x11 IDs also did not reach that constructor during the historical subject.

Lion's records at the same indices changed type/count and geometry:

```text
image ID  type/count  slot 0        slot 1
0x4e8e    1 / 2       1x31          2x62
0x4e90    3 / 3       10x10         10x10
0x4e89    1 / 2       1x46          2x92
0x4e8a    1 / 2       1x21          2x42
0x4e8d    1 / 2       1x31          2x62
0x4e8f    1 / 2       128x128        256x256
0x4e91    3 / 3       10x9          10x9
```

The previous Lion live constructor trace recorded exactly two raw calls: `256x256` and `2x62`. The static records now identify `256x256` uniquely as `0x4e8f` slot 1, while `2x62` is narrowed to `0x4e8e` or `0x4e8d` slot 1. Type-`3` records can instead enter the ImageIO path in the same Snow-PPC reader.

This is the first concrete release-resource contract mismatch that exactly predicts the observed Lion raw geometry. It is still not authorization to rewrite a record or substitute Snow resource bytes.

## Objective

Run one guarded Snow control and one guarded Lion integration that preserve the accepted compatibility stack while passively recovering the exact legacy frame image ID for:

1. each `CreateImageFromBytes -> CGImageCreate` call at CoreUI return offset `0x0002ad34`;
2. each `CreateImageSource -> CGImageSourceCreateImageAtIndex` call at CoreUI return offset `0x0002afe8`.

The trace does not interpose or patch private CoreUI C++ methods. It interposes only the two external image-construction APIs and uses the already-proven Snow-PPC stack frames to read the caller-saved `r30` value that contains the original legacy image ID:

```text
CreateImageFromBytes caller frame: saved r30 at caller_sp + 0x68
CreateImage/ImageIO caller frame:  saved r30 at caller_sp + 0x60
```

Every recovered value is checked against the exact seven frame IDs. The wrappers preserve all original arguments and return values. The existing exact-six Lion `CGImageCreate bitmapInfo 0x2 -> 0x2002` titlebar adaptation remains unchanged.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-windowframe-shared-art-selection-trace-compat-interposer.c
Git blob f00dac20f8d3fcfd006475d128504e84d0f2c4bf

scripts/build-ppc-coreui-windowframe-shared-art-selection-trace-compat-on-snowleopard.sh
Git blob f9f9d44b465de680a1340d863ca7f3215036d031

scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py
Git blob dfedc046526e555b1b541997989e71ebc572d571
```

Build contract:

```text
compat_build_id=coreui-windowframe-shared-art-selection-trace-compat-v1
interposer_source_git_blob=f00dac20f8d3fcfd006475d128504e84d0f2c4bf
```

The existing accepted runners are unchanged:

```text
scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh
Git blob ccf1494011a9e3306a32c2f094e0c3437f2fa03c

scripts/run-lion-ppc-carbon-gui-coreui-image-bitmapinfo-compat.sh
Git blob 61879224e7a2136c6d26ee8710d3f96e0eb6d1a7
```

## Phase-B build correction

The first Phase-B attempt exposed a Snow Leopard SDK portability issue in the diagnostic source: the tool included `<ImageIO/ImageIO.h>`, but the installed 10.6/Xcode 3.2.6 SDK does not expose that header at that framework include path. No runtime evidence was collected and no compatibility boundary changed.

Current `main` removes that header dependency, declares only the one external ImageIO function signature needed by the passive interposer, and continues linking through the existing `ApplicationServices` umbrella. The diagnostic semantics are unchanged: the same two external constructors are interposed, all arguments/results remain passthrough, and the accepted exact-six bitmap-info adaptation is retained.

## Phase-B declaration correction

The second Phase-B attempt proved that the ApplicationServices umbrella on Snow Leopard already includes `ImageIO.framework/Headers/CGImageSource.h`, even though `<ImageIO/ImageIO.h>` is not available as a top-level include. The temporary manual declaration of `CGImageSourceCreateImageAtIndex` therefore conflicted with the SDK's real declaration.

Current `main` now uses the SDK-provided `CGImageSourceRef` type and `CGImageSourceCreateImageAtIndex` declaration exposed through `<ApplicationServices/ApplicationServices.h>`; no manual function declaration and no direct `<ImageIO/ImageIO.h>` include remain. Diagnostic behavior is unchanged.

## Phase-B assembler correction

The third Phase-B attempt reached C compilation but failed in the Snow Leopard PPC assembler at both invocations of the diagnostic's inline `mr %0,1` stack-pointer read. This was diagnostic-only code; no PPC subject was launched and no runtime evidence changed.

Before committing the correction, the replacement stack-frame primitive was verified independently: the exact `__builtin_frame_address(0)` backchain logic was compiled as GNU89 C on the host and cross-compiled to 32-bit PowerPC objects at both `-O0` and `-O2`. The generated PPC code uses the normal stack frame/backchain and reads the requested `caller_sp+0x68` / `caller_sp+0x60` offsets without any inline assembler. Current `main` therefore removes the hand-written PPC `mr` instruction entirely and uses the compiler frame builtin; no diagnostic selection rule or compatibility behavior changes.

## Safety constraints

- Run only the exact historical PPC Carbon GUI subject already used by the accepted compatibility runners.
- Keep the accepted CoreServices/CGS, notification, exact-six titlebar-key, ShapeWindow, backing-sync, and bitmap-info rules unchanged.
- Do not change any shared-art image ID, type, count, slot, width, height, provider length, provider offset, or pixel bytes.
- Do not copy Snow `SArtFile.bin` or individual Snow records to Lion.
- Do not patch CoreUI or interpose private C++ methods.
- Do not change CGContext state, hit masks, classic part codes, mouse routing, or control actions.
- Do not broaden CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.
- Do not manually click or drag the window during the trace.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-windowframe-shared-art-selection-trace-compat-interposer.c)" = \
  "f00dac20f8d3fcfd006475d128504e84d0f2c4bf" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-windowframe-shared-art-selection-trace-compat-on-snowleopard.sh)" = \
  "f9f9d44b465de680a1340d863ca7f3215036d031" || exit 1

test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py)" = \
  "dfedc046526e555b1b541997989e71ebc572d571" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-windowframe-shared-art-selection-trace-compat-on-snowleopard.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py","rb").read(),"summarize-shared-art-selection.py","exec")' || exit 1
```

## Phase B — build the diagnostic trace+compat artifact on Snow Leopard

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

./scripts/build-ppc-coreui-windowframe-shared-art-selection-trace-compat-on-snowleopard.sh \
  ./payload/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib || exit 1
```

Require the info file to report:

```text
compat_build_id=coreui-windowframe-shared-art-selection-trace-compat-v1
interposer_source_git_blob=f00dac20f8d3fcfd006475d128504e84d0f2c4bf
```

Require a PPC `__DATA,__interpose` section of `0x10` bytes: exactly two PPC tuples, replacing only `CGImageCreate` and `CGImageSourceCreateImageAtIndex`.

## Phase C — Snow control

On Snow Leopard, from the runtime `payload/` directory:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-selection-trace-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="f00dac20f8d3fcfd006475d128504e84d0f2c4bf"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-shared-art-selection-snow.log \
  ./ppc-carbon-gui-shared-art-selection-snow-observer.log || exit 1

/usr/bin/python ../scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py \
  ./ppc-carbon-gui-shared-art-selection-snow.log \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-selection-snow.txt || exit 1
```

Require the accepted Snow runner to remain PASS and the summary to end with:

```text
mode=snow
raw_call_count=5
imageio_call_count=0
shared_art_selection_trace_exact=YES
RESULT: PASS
```

Every raw selection must report `stack_ok=YES frame_target=YES` and 11x11/bpr44 geometry. Record the five recovered frame IDs in order.

## Phase D — transfer only the new diagnostic artifact

Transfer to Lion's runtime `payload/`:

```text
pm-coreui-windowframe-shared-art-selection-trace-compat.dylib
pm-coreui-windowframe-shared-art-selection-trace-compat.dylib.info.txt
pm-coreui-windowframe-shared-art-selection-trace-compat.dylib.sha256
```

Do not transfer or replace any CoreUI resource.

## Phase E — Lion integration

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-selection-trace-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-selection-trace-compat-v1"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="f00dac20f8d3fcfd006475d128504e84d0f2c4bf"

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
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-selection.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-selection-observer.log" || exit 1

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-selection-trace.py \
  ./payload/lion-ppc-carbon-gui-shared-art-selection.log \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-selection-lion.txt || exit 1
```

Require the accepted Lion runner to remain PASS and the summary to end with:

```text
mode=lion
raw_call_count=2
lion_2x62_frame_id=0x....
lion_256x256_frame_id=0x4e8f
shared_art_selection_trace_exact=YES
RESULT: PASS
```

Every raw/ImageIO selection must report `stack_ok=YES frame_target=YES`. Do not require a predetermined Lion ImageIO call count; that is part of the discriminator.

## Review gate

### Lion 2x62 resolves to 0x4e8e or 0x4e8d and the remaining Snow-active IDs move to ImageIO

The release-resource mismatch is fully correlated to exact frame IDs and branch selection. The next step should be a minimal compatibility-design audit comparing only the type/count/slot-selection metadata for those live IDs. Do not copy image bytes or rewrite the whole record.

### Lion 2x62 or 256x256 recovers an unexpected frame ID

Stop. Treat the stack-recovery assumption as disproven and do not adapt any SArtFile metadata.

### Snow recovered IDs do not match the five prior 11x11 calls

Stop. The diagnostic is intrusive or the caller-frame derivation is wrong.

### Lion raw IDs correlate but ImageIO IDs do not account for the Snow-active remainder

Trace only the `CreateImage(long,float)` return/result for the unresolved live IDs before designing compatibility.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-shared-art-selection-snow.txt
ppc-carbon-gui-coreui-windowframe-shared-art-selection-lion.txt
```

Also preserve the underlying Snow/Lion subject logs locally in case a validation line needs expansion. Do not return the dylib binary unless specifically requested.

## Current boundary

```text
SArtFile frame-record audit                      PASS
Snow exact-seven record type/count               all type 2 / count 1
Snow raw slot-0 candidates                       six 11x11 + one 1x23
prior Snow live raw stream                       five 11x11
Lion 0x4e8f slot 1                               256x256 / exact live match
Lion 0x4e8e or 0x4e8d slot 1                     2x62 / remaining ambiguity
resource mismatch                                PROVEN
exact live ID/path correlation                   NOT YET PROVEN
record rewrite                                   NOT AUTHORIZED
next step                                        guarded shared-art selection live trace
XNU                                              no source change indicated
```
