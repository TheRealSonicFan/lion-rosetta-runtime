# PPC Carbon GUI display-shmem semantic-field audit

## Status

**DISPLAY SHARED-STATE STRIDE DELTA CONFIRMED / SEMANTIC FIELD CORRESPONDENCE NEXT.**

The completed state-layout reports pass on Snow Leopard PPC and Lion i386 and
move the failure boundary beyond the shared-memory transport itself.

Both releases use a count word at the mapped-object base and begin the
per-display source array at `+0x20`, but the record geometry differs:

~~~text
Snow source stride  0x150
Snow local stride   0x58

Lion source stride  0x17c
Lion local stride   0x68
~~~

More importantly, the main-display consumers expose a coherent semantic shift.
The Snow identity/status offsets used by `_lookupMainDisplay` correspond to
Lion offsets exactly `+0x1c` later:

~~~text
Snow   Lion   delta
0x0f4  0x110  +0x1c
0x0f8  0x114  +0x1c
0x10c  0x128  +0x1c
0x10d  0x129  +0x1c
0x10e  0x12a  +0x1c
0x110  0x12c  +0x1c
0x111  0x12d  +0x1c
0x112  0x12e  +0x1c
0x113  0x12f  +0x1c
~~~

This is stronger than a bare stride mismatch: the fields governing the
main-display decision have moved as a block. The total record growth is
`0x2c`, however, so another `0x10` of growth remains to be located.

Lion additionally references `+0x118`, `+0x138`, `+0x154`, and
`+0x170` in the examined display paths. Their exact Snow correspondence and
semantic roles are not yet established.

The state-layout audit also revealed that Snow `__XGetDisplayShmem`, like
Lion, calls `__CGXGetDisplayShmem`; analyzer v1 did not emit the Snow
`__CGXGetDisplayShmem` body. That missing server-side helper is included in
this follow-up audit.

## Objective

Resolve the semantic field correspondence before any mapped-state rewrite or
live compatibility experiment.

This audit must determine:

1. whether the nine main-display identity/status fields are truly an exact
   `+0x1c` semantic shift;
2. which display-related functions read or write each of those fields;
3. the complete Snow `__CGXGetDisplayShmem` output-reference path and its
   relation to Lion's implementation;
4. the roles of Lion `+0x118`, `+0x138`, `+0x154`, and `+0x170`;
5. where the remaining `0x10` of the total `0x2c` Lion record growth is
   introduced; and
6. whether the next step can safely be a passive mapped-state snapshot or still
   requires a narrower writer-side static audit.

A PASS here is evidence collection only. It does not authorize a record
translation.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-semantic-fields.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-semantic-fields-v1
~~~

Current analyzer Git blob:

~~~text
5e3b2adacdabb50892ae721db287f4e8bd4dfb6d
~~~

The analyzer emits complete symbol windows for the mapping builders/lookups and
both server-side display-shmem helpers, then inventories display-related
references to the semantic offsets.

Snow targets include:

~~~text
_initCGDisplayMappings
_bindDisplayMapping
_lookupMainDisplay
_lookupDisplay
_CGSMainDisplayID
__XGetDisplayShmem
__CGXGetDisplayShmem
~~~

Lion targets include:

~~~text
_initDisplayMappings
_lookupMainDisplay
_lookupDisplay
_lookupDisplayNumber
_CGSMainDisplayID
__XGetDisplayShmem
__CGXGetDisplayShmem
~~~

Pinned CoreGraphics slices remain:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Safety constraints

- Do not launch the PPC Carbon subject.
- Do not repeat a titlebar drag.
- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add or broaden a display-shmem adapter.
- Do not copy, rewrite, truncate, or synthesize shared-memory records.
- Do not patch the mapping/state initializers or private HIToolbox.
- Do not add a `__CGSGetNumberOfDisplays` adapter.
- Do not rewrite event fields or `0x7218` move payloads.
- Keep the accepted v9 SharedWindow bridge, exact-six bitmap-info rule, and
  exact-21 notification policy unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-semantic-fields.py \
  ./ppc-carbon-gui-display-shmem-semantic-fields-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-semantic-fields-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
target=__CGXGetDisplayShmem count=1
lookup_main_field_0x0f4=YES
lookup_main_field_0x0f8=YES
lookup_main_field_0x10c=YES
lookup_main_field_0x10d=YES
lookup_main_field_0x10e=YES
lookup_main_field_0x110=YES
lookup_main_field_0x111=YES
lookup_main_field_0x112=YES
lookup_main_field_0x113=YES
main_id_field_primary=0x0f4
main_id_field_secondary=0x0f8
main_status_block=0x10c-0x113
display_shmem_semantic_field_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-semantic-fields.py \
  ./ppc-carbon-gui-display-shmem-semantic-fields-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-semantic-fields-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
target=__CGXGetDisplayShmem count=1
lookup_main_field_0x110=YES
lookup_main_field_0x114=YES
lookup_main_field_0x128=YES
lookup_main_field_0x129=YES
lookup_main_field_0x12a=YES
lookup_main_field_0x12c=YES
lookup_main_field_0x12d=YES
lookup_main_field_0x12e=YES
lookup_main_field_0x12f=YES
main_id_field_primary=0x110
main_id_field_secondary=0x114
main_status_block=0x128-0x12f
display_shmem_semantic_field_audit_exact=YES
RESULT: PASS
~~~

If either report fails, return it unchanged. Do not compensate with a live
probe.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-shmem-semantic-fields-snow.txt
ppc-carbon-gui-display-shmem-semantic-fields-lion.txt
~~~

## Current boundary

~~~text
display-shmem wire relation                       IDENTICAL
mapped source base                                +0x20 on both
Snow source/local stride                          0x150 / 0x58
Lion source/local stride                          0x17c / 0x68
main identity/status semantic shift               candidate +0x1c
total record growth                               +0x2c
unexplained growth                                +0x10
Snow __CGXGetDisplayShmem body                    next audit includes it
shared-record rewrite                             NOT AUTHORIZED
display-ID substitution/normalization             NOT AUTHORIZED
event/move rewrite                                NOT AUTHORIZED
next action                                       static semantic-field audit
XNU                                               unchanged
~~~
