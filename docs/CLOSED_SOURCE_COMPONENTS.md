# Closed-source component inventory

The collector takes the complete Snow Leopard 10.6.8 `/usr/libexec/oah` directory rather than relying on a brittle hard-coded list.

The validated 10.6.8 (10K549) payload confirms these OAH components:

- `/usr/libexec/oah/translate` — i386 PowerPC-to-x86 translation executable selected by XNU's architecture handler.
- `/usr/libexec/oah/RosettaNonGrata` — stand-in executable used when Rosetta is unavailable.
- `/usr/libexec/oah/Shims/` — compatibility shims, including ApplicationServices, CoreFoundation, IOKit, GLEngine, `Interposers.dylib`, `BDL.dylib`, `libmathCommon.A.dylib`, and `libSystem.B.dylib`.

There is **no `/usr/libexec/oah/translated` executable** in the inspected Snow Leopard 10.6.8 runtime.

The collector also records these when present:

- `/private/var/db/RosettaVersion.plist`
- `/private/var/db/receipts/*Rosetta*` and `*rosetta*` (provenance/diagnostics only)
- `/private/var/db/dyld/dyld_shared_cache_rosetta`
- `/private/var/db/dyld/dyld_shared_cache_rosetta.map`
- `/Library/Preferences/com.apple.ReportMessages.domains`
- `/System/Library/OAH/`

Although `translate` contains an absolute reference to `/System/Library/OAH/nbb/`, a direct audit of the validating 10.6.8 build 10K549 source found `/System/Library/OAH` absent. It is therefore not considered a required component.

`ROSETTA_PACKAGE_FILES.txt` is generated from `pkgutil --files` for the Rosetta package receipts. On the audited source, both the base Rosetta receipt and the 10.6.8 combo-update receipt identify `/usr/libexec/oah/translate` as their payload file.

A new postmortem finding identifies a separate guest-loader dependency: `translate` explicitly opens `/usr/lib/dyld` while requesting a PowerPC Mach-O slice. Lion's native dyld has no PPC slice, so a controlled compatibility experiment may require a private Snow Leopard PPC-capable dyld at an alternate path. This file is **not** part of the public runtime payload inventory, must never replace Lion's native `/usr/lib/dyld`, and must never be committed. See `PPC_DYLD_GAP.md`.

The Snow Leopard Rosetta cache is mutable and can be rebuilt when the system shared cache changes. The collector hashes the source and staged cache after copying and refuses to create an archive if the file changes during collection. The manifest records cache size and modification epoch.

The currently validated `dyld_shared_cache_rosetta` identifies itself as a PPC cache (`dyld_v1     ppc`) and its map contains 180 unique PPC image paths. An older cache snapshot contained three additional private symbolication/debugging frameworks; their removal is documented in `VALIDATED_PAYLOAD.md`. Because Lion removed PPC slices from many system frameworks, the runtime installer installs this isolated Rosetta cache while leaving Lion's native i386/x86_64 caches untouched.

## What to provide for debugging

Do not upload the proprietary payload to a public GitHub repository. If a test fails, the useful diagnostic material is:

1. output of `scripts/collect-lion-test-report.sh` or `scripts/diagnose-on-lion.sh`;
2. `ROSETTA_PAYLOAD_MANIFEST.txt` and `ROSETTA_PACKAGE_FILES.txt`;
3. `file` and `otool -L` output for the failing PowerPC executable;
4. the exact console/Terminal error and any relevant `translate_*.crash` report.
