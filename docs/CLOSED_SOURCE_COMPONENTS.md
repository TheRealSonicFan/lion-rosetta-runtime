# Closed-source component inventory

The collector takes the complete Snow Leopard 10.6.8 `/usr/libexec/oah` directory rather than relying on a brittle hard-coded list.

The uploaded 10.6.8 (10K549) payload confirms these OAH components on that installation:

- `/usr/libexec/oah/translate` — i386 PowerPC-to-x86 translation executable selected by XNU's architecture handler.
- `/usr/libexec/oah/RosettaNonGrata` — stand-in executable used when Rosetta is unavailable.
- `/usr/libexec/oah/Shims/` — compatibility shims, including ApplicationServices, CoreFoundation, IOKit, GLEngine, `Interposers.dylib`, `BDL.dylib`, `libmathCommon.A.dylib`, and `libSystem.B.dylib`.

There is **no `/usr/libexec/oah/translated` executable** in the inspected Snow Leopard 10.6.8 runtime. Earlier project notes that expected one were incorrect and have been removed.

The collector also records these when present:

- `/private/var/db/RosettaVersion.plist`
- `/private/var/db/receipts/*Rosetta*` and `*rosetta*` (provenance/diagnostics only)
- `/private/var/db/dyld/dyld_shared_cache_rosetta`
- `/private/var/db/dyld/dyld_shared_cache_rosetta.map`
- `/Library/Preferences/com.apple.ReportMessages.domains`
- `/System/Library/OAH/` — `translate` contains an absolute reference to `/System/Library/OAH/nbb/`; however, a direct audit of the validating 10.6.8 build 10K549 source found `/System/Library/OAH` absent. The collector still captures it if another Snow Leopard installation has it, but it is not considered a required component.

`ROSETTA_PACKAGE_FILES.txt` is generated from `pkgutil --files` for the Rosetta package receipts when available. On the audited 10K549 source, both the base Rosetta receipt and the 10.6.8 combo-update receipt identify `/usr/libexec/oah/translate` as their payload file. The file list is diagnostic metadata only and contains no proprietary binary data.

The Snow Leopard Rosetta cache is mutable: it can be rebuilt when the system shared cache changes. The collector therefore hashes the source and staged cache after copying and refuses to create an archive if the file changes during collection. The manifest also records the source cache size and modification epoch.

The inspected `dyld_shared_cache_rosetta` identifies itself as a PPC cache (`dyld_v1     ppc`) and its map contains 183 PPC system images. Because Lion removed PPC slices from many of those frameworks, the runtime installer installs this isolated Rosetta cache while leaving Lion's native i386/x86_64 caches untouched. This remains an experimental compatibility boundary: preserve exact loader/crash diagnostics before copying any additional Snow Leopard system files.

## What to provide for debugging

Do not upload the proprietary payload to a public GitHub repository. If a test fails, the useful diagnostic material is:

1. output of `scripts/diagnose-on-lion.sh`;
2. `ROSETTA_PAYLOAD_MANIFEST.txt` and `ROSETTA_PACKAGE_FILES.txt` (paths/hashes/sizes, not binary contents);
3. `file` and `otool -L` output for the failing PowerPC executable;
4. the exact console/Terminal error and any `translate_*.crash` report.
