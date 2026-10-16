# PPC Carbon GUI display-shmem record writer-layout audit

## Status

**MAIN-DISPLAY +0x1c FIELD SHIFT CONFIRMED / WRITER-SIDE INSERTION BOUNDARY NEXT.**

The completed semantic-field reports pass on Snow Leopard PPC and Lion i386.

The exact main-display lookup logic now proves a coherent semantic displacement:

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

That correspondence is no longer a stride-only inference: both release-local
`_lookupMainDisplay` implementations make the corresponding decisions from
those exact fields.

The server-side helper is also now complete on both releases. Snow
`__CGXGetDisplayShmem` and Lion `__CGXGetDisplayShmem` each populate the
same three shared-memory reference pairs consumed by `__XGetDisplayShmem`.
Their internal producers are release-local, but the output shape does not
support a display-shmem transport adapter.

The remaining problem is writer-side structure placement. Lion's source record
is `0x17c` bytes versus Snow's `0x150`, a total growth of `0x2c`. The
main semantic block explains `0x1c`, leaving another `0x10` to locate.
Lion fields `+0x118`, `+0x138`, `+0x154`, and `+0x170` appear in
display-related code, but the completed semantic-field inventory intentionally
matched numeric immediates broadly and therefore cannot by itself prove that
every occurrence is a member of the same display record. A passive raw-memory
snapshot would not resolve that ambiguity.

## Objective

Resolve the exact writer/reader insertion boundary before any live mapped-state
observation.

The audit asks:

1. in same-named display-device writers/readers, where does the Snow-to-Lion
   displacement first become `+0x1c`;
2. where the additional `+0x10` of Lion record growth is inserted;
3. which record-range offsets are consistently used by
   `_CGXDisplayDriverInitialize`, `_CGXPerformInitialDisplayConfiguration`,
   and `_reconfigureDisplays` on both releases;
4. whether Lion `+0x118`, `+0x138`, `+0x154`, and `+0x170` have
   stable same-function Snow counterparts;
5. which same-number references are merely stack/local or other-object
   displacements; and
6. whether the next action can then be a narrow passive snapshot of the mapped
   first display record.

A PASS is static evidence only. It does not authorize a copied or rewritten
shared-memory projection.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-record-writer-layout.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-record-writer-layout-v1
~~~

Current analyzer Git blob:

~~~text
8af43e52196d0c535722d21d88c1b771046272df
~~~

The analyzer emits only record-range immediate references plus two instructions
of local context on each side for the selected display-device writer/reader
functions. That is intentionally narrower than the prior global immediate
inventory.

Common targets:

~~~text
_CGXMainDisplayDevice
_markNewMainDisplay
_lookupMainDisplay
_lookupMasterDisplay
_CGSDisplayStatusQuery
_CGXDisplayDriverInitialize
_CGXPerformInitialDisplayConfiguration
_reconfigureDisplays
_get_active_display_list
_logOneDisplayState
_VFBGetMonitorInfo
_MPGetMonitorInfo
_CGXDeviceStateChanged
_CGXConstructVirtualFramebuffer
~~~

Release-specific writer targets:

~~~text
Snow: _display_connect_change
Lion: _displayConnectChange
      _displayAliasActivate
~~~

Record-range filters:

~~~text
Snow  0x0e0 .. 0x14f
Lion  0x0e0 .. 0x17b
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
- Do not take a live mapped-memory snapshot yet.
- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add or broaden a display-shmem adapter.
- Do not copy, rewrite, truncate, or synthesize display shared-memory records.
- Do not patch the mapping/state initializers or private HIToolbox.
- Do not add a `__CGSGetNumberOfDisplays` adapter.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Keep the accepted v9 SharedWindow bridge, exact-six bitmap-info rule,
  exact-21 notification policy, and other accepted compatibility rules
  unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-record-writer-layout.py \
  ./ppc-carbon-gui-display-shmem-record-writer-layout-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-record-writer-layout-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
target=_CGXDisplayDriverInitialize count=1
target=_CGXPerformInitialDisplayConfiguration count=1
target=_reconfigureDisplays count=1
target=_display_connect_change count=1
lookup_main_field_0x0f4=YES
lookup_main_field_0x0f8=YES
lookup_main_field_0x10c=YES
lookup_main_field_0x10d=YES
lookup_main_field_0x10e=YES
lookup_main_field_0x110=YES
lookup_main_field_0x111=YES
lookup_main_field_0x112=YES
lookup_main_field_0x113=YES
display_shmem_record_writer_layout_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-record-writer-layout.py \
  ./ppc-carbon-gui-display-shmem-record-writer-layout-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-shmem-record-writer-layout-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
target=_CGXDisplayDriverInitialize count=1
target=_CGXPerformInitialDisplayConfiguration count=1
target=_reconfigureDisplays count=1
target=_displayConnectChange count=1
target=_displayAliasActivate count=1
lookup_main_field_0x110=YES
lookup_main_field_0x114=YES
lookup_main_field_0x128=YES
lookup_main_field_0x129=YES
lookup_main_field_0x12a=YES
lookup_main_field_0x12c=YES
lookup_main_field_0x12d=YES
lookup_main_field_0x12e=YES
lookup_main_field_0x12f=YES
display_shmem_record_writer_layout_audit_exact=YES
RESULT: PASS
~~~

If either report fails, return it unchanged. Do not compensate with a live
probe.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-shmem-record-writer-layout-snow.txt
ppc-carbon-gui-display-shmem-record-writer-layout-lion.txt
~~~

## Current boundary

~~~text
display-shmem wire relation                       IDENTICAL
Snow/Lion __CGXGetDisplayShmem output shape       three reference pairs
Snow source/local stride                          0x150 / 0x58
Lion source/local stride                          0x17c / 0x68
main identity/status semantic shift               CONFIRMED +0x1c
total source-record growth                        +0x2c
writer-side unexplained growth                    +0x10
passive mapped-state snapshot                     NOT YET AUTHORIZED
shared-record rewrite                             NOT AUTHORIZED
next action                                       static record writer-layout audit
XNU                                               unchanged
~~~
