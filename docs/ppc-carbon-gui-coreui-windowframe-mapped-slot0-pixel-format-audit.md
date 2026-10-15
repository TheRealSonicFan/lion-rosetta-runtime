# PPC Carbon GUI CoreUI window-frame mapped slot-0 pixel-format audit

## Status

COMPLETED STATIC PASS.

The returned Lion report pins the exact 10.7.5 / 11G63 SArtFile and passes the audit contract. The three byte-identical Snow anchors (legacy `0x4e8d`, `0x4e8e`, `0x4e90`) are alpha-layout ambiguous because byte 0 and byte 3 produce identical masks and zero violations; this does not justify changing their healthy Snow `bitmapInfo=0x2` contract. The two changed Lion payloads (legacy `0x4e8f` and `0x4e91`) are decisive: byte-0 interpretation yields zero nonzero-alpha pixels with 120 violations, while byte-3 yields 120 nonzero-alpha pixels with zero violations. Their byte-3 masks are mirrored upper-left/upper-right corner shapes.

The downstream Snow renderer already loads `0x4e8f` and `0x4e91` as the paired final frame images before the frame draw. Combined with the first live test's exact symptom—background restored but both top corners absent—the format evidence is sufficient for one exact-two construction correction. Current `main` advances to `docs/ppc-carbon-gui-coreui-windowframe-shared-art-slot0-format-compat-live-test.md`; do not broaden the change to the other three mapped images or to notification policy.

The Snow passthrough control passed exactly. The Lion run did not satisfy the
full-stack runner because the dedicated exact-21 distributed-notification
broker accepted only the first six registrations, then rejected fourteen
requests as state mismatches. The slot-0 adapter itself did **not** fail:
all five target substitutions reported `ADAPTER_PASS`, all three ImageIO
source bindings were established, all six accepted titlebar bitmap-info
adaptations passed, the subject exited zero, and the WindowServer observer
saw the 400x222 window onscreen.

The notification sequence is not random corruption. Comparing the failed run
with the immediately preceding accepted Lion bitmap-info baseline gives:

```text
accepted baseline request 7: size 308 / payload 276
    -> exact registration 7 / allowed 5
    -> com.apple.ColorSync.DisplayProfileNotification

slot0 run request 7: size 304 / payload 269
    -> byte-for-byte sequence position/geometry of prior request 8

slot0 run requests 7..20:
    -> same payload-length sequence as accepted baseline requests 8..21
```

Thus exactly one previously accepted registration disappears and every later
registration shifts left by one. Do **not** broaden the global exact-21 broker
or declare an exact-20 replacement policy yet; the missing ColorSync
registration may be a causal side effect of replacing ImageIO-created frame
images with raw slot-0 images.

The manual rendering result is independently useful: the titlebar background
is restored and opaque with the Snow-era appearance, but the top-left and
top-right corners remain absent. Titlebar dragging remains nonfunctional and
continues to be treated as a separate interaction defect.

The next question is whether the two Lion slot-0 payloads whose bytes changed
across releases (`0x4e77` and `0x4e79`, mapped from legacy `0x4e8f` and
`0x4e91`) use a different 32-bit channel/alpha layout than the three exact
Snow-byte anchors. The current adapter constructs all five with raw
`bitmapInfo=0x00000002`; a release-specific alpha-byte split would directly
explain why only the corner-like portions remain transparent.

## Objective

Run one Lion-only, read-only SArtFile pixel-format audit. It must:

- pin exact Lion 10.7.5 / 11G63 `SArtFile.bin`;
- revalidate the exact five mapped records and slot-0 provider offsets;
- hash all five 11x11 / 484-byte slot-0 payloads;
- preserve the three exact Snow-byte anchors as fixed controls;
- score each payload under alpha-byte-0 and alpha-byte-3 premultiplied models;
- emit nonzero-alpha bounding boxes and compact 11x11 alpha masks for both
  candidate layouts;
- modify nothing and launch no PPC code.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format.py
Git blob b0cd902e302c517ae192f1b9b3cf38157000807a
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-v1
```

## Safety constraints

- Lion static-only; do not launch the PPC subject.
- Do not rerun the failed slot-0 integration for this step.
- Do not change the exact-five mapping.
- Do not change per-ID bitmapInfo yet.
- Do not add an exact-20 notification broker yet.
- Do not modify SArtFile, ArtFile, ArtFile200, CoreUI, HIToolbox, Rosetta
  cache, CGContext state, hit masks, part codes, mouse routing, CGS policy,
  or XNU.

## Phase A — update and pin

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format.py)" = \
  "b0cd902e302c517ae192f1b9b3cf38157000807a" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format.py","rb").read(),"mapped-slot0-pixel-format.py","exec")' || exit 1
```

## Phase B — Lion static report

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format.py \
  ./ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=348
sartfile_data_region_base=0x3ff0
mapped_slot0_pixel_format_audit_exact=YES
RESULT: PASS
```

## Review gate

### The three exact-byte anchors prefer BYTE0 and 0x4e77 / 0x4e79 prefer BYTE3

The missing-corner result has a concrete format explanation. Prepare a new
guarded adapter revision that retains `0x2` only for the three Snow-byte
anchors and uses the proven Lion byte-order contract for the two changed
payloads. Do not combine that change with notification-policy changes; first
re-run Snow passthrough and one Lion rendering integration while recording the
same notification sequence.

### All five prefer BYTE0

The current per-image bitmapInfo is not the corner cause. Hold the adapter and
move to a static renderer-role/alignment audit for the two changed-pixel
records before another live run.

### All five prefer BYTE3

The current slot-0 construction contract is globally wrong. Do not patch only
the corners; prepare a complete exact-five image-format correction after
reviewing the three exact-byte anchors against their healthy Snow semantics.

### Any target is ambiguous

Do not guess from the screenshot. Return the report and inspect the emitted
alpha masks plus downstream renderer role/alignment before changing the
adapter.

## Notification side-effect gate

The exact-21 failure is held separately from the corner-format decision. The
failed Lion run proves a precise sequence deletion:

```text
prior request 7 / ColorSync.DisplayProfileNotification missing
prior requests 8..21 shifted to current requests 7..20
```

No notification policy change is authorized until the image-format result is
known and the next live adapter revision confirms whether that deletion
persists.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-mapped-slot0-pixel-format-lion.txt
```

## Current boundary

```text
Snow slot0 passthrough                           PASS
Lion slot0 replacement calls                     5 / all ADAPTER_PASS
Lion ImageIO source bindings                     3 / all BOUND
Lion exact-six bitmap adapter                    6 / all PASS
Lion frame background                            RESTORED / partial visual success
Lion top-left/top-right corners                  MISSING
Lion titlebar dragging                           STILL FAILS / separate interaction defect
Lion exact-21 runner                             FAIL
notification delta                               exact registration 7 absent; prior 8..21 shifted
global notification-policy change                NOT AUTHORIZED
current all-five slot0 bitmapInfo                 0x00000002
next step                                        exact-two slot0 format compatibility live test
XNU                                              no source change indicated
```
