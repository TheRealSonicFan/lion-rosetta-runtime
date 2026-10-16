# PPC Carbon GUI display-shmem record writer-layout audit

## Status

**COMPLETE — MAIN-DISPLAY WRITER SHIFT CONFIRMED / PREFIX SUFFICIENT FOR A PASSIVE SNAPSHOT.**

The returned analyzer-v1 reports pass on Snow Leopard PPC and Lion i386 with
the pinned CoreGraphics slices.

The decisive writer-side result is the same-named
`_markNewMainDisplay` routine:

~~~text
Snow                        Lion
read  +0x112                read  +0x12e
write +0x10e = 0/1          write +0x12a = 0/1
delta                        +0x1c
~~~

This independently confirms that the main-display status block did not merely
move in readers; the release-local writers moved with it.

The same-function status/debug consumers extend the coherent record prefix:

~~~text
Snow    Lion    delta
0x0fc   0x118   +0x1c
0x100   0x11c   +0x1c
0x104   0x120   +0x1c
0x108   0x124   +0x1c
0x10c   0x128   +0x1c
0x10d   0x129   +0x1c
0x114   0x130   +0x1c
0x138   0x154   +0x1c
~~~

Together with the already closed main-display reader audit, the main identity
and status fields are therefore a release-local layout shift rather than an
incidental immediate match.

The analyzer intentionally still reports some stack/local offsets in large
functions, so it does not establish a complete type map for every record-tail
immediate. Lion's total source-record growth remains `+0x2c`; the coherent
prefix explains `+0x1c`, while another `+0x10` remains in the unresolved
tail. That tail is outside the fields needed to distinguish the current
main-display failure.

A passive snapshot of the already mapped first-record prefix is now justified
in principle, but its entry mechanism must first be pinned statically because
`__CGSGetDisplayShmem` is non-external and must not be invoked through a
guessed private function pointer.

## Completed analyzer

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-record-writer-layout.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-record-writer-layout-v1
Git blob 8af43e52196d0c535722d21d88c1b771046272df
~~~

Both returned reports contain:

~~~text
display_shmem_record_writer_layout_audit_exact=YES
RESULT: PASS
~~~

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-snapshot-entry-contract-audit.md
~~~

Run its static analyzer on Snow PPC and Lion i386 and return only:

~~~text
ppc-carbon-gui-display-shmem-snapshot-entry-contract-snow.txt
ppc-carbon-gui-display-shmem-snapshot-entry-contract-lion.txt
~~~

Do not run a live snapshot or the PPC Carbon GUI subject until those reports
are reviewed.

## Safety constraints

- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not call non-external display-shmem helpers by guessed addresses.
- Do not add or broaden a display-shmem adapter.
- Do not copy, rewrite, truncate, or synthesize display shared-memory records.
- Do not patch display mapping/state initializers or private HIToolbox.
- Do not add a `__CGSGetNumberOfDisplays` adapter.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Keep all accepted compatibility policies unchanged.
- Do not modify CoreGraphics, WindowServer, Rosetta caches, dyld, or XNU.

## Current boundary

~~~text
display-shmem wire relation                       IDENTICAL
main reader semantic displacement                 CONFIRMED +0x1c
main writer semantic displacement                 CONFIRMED +0x1c
coherent proven prefix                            through Snow +0x138 / Lion +0x154
total source-record growth                        +0x2c
unresolved tail growth                            +0x10
passive prefix snapshot                           JUSTIFIED IN PRINCIPLE
snapshot entry route                              STATIC VERIFICATION NEXT
shared-record rewrite                             NOT AUTHORIZED
XNU                                               unchanged
~~~
