# lion-rosetta-runtime

Local extraction, validation, installation, and diagnostics for the closed-source Rosetta 1 runtime from a Mac OS X 10.6.8 Snow Leopard system.

**This repository intentionally contains no Apple proprietary binaries.** The scripts collect them from your own Snow Leopard installation into a local tarball ignored by Git.

Use this together with `lion-rosetta-xnu`. Its phase-2 source patch restores both Lion's PowerPC architecture-handler path and the Snow Leopard-compatible translated 32-bit commpage ABI required by Rosetta.

## Verified 10.6.8 payload

A payload collected from Mac OS X 10.6.8 build 10K549 was inspected while developing these scripts. It contains `translate`, `RosettaNonGrata`, the complete `Shims` tree, `RosettaVersion.plist`, Rosetta receipts, the Rosetta dyld shared cache/map, and the ancillary report-messages preference. The inspected runtime does **not** contain a `/usr/libexec/oah/translated` executable.

The translator binary contains an absolute reference to `/System/Library/OAH/nbb/`, but a direct audit of the validating 10.6.8 build 10K549 machine found `/System/Library/OAH` absent. The collector still preserves that tree if it exists on another source Mac.

The currently validated private payload and cache fingerprints are documented in `docs/VALIDATED_PAYLOAD.md`. No Apple binary data is committed there.

## 1. On the Snow Leopard 10.6.8 source system

For a read-only inventory first:

```sh
scripts/audit-snowleopard-source.sh
```

Then collect the private runtime:

```sh
sudo scripts/collect-snowleopard-rosetta.sh
```

By default it writes:

```
payload/rosetta-10.6.8-runtime.tar.gz
payload/rosetta-10.6.8-runtime.tar.gz.sha256
```

The archive preserves original paths beneath a private staging root. It includes `/usr/libexec/oah` and, when present, Rosetta metadata/receipts, `/System/Library/OAH`, the report-messages preference, and the Snow Leopard Rosetta dyld cache. It does **not** copy Snow Leopard's general `/System/Library` or `/usr/lib` contents. The collector verifies critical source/staged hashes and records the Rosetta cache size/mtime so a cache rebuild between audits is detectable.

## 2. Transfer the local payload to Lion

Copy the tarball to the Lion Mac by your preferred private method. Do not commit it to GitHub.

Inspect it first:

```sh
scripts/inspect-payload.sh payload/rosetta-10.6.8-runtime.tar.gz
```

The inspector verifies every file listed in `ROSETTA_PAYLOAD_MANIFEST.txt` before reporting the payload as valid.

## 3. Install on Lion

Install the OAH runtime:

```sh
sudo scripts/install-on-lion.sh payload/rosetta-10.6.8-runtime.tar.gz
```

The installer copies the OAH runtime and the Snow Leopard **Rosetta-only PPC dyld cache**. The currently validated cache identifies itself as `dyld_v1     ppc` and its map contains 180 unique PPC system images. It does **not** replace Lion's native `dyld_shared_cache_i386` or `dyld_shared_cache_x86_64`.

After installing the patched kernel from the companion repository and rebooting, run:

```sh
scripts/diagnose-on-lion.sh
```

Before executing another PowerPC process with the phase-2 kernel, run the native i386 translated-commpage probe. Build it on Snow Leopard if the Lion system has no Developer Tools:

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
scripts/build-lion-commpage-probe-on-snowleopard.sh ./lion-commpage-probe
```

Copy it to Lion and run:

```sh
scripts/run-lion-commpage-probe.sh ./lion-commpage-probe
```

Only after the probe reports `RESULT: PASS` should you rerun the disposable 32-bit PPC smoke test. To capture a shareable report around a PPC attempt:

```sh
scripts/collect-lion-test-report.sh ./lion-rosetta-test-report.txt /path/to/ppc-smoketest
```

The report script records candidate Rosetta crash paths and embeds the newest relevant crash report when one exists. It does not rerun the PPC executable unless `--execute` is supplied as its third argument.

## Why the test is staged

Historical Lion experiments show that copying `translate` alone can reach the translator and then crash inside it. Lion also removed PowerPC slices from many system frameworks. This project therefore treats kernel dispatch, translator startup, dyld/shared-region behavior, and higher-level framework compatibility as separate layers and records evidence before broad system-file replacement.

## Payload policy

The `.gitignore` is intentionally broad. It excludes the entire `payload/` directory and common Rosetta binary/cache names to reduce the chance of accidentally publishing Apple's proprietary components.

See `docs/CLOSED_SOURCE_COMPONENTS.md`, `docs/VALIDATED_PAYLOAD.md`, and `docs/TEST_PLAN.md`.
