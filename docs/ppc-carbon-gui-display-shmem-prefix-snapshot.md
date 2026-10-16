# PPC Carbon GUI display-shmem read-only prefix snapshot

## Status

**V3 SNOW FAILURE DIAGNOSED / V4 LOADED-PIC RUNTIME ADDRESSING READY.**

The third Snow control disproves the v3 interpretation that the remaining
problem was only `vm_region` visibility. The v3 probe reached the corrected
standalone selector/source addresses, called exported `CGSMainDisplayID`
successfully, obtained a nonzero main-display ID, and then faulted while trying
to directly read the selector pointer value it had obtained from:

~~~text
loaded CoreGraphics header + standalone selector VM address
~~~

The decisive returned sequence was:

~~~text
coregraphics_header=0x93615000
selector_global_slot=0x93d1426c
CGSMainDisplayID_dlsym=PASS
main_display_id_zero=NO
selector_pointer_after=0x41a20028
selector_pointer_vm_region_readable=NO
selector_direct_read=FAIL
~~~

The arithmetic that produced `0x93d1426c` is exactly:

~~~text
0x93615000 + 0x006ff26c
~~~

That is the remaining diagnostic bug.

## Correct diagnosis

The static addresses `0x6ff26c`, `0x700460`, and `0x700458` are
**standalone Snow PPC CoreGraphics VM addresses**, not guaranteed runtime
offsets from the loaded shared-cache image header.

This repository already encountered and closed the same address-model problem
in the Process Manager CPS connection discriminator. Its accepted correction
established that the Rosetta shared cache can relocate `__TEXT` and
`__DATA` independently. Cross-segment PPC data references must therefore be
reconstructed from the **loaded PPC PIC instructions**, not from:

~~~text
loaded_image_header + standalone_data_vmaddr
~~~

The v3 direct-read failure is exactly consistent with that established model:
the probe read a plausible four-byte value from the wrong runtime data address,
then attempted to dereference that value and faulted. It does not contradict
the successful `CGSMainDisplayID` call, because CoreGraphics itself uses its
cache-rewritten loaded PIC displacement to reach the real selector global.

## V4 runtime address model

V4 keeps the static audit as provenance but no longer treats standalone data VM
addresses as runtime offsets.

For translated Snow PPC CoreGraphics, it:

1. resolves exported `CGSMainDisplayID`;
2. derives loaded `_lookupMainDisplay` using the audited same-`__TEXT`
   delta `-0x5858`;
3. validates the loaded PPC prologue and exact register forms of the
   `addis`/`lwz` and `addis`/`addi` PIC references;
4. decodes the **loaded immediates** to reconstruct the actual runtime
   selector-global, source-array, and local-array addresses;
5. requires all three decoded targets to fall inside loaded CoreGraphics
   segments;
6. calls `CGSMainDisplayID`;
7. reads the actual selector slot, selector byte, selected source slot, and
   source prefix with guarded direct reads.

For native Lion i386, V4 applies the same principle. It derives loaded
`_lookupMainDisplay` from exported `CGSMainDisplayID`, validates the
release-pinned instruction forms, decodes the loaded PIC displacements for the
selector/source/local globals, and uses those runtime targets instead of
`image_header + standalone_vmaddr`.

The mode-2 mapping remains static provenance only for this snapshot and is not
dereferenced by V4.

## Prepared files

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-display-shmem-prefix-snapshot.c
Git blob 83279f55ec80f5aa22065cec1c6f56fd5f8f67eb

scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
Git blob ff79b07192a129f4515739fb861908fefd9ac18a

scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
Git blob be7cc338e98a2d501f25cd2e74bc48f2732a1a83

scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
Git blob 315d7287c5ed1136d86513b890e515d7ec406329

scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py
Git blob 137a7f55ca87503d4defa6d665c97086c13649fa
~~~

The embedded live contract is:

~~~text
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v4
translated_guest_pointer_validation=LOADED_PPC_PIC_PLUS_GUARDED_DIRECT_READ
~~~

The static analyzer is now v3 and explicitly records that standalone VM
addresses are not authorized as loaded-image-header-relative runtime offsets.

## Safety constraints

- Do not run the original PPC Carbon GUI subject.
- Do not create, show, move, drag, or click a window.
- Do not call `__CGSGetDisplayShmem` directly.
- Do not call `_CGSResolveShmemReference` directly.
- Do not write CoreGraphics globals.
- Do not write mapped display shared memory.
- Do not change VM protection.
- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not create a Snow-layout projection/copy.
- Do not add or broaden a display-shmem adapter.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Step 1 — rebuild V4 on Snow Leopard

The V3 PPC/i386 binaries and SHA sidecars are stale because the probe source
changed.

From current runtime `main` on Snow Leopard 10.6.8 / 10K549:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
~~~

Require a successful build of both probes and newly generated SHA sidecars.
Do not reuse V3 binaries.

## Step 2 — rerun Snow PPC control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
~~~

Require the embedded probe to reach:

~~~text
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v4
snapshot_mode=snow-ppc-control
CGSMainDisplayID_dlsym=PASS
runtime_address_model=LOADED_PPC_LOOKUPMAIN_PIC
ppc_pic_pattern=PASS
ppc_runtime_targets_in_segments=YES
coregraphics_slots_readable=YES
main_display_id_zero=NO
selector_slot_read=PASS
selector_direct_read=PASS
selector_index_valid=YES
selected_slot_read=PASS
source_after_nonnull=YES
source_direct_read=PASS
record_count_valid=YES
snapshot_complete=YES
write_attempts=0
RESULT: PASS
~~~

The wrapper must finish:

~~~text
RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_SNOW_PASS
RESULT: PASS
~~~

If Step 2 fails again, stop and return both:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt
ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt.raw.log
~~~

The new log's loaded PIC words and decoded runtime targets are then the next
evidence boundary. Do not proceed to Lion after a failed Snow control.

## Step 3 — transfer exact rebuilt probes to Lion

Only after Snow V4 passes, copy the rebuilt PPC/i386 binaries and their new SHA
sidecars to Lion without rebuilding them.

## Step 4 — Lion native + translated-PPC differential

Run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
~~~

The Lion runner requires:

- native i386 V4 loaded-`_lookupMainDisplay` PIC resolution;
- translated PPC V4 loaded-`_lookupMainDisplay` PIC resolution;
- valid selector/source reads;
- valid display counts;
- complete snapshots;
- unchanged protected hashes and no new diagnostics.

Either zero or nonzero `CGSMainDisplayID` remains accepted for the minimal
translated PPC probe; the actual result is evidence.

## Return evidence after a full pass

Return only:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt
ppc-carbon-gui-display-shmem-prefix-snapshot-lion.txt
~~~

No shared-record rewrite or compatibility adapter is authorized by this
procedure alone.
