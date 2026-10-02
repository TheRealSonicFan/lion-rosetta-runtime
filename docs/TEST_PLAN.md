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
   - before copying any additional Snow Leopard libraries, rerun the guarded direct test with `ROSETTA_CACHE_BYPASS_VALIDATION=1`; this validates the exact installed Rosetta cache/map and sets `DYLD_SHARED_CACHE_DONT_VALIDATE=1` only for the test process.
   - follow `docs/rosetta-shared-cache-experiment.md` for the exact preflight, command, output files, stop conditions, and result interpretation.
   - do not add `DYLD_SHARED_REGION=private`, rebuild caches, or modify Lion's `/usr/lib` in that experiment; isolate the cache-validation question first.
   - after a successful direct-translator private-dyld/cache test, exercise normal PPC exec only when the running kernel includes the PowerPC subject-path correction documented in `lion-rosetta-xnu`.

7. **Dynamic-library expansion**
   - only if the validated Rosetta cache still cannot satisfy the guest dependency should individual Snow Leopard PPC libraries be collected for a new private-path experiment.
   - if the smoke test works, test additional PPC binaries that exercise ordinary system libraries.
   - preserve any dyld or translator error verbatim before modifying framework/cache state.

8. **GUI application**
   - only after command-line translation is confirmed should Carbon/Cocoa applications be tested.

9. **Compatibility expansion**
   - add only the specific shim/framework/cache behavior demonstrated missing by the prior step.
   - do not copy Snow Leopard `/System/Library` wholesale into Lion.
