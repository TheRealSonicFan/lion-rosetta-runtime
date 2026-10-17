# PPC Carbon GUI event-unflip near-stub interposition audit

## Status

**COMPLETE — `_dladdr` IS THE SELECTED LR-PRESERVING EXISTING-STUB ROUTE.**

The corrected patch-placement preflight has now passed on both pinned systems. Snow Leopard PPC and Lion translated PPC resolve the same audited event-unflip branch word and target. On Lion the callsite is currently read-only but has maximum `rwx` protection; that is only a VM-protection observation and does not authorize a text write. The separately loaded marker is far outside the PPC relative-branch window, no unmapped page-sized candidate was observed in that window, and the placement result is `NONE_OBSERVED` on both systems. The preflight performed no text write, `vm_protect`, `vm_allocate`, executable mapping, private CoreGraphics call, or original GUI launch.

That closes the direct-helper and near-page branches for now. Do not jump from `callsite_region_max_write=YES` to a text-writability experiment. The next branch is static: inventory the existing CoreGraphics symbol stubs already resident near the Snow-PPC callsite and determine whether one can serve as a process-local indirection point for an exact-return-address interposer. The intended future shape, if the static evidence supports it, is one patched PPC `bl` from the already-audited callsite to an existing imported-symbol stub; the stub itself and its indirect-symbol entry remain unchanged; an interposed target recognizes only return address `0x0014c390` as the event-unflip repair call and forwards every non-target invocation to the original imported function unchanged.

This audit does **not** choose or load an interposer, modify the callsite, change page protections, or run the GUI subject. It only captures the stub table, stub references, imported-symbol inventory, and raw stub-section words needed to select or reject that route.

## Observed result — `_dladdr` selected

Both returned captures pass with the pinned images and zero mutation. Snow's `__TEXT,__picsymbolstub1` contains 615 32-byte entries. The `_dladdr` entry is at `0x006710dc`; its raw body saves LR, restores LR before the indirect transfer, loads the lazy target into CTR, and ends in `bctr`. The disassembly contains exactly one existing CoreGraphics branch through that stub, at `0x001664d8`, and the import is `undefined [lazy bound]` from libSystem.

From the already-audited event-unflip callsite `0x0014c38c`, the displacement to the `_dladdr` stub is `0x00524d50`, producing PPC `bl` word `0x48524d51`. This is comfortably inside the +/-32 MiB range. `dladdr(const void *, Dl_info *)` also gives the narrowest practical ABI among the one-call candidates: two GPR arguments and an integer return, with observational normal behavior. A future process-local `__interpose` replacement can guard only return address `0x0014c390` and forward every other call through the original replacee, following the same replacee-preservation pattern already used by the accepted titlebar `bsearch` interposer.

The route is therefore selected without changing any stub or indirect-symbol entry. The reversible loaded-text mutability gate and the subsequent `_dladdr` binding/guard preflight now pass on both Snow and Lion: the selected stub reaches the interposer, ordinary calls preserve `dladdr` results through the saved replacee, the exact event-unflip return guard rejects adjacent addresses, and target-wrapper execution remains zero. Current `main` now advances to `docs/ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.md`, which executes the actual patched callsite once on a synthetic event under the unchanged fail-closed wrapper before any functional display-source helper is introduced.

## Current evidence being advanced

The returned placement reports establish:

- Snow 10.6.8 / 10K549: `bounds_call_runtime_word=0x4bff702d`, decoded target matches, callsite region `r--` with maximum `rwx`, marker out of range, no unmapped near-page candidate, `placement_route=NONE_OBSERVED`, bytes unchanged, PASS.
- Lion 10.7.5 / 11G63 translated PPC: the same branch word and decoded target, callsite region `r--` with maximum `rwx`, marker out of range, no unmapped near-page candidate, `placement_route=NONE_OBSERVED`, bytes unchanged, protected hashes unchanged, PASS.

The exact Snow-PPC static patch constants remain:

```text
_CGSGetUnflippedEventLocation = 0x0014c348
bounds callsite              = 0x0014c38c
return address after bl      = 0x0014c390
_CGSGetDisplayBounds target  = 0x001433b8
original call word           = 0x4bff702d
```

The translated Lion runtime addresses from the accepted preflight are intentionally not hard-coded into a future patch; they are evidence for the current load only. The route review is anchored in Snow-PPC image-relative addresses and the accepted Rosetta-cache identity.

## Prepared collector

Current runtime `main` provides:

```text
scripts/collect-ppc-carbon-gui-event-unflip-near-stub-audit.sh
```

The collector is read-only with respect to system state. It creates only a temporary thin architecture slice under `/tmp`, removes it automatically, and writes the requested report. It records:

- pinned CoreGraphics slice SHA-256;
- `otool -Iv` indirect symbol/stub inventory;
- every `otool -tvV` branch annotated as `symbol stub for:`;
- undefined/lazy imported-symbol lines from `nm -m`;
- stub-section metadata from `otool -l`;
- raw words for `__stubs`, `__symbol_stub1`, and `__picsymbolstub1` when present;
- on Lion, accepted Rosetta shared-cache/map provenance and CoreGraphics presence in the cache map.

## Phase A — Snow Leopard PPC static capture

On Snow Leopard 10.6.8 / 10K549, pull current `main` and run:

```sh
/bin/bash ./scripts/collect-ppc-carbon-gui-event-unflip-near-stub-audit.sh \
  ./ppc-carbon-gui-event-unflip-near-stub-snow.txt
```

Require at minimum:

```text
mode=snow
required_arch=ppc7400
slice_exact=YES
prior_patch_placement_result=NONE_OBSERVED
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
helper_or_interposer_load_attempts=0
original_gui_launch_count=0
patch_callsite=0x0014c38c
patch_return_address=0x0014c390
original_bounds_target=0x001433b8
original_call_word=0x4bff702d
RESULT: NEAR_STUB_AUDIT_CAPTURE_PASS
RESULT: PASS
```

If this phase fails, stop and return only the Snow report. Do not run a live PPC subject to compensate for missing static evidence.

## Phase B — Lion environment/reference capture

Only after Snow passes, on Lion 10.7.5 / 11G63 pull current runtime `main` and run:

```sh
/bin/bash ./scripts/collect-ppc-carbon-gui-event-unflip-near-stub-audit.sh \
  ./ppc-carbon-gui-event-unflip-near-stub-lion.txt
```

Require at minimum:

```text
mode=lion
required_arch=i386
slice_exact=YES
rosetta_cache_expected=YES
rosetta_cache_map_expected=YES
coregraphics_present_in_rosetta_cache_map=YES
translated_ppc_stub_inventory_source=PINNED_SNOW_PPC_COREGRAPHICS
prior_patch_placement_result=NONE_OBSERVED
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
helper_or_interposer_load_attempts=0
original_gui_launch_count=0
RESULT: NEAR_STUB_AUDIT_CAPTURE_PASS
RESULT: PASS
```

This Lion phase is only an environment/reference guard. The translated PPC stub inventory comes from the pinned Snow PPC CoreGraphics image already proven identical to the Rosetta shared-cache code source used by the restored stack.

## Return evidence

Return only:

```text
ppc-carbon-gui-event-unflip-near-stub-snow.txt
ppc-carbon-gui-event-unflip-near-stub-lion.txt
```

## Review questions after the capture

The returned Snow report will be used to answer five questions before any live modification is designed:

1. Which existing Snow-PPC CoreGraphics symbol stubs are within the legal +/-32 MiB displacement from `0x0014c38c`?
2. Which of those stubs use an LR-preserving tail transfer (for example a final `bctr`, not `bctrl`) so the target can discriminate exact return address `0x0014c390`?
3. Which candidate has the narrowest pre-existing caller surface, and what original imported function must be preserved for every non-target return address?
4. Can the route keep the chosen stub bytes and indirect-symbol entry untouched, so the only eventual CoreGraphics text mutation remains the already-audited one-word callsite?
5. If a candidate survives, what separate reversible proof is required before any callsite text write or process-local interposer is attempted?

The returned evidence selects `_dladdr` as the route, and the subsequent reversible write/restore proof has now passed on both pinned systems without executing it. The next proof is `docs/ppc-carbon-gui-event-unflip-dladdr-guard-preflight.md`; it must prove original-replacee forwarding, Snow passthrough, Lion binding, exact target classification, adjacent-address rejection, and zero target-wrapper execution before any patched-route execution or functional display helper is considered.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not write CoreGraphics or HIToolbox text or data.
- Do not call `vm_protect` or `vm_allocate` for this audit.
- Do not allocate a branch island or executable trampoline.
- Do not load a new helper/interposer.
- Do not modify any symbol stub or indirect-symbol pointer.
- Do not build the functional source-scan helper yet.
- Do not modify process-local display pointers or server-owned display shared memory.
- Do not normalize/substitute display IDs or rewrite event/movement payloads.
- Keep the accepted Process Manager/CoreServices/Security/CGS compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, shared-cache files, or XNU.
