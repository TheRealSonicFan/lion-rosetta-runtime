# PPC Carbon GUI display-shmem snapshot-entry contract audit

## Status

**COMPLETE — READ-ONLY SNAPSHOT ENTRY ROUTE PROVED.**

Both returned analyzer-v1 reports pass on the pinned Snow Leopard PPC and Lion
i386 CoreGraphics slices.

The Snow report proves:

~~~text
text_vmaddr=0x0
main_display_id_external=YES
resolve_shmem_reference_external=YES
get_display_shmem_nonexternal=YES
mapping_global_vmaddr=0x70046c
mapping_global_from_image_header=0x70046c
mapping_global_calculation_exact=YES
main_route_target=_lookupMainDisplay
snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_INITIALIZER_MAPPING_GLOBAL
display_shmem_snapshot_entry_contract_audit_exact=YES
RESULT: PASS
~~~

The Lion report proves:

~~~text
text_vmaddr=0x0
main_display_id_external=YES
resolve_shmem_reference_external=YES
get_display_shmem_nonexternal=YES
mapping_global_vmaddr=0x949848
mapping_global_from_image_header=0x949848
mapping_global_calculation_exact=YES
main_route_target=_lookupDisplayNumber
snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_INITIALIZER_MAPPING_GLOBAL
display_shmem_snapshot_entry_contract_audit_exact=YES
RESULT: PASS
~~~

Because `__TEXT vmaddr` is zero in both audited images, the mapping-global
preferred addresses are exact offsets from the loaded CoreGraphics Mach-O
header. The later diagnostic therefore does not need to invoke private
`__CGSGetDisplayShmem` or `_CGSResolveShmemReference` directly.

The next controlled step is:

~~~text
docs/ppc-carbon-gui-display-shmem-prefix-snapshot.md
~~~

That procedure authorizes one dedicated read-only Snow PPC control and one Lion
native-i386 / translated-PPC differential using a minimal diagnostic probe. It
does not authorize running the original Carbon GUI subject, dragging a window,
normalizing/substituting a display ID, or rewriting shared state.

## Completed analyzer

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-snapshot-entry-contract-v1
Git blob 0a9577efd97e91fb62e13426c54f3a4c83b2af7b
~~~

Pinned CoreGraphics slices:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Current boundary

~~~text
display-shmem generated transport                 IDENTICAL
main reader semantic displacement                 CONFIRMED +0x1c
main writer semantic displacement                 CONFIRMED +0x1c
coherent proven prefix                            through Snow +0x138 / Lion +0x154
total source-record growth                        +0x2c
unresolved record-tail growth                     +0x10
external CGSMainDisplayID entry                    CONFIRMED
private __CGSGetDisplayShmem direct call           NOT AUTHORIZED
mapping-global read route                         CONFIRMED
passive mapped-prefix snapshot                    AUTHORIZED BY NEXT PROCEDURE
shared-record rewrite                             NOT AUTHORIZED
XNU                                               unchanged
~~~
