# PPC Carbon GUI event-unflip `_dladdr` patched-route execution preflight

## Status

**RETRY PHASES A–B WITH THE V3 DEDICATED LEAF ROUTE GUARD. DO NOT ADVANCE TO LION UNLESS THE SNOW CONTROL PROVES ZERO NON-TARGET `dladdr` REENTRY AND EXACT EVENT-COORDINATE PRESERVATION.**

The selected process-local route remains mechanically valid. The audited Snow PPC event-unflip callsite is still the single four-byte `bl _CGSGetDisplayBounds` at image-relative offset `0x3ff0` from `CGSMainDisplayID`; candidate word `0x48524d51` reaches the existing CoreGraphics `_dladdr` `__picsymbolstub1`; the exact return-address guard is `callsite + 4`; and the previous write/restore and binding preflights established that the loaded callsite can be changed and restored without changing the CoreGraphics file.

The second Snow route-execution result (v2) narrows the remaining problem further. Same-process lazy-stub warmup passed completely, the patched route reached the exact target wrapper once, the callsite was restored, the page returned to its original protection, and the synthetic event cache stayed zero. Nevertheless, the output event coordinates were corrupted: input `x=123.5` became `0`, and input `y=45.25` became `9000`. The same interval also increased the interposer's **non-target** forward count by one in addition to the exact target-wrapper delta of one.

That last observation means v2 was still not a clean steady-state route-ABI discriminator. The reused binding/guard interposer performed ordinary C/libc work on its target path (including environment/logging support) and the event interval demonstrably traversed the interposer on an additional non-target `dladdr` call. The audited event-unflip function keeps its input `x/y` live in nonvolatile `f31/f30` across the patched callsite and copies those registers to the output when the replacement returns nonzero. Therefore the v2 corruption cannot yet be assigned uniquely to the selected CoreGraphics stub itself.

Current `main` replaces that v2 proof harness for route execution only. Contract `carbon-gui-event-unflip-dladdr-route-execution-v3` uses a **dedicated route leaf interposer**. Before any CoreGraphics write, the probe resolves the exact target return, validates the route leaf contract, and warms the selected lazy stub once through the ordinary non-target forwarding path. During the patched event call, the exact target path only compares the already-resolved LR value, increments the target counter, and returns the fail-closed nonzero result; it does not resolve symbols, call original `dladdr`, inspect the environment, format/log output, or intentionally invoke any other routine. The probe now additionally requires `patched_route_non_target_delta=0`.

The earlier `ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib` remains the authoritative artifact for the completed binding/guard preflight. **Do not use or rebuild it for this v3 route-execution retry.** The v3 route test builds a separate artifact so the already-passed guard evidence is not overwritten.

## Why the synthetic call is bounded

The audited Snow PPC `_CGSGetUnflippedEventLocation` body receives the caller output point in `r3` and an event record in `r4`. It saves the incoming event coordinates in `f31/f30`, reads cached extent `event+0xc6`, and on a zero cache calls `CGSMainDisplayID` followed by the selected bounds callsite. A nonzero return from that callsite takes the existing failure path, which copies `f31/f30` directly into the caller's output point and does not populate the cached extent.

The prepared probe allocates only a synthetic in-process event buffer, seeds known finite `x/y` values, keeps `event+0xc6` at zero, and invokes the event-unflip function exactly once. A successful discriminator therefore requires all of the following together:

- the selected lazy `_dladdr` stub is warmed exactly once in the same process before any text write, with ordinary result and `Dl_info` matching the saved original replacee;
- the dedicated route interposer reports its target-leaf contract before patching;
- the candidate word is installed and read back exactly;
- data/instruction cache synchronization is issued for the modified word;
- the callsite page is returned to its original protection before the event function is invoked;
- the exact target-wrapper count increases by one during the event call;
- the non-target-forward count does not change during that event call;
- the wrapper's fail-closed nonzero result leaves output `x/y` bit-identical to the synthetic input and leaves `event+0xc6` zero;
- the original call word is restored, cache synchronization is issued again, and final page protection matches the original value.

No original Carbon GUI, window, mouse event, functional source scan, or persistent CoreGraphics modification is part of this proof.

## Prepared artifacts

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-event-unflip-dladdr-route-leaf-interposer.c
tests/ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.c
scripts/build-ppc-carbon-gui-event-unflip-dladdr-route-execution-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
scripts/run-lion-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
~~~

The v3 probe derives all runtime addresses from `CGSMainDisplayID`, verifies the event-unflip prologue, original call word, selected stub shape, route displacement, exact guard target return, and route-leaf helper before any write. It then warms the selected lazy `_dladdr` stub exactly once through the non-target path and verifies the original-replacee result/`Dl_info` match before patching. It never resolves or calls the private event-unflip symbol by name; it uses the already-audited image-relative offset from `CGSMainDisplayID`.

## Legacy-target provenance rule

Snow Leopard 10.6.8 and Lion 10.7.5 remain offline legacy execution targets. Do not run Git provenance checks on either system. Verify current repository content and the two new source SHA-256 values on a modern TLS-capable staging system, transfer that verified tree/archive, and compare the builder-recorded `source_sha256=` values with the staging-system values. Generated artifacts use SHA-256 sidecars on the legacy hosts.

## Phase A — build the v3 leaf guard and route probe on Snow Leopard

On the modern staging system verify current `main`, then transfer that verified tree/archive to Snow Leopard 10.6.8 / 10K549. On Snow run:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-event-unflip-dladdr-route-execution-on-snowleopard.sh
~~~

This creates:

~~~text
ppc-carbon-gui-event-unflip-dladdr-route-leaf-interposer.dylib
ppc-carbon-gui-event-unflip-dladdr-route-leaf-interposer.dylib.info.txt
ppc-carbon-gui-event-unflip-dladdr-route-leaf-interposer.dylib.sha256

ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld
ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld.info.txt
ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld.sha256
~~~

Require the interposer and probe to be 32-bit PPC. Require interposer build ID `event-unflip-dladdr-route-leaf-guard-v1`, one PPC `__DATA,__interpose` tuple, exported route helpers, probe contract `carbon-gui-event-unflip-dladdr-route-execution-v3`, and `LC_LOAD_DYLINKER=/usr/oah/dyld` on the probe. Compare both recorded source SHA-256 values with the values verified on the modern staging system.

## Phase B — Snow fail-closed route execution control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
~~~

Require at minimum:

~~~text
probe_contract=carbon-gui-event-unflip-dladdr-route-execution-v3
preflight_mode=snow-ppc-control
guard_mode=passthrough
guard_target_leaf_contract_dlsym=PASS
guard_target_leaf_contract=PASS
target_return_matches_callsite_plus4=YES
candidate_branch_reachable=YES
candidate_branch_word=0x48524d51
event_unflip_prologue_match=YES
bounds_call_original_word_match=YES
selected_dladdr_stub_runtime_shape_match=YES
original_replacee_helper_dlsym=PASS
selected_stub_warmup_result_match=YES
selected_stub_warmup_info_match=YES
selected_stub_warmup_non_target_delta=1
selected_stub_warmup_target_delta=0
selected_dladdr_stub_direct_probe_calls=1
selected_stub_warmup_complete=YES
callsite_region_max_write=YES
vm_protect_enable_candidate_kr=0
candidate_install_readback_match=YES
vm_protect_candidate_lockdown_kr=0
candidate_execution_protection_match=YES
candidate_instruction_execution_attempts=1
patched_route_target_wrapper_delta=1
patched_route_non_target_delta=0
patched_target_wrapper_executed=YES
event_return_matches_output=YES
event_output_x_preserved=YES
event_output_y_preserved=YES
event_cache_extent_unchanged_zero=YES
failclosed_event_path_preserved=YES
vm_protect_enable_restore_kr=0
original_restore_readback_match=YES
vm_protect_final_restore_kr=0
final_protection_match=YES
loaded_callsite_bytes_restored=YES
vm_protect_attempts=4
coregraphics_text_write_attempts=2
dcache_flush_attempts=2
icache_invalidate_attempts=2
synthetic_event_unflip_calls=1
functional_source_helper_executed=NO
preflight_complete=YES
protected_hashes_unchanged=YES
RESULT: DLADDR_ROUTE_EXECUTION_SNOW_PASS
RESULT: PASS
~~~

The raw log must contain exactly one route-leaf build marker:

~~~text
PM_EVENT_UNFLIP_DLADDR_ROUTE_GUARD_BUILD_ID:event-unflip-dladdr-route-leaf-guard-v1
~~~

Unlike v1/v2, there is intentionally **no target-path log marker**: writing one would reintroduce call-outs into the exact path this experiment is trying to isolate. The counter delta is the target-execution proof.

If Snow fails, stop and return only the Snow report. In particular:

- if the warmup fails, do not patch the callsite;
- if `patched_route_target_wrapper_delta` is not exactly one, the route is not proved;
- if `patched_route_non_target_delta` is not zero, the target interval is still contaminated and must not be interpreted as a clean ABI result;
- if the target delta is one and non-target delta is zero but `x/y` preservation still fails, treat that as evidence against this `_dladdr` route's ABI suitability and stop.

Do not retry by weakening the coordinate gate, removing cache synchronization, leaving the page writable during execution, or introducing the functional helper.

## Phase C — transfer the exact v3 artifacts to Lion

Only after Snow passes, transfer the exact Snow-built route probe and route leaf interposer with their `.info.txt` and `.sha256` sidecars to Lion. Place the route leaf interposer and its sidecar under `payload/`, matching the Lion runner default, and keep the probe plus its sidecar at the repository root. Keep the accepted CoreServices/Security/CGS stack unchanged. Do not rebuild either v3 artifact on Lion.

Do not replace or remove the older passing guard-preflight interposer merely to run this test; it is a separate historical proof artifact.

## Phase D — Lion translated-PPC fail-closed route execution

From the logged-in Aqua console user's Terminal run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
~~~

Require the same warmup, leaf-contract, route, zero-reentry, coordinate-preservation, restoration, cache-synchronization, and single target-wrapper markers as Snow, with:

~~~text
preflight_mode=lion-ppc-translated
guard_mode=lion-guard-v1
guard_target_leaf_contract_dlsym=PASS
guard_target_leaf_contract=PASS
patched_route_target_wrapper_delta=1
patched_route_non_target_delta=0
patched_target_wrapper_executed=YES
event_output_x_preserved=YES
event_output_y_preserved=YES
failclosed_event_path_preserved=YES
loaded_callsite_bytes_restored=YES
final_protection_match=YES
functional_source_helper_executed=NO
protected_hashes_unchanged=YES
RESULT: DLADDR_ROUTE_EXECUTION_LION_PASS
RESULT: PASS
~~~

The raw Lion log must likewise contain exactly one route-leaf build marker and no target-path logging requirement.

## Return evidence

If Snow fails, return only:

~~~text
ppc-carbon-gui-event-unflip-dladdr-route-execution-snow.txt
~~~

If Snow passes and Lion is run, return:

~~~text
ppc-carbon-gui-event-unflip-dladdr-route-execution-snow.txt
ppc-carbon-gui-event-unflip-dladdr-route-execution-lion.txt
~~~

Also return an unexpected crash/core diagnostic if one appears. A process crash cannot persist the process-local patch, but it still fails this gate.

## Decision gate after this preflight

If both systems prove that the actual patched callsite reaches the exact leaf target once with zero non-target `dladdr` reentry, preserves the event-unflip failure path and live coordinates, restores the original word/protection, and preserves protected file hashes, the route is mechanically closed through real execution. The following step should then build a **separately callable functional display-source helper proof** with no callsite patch, so Lion source scanning/main-master selection/bounds production can be validated independently before it is combined with this route.

If either system does not reach the target wrapper exactly once, has any non-target `dladdr` activity during the event interval, takes the synthetic event success path, corrupts `x/y`, cannot restore the callsite/protection, or changes protected hashes, stop. Do not combine routing and functional source logic, broaden the CoreGraphics hook, rewrite the stub/indirect pointer, launch the original GUI, or modify XNU.

## Safety boundary

- Use the dedicated v3 route leaf interposer for this experiment; preserve the older passing binding/guard artifact separately.
- Before patching, perform exactly one ordinary non-target direct call through the selected `_dladdr` stub in the same process and require its passthrough result/`Dl_info` to match the original replacee.
- Resolve and validate the exact target return and leaf contract before modifying CoreGraphics.
- Patch only the one audited four-byte process-local callsite.
- Restore the original page protection before executing the synthetic event call.
- Issue data/instruction-cache synchronization after candidate installation and after restoration.
- Invoke `_CGSGetUnflippedEventLocation` exactly once, with only the probe's synthetic event buffer and output point.
- Require zero non-target `dladdr` delta during that event call.
- Do not execute the original PPC Carbon GUI subject.
- Do not create, move, drag, click, or synthesize a real window event.
- Do not implement or call the functional Lion display-source scan in this phase.
- Do not modify a symbol stub, indirect-symbol pointer, shared-cache file, dyld, WindowServer state, Rosetta cache, or XNU.
