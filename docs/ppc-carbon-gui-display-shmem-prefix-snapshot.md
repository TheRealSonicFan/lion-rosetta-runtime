# PPC Carbon GUI display-shmem read-only prefix snapshot

## Status

**V1 SNOW CONTROL FAILURE DIAGNOSED / V2 SOURCE-SLOT SNAPSHOT READY.**

The first Snow control did not expose corrupted display state. It exposed a
bug in the diagnostic: v1 decoded the mode-2 shared-memory mapping at
`0x70046c` as though it were the display-record source. The pointer was
readable and stable, but its first four bytes are not a display count.

The returned Snow control proves the surrounding run was healthy:

~~~text
CGSMainDisplayID_dlsym=PASS
main_display_id_zero=NO
mapping_after_nonnull=YES
mapped_prefix_readable=YES
record_count_valid=NO
new_diagnostics=none
protected_hashes_unchanged=YES
~~~

The invalid count is therefore local to the probe's object selection.

The v1 static reports already show the corrected route:

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

The display-record object is selected by the current selector byte and the
two-entry source-pointer array. `_initCGDisplayMappings` /
`_initDisplayMappings` consume the same source array, independently
confirming the route.

## Prepared v2 probe

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-display-shmem-prefix-snapshot.c
Git blob d8b0e74af87c0cb0ce1455401c12a27166a5c2d5

scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
Git blob ff79b07192a129f4515739fb861908fefd9ac18a

scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
Git blob fa64ec6e7d6c0185a815ae1e2510b121b39ee55a

scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
Git blob 71625bc01eaf72b04b3905762dd68fb5874f488c
~~~

The embedded snapshot contract is now:

~~~text
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v2
v1_mode2_pointer_misclassification=CORRECTED
~~~

The v2 probe calls exported `CGSMainDisplayID` once, reads the release-local
selector pointer, requires selector index 0 or 1, reads the corresponding
source-array slot, and only then decodes the display count and first-record
prefix. It logs the mode-2 pointer separately and does not decode it as a
display record.

No shared-memory or CoreGraphics global write is performed.

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

## Step 1 — rebuild v2 on Snow Leopard

The v1 binaries and SHA sidecars are obsolete because the probe source changed.

From current runtime `main` on Snow Leopard 10.6.8 / 10K549:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
~~~

This recreates:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld
ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld.sha256
lion-i386-display-shmem-prefix-snapshot
lion-i386-display-shmem-prefix-snapshot.sha256
~~~

Do not reuse the old v1 binaries.

## Step 2 — rerun Snow PPC control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
~~~

Require the embedded probe to report:

~~~text
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v2
v1_mode2_pointer_misclassification=CORRECTED
snapshot_mode=snow-ppc-control
selector_global_from_image_header=0x006ff26c
source_array_from_image_header=0x00700460
local_array_from_image_header=0x00700458
mode2_mapping_from_image_header=0x0070046c
coregraphics_slots_readable=YES
CGSMainDisplayID_dlsym=PASS
main_display_id_zero=NO
selector_pointer_readable=YES
selector_index_valid=YES
source_after_nonnull=YES
source_prefix_readable=YES
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

Do not proceed to Lion on a failed Snow control.

## Step 3 — transfer exact rebuilt probes to Lion

Only after Snow v2 passes, copy the rebuilt PPC/i386 binaries and their new SHA
sidecars to Lion without rebuilding them.

## Step 4 — Lion native + translated-PPC differential

Run:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
~~~

The runner has also been replaced with a clean v2 gate. It first runs the i386
reference without interposers, then the PPC probe with only the established
connection prerequisites.

Require the final wrapper result:

~~~text
RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_LION_PASS
RESULT: PASS
~~~

The native i386 section must report a valid Lion source slot and nonzero main
display. The translated PPC section must report a valid Snow-client source
slot and complete both legacy/Snow and Lion semantic views of the same mapped
prefix. Either zero or nonzero `CGSMainDisplayID` is accepted for the minimal
translated probe; record the actual result.

## Return evidence after a full pass

Return only:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt
ppc-carbon-gui-display-shmem-prefix-snapshot-lion.txt
~~~

## Interpretation gate

The desired discriminator remains unchanged: compare the Snow legacy view,
Lion native view, and Lion translated-PPC legacy/Lion views of the actual
display-source object.

No shared-record rewrite or compatibility adapter is authorized by this
procedure alone.
