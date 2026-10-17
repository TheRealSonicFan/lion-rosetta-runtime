# PPC Carbon GUI event-unflip `dladdr` guard/interposition preflight

## Status

**NEXT STEP — PROVE THE SELECTED `_dladdr` INTERPOSITION BINDING AND EXACT RETURN-ADDRESS GUARD WITHOUT EXECUTING THE PATCHED CALLSITE.**

The reversible write/restore preflight has now passed on both pinned systems. Snow Leopard PPC and Lion translated PPC both accepted a temporary write-enable on only the audited callsite page, read back candidate branch word `0x48524d51`, restored original word `0x4bff702d`, restored the original `r--` protection, and ended with the loaded callsite unchanged. Neither run executed the candidate instruction or the selected `_dladdr` stub.

That closes loaded-text mutability as a blocker. It still does **not** authorize executing the patched route. Before the callsite is ever redirected live, the selected process-local `__DATA,__interpose` path must prove four things independently:

1. the original `dladdr` implementation is recoverable through the interpose tuple's replacee pointer;
2. one ABI-correct direct call through the **selected CoreGraphics `_dladdr` stub itself** reaches the proof interposer, is forwarded to that original replacee, and returns the same `Dl_info` result;
3. the target guard resolves the event-unflip return address dynamically as `CGSMainDisplayID + 0x3ff4`, accepts that exact address, and rejects the immediately adjacent `-4` and `+4` addresses;
4. on Lion, under the accepted compatibility stack, the selected stub is interposed while the patched target-wrapper count remains zero.

No functional display-source scan is implemented in this stage. If the target wrapper were reached unexpectedly, the proof interposer fails closed with a nonzero result rather than interpreting the incoming event-unflip ABI as ordinary `dladdr` arguments.

## Prepared artifacts

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-event-unflip-dladdr-guard-interposer.c
tests/ppc-carbon-gui-event-unflip-dladdr-guard-probe.c
scripts/build-ppc-carbon-gui-event-unflip-dladdr-guard-preflight-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-guard-preflight.sh
scripts/run-lion-ppc-carbon-gui-event-unflip-dladdr-guard-preflight.sh
~~~

The interposer contains exactly one 32-bit PPC `__DATA,__interpose` tuple for `dladdr`. It obtains the original routine from that tuple's replacee pointer, not through `RTLD_NEXT`. `dlsym` is used only to resolve the already-audited `CGSMainDisplayID` runtime address for the return-address guard.

The probe forces CoreGraphics to load through its normal ApplicationServices dependency, resolves the interposer's proof helpers, derives the selected `_dladdr` stub runtime address from the same `CGSMainDisplayID` anchor, verifies the audited LR-preserving stub instruction shape in memory, calls that stub exactly once with a valid `dladdr` ABI, and compares its result with a direct call through the saved original replacee in the same process. The interposer counter must increase by exactly one across that selected-stub call. The probe also tests exact/±4-byte guard classification. It performs no CoreGraphics text write and no `vm_protect`.

## Legacy-target provenance rule

Snow Leopard 10.6.8 and Lion 10.7.5 remain offline legacy execution targets. Do not run `git fetch`, `git pull`, `git rev-parse`, `git hash-object`, or any other Git provenance check on either machine.

Obtain and verify current `main` on a modern TLS-capable staging system, transfer that exact verified tree/archive to the legacy Macs, and compare the builder-recorded source SHA-256 values with the SHA-256 values verified on the staging system. Generated executables/dylibs use SHA-256 sidecars on the legacy hosts.

## Phase A — build both PPC artifacts on Snow Leopard

On the modern staging system first verify current `main`, then transfer it to Snow Leopard 10.6.8 / 10K549.

On Snow Leopard run:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-event-unflip-dladdr-guard-preflight-on-snowleopard.sh
~~~

This creates:

~~~text
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib.info.txt
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib.sha256
ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld
ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld.info.txt
ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld.sha256
~~~

Require:

~~~text
both outputs are 32-bit PPC
interposer __DATA,__interpose size = 0x00000008
interposer build ID = event-unflip-dladdr-guard-v1
probe contract = carbon-gui-event-unflip-dladdr-guard-preflight-v1
probe LC_LOAD_DYLINKER = /usr/oah/dyld
legacy_git_blob_check=NOT_REQUIRED
~~~

Compare both recorded `source_sha256=` values in the `.info.txt` files with the same source-file SHA-256 values verified on the modern staging system. Stop if either differs.

## Phase B — Snow Leopard passthrough/guard control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-guard-preflight.sh
~~~

Require at minimum:

~~~text
probe_contract=carbon-gui-event-unflip-dladdr-guard-preflight-v1
preflight_mode=snow-ppc-control
guard_mode=passthrough
target_return_resolved=YES
guard_exact_match=YES
guard_minus4_reject=YES
guard_plus4_reject=YES
original_replacee_available=YES
selected_dladdr_stub_runtime_shape_match=YES
selected_stub_passthrough_result_match=YES
selected_stub_passthrough_info_match=YES
selected_stub_interposer_forward_delta=1
selected_dladdr_stub_direct_probe_calls=1
interposer_target_wrapper_count=0
patched_target_wrapper_executed=NO
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
candidate_instruction_execution_attempts=0
functional_source_helper_load_attempts=0
original_gui_launch_count=0
preflight_complete=YES
protected_hashes_unchanged=YES
RESULT: DLADDR_GUARD_PREFLIGHT_SNOW_PASS
RESULT: PASS
~~~

If Snow fails, stop. Do not transfer or run the Lion phase.

## Phase C — transfer exact built artifacts to Lion

Transfer these exact Snow-built artifacts and sidecars to Lion:

~~~text
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib.info.txt
ppc-carbon-gui-event-unflip-dladdr-guard-interposer.dylib.sha256
ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld
ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld.info.txt
ppc-carbon-gui-event-unflip-dladdr-guard-probe-private-dyld.sha256
~~~

Place the interposer under Lion `payload/` as expected by the runner. Do not rebuild either artifact on Lion.

## Phase D — Lion binding/guard preflight

From the logged-in Aqua console user's Terminal, with the accepted CoreServices/Security/CGS compatibility artifacts unchanged, run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-event-unflip-dladdr-guard-preflight.sh
~~~

The runner inserts the accepted compatibility stack plus only the new proof interposer. It does **not** patch the event-unflip callsite.

Require at minimum:

~~~text
probe_contract=carbon-gui-event-unflip-dladdr-guard-preflight-v1
preflight_mode=lion-ppc-translated
guard_mode=lion-guard-v1
target_return_resolved=YES
guard_exact_match=YES
guard_minus4_reject=YES
guard_plus4_reject=YES
original_replacee_available=YES
selected_dladdr_stub_runtime_shape_match=YES
selected_stub_passthrough_result_match=YES
selected_stub_passthrough_info_match=YES
selected_stub_interposer_forward_delta=1
selected_dladdr_stub_direct_probe_calls=1
interposer_target_wrapper_count=0
patched_target_wrapper_executed=NO
coregraphics_text_write_attempts=0
vm_protect_attempts=0
vm_allocate_attempts=0
candidate_instruction_execution_attempts=0
functional_source_helper_load_attempts=0
original_gui_launch_count=0
preflight_complete=YES
protected_hashes_unchanged=YES
RESULT: DLADDR_GUARD_PREFLIGHT_LION_PASS
RESULT: PASS
~~~

The raw output must also contain the interposer build marker:

~~~text
PM_EVENT_UNFLIP_DLADDR_GUARD_BUILD_ID:event-unflip-dladdr-guard-v1
~~~

and at least one:

~~~text
PM_EVENT_UNFLIP_DLADDR_GUARD:NON_TARGET_PASSTHROUGH
~~~

It must contain no:

~~~text
PM_EVENT_UNFLIP_DLADDR_GUARD:TARGET_MATCH_FAIL_CLOSED
~~~

because the patched target is deliberately not executed in this preflight.

## Return evidence

After both phases pass, return only:

~~~text
ppc-carbon-gui-event-unflip-dladdr-guard-preflight-snow.txt
ppc-carbon-gui-event-unflip-dladdr-guard-preflight-lion.txt
~~~

If either report names an unexpected crash/core diagnostic, return that diagnostic as well.

## Decision gate after this preflight

If Snow proves exact selected-stub passthrough and Lion proves that the selected CoreGraphics `_dladdr` stub itself reaches the interposer, forwards through the saved original replacee with identical `Dl_info`, accepts only the exact target classification, rejects adjacent addresses, leaves the target-wrapper count at zero, and preserves protected hashes, the route is closed at the binding/guard level.

Only then should the next procedure decide how to exercise the exact target path safely. Do **not** immediately launch the original Carbon GUI or fold in the functional display-source scan. The next review must choose between a fail-closed patched-route execution discriminator and a separately callable functional source-helper proof based on the returned binding evidence.

If the interposer does not bind, ordinary `dladdr` results differ, the replacee pointer is unusable, the exact guard fails, either adjacent address is accepted, or the target wrapper executes unexpectedly, stop. Do not relax the return-address guard, patch a global CoreGraphics function, rewrite the indirect symbol pointer, allocate a branch island, or modify XNU.

## Safety boundary

- Do not patch or write the CoreGraphics callsite in this phase.
- Do not call `vm_protect` or `vm_allocate`.
- Do not execute candidate branch word `0x48524d51`.
- Exactly one direct ABI-correct call through the selected `_dladdr` stub is authorized by the prepared probe solely to prove its binding; do not invoke that stub from the event-unflip callsite.
- Do not implement or call the functional display-source scan.
- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not modify any symbol stub, indirect-symbol pointer, shared-cache file, dyld, WindowServer state, or XNU.
