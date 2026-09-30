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
- `/System/Library/OAH/` — `translate` contains an absolute reference to `/System/Library/OAH/nbb/`; the tree is captured when present so its role can be tested rather than guessed.

`ROSETTA_PACKAGE_FILES.txt` is generated from `pkgutil --files` for the Rosetta package receipts when available. It is a path inventory only and contains no proprietary binary data.

The inspected `dyld_shared_cache_rosetta` identifies itself as a PPC cache (`dyld_v1     ppc`) and its map contains 183 PPC system images. Because Lion removed PPC slices from many of those frameworks, the runtime installer installs this isolated Rosetta cache while leaving Lion's native i386/x86_64 caches untouched. This remains an experimental compatibility boundary: preserve exact loader/crash diagnostics before copying any additional Snow Leopard system files.

## What to provide for debugging

Do not upload the proprietary payload to a public GitHub repository. If a test fails, the useful diagnostic material is:

1. output of `scripts/diagnose-on-lion.sh`;
2. `ROSETTA_PAYLOAD_MANIFEST.txt` and `ROSETTA_PACKAGE_FILES.txt` (paths/hashes/sizes, not binary contents);
3. `file` and `otool -L` output for the failing PowerPC executable;
4. the exact console/Terminal error and any `translate_*.crash` report.
