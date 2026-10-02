# PowerPC dyld compatibility gap on Lion

## Finding

Postmortem analysis of a non-debugged Lion `translate` core shows that Rosetta explicitly opens `/usr/lib/dyld` while constructing a Mach-O parser for CPU type `0x12` (PowerPC).

On the tested Lion 10.7.5 system, `/usr/lib/dyld` contains only x86_64 and i386 slices. The Snow Leopard translator's private parser does not safely reject that no PPC slice was found: its architecture-selection fallback chooses the first available slice. On Lion this is x86_64.

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

The collector is read-only with respect to `/usr/lib/dyld`. It requires a 32-bit `ppc` slice, records `file`, `lipo`, the PPC Mach-O header, and SHA-256 evidence, then copies the original Snow Leopard dyld unchanged into the ignored `payload/` directory. It emits:

```
payload/snowleopard-10.6.8-dyld
payload/snowleopard-10.6.8-dyld.info.txt
payload/snowleopard-10.6.8-dyld.sha256
```

Keep all three artifacts private. Only continue when the report says `ppc_verify=PASS` and the source/copy checksums match.

For manual verification, older Apple `lipo` versions accept different `-verify_arch` argument orderings; the collector tries both. The equivalent inspection is:

```sh
file /usr/lib/dyld
/usr/bin/lipo -info /usr/lib/dyld
/usr/bin/lipo /usr/lib/dyld -verify_arch ppc || /usr/bin/lipo -verify_arch ppc /usr/lib/dyld
/usr/bin/otool -hv -arch ppc /usr/lib/dyld
/usr/bin/shasum -a 256 /usr/lib/dyld
```

For a disposable experiment, put a private copy of the validated Snow Leopard dyld at a path that does not replace any Lion native file. For example:

```
/usr/local/libexec/rosetta-test/dyld
```

Then, on Snow Leopard, build a new PPC smoke executable whose `LC_LOAD_DYLINKER` names that path:

```sh
PPC_DYLINKER=/usr/local/libexec/rosetta-test/dyld \
  ./scripts/build-ppc-smoketest-on-snowleopard.sh ./ppc-smoketest-private-dyld
```

Verify the resulting load command before moving the binary:

```sh
/usr/bin/otool -l ./ppc-smoketest-private-dyld | \
  /usr/bin/grep -A3 LC_LOAD_DYLINKER
```

Stage the Snow Leopard dyld privately on Lion, preserving a checksum of the source and destination. Do not overwrite `/usr/lib/dyld`.

Run the direct-translator control first:

```sh
/usr/libexec/oah/translate ./ppc-smoketest-private-dyld
echo "status=$?"
```

If that reaches the PPC smoke-test message and exits 0, the private-dyld hypothesis is confirmed for direct translator launch.

The normal PPC exec path is the next layer, but only expect it to work after the XNU PowerPC subject-path correction is present in the *running* kernel. If the currently booted kernel predates that correction, preserve the successful direct-launch result and defer the normal launch until the corrected kernel has been rebuilt and installed:

```sh
./scripts/run-ppc-smoketest.sh ./ppc-smoketest-private-dyld
```

If either test fails, preserve the exact output and newest crash report before changing anything else.

## Production direction

A successful private-dyld experiment would establish the missing runtime dependency, but it would not by itself define the final installation design. A production solution should keep Lion's native dyld untouched and redirect only translated PPC guest dyld resolution to private Rosetta-compatible material. Candidate mechanisms should be evaluated only after the private-path experiment succeeds.
