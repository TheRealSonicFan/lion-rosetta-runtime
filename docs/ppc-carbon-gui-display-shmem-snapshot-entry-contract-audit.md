# PPC Carbon GUI display-shmem snapshot-entry contract audit

## Status

**WRITER-SIDE MAIN-DISPLAY SHIFT CONFIRMED / PASSIVE SNAPSHOT ENTRY PATH NEXT.**

The completed record writer-layout reports pass on the pinned Snow Leopard PPC
and Lion i386 CoreGraphics slices. They strengthen the earlier reader-only
result in two important ways.

First, the same-named main-display writer now moves with the reader block:
Snow `_markNewMainDisplay` reads `+0x112` and sets/clears `+0x10e`;
Lion `_markNewMainDisplay` reads `+0x12e` and sets/clears `+0x12a`.
Those are exact `+0x1c` correspondences.

Second, same-named status/debug consumers extend the coherent shift through a
larger prefix. In particular, Snow record fields
`+0x0fc/+0x100/+0x104/+0x108` correspond to Lion
`+0x118/+0x11c/+0x120/+0x124`, while Snow `+0x138` corresponds to Lion
`+0x154` in the same display-state logging family. The main identity/status
block remains the already confirmed `+0x1c` shift.

The full record tail is still not completely resolved. Lion's source record is
`0x17c` bytes versus Snow's `0x150`, so another `+0x10` exists outside
the proven prefix. That unresolved tail does not need to block a read-only
observation of the main-display prefix, but the observation must not depend on
calling the private non-external `__CGSGetDisplayShmem` by an assumed ABI or
on rewriting any mapped bytes.

The next static gate therefore pins the safe entry route to the already mapped
display object before a live snapshot is built.

## Objective

Prove, on each pinned release, the exact read-only route a later diagnostic can
use to observe the first mapped display record without patching CoreGraphics or
calling the non-external display-shmem helper directly.

The audit must establish:

1. `_CGSMainDisplayID` is externally callable;
2. `_CGSResolveShmemReference` is external while
   `__CGSGetDisplayShmem` remains non-external;
3. the release-local display-state initializer resolves the first reference
   with the already established mode-2 path and stores the resulting mapped
   pointer into one stable CoreGraphics global;
4. the exact preferred-image address of that mapping global;
5. the `__TEXT` preferred vmaddr needed to convert that address to an offset
   from the loaded Mach-O header; and
6. the existing `_CGSMainDisplayID` route reaches the display mapping repair
   path before returning, including the Snow case where the final ID can still
   be zero.

If both reports pass, the next step may be a narrowly hash-gated passive
snapshot that calls only the external main-display API, then reads the
already-populated mapping pointer and record prefix. This audit itself does not
authorize that live run.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-snapshot-entry-contract-v1
~~~

Current analyzer Git blob:

~~~text
0a9577efd97e91fb62e13426c54f3a4c83b2af7b
~~~

Pinned CoreGraphics slices remain:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

The analyzer emits the complete relevant initializer, lookup, mapping, shmem,
and main-display symbol bodies, plus the load-command `__TEXT` vmaddr and the
exact initializer global-address calculation.

Pinned static candidates to verify:

~~~text
Snow:
  resolver call                  0x140b04
  resolved mapping store         0x140b0c
  PIC anchor                     0x1409cc
  high displacement              0x005c0000
  signed store displacement      0xfaa0 (-0x560)
  mapping-global preferred addr  0x70046c
  main-display lookup call       0x148410 -> _lookupMainDisplay

Lion:
  resolver call                  0x0cceff
  resolved mapping store         0x0ccf04
  PIC anchor                     0x0ccdc1
  mapping-global displacement    0x87ca87
  mapping-global preferred addr  0x949848
  main-display route             0x087bbe -> _lookupDisplayNumber
~~~

These are diagnostic address facts for the pinned binaries only. They are not
compatibility constants and must not be used to modify shared state.

## Safety constraints

- Do not launch the PPC Carbon GUI subject.
- Do not repeat a titlebar drag.
- Do not run a live display-shmem snapshot yet.
- Do not call a non-external CoreGraphics helper by a guessed function pointer.
- Do not write to the mapping global or any mapped shared-memory byte.
- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add or broaden a display-shmem adapter.
- Do not copy, rewrite, truncate, or synthesize display records.
- Do not patch display mapping/state initializers or private HIToolbox.
- Do not add a `__CGSGetNumberOfDisplays` adapter.
- Do not rewrite event, hit-part, or `0x7218` movement payloads.
- Keep all accepted compatibility policies unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py \
  ./ppc-carbon-gui-display-shmem-snapshot-entry-contract-snow.txt
~~~

Require at minimum:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-snapshot-entry-contract-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
target=_CGSMainDisplayID count=1
target=_lookupMainDisplay count=1
target=_initCGDisplayMappings count=1
target=_initCGDisplayState count=1
target=__CGSGetDisplayShmem count=1
target=_CGSResolveShmemReference count=1
main_display_id_external=YES
resolve_shmem_reference_external=YES
get_display_shmem_nonexternal=YES
mapping_global_vmaddr=0x70046c
mapping_global_calculated_vmaddr=0x70046c
mapping_global_calculation_exact=YES
main_route_target=_lookupMainDisplay
snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_INITIALIZER_MAPPING_GLOBAL
display_shmem_snapshot_entry_contract_audit_exact=YES
RESULT: PASS
~~~

Record the emitted `text_vmaddr` and
`mapping_global_from_image_header` exactly; do not substitute an assumed
image base.

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py \
  ./ppc-carbon-gui-display-shmem-snapshot-entry-contract-lion.txt
~~~

Require at minimum:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-snapshot-entry-contract-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
target=_CGSMainDisplayID count=1
target=_lookupDisplayNumber count=1
target=_lookupMainDisplay count=1
target=_initDisplayMappings count=1
target=_initDisplayState count=1
target=__CGSGetDisplayShmem count=1
target=_CGSResolveShmemReference count=1
main_display_id_external=YES
resolve_shmem_reference_external=YES
get_display_shmem_nonexternal=YES
mapping_global_vmaddr=0x949848
mapping_global_calculated_vmaddr=0x949848
mapping_global_calculation_exact=YES
main_route_target=_lookupDisplayNumber
snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_INITIALIZER_MAPPING_GLOBAL
display_shmem_snapshot_entry_contract_audit_exact=YES
RESULT: PASS
~~~

Again, preserve the emitted `text_vmaddr` and
`mapping_global_from_image_header` exactly.

If either report fails, return it unchanged. Do not compensate by trying a
live probe.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-shmem-snapshot-entry-contract-snow.txt
ppc-carbon-gui-display-shmem-snapshot-entry-contract-lion.txt
~~~

## Current boundary

~~~text
display-shmem generated transport                 IDENTICAL
main reader semantic displacement                 CONFIRMED +0x1c
main writer semantic displacement                 CONFIRMED +0x1c
coherent proven prefix                            extends through Snow +0x138 / Lion +0x154
total source-record growth                        +0x2c
unresolved record-tail growth                     +0x10
private __CGSGetDisplayShmem direct call           NOT AUTHORIZED
mapping-global read route                         STATIC VERIFICATION NEXT
passive mapped-state snapshot                     NOT YET AUTHORIZED
shared-record rewrite                             NOT AUTHORIZED
XNU                                               unchanged
~~~
