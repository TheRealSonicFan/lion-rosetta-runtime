# PPC Carbon GUI event-unflip `dladdr` route write/restore preflight

## Status

**NEXT STEP — PROVE THE SELECTED ONE-WORD ROUTE CAN BE WRITTEN AND RESTORED WITHOUT EXECUTING IT.**

The near-stub capture passes on both pinned systems and closes the route-selection question. Snow's exact PPC CoreGraphics image contains a 32-byte `__picsymbolstub1` entry for `_dladdr` at `0x006710dc`. The stub saves LR, obtains its PIC base, restores LR before loading the indirect target, moves that target to CTR, and ends in `bctr`; therefore a branch-with-link into the stub preserves the caller's LR for the eventual interposed function. The report shows exactly one existing direct CoreGraphics call through this stub, at `0x001664d8`, and `_dladdr` is an undefined lazy-bound libSystem import.

This is the preferred existing-stub route because `dladdr(const void *, Dl_info *)` has a simple two-GPR / integer-return ABI, its normal operation is observational, and the existing project already uses Mach-O `__DATA,__interpose` with exact caller guards. A future replacement can therefore recognize only event-unflip return address `0x0014c390`; every other `dladdr` call must be forwarded unchanged to the original replacee. No `dladdr` interposer or functional display helper is built in this phase.

The PPC patch constants are now closed:

~~~text
original callsite             0x0014c38c
original return address       0x0014c390
original bounds target        0x001433b8
original call word            0x4bff702d
selected _dladdr stub         0x006710dc
relative displacement         0x00524d50
candidate PPC bl word         0x48524d51
existing CoreGraphics callers 1
existing caller               0x001664d8
~~~

The candidate is well inside the PPC +/-32 MiB branch range. The next unresolved gate is no longer placement: it is whether the loaded translated-PPC callsite can be made writable process-locally, changed to exactly `0x48524d51`, read back, restored to `0x4bff702d`, and returned to its original page protection without executing the changed instruction.

## Prepared probe

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-event-unflip-dladdr-route-write-restore-preflight.c
scripts/build-ppc-carbon-gui-event-unflip-dladdr-write-restore-on-snowleopard.sh
scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-write-restore.sh
~~~

The probe derives the loaded callsite and selected stub from `CGSMainDisplayID`, verifies the original call word and the runtime `_dladdr` stub shape, computes the candidate branch word, and then performs exactly this non-executing sequence:

1. record the original VM protection;
2. add write permission to only the callsite page;
3. write `0x48524d51`;
4. read it back;
5. immediately restore `0x4bff702d`;
6. read the original word back;
7. restore the original page protection;
8. verify the final word and protection.

The candidate instruction is never executed, the `_dladdr` stub is never called, no route interposer/helper is loaded, and the original Carbon GUI is never launched.

## Phase A — build once on Snow Leopard

On Snow Leopard 10.6.8 / 10K549, pull current `main` and run:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-event-unflip-dladdr-write-restore-on-snowleopard.sh
~~~

This creates:

~~~text
ppc-carbon-gui-event-unflip-dladdr-write-restore-private-dyld
ppc-carbon-gui-event-unflip-dladdr-write-restore-private-dyld.info.txt
ppc-carbon-gui-event-unflip-dladdr-write-restore-private-dyld.sha256
~~~

Require a 32-bit PPC executable with `LC_LOAD_DYLINKER=/usr/oah/dyld`. Do not rebuild it on Lion.

## Phase B — Snow reversible-write control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-event-unflip-dladdr-write-restore.sh
~~~

Require at minimum:

~~~text
preflight_contract=carbon-gui-event-unflip-dladdr-write-restore-v1
preflight_mode=snow-ppc-control
candidate_route=EXISTING_DLADDR_PICSYMBOLSTUB1
candidate_import=_dladdr
candidate_static_existing_call_count=1
candidate_stub_lr_preserving=YES
candidate_stub_tail_transfer=BCTR
candidate_branch_reachable=YES
candidate_branch_word=0x48524d51
main_prologue_match=YES
bounds_call_original_word_match=YES
dladdr_stub_runtime_shape_match=YES
callsite_region_max_write=YES
vm_protect_enable_kr=0
candidate_write_readback_match=YES
original_restore_readback_match=YES
vm_protect_restore_kr=0
final_protection_match=YES
loaded_callsite_bytes_restored=YES
vm_protect_attempts=2
coregraphics_text_write_attempts=2
candidate_instruction_executed=NO
dladdr_stub_executed=NO
dladdr_interposer_load_attempts=0
functional_source_helper_load_attempts=0
private_coregraphics_call_count=0
original_gui_launch_count=0
preflight_complete=YES
RESULT: PASS
RESULT: DLADDR_WRITE_RESTORE_SNOW_PASS
~~~

If Snow fails, stop and return only the Snow report. Do not transfer or retry on Lion.

## Phase C — transfer the exact probe to Lion

Transfer the exact executable plus its `.info.txt` and `.sha256` sidecars to the current Lion runtime checkout. Verify the executable SHA-256 against the sidecar before execution.

Keep the accepted runtime stack unchanged. In particular, do not add a `dladdr` interposer, source helper, marker dylib, trampoline, or any new compatibility component in this phase.

## Phase D — Lion reversible-write preflight

From the logged-in Aqua console user's Terminal, first verify the same accepted protected identities used by the preceding placement preflight:

~~~text
/mach_kernel
/usr/libexec/oah/translate
/usr/oah/dyld
/private/var/db/dyld/dyld_shared_cache_rosetta
/private/var/db/dyld/dyld_shared_cache_rosetta.map
/System/Library/.../CoreGraphics
payload/pm-selectwindow-orderfront-compat.dylib
payload/ppc-process-manager-security-session-auditinfo-api.dylib
payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib
~~~

Then run the exact transferred probe under the already accepted CoreServices/Security/CGS compatibility stack, with no additional inserted library:

~~~sh
CORE_COMPAT="$PWD/payload/pm-selectwindow-orderfront-compat.dylib"
SEC_INTERPOSER="$PWD/payload/ppc-process-manager-security-session-auditinfo-api.dylib"
CGS_INTERPOSER="$PWD/payload/ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib"
PROBE="$PWD/ppc-carbon-gui-event-unflip-dladdr-write-restore-private-dyld"
REPORT="$PWD/ppc-carbon-gui-event-unflip-dladdr-write-restore-lion.txt"

INSERT_LIBS="$CORE_COMPAT:$SEC_INTERPOSER:$CGS_INTERPOSER"

ROSETTA_CORESERVICES_COMPAT_MODE=lion-dual-sessioninit-adapter \
ROSETTA_SECURITY_SESSION_API_COMPAT_MODE=lion-auditinfo-v1 \
ROSETTA_CGS_SESSION_BOOTSTRAP_COMPAT_MODE=lion-session-port-v1 \
ROSETTA_CGS_SERVER_VERSION_COMPAT_MODE=lion-server-version-v1 \
DYLD_INSERT_LIBRARIES="$INSERT_LIBS" \
DYLD_SHARED_CACHE_DONT_VALIDATE=1 \
"$PROBE" > "$REPORT" 2>&1
~~~

Require the same route/write/restore markers as Snow, with:

~~~text
preflight_mode=lion-ppc-translated
candidate_branch_word=0x48524d51
candidate_write_readback_match=YES
original_restore_readback_match=YES
final_protection_match=YES
loaded_callsite_bytes_restored=YES
vm_protect_attempts=2
coregraphics_text_write_attempts=2
candidate_instruction_executed=NO
dladdr_stub_executed=NO
dladdr_interposer_load_attempts=0
functional_source_helper_load_attempts=0
preflight_complete=YES
RESULT: PASS
~~~

After the process exits, re-hash the same protected system/runtime files and require all hashes to match their pre-run values. The CoreGraphics file itself must remain byte-for-byte unchanged; only the process-local loaded mapping is touched and restored.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-event-unflip-dladdr-write-restore-snow.txt
ppc-carbon-gui-event-unflip-dladdr-write-restore-lion.txt
~~~

Also report any unexpected crash/core diagnostic if one appears. None is expected because the changed instruction is never executed.

## Decision gate after this preflight

If both systems prove exact write/readback/restore and final protection restoration, the next step may build a proof-only PPC `_dladdr` interposer that forwards every ordinary call through the original `__interpose` replacee and only recognizes the exact event-unflip return address. That later step must still avoid the functional display-source scan and must prove Snow passthrough plus Lion binding/guard behavior before the patched instruction is ever executed.

If either system cannot add write permission, cannot read back the candidate word, cannot restore the original word, or cannot restore the original page protection, stop. Do not try a broader CoreGraphics hook, indirect-symbol rewrite, branch island, persistent projection, or XNU change.

## Safety boundary

- Do not execute the candidate branch in this phase.
- Do not load a new `dladdr` interposer or display helper.
- Do not call the selected `_dladdr` stub through the patched site.
- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Modify only the one audited four-byte callsite in the process-local mapping and restore it immediately.
- Do not modify any CoreGraphics file, symbol stub, indirect-symbol pointer, HIToolbox image, Rosetta cache, dyld, WindowServer state, or XNU.
