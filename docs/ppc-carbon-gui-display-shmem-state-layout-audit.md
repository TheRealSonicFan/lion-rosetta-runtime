# PPC Carbon GUI display shared-state layout audit

## Status

**DISPLAY-SHMEM WIRE CONTRACT CLOSED / MAPPED RECORD LAYOUT NEXT.**

The completed display-shmem transport reports pass on both reference systems and
rule out the generated-MIG boundary as the source of the current main-display
failure.

Snow PPC and Lion i386 `__CGSGetDisplayShmem` use the same request/reply
contract:

~~~text
request ID       0x748b
reply ID         0x74ef
Mach bits        0x1513
mach_msg option  0x00000003
send size        0x18
receive size     0x44
success size     0x3c
error size       0x24
~~~

Both generated clients perform the same reply-ID/size checks and the same
NDR-aware 32-bit conversion before returning three shared-memory reference
pairs. Both release-local display-state initializers then resolve the first pair
with `_CGSResolveShmemReference(..., 2, ...)` and the remaining two with
mode `1`.

No `__CGSGetDisplayShmem` ID adapter, request reshaping, reply reshaping, or
display-ID substitution is justified by this result.

The first concrete release differential is immediately above the resolved
mapping. Snow `_initCGDisplayMappings` treats the mapped display array as
records beginning at `+0x20`, stepping each source record by `0x150`, and
builds `0x58`-byte local mapping entries. Lion `_initDisplayMappings`
also begins at `+0x20` but steps source records by `0x17c`, builds
`0x68`-byte local entries, and directly consumes source fields at
`+0x138` and `+0x170`.

That record-layout delta is now the unresolved engineering boundary.

## Objective

Map the exact server-owned display shared-state structure consumed after
`__CGSGetDisplayShmem` and `_CGSResolveShmemReference`.

The audit must answer:

1. What count/header fields precede the mapped per-display records?
2. Which offsets encode display identity, active/main state, bounds, and the
   metadata copied into the local mapping entries?
3. Is the source stride conclusively `0x150` on Snow and `0x17c` on
   Lion?
4. Which Lion fields at or beyond Snow's old `0x150` boundary cause a
   legacy reader to lose record alignment?
5. How do `__XGetDisplayShmem` and, where present,
   `__CGXGetDisplayShmem` expose the server-owned reference pairs?
6. Does the evidence support a narrow passive observation of the mapped state,
   or does another static writer/reader audit need to precede any live run?

The goal is to identify the semantic record boundary. A passing static report
does not authorize rewriting a shared-memory record.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-state-layout.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-state-layout-v1
~~~

Current analyzer Git blob:

~~~text
3d2bb564cdb5da8482961c7e29092bd1c6d885b0
~~~

The analyzer emits complete symbol-bounded disassembly, direct-reference
inventories, and layout-bearing immediate inventories for the client
initializers, mapping builders/lookups, shared-reference resolver, and
server-side display-shmem handlers.

Snow required targets include:

~~~text
_initCGDisplayState
_initCGDisplayMappings
_bindDisplayMapping
_lookupMainDisplay
_lookupDisplay
_CGSMainDisplayID
__CGSGetDisplayShmem
_CGSResolveShmemReference
__XGetDisplayShmem
~~~

Lion required targets include:

~~~text
_initDisplayState
_initDisplayMappings
_addEntryForDisplay
_lookupMainDisplay
_lookupDisplay
_lookupDisplayNumber
_CGSMainDisplayID
__CGSGetDisplayShmem
_CGSResolveShmemReference
__XGetDisplayShmem
__CGXGetDisplayShmem
~~~

The discriminator requires the already observed mapping-layout constants:

~~~text
Snow source base +0x20, source stride 0x150, local stride 0x58

Lion source base +0x20, source stride 0x17c, local stride 0x68,
     referenced source fields +0x138 and +0x170
~~~

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
- Do not add a `__CGSGetDisplayShmem` adapter; its wire contract is now
  statically release-stable.
- Do not rewrite or copy shared-memory records.
- Do not patch either mapping/state initializer or any mapping global.
- Do not add an adapter for `__CGSGetNumberOfDisplays`.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Do not add the deferred out-of-line event adapter.
- Keep the accepted v9 SharedWindow bridge and all accepted titlebar,
  notification, and CoreUI compatibility rules unchanged.
- Do not modify CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.
- Verify current repository contents on a modern TLS-capable staging system,
  transfer the verified tree offline, and use SHA-256 on Snow/Lion.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-state-layout.py \
  ./ppc-carbon-gui-display-shmem-state-layout-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-state-layout-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
mapping_immediate_0x020=YES
mapping_immediate_0x058=YES
mapping_immediate_0x150=YES
mapped_display_record_stride=0x150
local_mapping_record_stride=0x58
mapped_display_record_base_offset=0x20
display_shmem_state_layout_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-state-layout.py \
  ./ppc-carbon-gui-display-shmem-state-layout-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-state-layout-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
mapping_immediate_0x020=YES
mapping_immediate_0x068=YES
mapping_immediate_0x138=YES
mapping_immediate_0x170=YES
mapping_immediate_0x17c=YES
mapped_display_record_stride=0x17c
local_mapping_record_stride=0x68
mapped_display_record_base_offset=0x20
mapped_display_record_field_0x138=REFERENCED
mapped_display_record_field_0x170=REFERENCED
display_shmem_state_layout_audit_exact=YES
RESULT: PASS
~~~

If either report fails, return it unchanged. Do not compensate with a live
probe or an adapter.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-shmem-state-layout-snow.txt
ppc-carbon-gui-display-shmem-state-layout-lion.txt
~~~

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Lion public mouse-down                            sane / inDrag (4)
Snow display-shmem wire                           0x748b/0x74ef, 0x18/0x44
Lion display-shmem wire                           identical
display-shmem ID/schema adapter                   NOT AUTHORIZED
Snow mapped display-record stride                 0x150
Lion mapped display-record stride                 0x17c
Snow local mapping stride                         0x58
Lion local mapping stride                         0x68
Lion mapped fields +0x138/+0x170                  referenced
display-ID substitution                           NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
shared-record rewrite                             NOT AUTHORIZED
event/move rewrite                                NOT AUTHORIZED
next action                                       static display shared-state layout audit
XNU                                               unchanged
~~~
