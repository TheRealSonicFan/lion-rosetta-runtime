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

See `docs/CLOSED_SOURCE_COMPONENTS.md`, `docs/VALIDATED_PAYLOAD.md`, `docs/PPC_DYLD_GAP.md`, `docs/rosetta-shared-cache-experiment.md`, `docs/postmortem-collector-experiment.md`, `docs/lion-normal-ppc-exec-experiment.md`, `docs/ppc-corefoundation-experiment.md`, `docs/ppc-carbon-gui-experiment.md`, `docs/process-manager-hiservices-audit.md`, `docs/process-manager-registerapplication-callsite-audit.md`, `docs/process-manager-launchservices-registration-protocol-audit.md`, `docs/process-manager-noasn-discriminator-experiment.md`, `docs/process-manager-process-dispatch-audit.md`, `docs/process-manager-systemservice-transport-audit.md`, `docs/process-manager-predispatch-preflight-experiment.md`, `docs/process-manager-systemservice-client-internals-audit.md`, `docs/process-manager-systemservice-rpc-protocol-audit.md`, `docs/process-manager-systemservice-stage-discriminator-experiment.md`, `docs/process-manager-security-session-protocol-audit.md`, `docs/process-manager-security-session-rpc-discriminator-experiment.md`, `docs/process-manager-securityserver-bootstrap-protocol-adapter-experiment.md`, `docs/process-manager-security-session-bootstrap-compat-integration-experiment.md`, `docs/process-manager-security-session-auditinfo-oracle-experiment.md`, and `docs/TEST_PLAN.md`.


The initial `NOT_PATCHABLE` result from the private LaunchServices experiment was a patcher-signature defect, not a system-baseline mismatch: the full LaunchServices and i386-slice hashes matched the validated Lion 10.7.5 values. The corrected patcher now targets the audited i386 instruction by Mach-O virtual address and verifies its exact bytes before modifying one byte in a private copy. Continue with `docs/private-launchservices-ppc-compat-experiment.md` after pulling current `main`.


The Process Manager GetProcessForPID-first experiment passed on Snow Leopard and failed on Lion before returning, matching the earlier `GetCurrentProcess` and pseudo-PSN `GetProcessPID` abort family. Static localization now leaves two concrete candidates: the earlier LaunchServices process-dispatch setup abort and the later HIServices no-ASN/PSN abort. The registration-protocol audit has resolved the exact control as `LSDONOTABORTIFNOASN=0` and found that the Snow Leopard PPC client and Lion i386 client use the same 32-bit registration request sizes. The next controlled step is `docs/process-manager-noasn-discriminator-experiment.md`: one Snow Leopard positive control and one guarded Lion launch, with the override supplied only in the test app's `LSEnvironment`, followed by an immediate exit after `GetProcessForPID` status/PSN logging.


The process-local no-ASN discriminator is now complete. The exact PPC subject sees `LSDONOTABORTIFNOASN=0` on both systems; Snow Leopard returns `noErr` with a nonzero PSN, while Lion still self-SIGABRTs before `GetProcessForPID` returns. This rules out the later HIServices no-ASN abort as the observed fatal branch. The latest crash again matches Rosetta's guest-requested self-abort wrapper, syscall-295 remains validated, and protected hashes are unchanged. The next controlled step is entirely read-only: `docs/process-manager-process-dispatch-audit.md` compares LaunchServices process-dispatch initialization, session/service setup, and the complete InitializeProcessesServices family before any compatibility code is attempted. Do not rerun the PPC app or change XNU.


The Process Manager process-dispatch audit is now complete on Snow Leopard and Lion. The Snow Leopard PPC and Lion i386 LaunchServices clients use the same InitializeProcessesServices message ID and 32-bit request/reply sizing, and their high-level setup sequence is structurally aligned through session discovery, system-service acquisition, process-services initialization, Mach-port creation, and dispatch-table installation. Both systems expose the same coreservicesd launchd Mach service. No obvious LaunchServices-level wire mismatch was found. The remaining static gap is the imported CarbonCore system-service transport and Security session implementation below LaunchServices. The next controlled step is the read-only `docs/process-manager-systemservice-transport-audit.md`; do not rerun the PPC application, use `SCDontUseServer`, or change XNU.


The Process Manager system-service transport audit is now complete. CarbonCore's top-level system-service API remains recognizable across Snow Leopard PPC and Lion i386, but Security changed materially: Snow Leopard PPC `SessionGetInfo` uses the legacy SecurityServer client path, while Lion i386 reads audit-session state through `CommonCriteria::AuditInfo`. Because translated PPC on Lion uses the restored Snow Leopard PPC Security image from the Rosetta cache, this is now a concrete cross-version boundary. The next controlled step is `docs/process-manager-predispatch-preflight-experiment.md`: a command-line PPC probe that acquires the `LaunchApplicationServices` system-service port, queries `SessionGetInfo`, and exits before Process Manager or LaunchServices process-services initialization.


The first Process Manager pre-dispatch Phase B build attempt exposed a harness-only linker error: Snow Leopard forbids direct client linkage to the CarbonCore subframework and requires the CoreServices umbrella. The current builder now links `-framework CoreServices -framework Security`, and the Snow Leopard/Lion validators expect the CoreServices umbrella load command while retaining CarbonCore/Security Rosetta-cache provenance checks. No PPC runtime behavior was exercised by the failed build; repeat Phase B after pulling current `main`.


The guarded Process Manager pre-dispatch probe has now localized the immediate Lion failure to CoreServices system-service acquisition. The exact PPC executable succeeds on Snow Leopard, but on Lion `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)` returns normally with a zero port before `SessionGetInfo` is reached. No crash occurs, syscall 295 remains validated, and protected hashes remain unchanged. The next step is the read-only `docs/process-manager-systemservice-client-internals-audit.md`, which compares CarbonCore's internal `SCSession::findOrCreateService` / `SCClientSession` machinery and coreservicesd check-in/service negotiation before any further live probe.


The CarbonCore client-internals audit is now complete. Snow Leopard PPC and Lion i386 share the same broad service-client architecture through bootstrap lookup, `ServerCheckin`, `SCSession::findOrCreateService`, and client `FindService`; the observed private object-layout changes do not by themselves prove an IPC mismatch. The current zero-port result is now narrowed to either CoreServices client check-in/session establishment or the subsequent `LaunchApplicationServices` service lookup. The next step is the read-only `docs/process-manager-systemservice-rpc-protocol-audit.md`, which expands the actual RPC stubs, message contracts, and Lion connection-state path before another PPC launch.


The CoreServices system-service RPC audit established matching `FindService` constants but its initial ServerCheckin compatibility interpretation was later corrected: Snow Leopard PPC sends a complex `0x28` request while Lion expects a simple `0x18` request and rejects the complex form. The later integration experiment confirms that this is the next active boundary after bootstrap adaptation.


The guarded CoreServices system-service stage discriminator is now complete. The exact PPC subject passes on Snow Leopard with nonzero service/check-in ports, but on Lion returns service port zero, server-checkin port zero, process options `0x00000002`, no diagnostic, and `RESULT: CHECKIN_SESSION_UNAVAILABLE`. The immediate failure is therefore before `FindService`: the guest PPC CarbonCore does not establish a usable coreservicesd client session. The next controlled step is `docs/process-manager-bootstrap-lookup-discriminator-experiment.md`, which performs one exact PPC `bootstrap_look_up2` for `com.apple.CoreServices.coreservicesd` using target PID 0 and the recovered 64-bit flags value `0x8`. It does not call `ServerCheckin` in the same run. No additional XNU change is indicated.


The guarded coreservicesd bootstrap discriminator is now complete. The exact PPC subject succeeds on Snow Leopard but on Lion reaches `bootstrap_look_up2` with a nonzero bootstrap port and the same service name/target/flags, then returns `kr=-304` (`MIG_BAD_ARGUMENTS`) with a zero service port and no crash. Public Apple launchd sources for 10.6.8 and 10.7.5 show a matching hidden protocol evolution: Lion adds an `instanceid : uuid_t` field to `vproc_mig_look_up2` beneath the unchanged five-argument `bootstrap_look_up2` API. The next step is the read-only `docs/process-manager-bootstrap-protocol-audit.md`, which confirms the exact shipped binary request layouts before any process-local adapter is designed. No additional XNU change is indicated.


The corrected bootstrap protocol audit now confirms the shipped-binary request mismatch behind Lion's `MIG_BAD_ARGUMENTS`. Snow Leopard PPC `vproc_mig_look_up2` sends a `0xac` request with target PID followed directly by 64-bit flags. Lion's stripped i386 MIG body, inferred at `0x7967` from `bootstrap_look_up3`, sends `0xbc` bytes and contains an additional 16-byte field between target PID and flags; request/reply IDs and receive size remain aligned. The `0x10` delta matches Lion's added `instanceid : uuid_t`. The next stage is the guarded `docs/process-manager-bootstrap-protocol-adapter-experiment.md`, which sends exactly one process-local Lion-format lookup request from PPC and stops before CoreServices `ServerCheckin`. No system component or XNU is patched.


The standalone PPC bootstrap protocol adapter proof is now a clean PASS. Lion accepts the binary-confirmed UUID-expanded `look_up2` request from the translated PPC task and returns a nonzero coreservicesd service port, proving the earlier `MIG_BAD_ARGUMENTS` was caused by Snow Leopard's legacy `0xac` request layout versus Lion's `0xbc` UUID-expanded layout. The next controlled stage is `docs/process-manager-bootstrap-integration-experiment.md`: a private process-local PPC `__DATA,__interpose` dylib adapts only CarbonCore's exact coreservicesd bootstrap call, then unmodified PPC CarbonCore continues through its own `ServerCheckin -> FindService` path. This will distinguish live ServerCheckin failure, later FindService failure, or complete system-service recovery. No system component or XNU is patched.


The first Snow Leopard bootstrap integration control exposed a harness-only resolver defect before any Lion run: the interposer loaded and triggered correctly, but its `RTLD_NEXT` lookup could not recover the pre-interposed `bootstrap_look_up2` address. The interposer now uses the `replacee` pointer already stored in its own `__DATA,__interpose` tuple, and the control explicitly verifies that resolution path. Rebuild the Phase B artifacts and rerun Phase C before continuing to Lion.


A second Snow Leopard integration-control submission was confirmed to be the same obsolete pre-fix interposer: it retained the old SHA-256 and `_dlsym` import and never exercised the corrected tuple-based resolver. Current build/control tooling now tags the corrected interposer as `interpose-replacee-v2`, records its runtime Git HEAD, and rejects stale binaries before execution. Phase A must be repeated before rebuilding and rerunning the Snow Leopard control; no Lion integration run is authorized until that control passes.


The third Snow Leopard bootstrap-integration submission confirmed that the corrected no-`dlsym` resolver was rebuilt, but a preflight-only marker check rejected it before launch because the desired runtime-formatted build ID was not stored as one binary string literal. The interposer is now tagged `interpose-replacee-v3` using an exact compile-time marker, and provenance records the source SHA-256 plus a non-git-checkout sentinel when Git metadata is unavailable. Rebuild after pulling current main and rerun the Snow Leopard control before any Lion integration run.


The bootstrap integration experiment has now reached the next compatibility boundary. The validated v3 process-local interposer successfully adapts CarbonCore's exact coreservicesd bootstrap lookup on Lion and returns a nonzero service port, but unmodified Snow Leopard PPC CarbonCore still ends with a zero server-checkin port and `RESULT: BOOTSTRAP_COMPAT_SERVERCHECKIN_FAILURE`. Re-reading the shipped stubs corrects an earlier static interpretation: Snow Leopard PPC `ServerCheckin` is a complex `0x28` request with one port descriptor, while Lion's native i386 client sends a simple `0x18` request and Lion's i386 `__XServerCheckin` rejects complex requests before dispatch. The next controlled stage is `docs/process-manager-servercheckin-protocol-adapter-experiment.md`, a standalone one-transaction proof of the native Lion simple ServerCheckin request after the already-proven adapted bootstrap lookup. No additional XNU change is indicated.


The standalone ServerCheckin protocol adapter is now a clean PASS. On Lion, the translated PPC subject first completed the already-proven UUID-expanded coreservicesd lookup, then sent Lion's native simple `0x18` ServerCheckin request and received the expected complex `0x34` reply with descriptor count 1, disposition `0x11`, a nonzero session port, and options `0x03000000`. The Snow Leopard control likewise passed with the legacy complex `0x28` request. No crash occurred, protected hashes were unchanged, and syscall 295 remained healthy. Both CoreServices request-shape mismatches are therefore independently proven. The next controlled stage is `docs/process-manager-coreservices-compat-integration-experiment.md`: one private PPC interposer combines only the proven bootstrap and ServerCheckin adaptations and then lets unmodified PPC CarbonCore continue through its existing `FindService("LaunchApplicationServices")` path. No additional XNU change is indicated.


The first Snow Leopard control for the dual CoreServices integration exposed a harness matcher defect, not a CoreServices regression. Both PPC artifacts and the two-tuple interposer loaded correctly, the bootstrap tuple passed through with a nonzero coreservicesd port, and unmodified Snow Leopard CarbonCore still completed with nonzero service/check-in ports and `STAGE_CONTROL_PASS`; the runner failed only because the private ServerCheckin exact-match marker was absent. The v1 filter had unnecessarily required the request's port descriptor to be numerically equal to a fresh `mach_task_self()` value from the interposer. The corrected `dual-bootstrap-servercheckin-v2` filter keeps the exact server port, request ID, header/argument sizes, descriptor count/disposition/type, reply port, timeout, and notify checks, requires only a nonzero descriptor port, and logs a full ServerCheckin candidate record before matching. Pull current main, rebuild Phase B, and repeat Phase C only; do not proceed to Lion until the v2 Snow Leopard control reports `RESULT: PASS`.


The rebuilt v2 Snow Leopard dual-integration control again proved that CarbonCore itself is healthy but exposed one remaining harness predicate error. The new candidate logger captured the real legacy ServerCheckin call with bits `0x80001513`, request ID `0x2710`, `mach_msg` send argument `0x28`, receive size `0x3c`, one nonzero port descriptor, disposition `0x13`, type `0x00`, matching reply/receive ports, and zero timeout/notify; only the in-buffer `msgh_size` word was `0x40`. Re-reading the recovered PPC MIG stub shows that CarbonCore never initializes that header word before calling `mach_msg`; the authoritative send size is the separate `0x28` argument. The corrected `dual-bootstrap-servercheckin-v3` matcher therefore logs `headerSizeObserved` but does not constrain it, while still explicitly setting `msgh_size=0x18` for the Lion adaptation. Pull current main, rebuild Phase B, and repeat Phase C only; no Lion run is authorized until v3 reports `RESULT: PASS`.


The corrected v3 dual CoreServices integration now passes completely on Lion. The process-local adapter returns a valid coreservicesd bootstrap port, converts CarbonCore's exact legacy ServerCheckin request to Lion's native simple form, receives a nonzero session port, and then lets unmodified PPC CarbonCore complete its own `FindService("LaunchApplicationServices")` path with a nonzero service port and zero process-option error state. No diagnostic was produced, protected hashes were unchanged, and syscall 295 remains healthy. This closes the CarbonCore system-service boundary and shows that no FindService adapter is needed. The next controlled stage is `docs/process-manager-predispatch-compat-integration-experiment.md`, which reuses the original pre-dispatch subject under the proven v3 CoreServices adapter and finally reaches the previously blocked Snow Leopard PPC `SessionGetInfo(callerSecuritySession,...)` call. No additional XNU change is indicated.


The Security bootstrap compatibility integration has now reached the next concrete boundary. After the proven Lion-format `com.apple.SecurityServer` lookup succeeds, untouched Snow Leopard PPC Security completes `verifyPrivileged2 (0x441)` and `setup (0x3e8)`, then sends binary-proven `getSessionInfo=0x428`. Lion returns a simple `0x24` MIG error reply; applying the shipped PPC stub's NDR byte-order conversion to the observed raw word `0xd1feffff` yields `0xfffffed1`, signed `-303` / `MIG_BAD_ID`. Thus the retired session RPC itself is now directly proven absent. Lion's native `SessionGetInfo(callerSecuritySession,...)` instead reads kernel-backed audit information via `getaudit_addr(..., 0x30)`. The next controlled stage is `docs/process-manager-security-session-auditinfo-oracle-experiment.md`, which validates that native mapping and tests translated-PPC direct `getaudit_addr` access before any SessionGetInfo compatibility shim is designed. No Security/securityd or XNU patch is justified yet.


The first Snow Leopard AuditInfo oracle control exposed a harness overconstraint rather than a platform failure. Both PPC and i386 subjects returned a successful legacy `SessionGetInfo`, and both raw `getaudit_addr` reads succeeded with the same session ID at word `0x24`; only the legacy public attribute bits (`0x8030`) differed from raw word `0x28` (PPC `0`, i386 `1`). The corrected oracle now uses a Snow-only `session-id-audit` mode that requires only the proven session-ID correspondence, while preserving strict ID+attribute equality for the native Lion `session-audit` oracle. Pull current main, rebuild Phase B, and rerun Phase C only; do not proceed to Lion until the corrected control reports `RESULT: PASS`.


The corrected Security AuditInfo oracle now passes completely. On Lion, native i386 `SessionGetInfo(callerSecuritySession,...)` returned status 0 and exactly matched the typed audit session ID/attribute values from `getaudit_addr(..., 0x30)`; translated PPC also called `getaudit_addr` successfully and returned the same audit session ID. The raw 32-bit word at offset `0x28` differs between i386 and PPC because `ai_flags` is a 64-bit field: the previous probe logged only the first word, which is the low half on little-endian i386 and the high half on big-endian PPC. The next controlled stage is `docs/process-manager-security-session-auditinfo-api-adapter-experiment.md`, a one-tuple process-local `SessionGetInfo` adapter for `callerSecuritySession` that uses typed `auditinfo_addr_t.ai_asid` / `ai_flags` and sends no SecurityServer RPC. No additional XNU change is indicated.
