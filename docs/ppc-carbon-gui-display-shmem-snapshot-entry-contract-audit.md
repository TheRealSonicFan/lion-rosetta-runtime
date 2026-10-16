# PPC Carbon GUI display-shmem snapshot-entry contract audit

## Status

**V1 SOURCE-POINTER CLASSIFICATION CORRECTED / V2 SOURCE-SLOT ROUTE ESTABLISHED.**

The returned v1 reports themselves contain the disassembly needed to diagnose
the failed Snow live control. The v1 analyzer correctly identified the mode-2
shared-memory mapping store, but incorrectly treated that mapping as the
display-record source consumed by the display-mapping and main-display lookup
paths.

That distinction matters.

On Snow, `_initCGDisplayState` stores the mode-2 resolved pointer at:

~~~text
0x70046c
~~~

But `_initCGDisplayMappings` and `_lookupMainDisplay` use a different
two-entry source-pointer array:

~~~text
selector pointer global   0x6ff26c
source pointer array      0x700460
local mapping array       0x700458
mode-2 mapping            0x70046c   (not the display source array)
~~~

The active source pointer is selected as:

~~~text
selector = **0x6ff26c
source   = *(0x700460 + selector * 4)
local    = *(0x700458 + selector * 4)
~~~

On Lion native i386, the corresponding route is:

~~~text
selector pointer global   0x948630
source pointer array      0x94983c
local mapping array       0x94984c
mode-2 mapping            0x949848   (not the display source array)
~~~

The active source pointer is selected as:

~~~text
selector = **0x948630
source   = *(0x94983c + selector * 4)
local    = *(0x94984c + selector * 4)
~~~

The two-entry source arrays are the objects whose first word is consumed as the
display count and whose records begin at `+0x20`. The v1 live probe instead
read the distinct mode-2 object, so its invalid "record count" was a diagnostic
address-selection error rather than evidence that the display source itself
was corrupt.

No additional static collection is required before retrying the live Snow
control because the already returned v1 reports contain the complete
`_lookupMainDisplay` and mapping-initializer bodies that establish these
addresses. The analyzer has nevertheless been advanced for reproducibility.

## Corrected analyzer

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py
analyzer_version=2
audit_contract=carbon-gui-display-shmem-snapshot-entry-contract-v2
Git blob 16b322bf9a772fca008b21d753facd345d3ec664
~~~

V2 distinguishes:

~~~text
selector_global
source_array
local_array
mode2_mapping
~~~

and requires the source-array address derived from `_lookupMainDisplay` to
match the source-array address derived independently from
`_initCGDisplayMappings` / `_initDisplayMappings`.

## Superseded v1 conclusion

The following v1 statement is withdrawn:

~~~text
snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_INITIALIZER_MAPPING_GLOBAL
~~~

The corrected route is:

~~~text
snapshot_route=CALL_EXTERNAL_CGSMainDisplayID_THEN_READ_ACTIVE_SOURCE_ARRAY_SLOT
~~~

The mode-2 mapping global remains valid static information; it is simply not
the record source to decode.

## Next controlled step

Follow the corrected:

~~~text
docs/ppc-carbon-gui-display-shmem-prefix-snapshot.md
~~~

Rebuild the probes from current `main` on Snow Leopard, because the probe
source changed. Do not reuse the v1 binaries or SHA sidecars. Then rerun the
Snow control.

## Safety boundary

- No shared-memory write is authorized.
- No display-ID normalization or substitution is authorized.
- No private `__CGSGetDisplayShmem` or resolver call is authorized.
- No original GUI/titlebar subject run is authorized for this step.
- No event or movement rewrite is authorized.
- No CoreGraphics, WindowServer, Rosetta cache, dyld, or XNU modification is
  authorized.

## Current boundary

~~~text
v1 mode-2 pointer classification                  CORRECTED
Snow active source array                          0x700460
Snow active selector global                       0x6ff26c
Lion active source array                          0x94983c
Lion active selector global                       0x948630
mode-2 mapping objects                            separate / not decoded as display records
passive source-prefix snapshot                    RETRY WITH V2 PROBE
shared-record rewrite                             NOT AUTHORIZED
XNU                                               unchanged
~~~
