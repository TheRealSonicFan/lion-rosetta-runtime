# PPC Carbon GUI CoreUI window-frame Lion legacy payload provenance audit

## Status

COMPLETED STATIC PASS. The Lion provenance audit confirms exactly three byte-for-byte SArtFile relocations and finds no exact Snow `0x4e8f` or `0x4e91` payload in SArtFile, ArtFile10, or ArtFile20. The next controlled step is `docs/ppc-carbon-gui-coreui-windowframe-frame-id-relocation-audit.md`.

The returned Snow report identifies five exact 484-byte frame payload fingerprints. Comparing those hashes with Lion's complete 11x11/484-byte SArtFile candidate inventory produces three exact byte-for-byte relocations:

```text
Snow 0x4e8d -> Lion SArtFile 0x4e75
Snow 0x4e8e -> Lion SArtFile 0x4e76
Snow 0x4e90 -> Lion SArtFile 0x4e78
```

The corresponding SHA-256 values are identical across releases:

```text
0x4e8d / 0x4e75  9577c7876e34e40a778511795c7a28702af3613dca28b5edeac5f6972ff9912e
0x4e8e / 0x4e76  44897e71f9f949fa7b276adc71a2d58c02ebaab80721ac0035d113fd9f37288f
0x4e90 / 0x4e78  ba825c44fbcb9a52febacfdd60c29383b3a9fb83d3740789f434e28b1cbf1cd7
```

No 11x11/484-byte Lion SArtFile candidate matched the remaining Snow payloads:

```text
Snow 0x4e8f  9f7b4499af15c5d4f3156650ff12c3042d084e49cee2ef911b3ba72183d912fa
Snow 0x4e91  b7f2dd24cc33a63a3b8a05f629f4289f0eaa130a7cc61b2dbc56d45c767d5385
```

This proves that Lion did not simply delete all five legacy frame assets: at least three survive byte-for-byte under different shared-art IDs. It does not yet authorize mapping those IDs, because their Lion-side consumers and the provenance of the remaining two assets must be resolved first.

## Objective

On Lion only, perform one read-only provenance audit across all three exact CoreUI resource archives:

```text
SArtFile.bin
ArtFile.bin
ArtFile200.bin
```

The analyzer embeds only the five Snow SHA-256 fingerprints, never Snow image bytes.

For SArtFile it:

- pins the exact Lion archive identity;
- uses the corrected `+0x08` offset table and the archive data-region base;
- hashes every valid 484-byte provider slot, regardless of geometry;
- verifies the three already observed SArtFile relocations;
- verifies that `0x4e8f` and `0x4e91` still have no exact-byte SArtFile match.

For ArtFile10 and ArtFile20 it:

- pins both exact Lion archive identities;
- parses the archive index and payload spans;
- applies the already-proven old Snow-PPC ArtFile cell contract:
  - record header length `0x68`;
  - cell data-offset array at `0x20`;
  - width array at `0x44`;
  - height array at `0x56`;
- hashes every structurally valid 484-byte cell body;
- reports any exact match to any of the five Snow fingerprints, with archive, record index, cell index, geometry, and payload offset.

This is an exact-byte provenance audit only. It does not claim that an unmatched compressed or differently encoded image is semantically absent.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.py
Git blob e63dfa796b64bf6d01e52ec31338c29ddfb05ba3
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-lion-legacy-payload-provenance-v1
```

Pinned Lion resource identities:

```text
SArtFile.bin
size 9370228
29f9fdb1b8ed8f7f2d25fd331002e0cb362709f74d1c689a9d776b231f1d492b

ArtFile.bin
size 4765184
0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4

ArtFile200.bin
size 18101720
463bdec2bb3a3f66d35bc85e80129b8e0ea85e474e8725b093d747ffa687614f
```

## Safety constraints

- Lion static-only; do not launch the PPC subject.
- Do not rerun the shared-art live trace.
- Do not transfer Snow SArtFile, ArtFile, ArtFile200, records, or image bytes to Lion.
- Do not add an image-ID mapping based on the three exact SArtFile matches yet.
- Do not modify any resource archive, CoreUI, HIToolbox, Rosetta cache, CGContext state, hit masks, part codes, mouse routing, or CGS policy.
- Retain the exact-six titlebar semantic-key translation and exact-six bitmap-info adapter unchanged.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.py)" = \
  "e63dfa796b64bf6d01e52ec31338c29ddfb05ba3" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-lion-legacy-payload-provenance-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.py","rb").read(),"audit-lion-legacy-payload-provenance.py","exec")' || exit 1
```

## Phase B — Lion provenance report

On Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.py \
  ./ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
SArtFile_exact=YES
ArtFile10_exact=YES
ArtFile20_exact=YES
lion_legacy_payload_provenance_audit_exact=YES
RESULT: PASS
```

The SArtFile section must contain exactly the three already established relocations:

```text
source_id=0x4e8d -> lion_image_id=0x4e75
source_id=0x4e8e -> lion_image_id=0x4e76
source_id=0x4e90 -> lion_image_id=0x4e78
```

and no SArtFile exact-byte match for Snow `0x4e8f` or `0x4e91`.

## Review gate

### The two unmatched Snow hashes appear in ArtFile10 and/or ArtFile20

Their byte-for-byte payloads survive elsewhere in Lion CoreUI resources. The next step is a static consumer/semantic audit of the exact matched records together with the three SArtFile relocations; only after that should an exact legacy-ID compatibility rule be designed.

### The two unmatched Snow hashes do not appear in either ArtFile archive

The exact raw bytes for those two assets are absent from all three Lion CoreUI archives under the parsed raw-cell/provider contracts. The next step is then a narrowly scoped semantic/image-equivalence audit for the two unmatched type-3 Lion records, not a pixel transplant.

### One unmatched hash survives and one does not

Split the next step: map/consumer-audit the surviving four exact assets and perform semantic/image-equivalence analysis only for the remaining unmatched asset.

### The three established SArtFile relocations fail to reproduce

Stop. Revisit the provider-range or fingerprint interpretation before any compatibility design.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance.txt
```

## Observed result

The report passes with all three Lion archives pinned exactly. The only exact-byte matches are:

```text
Snow 0x4e8d -> Lion SArtFile 0x4e75
Snow 0x4e8e -> Lion SArtFile 0x4e76
Snow 0x4e90 -> Lion SArtFile 0x4e78
```

ArtFile10 contains 23 structurally valid 484-byte old-loader cells and ArtFile20 contains none, but neither archive contains any of the five Snow target fingerprints. Snow `0x4e8f` and `0x4e91` therefore have no exact raw-byte match under the audited SArtFile/provider and ArtFile cell contracts.

This does not imply those two semantic assets disappeared: the pinned native Lion renderer report uses the contiguous shared-art ID set `0x4e75..0x4e79` in the same renderer-role order as Snow's active `0x4e8d..0x4e91` set, with the three exact-byte matches acting as independent anchors. Follow `docs/ppc-carbon-gui-coreui-windowframe-frame-id-relocation-audit.md` next to reproduce that mapping and inspect both Lion record slots before any live remap is built.

## Current boundary

```text
Lion legacy-payload provenance                   PASS
exact SArtFile byte relocations                  3
4e8d -> 4e75                                     PROVEN
4e8e -> 4e76                                     PROVEN
4e90 -> 4e78                                     PROVEN
4e8f / 4e91 exact bytes in all Lion archives    NOT FOUND
candidate semantic continuation                  4e8f->4e77;4e91->4e79
ID-only remap                                    NOT AUTHORIZED
next step                                        frame-ID relocation/slot audit
XNU                                              no source change indicated
```
