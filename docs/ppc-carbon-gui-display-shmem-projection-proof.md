# PPC Carbon GUI display-shmem one-record projection proof

## Status

**COMPLETE — CAUSAL ONE-RECORD PROJECTION PASSES / STATIC INTEGRATION-SEAM AUDIT NEXT.**

The returned controls close the proof gate. Snow Leopard PPC returns the expected nonzero main-display ID with zero projection writes. On Lion, translated PPC starts with a zero public main-display ID, temporarily installs the already-proven +0x1c semantic window in one process-local record while locked, returns the same nonzero display ID as native Lion, restores the original local pointer before unlock, leaves the source record unchanged, and finishes with protected hashes unchanged and no new diagnostics.

This establishes that the record-layout mismatch is causally sufficient to explain the main-display lookup failure. It does not authorize a persistent partial projection or identify the production insertion point. The proof procedure below is retained as the completed reproducible control.

The Snow PPC public wrapper is exact: lock display, update all display info, call lookupMainDisplay(1), read the returned local-entry record ID, then unlock. The static audit also proves that lookupMainDisplay can reach the mapping initializer only when selector/source/local state is absent. Once those objects are non-NULL, the scan uses the process-local local-mapping entry.

The already accepted semantic-field audit supplies the exact lookup window:

~~~text
Snow +0x0f4..+0x113  <-  Lion +0x110..+0x12f
delta                 = +0x1c
~~~

The proof does not attempt a general 0x17c-to-0x150 conversion. It copies the current Lion record into a private 0x150-byte stack buffer and shifts only this already-proven 0x20-byte window. It also requires projected Snow +0x10e != 0 and projected Snow +0x110 == 0. That selects the statically proven direct-return branch of lookupMainDisplay(1), so lookupDisplay and bindDisplayMapping are unreachable while the projection is installed.

## Prepared artifacts

~~~text
tests/ppc-carbon-gui-display-shmem-projection-proof.c
  Git blob a19bc7bde9059bf768f3a0ac78693ae2c807ce77

scripts/build-ppc-carbon-gui-display-shmem-projection-proof-on-snowleopard.sh
  Git blob 6d41553be591dd85f9dc3160099f539b004217ee

scripts/run-snowleopard-ppc-carbon-gui-display-shmem-projection-proof-control.sh
  Git blob d116929a9147bc12e9ef92dfdf7a7e53b4f56b02

scripts/run-lion-ppc-carbon-gui-display-shmem-projection-proof.sh
  Git blob 2b70156deb84076bd34a6baa401b257b3d4784c2
~~~

Probe contract:

~~~text
proof_contract=carbon-gui-display-shmem-projection-proof-v1
~~~

The translated PPC proof derives lockDisplay, updateAllDisplayInfoAsNeeded, lookupMainDisplay, and unlockDisplay from the loaded exported CGSMainDisplayID using the exact same-__TEXT deltas established by the call-boundary audit, validates their prologues, and resolves selector/source/local globals from the loaded lookupMainDisplay PPC PIC sequence.

## What the Lion proof writes

Exactly two writes are permitted, both to the first pointer field of one process-local 0x58 local-mapping entry allocated by Snow CoreGraphics: first install the address of the stack-owned projected record, then immediately restore the original pointer after lookupMainDisplay(1) returns.

The pointer is installed only after updateAllDisplayInfoAsNeeded has returned while the display lock is held, and it is restored before unlockDisplay. Therefore the normal release/rebind path and notification path cannot observe the projected record. The probe performs zero writes to the Lion source mapping, selector/source globals, CoreGraphics text/data, WindowServer, Rosetta, or XNU.

## Lion proof preconditions

The proof intentionally accepts only the narrow state already observed in the causal snapshot:

- translated PPC public CGSMainDisplayID() is zero before the proof;
- active selector, source slot, and local slot are valid;
- the active Lion source contains exactly one display record;
- the local entry original record pointer equals source + 0x20;
- raw Lion-at-Snow offset +0x10e is zero;
- native Lion main-candidate byte +0x12a is nonzero;
- after the exact +0x1c projection, Snow +0x110 is zero.

Any deviation is a STOP condition. Do not broaden the projection, alter the display setup, or add another compatibility rule to make the proof pass.

## Phase A — build on Snow Leopard

On Snow Leopard 10.6.8 / 10K549, pull current runtime main and build:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-display-shmem-projection-proof-on-snowleopard.sh
~~~

This creates:

~~~text
ppc-carbon-gui-display-shmem-projection-proof-private-dyld
ppc-carbon-gui-display-shmem-projection-proof-private-dyld.info.txt
ppc-carbon-gui-display-shmem-projection-proof-private-dyld.sha256
lion-i386-display-shmem-projection-proof
lion-i386-display-shmem-projection-proof.info.txt
lion-i386-display-shmem-projection-proof.sha256
~~~

The PPC executable must have LC_LOAD_DYLINKER /usr/oah/dyld.

## Phase B — Snow positive control

Still on Snow, run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-display-shmem-projection-proof-control.sh
~~~

Require:

~~~text
proof_mode=snow-ppc-control
helper_address_validation=PASS
runtime_globals_in_segments=YES
selected_state_ready=YES
baseline_public_main_display_id_zero=NO
private_lookup_matches_public=YES
process_local_pointer_write_count=0
projection_applied=NO
server_owned_shared_record_write_attempts=0
proof_complete=YES
RESULT: DISPLAY_SHMEM_PROJECTION_PROOF_SNOW_PASS
RESULT: PASS
~~~

If the Snow control fails, stop and return only ppc-carbon-gui-display-shmem-projection-proof-snow.txt. Do not proceed to Lion.

## Phase C — transfer exact build products

After Snow passes, transfer the exact PPC/i386 executables and their .sha256 sidecars to the Lion runtime checkout. Do not rebuild them on Lion.

## Phase D — one Lion proof

On Lion 10.7.5 / 11G63, from the logged-in Aqua console user's Terminal session, run exactly once:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-display-shmem-projection-proof.sh
~~~

The runner first records a native i386 CGSMainDisplayID reference, then runs the translated PPC proof under the existing accepted connection prerequisite stack only.

Require:

~~~text
native_main_display_id_zero=NO

proof_mode=lion-ppc-translated
helper_address_validation=PASS
runtime_globals_in_segments=YES
baseline_public_main_display_id_zero=YES
record_count_exactly_one=YES
local_record_matches_source_record=YES
projection_fast_path_guard=PASS
projection_applied=YES
process_local_pointer_write_count=2
projection_lookup_returned_target_entry=YES
projection_record_still_installed_after_lookup=YES
source_record_unchanged=YES
local_record_pointer_restored=YES
selected_state_ready=YES
server_owned_shared_record_write_attempts=0
after_public_main_display_id_zero=YES
proof_complete=YES
RESULT: PASS

native_projected_ids_match=YES
protected_hashes_unchanged=YES
new_diagnostics=none
RESULT: DISPLAY_SHMEM_PROJECTION_PROOF_LION_PASS
RESULT: PASS
~~~

after_public_main_display_id_zero=YES is intentional: the projection is restored before the final public control call. The proof is that the locked Snow lookup returns the same nonzero ID as native Lion while the private record view is installed, not that compatibility behavior has been made persistent.

## Return evidence

After both controls pass, return only:

~~~text
ppc-carbon-gui-display-shmem-projection-proof-snow.txt
ppc-carbon-gui-display-shmem-projection-proof-lion.txt
~~~

If Lion fails, return the Lion report without rerunning or broadening the projection.

## Completion result and next step

The Snow and Lion one-record proof remains complete: the private +0x1c Snow view repairs the translated PPC main-display lookup itself, and restoration intentionally returns the public Lion result to zero afterward.

The subsequent integration-seam audit is also complete. It found no named interposable HIToolbox boundary for the seven event-location/display candidates, so the project must not add a naive _CGSMainDisplayID interposer. Because that audit used a preselected candidate list, the next static step is broader rather than live: docs/ppc-carbon-gui-titlebar-coregraphics-import-closure-audit.md enumerates every HIToolbox import that resolves to a CoreGraphics text symbol and computes the direct-call closure from the titlebar tracking roots.

No live adapter, CoreGraphics/HIToolbox patch, persistent projection, original GUI rerun, display-ID substitution/normalization, or XNU change is authorized until that closure is reviewed.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not mutate the server-owned Lion display shared memory.
- Do not write selector or source-array globals.
- Do not leave the local-entry pointer redirected across update/rebind or unlock.
- Do not change the source/local array ownership model.
- Do not substitute or normalize display IDs.
- Do not patch CGSMainDisplayID, mapping initializers, or private HIToolbox.
- Do not add or broaden a display-shmem transport adapter.
- Do not rewrite event, hit-test, or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
