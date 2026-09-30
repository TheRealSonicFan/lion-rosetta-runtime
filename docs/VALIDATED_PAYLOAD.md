# Validated Snow Leopard 10.6.8 payload

This document records hashes and structural facts from the private test payload used to validate the public tooling. It contains no Apple binary data.

## Source

- Product: Mac OS X Server 10.6.8
- Build: 10K549
- Collection time (UTC): 2026-09-30T22:05:23Z
- Private archive SHA-256: `98e587de20c38f3392d1f638c9d9d0f8bece32fba4905373d9b738c03e4d2268`
- Manifest entries verified: 25/25

## Rosetta translator

- Path: `/usr/libexec/oah/translate`
- Size: 2,144,096 bytes
- SHA-256: `4b65c39c7832ed647d15c7a6dbdbb579c9261dac33a1708ebcb2dcbbd166de18`
- Mach-O architecture: i386

The Snow Leopard Rosetta receipts both identify `usr/libexec/oah/translate` as their installed payload file. The source machine does not contain `/System/Library/OAH`, even though `translate` contains the string `/System/Library/OAH/nbb/`.

## Refreshed Rosetta dyld cache

- Path: `/private/var/db/dyld/dyld_shared_cache_rosetta`
- Header magic: `dyld_v1     ppc\0`
- Size: 209,248,256 bytes
- SHA-256: `2968123ebb467633929398c692cfa68e8a13925ead683c5b1a04581c0aee6911`
- Source mtime epoch: `1790803990`
- Map SHA-256: `66e8940757eb909ffb1920ac1510134afafbd5d2d649a9cc7d750753333153f9`
- Map size: 41,511 bytes
- Unique absolute image paths in the map: 180

An earlier cache snapshot had 183 mapped images. The refreshed cache removed these three Apple private symbolication/debugging frameworks and added no new mapped image paths:

- `/System/Library/PrivateFrameworks/CoreSymbolication.framework/Versions/A/CoreSymbolication`
- `/System/Library/PrivateFrameworks/DebugSymbols.framework/Versions/A/DebugSymbols`
- `/System/Library/PrivateFrameworks/Symbolication.framework/Versions/A/Symbolication`

These are not native dependencies of `translate` and are not treated as requirements for the first Rosetta execution test.

## Ancillary state

`/Library/Preferences/com.apple.ReportMessages.domains` exists on the source and is now included by the collector:

- Size: 1,628 bytes
- SHA-256: `2577ab9ae444345952e8f7c516f9a6a1ee27a6a6875ad3bf37df5bdbaa690650`

This file is treated as ancillary rather than a prerequisite for translation.

## Reproducibility rule

The private archive itself is not published. A newly collected payload may legitimately have a different Rosetta cache hash if Snow Leopard rebuilds its shared caches. The collector verifies source-vs-staged hashes and the manifest inspector validates every included file before installation.
