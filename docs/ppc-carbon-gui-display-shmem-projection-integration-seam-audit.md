# PPC Carbon GUI display-shmem projection integration-seam audit

## Status

**NEXT STEP — STATIC INTEGRATION-SEAM AUDIT BEFORE ANY PRODUCTION PROJECTION.**

The one-record projection proof now passes on both required controls. Snow Leopard PPC returns its normal nonzero main display without any projection. On Lion, translated PPC begins with a zero public main-display result, temporarily installs the already-proven +0x1c semantic window in one process-local record under the display lock, obtains the same nonzero display ID as native Lion, restores the original local pointer before unlock, and leaves the source mapping and protected system state unchanged.

That closes the causal question for main-display lookup. It does **not** yet identify a safe production insertion point.

The release/rebuild audit remains binding: Snow _bindDisplayMapping reads record fields outside the 0x20 lookup window, and display notification / mapping-seed paths can rebind the existing local entries. Therefore the proof's partial projection must not be made persistent or exposed to normal bind/rebind.

There is a second integration constraint. The historical drag/display audit shows that Snow PPC _CGSGetUnflippedEventLocation reaches _CGSMainDisplayID by an image-local direct branch before passing its return value to _CGSGetDisplayBounds. A normal dyld __DATA,__interpose tuple for _CGSMainDisplayID therefore cannot be assumed to repair the real drag path. The next step is to identify the first imported, interposable call boundary in the actual HIToolbox titlebar-tracking path that encloses this fallback.

## Prepared analyzer

Use:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-projection-integration-seam.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-projection-integration-seam-v1
Git blob ce56c3eb38109cc147649022c64a3823835131e2
~~~

The analyzer is static-only. It verifies the pinned CoreGraphics and HIToolbox slices, confirms the image-local CoreGraphics fallback edges, inventories the relevant CoreGraphics event-location/display bodies, and scans HIToolbox titlebar-tracking families for calls to:

~~~text
_CGEventGetUnflippedLocation
_CGEventGetUnflippedWindowLocation
_CGSGetUnflippedEventLocation
_CGSGetUnflippedWindowEventLocation
_CGSGetWindowMouseLocation
_CGSMainDisplayID
_CGSGetDisplayBounds
~~~

For each candidate it records whether the symbol is an undefined import of HIToolbox and whether a titlebar-family call site references it. This distinguishes a plausible dyld interposition seam from an image-local CoreGraphics branch.

Pinned slices:

~~~text
Snow 10.6.8 / 10K549
CoreGraphics ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a
HIToolbox ppc7400
fcad83329ce788d33688aece9c7dfe80426d4ab2b94636acda1d8376a889318f

Lion 10.7.5 / 11G63
CoreGraphics i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
HIToolbox i386
b208091f3d4a88f1d95f6981e311c4e88c2769551d68a9a2662e00c77d4c1ae6
~~~

## Phase A — Snow Leopard PPC static audit

On Snow Leopard 10.6.8 / 10K549, use a verified current runtime tree transferred from a modern staging system and run:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-projection-integration-seam.py   ./ppc-carbon-gui-display-shmem-projection-integration-seam-snow.txt
~~~

Require:

~~~text
mode=snow
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
edge=_CGSGetUnflippedEventLocation->_CGSMainDisplayID present=YES binding=image-local
edge=_CGSGetUnflippedEventLocation->_CGSGetDisplayBounds present=YES binding=image-local
edge=_CGEventGetUnflippedLocation->_CGSGetUnflippedEventLocation present=YES binding=image-local
display_shmem_projection_integration_seam_audit_exact=YES
RESULT: PASS
~~~

The number of imported titlebar candidate calls is evidence, not a pass criterion. Do not modify code locally if it is zero.

If Phase A fails, stop and return only the Snow report.

## Phase B — Lion native-reference static audit

Only after Snow passes, run the same analyzer on Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-display-shmem-projection-integration-seam.py   ./ppc-carbon-gui-display-shmem-projection-integration-seam-lion.txt
~~~

Require:

~~~text
mode=lion
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
display_shmem_projection_integration_seam_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

After both audits pass, return only:

~~~text
ppc-carbon-gui-display-shmem-projection-integration-seam-snow.txt
ppc-carbon-gui-display-shmem-projection-integration-seam-lion.txt
~~~

## Decision gate after the audit

If Snow exposes an imported titlebar-path event-location boundary that encloses the failing zero-cache fallback, the next design review can consider a narrowly scoped adapter at that boundary. Such an adapter may use the already-proven locked projection only long enough to obtain the correct main display, restore the local record pointer, unlock, and then continue the bounds conversion with the returned nonzero ID.

If no such imported boundary exists, do not compensate with a naive _CGSMainDisplayID interposer. The next review must instead choose between a separately justified image-local CoreGraphics patch and a fully specified lifecycle projection. A count>1 display configuration remains outside the one-record proof; any later lifecycle design must project every relevant local record coherently or stop.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not build or load a new interposer in this step.
- Do not modify a process-local display record pointer in this step.
- Do not make the +0x1c partial projection persistent.
- Do not expose a partial projection to _bindDisplayMapping or notification-driven rebuilds.
- Do not mutate server-owned Lion display shared memory.
- Do not substitute or normalize display IDs.
- Do not rewrite event or movement payloads.
- Do not patch CoreGraphics or private HIToolbox yet.
- Keep the accepted compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, or XNU.
