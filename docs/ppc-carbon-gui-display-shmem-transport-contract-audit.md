# PPC Carbon GUI display-shmem transport contract audit

## Status

**COMPLETE — GENERATED DISPLAY-SHMEM WIRE CONTRACT IS RELEASE-STABLE.**

The returned analyzer-v1 reports pass on Snow Leopard PPC and Lion i386 with
the pinned CoreGraphics slices.

The generated `__CGSGetDisplayShmem` client contract is identical on the two
reference releases:

~~~text
request ID       0x748b
reply ID         0x74ef
Mach bits        0x1513
mach_msg option  0x00000003
send size        0x18
receive size     0x44
success size     0x3c
error size       0x24
~~~

Both clients use the same MIG reply-port lifecycle, the same reply-ID and size
checks, and the same NDR-aware 32-bit conversion before copying three
shared-memory reference pairs to the caller. There is no request-ID shift,
reply-ID shift, or immediate request/reply geometry mismatch at this boundary.

The release-local display-state initializers also consume those results in the
same broad way: the first returned reference pair is resolved through
`_CGSResolveShmemReference` with mode `2`, and the remaining two pairs
are resolved with mode `1`.

Therefore a `__CGSGetDisplayShmem` adapter is not supported by the static
evidence.

## Resolved transport contract

### Snow Leopard PPC

`__CGSGetDisplayShmem`:

~~~text
bits     0x1513
request  0x748b
option   0x3
send     0x18
receive  0x44
reply    0x74ef
sizes    0x3c success / 0x24 error
~~~

### Lion i386

`__CGSGetDisplayShmem`:

~~~text
bits     0x1513
request  0x748b
option   0x3
send     0x18
receive  0x44
reply    0x74ef
sizes    0x3c success / 0x24 error
~~~

The wire relation is therefore:

~~~text
display_shmem_wire_relation=IDENTICAL
display_shmem_id_adapter_authorized=NO
display_shmem_schema_adapter_authorized=NO
~~~

## Post-transport differential

The first concrete release differential is in the mapped state consumed after
the transport succeeds.

Snow `_initCGDisplayMappings` walks the mapped per-display source records from
`+0x20` with a `0x150` source stride and builds `0x58`-byte local
mapping entries.

Lion `_initDisplayMappings` also starts at `+0x20`, but walks source
records with a `0x17c` stride, builds `0x68`-byte local mapping entries,
and directly reads mapped source fields at `+0x138` and `+0x170`.

This difference is downstream of the now-proven identical MIG contract and is
the next engineering boundary.

## Analyzer provenance

The completed reports were produced by:

~~~text
scripts/audit-ppc-carbon-gui-display-shmem-transport-contract.py
analyzer_version=1
audit_contract=carbon-gui-display-shmem-transport-contract-v1
Git blob 564b9aa76a1e4631eabbe3d1e27ecb177661b820
~~~

Pinned CoreGraphics slices:

~~~text
Snow 10.6.8 / 10K549, ppc7400
83799ea11d2bb3b15fdc25974f47cf499178f3e1362d2e48e3cc0e1a2108572a

Lion 10.7.5 / 11G63, i386
4859edced4b9488d887f1243a9809d325e14dd12f7051815ba9f1f7875bbab7d
~~~

## Next controlled step

Follow:

~~~text
docs/ppc-carbon-gui-display-shmem-state-layout-audit.md
~~~

That procedure is static-only. It resolves the mapped display shared-state
record geometry, field offsets, lookup consumers, and server-side
`__XGetDisplayShmem` / `__CGXGetDisplayShmem` handlers before any live
observation or shared-record compatibility rule is considered.

Do not rerun the PPC subject for this step.

## Safety constraints

- Do not normalize display ID 0.
- Do not substitute Lion's native display ID into PPC state.
- Do not add a `__CGSGetDisplayShmem` adapter.
- Do not rewrite or clone display shared-memory records.
- Do not patch either mapping/state initializer or mapping globals.
- Do not add an adapter for `__CGSGetNumberOfDisplays`.
- Do not rewrite event fields, hit parts, or `0x7218` movement payloads.
- Do not add the deferred out-of-line event adapter.
- Keep the accepted v9 SharedWindow bridge and all accepted titlebar,
  notification, and CoreUI compatibility rules unchanged.
- Do not modify CoreGraphics, HIToolbox, WindowServer, Rosetta caches, dyld,
  or XNU.

## Current boundary

~~~text
v9 GetSharedWindow bridge                         target-proven
Lion public mouse-down                            sane / inDrag (4)
Snow display-shmem request/reply                  0x748b / 0x74ef
Lion display-shmem request/reply                  0x748b / 0x74ef
Snow/Lion send/receive                            0x18 / 0x44
display-shmem wire relation                       IDENTICAL
display-shmem adapter                             NOT AUTHORIZED
Snow mapped display-record stride                 0x150
Lion mapped display-record stride                 0x17c
Snow local mapping stride                         0x58
Lion local mapping stride                         0x68
Lion mapped fields +0x138/+0x170                  referenced
display-ID substitution                           NOT AUTHORIZED
display-0 normalization                           NOT AUTHORIZED
shared-record rewrite                             NOT AUTHORIZED
event/move rewrite                                NOT AUTHORIZED
next action                                       static display shared-state layout audit
XNU                                               unchanged
~~~
