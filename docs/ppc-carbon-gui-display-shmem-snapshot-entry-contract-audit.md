# PPC Carbon GUI display-shmem snapshot-entry contract audit

## Status

**SOURCE-SLOT CONTRACT ESTABLISHED / STANDALONE-TO-RUNTIME ADDRESS MODEL CORRECTED.**

The static audits correctly identify the display-source objects used by the
release-local mapping and main-display lookup paths, but the live V3 Snow run
proved that those standalone VM addresses cannot be used as offsets from the
loaded shared-cache image header.

## Static source contract

Snow PPC standalone CoreGraphics:

~~~text
selector pointer global   0x6ff26c
source pointer array      0x700460
local mapping array       0x700458
mode-2 mapping            0x70046c
~~~

Lion native i386 standalone CoreGraphics:

~~~text
selector pointer global   0x948630
source pointer array      0x94983c
local mapping array       0x94984c
mode-2 mapping            0x949848
~~~

The mode-2 mapping is not the display-record source. The active display source
is selected by the release-local selector byte and two-entry source array.

The static calculations remain exact:

- Snow `_lookupMainDisplay` and `_initCGDisplayMappings` independently
  resolve the same standalone source/local array targets.
- Lion `_lookupMainDisplay` and `_initDisplayMappings` independently
  resolve the same standalone source/local array targets.
- Snow and Lion therefore establish the release-local source-object contract
  needed for the semantic record comparison.

## Runtime-address correction

The following interpretation is superseded:

~~~text
runtime address = loaded image header + standalone data VM address
~~~

That model is not valid for cross-segment shared-cache references.

The V3 Snow run computed:

~~~text
CoreGraphics header      0x93615000
standalone selector      0x006ff26c
assumed runtime slot     0x93d1426c
slot value               0x41a20028
direct read              FAIL
~~~

At the same time, exported `CGSMainDisplayID` returned a nonzero display ID
without a crash. This is consistent with the already-established Rosetta
shared-cache rule from the Process Manager CPS discriminator: `__TEXT` and
`__DATA` may be relocated independently, and the cache-rewritten loaded PIC
instruction is the authority for a cross-segment data reference.

Therefore the live snapshot must decode the loaded
`_lookupMainDisplay` PIC references.

## Analyzer v3

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-snapshot-entry-contract.py
analyzer_version=3
audit_contract=carbon-gui-display-shmem-snapshot-entry-contract-v3
Git blob 137a7f55ca87503d4defa6d665c97086c13649fa
~~~

V3 retains the standalone static calculations but explicitly records:

~~~text
standalone_vmaddrs_are_runtime_offsets=NO
live_runtime_resolution=DECODE_LOADED_LOOKUPMAIN_PIC
image_header_plus_standalone_vmaddr_authorized=NO
~~~

No repeat static collection is required before the V4 live control because the
existing static reports already contain the complete release-pinned
`_lookupMainDisplay` instruction bodies used by the decoder.

## Live route

The current live route is:

~~~text
resolve exported CGSMainDisplayID
derive loaded _lookupMainDisplay from audited same-__TEXT delta
validate loaded release-pinned instruction forms
decode loaded cross-segment PIC immediates
resolve actual selector/source/local runtime globals
call CGSMainDisplayID
read active source slot and source prefix read-only
~~~

The mode-2 mapping remains provenance only and is not dereferenced by the V4
snapshot.

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-prefix-snapshot.md
~~~

Rebuild the V4 probes on Snow, then rerun the Snow control. Do not proceed to
Lion until Snow passes.

## Safety boundary

- No shared-memory write is authorized.
- No display-ID normalization or substitution is authorized.
- No private `__CGSGetDisplayShmem` or resolver call is authorized.
- No original GUI/titlebar subject run is authorized.
- No event or movement rewrite is authorized.
- No CoreGraphics, WindowServer, Rosetta cache, dyld, or XNU modification is
  authorized.
