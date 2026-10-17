# PPC Carbon GUI titlebar CoreGraphics import-closure audit

## Status

**NEXT STEP — CLOSE THE TITLEBAR-TO-COREGRAPHICS IMPORT GRAPH BEFORE CHOOSING PATCH VS LIFECYCLE PROJECTION.**

Both projection integration-seam reports pass. The decisive result is negative: neither Snow nor Lion reports any of the seven named event-location/display candidates as HIToolbox imports, and both report zero candidate call sites in the focused titlebar families. This rules out the specific dyld-interposition seams tested by the preceding audit.

It does not yet prove that the titlebar path has no higher-level imported CoreGraphics boundary at all. The v1 integration-seam analyzer intentionally searched only the named candidate list; it did not intersect the complete HIToolbox undefined-symbol set with CoreGraphics exports or compute a reachable HIToolbox direct-call closure from the titlebar tracking roots. That broader static closure is required before selecting an image-local CoreGraphics patch or a full display-mapping lifecycle projection.

The Lion v1 report also prints symbolic edge=NO for the three CoreGraphics image-local edges because its i386 disassembly renders those calls as numeric addresses. The emitted bodies show direct calls to the exact reported target addresses, so those labels are an analyzer presentation limitation, not evidence that Lion lacks the equivalent local edges. No rerun of the completed v1 audit is required for that presentation issue.

## Prepared analyzer

Current runtime main provides:

~~~text
scripts/audit-ppc-carbon-gui-titlebar-coregraphics-import-closure.py
analyzer_version=1
audit_contract=carbon-gui-titlebar-coregraphics-import-closure-v1
Git blob 7d2c96b36d4687a983209860b852036dcbb72819
~~~

The analyzer is static-only. For each pinned release it:

- verifies the exact CoreGraphics and HIToolbox architecture slices;
- enumerates every HIToolbox undefined import that is also a CoreGraphics text symbol;
- identifies the TrackMouseLocation / TWindowTracker / TDragTracker / DragWindow roots;
- resolves direct intra-HIToolbox calls by symbol name or exact target address;
- follows the reachable direct-call closure from those roots;
- reports every reachable call to a resolved CoreGraphics import, without a preselected API-name list;
- reports unresolved direct and indirect calls separately so a zero imported-call result cannot be overinterpreted when virtual/indirect targets remain unresolved.

Pinned slices remain:

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

## Phase A — Snow Leopard PPC

On Snow Leopard 10.6.8 / 10K549, from a verified transfer of current runtime main:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-coregraphics-import-closure.py \
  ./ppc-carbon-gui-titlebar-coregraphics-import-closure-snow.txt
~~~

Require:

~~~text
mode=snow
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
candidate_list_closed=YES
all_hitoolbox_coregraphics_imports_enumerated=YES
titlebar_direct_call_closure_computed=YES
titlebar_coregraphics_import_closure_audit_exact=YES
RESULT: PASS
~~~

The reachable CoreGraphics-import count and unresolved-call count are evidence, not pass criteria. If the audit itself fails, stop and return only the Snow report.

## Phase B — Lion native reference

Only after Snow passes, run the same analyzer on Lion 10.7.5 / 11G63:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-titlebar-coregraphics-import-closure.py \
  ./ppc-carbon-gui-titlebar-coregraphics-import-closure-lion.txt
~~~

Require:

~~~text
mode=lion
CoreGraphics slice_exact=YES
HIToolbox slice_exact=YES
candidate_list_closed=YES
all_hitoolbox_coregraphics_imports_enumerated=YES
titlebar_direct_call_closure_computed=YES
titlebar_coregraphics_import_closure_audit_exact=YES
RESULT: PASS
~~~

## Return evidence

Return only:

~~~text
ppc-carbon-gui-titlebar-coregraphics-import-closure-snow.txt
ppc-carbon-gui-titlebar-coregraphics-import-closure-lion.txt
~~~

## Decision gate after the audit

If a CoreGraphics import is reachable from the titlebar closure, the next review must inspect that exact call contract and determine whether a call-scoped adapter can encompass the failing event-unflip/main-display fallback without persistent projection state.

If the reachable CoreGraphics-import count is zero but unresolved indirect calls remain, do not choose the patch/projection architecture yet; the next step must resolve the relevant indirect targets or vtable slots.

If the reachable count is zero and the closure has no unresolved path capable of crossing into CoreGraphics, the interposable-seam branch is closed. The next review may then compare a narrowly justified image-local CoreGraphics repair against a fully specified multi-record lifecycle projection. The one-record +0x1c proof remains insufficient to authorize persistent projection or count>1 operation.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not build or load a new interposer.
- Do not patch CoreGraphics or HIToolbox.
- Do not modify a process-local display record pointer.
- Do not make the +0x1c proof projection persistent.
- Do not mutate server-owned display shared memory.
- Do not normalize or substitute display IDs.
- Do not rewrite event or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, or XNU.
