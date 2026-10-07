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

The private LaunchServices compatibility experiment has cleared Lion's PPC admission gate. Three independent Process Manager identity routes remain Snow Leopard-positive but self-SIGABRT on Lion before returning.

The prerequisite failure is now localized below LaunchServices to the launchd/bootstrap protocol used by the restored Snow Leopard PPC libSystem before CarbonCore can establish a coreservicesd client session.

The guarded CarbonCore stage discriminator first showed that Lion returns a zero `LaunchApplicationServices` service port, a zero CarbonCore server-checkin port, and process options `0x00000002`.

The exact PPC bootstrap discriminator then showed that the process has a valid bootstrap port but Lion returns `MIG_BAD_ARGUMENTS (-304)` for the Snow Leopard PPC `bootstrap_look_up2("com.apple.CoreServices.coreservicesd", target_pid=0, flags=0x8)` request.

The corrected binary audit established the exact schema mismatch:

- Snow Leopard PPC request: ID `0x194`, send `0xac`, receive `0x6c`, reply ID `0x1f8`, target PID at `0xa0`, flags at `0xa4`.
- Lion request: the same IDs/receive size, but a 16-byte instance UUID begins at `0xa4`, flags move to `0xb4`, and the send size becomes `0xbc`.

The guarded standalone protocol-adapter proof has now passed. The validated PPC subject constructed exactly the Lion UUID-expanded request, `mach_msg` returned success, and Lion returned the expected complex reply with descriptor count 1 and a nonzero coreservicesd service port. No crash occurred and all protected hashes remained unchanged.

Therefore the bootstrap wire-format defect itself is experimentally closed: supplying the missing 16-byte Lion instance field is sufficient for a translated PPC task to resolve coreservicesd.

The next question is integration, not another protocol guess. The authoritative next step is `docs/process-manager-bootstrap-integration-experiment.md`.

That experiment uses a private PPC `__DATA,__interpose` dylib loaded only into the dedicated test process. The replacement intercepts only the exact coreservicesd `bootstrap_look_up2` call with target PID 0 and flags `0x8`; Lion mode permits one adapted request only. All non-target calls pass through to the original Snow Leopard PPC implementation. The corrected service port is then returned to unmodified PPC CarbonCore, which continues its own normal `ServerCheckin -> FindService` path.

The same stage executable is used to read CarbonCore's resulting server-checkin port and requested service port. Possible outcomes distinguish live `ServerCheckin` failure, later `FindService` failure, or complete CoreServices service acquisition.

Do not call `ServerCheckin` or `FindService` directly, do not use `DYLD_FORCE_FLAT_NAMESPACE`, do not install the interposer system-wide, do not patch libSystem/liblaunch/launchd/CarbonCore, do not call Security or Process Manager, and do not change XNU. No additional XNU change is indicated.

The first Snow Leopard integration control exposed a harness-only pass-through resolver defect before any Lion run: the interposer successfully loaded and intercepted the exact call, but `dlsym(RTLD_NEXT, "bootstrap_look_up2")` did not yield a usable pre-interposed address, causing `PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE` and control exit status 20. The corrected interposer now obtains the original function address directly from its own `__interpose` tuple's `replacee` field, which is the exact address dyld used when installing the replacement. Rebuild Phase B and rerun Snow Leopard Phase C; do not proceed to Lion until the revised control passes.

The second submitted Snow Leopard integration control was still built from the pre-fix interposer: its SHA-256 remained `7c2e202c4fc80a33954902ccf59d66c11859e38ce59632f3184a9c71875e225b`, its build report still imported `_dlsym`, and the runtime log again emitted `PM_BOOTSTRAP_COMPAT_ORIGINAL_UNAVAILABLE`. This does not test the corrected `interpose_replacee` resolver. The integration builder/runners now enforce build identity `interpose-replacee-v2`, reject `_dlsym`, and record the runtime Git HEAD. Repeat Phase A before Phase B/C; Lion remains blocked until the revised Snow Leopard control passes.

The third Snow Leopard integration submission reached the corrected tuple-based resolver build, but the preflight rejected it before execution because the build-ID check searched the binary for a runtime-formatted concatenation that did not exist as one literal string. The submitted interposer had the new SHA-256 `0d4a34b0df4e8bab07645a434c5f35f81bb788d7c18bbb9b2d8130df139ccb15`, no `_dlsym` import, and `compat_build_id=interpose-replacee-v2`; therefore this was a provenance-gate false negative, not a resolver failure. Build identity is now `interpose-replacee-v3` and is embedded as one compile-time literal; builder and runners validate that literal, record the interposer source SHA-256, and handle non-git checkouts explicitly. Repeat Phase A/B/C and keep Lion blocked until the Snow Leopard control actually executes and passes.
