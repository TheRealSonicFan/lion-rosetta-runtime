# ShowWindow preserved-core ArtFile state audit

## Objective

Use the already-preserved exact-seven Lion core to recover the **active Snow-PPC CoreUI ArtFile path state at the crash**, without launching the PPC subject again.

The preceding static audit proved the framework/resource mismatch but did not identify the exact archive component that produces the invalid pointer. The three visible diagnostic names are not stored as literal dotted strings in any audited archive; CoreUI stores component names separately and reconstructs paths through an index table. The preserved core contains the old PPC CoreUI global archive state and the still-live `CUIElement::Load` stack frame, so the next discriminator can be entirely postmortem.

## Accepted evidence entering this stage

Both targeted ArtFile audits completed `RESULT: PASS`.

### Snow PPC CoreUI contract

Snow Leopard uses:

```text
ShowArtFilePathToStdErr(unsigned char const*)
CUIElement::LoadFromArtFile(unsigned char const*)
CUIElement::Load(_QSIContext*, ...)
ArtFileSetupOnce()
```

The old `ArtFileSetupOnce()` obtains a CoreUI resource URL, mmaps that resource, byte-swaps the archive header into global state, and stores derived pointers into process globals.

The old diagnostic helper takes only the byte-path argument. It uses global archive tables to translate each path byte into a component-string pointer and passes that pointer to `fprintf`. It has no per-archive `ArtFileInfo*` argument.

### Lion native CoreUI contract

Lion uses:

```text
ShowArtFilePathToStdErr(ArtFileInfo*, unsigned char const*)
CUIElement::LoadFromArtFile(unsigned char const*)
CUIElement::Load(void*, ...)
ArtFileInfo::ArtFile10SetupOnce()
ArtFileInfo::ArtFile20SetupOnce()
ArtFileInfo::GetArtFileInfoForScaleFactor(float)
```

The Lion helper validates both arguments and checks multiple `ArtFileInfo` fields/bounds before decoding a component string. Its loader passes the active `ArtFileInfo*` plus the path.

This is a material contract change, not just a renamed file.

### Archive generation

Snow:

```text
ArtFile.bin   5,946,480 bytes
SArtFile.bin    811,436 bytes
ArtFile200.bin  absent
scrollbars.xml  present
```

Lion:

```text
ArtFile.bin     4,765,184 bytes
SArtFile.bin    9,370,228 bytes
ArtFile200.bin 18,101,720 bytes
scrollbars.xml  absent
```

The exact diagnostic strings:

```text
west.clear.colorsrgb.determinate.scrollbars
west.colorsrgb.determinate.minus.scrollbars
west.colorsrgb.determinate.scrollbars
```

occur **zero times as complete byte strings** in Snow `ArtFile.bin`, Snow `SArtFile.bin`, Lion `ArtFile.bin`, Lion `ArtFile200.bin`, and Lion `SArtFile.bin`. Both ArtFile generations do contain component strings such as `colorsrgb`, `scrollbars`, and `titlebarcontrols`.

Therefore a literal-string search cannot identify the failing record. The index path must be decoded.

### Preserved crash

The preserved exact-seven crash remains:

```text
core
/cores/core.89664

crash report
$HOME/Library/Logs/DiagnosticReports/ppc-process-manager-cgs-session-bootstrap-integration-private-dy_2026-10-12-235958_Andys-Mac.crash

fault
EXC_BAD_ACCESS / KERN_INVALID_ADDRESS at 0x787221c4
```

The exact Snow-PPC CoreUI runtime image base is:

```text
0x923de000
```

The `CUIElement::Load` return address saved by `CUIElement::LoadFromArtFile` is:

```text
0x92407c84
```

In the Snow PPC `CUIElement::Load` body, the ArtFile path buffer is allocated at:

```text
Load-frame SP + 0x44
```

That lets the preserved PPC stack identify the exact eight-byte path used by the crashing call.

## Analyzer-v1 correction after the first Phase D run

The first Phase D report is useful evidence, but its final `RESULT: FAIL` came from an analyzer addressing error rather than a new Rosetta runtime failure.

Analyzer v1 took writable-data/global offsets from the standalone Snow Leopard PPC CoreUI slice, added the observed shared-cache CoreUI text base `0x923de000`, and treated those results as live global addresses. That assumption is invalid for the Rosetta dyld shared cache: code and writable data can be placed independently, and the cached PPC instructions contain the relocated PIC references that must be used at runtime.

The failed report itself exposes the mistake:

- both GDB passes succeeded;
- the PPC backchain still recovered one unique `CUIElement::Load` frame;
- the active path bytes were recovered as `a6 16 1f 7a b6 00 00 00`;
- the supposed legacy header/global values decode as PPC instruction words, and the supposed mapped-ArtFile head is executable PPC code rather than an ArtFile header.

Therefore the fixed addresses from analyzer v1 are retained only as an **uncached-reference diagnostic**. Analyzer v2 derives the actual runtime global addresses from the cached PPC instructions preserved in the same core and cross-checks the references used by `ShowArtFilePathToStdErr` and `ArtFileSetupOnce`.

Keep the same `/cores/core.89664` and matching crash report. Do not rerun the PPC subject to correct this collector bug.

## Prepared collector

Current runtime `main` provides:

```text
scripts/collect-pm-art-core.py
```

Analyzer version:

```text
2
```

The collector is Python-2-compatible and read-only. It:

1. verifies Lion 10.7.5;
2. verifies the accepted Rosetta translator SHA-256;
3. verifies Lion `ArtFile.bin` size and SHA-256 from the prior audit;
4. verifies the matching crash report contains the exact fault and the expected Snow-PPC CoreUI frames;
5. opens only the preserved core with Apple GDB in batch mode;
6. dumps the small Snow-PPC CoreUI code window containing `ShowArtFilePathToStdErr` / `ArtFileSetupOnce` plus a bounded PPC guest-stack range;
7. decodes the cached PPC `addis` + D-form instruction pairs to recover the **runtime** CoreUI global addresses, then cross-checks the header/table/string globals derived independently from the helper and setup code;
8. performs a second read-only GDB pass for only those recovered global words/header bytes;
9. decodes the old PPC CoreUI global values as big-endian guest data;
10. performs a third read-only GDB pass for only the first 256 bytes at the recovered mmap base;
11. requires the recovered mmap base to be page-aligned and those bytes to match Lion's on-disk `ArtFile.bin`;
12. requires the old PPC parsed-header globals and derived table/string pointers to match the Lion `ArtFile.bin` header;
13. follows the PPC stack backchain from the recorded crash SP;
14. identifies the unique `CUIElement::Load` frame via saved LR `0x92407c84`;
15. recovers the path buffer at that frame's SP plus `0x44`;
16. emulates the old PPC helper's component lookup while separately validating the component ID against Lion's header count and the computed table entry against the table/string-pool boundary;
17. reports both safe decoded components and the unsafe legacy lookup value/pointer for any out-of-range component, including its delta from fault address `0x787221c4`;
18. deletes all temporary memory dumps before exit.

Only the final text report is retained.

## Safety constraints

- Do not rerun the PPC ShowWindow subject.
- Do not rerun or rebuild the exact-seven notification broker.
- Do not attach GDB to a live process.
- Do not use DTrace or dtruss.
- Do not copy or replace Snow Leopard CoreUI/HIToolbox or any ArtFile resource.
- Do not patch Lion `ArtFile.bin`, `ArtFile200.bin`, or `SArtFile.bin`.
- Do not interpose `ShowArtFilePathToStdErr`, `LoadFromArtFile`, `fprintf`, or `vfprintf`.
- Do not change RawCamera, ImageIO, `CGSShapeWindow`, or any accepted compatibility adapter.
- Do not restart WindowServer, Dock, fontd, distnoted, launchd, or related services.
- Do not change XNU, rebuild the kernel, or reboot.
- Keep `/cores/core.89664` and the matching crash report preserved until this stage is reviewed.

## Phase A — update runtime on Lion

On Lion:

```sh
export RUNTIME=/path/to/lion-rosetta-runtime

cd "$RUNTIME" || exit 1
git pull --ff-only
git rev-parse HEAD

ls -l ./scripts/collect-pm-art-core.py
ls -l ./docs/pm-showwindow-art-core.md
```

No Snow Leopard action is required for this stage.

## Phase B — syntax-check the collector

On Lion:

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python -c 'compile(open("./scripts/collect-pm-art-core.py","rb").read(),"collect-pm-art-core.py","exec")' || exit 1
```

This syntax check does not launch the PPC subject.

## Phase C — confirm preserved evidence

```sh
CORE=/cores/core.89664
CRASH="$HOME/Library/Logs/DiagnosticReports/ppc-process-manager-cgs-session-bootstrap-integration-private-dy_2026-10-12-235958_Andys-Mac.crash"

ls -lh "$CORE" "$CRASH" || exit 1
```

If either file is missing, stop and report which one is unavailable. Do **not** recreate it by rerunning the PPC subject.

## Phase D — collect the preserved-core ArtFile state

```sh
cd "$RUNTIME" || exit 1

/usr/bin/python ./scripts/collect-pm-art-core.py \
  "$CORE" \
  "$CRASH" \
  ./pm-art-core.txt
```

Require:

```text
Created: .../pm-art-core.txt
RESULT: PASS
```

The report should also contain:

```text
analyzer_version=2
runtime_global_address_decode=PASS
shared_cache_data_relocated=YES
mapped_base_page_aligned=YES
core_header_matches_lion_disk=YES
legacy_derived_pointers_match_lion_header=YES
core_mapped_head_matches_lion_disk=YES
load_frame_match_count=1
```

These gates establish that the collector decoded the shared-cache relocation correctly, that the old Snow-PPC CoreUI instance in the crash was initialized from Lion's current `ArtFile.bin`, and that the active path buffer was recovered from the correct stack frame. `shared_cache_data_relocated=YES` is expected because analyzer v1 already demonstrated that the uncached data addresses do not contain the live globals.

A successful report may still contain `invalid_component_id_count` or `invalid_component_pointer_count` greater than zero. Those are **compatibility findings**, not collector failures, once the provenance gates above pass.

## Phase E — return evidence

Return exactly:

```text
pm-art-core.txt
```

Do not return the full core, temporary stack/global dumps, Lion `ArtFile.bin`, or any Apple framework/resource binary.

## Review gates

### A path component exceeds Lion's legacy component count or crosses the table boundary

This is now the highest-value discriminator. Lion's legacy-decoded `ArtFile.bin` header reports component maximum/count field `0xa9` (169), while the analyzer-v1 stack recovery produced path byte `0xb6` (182). For Lion's header layout, the old helper's `0xb6` entry address lands after the component table and inside the string pool. Analyzer v2 must confirm this against the correctly recovered runtime globals before it is treated as final proof.

If confirmed with `id_within_component_count=NO` and `entry_within_component_table=NO`, the archive-contract mismatch is exact: Snow-PPC CoreUI is indexing a component ID that Lion's legacy ArtFile table does not define. The next compatibility experiment must be scoped to that one path/table semantic boundary; do not replace the whole archive.

### Unsafe legacy lookup matches or is adjacent to the fault address

For an invalid component, analyzer v2 still emulates the unchecked legacy read and reports the resulting unsafe runtime pointer and signed fault delta. If it equals `0x787221c4`, lies inside the referenced bytes, or is immediately adjacent in a way explained by the failing `fprintf` load, the old PPC diagnostic helper's incompatible table decode is directly linked to the SIGSEGV. Preserve the exact delta for the next design step.

### All decoded path components are valid Lion ArtFile strings

If every component ID/table entry is valid and the fault address does not correspond to any decoded component, the crash is later in the old diagnostic/formatting path. Preserve the recovered path and move the next postmortem discriminator to the exact `fprintf` arguments/saved PPC registers; do not infer that the ArtFile archive itself needs replacement.

### Runtime-global decode fails

Keep the same core. This means the cached instruction-reference decoder needs refinement; it is not evidence that the ArtFile resource is incompatible. Do not fall back to analyzer-v1 fixed addresses.

### Runtime globals decode, but ArtFile provenance does not match

Treat this as an evidence/provenance result. The mapped object may be another archive or the recovered field interpretation may still need correction. Update only the read-only collector and repeat against the same preserved core.

### PPC backchain does not uniquely recover the Load frame

Keep the same core. Refine only the postmortem stack decoder; do not rerun the subject.

## Current boundary

```text
Rosetta shared cache Snow/Lion                    identical
Lion crash code                                   exact Snow-PPC CoreUI/HIToolbox
old PPC diagnostic helper                         global archive tables; no ArtFileInfo
native Lion diagnostic helper                     ArtFileInfo-aware and bounds-checked
Lion ArtFile generation                           structurally changed
analyzer-v1 fixed global-address assumption       disproven by first Phase D report
shared-cache runtime globals                      derive from cached PPC PIC references
recovered crash-time path                         a6 16 1f 7a b6 00 00 00 (v1; revalidate in v2)
Lion legacy component max                         0xa9 / 169
candidate incompatible component                  0xb6 / 182
exact bad component/table lookup                  pending analyzer-v2 provenance gates
next step                                         rerun analyzer v2 on same preserved core
PPC subject rerun                                 NO
resource substitution                             NO
RawCamera / ShapeWindow                           held
XNU                                                no change indicated
```


## Observed result — exact component-table overrun and crash pointer proven

Analyzer v2 completes all three GDB passes and ends `RESULT: PASS`. The shared-cache relocation is now resolved correctly: the live globals are at `0xa028c...`, the mapped archive is page-aligned at `0x030fb000`, and the recovered header/table/string pointers match Lion's on-disk `ArtFile.bin` exactly.

The active path is confirmed as:

```text
a6 16 1f 7a b6 00 00 00
west.colorsrgb.determinate.scrollbars.<invalid-0xb6>
```

Lion's legacy ArtFile component table contains `0xa9` / 169 entries and ends at file offset `0x560`. Old Snow-PPC CoreUI nevertheless indexes component `0xb6` / 182 at `0x5c0`, which is `0x60` bytes inside Lion's string pool. The unchecked legacy lookup reads `0x75626c65` there as a relative string offset and computes runtime pointer `0x787221c5`.

That exact pointer is already present in the earlier preserved crash as PPC `r3` and `r25`; the faulting address is `0x787221c4`, also present as PPC `r9` and host `ECX/CR2`. The ArtFile component-table overrun therefore explains the exact invalid pointer reaching the translated `fprintf/vfprintf` path. This is no longer only a nearby or circumstantial archive mismatch.

Do not suppress the diagnostic or add a blind bounds check as the compatibility fix. The diagnostic crash is downstream of a real semantic mismatch: Snow-PPC path construction emitted a component ID that Lion's legacy ArtFile table does not define.

The authoritative next procedure is:

```text
docs/pm-showwindow-artfile-component-audit.md
```

Run its read-only analyzer once on Snow Leopard and once on Lion and return `pm-art-components-snow.txt` and `pm-art-components-lion.txt`. The goal is to identify the Snow semantic name for component `0xb6` and determine whether Lion retains the same semantic under a different ID or removed it entirely. No PPC rerun, resource substitution, or XNU change is indicated.
