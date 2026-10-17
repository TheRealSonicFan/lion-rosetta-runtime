# PPC Carbon GUI event-unflip callsite patchability audit

## Status

**COMPLETE — ONE PPC CALLSITE SUFFICES / RUNTIME PLACEMENT PREFLIGHT NEXT.**

The direct-source helper contract reports pass on both pinned releases. The source-only branch is now viable at the semantic/lifecycle level: the native Lion main/master/bounds field sets are closed, Lion bounds has no Snow local-entry +0x48 dependency, and display notifications enter _updateAllDisplayInfoAsNeeded under the display lock. The update path may temporarily unlock around mapping initialization or _CGSReleaseAllDisplays, but it reacquires the display lock before returning; server shutdown separately releases displays, frees mapping state, and zeros the source globals. A helper must therefore call the normal update path, re-resolve the active source only after update has returned, fail closed if source state is absent, scan read-only while locked, and never retain a source pointer across calls.

The exact Snow zero-cache body exposes a narrower patch surface than the previous larger-block idea. _CGSGetUnflippedEventLocation calls _CGSMainDisplayID, immediately places its stack CGRect buffer in r4, then directly calls _CGSGetDisplayBounds. The caller already checks the returned CGError, caches the resulting bounds height at event +0xc6 on success, and preserves its existing failure behavior otherwise. A replacement at the single _CGSGetDisplayBounds call can therefore keep the entire event-unflip control flow intact: the helper may ignore the known-bad display ID in r3, fill the existing CGRect * in r4 from the Lion source scan, and return the same success/failure convention. _CGSMainDisplayID may remain unmodified; its zero result is simply not trusted by this one callsite.

The returned reports complete this gate. Snow identifies exactly one replacement site at 0x14c38c with original bytes 4b ff 70 2d; r4 already points to the caller-owned CGRect, r3 carries the CGError result, the normal success path caches the height, and the failure path remains intact. Lion shows the same zero-cache call shape as the native reference. The remaining questions are runtime address/protection and PPC branch placement, not event-unflip semantics.

## Prepared analyzer

Use:

~~~text
scripts/audit-ppc-carbon-gui-event-unflip-callsite-patchability.py
analyzer_version=1
audit_contract=carbon-gui-event-unflip-callsite-patchability-v1
Git blob ccb6943dfeca6e1b233b10884da535ee05041e86
~~~

The analyzer verifies the pinned CoreGraphics slice, resolves the exact event-unflip/main/bounds callsites, maps the candidate instruction back to the Mach-O __TEXT,__text bytes, verifies the caller-owned bounds buffer/cache contract, and records the unresolved runtime constraints: PPC relative-branch reachability and loaded-text writability.

Pinned slices remain:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Phase A — Snow Leopard PPC

Run:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-event-unflip-callsite-patchability.py \
  ./ppc-carbon-gui-event-unflip-callsite-patchability-snow.txt
~~~

Require:

~~~text
mode=snow
slice_exact=YES
main_call_count=1
bounds_call_count=1
snow_main_to_bounds_sequence_exact=YES
snow_bounds_return_status_checked_in_r3=YES
event_cache_offset=0xc6 present=YES
bounds_buffer_offset=0x50 present=YES
bounds_height_offset=0x5c present=YES
candidate_patch_scope=ONE_PPC_CALL_INSTRUCTION
candidate_requires_global_CGSMainDisplayID_patch=NO
candidate_requires_global_CGSGetDisplayBounds_patch=NO
direct_branch_to_future_helper_reachability=UNPROVEN
runtime_text_writability=UNPROVEN
event_unflip_callsite_patchability_audit_exact=YES
RESULT: PASS
~~~

If Snow fails, stop and return only the Snow report.

## Phase B — Lion native reference

Only after Snow passes, run:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-event-unflip-callsite-patchability.py \
  ./ppc-carbon-gui-event-unflip-callsite-patchability-lion.txt
~~~

Require:

~~~text
mode=lion
slice_exact=YES
main_call_count=1
bounds_call_count=1
event_cache_offset=0xbe present=YES
bounds_buffer_offset=0xe8 present=YES
bounds_height_offset=0xf4 present=YES
lion_reference_same_zero_cache_shape=YES
lion_is_patch_target=NO
event_unflip_callsite_patchability_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

Return only:

~~~text
ppc-carbon-gui-event-unflip-callsite-patchability-snow.txt
ppc-carbon-gui-event-unflip-callsite-patchability-lion.txt
~~~

## Decision gate after the audit

The one-callsite branch is closed in favor of a runtime placement preflight. Follow docs/ppc-carbon-gui-event-unflip-patch-placement-preflight.md.

That preflight resolves the loaded translated-PPC callsite from CGSMainDisplayID, verifies the in-memory branch word and decoded target, records current/maximum text protections, measures whether an inert injected PPC marker function is directly reachable within the +/-32 MiB bl window, and inventories any unmapped page-sized candidate inside that window.

It performs no CoreGraphics write, vm_protect, vm_allocate, executable-page allocation, private CoreGraphics call, or original GUI launch. No functional source-scan helper is built yet.
## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not patch CoreGraphics or HIToolbox.
- Do not allocate a branch island or executable trampoline.
- Do not build or load the source helper yet.
- Do not modify process-local display pointers.
- Do not persist or broaden the one-record projection.
- Do not mutate server-owned display shared memory.
- Do not normalize or substitute display IDs.
- Do not rewrite event or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, any shared-cache file, or XNU.
