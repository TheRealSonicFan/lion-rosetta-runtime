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

## Prepared collector

Current runtime `main` provides:

```text
scripts/collect-pm-art-core.py
```

Analyzer version:

```text
1
```

The collector is Python-2-compatible and read-only. It:

1. verifies Lion 10.7.5;
2. verifies the accepted Rosetta translator SHA-256;
3. verifies Lion `ArtFile.bin` size and SHA-256 from the prior audit;
4. verifies the matching crash report contains the exact fault and the expected Snow-PPC CoreUI frames;
5. opens only the preserved core with Apple GDB in batch mode;
6. dumps a small fixed CoreUI global-state range and a bounded PPC guest-stack range to temporary files;
7. decodes the old PPC CoreUI globals as big-endian guest values;
8. reads the old archive header pointers that `ArtFileSetupOnce()` stored;
9. performs a second read-only GDB pass for only the first 256 bytes at the recovered mmap base;
10. requires those bytes to match Lion's on-disk `ArtFile.bin`;
11. requires the old PPC parsed-header globals and derived table/string pointers to match the Lion `ArtFile.bin` header;
12. follows the PPC stack backchain from the recorded crash SP;
13. identifies the unique `CUIElement::Load` frame via saved LR `0x92407c84`;
14. recovers the path buffer at that frame's SP plus `0x44`;
15. emulates the old PPC helper's component-table lookup against Lion `ArtFile.bin`;
16. reports each path byte, table entry, string offset, runtime pointer, decoded component, file-bounds state, and relation to fault address `0x787221c4`;
17. deletes all temporary memory dumps before exit.

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
core_header_matches_lion_disk=YES
legacy_derived_pointers_match_lion_header=YES
core_mapped_head_matches_lion_disk=YES
load_frame_match_count=1
```

Those four gates establish that the old Snow-PPC CoreUI instance in the crash was initialized from Lion's current `ArtFile.bin` and that the active path buffer was recovered from the correct stack frame.

## Phase E — return evidence

Return exactly:

```text
pm-art-core.txt
```

Do not return the full core, temporary stack/global dumps, Lion `ArtFile.bin`, or any Apple framework/resource binary.

## Review gates

### One decoded component produces an out-of-file pointer

If the recovered path contains a component whose legacy table lookup resolves outside Lion `ArtFile.bin`, that is the first exact failing archive-contract discriminator. The next compatibility experiment must be scoped to that lookup/record interpretation; do not replace the whole archive.

### Fault address matches or lies inside one decoded component string

If `0x787221c4` equals or falls inside a reconstructed component-string pointer range, the old PPC diagnostic helper's incompatible table decode is directly proven. The next stage can be designed around the smallest path/table compatibility boundary.

### All decoded path components are valid Lion ArtFile strings

If every component pointer is in-bounds and the fault address does not correspond to any decoded component, the crash is later in the old diagnostic/formatting path. Preserve the recovered path and move the next postmortem discriminator to the exact `fprintf` arguments/saved PPC registers; do not infer that the ArtFile archive itself needs replacement.

### Core global state does not match Lion ArtFile.bin

Treat this as an evidence/provenance result, not a compatibility failure. The mapped object may be another archive or the assumed old-global offsets may need correction. Update only the read-only collector and repeat against the same preserved core.

### PPC backchain does not uniquely recover the Load frame

Keep the same core. Refine only the postmortem stack decoder; do not rerun the subject.

## Current boundary

```text
Rosetta shared cache Snow/Lion                    identical
Lion crash code                                   exact Snow-PPC CoreUI/HIToolbox
old PPC diagnostic helper                         global archive tables; no ArtFileInfo
native Lion diagnostic helper                     ArtFileInfo-aware and bounds-checked
Lion ArtFile generation                           structurally changed
visible dotted diagnostics                        synthesized from component IDs
exact crash-time path bytes                       recoverable from preserved core
exact bad component/table lookup                  not yet proven
next step                                         preserved-core path/table decode
PPC subject rerun                                 NO
resource substitution                             NO
RawCamera / ShapeWindow                           held
XNU                                                no change indicated
```
