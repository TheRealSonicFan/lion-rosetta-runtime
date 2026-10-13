# ShowWindow ArtFile component dictionary audit

## Objective

Close the exact Snow-PPC/Lion ArtFile component-ID mismatch proven by the preserved exact-seven core before preparing any live compatibility shim.

The analyzer-v2 preserved-core report now passes every provenance gate. It proves that the old Snow-PPC CoreUI instance mapped Lion's current `ArtFile.bin`, recovered the active path `a6 16 1f 7a b6 00 00 00`, and then used component `0xb6` even though Lion's legacy ArtFile header contains only `0xa9` / 169 component entries.

The unchecked Snow helper computes the `0xb6` entry at file offset `0x5c0`. On Lion, the component table ends at `0x560`, so that address is already `0x60` bytes inside the string pool. Interpreting those string bytes as a table word produces relative value `0x75626c65`, which combines with the recovered runtime string-pool pointer to produce `0x787221c5`.

That value is not merely near the prior crash. The earlier preserved postmortem recorded PPC `r3=0x787221c5` / `r25=0x787221c5`, PPC `r9=0x787221c4`, host `EAX=0x787221c5`, host `ECX=CR2=0x787221c4`, and a translated load through `ECX`. The ArtFile table overrun therefore explains the exact bad pointer delivered into the diagnostic path.

The remaining question is semantic: **what component does Snow Leopard define at ID `0xb6`, and does Lion retain an equivalent component under another ID or remove that dimension entirely?** Answer that statically before choosing a compatibility boundary.

## Accepted evidence

The successful Lion preserved-core report records:

```text
runtime_global_address_decode=PASS
shared_cache_data_relocated=YES
mapped_base=0x030fb000
mapped_base_page_aligned=YES
table_ptr=0x030fb018
string_ptr=0x030fb560
core_header_u16_4=169
core_header_matches_lion_disk=YES
legacy_derived_pointers_match_lion_header=YES
core_mapped_head_matches_lion_disk=YES
load_frame_match_count=1
path_bytes=a6161f7ab6000000
```

For component `0xb6` it records:

```text
id_within_component_count=NO
entry_off=0x5c0
entry_within_component_table=NO
table_overrun=0x60
unsafe_string_rel=0x75626c65
unsafe_runtime_ptr=0x787221c5
fault_address=0x787221c4
fault_delta=1
fault_near=YES
```

The earlier Snow static report already established that Snow `ArtFile.bin` has header component field `0xb6` / 182, while Lion has `0xa9` / 169. The new audit resolves the actual component names and all tail-ID mappings directly from each local archive.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-components.py
```

Analyzer version:

```text
1
```

The analyzer is Python-2-compatible and read-only. It:

1. accepts only Snow Leopard 10.6.8 / 10K549 or Lion 10.7.5 / 11G63;
2. verifies the exact previously accepted `ArtFile.bin` size and SHA-256 for that release;
3. decodes the legacy little-endian ArtFile header;
4. verifies that the component table ends exactly at the string-pool boundary;
5. resolves every valid component ID through the same `table_start + (id-1)*8` layout proven by the preserved-core decoder;
6. records both raw table words, string offset, and decoded text for every component;
7. explicitly decodes the three observed invalid-path byte sequences;
8. requires all three paths to be component-valid on Snow;
9. requires the first two paths to remain component-valid on Lion while the `0xb6` path is invalid;
10. prints the complete component dictionary plus a focused `0xa0..` tail section so the Snow `0xb6` semantic and any Lion equivalent can be compared without copying either Apple archive.

No PPC application is launched by this analyzer.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach GDB to a live process.
- Do not rebuild or rerun the exact-seven broker.
- Do not patch or replace `ArtFile.bin`, `ArtFile200.bin`, `SArtFile.bin`, CoreUI, or HIToolbox.
- Do not suppress or interpose `ShowArtFilePathToStdErr`, `fprintf`, or `vfprintf`.
- Do not add a bounds-check shim merely to hide the diagnostic crash.
- Do not remap component `0xb6` yet.
- Keep WindowBackingInfo, ColorProfileClient, ResolveColorProfile, distributed-notification, RawCamera, ShapeWindow, and all accepted compatibility adapters unchanged.
- Do not change XNU, rebuild the kernel, or reboot.

## Phase A — update runtime on both systems

On Snow Leopard and Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

ls -l ./scripts/audit-pm-artfile-components.py
ls -l ./docs/pm-showwindow-artfile-component-audit.md
```

No XNU build action is required.

## Phase B — syntax-check the analyzer

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-components.py","rb").read(),"audit-pm-artfile-components.py","exec")' || exit 1
```

## Phase C — Snow Leopard component audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-components.py \
  ./pm-art-components-snow.txt
```

Require:

```text
component_count=182
component_count_hex=0xb6
component_table_end_matches_string_pool=YES
release_expected_path_validity=PASS
RESULT: PASS
```

The `path=b6` line must report `all_components_valid=YES`.

## Phase D — Lion component audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-components.py \
  ./pm-art-components-lion.txt
```

Require:

```text
component_count=169
component_count_hex=0xa9
component_table_end_matches_string_pool=YES
release_expected_path_validity=PASS
RESULT: PASS
```

The `path=b6` line must report:

```text
all_components_valid=NO
invalid_ids=0xb6
```

## Phase E — return evidence

Return exactly:

```text
pm-art-components-snow.txt
pm-art-components-lion.txt
```

Do not return either ArtFile binary.

## Review gates

### Snow 0xb6 has a named component that Lion retains under another ID

If the Snow `component_id=0xb6` text appears exactly once in Lion's complete dictionary under a different valid ID, the next experiment can be scoped to that one semantic component mapping. Before altering any live path, verify that the other IDs in the three observed paths retain the same names on both releases and that the differing ID is generated by old `CreateQSIImagePath` rather than supplied by HIToolbox.

Do not remap arbitrary component bytes globally.

### Snow 0xb6 names a component absent from Lion

If Lion has no semantic equivalent, the release difference is not a simple numeric renumbering. The next read-only step must identify what native Lion `CreateQSIImagePath` emits for the same titlebar descriptor/variant so a descriptor/path semantic conversion can be designed. Do not invent a replacement component.

### IDs 1..0xa9 are otherwise stable

If the common component-ID prefix is name-stable and Snow merely extends the table through `0xb6`, this sharply localizes the compatibility defect to a Snow-only tail component reaching a shorter Lion legacy archive. That result is sufficient to reject whole-archive replacement and broad diagnostic suppression.

### Earlier IDs also differ semantically

If any of the active path IDs `0xa6,0x13,0x16,0x1f,0x56,0x7a` resolve to different names across releases, the incompatibility is broader than the single `0xb6` tail entry. Stop before a live shim and compare native Lion path construction for all changed components.

## Current boundary

```text
preserved-core analyzer v2                       PASS
runtime CoreUI globals                            exact shared-cache relocation recovered
mapped archive                                    Lion ArtFile.bin proven
active path                                       a6 16 1f 7a b6 00 00 00
Lion component count                              0xa9 / 169
legacy requested component                        0xb6 / 182
legacy computed entry                             0x5c0
Lion component-table end                          0x560
table overrun                                     0x60 into string pool
unsafe legacy relative word                       0x75626c65
unsafe legacy pointer                             0x787221c5
preserved PPC r3 / r25                            0x787221c5
fault address / PPC r9 / host ECX / CR2           0x787221c4
exact crash linkage                               proven
Snow 0xb6 semantic                                not yet decoded
next step                                         static Snow/Lion component dictionary audit
PPC subject rerun                                 NO
resource substitution                             NO
XNU                                                no change indicated
```
