# ShowWindow titlebar translated-path ArtFile feasibility audit

## Objective

Determine whether the three exact Snow-PPC titlebar paths preserved at the ShowWindow failure have semantic-equivalent keys in Lion's legacy `ArtFile.bin` lookup index before any live path translator is introduced.

The completed state-transition audit now proves an exact correspondence for the Snow state model when Lion's additional titlebar-secondary state is in its neutral/other class:

```text
Snow primary -> Lion primary
0xa3 -> 0xad
0xa4 -> 0xae
0xa5 -> 0xaf
0xa6 -> 0xb0
0xa7 -> 0xb1
0xa8 -> 0xb2
0xa9 -> 0xb3
0xaa -> 0xb4
```

For `regularwin`, `variant1`, and `variant2`, every Snow output semantic matches the Lion output semantic under that primary mapping when Lion secondary is `other`. Lion's `key`, `active`, and `inactive` secondary classes are additional native state distinctions, not replacements for the neutral correspondence.

The old Snow-PPC consumer boundary is therefore suitable for a narrower question: by the time `CUIElement::Load` calls `LoadFromArtFile(const unsigned char*)`, the path already contains the emitted semantic state. A path-consumer compatibility layer would not need to reconstruct Lion's descriptor state if the exact semantic-equivalent Lion index keys already exist.

## Exact crash-time semantic paths

The three already-preserved Snow paths are:

```text
clear  a6 13 16 1f 7a 00 00 00
       titlebarcontrols.close.colorsryg.disabled.regularwin

minus  a6 16 1f 56 7a 00 00 00
       titlebarcontrols.colorsryg.disabled.minimize.regularwin

zoom   a6 16 1f 7a b6 00 00 00
       titlebarcontrols.colorsryg.disabled.regularwin.zoom
```

The audit must not broaden beyond these three paths.

## Legacy ArtFile index contract

The Snow-PPC `LoadFromArtFile` implementation constructs a search key of:

```text
4-byte payload offset field + 8-byte component path
```

and performs `bsearch` over the index beginning at header field `0x10`, using:

```text
record_count = header u16 @ 0x00
path_length  = header u16 @ 0x02
record_size  = path_length + 4
index_start  = header u32 @ 0x10
payload_base = header u32 @ 0x14
```

For the accepted archives this yields:

```text
Snow: 3324 records, index 0x0c4a..0x0a81a, 2 bytes padding, payload base 0x0a81c
Lion: 2674 records, index 0x0b9d..0x088f5, 3 bytes padding, payload base 0x088f8
```

A matching index record's first little-endian word is added to the payload base; the old loader then consumes the referenced image metadata. The prepared analyzer validates that any matched record has at least the first `0x68` payload bytes inside the archive.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-translated-paths.py
```

Identity:

```text
analyzer_version=1
audit_contract=titlebar-translated-path-feasibility-v1
git_blob=93632a826bbf4248b8336eb055a892f0b6f85d99
```

The analyzer is read-only and Python-2-compatible. It:

1. verifies the exact Snow/Lion build and `ArtFile.bin` size/SHA;
2. validates the legacy header and exact index geometry;
3. decodes the release-local component dictionary;
4. encodes each of the three preserved semantic paths using the local release's component IDs;
5. searches the actual fixed-size lookup records, not arbitrary raw file bytes;
6. reports exact direct-key hits and their payload offsets;
7. also reports any record with the same semantic component set in a different order, so a canonical-order change cannot be mistaken for a missing resource;
8. on Snow, provides a source-archive positive control;
9. on Lion, reports whether all three translated semantic keys are direct valid index records.

This audit does not execute CoreUI code and does not run the PPC subject.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach a debugger to a live process.
- Do not patch CoreUI or any ArtFile.
- Do not install a titlebar interposer yet.
- Do not globally remap CoreUI IDs.
- Do not suppress diagnostics.
- Do not substitute Snow resources on Lion.
- Keep accepted Process Manager/CGS/notification adapters unchanged.
- Keep RawCamera and ShapeWindow held.
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

echo "local_head=$LOCAL_HEAD"
echo "origin_main=$REMOTE_HEAD"

test "$LOCAL_HEAD" = "$REMOTE_HEAD" || {
  echo "ERROR: local runtime main is not current origin/main"
  exit 1
}

SCRIPT=./scripts/audit-pm-artfile-titlebar-translated-paths.py

test "$(git hash-object "$SCRIPT")" = "93632a826bbf4248b8336eb055a892f0b6f85d99" || {
  echo "ERROR: translated-path analyzer is stale or locally modified"
  exit 1
}

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' "$SCRIPT" || {
  echo "ERROR: expected analyzer version 1"
  exit 1
}

/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-translated-path-feasibility-v1"$' "$SCRIPT" || {
  echo "ERROR: unexpected analyzer contract"
  exit 1
}
```

Do not proceed if Phase A fails.

## Phase B — syntax-check

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-translated-paths.py","rb").read(),"audit-pm-artfile-titlebar-translated-paths.py","exec")' || exit 1
```

## Phase C — Snow source-index control

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-translated-paths.py   ./pm-art-titlebar-translated-paths-snow.txt
```

Require:

```text
analyzer_version=1
audit_contract=titlebar-translated-path-feasibility-v1
product_version=10.6.8
build_version=10K549
record_count=3324
path_length=8
record_size=12
path_index_start=0xc4a
payload_region_start=0xa81c
source_archive_positive_control=PASS
RESULT: PASS
```

Each of `clear`, `minus`, and `zoom` must report `disposition=DIRECT_INDEX_HIT` with a valid payload reference. If the Snow positive control fails, return the report and stop; do not interpret the Lion result.

## Phase D — Lion translated-key feasibility

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-translated-paths.py   ./pm-art-titlebar-translated-paths-lion.txt
```

Require structural success:

```text
analyzer_version=1
audit_contract=titlebar-translated-path-feasibility-v1
product_version=10.7.5
build_version=11G63
record_count=2674
path_length=8
record_size=12
path_index_start=0xb9d
payload_region_start=0x88f8
RESULT: PASS
```

Then review `lion_translated_path_feasibility` and the three per-path dispositions.

## Phase E — return evidence

Return exactly:

```text
pm-art-titlebar-translated-paths-snow.txt
pm-art-titlebar-translated-paths-lion.txt
```

Do not return CoreUI or ArtFile binaries.

## Review gates

### Lion direct index hits for all three paths

If Snow's positive control passes and Lion reports:

```text
lion_translated_path_feasibility=PASS
```

with `DIRECT_INDEX_HIT` and valid payloads for all three paths, the immediate compatibility hypothesis is strongly constrained: semantic translation of only these three exact Snow path keys reaches real Lion legacy-ArtFile entries. The next stage may prepare a process-local **policy proof** for an exact three-key translation at the old Snow-PPC `LoadFromArtFile` consumer boundary.

That next stage must still be non-live first: prove the mapping function, exact byte predicates, release/resource guards, and no-op behavior for every non-target path before integrating it into the existing process-local compatibility environment.

### Same semantic component set exists but order differs

If a path reports `SEMANTIC_SET_REORDERED`, stop before a translator. The next discriminator must explain the CUIPath canonical ordering difference and derive the exact Lion key from native Lion path construction.

### Lion semantic path missing

If any path reports `SEMANTIC_PATH_MISSING`, stop. Do not synthesize an ArtFile entry, substitute Snow resources, or broaden the translator.

### Snow source positive control fails

The index model is not sufficiently validated. Stop and correct the static parser before using Lion results.

## Completed result

The returned Snow report passes the source-archive positive control. All three exact Snow keys are direct source-index hits with valid payload references. The returned Lion report also passes: each untranslated Snow key is absent, while each semantic-equivalent Lion key is a unique direct index hit with a valid payload reference:

```text
clear  a613161f7a000000 -> 9914172272000000
minus  a6161f567a000000 -> 9917225572000000
zoom   a6161f7ab6000000 -> 99172272a9000000
```

Therefore the translated-path feasibility gate is closed positively. The next authoritative stage is the non-live exact-three-key policy proof in `docs/pm-showwindow-artfile-titlebar-three-key-policy-proof.md`, using `scripts/audit-pm-artfile-titlebar-three-key-policy.py`. It must prove the exact three-entry mapping, Lion-only release/resource guard, idempotence, and identity behavior for non-target paths before any live CoreUI integration is designed.

## Current boundary

```text
titlebar prefix namespace shift                  PROVEN
window-variant semantic reindex                 PROVEN
state transition neutral correspondence         PROVEN
Snow primary -> Lion primary                    +0x0a for 0xa3..0xaa
Lion extra titlebar-secondary distinctions      additive and preserved
exact crash-time Snow paths                     PROVEN
Lion semantic-equivalent index keys             PROVEN
exact three-key translation table               DEFINED
next step                                       static policy proof
live path translator                            NOT AUTHORIZED
PPC subject rerun                               NO
CoreUI/ArtFile patch                            NO
XNU                                             no change indicated
```
