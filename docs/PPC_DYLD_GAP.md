# PowerPC dyld compatibility gap on Lion

## Finding

Postmortem analysis of a non-debugged Lion `translate` core shows that Rosetta explicitly opens `/usr/lib/dyld` while constructing a Mach-O parser for CPU type `0x12` (PowerPC).

On the tested Lion 10.7.5 system, `/usr/lib/dyld` contains only x86_64 and i386 slices. The Snow Leopard 10.6.8 control system's `/usr/lib/dyld` contains x86_64, i386, and `ppc7400` slices. This is an exact match for the translator core: its dyld parser requests PowerPC CPU type `0x12` and subtype `0x0a`, and the Mac OS X 10.6 SDK defines `CPU_SUBTYPE_POWERPC_7400` as decimal 10 (`0x0a`).

The Snow Leopard translator's private parser does not safely reject that no requested PPC slice was found: its architecture-selection fallback chooses the first available slice. On Lion this is x86_64.

The parser then treats the selected x86_64 dyld as a 32-bit image. It advances by the 32-bit Mach-O header size (`0x1c`) instead of the 64-bit size (`0x20`), byte-swaps `LC_SEGMENT_64 == 0x19` into `0x19000000`, interprets that value as a load-command size, advances by `0x19000000`, and faults at the resulting unmapped address.

Therefore the observed direct-launch crash is a missing guest PPC dyld dependency, not evidence that another arbitrary Lion VM range needs to be mapped.

## Safety rule

Do **not** replace Lion's native `/usr/lib/dyld`. It is a critical native system component.

Any Snow Leopard dyld used for Rosetta investigation is proprietary runtime material. Keep it private and never commit it to this repository.

## Controlled test

First, on the Snow Leopard 10.6.8 source system, collect and validate the dyld privately:

```sh
git pull
./scripts/collect-snowleopard-ppc-dyld.sh
```

The collector is read-only with respect to `/usr/lib/dyld`. It accepts the observed `ppc7400` slice (preferred, because it exactly matches the translator's requested subtype) and a generic `ppc` slice as a fallback. It records `file`, `lipo`, the selected PPC Mach-O header, and SHA-256 evidence, then copies the original Snow Leopard dyld unchanged into the ignored `payload/` directory. It emits:

```
payload/snowleopard-10.6.8-dyld
payload/snowleopard-10.6.8-dyld.info.txt
payload/snowleopard-10.6.8-dyld.sha256
```

Keep all three artifacts private. On the current Snow Leopard control, the report should say `selected_ppc_arch=ppc7400` and `ppc_verify=PASS`, and the source/copy checksums must match.

### Validated Snow Leopard control artifact

The collected 10.6.8 control has now been independently rechecked from the private binary plus its audit/checksum sidecars:

- source system: Mac OS X 10.6.8 build `10K549`;
- full fat dyld size: `1054960` bytes;
- SHA-256: `963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb`;
- fat architectures: x86_64, i386, and `ppc7400`;
- PowerPC slice: CPU type `0x12`, subtype `0x0a`, fat offset `0x000b0000`, size `334064` bytes;
- PowerPC Mach-O header: `MH_MAGIC`, `MH_DYLINKER`, 9 load commands, `sizeofcmds=0x600`, flags `0x85`;
- the first PowerPC load command begins at the 32-bit header boundary `+0x1c` and is `LC_SEGMENT` with `cmdsize=0x258`.

That final point directly matches the parser behavior seen in the Lion core: when Rosetta receives this `ppc7400` slice, its hard-coded 32-bit `+0x1c` load-command cursor lands on a valid `LC_SEGMENT`, instead of the reserved word of Lion's x86_64 `MH_MAGIC_64` slice.


For manual verification, older Apple `lipo` versions accept different `-verify_arch` argument orderings; the collector tries both. The equivalent inspection for the observed control is:

```sh
file /usr/lib/dyld
/usr/bin/lipo -info /usr/lib/dyld
/usr/bin/lipo /usr/lib/dyld -verify_arch ppc7400 || /usr/bin/lipo -verify_arch ppc7400 /usr/lib/dyld
/usr/bin/otool -hv -arch ppc7400 /usr/lib/dyld
/usr/bin/shasum -a 256 /usr/lib/dyld
```

For the controlled experiment, use the short private path:

```
/usr/oah/dyld
```

The short path is deliberate. The Xcode 3.2.6 linker used for the known-good PPC build is ld64-97.17. In that linker, `-dylinker` is an output-kind switch used when building dyld itself; it does **not** accept a pathname argument. The same linker emits the executable's `LC_LOAD_DYLINKER` with the literal string `/usr/lib/dyld`. Therefore the former `-Wl,-dylinker,<path>` recipe was invalid: ld treated the following pathname as an input file, which produced `ld: file not found`.

The runtime build script now keeps the proven Xcode 3.2.6 PPC compilation path and, when `PPC_DYLINKER` is set, rewrites the existing `LC_LOAD_DYLINKER` command after a normal link. The replacement must fit in the existing load-command string area; `/usr/oah/dyld` has the same 13-character length as `/usr/lib/dyld`.

For the cleanest experiment, derive the private-dyld executable directly from the already validated baseline `ppc-smoketest`. This keeps every byte of the executable unchanged except the dylinker pathname field:

```sh
/bin/cp -p ./ppc-smoketest ./ppc-smoketest-private-dyld
/usr/bin/python ./scripts/patch-ppc-load-dylinker.py \
  ./ppc-smoketest-private-dyld /usr/oah/dyld
```

If the baseline executable is unavailable and a rebuild is required, explicitly use the proven Xcode 3.2.6 compiler:

```sh
CC=/Developer-3.2.6/usr/bin/gcc-4.2 \
PPC_DYLINKER=/usr/oah/dyld \
  ./scripts/build-ppc-smoketest-on-snowleopard.sh ./ppc-smoketest-private-dyld
```

The build script now probes `/Developer-3.2.6/usr/bin/gcc-4.2` before the Xcode 4.2 and system compiler paths.

Verify the resulting load command:

```sh
/usr/bin/otool -l ./ppc-smoketest-private-dyld | \
  /usr/bin/grep -A3 LC_LOAD_DYLINKER
```

It must name `/usr/oah/dyld`.

Before moving the experiment to Lion, validate the same arrangement on Snow Leopard. Stage the collected dyld at that private pathname, verify its SHA-256, and run the direct translator control:

```sh
sudo /bin/mkdir -p /usr/oah
sudo /usr/bin/ditto --rsrc --extattr \
  ./payload/snowleopard-10.6.8-dyld \
  /usr/oah/dyld
sudo /bin/chmod 755 /usr/oah/dyld

/usr/bin/shasum -a 256 /usr/oah/dyld
/usr/libexec/oah/translate ./ppc-smoketest-private-dyld
echo "status=$?"
```

The staged dyld hash must remain `963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb`. A successful smoke-test message and status 0 establish that the alternate `LC_LOAD_DYLINKER` path is itself valid under stock Snow Leopard Rosetta.


### Snow Leopard private-dyld positive control: PASS

The controlled Snow Leopard run has now passed exactly as designed:

- baseline `ppc-smoketest` SHA-256 remained `abdc2d58922b0a420e2c9a762816fecb3acf5e1d115eb29cfab444479f34217c`;
- the copied test was patched from `/usr/lib/dyld` to `/usr/oah/dyld` inside the existing `LC_LOAD_DYLINKER` command, whose path field has 16 bytes of capacity including NUL;
- `otool -l` confirmed the baseline still names `/usr/lib/dyld` and the experimental copy names `/usr/oah/dyld`;
- the experimental executable SHA-256 became `b34e7c4b1ffe9750ae866c4a1e2d732e5dd90aa44c3f79d15359d58076987b0a`;
- the staged `/usr/oah/dyld` SHA-256 matched the validated Snow Leopard dyld exactly: `963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb`;
- direct `/usr/libexec/oah/translate ./ppc-smoketest-private-dyld` printed the expected `Rosetta PPC smoke test` message and exited with status 0.

This proves that stock Snow Leopard Rosetta accepts the private-path dyld arrangement and that the post-link `LC_LOAD_DYLINKER` rewrite is behaviorally valid. It does not yet prove that Lion will succeed; the next experiment is the same private dyld and exact experimental PPC binary under Lion's direct translator.

Only after that control passes, transfer the exact experimental executable and the exact validated Snow Leopard dyld to the Lion runtime checkout. The guarded runner expects these default private input paths:

```
payload/ppc-smoketest-private-dyld
payload/snowleopard-10.6.8-dyld
```

Their required SHA-256 values are respectively:

```
b34e7c4b1ffe9750ae866c4a1e2d732e5dd90aa44c3f79d15359d58076987b0a
963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb
```

On Lion 10.7.5, pull the current runtime repository and run:

```sh
git pull
./scripts/run-lion-private-dyld-experiment.sh
```

The runner verifies the OS version, both input hashes, the PPC architecture, and the private `LC_LOAD_DYLINKER`; refuses unexpected or symlinked `/usr/oah` state; records Lion's native `/usr/lib/dyld` hash before and after staging; stages the validated Snow Leopard dyld only as `/usr/oah/dyld`; performs the direct-translator test; records the exit status; identifies any new crash reports or core files created after the test marker; and verifies both dyld hashes again afterward.

It writes:

```
payload/lion-private-dyld-experiment.log
payload/lion-private-dyld-direct.raw.log
```

Do not run the normal PPC exec path in this step. If the guarded runner fails, preserve both logs and every newly listed crash/core artifact before changing the runtime, kernel, or private dyld.

The direct translator operation performed by the runner is equivalent to:

```sh
/usr/libexec/oah/translate ./payload/ppc-smoketest-private-dyld
echo "status=$?"
```

If that reaches the PPC smoke-test message and exits 0, the private-dyld hypothesis is confirmed for direct translator launch.

### Lion private-dyld result: guest dyld reached, Rosetta cache rejected

The first guarded Lion run did not reproduce the earlier `0xc918a01c` parser crash. The exact experimental executable and private Snow Leopard dyld passed all identity checks, Lion's native `/usr/lib/dyld` hash remained unchanged, and the private PPC dyld reached ordinary guest-library resolution.

The new failure is explicit:

```
dyld: shared cached file was build against a different libSystem.dylib, ignoring cache
dyld: Library not loaded: /usr/lib/libgcc_s.1.dylib
  Referenced from: .../ppc-smoketest-private-dyld
  Reason: no suitable image found.  Did find:
    /usr/lib/libgcc_s.1.dylib: no matching architecture in universal wrapper
```

The direct translator exited 133, and the shell identified the terminating signal as `Trace/BPT trap: 5`. This is a different failure class from the former SIGSEGV: the private PPC dyld is now running far enough to reject the installed Rosetta shared cache as stale against Lion's on-disk libSystem and then fall back to Lion's ordinary `/usr/lib/libgcc_s.1.dylib`, which has no PPC slice.

Do not copy a Snow Leopard `libgcc_s.1.dylib` over Lion's system file. Before collecting individual guest libraries, test whether the already-installed, validated Snow Leopard Rosetta cache can satisfy this dependency when its on-disk inode/modification-time validation is disabled for this one process. The validated Snow Leopard dyld binary contains support for `DYLD_SHARED_CACHE_DONT_VALIDATE`, and Apple's dyld-132.13 documentation defines that variable specifically to allow a process to use shared-cache dylibs even when the corresponding files on disk no longer match.

The runner now has a separate, non-destructive cache-validation-bypass mode. The authoritative step-by-step procedure for this experiment is `docs/rosetta-shared-cache-experiment.md`; follow that document rather than improvising additional dyld environment variables or library copies. It uses different report filenames, verifies the exact validated Rosetta cache and map hashes, audits membership for `/usr/lib/libgcc_s.1.dylib`, `/usr/lib/libSystem.B.dylib`, and `/usr/lib/system/libmathCommon.A.dylib`, and then sets `DYLD_SHARED_CACHE_DONT_VALIDATE=1` plus `DYLD_PRINT_LIBRARIES=1` only for the direct translator process.

The first attempt at this mode stopped before launching `translate` because the runner incorrectly treated cache-map membership as an identity requirement. The exact cache and map hashes matched the validated baseline, while that map does not list `/usr/lib/libgcc_s.1.dylib`. The runner has been corrected: map membership is now diagnostic, so the experiment can answer the intended question—whether the validation-bypass variable prevents the guest dyld from rejecting the cache—even though the subject may subsequently stop on uncached `libgcc_s.1.dylib`.

Run the corrected mode with:

```sh
git pull
ROSETTA_CACHE_BYPASS_VALIDATION=1 \
  ./scripts/run-lion-private-dyld-experiment.sh
```

This writes:

```
payload/lion-private-dyld-cache-bypass-experiment.log
payload/lion-private-dyld-cache-bypass-direct.raw.log
```

Do not set `DYLD_SHARED_REGION=private` yet and do not rebuild the Rosetta cache for this step. The cache was already found by the guest dyld; the first question is whether bypassing only the stale-file validation is sufficient. If the cache-bypass run still reports a missing PPC image, preserve the exact output and newly generated crash/core diagnostics before collecting any additional Snow Leopard system library.

The normal PPC exec path is the next layer, but only expect it to work after the XNU PowerPC subject-path correction is present in the *running* kernel. If the currently booted kernel predates that correction, preserve the successful direct-launch result and defer the normal launch until the corrected kernel has been rebuilt and installed:

```sh
./scripts/run-ppc-smoketest.sh ./ppc-smoketest-private-dyld
```

If either test fails, preserve the exact output and newest crash report before changing anything else.


### Cache-bypass result: SIGSYS at retired syscall ABI

The corrected cache-bypass run removed the previous cache-rejection diagnostic and reported the PPC subject as loaded, but `translate` then exited 140. The non-debugged crash report identifies `EXC_CRASH (SIGSYS)`, `EIP=0xb815ac07`, and `EAX=0x4e`.

This is no longer best explained as an immediate missing-`libgcc_s.1.dylib` failure. Snow Leopard dyld 132.13 directly invokes legacy syscall 295 for `shared_region_map_np(fd, count, mappings)`. Snow Leopard XNU 1504.15.3 implements syscall 295 with that interface. Lion XNU 1699.32.7 replaces syscall 295 with `nosys` (`old shared_region_map_np`). Lion's `nosys()` sends `SIGSYS` and returns `ENOSYS`; `ENOSYS` is decimal 78, or `0x4e`, matching the crash register.

The postmortem collector has now confirmed this boundary. Runtime-decrypted code executes `int $0x80` at `0xb815ac05`, reaches `0xb815ac07` with `EAX=ENOSYS` and carry set, and the caller supplies syscall number 295 with arguments `fd=4`, `mappingCount=3`, and a three-entry shared-cache mapping array. The final mapping ends exactly at the validated Rosetta cache size (209,248,256 bytes). See `docs/postmortem-collector-experiment.md`. Do not collect or install a private `libgcc_s.1.dylib` yet; the next phase is XNU compatibility design for the old syscall-295 ABI.

## Production direction

A successful private-dyld experiment would establish the missing runtime dependency, but it would not by itself define the final installation design. A production solution should keep Lion's native dyld untouched and redirect only translated PPC guest dyld resolution to private Rosetta-compatible material. Candidate mechanisms should be evaluated only after the private-path experiment succeeds.


### Syscall-295 compatibility result: direct translation PASS

The syscall-295 XNU compatibility experiment has now passed end to end on Lion 10.7.5.

Validated boot kernel SHA-256:

```text
fe68467b60b3bd7edfab61b2d6c8af7f988de5206c4b7b624151dc9f1a1061d3
```

After reboot, the translated-commpage regression probe still passed and the native i386 syscall-295 routing probe returned `EBADF` without `SIGSYS`.

The guarded direct cache-bypass control then loaded:

```text
ppc-smoketest-private-dyld
/usr/libexec/oah/Shims/Interposers.dylib
/usr/lib/libSystem.B.dylib
/usr/lib/system/libmathCommon.A.dylib
```

It printed the expected `Rosetta PPC smoke test` message and exited 0. No new crash/core diagnostic was detected. Lion's native `/usr/lib/dyld` and private `/usr/oah/dyld` hashes remained unchanged.

This closes the direct-translator dyld/shared-region compatibility boundary for the minimal PPC subject under the private-dyld plus cache-validation-bypass arrangement.

The next controlled layer is **normal PowerPC exec activation**, not another library or kernel modification. Follow `docs/lion-normal-ppc-exec-experiment.md`. The normal-exec runner executes the PPC Mach-O itself rather than manually launching `translate`, so it specifically tests the kernel architecture-handler and PowerPC subject-path correction together with the now-validated runtime stack.
