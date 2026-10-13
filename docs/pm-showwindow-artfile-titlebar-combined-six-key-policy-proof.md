# ShowWindow titlebar combined six-key policy proof

## Objective

Prove the complete six-key byte policy implied by the live original exact-three result plus the newly completed residual exact-three static proof, without modifying the live interposer and without launching the PPC ShowWindow subject.

The two residual reports now close their static gate:

```text
Snow residual source control                  PASS
Lion residual target proof                    PASS
residual source keys                          one Snow index hit each
residual Lion targets                         one valid direct index hit each
single-byte near misses                       6120 / 0 failures
original/residual source overlap              0
original/residual target overlap              0
```

The combined policy to be proven is exactly:

```text
disabled-clear
a613161f7a000000 -> 9914172272000000

disabled-minus
a6161f567a000000 -> 9917225572000000

disabled-zoom
a6161f7ab6000000 -> 99172272a9000000

active-clear
a60113167a000000 -> 9901141772000000

active-minus
a60116567a000000 -> 9901175572000000

active-zoom
a601167ab6000000 -> 99011772a9000000
```

No seventh key is authorized.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-combined-six-key-policy.py
```

Identity:

```text
analyzer_version=1
audit_contract=titlebar-combined-six-key-policy-v1
git_blob=1553c522d1d31fedf5971944d41798d31e73d6d1
```

The analyzer is Python-2-compatible and read-only. It proves the two three-key sets together under one policy function:

1. exact Snow 10.6.8/10K549 and Lion 10.7.5/11G63 ArtFile identities and archive geometry;
2. Lion-only release/resource activation and Snow identity fallback;
3. exactly three original entries plus exactly three residual entries;
4. six unique full-eight-byte source predicates and six unique outputs;
5. zero source/target overlap and zero original/residual set overlap;
6. exact mapping self-tests and target idempotence for all six entries;
7. all 12,240 single-byte mutations of the six source keys remain identity;
8. every local ArtFile index record remains unchanged under the actual host guard;
9. on Snow, each of the six source keys is a real direct index entry while the guard is disabled;
10. on Lion, all six Snow sources are absent and all six semantic-equivalent Lion targets are unique direct index hits with valid payload references and exact semantic decodes.

This stage does not change `pm-titlebar-bsearch-compat.dylib`. A six-key live interposer is not authorized until both combined reports pass and are reviewed.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not rebuild or replace the existing three-key titlebar compatibility dylib.
- Do not add any key beyond the six listed above.
- Do not attach to a live PPC process.
- Do not patch CoreUI or `ArtFile.bin`.
- Do not suppress the CoreUI diagnostic path.
- Keep the exact-seven notification policy and every accepted compatibility adapter unchanged.
- Keep RawCamera and ShapeWindow held.
- Preserve `core.9821`; it is not required for this static stage.
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

SCRIPT=./scripts/audit-pm-artfile-titlebar-combined-six-key-policy.py

test "$(git hash-object "$SCRIPT")" =   "1553c522d1d31fedf5971944d41798d31e73d6d1" || exit 1

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' "$SCRIPT" || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-combined-six-key-policy-v1"$' "$SCRIPT" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-combined-six-key-policy.py","rb").read(),"audit-pm-artfile-titlebar-combined-six-key-policy.py","exec")' || exit 1
```

Do not proceed if Phase A fails.

## Phase B — Snow combined source control

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1
/usr/bin/python ./scripts/audit-pm-artfile-titlebar-combined-six-key-policy.py   ./pm-art-titlebar-combined-six-key-policy-snow.txt
```

Require:

```text
product_version=10.6.8
build_version=10K549
guard_enabled=NO
guard_selftest=PASS
original_policy_entry_count=3
residual_policy_entry_count=3
policy_entry_count=6
single_byte_near_miss_cases=12240
single_byte_near_miss_failures=0
local_index_records_checked=3324
local_index_records_changed=0
target_outputs_are_policy_sources=NO
policy_idempotence=PASS
original_residual_source_overlap=0
original_residual_target_overlap=0
RESULT: PASS
```

For all six paths require `local_source_index_hits=1`. Lion target hit counts are not acceptance predicates on Snow.

## Phase C — Lion combined target proof

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1
/usr/bin/python ./scripts/audit-pm-artfile-titlebar-combined-six-key-policy.py   ./pm-art-titlebar-combined-six-key-policy-lion.txt
```

Require:

```text
product_version=10.7.5
build_version=11G63
guard_enabled=YES
guard_selftest=PASS
original_policy_entry_count=3
residual_policy_entry_count=3
policy_entry_count=6
single_byte_near_miss_cases=12240
single_byte_near_miss_failures=0
local_index_records_checked=2674
local_index_records_changed=0
target_outputs_are_policy_sources=NO
policy_idempotence=PASS
original_residual_source_overlap=0
original_residual_target_overlap=0
RESULT: PASS
```

For all six paths require:

```text
local_source_index_hits=0
local_target_index_hits=1
local_target_payload_0x68_valid=YES
```

and verify each `local_target_decoded` exactly matches its documented semantic path.

## Phase D — return evidence

Return exactly:

```text
pm-art-titlebar-combined-six-key-policy-snow.txt
pm-art-titlebar-combined-six-key-policy-lion.txt
```

Do not return ArtFile binaries, the compatibility dylib, or `core.9821`.

## Review gate

If both reports pass, the next stage may update the process-local `bsearch` compatibility source from exactly three to exactly six proven keys and prepare a mandatory Snow passthrough control before considering one new Lion run. That implementation stage must preserve the existing callsite/comparator, archive-geometry, release/resource, prefix, exact-seven notification, and non-target identity guards.

If either report fails, stop. Keep the currently live-proven three-key artifact and all other compatibility components unchanged.

## Current boundary

```text
original exact-three policy                    LIVE-PROVEN
residual exact-three policy                    STATIC-PROVEN
combined exact-six mapping set                 DEFINED
combined exact-six static proof                NEXT
live six-key interposer                        NOT AUTHORIZED
PPC Lion rerun                                 NO
core.9821                                      preserve; not required now
CoreUI/ArtFile patch                           NO
XNU                                            no change indicated
```
