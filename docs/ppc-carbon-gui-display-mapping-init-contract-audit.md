# PPC Carbon GUI display-mapping initialization contract audit

## Status

**MAIN-DISPLAY ZERO LOCALIZED / DISPLAY-MAPPING INITIALIZATION NEXT.**

The returned main-display ID audits pass on both reference systems and narrow
the Lion titlebar defect one layer further.

Snow PPC `_CGSMainDisplayID` is entirely local at the call site: after
initialization it locks display state, calls
`_updateAllDisplayInfoAsNeeded`, asks `_lookupMainDisplay(1)`, and returns
zero if that lookup fails. If the lookup succeeds, Snow returns the display ID
stored in the mapping object. The same Snow `_lookupMainDisplay` path calls
`_initCGDisplayMappings` when its mapping globals are absent or incomplete.

Lion native has the same logical outcome but a different state pipeline.
`_CGSMainDisplayID` routes through `_lookupDisplayNumber`; a zero display
argument makes that helper call `_lookupMainDisplay(1)`, and Lion's
`_lookupMainDisplay` in turn repairs missing state through
`_initDisplayMappings`. The returned Lion report already shows that
`_initDisplayMappings` obtains an `_initDisplayState` object and builds
release-local mapping entries from it.

This makes the current live `CGSGetDisplayBounds(display 0)` diagnostic a
display-mapping initialization failure until disproved. It does not authorize
substituting Lion's native main-display ID into the PPC process.

A generated Snow `__CGSGetNumberOfDisplays` stub with request/reply
`0x7471/0x74d5` exists, but the returned audit records zero direct references
to that stub. It is not the next live adapter candidate merely because its
name mentions displays.

## Objective

Compare the exact release-local initialization path that creates the state
consumed by `_lookupMainDisplay`.

The audit must answer:

1. What object or shared mapping does Snow `_initCGDisplayState` create, and
   how does `_initCGDisplayMappings` bind it?
2. What object does Lion `_initDisplayState` create, and how does
   `_initDisplayMappings` project it into its mapping entries?
3. Which exact call first crosses a process/server/shared-memory boundary on
   each release?
4. Are those boundary contracts identical, ID-shifted, or structurally
   different?
5. What exact condition makes Snow `_lookupMainDisplay` still return NULL
   after its initialization attempt?
6. Does the old generated `__CGSGetNumberOfDisplays` transport participate
   in this path at all?

Only after those questions are answered may a live observation boundary be
selected.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-display-mapping-init-contract.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-mapping-init-contract-v1
~~~

Current analyzer Git blob:

~~~text
b17b55fd1c883f10dc495680d19adc756bb31167
~~~

The analyzer emits complete symbol-bounded disassembly, call/branch subsets,
transport candidates, and direct-reference inventories for the common display
lookup path plus the release-specific mapping initializers.

Snow-specific required targets:

~~~text
_initCGDisplayMappings
_initCGDisplayState
_bindDisplayMapping
~~~

Lion-specific required targets:

~~~text
_initDisplayMappings
_initDisplayState
_addEntryForDisplay
_lookupDisplayNumber
~~~

Common focused targets include:

~~~text
_CGSMainDisplayID
_lookupMainDisplay
_updateAllDisplayInfoAsNeeded
_CGSDisplayMappingChangedSeed
_CGSDisplayChangedSeed
_CGSGetNumberOfDisplays
__CGSGetNumberOfDisplays
_CGSGetDisplayList
_CGSGetActiveDisplayList
__CGSDisplayInitialize
_CGSDisplayNotifyProc
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
- Do not substitute the native observer's display ID into PPC state.
- Do not patch `_CGSMainDisplayID`, either mapping initializer, or any
  mapping global.
- Do not add an adapter for `0x7471/0x74d5` unless this audit proves that
  generated stub is actually on the live initialization path.
- Do not rewrite event fields or `0x7218` movement payloads.
- Do not add the deferred out-of-line event adapter.
- Keep the accepted v9 SharedWindow bridge and exact-21 notification policy
  unchanged.
- Do not modify CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.
- Verify current repository contents on a modern TLS-capable staging system,
  transfer the tree offline, and use SHA-256 on Snow/Lion.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-mapping-init-contract.py \
  ./ppc-carbon-gui-display-mapping-init-contract-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-mapping-init-contract-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
display_mapping_init_contract_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-mapping-init-contract.py \
  ./ppc-carbon-gui-display-mapping-init-contract-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-display-mapping-init-contract-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
display_mapping_init_contract_audit_exact=YES
RESULT: PASS
~~~

If either report fails, return it unchanged. Do not compensate with a live
probe.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-display-mapping-init-contract-snow.txt
ppc-carbon-gui-display-mapping-init-contract-lion.txt
~~~

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Lion public mouse-down                            sane / inDrag (4)
event x/y layout                                  aligned
Snow _CGSMainDisplayID failure result             0
Snow main-display state repair                    _initCGDisplayMappings
Lion main-display state repair                    _initDisplayMappings
Lion init source                                  _initDisplayState
legacy __CGSGetNumberOfDisplays direct refs       0 in returned Snow audit
display-ID substitution                           NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
event/move rewrite                                NOT AUTHORIZED
next action                                       static display-mapping init audit
XNU                                               unchanged
~~~
