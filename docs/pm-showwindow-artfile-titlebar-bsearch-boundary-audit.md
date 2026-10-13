# ShowWindow titlebar bsearch integration-boundary audit

## Objective

Establish the narrowest mechanically interposable process-local boundary for applying the already-proven exact-three-key titlebar translation, without running the PPC ShowWindow subject and before building any live compatibility interposer.

The completed exact-three-key policy proof now closes the policy question:

```text
Snow guard disabled                         PASS
Lion release/resource guard enabled         PASS
exact policy entries                        3
single-byte near misses                     6120
near-miss failures                          0
local ArtFile records changed               0
policy idempotence                          PASS
Lion direct target entries                  3 / 3 valid
```

The remaining question is not which bytes to translate. It is where the old Snow-PPC CoreUI code can be intercepted with the least scope.

Accepted earlier static evidence already shows that `CUIElement::Load` reaches `CUIElement::LoadFromArtFile` with a direct internal PPC branch, while `LoadFromArtFile` calls libSystem `bsearch` through a symbol stub after constructing the old 12-byte lookup record. A direct intra-image branch is not a suitable ordinary dyld-interposition boundary. The external lazy-bound `bsearch` call is a narrower candidate because the exact search key can be replaced only for the duration of that call while leaving the original CoreUI path buffer untouched.

This stage re-proves that boundary from the accepted Snow PPC CoreUI binary and ties it to Lion's unchanged Rosetta shared cache and accepted Lion `ArtFile.bin` identity.

## Prepared analyzer

Current runtime `main` provides:

```text
scripts/audit-pm-artfile-titlebar-bsearch-boundary.py
```

Identity:

```text
analyzer_version=1
audit_contract=titlebar-bsearch-boundary-v1
git_blob=369ee8aad4fa3afe9bdaf0b10dcd94e5d1d84251
```

The analyzer is read-only and Python-2-compatible. On Snow Leopard it:

1. verifies the accepted Rosetta shared-cache/cache-map identities;
2. verifies the accepted Snow CoreUI whole-file and PPC-slice identities;
3. verifies the exact Snow PPC symbol addresses for `ShowArtFilePathToStdErr`, `CUIElement::LoadFromArtFile`, and `CUIElement::Load`;
4. proves `CUIElement::Load -> LoadFromArtFile` is a direct internal branch at relative address `0x29c80`;
5. proves `_bsearch` is an undefined lazy-bound external;
6. proves there is exactly one PPC CoreUI call through the `_bsearch` symbol stub, at relative address `0x294f4`;
7. verifies the exact argument-setup window immediately before that call;
8. records the old comparator at relative address `0x25c08`;
9. identifies libSystem `bsearch` as the candidate process-local boundary and rejects ordinary symbol interposition of `LoadFromArtFile`.

On Lion it:

1. verifies the same accepted Rosetta shared-cache/cache-map identities, establishing that the runtime PPC CoreUI code contract is the accepted Snow-era cached image;
2. verifies Lion 10.7.5 / 11G63 and the accepted `ArtFile.bin` size/SHA/header geometry;
3. confirms Lion's on-disk CoreUI has no PPC slice, so the translated process necessarily uses the Rosetta shared-cache copy;
4. records the Lion live-environment guard that any later interposer must require.

This audit does not build, load, or execute an interposer.

## Candidate integration contract

If both static reports pass, the later compatibility artifact may be designed around libSystem `bsearch`, but only with all of the following guards:

```text
host                         Lion 10.7.5 / 11G63
ArtFile resource             exact accepted Lion ArtFile.bin identity
search key                   exact full 8-byte match to one of three Snow keys
record geometry              nmemb=2674, size=12
comparator                   old PPC CoreUI ArtFile comparator
base                         exact old CoreUI ArtFile index for the accepted mapped archive
translation                  temporary search-key copy only
original CoreUI path buffer  unchanged
all non-target bsearch calls passthrough
already-native Lion keys     passthrough
```

The static audit establishes only the call/binding boundary. It does not yet authorize the live compatibility artifact.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not attach a debugger to a live process.
- Do not build, load, or install the titlebar compatibility interposer yet.
- Do not interpose `LoadFromArtFile`, `ShowArtFilePathToStdErr`, `fprintf`, or `vfprintf`.
- Do not patch CoreUI or any ArtFile resource.
- Do not mutate the original CoreUI path buffer.
- Do not broaden the three-key policy.
- Do not suppress diagnostics.
- Do not substitute Snow resources on Lion.
- Keep all accepted Process Manager, CGS, notification, Security, HIToolbox, and other compatibility artifacts unchanged.
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

SCRIPT=./scripts/audit-pm-artfile-titlebar-bsearch-boundary.py

test "$(git hash-object "$SCRIPT")" = "369ee8aad4fa3afe9bdaf0b10dcd94e5d1d84251" || {
  echo "ERROR: bsearch-boundary analyzer is stale or locally modified"
  exit 1
}

/usr/bin/grep -q '^ANALYZER_VERSION = "1"$' "$SCRIPT" || exit 1
/usr/bin/grep -q '^AUDIT_CONTRACT = "titlebar-bsearch-boundary-v1"$' "$SCRIPT" || exit 1
```

Do not proceed if Phase A fails.

## Phase B — syntax-check

On both systems:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/audit-pm-artfile-titlebar-bsearch-boundary.py","rb").read(),"audit-pm-artfile-titlebar-bsearch-boundary.py","exec")' || exit 1
```

## Phase C — Snow PPC call/binding audit

On Snow Leopard 10.6.8:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-bsearch-boundary.py   ./pm-art-titlebar-bsearch-boundary-snow.txt
```

Require:

```text
product_version=10.6.8
build_version=10K549
rosetta_cache_expected=YES
rosetta_cache_map_expected=YES
coreui_present_in_rosetta_cache_map=YES
shared_cache_contract_matches_accepted_snow_ppc=YES
load_to_loadfromartfile_call_kind=DIRECT_INTERNAL_BRANCH
loadfromartfile_symbol_interposition_candidate=NO
bsearch_import_kind=UNDEFINED_LAZY_BOUND_EXTERNAL
bsearch_stub_call_count=1
bsearch_call_address=0x294f4
bsearch_stub_address=0x2ce70
bsearch_comparator_relative_address=0x25c08
candidate_process_local_hook=libSystem_bsearch
snow_static_boundary=PASS
RESULT: PASS
```

If this phase fails, return the report and stop. Do not infer that another broad libc hook is acceptable.

## Phase D — Lion live-environment guard audit

On Lion 10.7.5:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/audit-pm-artfile-titlebar-bsearch-boundary.py   ./pm-art-titlebar-bsearch-boundary-lion.txt
```

Require:

```text
product_version=10.7.5
build_version=11G63
rosetta_cache_expected=YES
rosetta_cache_map_expected=YES
coreui_present_in_rosetta_cache_map=YES
shared_cache_contract_matches_accepted_snow_ppc=YES
artfile_size=4765184
artfile_sha256=0cc8e1491be49fb015cb8b290fe9c289e4587bde570804a44a43e2b35e4b19f4
artfile_record_count=2674
artfile_path_length=8
artfile_component_count=169
artfile_index_start=0xb9d
artfile_payload_start=0x88f8
disk_coreui_ppc_present=NO
runtime_ppc_coreui_source=dyld_shared_cache_rosetta
lion_environment_guard=PASS
RESULT: PASS
```

## Phase E — return evidence

Return exactly:

```text
pm-art-titlebar-bsearch-boundary-snow.txt
pm-art-titlebar-bsearch-boundary-lion.txt
```

Do not return CoreUI, the Rosetta shared cache, or ArtFile binaries.

## Review gates

### Both reports pass

The static integration boundary is then sufficiently constrained to prepare the actual process-local compatibility artifact.

The next stage may build an exact guarded PPC `bsearch` interposer that:

- activates only on the accepted Lion host/resource state;
- requires the exact old CoreUI ArtFile call geometry and comparator;
- translates only one of the three full eight-byte Snow keys into a temporary Lion-key copy;
- calls the real libSystem `bsearch` with that temporary key;
- passes every other call through byte-for-byte and argument-for-argument;
- never mutates CoreUI memory or the mapped ArtFile;
- emits bounded diagnostic counters so the first live run can prove whether exactly the intended titlebar searches were intercepted.

That subsequent stage must include a Snow passthrough control and a single Lion ShowWindow run with all accepted compatibility layers unchanged.

### Snow boundary fails

Stop. The old PPC call path is not sufficiently proven for a narrow interposer. Do not fall back to `LoadFromArtFile`, `fprintf`, or a global component remap.

### Lion environment guard fails

Stop. Do not load an interposer into a Lion environment whose shared cache or ArtFile identity differs from the accepted state.

## Completed result

Both returned boundary reports pass. Snow re-proves the accepted PPC CoreUI image and exact internal/external call structure: `CUIElement::Load -> LoadFromArtFile` is a direct internal branch at `0x29c80`, while `LoadFromArtFile` reaches one undefined lazy-bound libSystem `bsearch` stub at `0x294f4` with comparator `0x25c08`. Lion re-proves the identical Rosetta-cache contract, the accepted 10.7.5 / 11G63 ArtFile identity and geometry, and the absence of a PPC slice in the on-disk Lion CoreUI.

The integration boundary is therefore closed positively. Current `main` advances to `docs/pm-showwindow-artfile-titlebar-bsearch-compat-integration.md`. The prepared PPC dylib interposes only `bsearch`, requires the exact old CoreUI call relationship plus archive geometry, translates only the three already-proven Snow keys into a temporary search-record copy, and leaves CoreUI's source path and ArtFile mapping untouched. A Snow passthrough control is mandatory before the single authorized Lion ShowWindow run.

## Current boundary

```text
exact three-key translation policy                PROVEN
Snow/Lion release-resource guards                 PROVEN
non-target identity behavior                      PROVEN
old Load -> LoadFromArtFile call                  DIRECT INTERNAL BRANCH
old LoadFromArtFile -> bsearch stub               PROVEN / one lazy-bound external
chosen interposition boundary                     libSystem bsearch
live bsearch interposer                           PREPARED / NOT YET LIVE-PROVEN
Snow passthrough control                          next
Lion PPC ShowWindow rerun                         one run after Snow PASS
CoreUI/ArtFile patch                              NO
XNU                                               no change indicated
```
