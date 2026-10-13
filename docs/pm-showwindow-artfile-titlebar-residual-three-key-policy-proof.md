# ShowWindow residual titlebar exact-three-key policy proof

## Objective

Classify the post-translation Lion crash and prove, without another PPC run, whether the newly observed residual titlebar ArtFile keys have exact semantic-equivalent Lion index entries suitable for a later policy-extension review.

The 2026-10-13 Lion crash report is decisive enough for classification without the 500+ MB core:

```text
exception                         EXC_BAD_ACCESS (SIGSEGV)
fault address                     0x7872a1c4
Rosetta host EIP                  0x8bea0843
CoreUI helper                     ShowArtFilePathToStdErr + 220
LoadFromArtFile                   +1840
CUIElement::Load                  +132
entry path                        HIToolbox titlebar drawing during ShowWindow
```

Those helper offsets and the Rosetta host EIP are identical to the previously preserved CoreUI diagnostic-helper crash. The new fault pointer is different, but the failure class is not downstream: the live original exact-three translator exposed a second titlebar-key set which still misses Lion's ArtFile and enters the same unchecked CoreUI diagnostic path.

The residual exact Snow keys observed immediately before the crash are:

```text
active-clear  a60113167a000000
active-minus  a60116567a000000
active-zoom   a601167ab6000000
```

Existing Snow/Lion component-dictionary evidence gives the semantic-equivalent candidate Lion keys:

```text
active-clear  a60113167a000000 -> 9901141772000000
active-minus  a60116567a000000 -> 9901175572000000
active-zoom   a601167ab6000000 -> 99011772a9000000
```

No live-policy extension is authorized by the crash report alone. These mappings must first pass the same release/resource, direct-index, payload-validity, idempotence, and near-miss proof used for the original exact-three policy.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-residual-three-key-policy.py
```

Identity:

```text
analyzer_version=1
audit_contract=titlebar-residual-three-key-policy-v1
git_blob=7cefe925b73ec4be54ea916fbc8e038ca2aca12a
```

The analyzer is Python-2-compatible and read-only. It:

1. validates exact Snow 10.6.8/10K549 and Lion 10.7.5/11G63 ArtFile identities and geometry;
2. keeps the Lion translation guard disabled on Snow;
3. tests exactly the three residual eight-byte source keys above;
4. tests only the three semantic-equivalent Lion candidates above;
5. requires full eight-byte equality;
6. proves source/target uniqueness and idempotence;
7. proves the residual source and target sets do not overlap the already-live original exact-three source/target sets;
8. exercises all 6,120 single-byte near misses as identity;
9. requires one Snow source-index hit per residual key;
10. requires zero Lion source hits, one Lion target hit, the expected semantic decode, and a valid payload reference per residual key;
11. changes no ArtFile record and launches no PPC process.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not modify the existing bsearch interposer.
- Do not add the residual keys to the live policy yet.
- Do not attach to a live process.
- Do not patch CoreUI or ArtFile.bin.
- Do not suppress ShowArtFilePathToStdErr/fprintf/vfprintf.
- Keep the exact-seven notification policy and all accepted adapters unchanged.
- Keep RawCamera and ShapeWindow held.
- Preserve core.9821; it is not required for this classification/proof stage.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update and preflight

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git fetch origin || exit 1
git pull --ff-only origin main || exit 1

LOCAL_HEAD="$(git rev-parse HEAD)" || exit 1
REMOTE_HEAD="$(git rev-parse origin/main)" || exit 1
test "$LOCAL_HEAD" = "$REMOTE_HEAD" || exit 1

SCRIPT=./scripts/audit-pm-artfile-titlebar-residual-three-key-policy.py

test "$(git hash-object "$SCRIPT")" =   "7cefe925b73ec4be54ea916fbc8e038ca2aca12a" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' "$SCRIPT" || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-residual-three-key-policy-v1"$' "$SCRIPT" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-residual-three-key-policy.py","rb").read(),"audit-pm-artfile-titlebar-residual-three-key-policy.py","exec")' || exit 1
```

Do not proceed if preflight fails.

## Phase B — Snow residual-source control

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1
/usr/bin/python ./scripts/audit-pm-artfile-titlebar-residual-three-key-policy.py   ./pm-art-titlebar-residual-three-key-policy-snow.txt
```

Require:

```text
product_version=10.6.8
build_version=10K549
guard_enabled=NO
guard_selftest=PASS
policy_entry_count=3
single_byte_near_miss_cases=6120
single_byte_near_miss_failures=0
local_index_records_checked=3324
local_index_records_changed=0
original_policy_source_overlap=0
original_policy_target_overlap=0
policy_idempotence=PASS
RESULT: PASS
```

For active-clear, active-minus, and active-zoom require `local_source_index_hits=1`.

## Phase C — Lion residual-target proof

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1
/usr/bin/python ./scripts/audit-pm-artfile-titlebar-residual-three-key-policy.py   ./pm-art-titlebar-residual-three-key-policy-lion.txt
```

Require:

```text
product_version=10.7.5
build_version=11G63
guard_enabled=YES
guard_selftest=PASS
policy_entry_count=3
single_byte_near_miss_cases=6120
single_byte_near_miss_failures=0
local_index_records_checked=2674
local_index_records_changed=0
original_policy_source_overlap=0
original_policy_target_overlap=0
target_outputs_are_policy_sources=NO
policy_idempotence=PASS
RESULT: PASS
```

For each residual key require:

```text
local_source_index_hits=0
local_target_index_hits=1
local_target_payload_0x68_valid=YES
```

and verify the semantic decode equals the documented path.

## Phase D — return evidence

Return exactly:

```text
pm-art-titlebar-residual-three-key-policy-snow.txt
pm-art-titlebar-residual-three-key-policy-lion.txt
```

Do not return ArtFile binaries or core.9821.

## Review gate

If both reports pass, the next stage may design a six-key policy update by combining the already-live original three keys with these residual three keys, followed by a mandatory static combined-policy proof before any new compatibility dylib or Lion PPC run.

If either report fails, stop and preserve the current three-key live policy unchanged.

## Current boundary

```text
original exact-three live translation              PASS
post-translation crash class                       same CoreUI diagnostic-helper fault
residual exact-three source keys                   OBSERVED LIVE
residual semantic candidate mappings               STATIC DICTIONARY-DERIVED
residual direct-index/payload proof                 NEXT
core.9821                                           PRESERVE; NOT REQUIRED NOW
live six-key policy                                 NOT AUTHORIZED
PPC Lion rerun                                      NO
CoreUI/ArtFile patch                                NO
XNU                                                 no change indicated
```
