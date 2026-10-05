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

The phase-2 commpage probe has now been validated on Lion 10.7.5: it reports the expected 19-page mapping, native commpage version 12, Rosetta compatibility version 11, readable/populated data at `0xffff8020`, correct PPC-view constants, signature data, and representative branch-assist entries, ending with `RESULT: PASS`.

Only after the probe reports `RESULT: PASS` should you proceed through the staged runtime tests. The syscall-295 compatibility experiment, guarded direct Rosetta control, normal PowerPC exec control, and command-line CoreFoundation experiment have passed. The first Carbon GUI control passed on Snow Leopard but aborts on Lion before a window marker. Postmortem analysis now confirms that the translated guest requests syscall 37 `kill(self, SIGABRT, 1)` and the host syscall succeeds, so no new XNU syscall fix is indicated. The milestone experiment localized the shell-launched Carbon failure to `GetCurrentProcess`. A subsequent registered `.app` control revealed an earlier Lion LaunchServices boundary: the identical PPC bundle is rejected with `-10665` (`kLSNoRosettaEnvironmentErr`) before execution, while the Snow Leopard LaunchServices control passes. The LaunchServices Rosetta-environment audit is now complete. It shows that Lion's LaunchServices lacks Snow Leopard's explicit Rosetta/OAH logic and marks the registered PPC app `unsupported-format`; Lion also lacks the Snow Leopard Rosetta receipts, but that difference is not yet proven causal. The LaunchServices policy hypothesis has now been confirmed experimentally. A one-byte change in a private i386 LaunchServices copy, after verified private-framework loading, clears Lion's `-10665` PPC application gate and allows LaunchServices to spawn the app. Process Manager localization has since advanced through three Snow Leopard-positive controls: `GetCurrentProcess`, pseudo-PSN `GetProcessPID`, and PID-first `GetProcessForPID`. All three identity routes self-SIGABRT on Lion before returning. The first HIServices differential audit is now complete: the validated Rosetta cache/map is identical on both systems, the Rosetta ApplicationServices/Interposers shims match exactly, and Snow Leopard's PPC HIServices routes all three identity APIs through the shared lazy `__RegisterApplication` path. The corrected version-2 `docs/process-manager-registerapplication-callsite-audit.md` and the follow-on registration-protocol audit have now passed on both systems. The protocol audit maps the exact abort-control operand to `LSDONOTABORTIFNOASN` and proves that value `0` disables only the later HIServices no-ASN abort. It also shows that Snow Leopard PPC and Lion i386 `_LSDoRegisterApplication` use the same registration message ID `0x4652` and the same 32-bit `0x44` send / `0x48` receive sizes, so an immediate 32-bit wire-schema mismatch is not established. An earlier LaunchServices process-dispatch abort remains possible. The current step is therefore the single process-local discriminator in `docs/process-manager-noasn-discriminator-experiment.md`. Do not install the private LaunchServices patch system-wide, edit the LaunchServices database, modify HIServices, or change XNU.

To capture a shareable report around a PPC attempt:

```sh
scripts/collect-lion-test-report.sh ./lion-rosetta-test-report.txt /path/to/ppc-smoketest
```

The report script records candidate Rosetta crash paths and embeds the newest relevant crash report when one exists. It does not rerun the PPC executable unless `--execute` is supplied as its third argument.

## Why the test is staged

Historical Lion experiments show that copying `translate` alone can reach the translator and then crash inside it. Lion also removed PowerPC slices from many system frameworks. This project therefore treats kernel dispatch, translator startup, dyld/shared-region behavior, and higher-level framework compatibility as separate layers and records evidence before broad system-file replacement.

## Payload policy

The `.gitignore` is intentionally broad. It excludes the entire `payload/` directory and common Rosetta binary/cache names to reduce the chance of accidentally publishing Apple's proprietary components.

See `docs/CLOSED_SOURCE_COMPONENTS.md`, `docs/VALIDATED_PAYLOAD.md`, `docs/PPC_DYLD_GAP.md`, `docs/rosetta-shared-cache-experiment.md`, `docs/postmortem-collector-experiment.md`, `docs/lion-normal-ppc-exec-experiment.md`, `docs/ppc-corefoundation-experiment.md`, `docs/ppc-carbon-gui-experiment.md`, `docs/process-manager-hiservices-audit.md`, `docs/process-manager-registerapplication-callsite-audit.md`, `docs/process-manager-launchservices-registration-protocol-audit.md`, `docs/process-manager-noasn-discriminator-experiment.md`, `docs/process-manager-process-dispatch-audit.md`, and `docs/TEST_PLAN.md`.


The initial `NOT_PATCHABLE` result from the private LaunchServices experiment was a patcher-signature defect, not a system-baseline mismatch: the full LaunchServices and i386-slice hashes matched the validated Lion 10.7.5 values. The corrected patcher now targets the audited i386 instruction by Mach-O virtual address and verifies its exact bytes before modifying one byte in a private copy. Continue with `docs/private-launchservices-ppc-compat-experiment.md` after pulling current `main`.


The Process Manager GetProcessForPID-first experiment passed on Snow Leopard and failed on Lion before returning, matching the earlier `GetCurrentProcess` and pseudo-PSN `GetProcessPID` abort family. Static localization now leaves two concrete candidates: the earlier LaunchServices process-dispatch setup abort and the later HIServices no-ASN/PSN abort. The registration-protocol audit has resolved the exact control as `LSDONOTABORTIFNOASN=0` and found that the Snow Leopard PPC client and Lion i386 client use the same 32-bit registration request sizes. The next controlled step is `docs/process-manager-noasn-discriminator-experiment.md`: one Snow Leopard positive control and one guarded Lion launch, with the override supplied only in the test app's `LSEnvironment`, followed by an immediate exit after `GetProcessForPID` status/PSN logging.


The process-local no-ASN discriminator is now complete. The exact PPC subject sees `LSDONOTABORTIFNOASN=0` on both systems; Snow Leopard returns `noErr` with a nonzero PSN, while Lion still self-SIGABRTs before `GetProcessForPID` returns. This rules out the later HIServices no-ASN abort as the observed fatal branch. The latest crash again matches Rosetta's guest-requested self-abort wrapper, syscall-295 remains validated, and protected hashes are unchanged. The next controlled step is entirely read-only: `docs/process-manager-process-dispatch-audit.md` compares LaunchServices process-dispatch initialization, session/service setup, and the complete InitializeProcessesServices family before any compatibility code is attempted. Do not rerun the PPC app or change XNU.
