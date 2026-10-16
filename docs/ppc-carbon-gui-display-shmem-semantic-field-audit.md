# PPC Carbon GUI display-shmem semantic-field audit

## Status

**COMPLETE — MAIN-DISPLAY +0x1c SEMANTIC SHIFT CONFIRMED.**

The returned analyzer-v1 reports pass on Snow Leopard PPC and Lion i386 with
the pinned CoreGraphics slices.

The main-display path establishes a coherent field correspondence:

~~~text
Snow   Lion   delta
0x0f4  0x110  +0x1c
0x0f8  0x114  +0x1c
0x10c  0x128  +0x1c
0x10d  0x129  +0x1c
0x10e  0x12a  +0x1c
0x110  0x12c  +0x1c
0x111  0x12d  +0x1c
0x112  0x12e  +0x1c
0x113  0x12f  +0x1c
~~~

This is a direct release-local reader correspondence, not merely an inference
from the source-record stride.

The previously missing Snow server-side helper is also resolved:
`__XGetDisplayShmem` calls `__CGXGetDisplayShmem@0x2274ec`, which fills
three shared-memory reference pairs. Lion
`__CGXGetDisplayShmem@0x40e8b` likewise fills three pairs. The internal
producers differ, but the output shape remains compatible with the already
closed generated-MIG transport contract. No display-shmem transport adapter is
supported.

Lion's source record is still `0x2c` larger overall (`0x17c` versus
`0x150`), while the confirmed main semantic shift explains only `0x1c`.
The remaining `0x10` is not resolved by this report.

The broad semantic-field reference inventory is useful for locating candidate
users of Lion `+0x118`, `+0x138`, `+0x154`, and `+0x170`, but it
matches equal numeric immediates in many display-named routines and therefore
does not prove that every occurrence is a member of the same display-device
record. A raw live snapshot would not distinguish those cases.

## Completed analyzer

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-semantic-fields.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-semantic-fields-v1
Git blob 5e3b2adacdabb50892ae721db287f4e8bd4dfb6d
~~~

Both returned reports contain:

~~~text
display_shmem_semantic_field_audit_exact=YES
RESULT: PASS
~~~

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-record-writer-layout-audit.md
~~~

Run its static analyzer on Snow PPC and Lion i386 and return only:

~~~text
ppc-carbon-gui-display-shmem-record-writer-layout-snow.txt
ppc-carbon-gui-display-shmem-record-writer-layout-lion.txt
~~~

Do not launch the PPC subject or take a live mapped-memory snapshot before the
writer-side correspondence is reviewed.

## Safety constraints

- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add or broaden a display-shmem adapter.
- Do not copy, rewrite, truncate, or synthesize display shared-memory records.
- Do not patch the mapping/state initializers or private HIToolbox.
- Do not add a `__CGSGetNumberOfDisplays` adapter.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Keep all accepted compatibility policies unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Current boundary

~~~text
display-shmem wire relation                       IDENTICAL
Snow/Lion __CGXGetDisplayShmem output shape       three reference pairs
Snow source/local stride                          0x150 / 0x58
Lion source/local stride                          0x17c / 0x68
main identity/status semantic shift               CONFIRMED +0x1c
total source-record growth                        +0x2c
writer-side unexplained growth                    +0x10
passive mapped-state snapshot                     NOT YET AUTHORIZED
shared-record rewrite                             NOT AUTHORIZED
next action                                       static record writer-layout audit
XNU                                               unchanged
~~~
