# PPC Carbon GUI display-mapping initialization contract audit

## Status

**COMPLETE — FIRST SHARED-MEMORY BOUNDARY RESOLVED.**

The returned analyzer-v1 reports pass on both reference systems with the pinned
CoreGraphics slices. The local display-mapping representation differs between
Snow Leopard PPC and Lion i386, but both initializer pipelines converge on the
same lower shared-memory acquisition primitive.

Snow `_initCGDisplayMappings` calls `_initCGDisplayState`. That state
initializer acquires the CGS server port, calls `__CGSGetDisplayShmem`, and
then resolves returned references through `_CGSResolveShmemReference`.
Only after that state exists does `_initCGDisplayMappings` allocate and bind
its per-display mapping entries and update the display/mapping seeds.

Lion `_initDisplayMappings` calls `_initDisplayState` and constructs its
newer per-display mapping entries from the returned state. In the Lion report,
the lower calls are emitted by address. Correlation with the preserved
same-binary CoreGraphics symbol inventory resolves `0x00074836` as
`__CGSGetDisplayShmem` and `0x000741cd` as
`_CGSResolveShmemReference`. Thus the first relevant cross-process/shared-
state boundary is not a release-specific main-display lookup or the old
`__CGSGetNumberOfDisplays` stub; it is display shared-memory acquisition.

The current reports do not emit enough of the generated
`__CGSGetDisplayShmem` client body to determine whether Snow and Lion use
the same message IDs and wire geometry. That exact transport contract is now
the unresolved engineering step.

## Returned evidence

Both reports identify the expected release, architecture, pinned slice, and
end with:

~~~text
display_mapping_init_contract_audit_exact=YES
RESULT: PASS
~~~

Snow resolves this chain directly:

~~~text
_initCGDisplayMappings
  -> _initCGDisplayState
       -> _CGSServerPort
       -> __CGSGetDisplayShmem
       -> _CGSResolveShmemReference
  -> _bindDisplayMapping
  -> _CGSDisplayChangedSeed
  -> _CGSDisplayMappingChangedSeed
~~~

Lion resolves the analogous chain:

~~~text
_initDisplayMappings
  -> _initDisplayState
       -> _CGSServerPort
       -> __CGSGetDisplayShmem
       -> _CGSResolveShmemReference
  -> release-local mapping entry construction
  -> _CGSDisplayChangedSeed
  -> _CGSDisplayMappingChangedSeed
~~~

The mapping containers are release-local, but the lower acquisition primitive
is shared.

## `_lookupMainDisplay` failure condition

Snow `_lookupMainDisplay` first checks whether the current display-state and
mapping globals are usable. If not, it unlocks, calls
`_initCGDisplayMappings`, relocks, and repeats those checks. It returns NULL
when the required state/mapping pointer is still absent or when the selected
entry fails the subsequent active/main-display validity tests. Consequently
`_CGSMainDisplayID` can legitimately return 0 when initialization failed to
produce a usable mapping.

Lion's corresponding path also retries through `_initDisplayMappings`
before returning no mapping.

This confirms that substituting Lion's native main-display ID would bypass the
failing initialization contract rather than repair it.

## Legacy `__CGSGetNumberOfDisplays`

The Snow generated `__CGSGetNumberOfDisplays` transport is not directly
referenced by the examined main-display repair path. No adapter for its
`0x7471/0x74d5` pair is authorized from this evidence.

## Analyzer provenance

The completed reports were produced by:

~~~text
scripts/audit-ppc-carbon-gui-display-mapping-init-contract.py
analyzer_version=1
audit_contract=carbon-gui-display-mapping-init-contract-v1
Git blob b17b55fd1c883f10dc495680d19adc756bb31167
~~~

Pinned CoreGraphics slices:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-transport-contract-audit.md
~~~

That procedure is static-only. It emits the exact
`__CGSGetDisplayShmem` generated-MIG client on Snow PPC and Lion i386,
including request/reply IDs, Mach/MIG calls, protocol-bearing immediates, and
the shared-memory resolution chain. Compare the two reports before selecting
any live observation or compatibility rule.

Do not rerun the PPC subject for this step.

## Safety constraints

- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not patch `_CGSMainDisplayID`, either mapping initializer, either
  display-state initializer, or their mapping globals.
- Do not add a `__CGSGetDisplayShmem` adapter until the focused static
  transport reports are compared.
- Do not add an adapter for `__CGSGetNumberOfDisplays`.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Do not add the deferred out-of-line event adapter.
- Keep the accepted v9 SharedWindow bridge, exact-six bitmap-info rule, and
  exact-21 notification policy unchanged.
- Do not modify CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Lion public mouse-down                            sane / inDrag (4)
Snow _CGSMainDisplayID failure result             0
Snow mapping initializer                          _initCGDisplayMappings
Snow display-state initializer                    _initCGDisplayState
Snow first shared-state acquisition               __CGSGetDisplayShmem
Lion mapping initializer                          _initDisplayMappings
Lion display-state initializer                    _initDisplayState
Lion first shared-state acquisition               __CGSGetDisplayShmem
shared-reference resolver                         _CGSResolveShmemReference on both
legacy __CGSGetNumberOfDisplays                   not on examined repair path
display-shmem wire relation                       UNKNOWN
display-ID substitution                           NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
event/move rewrite                                NOT AUTHORIZED
next action                                       static display-shmem transport audit
XNU                                               unchanged
~~~
