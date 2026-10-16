# PPC Carbon GUI display-shmem projection call-boundary audit

## Status

**NEXT STEP — PIN THE LOCKED LOOKUP FAST PATH BEFORE ANY LIVE PROJECTION WRITE.**

The projection-seam reports pass on both pinned releases and close the
release/rebuild lifecycle needed to choose the next boundary.

The decisive Snow behavior is narrower than the earlier source-array model:

- `_CGSReleaseAllDisplays` tears down and refreshes per-display local state,
  but it does not free or null the top-level two-entry source array or
  process-local mapping-array slots.
- when `_updateAllDisplayInfoAsNeeded` observes a changed mapping seed, it
  calls `_CGSReleaseAllDisplays` and then re-enters `_bindDisplayMapping`
  over the existing local mapping entries.
- only `_CGSDisplayServerShutdown` frees the local mapping allocations and
  clears the local/source slots and mode-2 state.
- `_CGSDisplayNotifyProc` can synchronously enter
  `_updateAllDisplayInfoAsNeeded`, and `__CGSDisplayInitialize` registers
  that callback before invoking the mapping initializer.

Lion has the corresponding lifecycle shape.

Therefore a projected record pointer must never remain installed across the
normal update/rebind path: if the mapping seed advances while it is present,
Snow's normal `_bindDisplayMapping` path could consume projection bytes that
were created only for main-display lookup. A proof experiment is only
acceptable if it can run `_updateAllDisplayInfoAsNeeded` first while the
display lock is held, install one process-local record pointer only after that
update returns, invoke the lookup fast path directly, restore the pointer, and
unlock before any notification/update path can observe the projection.

Before authorizing those private calls, the exact call boundary and all lookup
record reads must be pinned statically.

## Prepared analyzer

Use:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-projection-call-boundary.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-projection-call-boundary-v1
Git blob febd005e0660e91b688fcf2406a0c7f412a95d6e
~~~

The analyzer is static-only. It verifies the pinned CoreGraphics slice, emits
the complete release-local bodies for the public main-display entry and its
lock/update/lookup helpers, validates the known internal call edges, records
same-`__TEXT` deltas from `_CGSMainDisplayID`, and inventories memory
displacements used by `_lookupMainDisplay` and `_lookupDisplay`.

No live private-function call or process-local mapping write is authorized by
this analyzer itself.

## Phase A — Snow Leopard PPC

On Snow Leopard 10.6.8 / 10K549 from current runtime `main`:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-projection-call-boundary.py \
  ./ppc-carbon-gui-display-shmem-projection-call-boundary-snow.txt
~~~

Require:

~~~text
mode=snow
slice_exact=YES
edge=_CGSMainDisplayID->_lockDisplay present=YES
edge=_CGSMainDisplayID->_updateAllDisplayInfoAsNeeded present=YES
edge=_CGSMainDisplayID->_lookupMainDisplay present=YES
edge=_CGSMainDisplayID->_unlockDisplay present=YES
edge=_lookupMainDisplay->_initCGDisplayMappings present=YES
edge=_lookupMainDisplay->_lookupDisplay present=YES
edge=_lookupDisplay->_initCGDisplayMappings present=YES
display_shmem_projection_call_boundary_audit_exact=YES
RESULT: PASS
~~~

If Phase A fails, stop and return only the Snow report.

## Phase B — Lion native reference

Only after Snow passes, run on Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-projection-call-boundary.py \
  ./ppc-carbon-gui-display-shmem-projection-call-boundary-lion.txt
~~~

Require:

~~~text
mode=lion
slice_exact=YES
edge=_CGSMainDisplayID->_lookupDisplayNumber present=YES
edge=_lookupDisplayNumber->_lockDisplay present=YES
edge=_lookupDisplayNumber->_lookupMainDisplay present=YES
edge=_lookupDisplayNumber->_unlockDisplay present=YES
edge=_lookupMainDisplay->_initDisplayMappings present=YES
edge=_lookupMainDisplay->_lookupDisplay present=YES
edge=_lookupDisplay->_initDisplayMappings present=YES
display_shmem_projection_call_boundary_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

After both phases pass, return only:

~~~text
ppc-carbon-gui-display-shmem-projection-call-boundary-snow.txt
ppc-carbon-gui-display-shmem-projection-call-boundary-lion.txt
~~~

The review will decide whether the fast-path field closure is narrow enough to
build a dedicated one-record, proof-only translated-PPC control. That future
control, if authorized, will have to validate the loaded private helper
addresses from the exported main-display symbol, call update before installing
the projection, modify only one process-local local-mapping record pointer
while locked, restore it before unlock, and reject any state that could enter a
mapping rebuild.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not mutate WindowServer-owned Lion display shared memory.
- Do not write selector or source-array globals.
- Do not write the local mapping array or any local entry yet.
- Do not call private lock/update/lookup helpers yet.
- Do not substitute or normalize display IDs.
- Do not patch `_CGSMainDisplayID`, mapping initializers, or private
  HIToolbox.
- Do not add or broaden a display-shmem transport adapter.
- Do not rewrite event, hit-test, or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
