# PPC Carbon GUI CoreUI window-frame live-active SArtFile payload fingerprint audit

## Status

COMPLETED STATIC PASS. All five Snow live-active provider ranges are valid and the Lion SArtFile inventory passes. Three Snow payloads survive byte-for-byte under different Lion shared-art IDs, while two have no exact match among Lion's 11x11/484-byte SArtFile candidates. The next step is `docs/ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance-audit.md`.

Snow's exact live-active set is:

```text
0x4e8e
0x4e90
0x4e8d
0x4e8f
0x4e91
```

All five are Snow type-2/count-1 records with 11x11 slot-0 raw payloads.

On Lion, the same five IDs split deterministically:

```text
0x4e8e  type 1 / count 2 -> live raw slot 1 -> 256x256
0x4e8d  type 1 / count 2 -> live raw slot 1 -> 2x62

0x4e90  type 3 / count 3 -> ImageIO branch
0x4e8f  type 3 / count 3 -> ImageIO branch
0x4e91  type 3 / count 3 -> ImageIO branch
```

The two raw IDs are directly recovered by the live trace. The remaining three IDs are the exact Snow-active remainder, all three are Lion type-3/count-3, and the Lion live trace contains exactly three non-NULL ImageIO constructions. No additional live trace is needed to establish this partition.

The current question is no longer branch selection. It is asset provenance: do the five Snow 11x11 raw payloads still exist elsewhere in Lion's SArtFile under different legacy IDs, or are the legacy frame pixels absent from the Lion SArtFile entirely?

## Objective

Perform a read-only fingerprint audit of the exact five Snow-live-active provider payloads and all Lion SArtFile provider slots that are structurally compatible with the Snow 11x11 raw images.

The analyzer:

- pins the exact Snow/Lion `SArtFile.bin` identities;
- uses the corrected table base `+0x08`;
- reads the SArtFile data-region base from header offset `+0x04`, matching Snow-PPC `CUISharedArtReader::Setup()`;
- resolves each provider byte range as:
  `mapped base + data-region base + provider-data-offset`;
- hashes the exact five Snow-live-active 11x11/484-byte provider payloads;
- on Lion, hashes every valid SArtFile slot with 11x11 geometry and 484-byte provider length;
- records the exact-five Lion record/slot hashes as context;
- copies no Snow image bytes to Lion and launches no PPC process.

An exact SHA-256 match is sufficient to prove that a Snow legacy frame payload survives byte-for-byte somewhere in Lion's SArtFile. A non-match is not yet proof that the payload is absent from all CoreUI resources; `ArtFile.bin` and `ArtFile200.bin` remain a later static search boundary.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py
Git blob a761b75ed674e446d06fb69033d35828ad6f0492
```

Contract:

```text
analyzer_version=1
audit_contract=carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-v1
```

## Safety constraints

- Static only; do not launch the PPC subject.
- Do not rebuild or load the shared-art live diagnostic.
- Do not copy Snow image bytes, records, SArtFile, ArtFile, or ArtFile200 to Lion.
- Do not alter image IDs, record types/counts, selected slots, geometry, provider offsets, provider bytes, or bitmap-info policy.
- Retain the exact-six titlebar semantic-key translation and exact-six bitmap-info adapter unchanged.
- Do not change CGContext state, hit masks, classic part codes, mouse routing, control actions, or CGS compatibility.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py)" = \
  "a761b75ed674e446d06fb69033d35828ad6f0492" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-v1"$' \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py","rb").read(),"audit-live-payload-fingerprints.py","exec")' || exit 1
```

## Phase B — Snow fingerprints

On Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py \
  ./ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=237
offset_table_base=0x08
live_active_id_count=5
live_active_payload_fingerprint_audit_exact=YES
RESULT: PASS
```

Require the five exact live-active IDs to remain type 2 / count 1 with slot 0 at 11x11 and provider length 484, with `provider_range_valid=YES`.

## Phase C — Lion candidate inventory

On Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints.py \
  ./ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
sartfile_exact=YES
sartfile_version=2
sartfile_entry_count=348
offset_table_base=0x08
live_active_id_count=5
lion_live_raw_slot1_ids=0x4e8e,0x4e8d
lion_live_imageio_ids_by_active_set_type_partition=0x4e90,0x4e8f,0x4e91
live_active_payload_fingerprint_audit_exact=YES
RESULT: PASS
```

Do not copy the Snow report or any Snow payload bytes to Lion. Return both text reports for comparison.

## Review gate

### One or more Snow payload SHA-256 values match Lion 11x11/484-byte candidates

The legacy frame artwork survives in Lion's SArtFile under different IDs/slots. The next step becomes a static mapping/consumer audit for only those matched records before considering any exact-ID compatibility rule.

### None of the five Snow payload hashes match any Lion SArtFile 11x11/484-byte candidate

Close the same-archive relocation hypothesis. The next static boundary is an exact-hash inventory of Lion `ArtFile.bin` and `ArtFile200.bin` for the five Snow payload fingerprints. Do not yet embed or substitute Snow pixels.

### Only a subset matches

Map the surviving subset and search only the unmatched payload hashes in Lion's other CoreUI archives.

### Any provider range is invalid

Stop. Revisit the SArtFile data-region-base interpretation before any provenance conclusion.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-snow.txt
ppc-carbon-gui-coreui-windowframe-sartfile-live-payload-fingerprints-lion.txt
```

## Observed result

Both reports pass. Snow supplies five exact 484-byte provider SHA-256 fingerprints. Lion contains exact byte-for-byte SArtFile matches for three of them:

```text
Snow 0x4e8d -> Lion 0x4e75
Snow 0x4e8e -> Lion 0x4e76
Snow 0x4e90 -> Lion 0x4e78
```

The Snow `0x4e8f` and `0x4e91` hashes do not appear among Lion's 44 exact 11x11/484-byte SArtFile candidates. This is a partial relocation result: do not add a mapping yet. Follow `docs/ppc-carbon-gui-coreui-windowframe-lion-legacy-payload-provenance-audit.md` to verify the three relocations across all 484-byte SArtFile slots and search Lion ArtFile10/ArtFile20 old-loader cells for the two unmatched fingerprints.

## Current boundary

```text
live-active payload fingerprint audit            PASS
Snow exact payload fingerprints                  5
Lion SArtFile exact-byte relocations              3
Snow 4e8d -> Lion                                4e75
Snow 4e8e -> Lion                                4e76
Snow 4e90 -> Lion                                4e78
Snow 4e8f / 4e91 SArtFile exact match            NOT FOUND
ArtFile10/ArtFile20 provenance                   UNKNOWN
new mapping                                      NOT AUTHORIZED
next step                                        Lion legacy-payload provenance audit
XNU                                              no source change indicated
```
