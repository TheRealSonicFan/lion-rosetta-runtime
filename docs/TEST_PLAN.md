# Test plan

Use a staged progression so a failure identifies the layer that is still incompatible.

1. **Payload validation on 10.6.8**
   - `translate` exists.
   - collector succeeds and emits a manifest/checksum.
   - `inspect-payload.sh` verifies every manifest entry.
   - compare the cache identity with `docs/VALIDATED_PAYLOAD.md` when reproducing the current test baseline.

2. **Lion runtime staging**
   - install the OAH directory and isolated `dyld_shared_cache_rosetta`.
   - verify Lion's i386/x86_64 dyld caches were not replaced.
   - run `diagnose-on-lion.sh`.

3. **Phase-2 XNU source validation/build**
   - apply `lion-rosetta-xnu/patches/xnu-1699.32.7-rosetta-commpage.patch` to a clean `xnu-1699.32.7` tree.
   - run `lion-rosetta-xnu/tools/validate_rosetta_source.py` before compiling.
   - compile the patched kernel with the historical Apple build environment.
   - install it using the existing backup/rollback discipline and rebuild the kernelcache.

4. **Reboot and architecture-handler check**
   - confirm `sysctl kern.exec.archhandler.powerpc` reports `/usr/libexec/oah/translate`.

5. **Native i386 commpage verification**
   - build `lion-commpage-probe` on Snow Leopard with `build-lion-commpage-probe-on-snowleopard.sh` if necessary.
   - run it on Lion with `run-lion-commpage-probe.sh`.
   - require `RESULT: PASS` before invoking a PPC executable.
   - this specifically verifies that `0xffff8020` and representative Rosetta branch/signature data are mapped and populated.
   - validated result on the current Lion 10.7.5 phase-2 kernel: PASS; native version 12, Rosetta version 11, PPC capabilities `0x00020145`, cache line 32, expected PPC-view constants, signature data, and low/high branch-assist representatives.

6. **Minimal 32-bit PPC Mach-O**
   - reuse the already validated `ppc-smoketest` binary when possible.
   - run it on Lion with `run-ppc-smoketest.sh`.
   - capture `collect-lion-test-report.sh ./lion-rosetta-test-report.txt ./ppc-smoketest` after the attempt.
   - if Rosetta fails while opening the guest `/usr/lib/dyld`, follow `docs/PPC_DYLD_GAP.md` before making another kernel change.
   - the current Lion direct-launch postmortem shows exactly this condition: Rosetta requests a PPC dyld, Lion provides only x86_64/i386, and the translator misparses the fallback x86_64 slice.
   - use a disposable PPC smoke binary with a private alternate `LC_LOAD_DYLINKER` for the controlled test; never replace Lion's native `/usr/lib/dyld`.
   - the first Lion private-dyld run has now passed the former parser boundary: guest dyld reaches library resolution, rejects the Snow Leopard Rosetta cache because Lion's on-disk libSystem does not match it, then reports that Lion's `/usr/lib/libgcc_s.1.dylib` has no PPC slice.
   - the corrected cache-bypass run has now completed: the stale-cache rejection disappeared, the PPC subject was reported as loaded, and `translate` then terminated with `EXC_CRASH (SIGSYS)`, status 140, `EIP=0xb815ac07`, and `EAX=0x4e`.
   - source comparison points to removed syscall 295 (`shared_region_map_np`) as the leading boundary: Snow Leopard dyld calls it directly, Snow Leopard XNU implements it, and Lion routes 295 to `nosys`.
   - the read-only postmortem collector has now confirmed the legacy shared-region call: runtime code executes `int $0x80`, returns `ENOSYS` with carry set, and the caller passes syscall 295 with `fd=4`, `mappingCount=3`, and mappings spanning exactly the validated Rosetta shared-cache file.
   - do not collect or install a private `libgcc_s.1.dylib` yet. The confirmed syscall-295 boundary precedes that unresolved library question under the active cache-validation bypass.
   - the syscall-295 compatibility experiment has now passed completely: both kernel architectures built, the installed kernel hash matched the candidate, the commpage regression probe passed, the native syscall-295 probe returned EBADF with no SIGSYS, and the guarded direct Rosetta private-dyld/cache-bypass control printed the PPC smoke-test message and exited 0.
   - the syscall-295 SIGSYS/ENOSYS boundary is therefore closed. Do not add guest libraries or make another XNU change before testing the next layer.
   - the normal PPC exec activation experiment has now passed: the validated private-dyld subject launched through the kernel architecture handler, loaded the Rosetta runtime libraries, printed the smoke-test marker, exited 0, and generated no diagnostic.
   - the kernel activation/subject-path layer is therefore closed for the minimal command-line subject.
   - the PPC CoreFoundation experiment has now passed on both Snow Leopard and Lion. The exact PPC subject loaded CoreFoundation plus libauto, libicucore, libobjc, libz, libstdc++, libSystem, and libmathCommon, validated CFString/CFArray behavior, exited 0, and generated no diagnostic.
   - command-line CoreFoundation compatibility is therefore closed for the controlled environment.
   - the first Carbon GUI experiment passed on Snow Leopard but failed on Lion before either program marker or window creation: the exact PPC subject loaded the Carbon/ApplicationServices dependency graph and then terminated with SIGABRT/status 134, producing `/cores/core.1311`.
   - the preserved-core postmortem has now confirmed that Rosetta executes syscall 37 `kill(pid, signum, posix)` with PID 1311, SIGABRT, and posix flag 1; the host syscall returns success. The abort is therefore guest-requested rather than another missing Lion syscall ABI.
   - the milestone experiment has now localized the guest abort precisely: Lion reaches `M00_MAIN_ENTER` and `M01_BEFORE_GetCurrentProcess`, then self-SIGABRTs before `M02_AFTER_GetCurrentProcess`. Snow Leopard reaches all milestones through `M27_SUCCESS` with the exact control binary.
   - this rules out pre-main framework initialization and makes `GetCurrentProcess`/Carbon Process Manager initialization the immediate observed boundary.
   - the LaunchServices bundle control passed on Snow Leopard, but Lion refuses the identical PPC app before execution with `LSOpenURLsWithRole` error `-10665` (`kLSNoRosettaEnvironmentErr`). No milestone file is expected because `main()` is never entered.
   - this is now an earlier LaunchServices Rosetta-availability gate, so the experiment cannot yet test whether registration changes `GetCurrentProcess`.
   - the Snow Leopard/Lion LaunchServices environment audit is complete. Runtime metadata matches, but Snow Leopard has Rosetta receipts and explicit Rosetta/OAH LaunchServices logic while Lion does not; Lion also records the same PPC app as `unsupported-format`.
   - the receipts difference is not yet proven causal. Do not install Snow Leopard receipts on Lion.
   - the first static audit confirms a real Snow Leopard `-10665` path through `_LSAppMeetsRosettaRequirement` and a structurally different Lion `-10665` path, but the analyzer's symbol spelling and broad text matcher prevented precise Lion callsite attribution.
   - the corrected callsite audit is complete: Snow Leopard's `_LSLaunch` uses `_LSAppMeetsRosettaRequirement`, while Lion's `_LSLaunch` calls `_LSBundleDataGetUnsupportedFormatFlag` and returns `-10665` from that persisted classification.
   - the unsupported-format provenance audit is complete. `_LSBundleDataGetUnsupportedFormatFlag` computes the flag from bundle architecture bits and current CPU policy; no dedicated unsupported-format setter was identified.
   - Snow Leopard contains an Intel-host fallback that accepts the PPC architecture bit for Rosetta, while Lion's x86_64-host path tests only native Intel bits and returns unsupported-format for the PPC-only bundle.
   - the private one-byte i386 LaunchServices hypothesis test has now cleared the `-10665` launch gate: the verified private framework was loaded, `open` returned 0, and the PPC app was spawned by LaunchServices. The app then reproduced the independent `GetCurrentProcess` self-SIGABRT boundary.
   - do not broaden or install the LaunchServices patch. Follow `docs/process-manager-alternate-path-experiment.md` to test documented alternate Process Manager identity routes while keeping the private LaunchServices proof setup unchanged.
   - the initial Phase B `NOT_PATCHABLE` result was a patcher-signature bug: the system and i386 hashes matched the validated baseline. The corrected patcher now maps the audited Mach-O virtual address through `LC_SEGMENT` and verifies the exact target instruction bytes before changing one byte in a private copy.

7. **Dynamic-library expansion**
   - only if the validated Rosetta cache still cannot satisfy the guest dependency should individual Snow Leopard PPC libraries be collected for a new private-path experiment.
   - if the smoke test works, test additional PPC binaries that exercise ordinary system libraries.
   - preserve any dyld or translator error verbatim before modifying framework/cache state.

8. **GUI application**
   - only after command-line translation is confirmed should Carbon/Cocoa applications be tested.

9. **Compatibility expansion**
   - add only the specific shim/framework/cache behavior demonstrated missing by the prior step.
   - do not copy Snow Leopard `/System/Library` wholesale into Lion.


## Current Process Manager boundary

The private LaunchServices compatibility experiment has cleared Lion's PPC admission gate. Three independent Process Manager identity routes remain Snow Leopard-positive but self-SIGABRT on Lion before returning:

- `GetCurrentProcess()`;
- `GetProcessPID({0,kCurrentProcess},...)`;
- `GetProcessForPID(getpid(), &psn)`.

The HIServices provenance audit, corrected RegisterApplication audit, registration-protocol audit, no-ASN discriminator, LaunchServices process-dispatch audit, and system-service transport audit are complete.

The process-dispatch audit found no obvious 32-bit InitializeProcessesServices wire mismatch. The system-service transport audit then identified the next material divergence one layer lower.

Snow Leopard PPC `SessionGetInfo` still uses the legacy SecurityServer client path through `ModuleNexus<AuthClient>` and `SecurityServer::ClientSession::getSessionInfo`. Lion i386 `SessionGetInfo` instead uses `CommonCriteria::AuditInfo::get` and reads the audit-session state locally.

This matters because translated PPC on Lion uses the restored Snow Leopard PPC Security image from the validated Rosetta shared cache. A legacy Snow Leopard Security session client is therefore being exercised against Lion's native host security/session environment.

CarbonCore's top-level `scCreateSystemServiceVersion` remains semantically similar across the audited PPC/i386 paths and still reaches `SCSession::findOrCreateService`, but that cross-version service acquisition also has not yet been behaviorally tested.

The authoritative next step is the guarded command-line PPC preflight in `docs/process-manager-predispatch-preflight-experiment.md`. It mirrors the real setup order without calling Process Manager:

1. `scCreateSystemServiceVersion("LaunchApplicationServices", 0x00010000, NULL)`;
2. require a nonzero service port;
3. `SessionGetInfo(callerSecuritySession,...)`;
4. require `noErr` and a nonzero session ID;
5. exit.

Run the Snow Leopard positive control first, repeat the native Lion commpage/syscall-295 safety gates, then run the Lion PPC preflight exactly once.

Do not run another Process Manager GUI test, call `_LSDoInitializeProcessesServices` directly, use `SCDontUseServer`, patch CarbonCore/Security/LaunchServices, restart CoreServices/security services, use live instrumentation, or change XNU before that result is reviewed. No additional XNU change is indicated.
