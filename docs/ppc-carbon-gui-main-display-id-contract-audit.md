# PPC Carbon GUI main-display ID contract audit

## Status

**COMPLETED / MAIN-DISPLAY ZERO LOCALIZED TO MAPPING INITIALIZATION.**

Both returned reports pass exact provenance and validation. They show that the
zero reaching `CGSGetDisplayBounds` is produced locally by the old Snow PPC
display-state path rather than by a generated display-bounds RPC.

Snow `_CGSMainDisplayID` locks display state, calls
`_updateAllDisplayInfoAsNeeded`, then asks `_lookupMainDisplay(1)`; if that
lookup is NULL it returns 0. The Snow lookup repairs absent/incomplete mapping
state by calling `_initCGDisplayMappings`.

Lion native reaches the same logical result through a different representation:
`_CGSMainDisplayID` routes through `_lookupDisplayNumber`, which uses
`_lookupMainDisplay(1)`; Lion repairs missing mapping state through
`_initDisplayMappings`. The returned Lion audit further shows that
`_initDisplayMappings` calls `_initDisplayState` and constructs its
release-local per-display mapping entries from that state.

The old Snow generated `__CGSGetNumberOfDisplays` transport is not promoted
to a live candidate: the returned audit shows it has no direct references in
the examined path.

The authoritative next procedure is
`docs/ppc-carbon-gui-display-mapping-init-contract-audit.md`. It is
static-only and resolves `_initCGDisplayMappings/_initCGDisplayState` versus
Lion's `_initDisplayMappings/_initDisplayState` before any display-ID
substitution or mapping patch is considered.

## Objective

Compare the exact Snow PPC and Lion native main-display lookup pipelines and
answer:

1. What value source does `_CGSMainDisplayID` return on each release?
2. Which `_lookupMainDisplay` / `_lookupDisplay` representation backs the
   returned ID?
3. Which initializer or server-facing update populates the Snow PPC display
   mapping used by `_CGSGetUnflippedEventLocation`?
4. Did Lion replace that old mapping contract with
   `_lookupDisplayNumber` or another representation?
5. Is there a narrow generated-MIG or display-state boundary suitable for a
   later live probe, without rewriting display IDs or event/move payloads?

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-main-display-id-contract.py
~~~

Contract:

~~~text
analyzer_version=1
audit_contract=carbon-gui-main-display-id-contract-v1
~~~

Current analyzer Git blob:

~~~text
67f40aef7a1d60ea247739f5fdbf0640dcba37ca
~~~

The analyzer emits complete symbol-bounded disassembly and direct-reference
inventories for the following display path and any matching release-local
family members:

~~~text
_CGMainDisplayID
_CGSMainDisplayID
_CGSGetDisplayBounds
_CGSGetUnflippedEventLocation
_CGSMainConnectionID
_lookupMainDisplay
_lookupDisplayNumber
_lookupDisplay
_updateAllDisplayInfoAsNeeded
_CGSInitialize
__CGSDisplayInitialize
_CGBDSBuildDisplayList
_CGSGetNumberOfDisplays
_CGSGetDisplayList
_CGSGetOnlineDisplayList
_CGSGetActiveDisplayList
~~~

It additionally reports any Mach/MIG-looking lines inside those functions so a
later live test is chosen from evidence rather than from symbol names alone.

Pinned CoreGraphics slices remain:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Safety constraints

- Do not launch the PPC Carbon subject for this step.
- Do not repeat the titlebar drag.
- Do not rebuild or rerun the unusable `CGSMoveWindow` entry tracer.
- Do not normalize display ID 0.
- Do not substitute the native observer's main display ID into PPC state.
- Do not rewrite event object fields at `0xc6`, `0xbe`, or elsewhere.
- Do not rewrite `0x7218` move requests.
- Do not patch `_CGSMainDisplayID`, `_lookupMainDisplay`, or private
  HIToolbox code.
- Do not add the deferred out-of-line event adapter.
- Keep the accepted v9 SharedWindow bridge and exact-21 notification policy
  unchanged.
- Do not modify CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.
- Verify current repository contents on a modern TLS-capable staging system,
  transfer the tree offline, and use SHA-256 for legacy-target provenance.

## Snow static report

On Snow Leopard 10.6.8 / 10K549:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-main-display-id-contract.py \
  ./ppc-carbon-gui-main-display-id-contract-snow.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-main-display-id-contract-v1
mode=snow
product_version=10.6.8
build_version=10K549
required_arch=ppc7400
slice_exact=YES
main_display_id_contract_audit_exact=YES
RESULT: PASS
~~~

## Lion native-reference static report

On Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-main-display-id-contract.py \
  ./ppc-carbon-gui-main-display-id-contract-lion.txt
~~~

Require:

~~~text
analyzer_version=1
audit_contract=carbon-gui-main-display-id-contract-v1
mode=lion
product_version=10.7.5
build_version=11G63
required_arch=i386
slice_exact=YES
main_display_id_contract_audit_exact=YES
RESULT: PASS
~~~

If either report fails, return it unchanged. Do not compensate with another
live PPC run.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-main-display-id-contract-snow.txt
ppc-carbon-gui-main-display-id-contract-lion.txt
~~~

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Snow public titlebar drag                         PASS
Lion public mouse-down                            sane / inDrag (4)
Snow/Lion event x/y storage                       same offsets 0x0c/0x10
Snow cached unflip extent                         event +0xc6
Lion cached unflip extent                         event +0xbe
Snow zero-cache fallback                          _CGSMainDisplayID -> _CGSGetDisplayBounds
Lion live bounds diagnostic                       display 0
native Lion observer main display                 valid nonzero
event-coordinate rewrite                          NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
move rewrite                                      NOT AUTHORIZED
next action                                       static main-display ID contract audit
XNU                                               unchanged
~~~
