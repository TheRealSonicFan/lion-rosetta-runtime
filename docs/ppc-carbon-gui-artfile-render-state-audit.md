# PPC Carbon GUI ArtFile render-state and image-format audit

## Status

COMPLETED STATIC PASS. Snow's six exact bodies consistently favor BYTE0 alpha while Lion's six consistently favor BYTE3; the release-local image-constructor contracts also differ exactly at byte-order semantics. The next controlled step is `docs/ppc-carbon-gui-coreui-image-constructor-live-trace.md`.

## Reviewed result that advances this step

Both returned field-contract reports pass.

Snow Leopard 10.6.8 / 10K549 proves the pinned Snow PPC `CUIElement::LoadFromArtFile` contract and decodes all six exact titlebar-control records as valid one-cell records:

```text
snow_loader_instruction_contract=PASS
header_copy_length=0x68
direct_halfword_0x1e_observed=NO
exact_six_old_loader_record_count=6
exact_six_old_loader_cell_contract_count=6
old_loader_field_contract_exact=YES
RESULT: PASS
```

All six Snow records share the same directly consumed metric vector:

```text
metric_s16_0x04_to_0x1c=
0,2,14,14, 0,2,14,14, 0,2,14,14, 2
```

and each image body is located exactly by:

```text
body offset = 0x68
width       = 14
height      = 16
body bytes  = 896
record span = 1000
```

Lion 10.7.5 / 11G63 proves that the historical process still uses the accepted Snow-era PPC loader from `dyld_shared_cache_rosetta`, while all six semantic-equivalent Lion ArtFile10 records remain structurally valid under that old loader:

```text
runtime_ppc_loader_contract=accepted_identical_snow_ppc_cache
exact_six_old_loader_record_count=6
exact_six_old_loader_cell_contract_count=6
old_loader_field_contract_exact=YES
RESULT: PASS
```

All six Lion records share this directly consumed metric vector:

```text
metric_s16_0x04_to_0x1c=
2,2,13,14, 1,2,14,14, 1,2,14,14, 2
```

and each image body is located exactly by:

```text
body offset = 0x68
width       = 16
height      = 16
body bytes  = 1024
record span = 1128
```

The release delta is therefore confined to directly consumed render metrics and the release-local image geometry; it is **not** a broken body offset, width/height-array layout, cell count, record length, or use of the unconsumed `0x1e` halfword.

The earlier rendering-contract disassembly also exposes a more specific discriminator that must be resolved before changing those metrics. The Snow PPC loader writes the thirteen metric halfwords into three consecutive four-float regions plus one scalar in `CUIElement`, and its image-construction path can reach `CGImageCreate` with default-byte-order bitmap-info values `0x2` or `0x4`, with a conditional `CWMatchBitmap` path. Lion native CoreUI writes the same thirteen serialized metric positions into the same three-region-plus-scalar object layout, but constructs the ArtFile image with bitmap-info `0x2002` (32-bit little-endian plus alpha-first semantics).

That means the metric layout itself may be semantically stable while the raw 32-bit image-body byte order is release-specific. A field rewrite would be premature until the raw body layout and image-constructor contracts are compared directly.

## Objective

Perform one read-only Snow report and one read-only Lion report that answer two questions:

1. Do the release-local loaders map the thirteen serialized metric values into the same logical `CUIElement` state layout?
2. Does the raw exact-six image body have a release-specific alpha-byte position consistent with the different `CGImageCreate` bitmap-info contracts?

The analyzer does **not** render, launch, attach, patch, interpose, or mutate anything.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py
Git blob ee073d8f8ffa9713a53e1f73dfbee0a53bfa873f
```

Analyzer contract:

```text
analyzer_version=1
audit_contract=carbon-gui-artfile-render-state-contract-v1
```

The analyzer verifies the accepted release-local CoreUI slice and ArtFile identities, then checks the exact static instruction contract.

### Snow PPC consumer

The pinned PPC loader maps the already-proven serialized metric offsets as:

```text
header 0x04,0x06,0x08,0x0a -> CUIElement +0x10,+0x14,+0x18,+0x1c
header 0x0c,0x0e,0x10,0x12 -> CUIElement +0x20,+0x24,+0x28,+0x2c
header 0x14,0x16,0x18,0x1a -> CUIElement +0x30,+0x34,+0x38,+0x3c
header 0x1c                -> CUIElement +0x40
```

It also verifies the image construction boundary:

```text
bits/component                 8
bits/pixel                     32
provider path                  Direct or WithData
bitmapInfo after Direct        0x00000004
bitmapInfo after WithData      0x00000002
byte-order mask                default
CWMatchBitmap branch           present
CWMatchBitmap tag              0x1881
```

### Lion native consumer

Lion native `LoadFromArtFile` copies the same `0x68` header and stores the thirteen metric positions into the same `CUIElement` destinations. For the current positive exact-six values, its unsigned 16-bit-to-float conversion is numerically identical to Snow's signed conversion.

Its ArtFile image constructor is different:

```text
bits/component                 8
bits/pixel                     32
provider path                  WithData
bitmapInfo                     0x00002002
byte-order mask                32_LITTLE
CWMatchBitmap branch           absent
```

### Raw body diagnostics

For each exact-six image body the analyzer evaluates two **diagnostic models** without modifying bytes:

```text
BYTE0 model: byte 0 is alpha; bytes 1..3 are color
BYTE3 model: byte 3 is alpha; bytes 0..2 are color
```

For each model it reports:

```text
premul violation count
zero-alpha pixels with nonzero color
nonzero-alpha pixel count
opaque-alpha pixel count
```

and chooses the lower-error diagnostic alpha position, or `AMBIGUOUS` on a tie.

This is not a renderer and does not claim a color-space interpretation. It is only a discriminator for whether the raw 32-bit resource bodies move the alpha byte between releases in the way suggested by the static constructor contracts.

## Safety constraints

- Do not launch the PPC Carbon subject.
- Do not rerun the all-ArtFile live trace.
- Do not build or load a compatibility dylib.
- Do not change the exact-six mapping table.
- Do not rewrite any `0x68` metric field.
- Do not rewrite, byte-swap, or copy any image body.
- Do not substitute Snow resources or recipes.
- Do not force ArtFile200 or another scale factor.
- Do not interpose `CGImageCreate`, `CWMatchBitmap`, `LoadFromArtFile`, `memcpy`, renderer routines, or CoreGraphics at this stage.
- Do not change CGS, WindowServer, LaunchServices, Cocoa, or XNU.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py)" = \
  "ee073d8f8ffa9713a53e1f73dfbee0a53bfa873f" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-artfile-render-state-contract-v1"$' \
  ./scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py","rb").read(),"audit-ppc-carbon-gui-artfile-render-state-contract.py","exec")' || exit 1
```

Do not proceed if Phase A fails.

## Phase B — Snow static render-state/image-format report

On Snow Leopard 10.6.8 / 10K549:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py \
  ./ppc-carbon-gui-artfile-render-state-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
coreui_required_arch=ppc7400
coreui_instruction_contract=PASS
metric_layout_grouping_shared=YES
image_constructor_bitmapinfo_values=0x00000004|0x00000002
image_constructor_byte_order_mask=DEFAULT
image_constructor_matchbitmap_branch=PRESENT
render_state_image_contract_exact=YES
RESULT: PASS
```

Record the six `raw_body_preferred_alpha_byte` values and the final counts:

```text
preferred_alpha_byte0_count
preferred_alpha_byte3_count
preferred_alpha_ambiguous_count
```

## Phase C — Lion static render-state/image-format report

On Lion 10.7.5 / 11G63:

```sh
cd /path/to/lion-rosetta-runtime || exit 1

/usr/bin/python ./scripts/audit-ppc-carbon-gui-artfile-render-state-contract.py \
  ./ppc-carbon-gui-artfile-render-state-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
coreui_required_arch=i386
coreui_instruction_contract=PASS
metric_layout_grouping_shared=YES
image_constructor_bitmapinfo_values=0x00002002
image_constructor_byte_order_mask=32_LITTLE
image_constructor_matchbitmap_branch=ABSENT
render_state_image_contract_exact=YES
RESULT: PASS
```

Again record the six preferred-alpha results and final counts.

## Review gate

### Snow favors BYTE0 and Lion favors BYTE3

This is the strongest current candidate for the control distortion: the raw resource channel layout is release-specific while the historical PPC subject executes the Snow-era image-construction path against Lion's ArtFile10 body.

Do **not** rewrite the ArtFile or patch pixel bytes yet. The next controlled live step must only trace the actual old-PPC CoreUI image-construction branch on Snow and Lion: whether `CWMatchBitmap` executes for the exact-six bodies and which `CGImageCreate bitmapInfo` reaches CoreGraphics. That live trace must be passive.

### Alpha position is not release-specific

Close raw body byte order as the immediate explanation. Return to the three directly consumed rectangle deltas and trace their downstream renderer use before authorizing a metric-field adapter.

### Either static instruction contract fails

Stop. Preserve the report and treat the analyzer as stale for that release.

## Observed result — raw channel layout is release-specific

Both reports pass their identity, instruction-contract, metric-layout, and raw-body validation gates.

Snow Leopard:

```text
coreui_instruction_contract=PASS
metric_layout_grouping_shared=YES
image_constructor_bitmapinfo_values=0x00000004|0x00000002
image_constructor_byte_order_mask=DEFAULT
image_constructor_matchbitmap_branch=PRESENT
preferred_alpha_byte0_count=6
preferred_alpha_byte3_count=0
preferred_alpha_ambiguous_count=0
render_state_image_contract_exact=YES
RESULT: PASS
```

Lion:

```text
coreui_instruction_contract=PASS
metric_layout_grouping_shared=YES
image_constructor_bitmapinfo_values=0x00002002
image_constructor_byte_order_mask=32_LITTLE
image_constructor_matchbitmap_branch=ABSENT
preferred_alpha_byte0_count=0
preferred_alpha_byte3_count=6
preferred_alpha_ambiguous_count=0
render_state_image_contract_exact=YES
RESULT: PASS
```

The metric layout is not the immediate discriminator: both release-local loaders map the same thirteen serialized positions into the same three four-float regions plus one scalar. The raw image bodies are, however, unambiguously release-specific under the diagnostic models: all six Snow bodies fit byte-0 alpha with zero premultiplication violations, while all six Lion bodies fit byte-3 alpha with zero violations.

This aligns with the static constructor split: Snow PPC uses default byte order with bitmap-info `0x2` or `0x4` and has a conditional `CWMatchBitmap` path; Lion native CoreUI uses `0x2002`, explicitly selecting the little-endian 32-bit interpretation appropriate to the Lion bodies.

That is not yet permission to change pixels or metrics. The historical Lion process executes the cached Snow PPC CoreUI path, so the next controlled discriminator is the actual live PPC constructor behavior. Follow `docs/ppc-carbon-gui-coreui-image-constructor-live-trace.md`: one Snow passive control, then one Lion passive trace, recording only the exact CoreUI `CGImageCreate` bitmap-info value and whether `CWMatchBitmap` executes.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-artfile-render-state-snow.txt
ppc-carbon-gui-artfile-render-state-lion.txt
```

No binary or live log is required.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
validated ArtFile live set                       exact six only
outside-six ArtFile lookups                      0
ArtFile lookup misses                            0
old PPC record body/size contract                PASS on Snow and Lion
field 0x1e                                       copied but not directly consumed
Snow exact-six metrics                           0,2,14,14 / 0,2,14,14 / 0,2,14,14 / 2
Lion exact-six metrics                           2,2,13,14 / 1,2,14,14 / 1,2,14,14 / 2
metric/header rewrite                            NOT AUTHORIZED
raw image byte-order contract                    RELEASE-SPECIFIC STATIC PROOF
Snow exact-six alpha diagnostic                  BYTE0 for 6/6
Lion exact-six alpha diagnostic                  BYTE3 for 6/6
Snow PPC constructor                             0x2|0x4 / default byte order / CWMatch branch
Lion native constructor                          0x2002 / 32-bit little endian / no CWMatch branch
next step                                        docs/ppc-carbon-gui-coreui-image-constructor-live-trace.md
metric/header/pixel rewrite                      NOT AUTHORIZED
new mappings                                     NOT AUTHORIZED
payload/resource substitution                    NOT AUTHORIZED
ArtFile200 forcing                               NOT AUTHORIZED
XNU                                              no source change indicated
```
