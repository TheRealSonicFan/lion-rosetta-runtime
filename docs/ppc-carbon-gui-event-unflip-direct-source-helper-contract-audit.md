# PPC Carbon GUI event-unflip direct-source helper contract audit

## Status

**NEXT STEP — PROVE A SOURCE-ONLY EVENT-UNFLIP HELPER CAN BYPASS THE MIS-STRIDED LOCAL MAPPING BEFORE ANY PATCHABILITY WORK.**

The image-local repair-surface reports pass on both pinned releases. They close the remaining field-only patch option: Snow main-display lookup uses the already-proven +0x1c identity/status correspondence, but display bounds use a distinct +0x0c geometry shift plus a +0x1c selector/flag shift, and the Snow mapping builder derives local record pointers with a 0x150 source stride while Lion source records are 0x17c. A displacement-only repair cannot therefore be count>1 safe.

The reports also show why the next candidate should not be a complete persistent projection by default. Lion native `_lookupMasterDisplay` only consults record `+0x12e` and linked display ID `+0x114`; Lion native `_CGSGetDisplayBounds` then dereferences the selected record and reads only `+0x131` plus geometry `+0xdc..+0xf8`. Snow's bounds implementation has an additional local-entry `+0x48` branch that Lion native does not need. The direct-source candidate is therefore to bypass Snow's local mapping only for the zero-cache event-unflip fallback: scan the already-resolved server-owned Lion source read-only using its native 0x17c record stride, reproduce Lion main/master selection by record fields, and produce the native Lion bounds without leaving any projected record installed.

This is still only a candidate. The source mapping and notification lifecycle must be closed before reviewing a text patch or helper injection. In particular, the helper must not make server-owned writes, must stop if source state is absent or invalid, and must not assume that a stale source pointer remains valid across display-server shutdown or remapping.

## Prepared analyzer

Current runtime `main` provides:

~~~text
scripts/audit-ppc-carbon-gui-event-unflip-direct-source-helper-contract.py
analyzer_version=1
audit_contract=carbon-gui-event-unflip-direct-source-helper-contract-v1
~~~

The analyzer is static-only. It verifies the pinned CoreGraphics slice, validates the private event-unflip/main/bounds edges, closes the main/master/bounds record-field sets, verifies source/local strides and the event cached-extent offset, and emits the complete focused lifecycle bodies:

~~~text
_CGSGetUnflippedEventLocation
_lookupMainDisplay
_lookupMasterDisplay
_lookupDisplay
_CGSGetDisplayBounds
_initCGDisplayMappings / _initDisplayMappings
_updateAllDisplayInfoAsNeeded
_CGSReleaseAllDisplays
_CGSDisplayNotifyProc / __CGSDisplayNotifyProc
_CGSDisplayServerShutdown
~~~

The accepted prior source-global rule remains authoritative: loaded translated-PPC runtime globals must be resolved by decoding the loaded `_lookupMainDisplay` PIC references, not by adding standalone VM addresses to the image header.

## Phase A — Snow Leopard PPC

Run:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-event-unflip-direct-source-helper-contract.py \
  ./ppc-carbon-gui-event-unflip-direct-source-helper-contract-snow.txt
~~~

Require:

~~~text
mode=snow
slice_exact=YES
source_record_base_0x20_present=YES
source_record_stride=0x150 present=YES
local_mapping_stride=0x58 present=YES
event_cached_extent_offset=0xc6 present=YES
main_record_field_closure=YES
master_record_field_closure=YES
bounds_record_field_closure=YES
snow_bounds_local_entry_0x48_dependency=YES
ppc_byte_swap_instruction_in_lookupDisplay=YES
event_unflip_direct_source_helper_contract_audit_exact=YES
RESULT: PASS
~~~

If Snow fails, stop and return only the Snow report.

## Phase B — Lion native reference

Only after Snow passes, run on Lion:

~~~sh
/usr/bin/python ./scripts/audit-ppc-carbon-gui-event-unflip-direct-source-helper-contract.py \
  ./ppc-carbon-gui-event-unflip-direct-source-helper-contract-lion.txt
~~~

Require:

~~~text
mode=lion
slice_exact=YES
source_record_base_0x20_present=YES
source_record_stride=0x17c present=YES
local_mapping_stride=0x68 present=YES
event_cached_extent_offset=0xbe present=YES
main_record_field_closure=YES
master_record_field_closure=YES
bounds_record_field_closure=YES
event_unflip_direct_source_helper_contract_audit_exact=YES
RESULT: PASS
~~~

The Lion `_CGSMainDisplayID -> _lookupMainDisplay` relationship is indirect through `_lookupDisplayNumber`; that is expected and is not a failure condition.

## Return evidence

Return only:

~~~text
ppc-carbon-gui-event-unflip-direct-source-helper-contract-snow.txt
ppc-carbon-gui-event-unflip-direct-source-helper-contract-lion.txt
~~~

## Decision gate after the audit

If the returned lifecycle bodies confirm that the active source mapping can be consumed read-only under the display lock while main/master/bounds selection is reproduced entirely by direct source scan, the next step will be a static patchability audit of the zero-cache block in Snow PPC `_CGSGetUnflippedEventLocation`. That review will prefer one event-local out-of-line boundary that bypasses both the broken private main lookup and the broken private bounds lookup; it will not patch global `_CGSMainDisplayID` or `_CGSGetDisplayBounds` behavior.

If a correct source-only helper would still need to drive Snow's mis-strided mapping initializer/rebind path, or if source lifetime cannot be made exact without installing a projected local view, stop. The next engineering branch must then specify a complete multi-record lifecycle projection rather than a partial projection or a field-only patch.

No CoreGraphics text modification, branch island, helper injection, persistent projection, or original GUI run is authorized by this audit.

## Safety boundary

- Do not launch the original PPC Carbon GUI subject.
- Do not create, move, drag, or click a window.
- Do not build or load an interposer or helper.
- Do not patch CoreGraphics or HIToolbox.
- Do not modify process-local display pointers.
- Do not persist or broaden the one-record projection.
- Do not mutate server-owned display shared memory.
- Do not normalize or substitute display IDs.
- Do not rewrite event or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify WindowServer, Rosetta caches, dyld, or XNU.
