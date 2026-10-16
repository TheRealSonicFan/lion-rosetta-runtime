# PPC Carbon GUI display-shmem read-only prefix snapshot

## Status

**AUTHORIZED NEXT DIAGNOSTIC — PASSIVE MAIN-DISPLAY PREFIX SNAPSHOT.**

The snapshot-entry contract reports pass on both pinned releases. They establish
that the relevant display-state mapping is reached through the externally
callable `CGSMainDisplayID` path, while `__CGSGetDisplayShmem` remains
non-external and is not to be called by a guessed private ABI.

They also establish `__TEXT vmaddr = 0` for both audited CoreGraphics slices,
so the statically proven mapping-global preferred addresses are directly usable
as offsets from the loaded CoreGraphics Mach-O header:

~~~text
Snow PPC mapping-global offset from image header   0x70046c
Lion i386 mapping-global offset from image header  0x949848
~~~

The mapping-global address calculations are exact on both reports. The next
step may therefore observe the already-mapped display object without modifying
CoreGraphics, invoking the private shmem helper directly, or rewriting shared
memory.

This diagnostic does **not** run the original Carbon GUI subject and does not
perform a titlebar drag.

## Objective

Collect a three-way read-only differential:

1. Snow Leopard PPC control;
2. Lion native i386 reference; and
3. Lion translated PPC using only the already accepted connection
   prerequisites.

The probe calls exported `CGSMainDisplayID` exactly once, then reads the
release-local CoreGraphics mapping-global slot that the static audit proved is
populated by the display-state initializer. It validates that the slot and
mapped prefix are readable with `vm_region`, reads the little-endian display
count, and dumps only the required prefix of the first display record.

It does not write the mapping slot or the mapped object.

The Snow control stops after the last proven Snow field at `record+0x138`.
The Lion runs stop after the last proven Lion field at `record+0x154`. The
unresolved Lion record tail is deliberately not consumed.

The emitted semantic views include:

~~~text
legacy/Snow:
  IDs       +0x0f4, +0x0f8
  prefix    +0x0fc, +0x100, +0x104, +0x108
  status    +0x10c .. +0x113
  word      +0x138

Lion:
  IDs       +0x110, +0x114
  prefix    +0x118, +0x11c, +0x120, +0x124
  status    +0x128 .. +0x12f
  word      +0x154
~~~

On Lion, both the native i386 process and translated PPC process dump the Lion
view. The translated PPC process additionally exposes the legacy/Snow view of
the same mapped record, which is the discriminator needed for the current
`CGSMainDisplayID == 0` failure.

Do not require the Lion translated-PPC main-display result to be zero in the
runner. Record whichever value occurs. A nonzero result in this minimal probe
would itself be important evidence and must not be hidden by a test gate.

## Prepared files

Current runtime `main` provides:

~~~text
tests/ppc-carbon-gui-display-shmem-prefix-snapshot.c
Git blob 1ecdd406eb957cb056ed5ceb61f22e3bcea8545d

scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
Git blob ff79b07192a129f4515739fb861908fefd9ac18a

scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
Git blob 05b450bdc0600c9ded4b7a2e195a9851ef564215

scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
Git blob f7fa1030a9e82beaecfd8bc946226419d0c6bc11
~~~

The build creates two binaries from the same source on Snow Leopard:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld
lion-i386-display-shmem-prefix-snapshot
~~~

The PPC binary is patched to use `/usr/oah/dyld`. The i386 binary retains the
normal system dyld and is used only as the Lion native reference.

## Safety constraints

- Do not run the original PPC Carbon GUI subject.
- Do not create, show, move, or drag a window.
- Do not click titlebar controls.
- Do not call `__CGSGetDisplayShmem` directly.
- Do not call `_CGSResolveShmemReference` directly.
- Do not write to the CoreGraphics mapping global.
- Do not write to mapped display shared memory.
- Do not change VM protection.
- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add or broaden a display-shmem adapter.
- Do not copy/rewrite/synthesize a Snow-layout shared-memory record yet.
- Do not patch CoreGraphics, WindowServer, private HIToolbox, Rosetta caches,
  dyld, or XNU.
- Keep all accepted compatibility policies unchanged.

The Lion translated-PPC run loads only the established connection prerequisites
needed to let a minimal PPC CoreGraphics client reach WindowServer:

~~~text
pm-selectwindow-orderfront-compat.dylib
ppc-process-manager-security-session-auditinfo-api.dylib
ppc-process-manager-cgs-session-dockserver-fontserver-rendezvous-compat.dylib
~~~

No HIToolbox, CoreUI, notification-broker, window-creation, or titlebar
compatibility path is exercised by this diagnostic.

If the minimal PPC probe cannot reach the snapshot with those accepted
prerequisites, return the report unchanged. Do not add another adapter to make
the diagnostic pass.

## Step 1 — build once on Snow Leopard

From current runtime `main` on Snow Leopard 10.6.8 / 10K549:

~~~sh
/bin/bash ./scripts/build-ppc-carbon-gui-display-shmem-prefix-snapshot-on-snowleopard.sh
~~~

This creates the PPC and i386 probes plus `.info.txt` and `.sha256`
sidecars.

Do not rebuild either executable on Lion. Transfer the exact i386 binary, PPC
binary, and both SHA sidecars to Lion after the Snow control succeeds.

## Step 2 — Snow PPC control

Run:

~~~sh
/bin/bash ./scripts/run-snowleopard-ppc-carbon-gui-display-shmem-prefix-snapshot-control.sh
~~~

Require the final wrapper result:

~~~text
RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_SNOW_PASS
RESULT: PASS
~~~

The embedded probe must contain:

~~~text
snapshot_mode=snow-ppc-control
mapping_global_from_image_header=0x0070046c
CGSMainDisplayID_dlsym=PASS
mapping_after_nonnull=YES
mapped_prefix_readable=YES
record_count_valid=YES
main_display_id_zero=NO
snapshot_complete=YES
write_attempts=0
RESULT: PASS
~~~

Do not manually edit the report.

## Step 3 — transfer exact probes to Lion

Copy these four artifacts without rebuilding:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld
ppc-carbon-gui-display-shmem-prefix-snapshot-private-dyld.sha256
lion-i386-display-shmem-prefix-snapshot
lion-i386-display-shmem-prefix-snapshot.sha256
~~~

Keep the already accepted three compatibility dylibs and their SHA sidecars in
the runtime `payload/` locations expected by the Lion runner.

## Step 4 — Lion native + translated-PPC differential

From the logged-in Aqua console user's Terminal session on Lion 10.7.5 / 11G63:

~~~sh
/bin/bash ./scripts/run-lion-ppc-carbon-gui-display-shmem-prefix-snapshot.sh
~~~

The runner first executes the i386 probe with no compatibility interposers,
then executes the exact transferred PPC probe with only the accepted connection
prerequisites.

Require the final wrapper result:

~~~text
RESULT: DISPLAY_SHMEM_PREFIX_SNAPSHOT_LION_PASS
RESULT: PASS
~~~

The native section must include:

~~~text
snapshot_mode=lion-i386-native
mapping_global_from_image_header=0x00949848
CGSMainDisplayID_dlsym=PASS
mapping_after_nonnull=YES
mapped_prefix_readable=YES
record_count_valid=YES
main_display_id_zero=NO
snapshot_complete=YES
write_attempts=0
RESULT: PASS
~~~

The translated PPC section must include:

~~~text
snapshot_mode=lion-ppc-translated
mapping_global_from_image_header=0x0070046c
CGSMainDisplayID_dlsym=PASS
mapping_after_nonnull=YES
mapped_prefix_readable=YES
record_count_valid=YES
snapshot_complete=YES
write_attempts=0
RESULT: PASS
~~~

Either `main_display_id_zero=YES` or `NO` is accepted for the translated PPC
probe. Do not rerun merely to obtain the expected symptom.

The runner also requires the pinned Lion kernel, translator, private dyld,
Rosetta cache, cache map, native CoreGraphics, and the three accepted
connection-compatibility artifacts to match their established hashes and remain
unchanged after both observations.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-shmem-prefix-snapshot-snow.txt
ppc-carbon-gui-display-shmem-prefix-snapshot-lion.txt
~~~

Do not return or modify the generated raw helper logs unless the wrapper report
fails; on failure, return the wrapper report unchanged first.

## Interpretation gate

The next review will compare the raw record prefix and both semantic views.

The strongest expected causal discriminator would be:

~~~text
Snow PPC:
  main display nonzero
  legacy/Snow identity + status fields coherent

Lion native i386:
  main display nonzero
  Lion identity + status fields coherent

Lion translated PPC:
  mapped record present and count valid
  Lion identity + status positions coherent
  legacy/Snow positions do not satisfy Snow _lookupMainDisplay
  CGSMainDisplayID returns zero
~~~

That outcome would connect the already proven static `+0x1c` ABI shift to the
live translated failure on one record, without any rewrite.

A different outcome is equally important. In particular, if the minimal Lion
translated-PPC probe returns a nonzero main display ID, do not infer that the
layout shift is harmless; it would mean the failure depends on additional
state in the full GUI process and the next step must remain observational.

No shared-memory projection or compatibility adapter is authorized by this
procedure alone.
