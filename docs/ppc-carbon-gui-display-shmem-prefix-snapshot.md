# PPC Carbon GUI display-shmem read-only prefix snapshot

## Status

**V2 SNOW FAILURE DIAGNOSED / V3 GUARDED-DIRECT SNAPSHOT READY.**

The second Snow control reached the corrected source-slot probe but stopped at a
different diagnostic assumption:

~~~text
CGSMainDisplayID_dlsym=PASS
main_display_id_zero=NO
selector_pointer_after=0x41a20028
selector_pointer_readable=NO
RESULT: FAIL
~~~

This does not show that the selector pointer is invalid. The audited Snow
`_lookupMainDisplay` path loads the selector pointer from the same global and
dereferences byte zero before it can return a nonzero main display. The live
probe then called that exported path successfully and immediately observed a
nonzero main display. Therefore the subsequent `vm_region` rejection is not a
valid accessibility test for this translated PPC pointer.

The v2 wrapper also contained a separate shell-generation defect: the
`SOURCE_COUNT` grep line had an unterminated single quote and duplicated stale
tail content. That explains the reported `unexpected EOF while looking for
matching '\''` / `unexpected end of file` messages after the probe had
already run. The Snow and Lion runners have now both been replaced with clean
files.

## V3 diagnostic rule

The v3 probe keeps the corrected selector/source-array addressing from v2 but
changes how translated pointers are validated.

It still reads these CoreGraphics globals:

~~~text
Snow PPC
  selector pointer global   0x6ff26c
  source pointer array      0x700460
  local mapping array       0x700458
  mode-2 mapping            0x70046c

Lion native i386
  selector pointer global   0x948630
  source pointer array      0x94983c
  local mapping array       0x94984c
  mode-2 mapping            0x949848
~~~

For the selector target and selected source object, v3 records the `vm_region`
answer only as diagnostic metadata. It performs the actual read with a guarded
direct byte copy using normal process load semantics, with temporary
`SIGSEGV` / `SIGBUS` recovery. This matches how translated CoreGraphics
itself consumes those pointers and avoids treating Mach VM introspection as an
authority on Rosetta guest-pointer accessibility.

No write is performed.

## Prepared files

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-display-shmem-prefix-snapshot.c
Git blob 5d9c5b7664b1fe1a05353608ebbef11316083614

scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
Git blob ff79b07192a129f4515739fb861908fefd9ac18a

scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
Git blob d5e05d957b1dd23db326817e9bfcacfaabdf3628

scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
Git blob 275d24868c12abf3a89928ee61c006000d4ae1d3
~~~

The embedded snapshot contract is now:

~~~text
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v3
v1_mode2_pointer_misclassification=CORRECTED
translated_guest_pointer_validation=GUARDED_DIRECT_READ
~~~

## Safety constraints

- Do not run the original PPC Carbon GUI subject.
- Do not create, show, move, drag, or click a window.
- Do not call `__CGSGetDisplayShmem` directly.
- Do not call `_CGSResolveShmemReference` directly.
- Do not write the selector, source-array, local-array, or mode-2 globals.
- Do not write mapped display shared memory.
- Do not change VM protection.
- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not create a Snow-layout projection/copy yet.
- Do not add or broaden a display-shmem adapter.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Step 1 — rebuild v3 on Snow Leopard

The v2 PPC/i386 probes and SHA sidecars are obsolete because the probe source
changed again.

From current runtime `main` on Snow Leopard 10.6.8 / 10K549:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
~~~

Do not reuse the prior v2 binaries.

## Step 2 — rerun Snow PPC control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
~~~

Require the embedded probe to report:

~~~text
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v3
translated_guest_pointer_validation=GUARDED_DIRECT_READ
snapshot_mode=snow-ppc-control
selector_global_from_image_header=0x006ff26c
source_array_from_image_header=0x00700460
local_array_from_image_header=0x00700458
mode2_mapping_from_image_header=0x0070046c
coregraphics_slots_readable=YES
CGSMainDisplayID_dlsym=PASS
main_display_id_zero=NO
selector_direct_read=PASS
selector_index_valid=YES
source_after_nonnull=YES
source_direct_read=PASS
record_count_valid=YES
snapshot_complete=YES
write_attempts=0
RESULT: PASS
~~~

The `selector_pointer_vm_region_readable` and
`source_pointer_vm_region_readable` values are observational only and may be
`NO` under Rosetta.

The wrapper must finish:

~~~text
RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_SNOW_PASS
RESULT: PASS
~~~

If Step 2 fails, stop and return both the Snow wrapper report and raw log
unchanged. Do not proceed to Lion.

## Step 3 — transfer exact rebuilt probes to Lion

Only after Snow v3 passes, copy the rebuilt PPC/i386 binaries and their new SHA
sidecars to Lion without rebuilding them.

## Step 4 — Lion native + translated-PPC differential

Run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
~~~

The runner requires v3 from both the native i386 and translated PPC probe and
gates on guarded direct selector/source reads rather than `vm_region`
acceptance.

Either zero or nonzero `CGSMainDisplayID` remains accepted for the minimal
translated PPC probe. Record the actual result.

## Return evidence after a full pass

Return only:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt
ppc-carbon-gui-display-shmem-prefix-snapshot-lion.txt
~~~

No shared-record rewrite or compatibility adapter is authorized by this
procedure alone.
