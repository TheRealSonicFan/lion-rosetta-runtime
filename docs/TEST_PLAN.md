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
   - run `diagnose-on-lion.sh` before kernel replacement.

3. **Kernel staging**
   - patch a copy of `/mach_kernel` with `lion-rosetta-xnu`.
   - verify that the old `RosettaNonGrata` handler signature is absent and the `translate` handler string is present.

4. **Boot-cache update and reboot**
   - use the kernel installer, which backs up the current kernel and kernelcache.
   - after reboot, confirm `sysctl kern.exec.archhandler.powerpc` reports `/usr/libexec/oah/translate`.

5. **Minimal 32-bit PPC Mach-O**
   - build the included smoke test on Snow Leopard with `build-ppc-smoketest-on-snowleopard.sh`.
   - run it on Lion with `run-ppc-smoketest.sh`.
   - capture `collect-lion-test-report.sh ./lion-rosetta-test-report.txt ./ppc-smoketest`.

6. **Dynamic-library test**
   - if the smoke test works, test a second PPC binary that links ordinary system libraries.
   - preserve any dyld error verbatim before modifying framework/cache state.

7. **GUI application**
   - only after command-line translation is confirmed should Carbon/Cocoa applications be tested.

8. **Compatibility expansion**
   - add only the specific shim/framework/cache behavior demonstrated missing by the prior step.
   - do not copy Snow Leopard `/System/Library` wholesale into Lion.
