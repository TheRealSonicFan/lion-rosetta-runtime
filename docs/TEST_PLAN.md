# Test plan

Use a staged progression so a failure identifies the layer that is still incompatible.

1. **Payload validation on 10.6.8**
   - `translate` exists.
   - collector succeeds and emits a manifest/checksum.

2. **Lion runtime staging**
   - install the OAH directory and isolated `dyld_shared_cache_rosetta`.
   - verify Lion's i386/x86_64 dyld caches were not replaced.
   - run `diagnose-on-lion.sh` before kernel replacement.

3. **Kernel staging**
   - patch a copy of `/mach_kernel` with `lion-rosetta-xnu`.
   - verify that the old `RosettaNonGrata` signature is absent and `translate` is present.

4. **Boot-cache update and reboot**
   - use the kernel installer, which backs up the current kernel and kernelcache.
   - after reboot, confirm `sysctl kern.exec.archhandler.powerpc` reports `/usr/libexec/oah/translate`.

5. **Minimal 32-bit PPC Mach-O**
   - build the included smoke test on Snow Leopard with an era compiler that supports `-arch ppc`.
   - run it on Lion using `run-ppc-smoketest.sh`.

6. **Dynamic-library test**
   - if the trivial executable works, test a PPC binary that links ordinary system libraries.
   - record any dyld error exactly before changing caches or frameworks.

7. **GUI application**
   - only after command-line translation is confirmed should Carbon/Cocoa applications be tested.

8. **Compatibility expansion**
   - add only the specific shim/framework/cache behavior demonstrated missing by the prior step. Avoid copying Snow Leopard `/System/Library` wholesale into Lion.
