# PPC Carbon GUI event-unflip patch-placement preflight

## Status

**COMPLETE — BOTH V2 PREFLIGHTS PASS; `NONE_OBSERVED` SELECTS THE STATIC NEAR-STUB AUDIT.**

The static callsite-patchability reports pass on both pinned releases. On Snow PPC the zero-cache event-unflip block contains exactly one direct call to _CGSGetDisplayBounds at standalone address 0x14c38c, with exact file bytes 4b ff 70 2d. The preceding instruction places the existing stack CGRect at r4, and the following instruction checks the returned CGError in r3. The existing success path then caches bounds height from stack offset +0x5c into event +0xc6. This closes the semantic patch surface at one PPC call instruction; neither global _CGSMainDisplayID nor global _CGSGetDisplayBounds behavior needs to be changed.

The remaining unknowns are runtime placement properties, not record semantics. A PPC relative bl reaches only +/-32 MiB. The next preflight therefore measures the loaded translated-PPC CoreGraphics callsite, confirms that its in-memory word still matches 0x4bff702d and still decodes to the expected _CGSGetDisplayBounds target, records current and maximum VM protections for that text region, and checks whether an inert separately loaded PPC marker function is directly reachable. If it is not, the probe inventories whether any unmapped page-sized gap exists inside the legal branch window.

This is intentionally non-patching. The probe performs zero CoreGraphics writes, zero vm_protect calls, zero vm_allocate calls, zero executable-page allocations, and zero private CoreGraphics calls. The marker dylib has no constructor and its marker function is resolved but never executed.

## Observed result — both pinned systems

The returned Snow 10.6.8 / 10K549 and Lion 10.7.5 / 11G63 v2 reports both pass. In both runs the loaded PPC branch word is still `0x4bff702d`, decodes to the audited `_CGSGetDisplayBounds` target, and remains unchanged after the probe. The callsite region is currently `r--` with maximum `rwx`; the inert marker is outside the PPC relative-branch window; no unmapped page-sized candidate was observed within that window; and `placement_route=NONE_OBSERVED`. The Lion runner also confirms the protected compatibility-stack hashes remain unchanged.

`callsite_region_max_write=YES` remains only a protection observation. It does not authorize a text write or a `vm_protect` experiment. Because neither direct marker placement nor an unmapped near page is available, the subsequent near-stub audit was completed and selected the existing Snow-PPC `_dladdr` stub. The current procedure is now `docs/ppc-carbon-gui-event-unflip-dladdr-write-restore-preflight.md`.

## Prepared artifacts

Current runtime main provides:

~~~text
tests/ppc-carbon-gui-event-unflip-patch-placement-preflight.c
tests/ppc-carbon-gui-event-unflip-placement-marker.c
scripts/build-ppc-carbon-gui-event-unflip-patch-placement-preflight-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-event-unflip-patch-placement-preflight.sh
scripts/run-lion-ppc-carbon-gui-event-unflip-patch-placement-preflight.sh
preflight_contract=carbon-gui-event-unflip-patch-placement-preflight-v2
probe_blob=7c76c68aa5d2531458fbba90bf7884f4c02f849c
marker_blob=e83a0a219f35f7f56453904c64c534b843a1e183
build_script_blob=c3fe886e26ef62d31d15a7c69b00624f0c461e77
snow_runner_blob=e07063d0ad36643af92c1dd666902b784719e6fd
lion_runner_blob=a638069b20b005a68a788becd35825815e53e3b5
~~~

The build creates one PPC executable using /usr/oah/dyld and one inert PPC dylib used only as a placement marker. Transfer the exact build products and SHA-256 sidecars from Snow to Lion; do not rebuild them on Lion.

### Harness correction after the first Snow run

The first Phase B failure was in the preflight harness, not in the target binary. The runner tried to extract a generic `ppc` CoreGraphics slice even though the pinned Snow slice is `ppc7400`, and it handed `lipo` a path already created by `mktemp`. Current main now extracts `ppc7400` with both Snow-compatible command forms, removes the temporary placeholder before `lipo -output`, and only falls back to copying CoreGraphics when `file` proves it is already a non-64-bit thin PPC image. The exact slice SHA-256 remains the gate.

Review of the other phases found two additional harness defects before they could affect evidence. The architecture fallback now strips the filename prefix from `file` output before matching `ppc`, so a filename containing the string "ppc" cannot satisfy the gate by itself. The probe also previously declared `loaded_callsite_bytes_unchanged=YES` while testing an uninitialized local; contract v2 now rereads the loaded branch word and compares it with the original value. Both Snow and Lion runners additionally require the v2 contract marker, exported inert-marker symbol, runtime-region resolution, main-prologue match, zero mutation/allocation/private-call/original-GUI counters, and the real unchanged-callsite result before PASS.

Because the probe source and contract changed, discard the previously built Phase A products and rebuild them from current main before rerunning Phase B. Phase C must use those exact rebuilt binaries and sidecars.

## Phase A — build on Snow Leopard

Architecture validation note: current main accepts a thin 32-bit PPC Mach-O either through `lipo -verify_arch` or, for older Snow Leopard `lipo` behavior, through a guarded `/usr/bin/file` fallback that rejects `ppc64`. A `file` result of `Mach-O ... ppc` is therefore a valid 32-bit PPC result for this gate.

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-event-unflip-patch-placement-preflight-on-snowleopard.sh
~~~

The build now also verifies that the probe embeds the v2 contract marker and that the inert marker symbol is globally exported before writing sidecars.

This creates:

~~~text
ppc-carbon-gui-event-unflip-patch-placement-preflight-private-dyld
ppc-carbon-gui-event-unflip-patch-placement-preflight-private-dyld.info.txt
ppc-carbon-gui-event-unflip-patch-placement-preflight-private-dyld.sha256
ppc-carbon-gui-event-unflip-placement-marker.dylib
ppc-carbon-gui-event-unflip-placement-marker.dylib.info.txt
ppc-carbon-gui-event-unflip-placement-marker.dylib.sha256
~~~

## Phase B — Snow runtime control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-event-unflip-patch-placement-preflight.sh
~~~

Require at minimum:

~~~text
preflight_contract=carbon-gui-event-unflip-patch-placement-preflight-v2
preflight_mode=snow-ppc-control
runtime_regions_resolved=YES
main_prologue_match=YES
bounds_call_runtime_word_match=YES
decoded_bounds_target_match=YES
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
temporary_executable_mapping_attempts=0
private_coregraphics_call_count=0
original_gui_launch_count=0
loaded_callsite_bytes_unchanged=YES
preflight_complete=YES
protected_hashes_unchanged=YES
RESULT: PATCH_PLACEMENT_PREFLIGHT_SNOW_PASS
RESULT: PASS
~~~

The direct-marker reachability and unmapped-gap result are observations, not Snow pass/fail requirements.

If Snow fails, stop and return only ppc-carbon-gui-event-unflip-patch-placement-preflight-snow.txt.

## Phase C — Lion translated-PPC preflight

After Snow passes, transfer the exact executable, marker dylib, and both SHA-256 sidecars to the current Lion runtime checkout. From the logged-in Aqua console user session run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-event-unflip-patch-placement-preflight.sh
~~~

The Lion runner uses only the already accepted Process Manager/CoreServices/Security/CGS compatibility stack plus the inert marker dylib.

Require at minimum:

~~~text
preflight_contract=carbon-gui-event-unflip-patch-placement-preflight-v2
preflight_mode=lion-ppc-translated
main_prologue_match=YES
bounds_call_runtime_word_match=YES
decoded_bounds_target_match=YES
runtime_regions_resolved=YES
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
temporary_executable_mapping_attempts=0
private_coregraphics_call_count=0
original_gui_launch_count=0
loaded_callsite_bytes_unchanged=YES
preflight_complete=YES
protected_hashes_unchanged=YES
RESULT: PATCH_PLACEMENT_PREFLIGHT_LION_PASS
RESULT: PASS
~~~

Also preserve these decision markers exactly as emitted:

~~~text
callsite_region_protection=...
callsite_region_max_protection=...
callsite_region_current_write=YES|NO
callsite_region_max_write=YES|NO
direct_marker_branch_reachable=YES|NO
near_unmapped_page_candidate=YES|NO
placement_route=DIRECT_MARKER_DYLIB|UNMAPPED_NEAR_PAGE_CANDIDATE|NONE_OBSERVED
~~~

## Return evidence

After both phases pass, return only:

~~~text
ppc-carbon-gui-event-unflip-patch-placement-preflight-snow.txt
ppc-carbon-gui-event-unflip-patch-placement-preflight-lion.txt
~~~

## Decision gate after the preflight

If DIRECT_MARKER_DYLIB is observed on Lion, the next review can design a proof-only helper dylib whose entry remains within the proven PPC branch range, followed by a separate reversible text-write proof for the single call instruction. Do not assume a future rebuilt dylib will remain at the same address unless its placement contract is pinned.

If the marker is out of range but UNMAPPED_NEAR_PAGE_CANDIDATE is observed, do not allocate or execute a trampoline yet. The next step must prove that one exact candidate page can be allocated process-locally, changed to executable protection, and deallocated without a code write; only after that may a near branch island be considered.

If NONE_OBSERVED is returned, do not broaden to a global CoreGraphics patch. The next static branch should inventory nearby CoreGraphics symbol stubs and review an exact-return-address interposition route that preserves the imported function for every non-target caller. **This is the observed result on both returned v2 reports; follow `docs/ppc-carbon-gui-event-unflip-near-stub-interposition-audit.md` next.**

The callsite_region_max_write marker is only a protection observation. No text-writability conclusion is authorized until a separate reversible protection/write proof is explicitly reviewed.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not write CoreGraphics or HIToolbox text or data.
- Do not call vm_protect on CoreGraphics.
- Do not call vm_allocate for a trampoline or branch island.
- Do not execute the placement marker.
- Do not build the functional source-scan helper yet.
- Do not modify process-local display pointers.
- Do not persist or broaden the one-record projection.
- Do not mutate server-owned display shared memory.
- Do not normalize or substitute display IDs.
- Do not rewrite event or movement payloads.
- Keep the accepted compatibility stack unchanged except for loading the inert marker dylib in this preflight.
- Do not modify WindowServer, Rosetta caches, dyld, any shared-cache file, or XNU.
