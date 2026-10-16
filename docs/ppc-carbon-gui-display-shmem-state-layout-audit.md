# PPC Carbon GUI display shared-state layout audit

## Status

**COMPLETE — RECORD STRIDE DELTA CONFIRMED; SEMANTIC FIELD SHIFT IDENTIFIED.**

The returned analyzer-v1 reports pass on Snow Leopard PPC and Lion i386 with
the pinned CoreGraphics slices.

The generated display-shmem transport remains release-stable, but the resolved
shared-state record geometry is not:

~~~text
mapped source base      Snow +0x20   Lion +0x20
source record stride    Snow 0x150   Lion 0x17c
local mapping stride    Snow 0x58    Lion 0x68
~~~

Both mapping builders read the per-display count from the mapped object's first
word before walking the source records.

The main-display consumers reveal a stronger correspondence than stride alone.
The identity/status fields used by Snow `_lookupMainDisplay` reappear in Lion
exactly `0x1c` later:

~~~text
Snow   Lion
0x0f4  0x110
0x0f8  0x114
0x10c  0x128
0x10d  0x129
0x10e  0x12a
0x110  0x12c
0x111  0x12d
0x112  0x12e
0x113  0x12f
~~~

Lion's total source-record growth is `0x2c`, so the `+0x1c` semantic
block shift does not yet explain another `0x10` of layout growth. Lion also
uses `+0x118`, `+0x138`, `+0x154`, and `+0x170` in related display
paths; their exact Snow correspondence is not yet established.

The reports also show Snow `__XGetDisplayShmem` calling
`__CGXGetDisplayShmem`, just as Lion does. Analyzer v1 emitted Lion's
`__CGXGetDisplayShmem` body but did not include the Snow helper as a required
target. The next audit closes that omission and inventories the semantic-field
read/write references.

No shared-memory record rewrite, display-ID substitution, or normalization is
authorized from this result.

## Completed analyzer

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-state-layout.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-state-layout-v1
Git blob 3d2bb564cdb5da8482961c7e29092bd1c6d885b0
~~~

Both returned reports contain:

~~~text
display_shmem_state_layout_audit_exact=YES
RESULT: PASS
~~~

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-semantic-field-audit.md
~~~

Run its static analyzer on Snow PPC and Lion i386 and return only:

~~~text
ppc-carbon-gui-display-shmem-semantic-fields-snow.txt
ppc-carbon-gui-display-shmem-semantic-fields-lion.txt
~~~

Do not launch the PPC subject or compensate for a failed static report with a
live probe.

## Safety constraints

- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add a `__CGSGetDisplayShmem` adapter.
- Do not rewrite, copy, truncate, or synthesize display shared-memory records.
- Do not patch the mapping/state initializers or private HIToolbox.
- Do not add a `__CGSGetNumberOfDisplays` adapter.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Keep the accepted v9 SharedWindow bridge, exact-six bitmap-info rule, and
  exact-21 notification policy unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Current boundary

~~~text
display-shmem wire relation                       IDENTICAL
mapped source base                                +0x20 on both
Snow source/local stride                          0x150 / 0x58
Lion source/local stride                          0x17c / 0x68
main identity/status field shift                  +0x1c candidate
total source-record growth                        +0x2c
unexplained growth                                +0x10
shared-record rewrite                             NOT AUTHORIZED
next action                                       static semantic-field audit
XNU                                               unchanged
~~~
