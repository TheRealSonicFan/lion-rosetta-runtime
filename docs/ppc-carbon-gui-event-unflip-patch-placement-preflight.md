# PPC Carbon GUI event-unflip patch-placement preflight

## Status

**NEXT STEP — MEASURE THE LOADED ONE-CALLSITE ROUTE BEFORE ANY COREGRAPHICS TEXT WRITE.**

The static callsite-patchability reports pass on both pinned releases. On Snow PPC the zero-cache event-unflip block contains exactly one direct call to _CGSGetDisplayBounds at standalone address 0x14c38c, with exact file bytes 4b ff 70 2d. The preceding instruction places the existing stack CGRect at r4, and the following instruction checks the returned CGError in r3. The existing success path then caches bounds height from stack offset +0x5c into event +0xc6. This closes the semantic patch surface at one PPC call instruction; neither global _CGSMainDisplayID nor global _CGSGetDisplayBounds behavior needs to be changed.

The remaining unknowns are runtime placement properties, not record semantics. A PPC relative bl reaches only +/-32 MiB. The next preflight therefore measures the loaded translated-PPC CoreGraphics callsite, confirms that its in-memory word still matches 0x4bff702d and still decodes to the expected _CGSGetDisplayBounds target, records current and maximum VM protections for that text region, and checks whether an inert separately loaded PPC marker function is directly reachable. If it is not, the probe inventories whether any unmapped page-sized gap exists inside the legal branch window.

This is intentionally non-patching. The probe performs zero CoreGraphics writes, zero vm_protect calls, zero vm_allocate calls, zero executable-page allocations, and zero private CoreGraphics calls. The marker dylib has no constructor and its marker function is resolved but never executed.

## Prepared artifacts

Current runtime main provides:

~~~text
tests/ppc-carbon-gui-event-unflip-patch-placement-preflight.c
tests/ppc-carbon-gui-event-unflip-placement-marker.c
scripts/build-ppc-carbon-gui-event-unflip-patch-placement-preflight-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-event-unflip-patch-placement-preflight.sh
scripts/run-lion-ppc-carbon-gui-event-unflip-patch-placement-preflight.sh
preflight_contract=carbon-gui-event-unflip-patch-placement-preflight-v1
probe_blob=8c30b99ecce4870c57f8192960cc1a774dc3136c
marker_blob=e83a0a219f35f7f56453904c64c534b843a1e183
build_script_blob=9d3d40452e16a92e1900ab69843199e828ed5876
snow_runner_blob=6c9628d33af20837eec9f6a89cd7bdb64aab6516
lion_runner_blob=d119346788b9fc86c547dd642d5fdce3dce9988e
~~~

The build creates one PPC executable using /usr/oah/dyld and one inert PPC dylib used only as a placement marker. Transfer the exact build products and SHA-256 sidecars from Snow to Lion; do not rebuild them on Lion.

## Phase A — build on Snow Leopard

Architecture validation note: current main accepts a thin 32-bit PPC Mach-O either through `lipo -verify_arch` or, for older Snow Leopard `lipo` behavior, through a guarded `/usr/bin/file` fallback that rejects `ppc64`. A `file` result of `Mach-O ... ppc` is therefore a valid 32-bit PPC result for this gate.

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-event-unflip-patch-placement-preflight-on-snowleopard.sh
~~~

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
preflight_mode=snow-ppc-control
main_prologue_match=YES
bounds_call_runtime_word_match=YES
decoded_bounds_target_match=YES
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
temporary_executable_mapping_attempts=0
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
preflight_mode=lion-ppc-translated
main_prologue_match=YES
bounds_call_runtime_word_match=YES
decoded_bounds_target_match=YES
runtime_regions_resolved=YES
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
temporary_executable_mapping_attempts=0
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

If NONE_OBSERVED is returned, do not broaden to a global CoreGraphics patch. The next static branch should inventory nearby CoreGraphics symbol stubs and review an exact-return-address interposition route that preserves the imported function for every non-target caller.

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
