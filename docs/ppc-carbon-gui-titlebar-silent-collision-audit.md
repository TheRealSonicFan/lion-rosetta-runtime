# PPC Carbon GUI titlebar silent semantic-collision audit

## Status

COMPLETED STATIC PASS. The 223-key cross-release inventory finds no same-byte/different-semantic Lion collisions. The next controlled step is the passive live bsearch-key discriminator in `docs/ppc-carbon-gui-titlebar-live-key-trace.md`.

## Reviewed result that advances this step

Both returned payload-fidelity reports pass provenance and local index validation.

Snow Leopard 10.6.8 / 10K549:

```text
required_arch=ppc7400
artfile_sha256=1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5
six_payload_records_exact=YES
RESULT: PASS
```

Lion 10.7.5 / 11G63:

```text
required_arch=i386
artfile_sha256=0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4
six_payload_records_exact=YES
RESULT: PASS
```

The six semantic-equivalent payload records do not show a release-incompatible record layout at the boundary consumed by `CUIElement::LoadFromArtFile`.

For all six records on both releases:

- the first two little-endian 16-bit fields are `1,1`, so the record describes one image cell;
- the first image-data relative offset is `0x68`;
- Snow's first image dimensions are 14x16 and each complete span is exactly `0x68 + 14*16*4 = 1000` bytes;
- Lion's first image dimensions are 16x16 and each complete span is exactly `0x68 + 16*16*4 = 1128` bytes;
- Snow PPC `LoadFromArtFile` explicitly copies `0x68` bytes before decoding the header;
- Lion i386 `LoadFromArtFile` copies `0x1a` 32-bit words, also exactly `0x68` bytes, before decoding the corresponding geometry and image tables.

The release-local consumer implementations are not identical, and the image geometry/content is release-specific, but the audited fixed header plus 32-bit-pixel image-body structure is aligned. This evidence therefore does **not** justify payload substitution, a `memcpy` compatibility interposer, or copying Snow titlebar image bytes into Lion.

The next discriminator follows the payload-audit review gate: inventory every Snow `titlebarcontrols` index key and ask whether the same raw byte key silently resolves to a different semantic record in Lion. Such a collision can produce the wrong image without an `Invalid ArtFile Path` diagnostic and would not be counted by the existing exact-six translator.

## Objective

Perform a static, read-only cross-release inventory of all Snow legacy-ArtFile index records whose decoded first component is `titlebarcontrols`.

The Snow phase records each raw eight-byte key and its release-local semantic path. The Lion phase consumes that Snow text report and classifies every Snow titlebar key against the complete Lion index:

```text
IDENTITY_SAME_SEMANTIC
SILENT_COLLISION
TRANSLATION_REQUIRED
MISSING_EQUIVALENT
UNRESOLVED_COMPONENT
AMBIGUOUS
```

The already-live six mappings are pinned as a positive control and must remain exactly `TRANSLATION_REQUIRED` with their known Lion targets.

This stage does not prove which additional paths are exercised by the current Carbon subject. It only identifies archive-level candidates for a later exact live trace if needed.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py
```

Pinned identity:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-silent-collision-inventory-v1
git_blob=322dce3e56b5473bfc1136faf528a0853d4edf91
```

The analyzer is Python-2-compatible and:

- verifies the accepted Snow or Lion ArtFile identity and index geometry;
- enumerates every Snow record whose decoded first semantic component is `titlebarcontrols`;
- requires the six already-proven Snow source semantics to be present exactly;
- on Lion, verifies the returned Snow report provenance before using it;
- searches the full Lion index for the exact Snow raw key, not merely Lion titlebar entries;
- decodes any exact raw hit through Lion's local component dictionary;
- independently re-encodes the Snow semantic path with Lion component IDs and checks the semantic-equivalent Lion record;
- validates the six known source/target mappings as a positive control;
- reports outside-six silent collisions and outside-six translation candidates without modifying policy.

## Safety constraints

- Do not launch the PPC Carbon subject.
- Do not rerun the backing-sync integration.
- Do not rebuild or replace any compatibility dylib.
- Do not broaden the exact-six bsearch translation.
- Do not add a seventh titlebar key.
- Do not copy Snow CoreUI, `ArtFile.bin`, `SArtFile.bin`, titlebar payload bytes, or UI recipe resources to Lion.
- Do not patch Lion CoreUI or any ArtFile.
- Do not interpose `LoadFromArtFile`, `memcpy`, image-provider calls, or bitmap conversion from this audit alone.
- Do not change ShapeWindow, backing synchronization, WindowBackingInfo, color-profile, notification, CPS, or later CGS compatibility.
- Do not test another PPC application.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py)" = \
  "322dce3e56b5473bfc1136faf528a0853d4edf91" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION="1"$' \
  ./scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT="carbon-gui-titlebar-silent-collision-inventory-v1"$' \
  ./scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py","rb").read(),"audit-ppc-carbon-gui-titlebar-silent-collisions.py","exec")' || exit 1
```

Do not proceed if Phase A fails.

## Phase B — Snow source inventory

On Snow Leopard 10.6.8:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py \
  ./ppc-carbon-gui-titlebar-silent-collisions-snow.txt || exit 1
```

Require:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-silent-collision-inventory-v1
product_version=10.6.8
build_version=10K549
artfile_sha256=1ca5d946725e5815cb4fc34ef45006aab7220ef1f8e89128e65a5754359b4ec5
mode=snow-source-inventory
known_exact_six_source_count=6
duplicate_semantic_path_count=0
RESULT=PASS
RESULT: PASS
```

Do not edit the generated Snow report.

## Phase C — transfer only the Snow text report

Copy exactly this generated text file to the Lion runtime directory:

```text
ppc-carbon-gui-titlebar-silent-collisions-snow.txt
```

No ArtFile, CoreUI binary, dylib, or payload bytes are transferred.

## Phase D — Lion cross-release collision check

On Lion 10.7.5:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-silent-collisions.py \
  ./ppc-carbon-gui-titlebar-silent-collisions-lion.txt \
  ./ppc-carbon-gui-titlebar-silent-collisions-snow.txt || exit 1
```

Require:

```text
analyzer_version=1
audit_contract=carbon-gui-titlebar-silent-collision-inventory-v1
product_version=10.7.5
build_version=11G63
artfile_sha256=0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4
mode=lion-cross-release-collision-check
known_exact_six_translation_count=6
RESULT=PASS
RESULT: PASS
```

Record, but do not act on, these diagnostic counts:

```text
identity_same_semantic_count
silent_collision_count
translation_required_count
missing_equivalent_count
unresolved_component_count
ambiguous_count
outside_six_silent_collision_count
outside_six_translation_required_count
```

## Review gate

Do not change live policy until both reports are reviewed together.

- If `outside_six_silent_collision_count > 0`, the next step is an exact passive bsearch-key trace of the current Carbon subject to determine which collision candidates are actually exercised. Static collision alone does not authorize translation.
- If there are no silent collisions but `outside_six_translation_required_count > 0`, use the same passive live discriminator before adding any mapping; archive presence alone does not prove current execution.
- If both outside-six counts are zero, do not modify titlebar keys. The next discriminator moves away from key translation and toward release-specific rendering/recipe/scale behavior while keeping payload substitution held.
- If either report fails provenance or the known exact-six control changes, fix the analyzer/audit before any live run.

## Observed result — no silent collisions; live usage remains unresolved

The returned Snow report inventories 223 unique `titlebarcontrols` semantic paths and preserves the six known source keys. The Lion cross-release pass classifies all 223 Snow paths without ambiguity:

```text
identity_same_semantic_count=0
silent_collision_count=0
translation_required_count=197
missing_equivalent_count=26
unresolved_component_count=0
ambiguous_count=0
known_exact_six_translation_count=6
outside_six_silent_collision_count=0
outside_six_translation_required_count=191
RESULT=PASS
RESULT: PASS
```

The static result is decisive against the silent-collision hypothesis: no Snow titlebar raw key is a direct Lion index hit with different semantics. It is **not** evidence for adding 191 translations. Those 191 entries are only archive-level semantic equivalents, and current execution has not shown that the historical subject requests any of them.

Proceed only through `docs/ppc-carbon-gui-titlebar-live-key-trace.md`. That phase preserves the existing six live mappings and adds passive logging for validated outside-six titlebar bsearch keys. No mapping is added by the trace artifact.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-titlebar-silent-collisions-snow.txt
ppc-carbon-gui-titlebar-silent-collisions-lion.txt
```

No binaries are required.

## Current boundary

```text
CGSShapeWindow inline adapter                    LIVE-PROVEN PASS
backing-store synchronization adapter            LIVE-PROVEN PASS
Lion exact titled frame                          400x222 at (120,98), onscreen
titlebar exact-six live translations             6 / guard rejects 0
six release-local payload records                STATIC-PROVEN PRESENT
payload fixed-header/image-body structure        STRUCTURALLY COMPATIBLE
Snow titlebar index entries                      223
same-byte Lion semantic collisions               0
outside-six semantic equivalents                 191
outside-six live execution                       UNKNOWN
next step                                        docs/ppc-carbon-gui-titlebar-live-key-trace.md
new titlebar mappings                            NOT AUTHORIZED
payload substitution                             NOT AUTHORIZED
later CGS / LaunchServices / Finder / Cocoa      HELD
XNU                                              no source change indicated
```
