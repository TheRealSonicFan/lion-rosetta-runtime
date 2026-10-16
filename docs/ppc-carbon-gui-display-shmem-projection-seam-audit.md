# PPC Carbon GUI display-shmem projection-seam audit

## Status

**COMPLETE — RELEASE/REBUILD/NOTIFICATION SEAM PINNED; LOCKED LOOKUP AUDIT NEXT.**

The corrected V2 consumer-topology reports both pass on the pinned Snow PPC
and Lion i386 CoreGraphics slices. The causal display-record layout mismatch
therefore remains closed, and the broad ownership topology is now trustworthy.

The important Snow-side facts established by the V2 report are:

- `_initCGDisplayState` obtains the two mode-1 display mappings through
  `_CGSResolveShmemReference` and stores those resolved pointers into the
  two-entry source array.
- `_initCGDisplayMappings` allocates the process-local mapping array, derives
  each local mapping entry from `source + 0x20 + index * 0x150`, and then
  calls `_bindDisplayMapping`.
- `_lookupMainDisplay` reads the first pointer in each process-local mapping
  entry as the display-record pointer; it does not rescan the server mapping
  independently once the local mappings exist.
- `_updateAllDisplayInfoAsNeeded` re-enters the mapping initializer when
  source/local state is absent, compares display-mapping and display-change
  seeds, and invokes `_CGSReleaseAllDisplays` when the mapping seed changes.
- the display-notification callback calls
  `_updateAllDisplayInfoAsNeeded` under the display lock.

Lion shows the same lifecycle shape with its release-local
`_initDisplayState`, `_initDisplayMappings`, and
`__CGSDisplayNotifyProc`.

This is enough to reject a late source-array-only substitution: the Snow local
mapping array already contains record pointers derived from the source mapping.
A future projection must either be present before the local mapping builder
runs, or a proof-only experiment must redirect the relevant process-local
mapping entry and restore it without touching the server-owned mapping.

The remaining question before any live process-local write is the exact
release/rebuild/notification seam. In particular, the current broad topology
report did not emit the complete `_CGSReleaseAllDisplays` body or the complete
initialization path needed to determine whether source mappings survive a
mapping-seed change and where a private projection would have to be refreshed.

## Prepared static analyzer

Use:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-projection-seam.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-projection-seam-v1
Git blob 62fe60e2f328c4b3d702c66fe26c9b58df5e6fc5
~~~

The analyzer is static-only. It emits the complete release-local bodies and
direct caller sets for the state initializer, mapping initializer,
`_CGSReleaseAllDisplays`, display-server shutdown, display-update routine,
display-change/mapping-change seed readers, display-notification callback,
display initialization entry, and main-display lookup. On Snow it also emits
`_bindDisplayMapping`.

It validates the exact lifecycle edges already visible in the V2 reports, so a
missing release-local path stops the experiment before any live mutation is
considered.

## Phase A — Snow Leopard projection-seam audit

On Snow Leopard 10.6.8 / 10K549 from current runtime `main`:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-projection-seam.py \
  ./ppc-carbon-gui-display-shmem-projection-seam-snow.txt
~~~

Require:

~~~text
mode=snow
slice_exact=YES
edge=_initCGDisplayMappings->_initCGDisplayState present=YES
edge=_initCGDisplayMappings->_bindDisplayMapping present=YES
edge=_updateAllDisplayInfoAsNeeded->_CGSReleaseAllDisplays present=YES
edge=_CGSDisplayNotifyProc->_updateAllDisplayInfoAsNeeded present=YES
display_shmem_projection_seam_audit_exact=YES
RESULT: PASS
~~~

If Phase A fails, stop and return the Snow report only.

## Phase B — Lion projection-seam audit

Only after Snow passes, run on Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-projection-seam.py \
  ./ppc-carbon-gui-display-shmem-projection-seam-lion.txt
~~~

Require:

~~~text
mode=lion
slice_exact=YES
edge=_initDisplayMappings->_initDisplayState present=YES
edge=_updateAllDisplayInfoAsNeeded->_CGSReleaseAllDisplays present=YES
edge=__CGSDisplayNotifyProc->_updateAllDisplayInfoAsNeeded present=YES
display_shmem_projection_seam_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

After both reports pass, return only:

~~~text
ppc-carbon-gui-display-shmem-projection-seam-snow.txt
ppc-carbon-gui-display-shmem-projection-seam-lion.txt
~~~

The next decision will then be one of two narrow paths:

1. if the release/rebuild path proves that a single process-local record
   pointer can be redirected and restored without causing mapping rebuild or
   stale lifecycle state, prepare a dedicated proof-only
   `CGSMainDisplayID` projection control in a minimal translated PPC process;
2. otherwise, pin the exact notification/refresh hook before creating any
   process-local Snow-layout projection.

No production projection is authorized by this audit alone.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not mutate WindowServer-owned Lion display shared memory.
- Do not write selector or source-array globals.
- Do not write the process-local mapping array yet.
- Do not substitute or normalize display IDs.
- Do not patch `_CGSMainDisplayID`, mapping initializers, or private
  HIToolbox.
- Do not add or broaden a display-shmem transport adapter.
- Do not rewrite event, hit-test, or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.


## Completion result

Both returned projection-seam reports pass on the pinned Snow PPC and Lion
i386 slices.

Snow proves that `_CGSReleaseAllDisplays` operates on the existing
process-local display mapping entries without freeing or nulling the top-level
source/local arrays. If the mapping seed changes,
`_updateAllDisplayInfoAsNeeded` calls `_CGSReleaseAllDisplays` and then
rebinds the existing local entries with `_bindDisplayMapping`. In contrast,
`_CGSDisplayServerShutdown` performs the terminal cleanup: it frees the two
local mapping allocations and clears the local/source slots and mode-2 state.

The display callback is registered during `__CGSDisplayInitialize`; its
display-change path enters `_updateAllDisplayInfoAsNeeded` under the display
lock, and another notification path can tail-call `_CGSReleaseAllDisplays`.
Lion shows the same lifecycle shape.

This means a proof projection must not be installed before the update/rebind
phase and must not survive unlock. The next controlled step is therefore:

~~~text
docs/ppc-carbon-gui-display-shmem-projection-call-boundary-audit.md
~~~

Run that static analyzer on Snow and Lion and return its two reports. No live
projection write or private helper invocation is authorized until the locked
fast path and its exact record-field reads are reviewed.
