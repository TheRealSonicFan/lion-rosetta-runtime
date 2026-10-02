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

Only after that control passes, stage the same Snow Leopard dyld privately on Lion at the identical `/usr/oah/dyld` pathname, preserving the checksum. Do not overwrite `/usr/lib/dyld`.

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
