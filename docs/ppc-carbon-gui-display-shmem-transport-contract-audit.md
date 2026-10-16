# PPC Carbon GUI display-shmem transport contract audit

## Status

**DISPLAY-MAPPING INITIALIZER BOUNDARY RESOLVED / DISPLAY-SHMEM TRANSPORT NEXT.**

The returned display-mapping initialization audits pass on Snow Leopard PPC and
Lion i386. They close the local initializer question far enough to identify one
shared lower boundary without rewriting any display ID.

On Snow, `_initCGDisplayMappings` calls `_initCGDisplayState`. The latter
acquires the CGS server port, calls `__CGSGetDisplayShmem`, and then resolves
the returned references through `_CGSResolveShmemReference` before
`_initCGDisplayMappings` builds its per-display mapping entries.

On Lion, `_initDisplayMappings` calls `_initDisplayState`. The returned
Lion report shows the same lower call shape through numeric targets. Correlation
with the preserved same-binary CoreGraphics symbol inventory resolves
`0x00074836` as `__CGSGetDisplayShmem` and `0x000741cd` as
`_CGSResolveShmemReference`. The representation above that boundary changed,
but the first shared-memory acquisition primitive did not disappear.

The old Snow generated `__CGSGetNumberOfDisplays` stub remains off the
examined main-display repair path. It is not the next compatibility target.

## Objective

Resolve the exact generated-MIG contract used by
`__CGSGetDisplayShmem` on the two reference systems before any new live
adapter or display-state manipulation is considered.

The comparison must determine:

1. the Snow PPC and Lion i386 request/reply message IDs;
2. Mach message bits/options and request/receive sizes;
3. NDR and reply-ID/error validation behavior;
4. whether the release delta is identical, ID-only, or structurally different;
5. which returned shared-memory references are consumed by
   `_CGSResolveShmemReference`;
6. the single narrow live observation boundary that can prove where translated
   Snow display-state initialization fails on Lion without substituting or
   normalizing a display ID.

A `RESULT: PASS` from this audit means the required static evidence was
collected with pinned binary provenance. It does not by itself authorize an
adapter.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-transport-contract.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-transport-contract-v1
~~~

Current analyzer Git blob:

~~~text
564b9aa76a1e4631eabbe3d1e27ecb177661b820
~~~

The analyzer emits complete symbol-bounded disassembly, resolved direct-call
edges, Mach/MIG lines, protocol-bearing immediates, and caller inventories for:

~~~text
__CGSGetDisplayShmem
_CGSResolveShmemReference
_CGSServerPort
_CGSScoreboard
_CGSGetDenyWindowServerConnections
_lookupMainDisplay

Snow:
_initCGDisplayState
_initCGDisplayMappings

Lion:
_initDisplayState
_initDisplayMappings
~~~

It also verifies that the release-specific display-state initializer reaches
`_CGSServerPort`, `__CGSGetDisplayShmem`, and
`_CGSResolveShmemReference`, and that the generated display-shmem helper
contains visible Mach/MIG transport.

Pinned CoreGraphics slices remain:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Safety constraints

- Do not launch the PPC Carbon subject for this step.
- Do not repeat a titlebar drag.
- Do not normalize display ID 0.
- Do not substitute Lion's native main-display ID into PPC state.
- Do not patch either display-state or display-mapping initializer.
- Do not add a `__CGSGetDisplayShmem` adapter until both reports are compared.
- Do not add an adapter for `__CGSGetNumberOfDisplays`.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Do not add the deferred out-of-line event adapter.
- Keep the accepted v9 SharedWindow bridge, exact-six bitmap-info rule, and
  exact-21 notification policy unchanged.
- Do not modify CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.
- Verify current repository contents on a modern TLS-capable staging system,
  transfer the tree offline, and use SHA-256 on Snow/Lion.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-transport-contract.py \
  ./ppc-carbon-gui-display-shmem-transport-contract-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-transport-contract-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
init_calls_get_display_shmem=YES
init_calls_resolve_shmem_reference=YES
init_calls_cgs_server_port=YES
get_display_shmem_has_mach_mig_transport=YES
display_shmem_transport_contract_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-transport-contract.py \
  ./ppc-carbon-gui-display-shmem-transport-contract-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-transport-contract-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
init_calls_get_display_shmem=YES
init_calls_resolve_shmem_reference=YES
init_calls_cgs_server_port=YES
get_display_shmem_has_mach_mig_transport=YES
display_shmem_transport_contract_audit_exact=YES
RESULT: PASS
~~~

If either report fails, return it unchanged. Do not compensate with a live
probe or a broader static search.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-shmem-transport-contract-snow.txt
ppc-carbon-gui-display-shmem-transport-contract-lion.txt
~~~

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Lion public mouse-down                            sane / inDrag (4)
Snow main-display failure result                  0
Snow mapping initializer                          _initCGDisplayMappings
Snow display-state initializer                    _initCGDisplayState
Snow first shared-state acquisition               __CGSGetDisplayShmem
Lion mapping initializer                          _initDisplayMappings
Lion display-state initializer                    _initDisplayState
Lion first shared-state acquisition               __CGSGetDisplayShmem
shared-reference resolver                         _CGSResolveShmemReference on both
display-shmem wire relation                       UNKNOWN pending focused audit
legacy __CGSGetNumberOfDisplays                   not on examined repair path
display-ID substitution                           NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
event/move rewrite                                NOT AUTHORIZED
next action                                       static display-shmem transport audit
XNU                                               unchanged
~~~
