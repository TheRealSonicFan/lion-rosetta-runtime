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

For a disposable experiment, choose a private dyld pathname that does not replace any Lion native file. For example:

```
/usr/local/libexec/rosetta-test/dyld
```

The pathname does **not** need to exist while the smoke executable is being linked. `PPC_DYLINKER` is passed to the linker only to encode that string in the executable's `LC_LOAD_DYLINKER` command. The dyld file must exist at that pathname before the executable is actually run.

On Snow Leopard, build a **new** disposable smoke executable whose test source is the same minimal PPC smoke-test source used by this script, but whose `LC_LOAD_DYLINKER` differs from the earlier `ppc-smoketest`:

```sh
PPC_DYLINKER=/usr/local/libexec/rosetta-test/dyld \
  ./scripts/build-ppc-smoketest-on-snowleopard.sh ./ppc-smoketest-private-dyld
```

The existing `ppc-smoketest` is retained as the baseline artifact; `ppc-smoketest-private-dyld` is a separately compiled experimental binary, not a rename or copy of the baseline.

Verify the resulting load command before moving the binary:

```sh
/usr/bin/otool -l ./ppc-smoketest-private-dyld | \
  /usr/bin/grep -A3 LC_LOAD_DYLINKER
```

Before moving the experiment to Lion, validate the exact alternate-path arrangement on Snow Leopard itself. Stage the collected dyld at the same private pathname named by `LC_LOAD_DYLINKER`, verify its SHA-256, and run the direct translator control:

```sh
sudo /bin/mkdir -p /usr/local/libexec/rosetta-test
sudo /usr/bin/ditto --rsrc --extattr \
  ./payload/snowleopard-10.6.8-dyld \
  /usr/local/libexec/rosetta-test/dyld
sudo /bin/chmod 755 /usr/local/libexec/rosetta-test/dyld

/usr/bin/shasum -a 256 /usr/local/libexec/rosetta-test/dyld
/usr/libexec/oah/translate ./ppc-smoketest-private-dyld
echo "status=$?"
```

The staged dyld hash must remain `963fb4eb0649119b68d400713d178058ca5b0a471d6715c9ad6e802ede6df5cb`. A successful smoke-test message and status 0 establish that the alternate `LC_LOAD_DYLINKER` path is itself valid under stock Snow Leopard Rosetta.

Only after that control passes, stage the same Snow Leopard dyld privately on Lion at the identical pathname, preserving the checksum. Do not overwrite `/usr/lib/dyld`.

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
