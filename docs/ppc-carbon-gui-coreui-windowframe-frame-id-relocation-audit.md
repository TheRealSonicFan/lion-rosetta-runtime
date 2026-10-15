# PPC Carbon GUI CoreUI window-frame frame-ID relocation audit

## Status

PHASE C ANALYZER FALSE-FAILURE CORRECTED. The returned Snow Phase B report is valid and passes. The returned Lion report also proves the expected target order and all five type-1/count-2 record/slot contracts, but analyzer v1 falsely marked the constructor checks as failures because Lion `otool -tvV` printed the constructor calls as the numeric target `0x00004944` rather than the symbol name. The already-pinned renderer audit independently resolves `0x00004944` to `CUIRenderer::CreateInternalImageWithScale(long,CUIDescriptor const*,CGRect*,...)` at all five reported call sites.

Analyzer v2 resolves numeric direct-call targets through the `nm` address table before testing the expected constructor. The exact five Lion call forms from the failed report were verified against that resolver before the fix was committed. The SArtFile decoding, mapping candidates, and safety boundary are unchanged. Re-run Phase C only; the successful Snow Phase B report does not need to be regenerated.

The provenance report closes the archive search: three Snow frame payloads survive byte-for-byte in Lion SArtFile, and the two unmatched Snow payloads do not appear as exact raw cells/providers in Lion SArtFile, ArtFile10, or ArtFile20.

Historical pinned renderer reports already expose a stronger structural clue that must now be reproduced as a dedicated audit. Snow `DrawWindowFrameDark` uses the active legacy IDs in this code order:

```text
0x4e8e
0x4e90
0x4e8d
0x4e8f
0x4e91
```

Lion-native `DrawWindowFrameDark` uses:

```text
0x4e76
0x4e78
0x4e75
0x4e77
0x4e79
```

at corresponding image-construction positions. This is the same order under the exact transformation:

```text
legacy_id - 0x18
```

for the contiguous legacy range `0x4e8d..0x4e91`.

Three exact-byte anchors independently confirm that mapping:

```text
0x4e8d -> 0x4e75
0x4e8e -> 0x4e76
0x4e90 -> 0x4e78
```

The two remaining semantic candidates are therefore:

```text
0x4e8f -> 0x4e77
0x4e91 -> 0x4e79
```

but their bytes changed between releases. Before any live compatibility rule is built, the release-local renderer call order and every slot of all ten relevant records must be re-proven from the pinned binaries/resources.

## Objective

Run one static audit on Snow Leopard and one on Lion that jointly prove:

1. the exact five active legacy constants occur in Snow `DrawWindowFrameDark` in the accepted live order and are immediately consumed by `CUIRenderer::CreateImage`;
2. the exact five Lion candidates occur in native Lion `DrawWindowFrameDark` in the corresponding order and are immediately consumed by `CreateInternalImageWithScale`;
3. Snow records are type 2 / count 1 and expose 11x11 / 484-byte slot 0 providers;
4. Lion records `0x4e75..0x4e79` are type 1 / count 2 and expose every slot, including provider hashes and geometry;
5. the three exact-byte anchors remain exact.

The audit also emits a warning that an **ID-only** remap is not yet authorized. The old PPC reader's current Lion live run proves that type-1/count-2 records can select slot 1, so translating the ID alone could select the high-resolution slot rather than the 11x11 slot-0 contract the Snow renderer used.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py
Git blob 6a3cb4d9fc70a5d8ec9b142d0a90963350354367
```

Contract:

```text
analyzer_version=2
audit_contract=carbon-gui-coreui-windowframe-frame-id-relocation-v2
```

## Safety constraints

- Static only; do not launch the PPC subject.
- Do not build or load a new compatibility dylib.
- Do not add any image-ID mapping yet.
- Do not force slot 0, alter scale, patch SArtFile metadata, or copy Snow image bytes.
- Retain the exact-six titlebar semantic-key translation and exact-six bitmap-info adapter unchanged.
- Do not modify CoreUI, HIToolbox, SArtFile, ArtFile, ArtFile200, Rosetta cache, CGContext state, hit masks, part codes, mouse routing, or CGS policy.
- Do not modify XNU, rebuild the kernel, or reboot.

## Phase A — update and pin

On Snow Leopard and Lion:

```sh
cd /path/to/lion-rosetta-runtime || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

test "$(git hash-object ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py)" = \
  "6a3cb4d9fc70a5d8ec9b142d0a90963350354367" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "2"

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py","rb").read(),"audit-frame-id-relocation.py","exec")' || exit 1
```

## Phase B — Snow report

The already returned analyzer-v1 Snow report is accepted: it has exact pinned identities, the correct target order, five direct symbolic `CreateImage` matches, valid 11x11/484-byte records, and `RESULT: PASS`. Do not rerun Snow merely for the analyzer-v2 formatting change.

For a fresh full rerun only, the command remains:

On Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py \
  ./ppc-carbon-gui-coreui-windowframe-frame-id-relocation-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
coreui_slice_exact=YES
sartfile_exact=YES
expected_target_order=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
observed_target_order=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
frame_id_relocation_contract_exact=YES
RESULT: PASS
```

Each target must report type 2 / count 1 with slot 0 equal to 11x11 / 484 bytes and a valid provider range.

## Phase C — Lion report

Pull current `main` on Lion and rerun this phase. No PPC subject is launched.

On Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py \
  ./ppc-carbon-gui-coreui-windowframe-frame-id-relocation-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
coreui_slice_exact=YES
sartfile_exact=YES
expected_target_order=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
observed_target_order=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
callee_match=YES
frame_id_relocation_contract_exact=YES
RESULT: PASS
```

Each target must report type 1 / count 2. Review both slot 0 and slot 1 geometry/provider hashes.

## Review gate

### Both reports pass; Lion slot 0 is 11x11/484 for all five and slot 1 is a larger scale variant

The semantic relocation contract is proven for the active five IDs, and an ID-only adapter is insufficient for the old PPC reader. The next controlled step should be a guarded compatibility design that maps only:

```text
0x4e8d -> 0x4e75
0x4e8e -> 0x4e76
0x4e8f -> 0x4e77
0x4e90 -> 0x4e78
0x4e91 -> 0x4e79
```

while preserving the old renderer's 11x11 slot-0 image contract. The implementation must use Lion resource bytes only and must have a Snow passthrough control before one Lion run.

### Lion call order differs or any mapped ID is not consumed by the native frame renderer

Stop. Do not infer a semantic mapping from numeric adjacency alone.

### Any mapped Lion record does not have a valid 11x11 slot 0

Stop. Revisit the candidate mapping before implementing compatibility.

### Slot 1 is not a simple high-resolution variant

Do not force slot 0 yet. Resolve the scale/slot semantics first.

## Return evidence

The existing Snow report is already accepted. Return only the regenerated Lion report:

```text
ppc-carbon-gui-coreui-windowframe-frame-id-relocation-lion.txt
```

## Current boundary

```text
Lion provenance audit                            PASS
three exact byte relocations                     PROVEN
two remaining raw-byte payloads                  absent from Lion CoreUI archives
candidate semantic relocation                    legacy 4e8d..4e91 -> Lion 4e75..4e79
Snow renderer call-order correspondence          PASS
Lion target order/record slots                    PROVEN by failed-v1 report
Lion constructor callee validation                analyzer-v1 false negative / v2 prepared
ID-only remap                                    NOT AUTHORIZED
slot-0 forcing                                   NOT AUTHORIZED
next step                                        static frame-ID relocation/slot audit
XNU                                              no source change indicated
```
 \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "carbon-gui-coreui-windowframe-frame-id-relocation-v2"

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py","rb").read(),"audit-frame-id-relocation.py","exec")' || exit 1
```

## Phase B — Snow report

On Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py \
  ./ppc-carbon-gui-coreui-windowframe-frame-id-relocation-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
coreui_slice_exact=YES
sartfile_exact=YES
expected_target_order=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
observed_target_order=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
frame_id_relocation_contract_exact=YES
RESULT: PASS
```

Each target must report type 2 / count 1 with slot 0 equal to 11x11 / 484 bytes and a valid provider range.

## Phase C — Lion report

On Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py \
  ./ppc-carbon-gui-coreui-windowframe-frame-id-relocation-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
coreui_slice_exact=YES
sartfile_exact=YES
expected_target_order=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
observed_target_order=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
frame_id_relocation_contract_exact=YES
RESULT: PASS
```

Each target must report type 1 / count 2. Review both slot 0 and slot 1 geometry/provider hashes.

## Review gate

### Both reports pass; Lion slot 0 is 11x11/484 for all five and slot 1 is a larger scale variant

The semantic relocation contract is proven for the active five IDs, and an ID-only adapter is insufficient for the old PPC reader. The next controlled step should be a guarded compatibility design that maps only:

```text
0x4e8d -> 0x4e75
0x4e8e -> 0x4e76
0x4e8f -> 0x4e77
0x4e90 -> 0x4e78
0x4e91 -> 0x4e79
```

while preserving the old renderer's 11x11 slot-0 image contract. The implementation must use Lion resource bytes only and must have a Snow passthrough control before one Lion run.

### Lion call order differs or any mapped ID is not consumed by the native frame renderer

Stop. Do not infer a semantic mapping from numeric adjacency alone.

### Any mapped Lion record does not have a valid 11x11 slot 0

Stop. Revisit the candidate mapping before implementing compatibility.

### Slot 1 is not a simple high-resolution variant

Do not force slot 0 yet. Resolve the scale/slot semantics first.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-frame-id-relocation-snow.txt
ppc-carbon-gui-coreui-windowframe-frame-id-relocation-lion.txt
```

## Current boundary

```text
Lion provenance audit                            PASS
three exact byte relocations                     PROVEN
two remaining raw-byte payloads                  absent from Lion CoreUI archives
candidate semantic relocation                    legacy 4e8d..4e91 -> Lion 4e75..4e79
native renderer call-order correspondence        historical evidence / needs dedicated PASS
ID-only remap                                    NOT AUTHORIZED
slot-0 forcing                                   NOT AUTHORIZED
next step                                        static frame-ID relocation/slot audit
XNU                                              no source change indicated
```
 \
  ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py","rb").read(),"audit-frame-id-relocation.py","exec")' || exit 1
```

## Phase B — Snow report

On Snow Leopard:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py \
  ./ppc-carbon-gui-coreui-windowframe-frame-id-relocation-snow.txt || exit 1
```

Require:

```text
product_version=10.6.8
build_version=10K549
coreui_slice_exact=YES
sartfile_exact=YES
expected_target_order=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
observed_target_order=0x4e8e,0x4e90,0x4e8d,0x4e8f,0x4e91
frame_id_relocation_contract_exact=YES
RESULT: PASS
```

Each target must report type 2 / count 1 with slot 0 equal to 11x11 / 484 bytes and a valid provider range.

## Phase C — Lion report

On Lion:

```sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-coreui-windowframe-frame-id-relocation.py \
  ./ppc-carbon-gui-coreui-windowframe-frame-id-relocation-lion.txt || exit 1
```

Require:

```text
product_version=10.7.5
build_version=11G63
coreui_slice_exact=YES
sartfile_exact=YES
expected_target_order=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
observed_target_order=0x4e76,0x4e78,0x4e75,0x4e77,0x4e79
frame_id_relocation_contract_exact=YES
RESULT: PASS
```

Each target must report type 1 / count 2. Review both slot 0 and slot 1 geometry/provider hashes.

## Review gate

### Both reports pass; Lion slot 0 is 11x11/484 for all five and slot 1 is a larger scale variant

The semantic relocation contract is proven for the active five IDs, and an ID-only adapter is insufficient for the old PPC reader. The next controlled step should be a guarded compatibility design that maps only:

```text
0x4e8d -> 0x4e75
0x4e8e -> 0x4e76
0x4e8f -> 0x4e77
0x4e90 -> 0x4e78
0x4e91 -> 0x4e79
```

while preserving the old renderer's 11x11 slot-0 image contract. The implementation must use Lion resource bytes only and must have a Snow passthrough control before one Lion run.

### Lion call order differs or any mapped ID is not consumed by the native frame renderer

Stop. Do not infer a semantic mapping from numeric adjacency alone.

### Any mapped Lion record does not have a valid 11x11 slot 0

Stop. Revisit the candidate mapping before implementing compatibility.

### Slot 1 is not a simple high-resolution variant

Do not force slot 0 yet. Resolve the scale/slot semantics first.

## Return evidence

Return exactly:

```text
ppc-carbon-gui-coreui-windowframe-frame-id-relocation-snow.txt
ppc-carbon-gui-coreui-windowframe-frame-id-relocation-lion.txt
```

## Current boundary

```text
Lion provenance audit                            PASS
three exact byte relocations                     PROVEN
two remaining raw-byte payloads                  absent from Lion CoreUI archives
candidate semantic relocation                    legacy 4e8d..4e91 -> Lion 4e75..4e79
native renderer call-order correspondence        historical evidence / needs dedicated PASS
ID-only remap                                    NOT AUTHORIZED
slot-0 forcing                                   NOT AUTHORIZED
next step                                        static frame-ID relocation/slot audit
XNU                                              no source change indicated
```
