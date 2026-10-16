# PPC Carbon GUI display-shmem read-only prefix snapshot

## Status

**COMPLETE — LIVE CAUSAL RECORD-LAYOUT MISMATCH PROVEN.**

The V4 Snow and Lion controls both passed with the pinned probes, no new
diagnostics, and unchanged protected hashes.

The Snow control used loaded-PPC-PIC resolution, obtained a nonzero
`CGSMainDisplayID`, selected one valid display-source record, and captured a
Snow-layout prefix.

The Lion run captured the same Lion display-source object twice:

- once through native Lion i386 CoreGraphics;
- once through translated Snow PPC CoreGraphics under the accepted connection
  prerequisites.

The native and translated Lion snapshots use the same selector pointer, the
same selector index, and the same source pointer. Their captured source prefixes
differ at only one byte in the shared-state header (`raw +0x0c`), consistent
with an advancing seed/counter; the display-record bytes relevant to the
main-display decision are otherwise the same.

Despite that common source:

~~~text
Lion native i386    CGSMainDisplayID = 0x5b81c5c0
Lion translated PPC CGSMainDisplayID = 0x00000000
~~~

## Decisive field-level proof

The prior static reader/writer audits established the main-display semantic
shift:

~~~text
Snow record +0x10e  -> Lion record +0x12a
delta                = +0x1c
~~~

The live snapshots now prove the consequence.

Snow control, legacy status bytes:

~~~text
record +0x10c..+0x113 = 01 01 01 01 00 00 00 00
record +0x10e          = 01
~~~

Lion source interpreted by the translated Snow reader:

~~~text
record +0x10c..+0x113 = 37 03 00 00 00 00 00 00
record +0x10e          = 00
~~~

The same Lion record at native Lion offsets:

~~~text
record +0x128..+0x12f = 01 01 01 01 00 00 00 00
record +0x12a          = 01
~~~

Snow `_lookupMainDisplay` scans the bound source records and requires
record `+0x10e` to be nonzero for the main-display candidate. Lion native
checks the corresponding shifted field at `+0x12a`. Therefore the translated
Snow client rejects the real Lion main-display record at exactly the field
predicted by the static layout audit, while Lion native accepts that same
record.

This closes the causal question:

~~~text
display-shmem transport               release-stable
server-owned source mapping           valid
translated PPC source selection       valid
Snow parser applied to Lion record    incompatible
CGSMainDisplayID == 0 cause           record-layout mismatch
~~~

No display-ID substitution, display-0 normalization, event rewrite, or XNU
change is supported by this result.

## Completed V4 probe

~~~text
tests/ppc-carbon-gui-display-shmem-prefix-snapshot.c
snapshot_contract=carbon-gui-display-shmem-prefix-snapshot-v4
translated_guest_pointer_validation=LOADED_PPC_PIC_PLUS_GUARDED_DIRECT_READ
~~~

The runtime-address correction remains part of the accepted diagnostic model:
standalone CoreGraphics data VM addresses are provenance, while loaded
cross-segment shared-cache references are resolved from the release-pinned
loaded PIC instructions.

## Next controlled step

Do **not** write or overlay the WindowServer-owned Lion record.

The next step is the static ownership/lifecycle audit:

~~~text
docs/ppc-carbon-gui-display-shmem-consumer-topology-audit.md
scripts/audit-ppc-carbon-gui-display-shmem-consumer-topology.py
~~~

Run it first on Snow Leopard and then on Lion. Return only:

~~~text
ppc-carbon-gui-display-shmem-consumer-topology-snow.txt
ppc-carbon-gui-display-shmem-consumer-topology-lion.txt
~~~

That audit must establish every process-local consumer of the selector/source/
local globals, the source installation point, local-mapping construction, and
display-change/mapping-change refresh lifecycle before a proof-only
process-local Snow-layout projection can be designed.

## Safety boundary

- Do not mutate server-owned Lion display shared memory.
- Do not create a Snow-layout projection yet.
- Do not substitute or normalize display IDs.
- Do not patch `_CGSMainDisplayID`, mapping initializers, or private
  HIToolbox.
- Do not add a `__CGSGetDisplayShmem` wire adapter.
- Do not rewrite event, hit-test, or movement payloads.
- Keep the accepted compatibility stack unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.
