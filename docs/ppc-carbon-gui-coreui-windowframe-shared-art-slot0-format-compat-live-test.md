# PPC Carbon GUI CoreUI window-frame slot-0 format compatibility live test

## Status

COMPLETED RENDERING PASS / KNOWN NOTIFICATION-ORACLE FAIL.

The Snow control passes exactly. On Lion, the v2 adapter executes the proven five shared-art replacements with zero fallback/null results, keeps the three byte-identical mappings at `bitmapInfo=0x2`, and uses `0x2002` only for legacy `0x4e8f` and `0x4e91`. Manual review confirms the titlebar background and both top corners are now fully restored with the Snow Leopard color scheme, and the traffic-light controls remain sharp.

The generic runner's exit 1 is the already-known exact-21 notification-oracle mismatch, not a v2 image-adapter failure: only six registrations are accepted, the prior ColorSync registration 7 is absent, and the old requests 8..21 reappear as requests 7..20. The subject exits zero, the WindowServer observer passes, and protected hashes remain unchanged. This notification deletion remains held as a separate side effect; the broker policy is unchanged.

The rendering defect is therefore closed at the exact-five/exact-two CoreUI boundary. Titlebar dragging still fails and is now the only titlebar defect under investigation. The next controlled step is `docs/ppc-carbon-gui-hitoolbox-titlebar-drag-routing-audit.md`.

The Lion static report passed on the exact 10.7.5 / 11G63 SArtFile and resolves
the remaining corner-format ambiguity narrowly:

```text
0x4e8d -> 0x4e75   exact Snow-byte anchor   alpha byte ambiguous
0x4e8e -> 0x4e76   exact Snow-byte anchor   alpha byte ambiguous
0x4e90 -> 0x4e78   exact Snow-byte anchor   alpha byte ambiguous
0x4e8f -> 0x4e77   changed Lion payload     BYTE3 exact preference
0x4e91 -> 0x4e79   changed Lion payload     BYTE3 exact preference
```

The ambiguity of the three exact-byte anchors is benign rather than evidence
for another format change: those 484-byte payloads are byte-identical to their
healthy Snow sources, and the accepted Snow PPC raw constructor contract for
those bytes is `bitmapInfo=0x00000002`. Preserve that contract.

The two changed Lion payloads are different. Under a byte-0 alpha model each
has zero nonzero-alpha pixels and 120 premultiplication violations; under
byte-3 each has 120 nonzero-alpha pixels, zero violations, and a full 11x11
support. Their byte-3 masks are mirror images: `0x4e8f` fades in from the
upper-left edge and `0x4e91` fades out at the upper-right edge. Together with
their paired final-image use in Snow `CUIRenderer::DrawWindowFrameDark`, this
identifies them as the two top-corner images that remained visually absent in
the first slot-0 integration.

Therefore the next compatibility experiment changes only the replacement
image-construction bitmapInfo for legacy IDs `0x4e8f` and `0x4e91` from
`0x2` to `0x2002`. The other three mapped slot-0 images stay at `0x2`.
The accepted exact-six traffic-light `0x2 -> 0x2002` adapter is unchanged.

## Prepared implementation

Current runtime `main` provides:

```text
tests/ppc-coreui-windowframe-shared-art-slot0-compat-interposer.c
Git blob 4f4792987fded0609efda2a8b4c524bc7069c7fd
build ID coreui-windowframe-shared-art-slot0-compat-v2

scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh
Git blob 7c73c3c216bdaaade8bc2958aaed5b0e220bba87

scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py
Git blob 59bfb6af1db8e0a9cd77fcbde9e9f6ec71823011
```

The v2 interposer additionally emits one explicit format marker for each
replacement:

```text
PM_COREUI_SHARED_ART_SLOT0_FORMAT:legacy_id=... lion_id=... bitmapInfo=...
```

Required Lion format set:

```text
0x4e8d -> 0x4e75   0x00000002
0x4e8e -> 0x4e76   0x00000002
0x4e90 -> 0x4e78   0x00000002
0x4e8f -> 0x4e77   0x00002002
0x4e91 -> 0x4e79   0x00002002
```

No mapping, provider byte, geometry, source index, resource, private CoreUI
method, CGContext state, hit behavior, CGS rule, notification broker, or XNU
code is changed.

## Notification oracle

The prior Lion run failed the generic exact-21 runner because one previously
accepted registration disappeared:

```text
prior request 7 / com.apple.ColorSync.DisplayProfileNotification absent
prior requests 8..21 shifted to current requests 7..20
```

Do not modify the exact-21 broker for this experiment. The dedicated v2
summarizer treats that one already-proven sequence deletion as a known oracle
state, not as an accepted policy. Any other runner failure remains fatal.

## Safety constraints

- Keep the exact-five shared-art mapping unchanged.
- Keep the three exact Snow-byte anchors at `bitmapInfo=0x2`.
- Use `0x2002` only for mapped legacy IDs `0x4e8f` and `0x4e91`.
- Keep the exact-six traffic-light bitmap-info rule unchanged.
- Do not alter SArtFile, ArtFile, ArtFile200, CoreUI, HIToolbox, or Rosetta
  cache bytes.
- Do not interpose private C++ CoreUI methods.
- Do not change the distributed-notification broker or its accepted sequence.
- Do not change hit masks, part codes, mouse routing, actions, CGS policy, or
  XNU.
- Do not click or drag the titlebar during this rendering run.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./tests/ppc-coreui-windowframe-shared-art-slot0-compat-interposer.c)" = \
  "4f4792987fded0609efda2a8b4c524bc7069c7fd" || exit 1

test "$(git hash-object ./scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh)" = \
  "7c73c3c216bdaaade8bc2958aaed5b0e220bba87" || exit 1

test "$(git hash-object ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py)" = \
  "59bfb6af1db8e0a9cd77fcbde9e9f6ec71823011" || exit 1

/bin/bash -n ./scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh || exit 1
/usr/bin/python -c 'compile(open("./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py","rb").read(),"slot0-format-summary.py","exec")' || exit 1
```

## Phase B — build v2 on Snow Leopard

```sh
cd /path/to/lion-rosetta-runtime || exit 1
mkdir -p ./payload || exit 1

/bin/bash ./scripts/build-ppc-coreui-windowframe-shared-art-slot0-compat-on-snowleopard.sh \
  ./payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib || exit 1
```

Require the info report to contain:

```text
compat_build_id=coreui-windowframe-shared-art-slot0-compat-v2
interposer_source_git_blob=4f4792987fded0609efda2a8b4c524bc7069c7fd
```

If compilation fails, stop and return the build transcript.

## Phase C — Snow passthrough control

On Snow Leopard:

```sh
cd /path/to/lion-rosetta-runtime/payload || exit 1

export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v2"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="4f4792987fded0609efda2a8b4c524bc7069c7fd"

../scripts/run-snowleopard-ppc-carbon-gui-coreui-image-bitmapinfo-compat-control.sh \
  ./ppc-carbon-gui-smoketest-private-dyld \
  ./ppc-carbon-gui-smoketest-private-dyld.sha256 \
  ./pm-carbon-gui-backing-sync-compat.dylib \
  ./pm-carbon-gui-backing-sync-compat.dylib.sha256 \
  ./cgwindowlist-pid-observer \
  ./cgwindowlist-pid-observer.sha256 \
  ./ppc-carbon-gui-shared-art-slot0-format-compat-snow.log \
  ./ppc-carbon-gui-shared-art-slot0-format-compat-snow-observer.log || exit 1

/usr/bin/python ../scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py \
  ./ppc-carbon-gui-shared-art-slot0-format-compat-snow.log \
  ../ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat-snow.txt || exit 1
```

Require:

```text
mode=snow
runner_result_pass=YES
known_notification_shift=NO
image_bitmapinfo_exact_call_count=6
image_bitmapinfo_passthrough_count=6
snow_raw_passthrough_count=5
source_bind_count=0
adapter_call_count=0
adapter_result_count=0
shared_art_slot0_format_compat_exact=YES
RESULT: PASS
```

Manual Snow gate:

```text
Snow titlebar/window frame visually normal: YES
```

Do not proceed if Snow changes.

## Phase D — transfer only the rebuilt v2 artifact

Transfer exactly:

```text
pm-coreui-windowframe-shared-art-slot0-compat.dylib
pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt
pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256
```

to Lion's runtime `payload/`.

## Phase E — Lion resource preflight

```sh
SART="/System/Library/PrivateFrameworks/CoreUI.framework/Versions/A/Resources/SArtFile.bin"

test "$(/usr/bin/stat -f '%z' "$SART")" = "9370228" || exit 1
test "$(/usr/bin/shasum -a 256 "$SART" | /usr/bin/awk '{print $1}')" = \
  "29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b" || exit 1
```

## Phase F — one Lion format-correction integration

The generic runner may exit 1 solely because the known ColorSync registration
is still absent. Do not stop on exit 1 until the dedicated summarizer has
classified the run.

```sh
cd /path/to/lion-rosetta-runtime || exit 1

export ROSETTA_EXPECTED_KERNEL_SHA256=fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_PATH="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_SHA256_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.sha256"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_INFO_FILE="$PWD/payload/pm-coreui-windowframe-shared-art-slot0-compat.dylib.info.txt"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_BUILD_ID="coreui-windowframe-shared-art-slot0-compat-v2"
export ROSETTA_COREUI_IMAGE_BITMAPINFO_COMPAT_EXPECTED_SOURCE_BLOB="4f4792987fded0609efda2a8b4c524bc7069c7fd"

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
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-slot0-format-compat.log" \
  "$PWD/payload/cgwindowlist-pid-observer" \
  "$PWD/payload/cgwindowlist-pid-observer.sha256" \
  "$PWD/payload/lion-ppc-carbon-gui-shared-art-slot0-format-compat-observer.log"
RUN_RC=$?

if [ "$RUN_RC" -ne 0 ] && [ "$RUN_RC" -ne 1 ]; then
  echo "unexpected Lion runner exit: $RUN_RC" >&2
  exit "$RUN_RC"
fi

/usr/bin/python ./scripts/summarize-ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat.py \
  ./payload/lion-ppc-carbon-gui-shared-art-slot0-format-compat.log \
  ./ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat-lion.txt || exit 1
```

Require:

```text
mode=lion
image_bitmapinfo_exact_call_count=6
image_bitmapinfo_adapted_count=6
source_bind_count=3
adapter_call_count=5
adapter_result_count=5
slot0_fallback_count=0
adapter_null_count=0
format_0x2_ids=0x4e8e,0x4e90,0x4e8d
format_0x2002_ids=0x4e8f,0x4e91
shared_art_slot0_format_compat_exact=YES
RESULT: PASS
```

The exact format-ID order in the summary reflects live construction order;
the required set is three `0x2` IDs `0x4e8d,0x4e8e,0x4e90` and two
`0x2002` IDs `0x4e8f,0x4e91`.

The notification oracle must be exactly one of:

```text
runner_result_pass=YES
known_notification_shift=NO
```

or:

```text
runner_result_pass=NO
known_notification_shift=YES
request_7_to_20_payloads=269,269,271,277,273,277,273,286,283,272,275,273,274,257
request_21_present=NO
```

Any other runner failure is a hard stop.

Manual Lion rendering gate, still without clicking or dragging:

```text
Lion titlebar/window-frame background restored: YES/NO/PARTIAL
Lion top-left corner restored: YES/NO
Lion top-right corner restored: YES/NO
Lion traffic-light controls remain visually sharp: YES/NO
```

## Review gate

### Both top corners restored

The frame-rendering defect is closed at the exact-five shared-art boundary:
three byte-identical Snow-format slot-0 images remain `0x2`, and the two
Lion-native corner payloads require `0x2002`. Retain this exact contract.
The next rendering-independent investigation may return to the still-failing
titlebar interaction path using passive event/action-routing evidence; do not
rewrite classic hit part codes.

If the known notification deletion persists, keep it as a separate user-space
side effect to diagnose after the visual frame contract is closed. Do not
silently redefine the exact-21 policy.

### Only one corner is restored

Stop. Return both summaries and the manual observations. Do not broaden the
bitmap rule; inspect the remaining corner's renderer placement/alignment.

### Neither corner is restored

The alpha-layout diagnosis is necessary but not sufficient. Preserve the
format result and move to exact renderer placement/alignment for
`0x4e8f/0x4e91`; do not alter other frame images.

### Dedicated summary fails

Stop and return the summary plus raw Lion log. No further adaptation is
authorized.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat-snow.txt
ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat-lion.txt
```

plus the four manual Lion rendering observations above.

## Current boundary

```text
mapped slot0 pixel-format static audit            PASS
three exact Snow-byte anchors                     alpha layout ambiguous / retain healthy Snow 0x2
0x4e8f -> 0x4e77                                 BYTE3 / mirrored left-corner mask
0x4e91 -> 0x4e79                                 BYTE3 / mirrored right-corner mask
first slot0 live test                             background restored / corners missing
v2 compatibility change                          exact-two slot0 bitmapInfo 0x2 -> 0x2002
exact-six traffic-light bitmap adapter            unchanged
exact-five resource mapping                       unchanged
notification broker                               unchanged
known notification sequence deletion              observed / not accepted as policy
interaction defect                                held separately
next step                                         static HIToolbox titlebar drag-routing audit
XNU                                               no source change indicated
```
