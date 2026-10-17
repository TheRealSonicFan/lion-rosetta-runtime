# PPC Carbon GUI event-unflip `_dladdr` patched-route execution preflight

## Status

**NEXT STEP — EXECUTE THE SELECTED ONE-WORD ROUTE ONCE UNDER THE ALREADY-PROVEN FAIL-CLOSED GUARD, USING ONLY A SYNTHETIC EVENT.**

The returned `_dladdr` guard preflights pass on both pinned systems. Snow Leopard PPC and Lion translated PPC both resolve the exact event-unflip return address, accept only that address while rejecting `-4` and `+4`, recover the saved original `dladdr` replacee, and prove that one direct call through the selected CoreGraphics `_dladdr` stub reaches the interposer and returns an identical ordinary `Dl_info` result. In both reports the target-wrapper count remains zero because the patched callsite is deliberately not executed. Protected hashes remain unchanged.

That closes the binding/guard gate. The next unresolved route-specific question is narrower than the functional display repair: whether the actual modified event-unflip callsite, after data/instruction-cache synchronization and with its original page protection restored, executes candidate word `0x48524d51` under Rosetta and arrives at the proof interposer with LR equal to the exact audited return address. This procedure therefore chooses the **fail-closed patched-route execution discriminator before the separately callable functional source-helper proof**. The functional Lion display-source scan remains unimplemented.

The previously passing proof interposer is reused unchanged. Its required SHA-256 is:

~~~text
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib
ee6463df9002dc78a10c50d239486d5b88dd3a8ef4a4923ec453546154c6aa77
~~~

Do not rebuild or modify that interposer for this step. Its target branch already returns nonzero without dereferencing the incoming `r3`/`r4` values or calling the original `dladdr`, which preserves the existing event-unflip failure path.

## Why the synthetic call is bounded

The audited Snow PPC `_CGSGetUnflippedEventLocation` body takes the caller output point in `r3` and an event record in `r4`. Before the selected callsite it reads only event offsets `+0x0c`, `+0x10`, and cached extent `+0xc6`. With cached extent zero it calls `CGSMainDisplayID`, places its stack `CGRect` at `r4`, and executes the audited callsite. If the replacement returns nonzero, the existing failure path copies the original event `x/y` into the caller output and does not populate `event+0xc6`.

The prepared probe allocates only a synthetic in-process event buffer, seeds known finite `x/y` values, keeps `event+0xc6` at zero, and calls the event-unflip function exactly once. A successful discriminator therefore requires all of the following together:

- the candidate word is installed and read back exactly;
- data/instruction cache synchronization is issued for the modified word;
- the callsite page is returned to its original protection **before** the event function is invoked;
- the proof interposer target-wrapper count increases by exactly one;
- the wrapper's fail-closed nonzero result leaves output `x/y` equal to the synthetic input and leaves `event+0xc6` zero;
- the original call word is restored, cache synchronization is issued again, and final page protection matches the original value.

No original Carbon GUI, window, mouse event, functional source scan, or persistent CoreGraphics modification is part of this proof.

## Prepared artifacts

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.c
scripts/build-ppc-carbon-gui-event-unflip-dladdr-route-execution-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
scripts/run-lion-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
~~~

The probe derives all runtime addresses from `CGSMainDisplayID`, verifies the event-unflip prologue, original call word, selected stub shape, route displacement, and guard target return before any write. It never resolves or calls the private event-unflip symbol by name; it uses the already-audited image-relative offset from `CGSMainDisplayID`.

## Legacy-target provenance rule

Snow Leopard 10.6.8 and Lion 10.7.5 remain offline legacy execution targets. Do not run Git provenance checks on either system. Verify current repository content and the new probe source SHA-256 on a modern TLS-capable staging system, transfer that verified tree/archive, and compare the builder-recorded `source_sha256=` value with the staging-system value. Generated artifacts use SHA-256 sidecars on the legacy hosts.

## Phase A — build the new route probe on Snow Leopard

Reuse the exact guard interposer and sidecar from the passing guard preflight. On the modern staging system verify current `main`, then transfer it to Snow Leopard 10.6.8 / 10K549. On Snow run:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-event-unflip-dladdr-route-execution-on-snowleopard.sh
~~~

This creates:

~~~text
ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld
ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld.info.txt
ppc-carbon-gui-event-unflip-dladdr-route-execution-probe-private-dyld.sha256
~~~

Require a 32-bit PPC executable, contract `carbon-gui-event-unflip-dladdr-route-execution-v1`, and `LC_LOAD_DYLINKER=/usr/oah/dyld`. Compare the recorded source SHA-256 with the modern staging-system value. Do not rebuild the guard interposer.

## Phase B — Snow fail-closed route execution control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
~~~

Require at minimum:

~~~text
probe_contract=carbon-gui-event-unflip-dladdr-route-execution-v1
preflight_mode=snow-ppc-control
guard_mode=passthrough
target_return_matches_callsite_plus4=YES
candidate_branch_reachable=YES
candidate_branch_word=0x48524d51
event_unflip_prologue_match=YES
bounds_call_original_word_match=YES
selected_dladdr_stub_runtime_shape_match=YES
callsite_region_max_write=YES
vm_protect_enable_candidate_kr=0
candidate_install_readback_match=YES
vm_protect_candidate_lockdown_kr=0
candidate_execution_protection_match=YES
candidate_instruction_execution_attempts=1
patched_route_target_wrapper_delta=1
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

The raw log must contain exactly one:

~~~text
PM_EVENT_UNFLIP_DLADDR_GUARD:TARGET_MATCH_FAIL_CLOSED
~~~

If Snow fails, stop and return only the Snow report. Do not retry by removing cache synchronization, weakening the guard, leaving the page writable during execution, or introducing the functional helper.

## Phase C — transfer the exact new probe to Lion

Transfer the exact Snow-built route probe plus its `.info.txt` and `.sha256` sidecars to Lion. Keep the exact previously passing guard interposer in `payload/` and keep the accepted CoreServices/Security/CGS stack unchanged. Do not rebuild either artifact on Lion.

## Phase D — Lion translated-PPC fail-closed route execution

From the logged-in Aqua console user's Terminal run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-event-unflip-dladdr-route-execution-preflight.sh
~~~

Require the same route, restoration, cache-synchronization, synthetic-event, and single target-wrapper markers as Snow, with:

~~~text
preflight_mode=lion-ppc-translated
guard_mode=lion-guard-v1
patched_route_target_wrapper_delta=1
patched_target_wrapper_executed=YES
failclosed_event_path_preserved=YES
loaded_callsite_bytes_restored=YES
final_protection_match=YES
functional_source_helper_executed=NO
protected_hashes_unchanged=YES
RESULT: DLADDR_ROUTE_EXECUTION_LION_PASS
RESULT: PASS
~~~

The raw Lion log must likewise contain exactly one `PM_EVENT_UNFLIP_DLADDR_GUARD:TARGET_MATCH_FAIL_CLOSED`.

## Return evidence

After both controls pass, return only:

~~~text
ppc-carbon-gui-event-unflip-dladdr-route-execution-snow.txt
ppc-carbon-gui-event-unflip-dladdr-route-execution-lion.txt
~~~

Also return an unexpected crash/core diagnostic if one appears. A process crash cannot persist the process-local patch, but it still fails this gate.

## Decision gate after this preflight

If both systems prove that the actual patched callsite reaches the exact fail-closed target wrapper once, preserves the event-unflip failure path, restores the original word/protection, and preserves protected file hashes, the route is mechanically closed through real execution. The following step should then build a **separately callable functional display-source helper proof** with no callsite patch, so Lion source scanning/main-master selection/bounds production can be validated independently before it is combined with this route.

If either system does not reach the target wrapper exactly once, if the synthetic event takes the success path, if the callsite or protection cannot be restored, or if protected hashes change, stop. Do not combine routing and functional source logic, broaden the CoreGraphics hook, rewrite the stub/indirect pointer, launch the original GUI, or modify XNU.

## Safety boundary

- Reuse the exact passing proof interposer; do not change its target behavior.
- Patch only the one audited four-byte process-local callsite.
- Restore the original page protection before executing the synthetic event call.
- Issue data/instruction-cache synchronization after candidate installation and after restoration.
- Invoke `_CGSGetUnflippedEventLocation` exactly once, with only the probe's synthetic event buffer and output point.
- Do not execute the original PPC Carbon GUI subject.
- Do not create, move, drag, click, or synthesize a real window event.
- Do not implement or call the functional Lion display-source scan in this phase.
- Do not modify a symbol stub, indirect-symbol pointer, shared-cache file, dyld, WindowServer state, Rosetta cache, or XNU.
