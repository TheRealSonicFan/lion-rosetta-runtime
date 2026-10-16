# PPC Carbon GUI display-shmem consumer-topology audit

## Status

**COMPLETE — V2 OWNERSHIP TOPOLOGY PASSES / PROJECTION-SEAM LIFECYCLE NEXT.**

The first Phase B failure is an analyzer defect, not evidence that Lion lacks a
display-notification lifecycle path. The Lion slice contains
`__CGSDisplayNotifyProc` (two leading underscores), while V1 incorrectly
required the Snow spelling `_CGSDisplayNotifyProc`. The same failed Lion
report independently resolves `__CGSDisplayNotifyProc@0x2fcbb3` as a real
source-array consumer.

V1 also over-reported some global references because its lightweight register
tracker did not invalidate PIC-derived register values after unrelated
instructions overwrote those registers. Generic object-field accesses such as
`_create_provider` offsets `+0x08/+0x0c/+0x14` were therefore able to be
misclassified as source-array/mode-2 references. Because the Snow V1 PASS was
produced by the same tracker, its broad caller inventory is superseded even
though its required anchor references passed.

V2 fixes both issues: it uses the release-local notification symbol name and
conservatively invalidates register provenance across loads, arithmetic,
calls, and other writes before accepting a PIC-derived global reference.
Lifecycle direct references are likewise restricted to actual branch/call
instructions. Both phases must therefore be rerun from current `main`.

The V4 passive snapshots close the causal question that motivated the
display-shmem investigation.

Snow Leopard PPC reads a Snow-layout record and returns a nonzero main display.
Lion native and translated PPC both read the same Lion display-source object,
but native Lion returns the nonzero main display while the translated Snow PPC
reader returns zero.

The decisive status byte is release-shifted exactly as the prior static audits
predicted:

~~~text
Snow reader main-candidate byte     record +0x10e
Lion native main-candidate byte     record +0x12a
delta                               +0x1c
~~~

On the Snow control, record bytes `+0x10c..+0x113` are:

~~~text
01 01 01 01 00 00 00 00
~~~

so Snow `+0x10e` is nonzero.

On Lion, the translated PPC legacy view at `+0x10c..+0x113` is:

~~~text
37 03 00 00 00 00 00 00
~~~

so the Snow reader sees `+0x10e == 0` and rejects the record as the main
candidate. The Lion-native shifted view at `+0x128..+0x12f` is:

~~~text
01 01 01 01 00 00 00 00
~~~

so Lion `+0x12a` is nonzero and the native lookup succeeds.

The remaining coherent fields also match the proven `+0x1c` correspondence.
This is now live causal evidence of a record-layout compatibility boundary, not
only a static layout difference.

## Why implementation does not start yet

The server-owned Lion shared-memory record must remain untouched. A direct
rewrite, truncation, or in-place Snow-layout overlay would affect native
consumers and would couple the compatibility layer to WindowServer-owned
lifetime/state.

A future process-local Snow-layout projection may be viable, but the correct
ownership seam is not yet established. Before writing compatibility code we
must know:

1. every Snow CoreGraphics consumer of the selector/source/local globals;
2. where the two mode-1 source mappings are first installed;
3. how `_initCGDisplayMappings` builds its local mapping entries from those
   source slots;
4. which display-change/mapping-change seed paths invalidate or rebuild state;
5. whether one source-array substitution point can safely feed the existing
   Snow local-mapping builder;
6. what event must refresh a projection after display reconfiguration.

## Prepared analyzer

Run:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-consumer-topology.py
~~~

The analyzer is static-only.

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-consumer-topology.py
analyzer_version=2
audit_contract=carbon-gui-display-shmem-consumer-topology-v2
Git blob 73848eb677d172db90c7bf201e3072f8b25141e4
~~~

It thins the pinned release-local CoreGraphics slice, disassembles it,
reconstructs PIC references to the exact standalone
selector/source/local/mode-2 globals, and emits all resolved function-level
cross-references plus the focused initializer/lookup/update/seed bodies.

It validates at minimum that the already-proven core users are present:

~~~text
Snow
  selector       _lookupMainDisplay
  source array   _lookupMainDisplay, _initCGDisplayMappings
  local array    _lookupMainDisplay, _initCGDisplayMappings

Lion
  selector       _lookupMainDisplay
  source array   _lookupMainDisplay, _initDisplayMappings
  local array    _lookupMainDisplay, _initDisplayMappings
~~~

The analyzer also emits direct-reference topology for:

~~~text
release-local display-state initializer
release-local display-mapping initializer
_updateAllDisplayInfoAsNeeded
_CGSDisplayChangedSeed
_CGSDisplayMappingChangedSeed
Snow: _CGSDisplayNotifyProc
Lion: __CGSDisplayNotifyProc
~~~

## Phase A — rerun Snow Leopard static audit with V2

The prior V1 Snow report is no longer sufficient because the xref tracker was
corrected. On Snow Leopard 10.6.8 / 10K549 from current runtime `main`:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-consumer-topology.py \
  ./ppc-carbon-gui-display-shmem-consumer-topology-snow.txt
~~~

Require:

~~~text
mode=snow
slice_exact=YES
selector_required_caller__lookupMainDisplay=YES
source_array_required_caller__lookupMainDisplay=YES
source_array_required_caller__initCGDisplayMappings=YES
local_array_required_caller__lookupMainDisplay=YES
local_array_required_caller__initCGDisplayMappings=YES
display_shmem_consumer_topology_audit_exact=YES
RESULT: PASS
~~~

If it fails, stop and return the Snow report only.

## Phase B — rerun Lion static audit with V2

Only after the new V2 Snow report passes, run on Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-consumer-topology.py \
  ./ppc-carbon-gui-display-shmem-consumer-topology-lion.txt
~~~

Require:

~~~text
mode=lion
slice_exact=YES
selector_required_caller__lookupMainDisplay=YES
source_array_required_caller__lookupMainDisplay=YES
source_array_required_caller__initDisplayMappings=YES
local_array_required_caller__lookupMainDisplay=YES
local_array_required_caller__initDisplayMappings=YES
display_shmem_consumer_topology_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

After both reports pass, return only:

~~~text
ppc-carbon-gui-display-shmem-consumer-topology-snow.txt
ppc-carbon-gui-display-shmem-consumer-topology-lion.txt
~~~

## Decision gate after the audit

Do not implement a projection merely because the live layout mismatch is now
causal.

The next engineering decision will be made from the exact topology:

- if the Snow source array has one controllable process-local ownership seam
  and the existing mapping builder can consume a projected Snow record without
  further private state substitution, design a narrow proof-only
  process-local projection experiment;
- if source pointers are installed or consumed through multiple independent
  paths, audit those paths first rather than broadening an adapter;
- if display-change lifecycle can invalidate the projected record without an
  exact refresh hook, resolve that lifecycle before any live projection.

## Safety boundary

- Do not write the server-owned Lion display shared memory.
- Do not substitute or normalize display IDs.
- Do not patch `_CGSMainDisplayID`.
- Do not patch private HIToolbox.
- Do not add a `__CGSGetDisplayShmem` wire adapter; that transport is already
  release-stable.
- Do not create a process-local projection yet.
- Do not rewrite event, hit-test, or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.


## V2 completion

The rerun V2 Snow and Lion reports both pass with the pinned CoreGraphics
slices and the corrected release-local notification symbol. The Snow report
confirms that `_initCGDisplayState` stores the two mode-1 resolved mappings
into the source array, `_initCGDisplayMappings` derives each process-local
mapping entry from those source mappings, and `_lookupMainDisplay` consumes
the record pointer cached in the local mapping entry. The update path also
compares mapping/display seeds and calls `_CGSReleaseAllDisplays`, while the
display-notification callback enters `_updateAllDisplayInfoAsNeeded`.

Lion has the same high-level ownership/rebuild shape with
`_initDisplayState`, `_initDisplayMappings`, and
`__CGSDisplayNotifyProc`.

This closes the broad consumer inventory but does not yet authorize a live
projection. A late source-array-only substitution is insufficient because the
Snow local mapping array already caches record pointers derived from the source
mapping.

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-projection-seam-audit.md
~~~

Run the new static projection-seam analyzer on Snow and then Lion and return:

~~~text
ppc-carbon-gui-display-shmem-projection-seam-snow.txt
ppc-carbon-gui-display-shmem-projection-seam-lion.txt
~~~

That audit pins the exact release/free/rebuild/notification path before any
process-local mapping pointer is redirected or any Snow-layout projection is
constructed. XNU remains outside the evidence boundary.
