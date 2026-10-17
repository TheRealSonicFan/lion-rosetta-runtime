# PPC Carbon GUI image-local display repair surface audit

## Status

**NEXT STEP — CLOSE THE MAIN-LOOKUP / DISPLAY-BOUNDS RECORD SURFACE BEFORE CHOOSING IMAGE-LOCAL REPAIR VS LIFECYCLE PROJECTION.**

The DragWindow/main-display boundary reports pass on both pinned releases and close the public-interposition branch for the observed failure. Snow and Lion both use the same setup pattern: when a caller-supplied drag bounds rectangle needs normalization, `_DragWindow` calls imported public `_CGMainDisplayID`, immediately feeds that ID to `_HLTBGetDisplayBounds`, adjusts/intersects the rectangle, and only then constructs the tracker and enters `TWindowTracker::TrackWindow`. That result is therefore initial drag-bounds setup; it is not the event object's later zero-cache state.

CoreGraphics also confirms that public `_CGMainDisplayID` simply enters the same private main-display machinery, while the event-unflip fallback later calls private `_CGSMainDisplayID` and `_CGSGetDisplayBounds` image-locally. The earlier one-record projection proof further showed that a temporarily repaired lookup does not leave a durable main-display result after the process-local pointer is restored. A public `_CGMainDisplayID` interposer cannot therefore repair the later fallback by itself.

The new reports expose a second reason not to jump directly to a one-function patch: `_CGSGetDisplayBounds` has its own release-local record layout. Snow reads geometry at `+0xd0..+0xec` and a selector/flag at `+0x115`; Lion reads the corresponding geometry at `+0xdc..+0xf8` and the flag at `+0x131`. The geometry shift is `+0x0c`, while the flag shift is `+0x1c`. In addition, Snow constructs record pointers with source stride `0x150`, whereas Lion source records use `0x17c`; a field-displacement-only fix cannot be count>1 safe.

The next step is therefore a read-only repair-surface audit, not an implementation. It must determine whether a narrow image-local compatibility routine can read the Lion layout directly for main-display and bounds operations, or whether fixing all required lookup/mapping semantics expands into the same lifecycle complexity as a full projection.

## Prepared analyzer

Current runtime main provides:

~~~text
scripts/audit-ppc-carbon-gui-image-local-display-repair-surface.py
analyzer_version=1
audit_contract=carbon-gui-image-local-display-repair-surface-v1
~~~

The analyzer verifies the pinned CoreGraphics slice and emits the complete release-local bodies for:

~~~text
_CGSMainDisplayID
_lookupMainDisplay
_lookupMasterDisplay
_CGSGetDisplayBounds
_lookupDisplay
_initCGDisplayMappings       (Snow)
_initDisplayMappings         (Lion)
~~~

It also inventories the exact main-lookup and display-bounds record fields, verifies the release-local mapping stride literal, and records the known cross-release field correspondences. It performs no patching and no live private call.

Pinned slices remain:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Phase A — Snow Leopard PPC

Run:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-image-local-display-repair-surface.py \
  ./ppc-carbon-gui-image-local-display-repair-surface-snow.txt
~~~

Require:

~~~text
mode=snow
slice_exact=YES
main_lookup_field_inventory_complete=YES
bounds_geometry_field_inventory_complete=YES
bounds_flag_field_inventory_complete=YES
mapping_initializer_source_stride=0x150 present=YES
image_local_display_repair_surface_audit_exact=YES
RESULT: PASS
~~~

If Snow fails, stop and return only the Snow report.

## Phase B — Lion native reference

Only after Snow passes, run the same analyzer on Lion:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-image-local-display-repair-surface.py \
  ./ppc-carbon-gui-image-local-display-repair-surface-lion.txt
~~~

Require:

~~~text
mode=lion
slice_exact=YES
main_lookup_field_inventory_complete=YES
bounds_geometry_field_inventory_complete=YES
bounds_flag_field_inventory_complete=YES
mapping_initializer_source_stride=0x17c present=YES
image_local_display_repair_surface_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

Return only:

~~~text
ppc-carbon-gui-image-local-display-repair-surface-snow.txt
ppc-carbon-gui-image-local-display-repair-surface-lion.txt
~~~

## Decision gate after the audit

If `_lookupMasterDisplay` and the bounds path can be satisfied from a small, explicitly mapped set of Lion-layout fields without depending on Snow's mis-strided count>1 local-record pointers, the next review may specify a narrowly scoped image-local compatibility routine. It must still be translated-PPC-on-Lion-only, preserve Snow behavior, retain display locking/update semantics, and avoid display-ID substitution.

If the required surface reaches broad `_lookupDisplay`, `_bindDisplayMapping`, or multi-record mapping construction, do not implement a field-only CoreGraphics text patch. That would mean the repair is no longer narrow; the next review must compare a purpose-built direct-Lion-layout helper against a complete lifecycle projection with correct `0x17c -> 0x150` multi-record conversion.

A persistent partial projection remains prohibited because normal bind/rebind consumes fields outside the proven main-lookup projection window.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not build or load an interposer.
- Do not patch CoreGraphics or HIToolbox.
- Do not modify process-local display pointers.
- Do not persist the one-record projection.
- Do not mutate server-owned display shared memory.
- Do not normalize or substitute display IDs.
- Do not rewrite event or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, or XNU.
